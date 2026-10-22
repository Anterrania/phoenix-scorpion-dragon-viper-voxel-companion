class_name InventoryMigration
extends RefCounted
## SBX-4: bring your own inventory over from an OpenSim-family grid (the "grid closed, move my
## stuff" case). Reads a JSON inventory manifest (from an IAR-style listing or a grid's export
## tool), maps item types onto Viper kinds and carries copy / modify / transfer over. Our own code.
##
## Manifest: {"grid": "name", "items": [{"name", "type", "folder", "creator", "asset_id",
##   "perms": {"owner": mask, "next_owner": mask} | "perms": "CMT" | {"copy": b, "modify": b, "transfer": b},
##   "export": bool (optional, set by the origin marketplace)}]}
## Permission masks use the OpenSim/SL bit values: transfer 0x2000, modify 0x4000, copy 0x8000.
## Carry-over is conservative: what you may do = owner mask; what the next owner gets = owner mask
## AND next-owner mask. Nothing is ever widened.
## An item migrates only if you made it, or it is full-perm for you (copy + transfer), or the origin
## market marked it exportable. Others are skipped with a reason (creator rights stay protected).
## Scripts are kept as text but marked "needs_port" (no LSL runs here; SECOND_LIFE_SCRIPTING.md).
## Personal data: owner names are dropped; creators are kept only as ids for credit.
## Gates: your own inventory = SandboxGate "import" (Tiers "upload", creator+). Migrating for
## someone else = owner only ("migrate_for").

const PERM_TRANSFER := 0x2000
const PERM_MODIFY := 0x4000
const PERM_COPY := 0x8000
const TYPE_MAP := {
	"object": "object", "clothing": "clothing", "bodypart": "body_part", "body_part": "body_part",
	"texture": "texture", "snapshot": "texture", "sound": "sound", "animation": "animation",
	"gesture": "gesture", "notecard": "notecard", "script": "script", "lsltext": "script",
	"landmark": "landmark", "mesh": "object", "material": "material",
}
const SKIP_TYPES := {"callingcard": "calling cards hold people, not items", "link": "links point at items on the old grid"}
const MAX_ITEMS := 5000

static var _store = null

static func _all() -> Dictionary:
	if _store == null:
		var d: Variant = SandboxGate.load_json("migrated", {})
		_store = d if d is Dictionary else {}
	return _store

static func perms_from(p: Variant) -> Dictionary:
	if p is String:
		var s := (p as String).to_upper()
		var full := {"copy": s.contains("C"), "modify": s.contains("M"), "transfer": s.contains("T")}
		return {"owner": full, "next_owner": full.duplicate()}
	if p is Dictionary and p.has("owner"):
		var o := int(p.get("owner", 0))
		var n := o & int(p.get("next_owner", o))
		return {"owner": _bits(o), "next_owner": _bits(n)}
	if p is Dictionary:
		var f := {"copy": bool(p.get("copy", false)), "modify": bool(p.get("modify", false)), "transfer": bool(p.get("transfer", false))}
		return {"owner": f, "next_owner": f.duplicate()}
	return {"owner": _bits(0), "next_owner": _bits(0)}

static func _bits(m: int) -> Dictionary:
	return {"copy": (m & PERM_COPY) != 0, "modify": (m & PERM_MODIFY) != 0, "transfer": (m & PERM_TRANSFER) != 0}

static func may_migrate(it: Dictionary, importer: String, perms: Dictionary) -> String:
	if str(it.get("creator", "")) == importer: return ""
	if bool(it.get("export", false)): return ""
	if perms["owner"]["copy"] and perms["owner"]["transfer"]: return ""
	return "not yours and not full-perm (needs copy + transfer or an export flag)"

## Dry run or real import. Returns {"imported": [...], "skipped": [{name, reason}], "grid": ...} or {"error"}.
## creator_map turns old-grid creator names into Viper ids (unknown creators become "grid:<hash>").
static func migrate(actor: Variant, manifest: Dictionary, importer: String = "", creator_map := {}, dry_run := false) -> Dictionary:
	var me := SandboxGate.id_of(actor)
	var who := importer if importer != "" else me
	if who == me:
		if not SandboxGate.can(actor, "import"): return {"error": "Inventory import needs Creator tier or higher."}
	elif not SandboxGate.can(actor, "migrate_for"): return {"error": "Only the owner can migrate for someone else."}
	var items: Array = manifest.get("items", [])
	if items.size() > MAX_ITEMS: return {"error": "Too many items (max %d per batch)." % MAX_ITEMS}
	var grid := str(manifest.get("grid", "unknown")).left(64)
	var old_name := str(manifest.get("avatar", ""))   # the importer's name on the old grid (counts as "you")
	var done: Array = []
	var skipped: Array = []
	for it in items:
		if not (it is Dictionary): continue
		var nm := str(it.get("name", "item")).left(120)
		var t := str(it.get("type", "")).to_lower()
		if SKIP_TYPES.has(t): skipped.append({"name": nm, "reason": SKIP_TYPES[t]}); continue
		if not TYPE_MAP.has(t): skipped.append({"name": nm, "reason": "unknown type " + t}); continue
		var p := perms_from(it.get("perms", 0))
		var creator_old := str(it.get("creator", ""))
		var creator := str(creator_map.get(creator_old, who if (creator_old == old_name and old_name != "") else "grid:" + creator_old.sha256_text().left(12)))
		var why := may_migrate({"creator": creator, "export": it.get("export", false)}, who, p)
		if why != "": skipped.append({"name": nm, "reason": why}); continue
		var row := {"id": "mig_%s" % (grid + "/" + str(it.get("asset_id", nm)) + "/" + str(it.get("folder", ""))).sha256_text().left(16),
			"name": nm, "kind": TYPE_MAP[t], "folder": "Imported/%s/%s" % [grid, str(it.get("folder", "")).left(120)],
			"creator_id": creator, "permissions": p["owner"], "next_owner": p["next_owner"],
			"export": bool(it.get("export", false)), "origin_grid": grid, "asset_ref": str(it.get("asset_id", ""))}
		if row["kind"] == "script": row["needs_port"] = true
		done.append(row)
	if not dry_run and not done.is_empty():
		var mine: Array = _all().get(who, [])
		var have := {}
		for r in mine: have[r["id"]] = true
		for r in done:
			if not have.has(r["id"]): mine.append(r)   # re-running a migration never duplicates
		_all()[who] = mine
		if not SandboxGate.save_json("migrated", _all()): return {"error": "Saves are sealed. Unlock first."}
	return {"imported": done, "skipped": skipped, "grid": grid, "dry_run": dry_run}

static func items_of(member: String) -> Array: return _all().get(member, [])

static func reset_for_tests() -> void: _store = null
