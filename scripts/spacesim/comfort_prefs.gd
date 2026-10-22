class_name ComfortPrefs
extends RefCounted
## Comfort + control preferences (flight, travel and camera comfort; touch, keyboard and gamepad
## binding profiles). Its own file, user://frontier/comfort.json, so it never collides with
## Settings (settings.cfg, owned by the phone/display work). Everything is per device, no tier gate:
## comfort is never paywalled. Readers: the player camera, Foxy's HUD and flight UI (apply_camera()).
##
## Concepts from space sims' options menus, rebuilt for a phone: FOV, motion comfort (vignette while
## turning, snap turn, no camera shake / head bob / motion blur, horizon lock, travel-effect intensity),
## camera smoothing, invert look, look sensitivity, and named binding profiles.

const STORE := "comfort"
const FOV_MIN := 55
const FOV_MAX := 110
const DEFAULTS := {
	"fov": 75, "fov_vehicle": 85,
	"vignette_on_turn": true, "snap_turn": false, "snap_degrees": 30,
	"camera_shake": false, "head_bob": false, "motion_blur": false, "horizon_lock": true,
	"travel_fx": 0.5,          # 0 = calm travel effect (no streaks), 1 = full
	"camera_smoothing": 0.5,   # 0..1
	"look_sensitivity": 1.0,   # 0.2..3
	"invert_look_y": false,
	"profile": "touch_default",
}
## Action -> binding per profile. Touch bindings name on-screen controls/gestures (Foxy's HUD maps them).
const BUILTIN_PROFILES := {
	"touch_default": {"device": "touch", "bindings": {"move": "left_stick", "look": "right_drag", "jump": "button_a", "interact": "tap", "menu": "button_menu", "map": "two_finger_tap", "boost": "double_tap_stick", "travel": "hold_menu_travel", "brake": "button_b"}},
	"touch_left_handed": {"device": "touch", "bindings": {"move": "right_stick", "look": "left_drag", "jump": "button_a_left", "interact": "tap", "menu": "button_menu", "map": "two_finger_tap", "boost": "double_tap_stick", "travel": "hold_menu_travel", "brake": "button_b_left"}},
	"touch_one_thumb": {"device": "touch", "bindings": {"move": "tap_to_move", "look": "drag", "jump": "swipe_up", "interact": "tap", "menu": "button_menu", "map": "two_finger_tap", "boost": "long_press", "travel": "hold_menu_travel", "brake": "swipe_down"}},
	"keyboard_default": {"device": "keyboard", "bindings": {"move": "WASD", "look": "mouse", "jump": "Space", "interact": "F", "menu": "Tab", "map": "M", "boost": "Shift", "travel": "B", "brake": "X"}},
	"gamepad_default": {"device": "gamepad", "bindings": {"move": "left_stick", "look": "right_stick", "jump": "A", "interact": "X", "menu": "Start", "map": "Back", "boost": "LB", "travel": "RB_hold", "brake": "B"}},
}
const ACTIONS := ["move", "look", "jump", "interact", "menu", "map", "boost", "travel", "brake"]

static func _db() -> Dictionary: return FrontierStore.db(STORE, {"prefs": DEFAULTS.duplicate(), "profiles": {}})

static func get_pref(key: String) -> Variant: return _db()["prefs"].get(key, DEFAULTS.get(key))

static func all() -> Dictionary:
	var out := DEFAULTS.duplicate()
	out.merge(_db()["prefs"], true)
	return out

static func _valid(key: String, v: Variant) -> Variant:
	match key:
		"fov", "fov_vehicle": return clampi(int(v), FOV_MIN, FOV_MAX)
		"snap_degrees": return clampi(int(v), 15, 90)
		"travel_fx", "camera_smoothing": return clampf(float(v), 0.0, 1.0)
		"look_sensitivity": return clampf(float(v), 0.2, 3.0)
		"profile": return str(v) if profiles().has(str(v)) else null
	return bool(v) if DEFAULTS[key] is bool else null

static func set_pref(key: String, v: Variant) -> Dictionary:
	if not DEFAULTS.has(key): return FrontierStore.err("Unknown setting.")
	var val: Variant = _valid(key, v)
	if val == null: return FrontierStore.err("Not a valid value.")
	_db()
	var snap := FrontierStore.snap(STORE)
	_db()["prefs"][key] = val
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"value": val}))

static func reset() -> Dictionary:
	_db()
	var snap := FrontierStore.snap(STORE)
	_db()["prefs"] = DEFAULTS.duplicate()
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

## One tap: the calmest set (for motion sickness or tired eyes).
static func calm_preset() -> Dictionary:
	for kv in [["vignette_on_turn", true], ["snap_turn", true], ["camera_shake", false], ["head_bob", false], ["motion_blur", false], ["horizon_lock", true], ["travel_fx", 0.0], ["camera_smoothing", 0.8], ["fov", 70]]:
		var r := set_pref(kv[0], kv[1])
		if not r["ok"]: return r
	return FrontierStore.ok()

static func profiles() -> Dictionary:
	var out := BUILTIN_PROFILES.duplicate(true)
	out.merge(_db()["profiles"], true)
	return out

static func bindings(profile := "") -> Dictionary:
	var p := profile if profile != "" else str(get_pref("profile"))
	return profiles().get(p, BUILTIN_PROFILES["touch_default"])["bindings"].duplicate()

## Custom profile = a copy of a base profile with remaps. Built-ins can't be overwritten.
static func save_profile(name: String, base: String, remap: Dictionary) -> Dictionary:
	var n := FrontierStore.clean(name, 32)
	if n == "" or BUILTIN_PROFILES.has(n): return FrontierStore.err("Pick a new profile name.")
	if not profiles().has(base): return FrontierStore.err("Unknown base profile.")
	var b: Dictionary = profiles()[base].duplicate(true)
	for a in remap:
		if not a in ACTIONS: return FrontierStore.err("Unknown action: %s" % a)
		b["bindings"][a] = FrontierStore.clean(remap[a], 32)
	var used := {}
	for a in b["bindings"]:
		var k: String = b["bindings"][a]
		if used.has(k) and not k in ["tap"]: return FrontierStore.err("%s is bound twice (%s, %s)." % [k, used[k], a])
		used[k] = a
	_db()
	var snap := FrontierStore.snap(STORE)
	_db()["profiles"][n] = b
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"profile": n}))

static func delete_profile(name: String) -> Dictionary:
	if BUILTIN_PROFILES.has(name) or not _db()["profiles"].has(name): return FrontierStore.err("Only custom profiles can be deleted.")
	var snap := FrontierStore.snap(STORE)
	_db()["profiles"].erase(name)
	if _db()["prefs"].get("profile") == name: _db()["prefs"]["profile"] = "touch_default"
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

## Hook for the camera owner (player / Foxy's flight HUD): apply FOV for on-foot or vehicle view.
static func apply_camera(cam: Camera3D, in_vehicle := false) -> void:
	if cam: cam.fov = float(get_pref("fov_vehicle" if in_vehicle else "fov"))
