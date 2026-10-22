class_name InteropImport
extends RefCounted
## Import status + storage for OAR/IAR imports (Admin > Interop, docs/modules/INTEROP.md).
## Gates (Tiers):
## - inspect (read-only preview): anyone who can "browse".
## - import (store terrain / notecards on this phone): "upload" (Premium/Creator and up, or the
##   unlocked owner). Locked owner = guest, so a locked phone can't import.
## - clear the import log: unlocked owner only ("admin").
## Applying an imported heightmap to a live region is NOT built yet (Planned: needs the voxel
## generator hook + "land" permission on the region).
## Files (SecureFile, encrypted once an OwnerVault exists):
##   <root>/imports.json                 log, newest first, max 100
##   <root>/terrain/<id>.json            Viper heightmap (OpenSimArchive.to_viper_heightmap)
##   <root>/notecards/<id>.json          {name: text} from an IAR
## Archives larger than MAX_ARCHIVE bytes are refused before reading.

const MAX_ARCHIVE := 64 * 1024 * 1024
const MAX_LOG := 100
static var root := "user://interop"
static var _log = null

static func log_entries() -> Array:
	if _log == null:
		var d: Variant = SecureFile.read_json(root.path_join("imports.json"), [])
		_log = d if d is Array else []
	return _log

static func reload_data() -> void: _log = null

static func _append(row: Dictionary) -> void:
	log_entries().push_front(row)
	while _log.size() > MAX_LOG: _log.pop_back()
	SecureFile.write_json(root.path_join("imports.json"), _log)

static func status() -> Dictionary:
	var n := {"oar": 0, "iar": 0, "failed": 0}
	for r in log_entries():
		if not r.get("ok", false): n["failed"] += 1
		elif r.get("kind") in n: n[r["kind"]] += 1
	return {"imports": log_entries().size(), "oar": n["oar"], "iar": n["iar"], "failed": n["failed"],
		"last": log_entries()[0] if not log_entries().is_empty() else {}}

static func _id() -> String: return "imp%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec() % 100000]

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "error": "File not found."}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {"ok": false, "error": "Can't open file."}
	if f.get_length() > MAX_ARCHIVE: return {"ok": false, "error": "Archive is over %d MB." % (MAX_ARCHIVE >> 20)}
	return {"ok": true, "bytes": f.get_buffer(f.get_length())}

static func kind_of(path: String) -> String:
	var e := path.get_extension().to_lower()
	if e in ["oar", "iar"]: return e
	if path.to_lower().ends_with(".tar.gz") or e == "tgz": return "oar"
	return ""

## Read-only preview (no files written). {ok, error, kind, ...OpenSimArchive summary}
static func inspect(path: String, actor: Variant = "self") -> Dictionary:
	if not Tiers.can(actor, "browse"): return {"ok": false, "error": "Not allowed."}
	var k := kind_of(path)
	if k == "": return {"ok": false, "error": "Pick an .oar or .iar file."}
	var r := _read(path)
	if not r["ok"]: return r
	return OpenSimArchive.inspect_oar(r["bytes"]) if k == "oar" else OpenSimArchive.inspect_iar(r["bytes"])

## Import an OAR (terrain heightmap) or IAR (notecard texts). Returns the log row.
static func import_file(path: String, actor: Variant = "self", target := 64) -> Dictionary:
	var row := {"id": _id(), "file": path.get_file().left(120), "t": int(Time.get_unix_time_from_system()), "ok": false,
		"kind": kind_of(path), "by": Tiers.actor_id(actor)}
	if not Tiers.can(actor, "upload"):
		row["error"] = "Importing needs Premium/Creator or the owner unlock."
		return row   # refused attempts are not logged (nothing changed)
	if row["kind"] == "":
		row["error"] = "Pick an .oar or .iar file."
	else:
		var r := _read(path)
		if not r["ok"]: row["error"] = r["error"]
		elif row["kind"] == "oar": _import_oar(r["bytes"], row, target)
		else: _import_iar(r["bytes"], row)
	_append(row)
	return row

static func _import_oar(bytes: PackedByteArray, row: Dictionary, target: int) -> void:
	var sum := OpenSimArchive.inspect_oar(bytes)
	if not sum["ok"]: row["error"] = sum["error"]; return
	var t := OpenSimArchive.oar_terrain(bytes)
	row["summary"] = {"version": sum["version"], "region_size": sum["region_size"], "objects": sum["objects"],
		"assets": sum["assets"], "parcels": sum["parcels"].size(), "settings": sum["settings"]}
	if not t["ok"]: row["error"] = t["error"]; return
	var hm := OpenSimArchive.to_viper_heightmap(t["terrain"], target)
	hm["source"] = row["file"]; hm["region"] = t["name"]
	var out := root.path_join("terrain/%s.json" % row["id"])
	if not SecureFile.write_json(out, hm): row["error"] = "Saves are sealed. Unlock first."; return
	row["ok"] = true
	row["terrain"] = {"region": t["name"], "src_size": t["terrain"]["size"], "size": hm["size"],
		"min": snappedf(t["terrain"]["min"], 0.01), "max": snappedf(t["terrain"]["max"], 0.01), "file": out}
	row["note"] = "Heightmap stored. Applying it to a region is Planned. Prims were not converted."

static func _import_iar(bytes: PackedByteArray, row: Dictionary) -> void:
	var sum := OpenSimArchive.inspect_iar(bytes)
	if not sum["ok"]: row["error"] = sum["error"]; return
	var kinds := {}
	for it in sum["items"]: kinds[it["type"]] = int(kinds.get(it["type"], 0)) + 1
	row["summary"] = {"items": sum["items"].size(), "types": kinds, "textures_need_conversion":
		sum["textures"].filter(func(x): return not x["convertible"]).size()}
	var out := root.path_join("notecards/%s.json" % row["id"])
	if not SecureFile.write_json(out, sum["notecards"]): row["error"] = "Saves are sealed. Unlock first."; return
	row["ok"] = true
	row["notecards"] = {"count": sum["notecards"].size(), "file": out}
	row["note"] = "Notecard text stored. Textures, objects and scripts are listed only (Planned)."

static func load_terrain(row: Dictionary) -> Dictionary:
	var f := str(row.get("terrain", {}).get("file", ""))
	var d: Variant = SecureFile.read_json(f, {}) if f.begins_with(root) else {}
	return d if d is Dictionary else {}

static func load_notecards(row: Dictionary) -> Dictionary:
	var f := str(row.get("notecards", {}).get("file", ""))
	var d: Variant = SecureFile.read_json(f, {}) if f.begins_with(root) else {}
	return d if d is Dictionary else {}

## Owner only. Clears the log (stored heightmaps/notecards stay on disk; revisions are never deleted).
static func clear_log(actor: Variant = "self") -> bool:
	if not Tiers.can(actor, "admin"): return false
	_log = []
	return SecureFile.write_json(root.path_join("imports.json"), _log)

static func reset_for_tests(p: String) -> void:
	root = p; _log = null
