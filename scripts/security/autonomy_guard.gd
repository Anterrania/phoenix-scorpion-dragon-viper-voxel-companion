class_name AutonomyGuard
extends RefCounted
## E-stop / kill switch: pauses ALL companion autonomy (free roam goals), self-learning
## (BrainLearner, BrainCore proposals) and tool execution. Chat replies still work.
## Anyone can ENGAGE it (safety first); only the unlocked owner can RELEASE it. Persisted.
##
## SEC-FIX-3: once an OwnerVault exists, estop.json carries a MAC:
##   {"state": {paused, reason, since}, "mac": base64 HMAC-SHA256(DEK mac half, "phoenix/estop|" + state JSON)}
## FAIL CLOSED: if the file is unreadable, has no/invalid MAC, or can't be verified yet (vault exists
## but the data key isn't loaded), the e-stop counts as ENGAGED. It is re-checked automatically when
## the owner unlocks. With no vault there is no key, so the file is plain JSON (unreadable -> engaged).

static var path := "user://security/estop.json"
static var _state = null   # {paused, reason, since}
static var _verified := false   # state came from a MAC-verified (or no-vault plain) file / fresh write
static var _hooked := false

static func _hook() -> void:
	if _hooked: return
	_hooked = true
	OwnerVault.on_storage_ready.append(func(): if not _verified: _state = null)

static func _mac(state_json: String) -> String:
	var k := OwnerVault.dek()
	return Marshalls.raw_to_base64(CryptoBox.hmac(k["mac"], ("phoenix/estop|" + state_json).to_utf8_buffer()))

static func _closed(reason: String) -> Dictionary:
	return {"paused": true, "reason": reason, "since": "", "fail_closed": true}

static func _load() -> Dictionary:
	_hook()
	if _state == null:
		_verified = true
		_state = {"paused": false, "reason": "", "since": ""}
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not (d is Dictionary):
				_state = _closed("e-stop file unreadable"); _verified = false
			elif OwnerVault.has_vault():
				var st: Variant = d.get("state")
				var mac := str(d.get("mac", ""))
				if not (st is Dictionary) or mac == "":
					_state = _closed("e-stop file not sealed"); _verified = false
				elif not OwnerVault.storage_ready():
					_state = _closed("e-stop unverified until owner unlock"); _verified = false
				elif not CryptoBox.equal(_mac(JSON.stringify(st)).to_ascii_buffer(), mac.to_ascii_buffer()):
					_state = _closed("e-stop file tampered"); _verified = false
					push_error("AutonomyGuard: estop.json MAC check failed; e-stop engaged")
				else:
					_state.merge(st, true)
			else:
				_state.merge(d.get("state", d) if d.get("state") is Dictionary else d, true)
	return _state

static func paused() -> bool: return bool(_load()["paused"])
static func state() -> Dictionary: return _load().duplicate()

static func engage(reason := "e-stop") -> void:
	var s := _load()
	s["paused"] = true; s["reason"] = reason.left(120); s["since"] = Time.get_datetime_string_from_system()
	s.erase("fail_closed")
	_save()

## Owner only. Returns false if the owner session is not unlocked.
static func release() -> bool:
	if not OwnerVault.is_unlocked(): return false
	_load()
	_state = {"paused": false, "reason": "", "since": ""}
	return _save()

static func _save() -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var body := {}
	var sj := JSON.stringify(_state)
	if OwnerVault.has_vault():
		if not OwnerVault.storage_ready():
			# can't MAC: write an unsealed record, which loads as engaged (fail closed) - fine for engage()
			if not bool(_state.get("paused", false)): return false
			body = {"state": _state}
		else:
			body = {"state": _state, "mac": _mac(sj)}
	else:
		body = {"state": _state}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(body))
	f.close()
	SecureFile.replace_file(tmp, path)
	_verified = true
	return true

static func reset_for_tests(p: String) -> void:
	path = p; _state = null; _verified = false
