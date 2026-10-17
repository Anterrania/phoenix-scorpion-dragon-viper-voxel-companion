class_name PerkTree
extends RefCounted
## SBX-22: skill XP + perk system on top of SkillByUse (learn-by-doing skills, already shipped).
## - Skills level by use (SkillByUse). Every 3 skill levels gained grant a perk point (data/sim/perks.json).
## - Perks have a skill level gate, prerequisites and ranks; modifier(key) sums active effects.
## - Unlocking goes through SimGate "play" (Tiers browse) so owner matrix overrides apply to it too.
## - Respec: free for your own tree once per call by the owner (Profile.is_owner()) for anyone.
## No UI here; Foxy's HUD reads points_available()/unlocked.

var skills := SkillByUse.new()
var unlocked := {}        # perk id -> rank
var bonus_points := 0     # quest rewards etc.
var actor: Variant = "self"
var _defs := {}

func _init(p_actor: Variant = "self") -> void:
	actor = p_actor
	var d := SimGate.data("perks")
	_defs = d.get("perks", {})

func defs() -> Dictionary: return _defs
func level() -> int: return skills.character_level()

func spent() -> int:
	var s := 0
	for p in unlocked: s += int(unlocked[p])
	return s

## One perk point per `skill_levels_per_point` skill levels gained across all skills (+ bonus points).
func skill_levels_gained() -> int:
	var t := 0
	for s in skills.skills.values(): t += int(s["level"]) - 1
	return t

func points_total() -> int:
	return skill_levels_gained() / maxi(1, int(SimGate.data("perks").get("skill_levels_per_point", 3))) + bonus_points

func points_available() -> int: return maxi(0, points_total() - spent())

func gain_xp(skill: String, xp: float) -> void: skills.use(skill, xp)

func skill_level(skill: String) -> int: return int(skills.skills.get(skill, {"level": 1})["level"])

## "" if it can be unlocked, else the reason.
func why_not(pid: String) -> String:
	if not _defs.has(pid): return "No such perk."
	var p: Dictionary = _defs[pid]
	if int(unlocked.get(pid, 0)) >= int(p.get("ranks", 1)): return "Already at max rank."
	if skill_level(str(p["skill"])) < int(p["level"]): return "Needs %s %d." % [p["skill"], int(p["level"])]
	for r in p.get("requires", []):
		if not unlocked.has(r): return "Needs perk %s first." % r
	if points_available() <= 0: return "No perk points left."
	if not SimGate.can(actor, "play"): return "Not allowed right now."
	return ""

func unlock(pid: String) -> String:
	var why := why_not(pid)
	if why == "": unlocked[pid] = int(unlocked.get(pid, 0)) + 1
	return why

func modifier(key: String) -> float:
	var t := 0.0
	for pid in unlocked:
		t += float(_defs.get(pid, {}).get("effect", {}).get(key, 0.0)) * int(unlocked[pid])
	return t

## Refund every point. Owner can respec anyone; others only their own tree ("self").
func respec() -> bool:
	if not (SimGate.can(actor, "play") and Tiers.actor_id(actor) == Tiers.actor_id("self")) and not SimGate.can("self", "respec_any"):
		return false
	unlocked.clear()
	return true

func to_dict() -> Dictionary:
	return {"skills": skills.skills.duplicate(true), "unlocked": unlocked.duplicate(), "bonus_points": bonus_points}

func load_dict(d: Dictionary) -> void:
	if d.get("skills") is Dictionary:
		skills.skills = {}
		for k in d["skills"]:   # JSON numbers come back as floats; SkillByUse wants int levels
			var v: Variant = d["skills"][k]
			if v is Dictionary: skills.skills[k] = {"level": int(v.get("level", 1)), "xp": float(v.get("xp", 0.0))}
	if d.get("unlocked") is Dictionary:
		unlocked = {}
		for p in d["unlocked"]:
			if _defs.has(p): unlocked[p] = int(d["unlocked"][p])   # removed perks refund automatically
	bonus_points = int(d.get("bonus_points", 0))
