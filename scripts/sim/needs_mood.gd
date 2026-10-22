class_name NeedsMood
extends RefCounted
## INACTIVE FOR DEV (2026-10-22 fold): needs/moods, skills/perks, factions-as-teams and crafting are Foxy-owned
## client features (docs/specs/foxy/). This model was written before the split; it is kept, tested and
## unwired as a reference Foxy may adopt or replace. Nothing in the app calls it. Do not extend it here.
## SBX-SIM-1: needs + mood model for companions and NPCs (life-sim concept, our own numbers).
## Server/system side only: no UI. Implements docs/modules/NEEDS.md.
## - Needs 0..100 decay per in-world minute; activity multipliers (building drains energy faster).
## - Survival needs (warmth) only decay in hostile realms (context "hostile").
## - Mood = weighted need average + short-lived moodlets (e.g. "chatted with a friend" +10 for 60 min).
## - suggest(): utility pick of the most urgent need weighted by personality -> an action verb.
## - Relaxed mode (creative): no decay at all.
## - Bridges: to_life_energy() feeds CompanionLife.energy (0..1); remember() writes a mood change into
##   the companion's EveCore log when the cell accepts it. Nothing here touches Foxy's HUD.
## Saved per companion at user://sim/needs_<id>.json through SecureFile.

const NEEDS := {
	"hunger": {"decay": 0.5, "weight": 1.2, "fix": "eat"},
	"energy": {"decay": 0.33, "weight": 1.3, "fix": "rest"},
	"social": {"decay": 0.25, "weight": 1.0, "fix": "chat"},
	"fun": {"decay": 0.2, "weight": 0.9, "fix": "play"},
	"hygiene": {"decay": 0.1, "weight": 0.6, "fix": "wash"},
	"comfort": {"decay": 0.15, "weight": 0.7, "fix": "sit"},
	"purpose": {"decay": 0.08, "weight": 0.8, "fix": "build"},
	"warmth": {"decay": 1.0, "weight": 1.5, "fix": "shelter", "hostile_only": true},
}
## Activity -> {need: multiplier}. Unlisted needs decay at 1x.
const ACTIVITY := {
	"idle": {},
	"build": {"energy": 2.0, "hunger": 1.5, "purpose": -3.0},   # negative = refills while doing it
	"chat": {"social": -6.0},
	"rest": {"energy": -8.0, "comfort": -2.0},
	"explore": {"fun": -2.0, "energy": 1.3},
	"play": {"fun": -5.0},
}
const MOODS := [[85, "elated"], [65, "happy"], [45, "fine"], [25, "uneasy"], [0, "miserable"]]
const CRITICAL := 15.0

var id := ""
var values := {}
var moodlets: Array = []      # [{id, delta, minutes_left}]
var personality := {}         # need -> weight multiplier, e.g. {"social": 1.5} for an outgoing companion
var relaxed := false
var last_mood := ""

func _init(p_id := "", p_personality := {}) -> void:
	id = p_id
	personality = p_personality
	for n in NEEDS: values[n] = 80.0
	last_mood = mood()

func get_need(n: String) -> float: return float(values.get(n, 0.0))

func satisfy(n: String, amount: float) -> void:
	if values.has(n): values[n] = clampf(get_need(n) + amount, 0.0, 100.0)

## Advance the sim. minutes = in-world minutes since last tick (call on a Timer, not every frame).
func tick(minutes: float, activity := "idle", context := "") -> void:
	if minutes <= 0.0: return
	var mult: Dictionary = ACTIVITY.get(activity, {})
	if not relaxed:
		for n in NEEDS:
			var def: Dictionary = NEEDS[n]
			var m := float(mult.get(n, 1.0))
			if bool(def.get("hostile_only", false)) and context != "hostile":
				if m >= 0.0: m = -2.0   # recovers outside hostile realms
			values[n] = clampf(get_need(n) - float(def["decay"]) * m * minutes, 0.0, 100.0)
	else:
		for n in mult:   # refills still work in relaxed mode
			if float(mult[n]) < 0.0: satisfy(n, -float(mult[n]) * float(NEEDS[n]["decay"]) * minutes)
	for ml in moodlets: ml["minutes_left"] = float(ml["minutes_left"]) - minutes
	moodlets = moodlets.filter(func(ml): return float(ml["minutes_left"]) > 0.0)

func add_moodlet(mid: String, delta: float, minutes: float) -> void:
	for ml in moodlets:
		if ml["id"] == mid:
			ml["minutes_left"] = maxf(float(ml["minutes_left"]), minutes); return   # refresh, don't stack
	moodlets.append({"id": mid, "delta": clampf(delta, -40.0, 40.0), "minutes_left": minutes})

func _weight(n: String) -> float: return float(NEEDS[n]["weight"]) * float(personality.get(n, 1.0))

func mood_score() -> float:
	var tot := 0.0; var w := 0.0
	for n in NEEDS:
		tot += get_need(n) * _weight(n); w += _weight(n)
	var s := tot / maxf(w, 0.001)
	for ml in moodlets: s += float(ml["delta"])
	return clampf(s, 0.0, 100.0)

func mood() -> String:
	var s := mood_score()
	for m in MOODS:
		if s >= m[0]: return m[1]
	return "miserable"

func critical() -> Array:
	return NEEDS.keys().filter(func(n): return get_need(n) < CRITICAL)

## Utility AI: most urgent need (lowest value x weight), -> {need, action, urgency 0..1}.
func suggest() -> Dictionary:
	var best := ""; var best_u := -1.0
	for n in NEEDS:
		var u := (100.0 - get_need(n)) / 100.0 * _weight(n)
		if u > best_u: best_u = u; best = n
	return {"need": best, "action": NEEDS[best]["fix"], "urgency": clampf((100.0 - get_need(best)) / 100.0, 0.0, 1.0)}

## CompanionLife.energy is 0..1.
func to_life_energy() -> float: return get_need("energy") / 100.0

## Mood changed since last call? Log it to the companion's EveCore (returns true if logged).
## Locked cells refuse (cells unlock only for the owner), so last_mood stays and it retries later.
func remember(eve) -> bool:
	var m := mood()
	if m == last_mood or eve == null: return false
	var content := "needs " + JSON.stringify(_rounded())
	var ok := false
	if eve is EveCore: ok = eve._log("Mood: " + m, "Core", "Active", content, "", {"mood": m})
	elif eve.has_method("store_memory"): ok = eve.store_memory("Mood: " + m, "Core", "Active", content)
	if ok: last_mood = m
	return ok

func _rounded() -> Dictionary:
	var r := {}
	for n in values: r[n] = roundi(float(values[n]))
	return r

## Owner-only: reset a companion's needs (admin tool hook).
func reset_needs() -> bool:
	if not SimGate.can("self", "reset_needs"): return false
	for n in NEEDS: values[n] = 80.0
	moodlets.clear()
	return true

func to_dict() -> Dictionary:
	return {"id": id, "values": values.duplicate(), "moodlets": moodlets.duplicate(true), "personality": personality.duplicate(), "relaxed": relaxed}

static func from_dict(d: Dictionary) -> NeedsMood:
	var nm := NeedsMood.new(str(d.get("id", "")), d.get("personality", {}) if d.get("personality") is Dictionary else {})
	var v: Variant = d.get("values", {})
	if v is Dictionary:
		for n in v:
			if NEEDS.has(n): nm.values[n] = clampf(float(v[n]), 0.0, 100.0)   # unknown needs from old saves are ignored
	if d.get("moodlets") is Array: nm.moodlets = d["moodlets"]
	nm.relaxed = bool(d.get("relaxed", false))
	nm.last_mood = nm.mood()
	return nm

func save() -> bool: return SimGate.save_json("needs_" + id, to_dict())
static func load_for(cid: String) -> NeedsMood:
	var d: Variant = SimGate.load_json("needs_" + cid, null)
	return from_dict(d) if d is Dictionary else NeedsMood.new(cid)
