extends Node
## LIFE-3: survival engine, autoload "Survival". The server/system source of truth for vitals.
## Foxy's vitals HUD, suit UI and companion needs/moods READ from here (Survival.vitals(id) and the
## vitals_changed signal); they never write vitals themselves. Spec: docs/specs/foxy/LIVING_WORLD_CLIENT.md.
##
## Real-ish physiology, simplified for play (sources in docs/modules/SURVIVAL.md):
##   o2_sat   blood oxygen saturation %, from inspired O2 partial pressure (sea level ~21 kPa -> ~98 %)
##   co2      CO2 load 0..100 from inspired CO2 partial pressure (symptoms ~1 kPa, severe >= 5 kPa)
##   core_c   core temperature; hypothermia < 35 C, heat illness > 39.5 C
##   pressure_ok  false below the Armstrong limit (6.3 kPa) or above 1000 kPa unless sealed
##   radiation_msv cumulative dose; > 1000 mSv triggers void sickness (Disease)
##   hydration 0..100 (about 2.5 L a day; empty in ~3 days, faster in heat)
##   calories kcal reserve 0..2500 (about 2000 kcal/day at rest, more working or cold)
##   fatigue  0..100 (full after ~16 h awake; sleep clears it in ~8 h)
##   health   0..100; 0 = "incapacitated" (non-graphic: you need a rescue or wake at home)
## Time is in GAME hours. tick_region() runs at TICK_S real seconds and only for active regions.
## Rules skip the actor when LivingGate.exempt (Profile.is_owner(): owner role + unlocked vault).
## Estate survival mode: off = vitals hold still; softcore = half drain, health floors at 10.
## E-stop: bots/companions are frozen (held) while AutonomyGuard is paused.

signal vitals_changed(id: String, vitals: Dictionary)

const TICK_S := 5.0                 # real seconds between region ticks (low rate, phone-safe)
const GAME_H_PER_REAL_S := 1.0 / 600.0   # 1 real minute = 0.1 game hours (4 h day cycle -> 24 game h)
const KCAL_MAX := 2500.0
const BMR_KCAL_H := 83.0            # ~2000 kcal/day
const HYDRATION_H := 100.0 / 72.0   # % per hour at rest (~3 days without water)
const FATIGUE_H := 100.0 / 16.0
const SLEEP_H := 100.0 / 8.0
const ARMSTRONG_KPA := 6.3
const CRUSH_KPA := 1000.0
const ACTIVITY := {"sleep": 0.9, "idle": 1.0, "walk": 1.5, "work": 2.5, "mine": 3.0, "sprint": 4.0}
const DEFAULTS := {"o2_sat": 98.0, "co2": 0.0, "core_c": 37.0, "pressure_ok": true, "radiation_msv": 0.0,
	"hydration": 100.0, "calories": 2000.0, "fatigue": 0.0, "health": 100.0, "suit_o2_h": 0.0,
	"state": "ok", "alerts": [], "region": "", "mode": "off", "exempt": false}

var root := "user://living"
var _v := {}            # id -> vitals
var _track := {}        # id -> {actor, region, opts}
var _active := {}       # region -> true
var _acc := 0.0

func _ready() -> void:
	var d: Variant = SecureFile.read_json(root.path_join("vitals.json"), {})
	_v = d if d is Dictionary else {}
	set_process(false)

func vitals(id: String) -> Dictionary:
	var v: Dictionary = _v.get(id, {})
	var out := DEFAULTS.duplicate(true)
	out.merge(v, true)
	return out

func _put(id: String, v: Dictionary) -> void:
	_v[id] = v
	vitals_changed.emit(id, v.duplicate(true))

# ---------- region activity (only active regions tick) ----------
func set_region_active(region: String, on: bool) -> void:
	if on: _active[region] = true
	else: _active.erase(region)
	set_process(not _active.is_empty())

func active_regions() -> Array: return _active.keys()

## Register an actor in a region with its environment options (shelter, powered, suit, activity, y, t01).
func track(actor: Variant, region: String, opts := {}) -> void:
	_track[Tiers.actor_id(actor)] = {"actor": actor, "region": region, "opts": opts.duplicate()}

func untrack(actor: Variant) -> void: _track.erase(Tiers.actor_id(actor))

## PowerData budget (docs/modules/POWER_AND_DATA.md): sim_tick_hz from AutoConfig. TICK_S stays the
## floor (we never tick faster than every 5 s); 0 Hz (background) pauses ticking, time still accrues
## and is applied in one step when ticking resumes.
func tick_interval() -> float:
	var ac := get_node_or_null("/root/AutoConfig")
	var hz := float(ac.budget("sim_tick_hz", 1)) if ac != null and ac.has_method("budget") else 1.0
	if hz <= 0.0: return INF
	return maxf(TICK_S, 1.0 / hz)

func _process(delta: float) -> void:
	_acc += delta
	if _acc < tick_interval(): return
	var dt_h := minf(_acc, Dormancy.MAX_CATCH_UP_S) * GAME_H_PER_REAL_S
	_acc = 0.0
	for r in _active.keys():
		if Dormancy.is_dormant(DORMANCY_PREFIX + r): continue   # asleep: caught up on wake
		tick_region(r, dt_h)
		Ecology.step(r, dt_h)

# ---------- Dormancy (shared helper, PR #39) ----------
## Regions with no nearby viewer sleep (zero cost). On wake, ONE catch-up call applies the whole
## elapsed time: survival + disease in a single tick_actor step (the physiology clamps make a large
## dt safe) and ecology through closed-form logistic growth. Never a tick-by-tick replay.
const DORMANCY_PREFIX := "living:"
func register_region(region: String, center: Vector3, wake_radius := 96.0) -> void:
	Dormancy.register(DORMANCY_PREFIX + region, center, func(elapsed_s: float): catch_up(region, elapsed_s), wake_radius, "living")
	set_region_active(region, true)

func unregister_region(region: String) -> void:
	Dormancy.unregister(DORMANCY_PREFIX + region)
	set_region_active(region, false)

func catch_up(region: String, elapsed_s: float) -> void:
	var dt_h := minf(elapsed_s, Dormancy.MAX_CATCH_UP_S) * GAME_H_PER_REAL_S
	if dt_h <= 0.0: return
	tick_region(region, dt_h)
	Ecology.step(region, dt_h)

func tick_region(region: String, dt_h: float) -> int:
	var n := 0
	for id in _track.keys():
		var t: Dictionary = _track[id]
		if t["region"] == region:
			tick_actor(t["actor"], region, t["opts"], dt_h); n += 1
	return n

# ---------- the physiology step ----------
static func _o2_target(o2_kpa: float) -> float:
	# piecewise approximation of the oxygen-haemoglobin curve vs inspired pO2
	var pts := [[0.0, 10.0], [6.0, 35.0], [8.0, 60.0], [12.0, 82.0], [16.0, 92.0], [19.0, 97.0], [21.0, 98.0], [100.0, 99.0]]
	for i in range(1, pts.size()):
		if o2_kpa <= pts[i][0]:
			return lerpf(pts[i - 1][1], pts[i][1], (o2_kpa - pts[i - 1][0]) / (pts[i][0] - pts[i - 1][0]))
	return 99.0

## One step for one actor. Returns the new vitals. opts: y, t01, shelter, powered, suit, activity.
func tick_actor(actor: Variant, region: String, opts: Dictionary, dt_h: float) -> Dictionary:
	var id := Tiers.actor_id(actor)
	var v := vitals(id)
	var mode := LivingGate.mode(region)
	v["region"] = region; v["mode"] = mode
	if LivingGate.exempt(actor):
		var fresh := DEFAULTS.duplicate(true)
		fresh["region"] = region; fresh["mode"] = mode; fresh["exempt"] = true
		_put(id, fresh); return fresh
	v["exempt"] = false
	if mode == "off" or LivingGate.frozen(actor) or dt_h <= 0.0:
		_put(id, v); return v
	var k := 0.5 if mode == "softcore" else 1.0
	Disease.advance(actor, dt_h)
	var outdoor := WorldEnv.outdoor(LivingGate.realm_of(region), float(opts.get("y", 0.0)), float(opts.get("t01", 0.5)))
	var o := opts.duplicate(); o["suit_o2"] = float(v["suit_o2_h"]) > 0.0
	var env := WorldEnv.personal(outdoor, o)
	var act := float(ACTIVITY.get(str(opts.get("activity", "idle")), 1.0))
	var fx := Disease.effects(id)
	var alerts: Array = []
	# breathing gas: the suit tank drains while it is doing the work
	var suit := WorldEnv.suit(str(opts.get("suit", "none")))
	var in_habitat := bool(WorldEnv.shelter(str(opts.get("shelter", ""))).get("sealed", false)) and bool(opts.get("powered", true))
	if float(v["suit_o2_h"]) > 0.0 and not in_habitat and (bool(suit.get("sealed", false)) or bool(suit.get("mask", false))):
		v["suit_o2_h"] = maxf(0.0, float(v["suit_o2_h"]) - dt_h * act * float(fx.get("o2_need", 1.0)))
	var mix := clampf(dt_h * 30.0, 0.0, 1.0)   # gas exchange settles within minutes
	v["o2_sat"] = lerpf(float(v["o2_sat"]), _o2_target(float(env["o2_kpa"]) / float(fx.get("o2_need", 1.0))), mix)
	v["co2"] = lerpf(float(v["co2"]), clampf(float(env["co2_kpa"]) / 8.0 * 100.0, 0.0, 100.0), mix)
	var p := float(env["pressure_kpa"])
	v["pressure_ok"] = bool(env["sealed"]) or (p >= ARMSTRONG_KPA and p <= CRUSH_KPA)
	# temperature: drift outside the 10..30 C comfort band
	var felt := float(env["temp_c"])
	var drift := 0.0
	if felt < 10.0: drift = -(10.0 - felt) * 0.02
	elif felt > 30.0: drift = (felt - 30.0) * 0.02
	else: drift = (37.0 - float(v["core_c"])) * 0.5
	v["core_c"] = clampf(float(v["core_c"]) + drift * dt_h * k, 25.0, 44.0)
	# radiation, food, water, fatigue
	v["radiation_msv"] = float(v["radiation_msv"]) + float(env["radiation_msv_day"]) / 24.0 * dt_h
	var cold := maxf(0.0, 10.0 - felt) * 0.02
	v["calories"] = clampf(float(v["calories"]) - BMR_KCAL_H * act * (1.0 + cold) * dt_h * k, 0.0, KCAL_MAX)
	var heat := 1.0 + maxf(0.0, felt - 25.0) * 0.05
	v["hydration"] = clampf(float(v["hydration"]) - HYDRATION_H * heat * act * float(fx.get("hydration_rate", 1.0)) * dt_h * k, 0.0, 100.0)
	if str(opts.get("activity", "")) == "sleep": v["fatigue"] = maxf(0.0, float(v["fatigue"]) - SLEEP_H * dt_h)
	else: v["fatigue"] = minf(100.0, float(v["fatigue"]) + FATIGUE_H * act * 0.5 * float(fx.get("fatigue_rate", 1.0)) * dt_h * k)
	# health
	var dmg := 0.0
	if float(v["o2_sat"]) < 85.0: dmg += (85.0 - float(v["o2_sat"])) * 1.5; alerts.append("low_oxygen")
	if float(v["co2"]) > 25.0: dmg += (float(v["co2"]) - 25.0) * 0.8; alerts.append("high_co2")
	if not bool(v["pressure_ok"]): dmg += 120.0; alerts.append("pressure")
	if float(v["core_c"]) < 35.0: dmg += (35.0 - float(v["core_c"])) * 8.0; alerts.append("too_cold")
	if float(v["core_c"]) > 39.5: dmg += (float(v["core_c"]) - 39.5) * 8.0; alerts.append("too_hot")
	if bool(env["acid"]): dmg += 10.0; alerts.append("acid")
	if float(v["hydration"]) <= 0.0: dmg += 4.0; alerts.append("thirsty")
	elif float(v["hydration"]) < 25.0: alerts.append("thirsty")
	if float(v["calories"]) <= 0.0: dmg += 1.5; alerts.append("hungry")
	elif float(v["calories"]) < 500.0: alerts.append("hungry")
	if float(v["fatigue"]) >= 100.0: dmg += 1.0; alerts.append("exhausted")
	elif float(v["fatigue"]) > 80.0: alerts.append("tired")
	if float(v["radiation_msv"]) > 1000.0: alerts.append("radiation")
	dmg -= float(fx.get("health_rate", 0.0))
	var heal := 2.0 if alerts.is_empty() else 0.0
	v["health"] = clampf(float(v["health"]) - dmg * dt_h * k + heal * dt_h, 10.0 if mode == "softcore" else 0.0, 100.0)
	v["alerts"] = alerts
	v["state"] = "incapacitated" if float(v["health"]) <= 0.0 else ("critical" if float(v["health"]) < 25.0 or "pressure" in alerts or "low_oxygen" in alerts else ("warning" if not alerts.is_empty() else "ok"))
	_put(id, v)
	Disease.environment_check(actor, region, env, v)
	return v

# ---------- actions ----------
func _act(actor: Variant) -> String:
	if LivingGate.frozen(actor): return ""
	return Tiers.actor_id(actor)

func eat(actor: Variant, kcal: float) -> void:
	var id := _act(actor)
	if id == "": return
	var v := vitals(id); v["calories"] = clampf(float(v["calories"]) + kcal, 0.0, KCAL_MAX); _put(id, v)

## Drink water. treated=false (raw water) can carry the water bug (Disease decides with rng_val).
func drink(actor: Variant, liters: float, treated := true, rng_val := 1.0) -> void:
	var id := _act(actor)
	if id == "": return
	var v := vitals(id); v["hydration"] = clampf(float(v["hydration"]) + liters * 40.0, 0.0, 100.0); _put(id, v)
	if not treated: Disease.expose(actor, "water_bug", str(v.get("region", "")), rng_val, 24.0)

func refill_suit(actor: Variant, hours: float) -> void:
	var id := _act(actor)
	if id == "": return
	var v := vitals(id); v["suit_o2_h"] = clampf(float(v["suit_o2_h"]) + hours, 0.0, 12.0); _put(id, v)

## Rescue / wake at home after being incapacitated. Non-graphic; keeps half reserves.
func recover(actor: Variant) -> Dictionary:
	var id := Tiers.actor_id(actor)
	var v := vitals(id)
	for kk in ["health", "hydration"]: v[kk] = maxf(float(v[kk]), 50.0)
	v["calories"] = maxf(float(v["calories"]), 1000.0); v["o2_sat"] = 98.0; v["co2"] = 0.0; v["core_c"] = 37.0
	v["pressure_ok"] = true; v["state"] = "ok"; v["alerts"] = []
	_put(id, v); return v

func save() -> bool: return SecureFile.write_json(root.path_join("vitals.json"), _v)

func reset_for_tests(p_root: String) -> void:
	root = p_root; _v = {}; _track = {}; _active = {}; _acc = 0.0; set_process(false)
