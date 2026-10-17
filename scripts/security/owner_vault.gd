class_name OwnerVault
extends RefCounted
## Owner login + storage key.
## - Key slots: each slot wraps the same random 64-byte data key (DEK = 32 enc + 32 mac) with a
##   key-encryption key from PBKDF2-HMAC-SHA256(secret, random salt, iterations). Slot kinds:
##   "pin" (PIN or passphrase) and "legacy" (the old owner code, so it keeps working until the owner
##   retires it). Changing the PIN only rewraps the DEK; saves are not re-encrypted.
## - Two separate states:
##   storage_ready(): the DEK is in memory (after one unlock per app launch). Encrypted saves load.
##   is_unlocked(): the OWNER SESSION. Profile.is_owner() needs it. It auto-locks after
##   lock_minutes without input (default 30, owner-adjustable). Auto-lock keeps the DEK so companions
##   keep their memories; "Lock & seal" (lock_all) also drops the DEK.
## - Brute-force backoff: after 5 wrong tries, wait 30 s, doubling, max 1 h. Persisted.
## File: <root>/vault.json (no secrets inside: salts, iteration counts, wrapped keys).

const VERSION := 1
const MIN_PIN := 6
const MIN_PASSPHRASE := 8
const DEFAULT_LOCK_MIN := 30
const LOCK_RANGE := [1, 240]
const FREE_TRIES := 5

static var root := "user://security"
static var iterations := CryptoBox.DEFAULT_ITERATIONS   # tests lower this
static var _dek_enc := PackedByteArray()
static var _dek_mac := PackedByteArray()
static var _session := false
static var _last_activity_ms := 0
static var _legacy_code := ""          # held only during a legacy session, to add a legacy slot at setup
static var _vault_cache = null
static var on_storage_ready: Array[Callable] = []   # reload hooks (EveCore, Estate, AgentBrain...)
static var clock_ms := Callable()   # tests: fake clock

static func _now_ms() -> int: return clock_ms.call() if clock_ms.is_valid() else Time.get_ticks_msec()
static func _path() -> String: return root.path_join("vault.json")

static func vault() -> Dictionary:
	if _vault_cache == null:
		_vault_cache = {}
		if FileAccess.file_exists(_path()):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
			if d is Dictionary: _vault_cache = d
	return _vault_cache

static func _save_vault() -> void:
	DirAccess.make_dir_recursive_absolute(root)
	var tmp := _path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(_vault_cache, "\t"))
	f.close()
	DirAccess.rename_absolute(tmp, _path())

static func has_vault() -> bool: return not vault().get("slots", []).is_empty()
static func storage_ready() -> bool: return _dek_enc.size() == 32
static func dek() -> Dictionary: return {"enc": _dek_enc, "mac": _dek_mac}
static func lock_minutes() -> int: return int(vault().get("lock_minutes", DEFAULT_LOCK_MIN))
static func has_legacy_slot() -> bool: return vault().get("slots", []).any(func(s): return s.get("kind") == "legacy")
static func needs_pin_setup() -> bool: return _session and not has_vault()

static func validate_secret(secret: String) -> String:
	var s := secret.strip_edges()
	if s.is_valid_int() and s.length() >= MIN_PIN: return ""
	if not s.is_valid_int() and s.length() >= MIN_PASSPHRASE: return ""
	return "Use a PIN of at least %d digits or a passphrase of at least %d characters." % [MIN_PIN, MIN_PASSPHRASE]

# ---------- session ----------
static func is_unlocked() -> bool:
	if _session and _now_ms() - _last_activity_ms > lock_minutes() * 60000:
		lock()
	return _session

static func touch() -> void:
	if _session: _last_activity_ms = _now_ms()

static func seconds_left() -> int:
	if not is_unlocked(): return 0
	return maxi(0, (lock_minutes() * 60000 - (_now_ms() - _last_activity_ms)) / 1000)

static func lock() -> void:
	_session = false
	_legacy_code = ""

## Lock and drop the data key: encrypted saves stay closed until the next unlock.
static func lock_all() -> void:
	lock()
	_dek_enc = PackedByteArray(); _dek_mac = PackedByteArray()

static func _start_session() -> void:
	_session = true
	_last_activity_ms = _now_ms()

## Legacy owner code accepted by Profile (hash match) while no vault exists yet:
## owner session only (no storage key). The UI then offers the set-PIN step.
static func start_legacy_session(code: String) -> void:
	_legacy_code = code
	_start_session()

static func set_lock_minutes(m: int) -> bool:
	if not is_unlocked(): return false
	vault()["lock_minutes"] = clampi(m, LOCK_RANGE[0], LOCK_RANGE[1])
	_save_vault()
	return true

# ---------- slots ----------
## Legacy owner codes are case-insensitive (same normalisation as Profile.code_hash).
static func _norm(kind: String, secret: String) -> String:
	return secret.strip_edges().to_lower() if kind == "legacy" else secret.strip_edges()

static func _make_slot(kind: String, secret: String, dek_bytes: PackedByteArray) -> Dictionary:
	secret = _norm(kind, secret)
	var salt := CryptoBox.random_bytes(16)
	var k := CryptoBox.subkeys(CryptoBox.pbkdf2_sha256(secret.strip_edges().to_utf8_buffer(), salt, iterations))
	return {"kind": kind, "kdf": "pbkdf2-hmac-sha256", "iter": iterations, "salt": Marshalls.raw_to_base64(salt),
		"wrapped": Marshalls.raw_to_base64(CryptoBox.seal(k["enc"], k["mac"], dek_bytes))}

static func _try_slot(slot: Dictionary, secret: String) -> PackedByteArray:
	secret = _norm(str(slot.get("kind", "")), secret)
	var salt := Marshalls.base64_to_raw(str(slot.get("salt", "")))
	var k := CryptoBox.subkeys(CryptoBox.pbkdf2_sha256(secret.strip_edges().to_utf8_buffer(), salt, int(slot.get("iter", iterations))))
	var st := {}
	var d := CryptoBox.open(k["enc"], k["mac"], Marshalls.base64_to_raw(str(slot.get("wrapped", ""))), st)
	return d if st["ok"] and d.size() == 64 else PackedByteArray()

## First-run setup. Allowed while no vault exists AND an owner session is active (legacy code
## unlock) or allow_fresh is true (brand-new install: whoever sets it up owns this device).
## Adds a "legacy" slot for the old owner code if this session was opened with it.
static func setup(secret: String, allow_fresh := false) -> String:
	if has_vault(): return "Already set up. Use Change PIN."
	if not (_session or allow_fresh): return "Unlock with the owner code first."
	var e := validate_secret(secret)
	if e != "": return e
	var d := CryptoBox.random_bytes(64)
	var slots: Array = [_make_slot("pin", secret, d)]
	if _legacy_code != "": slots.append(_make_slot("legacy", _legacy_code, d))
	_vault_cache = {"v": VERSION, "slots": slots, "lock_minutes": DEFAULT_LOCK_MIN, "fails": 0, "retry_at": 0,
		"created": Time.get_datetime_string_from_system()}
	_save_vault()
	_set_dek(d)
	_legacy_code = ""
	_start_session()
	return ""

static func _set_dek(d: PackedByteArray) -> void:
	_dek_enc = d.slice(0, 32); _dek_mac = d.slice(32, 64)
	for cb in on_storage_ready.duplicate():
		if cb.is_valid(): cb.call()

static func retry_in_s() -> int:
	return maxi(0, int(vault().get("retry_at", 0)) - int(Time.get_unix_time_from_system()))

## PIN/passphrase or legacy code -> DEK + owner session. Returns "" or an error.
static func unlock(secret: String) -> String:
	if not has_vault(): return "No PIN set yet."
	if retry_in_s() > 0: return "Too many tries. Wait %d s." % retry_in_s()
	for slot in vault()["slots"]:
		var d := _try_slot(slot, secret)
		if d.size() == 64:
			vault()["fails"] = 0; vault()["retry_at"] = 0; _save_vault()
			if not storage_ready(): _set_dek(d)
			_start_session()
			return ""
	var v := vault()
	v["fails"] = int(v.get("fails", 0)) + 1
	if v["fails"] >= FREE_TRIES:
		v["retry_at"] = int(Time.get_unix_time_from_system()) + mini(3600, 30 * int(pow(2, v["fails"] - FREE_TRIES)))
	_save_vault()
	return "Wrong PIN."

## Future biometric plugin entry point (see BiometricHook). Not reachable today.
static func unlock_with_dek(d: PackedByteArray) -> bool:
	if d.size() != 64: return false
	_set_dek(d); _start_session()
	return true

static func change_secret(old_secret: String, new_secret: String) -> String:
	if not is_unlocked(): return "Unlock first."
	var e := validate_secret(new_secret)
	if e != "": return e
	var d := PackedByteArray()
	for slot in vault()["slots"]:
		if slot.get("kind") == "pin": d = _try_slot(slot, old_secret)
	if d.size() != 64: return "Current PIN is wrong."
	var slots: Array = vault()["slots"].filter(func(s): return s.get("kind") != "pin")
	slots.insert(0, _make_slot("pin", new_secret, d))
	vault()["slots"] = slots
	_save_vault()
	return ""

## Stop accepting the old owner code (PIN only from now on).
static func retire_legacy() -> bool:
	if not is_unlocked() or not has_legacy_slot(): return false
	vault()["slots"] = vault()["slots"].filter(func(s): return s.get("kind") != "legacy")
	_save_vault()
	return true

static func reset_for_tests(p_root: String, p_iter := 1000) -> void:
	root = p_root; iterations = p_iter; _vault_cache = null
	lock_all(); clock_ms = Callable()
