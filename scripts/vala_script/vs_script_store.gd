class_name VsScriptStore
extends RefCounted
## Scripts as inventory items (`.vscript`), with copy / modify / transfer permissions and
## next-owner permissions, like any other item. Saved through SecureFile (encrypted once an
## OwnerVault exists). The owner (unlocked) can always read, edit and copy.
##
## item = {id, name, source, owner, creator, perms: {copy, modify, transfer},
##         next_perms: {copy, modify, transfer}, created, updated}

const EXT := ".vscript"
const MAX_SOURCE := 65536
const MAX_ITEMS := 500
static var root := "user://vala_scripts"
static var _items = null

static func _path() -> String: return root.path_join("scripts.json")

static func items() -> Dictionary:
	if _items == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_items = d if d is Dictionary else {}
	return _items

static func _save() -> bool: return SecureFile.write_json(_path(), items())

static func _perm(p: Variant, k: String, dflt: bool) -> bool:
	return bool(p.get(k, dflt)) if p is Dictionary else dflt

static func _perms(p: Variant) -> Dictionary:
	return {"copy": _perm(p, "copy", true), "modify": _perm(p, "modify", true), "transfer": _perm(p, "transfer", true)}

static func _is_owner_actor(actor: String) -> bool:
	return Tiers.actor_id(actor) == Tiers.OWNER_ID and Tiers.owner_session()

static func file_name(nm: String) -> String:
	var base := nm.strip_edges().to_lower().validate_filename().replace(" ", "_")
	return (base if base != "" else "script") + EXT

## Save a new script for `owner`. Returns {ok, id, error}.
static func create(owner: String, nm: String, src: String, next_perms := {}) -> Dictionary:
	if src.length() > MAX_SOURCE: return {"ok": false, "error": "script too long"}
	if items().size() >= MAX_ITEMS: return {"ok": false, "error": "too many scripts"}
	var oid := Tiers.actor_id(owner)
	var iid := "vs-%d-%d" % [Time.get_ticks_usec(), randi() % 100000]
	var now := int(Time.get_unix_time_from_system())
	items()[iid] = {"id": iid, "name": nm.strip_edges().left(63), "file": file_name(nm), "source": src, "owner": oid, "creator": oid,
		"perms": _perms({}), "next_perms": _perms(next_perms), "created": now, "updated": now}
	return {"ok": _save(), "id": iid, "error": ""}

static func get_item(iid: String) -> Dictionary: return items().get(iid, {})

static func can(actor: String, iid: String, what: String) -> bool:
	var it := get_item(iid)
	if it.is_empty(): return false
	if _is_owner_actor(actor): return true
	if it["owner"] != Tiers.actor_id(actor): return false
	if what == "read": return bool(it["perms"]["modify"])   # no-mod scripts can run but not be read
	return bool(it["perms"].get(what, false))

## Source for the editor, or "" if the actor may not read it.
static func source(actor: String, iid: String) -> String:
	return str(get_item(iid).get("source", "")) if can(actor, iid, "read") else ""

static func edit(actor: String, iid: String, src: String) -> String:
	if not can(actor, iid, "modify"): return "You can't modify this script."
	if src.length() > MAX_SOURCE: return "script too long"
	var it := get_item(iid)
	it["source"] = src; it["updated"] = int(Time.get_unix_time_from_system())
	return "" if _save() else "Saves are sealed. Unlock first."

static func copy(actor: String, iid: String) -> Dictionary:
	if not can(actor, iid, "copy"): return {"ok": false, "error": "no copy permission"}
	var it: Dictionary = get_item(iid).duplicate(true)
	it["id"] = "vs-%d-%d" % [Time.get_ticks_usec(), randi() % 100000]
	items()[it["id"]] = it
	return {"ok": _save(), "id": it["id"], "error": ""}

## Give to someone else. Needs transfer; the new owner gets next-owner perms (never more than now).
## A no-copy script moves; a copy script leaves the giver's item in place and hands over a copy.
static func transfer(actor: String, iid: String, to: String) -> Dictionary:
	if not can(actor, iid, "transfer"): return {"ok": false, "error": "no transfer permission"}
	var it := get_item(iid)
	var keep := bool(it["perms"]["copy"])
	var given: Dictionary = it.duplicate(true) if keep else it
	if keep: given["id"] = "vs-%d-%d" % [Time.get_ticks_usec(), randi() % 100000]
	var np: Dictionary = it["next_perms"]
	for k in ["copy", "modify", "transfer"]: given["perms"][k] = bool(it["perms"][k]) and bool(np[k])
	given["owner"] = Tiers.actor_id(to)
	items()[given["id"]] = given
	return {"ok": _save(), "id": given["id"], "error": ""}

static func remove(actor: String, iid: String) -> bool:
	var it := get_item(iid)
	if it.is_empty() or (it["owner"] != Tiers.actor_id(actor) and not _is_owner_actor(actor)): return false
	items().erase(iid)
	return _save()

static func owned_by(actor: String) -> Array:
	var oid := Tiers.actor_id(actor)
	return items().values().filter(func(it): return it["owner"] == oid)

static func reset_for_tests(p: String) -> void:
	root = p; _items = null
