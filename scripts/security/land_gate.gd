class_name LandGate
extends RefCounted
## Estate rules applied to movement, combat and companion tools (audit 2026-10-17, AUDIT-3/4).
## - Flying: Estate "allow_fly" for the parcel under you (parcel overrides region). The owner and
##   estate managers can always fly, like Second Life estate owners.
## - Damage: Estate "allow_damage" when the parcel or region sets it explicitly; otherwise the
##   built-in combat zones (CombatZone arenas) decide. So the owner can switch the Ember Arena off or
##   turn damage on anywhere from the Region/Estate panel.
## - Companion tools that change the world go through Tiers.can(companion_id, "build"|"land", parcel).

const TOOL_ACTIONS := {"place_voxel": "build", "carve_area": "build", "spawn_structure": "build", "build_realm": "land"}

static func target_at(pos: Vector3) -> Dictionary:
	return {"region": MapData.region_name(pos), "parcel": Estate.parcel_id(pos)}

## Explicit parcel or region value, or null if neither section sets the key.
static func explicit(pos: Vector3, key: String) -> Variant:
	var t := target_at(pos)
	var c := Estate.cfg()
	var ps := "parcel:%s/%s" % [t["region"], t["parcel"]]
	if c.has_section_key(ps, key): return c.get_value(ps, key)
	if c.has_section_key("region:" + t["region"], key): return c.get_value("region:" + t["region"], key)
	return null

static func can_fly(actor: Variant, pos: Vector3) -> bool:
	# HEAVEN-2: Heaven airspace has its own rule (owner + owner-granted members only; no rank bypass)
	if HeavenLayout.contains(pos): return HeavenAccess.can_fly(actor)
	if Tiers.rank(Tiers.tier_of(actor)) >= Tiers.rank("estate_manager"): return true
	var t := target_at(pos)
	return bool(Estate.parcel_get(t["region"], t["parcel"], "allow_fly"))

static func damage_enabled(pos: Vector3) -> bool:
	var e: Variant = explicit(pos, "allow_damage")
	if e != null: return bool(e)
	return CombatZone.in_arena(pos)

## "" when the tool may run, else a short reason. Tools that don't change the world always pass.
## The target is the tool's own x/z when given (where the voxels change), else the companion.
static func companion_tool_error(id: String, tool: String, args: Dictionary, at := Vector3.ZERO) -> String:
	if not TOOL_ACTIONS.has(tool): return ""
	var action: String = TOOL_ACTIONS[tool]
	var pos := at
	if args.has("x") and args.has("z"):
		# pos = Vector3(float(args["x"]), float(args.get("y", 0.0)), float(args["z"]))   # pre-HEAVEN
		pos = Vector3(float(args["x"]), float(args.get("y", at.y)), float(args["z"]))
	# HEAVEN-4: voxel studio tools in Heaven need the owner's studio grant for that companion
	if HeavenLayout.contains(pos) and not HeavenAccess.can_studio(id):
		return "heaven: %s needs the owner's studio grant to change Heaven terrain (use heaven_edit to propose)" % id
	var t := target_at(pos)
	var target: Variant = t if action == "build" else t["region"]
	if Tiers.can(id, action, target): return ""
	return "land: %s may not %s in %s" % [id, "build" if action == "build" else "reshape the region", t["region"]]
