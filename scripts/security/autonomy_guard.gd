class_name AutonomyGuard
extends RefCounted
## E-stop / kill switch: pauses ALL companion autonomy (free roam goals), self-learning
## (BrainLearner, BrainCore proposals) and tool execution. Chat replies still work.
## Anyone can ENGAGE it (safety first); only the unlocked owner can RELEASE it. Persisted.

static var path := "user://security/estop.json"
static var _state = null   # {paused, reason, since}

static func _load() -> Dictionary:
	if _state == null:
		_state = {"paused": false, "reason": "", "since": ""}
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary: _state.merge(d, true)
	return _state

static func paused() -> bool: return bool(_load()["paused"])
static func state() -> Dictionary: return _load().duplicate()

static func engage(reason := "e-stop") -> void:
	var s := _load()
	s["paused"] = true; s["reason"] = reason.left(120); s["since"] = Time.get_datetime_string_from_system()
	_save()

## Owner only. Returns false if the owner session is not unlocked.
static func release() -> bool:
	if not OwnerVault.is_unlocked(): return false
	_load()["paused"] = false
	_save()
	return true

static func _save() -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_state))

static func reset_for_tests(p: String) -> void:
	path = p; _state = null
