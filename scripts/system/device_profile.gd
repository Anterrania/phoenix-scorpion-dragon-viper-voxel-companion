extends Node
## DeviceProfile (autoload): detects the device once at startup, caches it as caps() (DeviceCaps schema),
## and re-detects on change: window resize/rotation/fold, gamepad connect, app focus, and a 30 s refresh
## of the live keys (battery_pct, power_save, charging, thermal, network, orientation). Consumers never poll:
## they read caps() and re-read it on caps_changed.
## Docs: docs/modules/DEVICE_COMPAT.md · Client spec: docs/specs/foxy/device_profile_caps.md
## PRIVACY: everything stays on this device. Nothing is uploaded or saved outside user:// settings.
signal caps_changed(caps: Dictionary)

const LIVE_REFRESH_S := 30.0
## Optional Android plugin singleton (not shipped yet). When present it fills the keys Godot cannot read:
## get_battery_pct() -> int, is_charging() -> bool, is_power_save() -> bool, get_thermal() -> int (0..6), get_network() -> String,
## get_vram_mb() -> int, has_vibrator() -> bool. See DEVICE_COMPAT.md §6 (gaps).
const PLUGIN := "ViperDevice"

var _caps: Dictionary = {}
var _fake: Variant = null          # tests / previews: a fake caps Dictionary replaces detection
var _timer: Timer
var detect_count := 0              # tests: how many full detections ran

func _ready() -> void:
	redetect(false)
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(func(): _on_change("screen"))
	Input.joy_connection_changed.connect(func(_d, _c): _on_change("input"))
	_timer = Timer.new(); _timer.wait_time = LIVE_REFRESH_S; _timer.autostart = true; _timer.name = "LiveRefresh"
	_timer.timeout.connect(refresh_live)
	add_child(_timer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and not _caps.is_empty(): refresh_live()

## The cached caps (always the full schema, never re-detects). Copy: callers can't mutate the cache.
func caps() -> Dictionary:
	if _caps.is_empty(): redetect(false)
	return _caps.duplicate(true)

func get_value(key: String, fallback: Variant = null) -> Variant:
	return _caps.get(key, DeviceCaps.defaults().get(key, fallback))

## Full detection. emit=false only for the first run in _ready (nobody is listening yet).
func redetect(emit := true) -> Dictionary:
	detect_count += 1
	_caps = DeviceCaps.normalize(_fake if _fake is Dictionary else detect())
	if _fake is Dictionary: _caps["source"] = "fake"
	if emit: caps_changed.emit(_caps.duplicate(true))
	return _caps.duplicate(true)

## Re-read only the cheap live keys; emits caps_changed only when one of them changed.
func refresh_live() -> bool:
	if _fake is Dictionary: return false
	var live := _live()
	var changed := false
	for k in live:
		if _caps.get(k) != live[k]: _caps[k] = live[k]; changed = true
	if changed: caps_changed.emit(_caps.duplicate(true))
	return changed

## Tests / admin previews. Pass null to go back to real detection.
func set_fake(c: Variant) -> void:
	_fake = c
	redetect(true)

func is_fake() -> bool: return _fake is Dictionary

func _on_change(what: String) -> void:
	if _fake is Dictionary: return
	var before := _caps.duplicate(true)
	if what == "screen": _caps.merge(_screen(), true)
	elif what == "input": _caps.merge(_input_caps(), true)
	_caps["form_factor"] = DeviceCaps.form_factor_of(_caps["os"], _caps["touch"], _caps["diag_in"], _caps["keyboard"], _caps["mouse"])
	_caps["foldable"] = DeviceCaps.foldable_of(_caps["os"], _caps["touch"], _caps["screen_w"], _caps["screen_h"], _caps["diag_in"])
	if _caps != before: caps_changed.emit(_caps.duplicate(true))

# ---------- detection (engine APIs only, no dependencies) ----------
static func _plugin() -> Object:
	return Engine.get_singleton(PLUGIN) if Engine.has_singleton(PLUGIN) else null

func detect() -> Dictionary:
	var c := DeviceCaps.defaults()
	var os := OS.get_name()
	c["source"] = "engine+plugin" if _plugin() else "engine"
	c["headless"] = DisplayServer.get_name() == "headless"
	c["os"] = os
	c["os_version"] = OS.get_version()
	c["android_api"] = DeviceCaps.android_api_of(OS.get_version()) if os == "Android" else -1
	c["model"] = OS.get_model_name() if OS.get_model_name() != "GenericDevice" else ""
	c["locale"] = OS.get_locale()
	c["arch"] = Engine.get_architecture_name()
	c["cpu_cores"] = OS.get_processor_count()
	c["cpu_name"] = OS.get_processor_name()
	var mem := OS.get_memory_info()
	c["ram_mb"] = int(int(mem.get("physical", -1)) / 1048576) if int(mem.get("physical", -1)) > 0 else -1
	var d := DirAccess.open("user://")
	if d:
		var left := d.get_space_left()
		c["storage_free_mb"] = int(left / 1048576) if left > 0 else -1
	# graphics
	c["gpu"] = RenderingServer.get_video_adapter_name()
	c["gpu_vendor"] = RenderingServer.get_video_adapter_vendor()
	c["gpu_api"] = RenderingServer.get_video_adapter_api_version()
	c["renderer"] = RenderingServer.get_current_rendering_method()
	c["compute"] = DeviceCaps.compute_of(c["renderer"], RenderingServer.get_rendering_device() != null)
	c["astc"] = RenderingServer.has_os_feature("astc")
	c["etc2"] = RenderingServer.has_os_feature("etc2")
	c["vram_mb"] = _vram_estimate(os, c["ram_mb"])
	c.merge(_screen(), true)
	c.merge(_input_caps(), true)
	c.merge(_media(), true)
	c.merge(_live(), true)
	c["form_factor"] = DeviceCaps.form_factor_of(os, c["touch"], c["diag_in"], c["keyboard"], c["mouse"])
	c["foldable"] = DeviceCaps.foldable_of(os, c["touch"], c["screen_w"], c["screen_h"], c["diag_in"])
	c["detected_at"] = int(Time.get_unix_time_from_system())
	c["capability_score"] = DeviceCaps.score(c)
	c["capability_class"] = DeviceCaps.capability_class(c)
	return c

## Phones share RAM with the GPU, so a quarter of RAM is a fair budget estimate. Desktop: unknown.
static func _vram_estimate(os: String, ram_mb: int) -> int:
	var p := _plugin()
	if p and p.has_method("get_vram_mb"): return int(p.get_vram_mb())
	if os in ["Android", "iOS"] and ram_mb > 0: return ram_mb / 4
	return -1

static func _screen() -> Dictionary:
	var s := {}
	if DisplayServer.get_name() == "headless": return {"orientation": ""}
	var scr := DisplayServer.window_get_current_screen()
	var sz := DisplayServer.screen_get_size(scr)
	s["screen_w"] = sz.x; s["screen_h"] = sz.y
	s["dpi"] = DisplayServer.screen_get_dpi(scr)
	s["screen_scale"] = DisplayServer.screen_get_scale(scr)
	s["refresh_hz"] = snappedf(DisplayServer.screen_get_refresh_rate(scr), 0.1)
	s["safe_area"] = DisplayServer.get_display_safe_area()
	s["orientation"] = DeviceCaps.orientation_of(sz.x, sz.y)
	s["diag_in"] = DeviceCaps.diagonal_in(sz.x, sz.y, s["dpi"])
	return s

static func _input_caps() -> Dictionary:
	var mobile := OS.has_feature("mobile")
	var acc := Input.get_accelerometer()
	var gyr := Input.get_gyroscope()
	var xr := false
	if ClassDB.class_exists("XRServer"):
		for i in XRServer.get_interfaces():
			var xi := XRServer.find_interface(str(i.get("name", "")))
			if xi and xi.is_initialized(): xr = true
	return {
		"touch": DisplayServer.is_touchscreen_available(),
		"mouse": not mobile and DisplayServer.get_name() != "headless",
		"keyboard": DisplayServer.has_hardware_keyboard() if mobile else DisplayServer.get_name() != "headless",
		"gamepads": Input.get_connected_joypads().size(),
		"xr": xr,
		# Godot reports ZERO until the sensor delivers a sample: on a phone that is "unknown", not "no".
		"accelerometer": 1 if acc != Vector3.ZERO else (-1 if mobile else 0),
		"gyro": 1 if gyr != Vector3.ZERO else (-1 if mobile else 0),
		"haptics": _haptics(mobile),
	}

static func _haptics(mobile: bool) -> bool:
	var p := _plugin()
	if p and p.has_method("has_vibrator"): return bool(p.has_vibrator())
	return mobile   # Input.vibrate_handheld exists on Android/iOS; phones without a motor ignore it

static func _media() -> Dictionary:
	var m := {}
	var feeds := 0
	if ClassDB.class_exists("CameraServer"):
		CameraServer.monitoring_feeds = true
		feeds = CameraServer.get_feed_count()
	var android := OS.get_name() == "Android"
	var granted := OS.get_granted_permissions() if android else PackedStringArray()
	m["camera_perm"] = ("granted" if "android.permission.CAMERA" in granted else "ask") if android else "n/a"
	m["mic_perm"] = ("granted" if "android.permission.RECORD_AUDIO" in granted else "ask") if android else "n/a"
	# Android lists camera feeds only after the permission: zero feeds without it means "unknown".
	m["camera"] = 1 if feeds > 0 else (-1 if android and m["camera_perm"] != "granted" else 0)
	var mics := AudioServer.get_input_device_list()
	var input_on := bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
	m["mic"] = 1 if input_on and mics.size() > 0 and DisplayServer.get_name() != "headless" else (-1 if android else 0)
	return m

func _live() -> Dictionary:
	var l := {"battery_pct": -1, "charging": -1, "power_save": -1, "thermal": -1, "network": "",
		"orientation": DeviceCaps.orientation_of(int(_caps.get("screen_w", -1)), int(_caps.get("screen_h", -1)))}
	if DisplayServer.get_name() != "headless":
		var sz := DisplayServer.window_get_size()
		l["orientation"] = DeviceCaps.orientation_of(sz.x, sz.y)
	var p := _plugin()
	if p:
		if p.has_method("get_battery_pct"): l["battery_pct"] = int(p.get_battery_pct())
		if p.has_method("is_charging"): l["charging"] = 1 if p.is_charging() else 0
		if p.has_method("is_power_save"): l["power_save"] = 1 if p.is_power_save() else 0
		if p.has_method("get_thermal"): l["thermal"] = clampi(int(p.get_thermal()), -1, 6)
		if p.has_method("get_network"): l["network"] = str(p.get_network())
	return l
