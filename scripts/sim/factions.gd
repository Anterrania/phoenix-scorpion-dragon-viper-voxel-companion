class_name Factions
extends RefCounted
## SBX-23: faction membership + reputation (RPG faction / open-world gang-territory concept, own rules).
## - Reputation per actor per faction, -1000..1000, ranks from hostile to exalted.
## - Gains spill over to allies (+50%) and rivals (-50%); exclusive factions block double membership.
## - Join: SimGate "join_faction" (Tiers group_join, residents+) and rank >= neutral.
## - Player-made factions: "create_faction" (Tiers group_create, creator tier+). Optional link to a
##   Social group id so land/roles reuse the group system instead of a second one.
## - Owner override: set_reputation() needs Profile.is_owner().
## - Territory: claim(region) records which faction holds a region; the estate still decides who may
##   build there (Tiers land rules), a claim is a label + reputation multiplier only.
## Saved at user://sim/factions.json through SecureFile.

const MIN_REP := -1000
const MAX_REP := 1000
const RANKS := [[750, "exalted"], [300, "honored"], [100, "friendly"], [-99, "neutral"], [-499, "unfriendly"], [-1000, "hostile"]]
const SPILL := {"ally": 0.5, "rival": -0.5}

var defs := {}
var rep := {}          # actor_id -> {faction: int}
var members := {}      # faction -> [actor_id]
var territory := {}    # region -> faction

func _init() -> void:
	defs = SimGate.data("factions").get("factions", {}).duplicate(true)

static func rank_for(value: int) -> String:
	for r in RANKS:
		if value >= r[0]: return r[1]
	return "hostile"

func get_rep(actor: Variant, f: String) -> int:
	return int(rep.get(Tiers.actor_id(actor), {}).get(f, 0))

func rank(actor: Variant, f: String) -> String: return rank_for(get_rep(actor, f))

func _put_rep(id: String, f: String, v: int) -> void:
	if not rep.has(id): rep[id] = {}
	rep[id][f] = clampi(v, MIN_REP, MAX_REP)

## System gain (quests, kills, trades). Returns the applied delta on the main faction.
func change(actor: Variant, f: String, delta: int, multiplier := 1.0) -> int:
	if not defs.has(f): return 0
	var id := Tiers.actor_id(actor)
	var d := roundi(delta * multiplier)
	_put_rep(id, f, get_rep(actor, f) + d)
	var rel: Dictionary = defs[f].get("relations", {})
	for other in rel:
		if defs.has(other) and SPILL.has(rel[other]):
			_put_rep(id, other, get_rep(actor, other) + roundi(d * float(SPILL[rel[other]])))
	return d

func is_member(actor: Variant, f: String) -> bool: return Tiers.actor_id(actor) in members.get(f, [])

func join(actor: Variant, f: String) -> String:
	if not defs.has(f): return "No such faction."
	if not SimGate.can(actor, "join_faction"): return "Your tier can't join factions."
	if rank_for(get_rep(actor, f)) in ["unfriendly", "hostile"]: return "They don't trust you yet."
	for x in defs[f].get("exclusive_with", []):
		if is_member(actor, x): return "Leave %s first." % defs.get(x, {}).get("name", x)
	var id := Tiers.actor_id(actor)
	if not members.has(f): members[f] = []
	if not id in members[f]: members[f].append(id)
	return ""

func leave(actor: Variant, f: String) -> void:
	if members.has(f): members[f].erase(Tiers.actor_id(actor))

func create(actor: Variant, fid: String, fname: String, social_group := "") -> String:
	if fid == "" or defs.has(fid): return "Pick a new faction id."
	if not SimGate.can(actor, "create_faction"): return "Creator tier needed to found a faction."
	defs[fid] = {"name": fname, "realm": "", "relations": {}, "exclusive_with": [], "founder": Tiers.actor_id(actor), "group": social_group}
	members[fid] = [Tiers.actor_id(actor)]
	_put_rep(Tiers.actor_id(actor), fid, 300)
	return ""

## Owner tool: set any reputation directly.
func set_reputation(actor: Variant, f: String, v: int) -> bool:
	if not SimGate.can("self", "set_reputation") or not defs.has(f): return false
	_put_rep(Tiers.actor_id(actor), f, v)
	return true

## Territory label. Only an estate manager / owner for that region may assign it.
func claim(actor: Variant, region: String, f: String) -> String:
	if not defs.has(f): return "No such faction."
	if not SimGate.can(actor, "manage_region", region): return "Estate manager needed."
	territory[region] = f
	return ""

## Rep multiplier for actions inside a region: +25% on your own faction's turf.
func turf_bonus(actor: Variant, region: String) -> float:
	var f := str(territory.get(region, ""))
	return 1.25 if f != "" and is_member(actor, f) else 1.0

func to_dict() -> Dictionary:
	var custom := {}
	for f in defs:
		if defs[f].has("founder"): custom[f] = defs[f]
	return {"rep": rep.duplicate(true), "members": members.duplicate(true), "territory": territory.duplicate(), "custom": custom}

func load_dict(d: Dictionary) -> void:
	if d.get("custom") is Dictionary: defs.merge(d["custom"])
	for k in ["rep", "members", "territory"]:
		if d.get(k) is Dictionary: set(k, d[k])
	for id in rep:
		for f in rep[id]: rep[id][f] = int(rep[id][f])

func save() -> bool: return SimGate.save_json("factions", to_dict())
static func load_saved() -> Factions:
	var fx := Factions.new()
	var d: Variant = SimGate.load_json("factions", null)
	if d is Dictionary: fx.load_dict(d)
	return fx
