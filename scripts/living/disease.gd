class_name Disease
extends RefCounted
## LIFE-3: diseases, family-friendly. Data: data/living/diseases.json (symptoms are short labels,
## effects are stat multipliers; nothing graphic).
## - Per person: incubating -> sick -> recovered (+ immunity for immunity_days). Treatments cut the
##   remaining sick time by their efficacy; vaccines give immunity (efficacy roll).
## - Vectors: airborne/contact (contagious, beta per contact-day), water (untreated drinking water),
##   insect (boreal summer bites), environment (Venus acid haze, cosmic radiation, smog, cold).
## - Region spread: sir_step() is a plain SIR model (dS = -beta*S*I/N, dI = beta*S*I/N - gamma*I,
##   dR = gamma*I) used for region outbreak forecasts and NPC crowds; individuals use expose().
## - Exempt: LivingGate.exempt (unlocked owner) never catches anything. Survival "off" regions do not
##   spread disease. E-stop freezes bots (no rolls, no progress).
## Time is game hours. State: user://living/health.json through SecureFile.

const PATH_DATA := "res://data/living/diseases.json"
static var root := "user://living"
static var _db = null
static var _state = null   # id -> {"cases": {disease: {stage, hours_left, incubation_left}}, "immune": {disease: days_left}}

static func db() -> Dictionary:
	if _db == null:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH_DATA))
		_db = d if d is Dictionary else {"diseases": {}, "vaccines": {}, "treatments": {}}
	return _db

static func info(disease: String) -> Dictionary: return db()["diseases"].get(disease, {})

static func _st() -> Dictionary:
	if _state == null:
		var d: Variant = SecureFile.read_json(root.path_join("health.json"), {})
		_state = d if d is Dictionary else {}
	return _state

static func record(id: String) -> Dictionary:
	if not _st().has(id): _st()[id] = {"cases": {}, "immune": {}}
	return _st()[id]

static func save() -> bool: return SecureFile.write_json(root.path_join("health.json"), _st())

static func is_immune(id: String, disease: String) -> bool:
	return float(record(id)["immune"].get(disease, 0.0)) > 0.0

static func cases(id: String) -> Dictionary: return record(id)["cases"].duplicate(true)

static func is_contagious(id: String) -> bool:
	for d in record(id)["cases"]:
		if record(id)["cases"][d]["stage"] == "sick" and bool(info(d).get("contagious", false)): return true
	return false

## Chance of infection for `contact_h` hours of exposure: 1 - exp(-beta * days). Non-contagious
## vectors (water, insect, environment) use beta 0.5 per exposure-day as the base.
static func chance(disease: String, contact_h: float) -> float:
	var i := info(disease)
	var beta := float(i.get("beta", 0.0))
	if beta <= 0.0: beta = 0.5
	return 1.0 - exp(-beta * contact_h / 24.0)

## Try to infect. rng_val in 0..1 (pass randf() in game). Returns true if a new case started.
static func expose(actor: Variant, disease: String, region: String, rng_val: float, contact_h := 1.0) -> bool:
	var i := info(disease)
	if i.is_empty() or LivingGate.exempt(actor) or LivingGate.frozen(actor): return false
	if region != "" and LivingGate.mode(region) == "off": return false
	var id := Tiers.actor_id(actor)
	var realms: Array = i.get("realms", ["*"])
	if region != "" and not "*" in realms and not LivingGate.realm_of(region) in realms: return false
	if is_immune(id, disease) or record(id)["cases"].has(disease): return false
	if rng_val >= chance(disease, contact_h): return false
	record(id)["cases"][disease] = {"stage": "incubating", "incubation_left": float(i["incubation_h"]), "hours_left": float(i["infectious_days"]) * 24.0}
	return true

## Contact between two people (talking, sharing a room). Spreads contagious diseases one way.
static func contact(from_actor: Variant, to_actor: Variant, region: String, hours: float, rng_val: float) -> Array:
	var out: Array = []
	var fid := Tiers.actor_id(from_actor)
	for d in record(fid)["cases"].keys():
		var c: Dictionary = record(fid)["cases"][d]
		if c["stage"] == "sick" and bool(info(d).get("contagious", false)) and expose(to_actor, d, region, rng_val, hours): out.append(d)
	return out

## Environment triggers, called by Survival after each tick (vitals + personal env).
static func environment_check(actor: Variant, region: String, env: Dictionary, v: Dictionary) -> void:
	if LivingGate.exempt(actor) or LivingGate.frozen(actor) or LivingGate.mode(region) == "off": return
	var id := Tiers.actor_id(actor)
	if bool(env.get("acid", false)): _start(id, "ember_lung")
	if float(v.get("radiation_msv", 0)) > 1000.0: _start(id, "void_sickness")
	if float(env.get("pollution", 0)) > 0.3 and float(v.get("fatigue", 0)) > 60.0: _start(id, "smog_cough")
	if float(v.get("core_c", 37)) < 35.5 and LivingGate.realm_of(region).begins_with("alaskan"): _start(id, "frostnip")

static func _start(id: String, disease: String) -> void:
	var i := info(disease)
	if i.is_empty() or record(id)["cases"].has(disease) or is_immune(id, disease): return
	record(id)["cases"][disease] = {"stage": "incubating", "incubation_left": float(i["incubation_h"]), "hours_left": float(i["infectious_days"]) * 24.0}

## Advance one person's illnesses by dt_h game hours.
static func advance(actor: Variant, dt_h: float) -> void:
	if LivingGate.frozen(actor): return
	var r := record(Tiers.actor_id(actor))
	if LivingGate.exempt(actor):
		r["cases"] = {}
		return
	for d in r["immune"].keys():
		r["immune"][d] = float(r["immune"][d]) - dt_h / 24.0
		if float(r["immune"][d]) <= 0.0: r["immune"].erase(d)
	for d in r["cases"].keys():
		var c: Dictionary = r["cases"][d]
		if c["stage"] == "incubating":
			c["incubation_left"] = float(c["incubation_left"]) - dt_h
			if float(c["incubation_left"]) <= 0.0: c["stage"] = "sick"
		elif c["stage"] == "sick":
			c["hours_left"] = float(c["hours_left"]) - dt_h
			if float(c["hours_left"]) <= 0.0: _recover(r, d)

static func _recover(r: Dictionary, d: String) -> void:
	r["cases"].erase(d)
	var days := float(info(d).get("immunity_days", 0))
	if days > 0: r["immune"][d] = days

## Apply a treatment. Returns "" or an error. Cuts remaining sick time by the treatment's efficacy.
static func treat(actor: Variant, disease: String, treatment: String) -> String:
	var r := record(Tiers.actor_id(actor))
	if not r["cases"].has(disease): return "Not sick with that."
	var eff := float(info(disease).get("treatments", {}).get(treatment, 0.0))
	if eff <= 0.0: return "That treatment doesn't help this illness."
	var c: Dictionary = r["cases"][disease]
	if c["stage"] == "incubating": c["stage"] = "sick"
	c["hours_left"] = float(c["hours_left"]) * (1.0 - eff)
	if eff >= 0.8 or float(c["hours_left"]) < 1.0: _recover(r, disease)
	return ""

## Vaccinate. rng_val < efficacy -> immune for the vaccine's days.
static func vaccinate(actor: Variant, vaccine: String, rng_val: float) -> String:
	var vac: Dictionary = db()["vaccines"].get(vaccine, {})
	if vac.is_empty(): return "Unknown vaccine."
	if LivingGate.frozen(actor): return "Paused by the e-stop."
	if rng_val < float(vac["efficacy"]): record(Tiers.actor_id(actor))["immune"][str(vac["protects"])] = float(vac["days"])
	return ""

## Merged stat multipliers of active (sick) cases, read by Survival.
static func effects(id: String) -> Dictionary:
	var out := {}
	if not _st().has(id): return out
	for d in record(id)["cases"]:
		if record(id)["cases"][d]["stage"] != "sick": continue
		var e: Dictionary = info(d).get("effects", {})
		for k in e:
			if k == "health_rate": out[k] = float(out.get(k, 0.0)) + float(e[k])
			else: out[k] = float(out.get(k, 1.0)) * float(e[k])
	return out

static func symptoms(id: String) -> Array:
	var out: Array = []
	for d in record(id)["cases"]:
		if record(id)["cases"][d]["stage"] == "sick":
			for s in info(d).get("symptoms", []):
				if not s in out: out.append(s)
	return out

## Plain SIR step (fractions or counts). Returns [S, I, R].
static func sir_step(s: float, i: float, r: float, beta: float, gamma: float, dt_days: float) -> Array:
	var n := s + i + r
	if n <= 0.0: return [s, i, r]
	var inf := minf(s, beta * s * i / n * dt_days)
	var rec := minf(i + inf, gamma * i * dt_days)
	return [s - inf, i + inf - rec, r + rec]

## Basic reproduction number R0 = beta / gamma (gamma = 1 / infectious days).
static func r0(disease: String) -> float:
	var i := info(disease)
	return float(i.get("beta", 0.0)) * float(i.get("infectious_days", 1.0))

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _state = null
static func reset_cache() -> void: _db = null
