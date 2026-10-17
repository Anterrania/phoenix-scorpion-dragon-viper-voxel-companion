class_name SaveMigration
extends RefCounted
## One-time migration of plaintext saves to SecureFile encryption, plus encrypted backups.
## Order (never lossy): 1) encrypted backup of ALL of user:// (incl. profile/avatar, settings/music
## prefs, wardrobe, estates...) 2) encrypt each target file: seal -> write tmp -> read back + compare
## -> replace 3) record a manifest in the vault. Any mismatch aborts and leaves the original untouched.
## Targets: companion memory, Eve cores + proposals, tracker/admin, estates.
## Kept plaintext on purpose (needed before unlock for the guest UI; not sensitive): profile.json,
## settings.cfg (music prefs), avatar/wardrobe data. They are inside every encrypted backup.

static var data_root := "user://"
const TARGETS := [
	["eve", ".json"],               # user://eve/<id>.json, proposals.json
	["brains", ".jsonl"],
	["memory", ".json"],            # user://memory/<id>.json (AgentBrain chat memory)           # user://brains/<id>/memory/facts.jsonl, episodes.jsonl
	["viper", ".json"], ["viper", ".jsonl"],   # tracker, wiki, signup, revisions
	["", "estate.cfg"],
]
const SKIP_DIRS := ["backups", "logs", "shader_cache", "vulkan", ".godot"]

static func _walk(dir: String, out: Array) -> void:
	if not DirAccess.dir_exists_absolute(dir): return
	for d in DirAccess.get_directories_at(dir):
		if d in SKIP_DIRS: continue
		_walk(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".tmp"): out.append(dir.path_join(f))

static func _rel(p: String) -> String: return p.trim_prefix(data_root).trim_prefix("/")

static func target_files() -> Array:
	var all: Array = []
	_walk(data_root, all)
	var out: Array = []
	for p in all:
		var rel := _rel(p)
		for t in TARGETS:
			if t[0] == "" and rel == t[1]: out.append(p)
			elif t[0] != "" and rel.begins_with(t[0] + "/") and rel.ends_with(t[1]): out.append(p)
	return out

## Sealed archive of every file under data_root (except backups/caches). Returns the path or "".
static func backup(label := "manual") -> String:
	if not OwnerVault.storage_ready(): return ""
	var files: Array = []
	_walk(data_root, files)
	var arc := {"format": "phoenix-backup/1", "created": Time.get_datetime_string_from_system(), "label": label, "files": {}}
	for p in files:
		if p.get_file() == "vault.json": continue   # vault is needed to open the backup; keep it separate
		arc["files"][_rel(p)] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(p))
	var dir := data_root.path_join("backups")
	DirAccess.make_dir_recursive_absolute(dir)
	var out := dir.path_join("%s_%s.pxb" % [label, Time.get_datetime_string_from_system().replace(":", "-")])
	var k := OwnerVault.dek()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_buffer(CryptoBox.seal(k["enc"], k["mac"], JSON.stringify(arc).to_utf8_buffer()))
	f.close()
	return out if not read_backup(out).is_empty() else ""

static func read_backup(path: String) -> Dictionary:
	if not OwnerVault.storage_ready() or not FileAccess.file_exists(path): return {}
	var k := OwnerVault.dek()
	var st := {}
	var p := CryptoBox.open(k["enc"], k["mac"], FileAccess.get_file_as_bytes(path), st)
	if not st["ok"]: return {}
	var d: Variant = JSON.parse_string(p.get_string_from_utf8())
	return d if d is Dictionary else {}

## Owner only: write every file of a backup back (raw bytes, as they were when backed up).
static func restore(path: String) -> int:
	if not OwnerVault.is_unlocked(): return -1
	var arc := read_backup(path)
	if arc.is_empty(): return -1
	var n := 0
	for rel in arc["files"]:
		if ".." in str(rel): continue
		var dst := data_root.path_join(rel)
		DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		var f := FileAccess.open(dst, FileAccess.WRITE)
		if f: f.store_buffer(Marshalls.base64_to_raw(arc["files"][rel])); n += 1
	return n

## Returns {ok, backup, migrated: [rel], skipped: [rel], errors: [..]}
static func migrate() -> Dictionary:
	var rep := {"ok": false, "backup": "", "migrated": [], "skipped": [], "errors": []}
	if not OwnerVault.storage_ready(): rep["errors"].append("storage key not loaded"); return rep
	rep["backup"] = backup("pre_encrypt")
	if rep["backup"] == "": rep["errors"].append("backup failed"); return rep
	for p in target_files():
		var raw := FileAccess.get_file_as_bytes(p)
		if CryptoBox.is_sealed(raw): rep["skipped"].append(_rel(p)); continue
		var text := raw.get_string_from_utf8()
		if not SecureFile.write_text(p, text): rep["errors"].append("write " + _rel(p)); continue
		if SecureFile.read_text(p) != text:
			var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(raw)   # put original back
			rep["errors"].append("verify " + _rel(p)); continue
		rep["migrated"].append(_rel(p))
	rep["ok"] = rep["errors"].is_empty()
	var v := OwnerVault.vault()
	v["migration"] = {"at": Time.get_datetime_string_from_system(), "backup": _rel(rep["backup"]), "files": rep["migrated"].size(), "ok": rep["ok"]}
	OwnerVault._save_vault()
	return rep
