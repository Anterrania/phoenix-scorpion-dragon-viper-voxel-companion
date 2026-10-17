class_name SecureFile
extends RefCounted
## Read/write a user:// save, encrypted when an OwnerVault exists.
## - No vault yet: plaintext (exactly as before), so guests and old installs behave the same.
## - Vault + storage key loaded: CryptoBox sealed bytes ("PXE1..."), written via tmp file + rename.
## - Vault but key NOT loaded (app started, owner hasn't unlocked): reads of sealed files return
##   "" (locked); writes to a path that already holds sealed data are REFUSED (never clobber what we
##   couldn't read); writes to new paths are held in memory and flushed encrypted on unlock.
## - Plaintext files are still readable (migration window). A bad MAC never returns data: the file
##   is copied once to <path>.tampered for inspection.

static var refused_writes := 0
static var _pending := {}    # path -> text (new files written while locked)
static var _hooked := false

static func _hook() -> void:
	if _hooked: return
	_hooked = true
	OwnerVault.on_storage_ready.append(flush_pending)

static func encrypted_mode() -> bool: return OwnerVault.has_vault()

static func is_sealed_file(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var f := FileAccess.open(path, FileAccess.READ)
	return f != null and f.get_length() >= 4 and f.get_buffer(4).get_string_from_ascii() == CryptoBox.MAGIC

static func exists(path: String) -> bool: return _pending.has(path) or FileAccess.file_exists(path)

## "" when missing or locked. status: {locked: bool, tampered: bool}
static func read_text(path: String, status := {}) -> String:
	status["locked"] = false; status["tampered"] = false
	if _pending.has(path): return _pending[path]
	if not FileAccess.file_exists(path): return ""
	var raw := FileAccess.get_file_as_bytes(path)
	if not CryptoBox.is_sealed(raw): return raw.get_string_from_utf8()
	if not OwnerVault.storage_ready():
		status["locked"] = true
		return ""
	var k := OwnerVault.dek()
	var st := {}
	var p := CryptoBox.open(k["enc"], k["mac"], raw, st)
	if not st["ok"]:
		status["tampered"] = true
		if not FileAccess.file_exists(path + ".tampered"): DirAccess.copy_absolute(path, path + ".tampered")
		push_error("SecureFile: integrity check failed for " + path)
		return ""
	return p.get_string_from_utf8()

static func read_json(path: String, fallback: Variant = null) -> Variant:
	var t := read_text(path)
	if t == "": return fallback
	var d: Variant = JSON.parse_string(t)
	return d if d != null else fallback

## Returns false if the write was refused (locked + existing sealed data, or tampered file).
static func write_text(path: String, text: String) -> bool:
	_hook()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if not encrypted_mode():
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null: return false
		f.store_string(text)
		return true
	if not OwnerVault.storage_ready():
		if is_sealed_file(path):
			refused_writes += 1
			return false
		_pending[path] = text
		return true
	if FileAccess.file_exists(path + ".tampered") and is_sealed_file(path):
		var st := {}
		read_text(path, st)
		if st["tampered"]: refused_writes += 1; return false
	var k := OwnerVault.dek()
	var tmp := path + ".tmp"
	var w := FileAccess.open(tmp, FileAccess.WRITE)
	if w == null: return false
	w.store_buffer(CryptoBox.seal(k["enc"], k["mac"], text.to_utf8_buffer()))
	w.close()
	DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK

static func write_json(path: String, data: Variant, indent := "") -> bool:
	return write_text(path, JSON.stringify(data, indent))

static func flush_pending() -> void:
	var p := _pending.duplicate()
	_pending.clear()
	for path in p: write_text(path, p[path])

static func reset_for_tests() -> void:
	_pending.clear(); refused_writes = 0
