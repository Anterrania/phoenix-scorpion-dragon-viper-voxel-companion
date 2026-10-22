class_name Crafting
extends RefCounted
## INACTIVE FOR DEV (2026-10-22 fold): needs/moods, skills/perks, factions-as-teams and crafting are Foxy-owned
## client features (docs/specs/foxy/). This model was written before the split; it is kept, tested and
## unwired as a reference Foxy may adopt or replace. Nothing in the app calls it. Do not extend it here.
## SBX-SIM-4: crafting + infusion (enchanting concept) tied to voxel materials.
## - Recipes (data/sim/recipes.json) take voxel materials ("voxel:<palette id>") and crafted
##   items, need a station (hands / workbench / forge / infuser) and a skill level, give SkillByUse
##   XP through a PerkTree. Perk "tinkerer" adds a bonus-output chance, "infuser" boosts infusions.
## - Crafting is a build action: SimGate "craft" -> Tiers.can(actor, "build", parcel). With a
##   parcel the estate rules apply (allow_build, access, bans); without one it's a tier check only.
## - Infusions add a named effect + power to one crafted item instance (one infusion per item).
## - inventory is a plain Dictionary {item_or_voxel_id: count} owned by the caller (Inventory /
##   satchel / server). Nothing is consumed unless the craft succeeds.
## - rng_val is passed in for deterministic tests; pass randf() in game.

var defs := {}
var perks: PerkTree
var actor: Variant = "self"

func _init(p_actor: Variant = "self", p_perks: PerkTree = null) -> void:
	actor = p_actor; perks = p_perks
	defs = SimGate.data("recipes")

func recipes() -> Dictionary: return defs.get("recipes", {})
func material_name(id: String) -> String: return str(defs.get("materials", {}).get(id, id))

static func has_all(inv: Dictionary, need: Dictionary, times := 1) -> bool:
	for k in need:
		if int(inv.get(k, 0)) < int(need[k]) * times: return false
	return true

static func _take(inv: Dictionary, need: Dictionary, times := 1) -> void:
	for k in need:
		inv[k] = int(inv.get(k, 0)) - int(need[k]) * times
		if int(inv[k]) <= 0: inv.erase(k)

## What can be made right now with this inventory at this station.
func available(inv: Dictionary, station := "") -> Array:
	return recipes().keys().filter(func(r): return why_not(r, inv, station) == "")

func why_not(rid: String, inv: Dictionary, station := "", parcel: Variant = null, times := 1) -> String:
	var r: Dictionary = recipes().get(rid, {})
	if r.is_empty(): return "No such recipe."
	if str(r.get("station", "")) != "" and str(r["station"]) != station: return "Needs a %s." % r["station"]
	var lvl := perks.skill_level(str(r.get("skill", "crafting"))) if perks else 1
	if lvl < int(r.get("level", 1)): return "Needs %s %d." % [r.get("skill", "crafting"), int(r["level"])]
	if not has_all(inv, r.get("inputs", {}), times): return "Missing materials."
	if not SimGate.can(actor, "craft", parcel): return "You can't craft here."
	return ""

## Craft `times` batches. Returns {"error": ""|reason, "made": {id: n}}.
func craft(rid: String, inv: Dictionary, station := "", parcel: Variant = null, times := 1, rng_val := 1.0) -> Dictionary:
	times = maxi(1, times)
	var why := why_not(rid, inv, station, parcel, times)
	if why != "": return {"error": why, "made": {}}
	var r: Dictionary = recipes()[rid]
	_take(inv, r.get("inputs", {}), times)
	var made := {}
	var bonus := perks.modifier("craft_bonus_chance") if perks else 0.0
	for k in r.get("output", {}):
		var n := int(r["output"][k]) * times
		if rng_val < bonus: n += 1   # one bonus item per craft call
		inv[k] = int(inv.get(k, 0)) + n
		made[k] = n
	if perks: perks.gain_xp(str(r.get("skill", "crafting")), float(r.get("xp", 1)) * times)
	return {"error": "", "made": made}

## Infuse one item instance (a Dictionary like {"id": "obsidian_blade"}) at an infuser station.
func infuse(item: Dictionary, iid: String, inv: Dictionary, station := "", parcel: Variant = null) -> String:
	var inf: Dictionary = defs.get("infusions", {}).get(iid, {})
	if inf.is_empty(): return "No such infusion."
	if station != "infuser": return "Needs an infuser."
	if not str(item.get("id", "")) in inf.get("applies_to", []): return "That item can't take this infusion."
	if item.has("infusion"): return "Already infused."
	if perks and perks.skill_level("crafting") < int(inf.get("level", 1)): return "Needs crafting %d." % int(inf["level"])
	if not has_all(inv, inf.get("inputs", {})): return "Missing materials."
	if not SimGate.can(actor, "craft", parcel): return "You can't craft here."
	_take(inv, inf.get("inputs", {}))
	var power := float(inf.get("power", 1)) * (1.0 + (perks.modifier("infuse_power") if perks else 0.0))
	item["infusion"] = {"id": iid, "power": snappedf(power, 0.01)}
	if perks: perks.gain_xp("crafting", float(inf.get("power", 1)))
	return ""
