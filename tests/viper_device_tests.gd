extends RefCounted
## ViperDevice Android plugin (COMPAT-7): fake plugin singleton -> DeviceProfile merge, live refresh on
## the 30 s timer / focus / plugin event (coalesced), unknowns stay unknown, source-tree checks.

class FakePlugin extends Object:
	signal live_changed
	var stat := {}
	var live := {}
	var live_calls := 0
	func get_plugin_version() -> int: return 1
	func get_static() -> Dictionary: return stat
	func get_live() -> Dictionary:
		live_calls += 1
		return live

const NAME := "ViperDevice"

static func run(t: Node) -> void:
	var DP: Node = t.get_node("/root/DeviceProfile")
	DP.set_fake(null)
	# ---------- pure merges ----------
	var c := DeviceCaps.defaults()
	c["os"] = "Android"; c["form_factor"] = "phone"; c["camera"] = -1; c["gyro"] = 1; c["ram_mb"] = 3800
	DP.merge_plugin_static(c, {"android_api": 34, "ram_mb": 3712, "vram_mb": -1, "has_vibrator": 0, "camera": 1, "gyro": 0, "tv": 0, "chromeos": false, "hinge": -1})
	t.check(c["android_api"] == 34 and c["ram_mb"] == 3712 and c["camera"] == 1, "viperdevice: real API level, RAM and camera (no permission) from plugin")
	t.check(c["haptics"] == false and c["gyro"] == 1 and c["form_factor"] == "phone", "viperdevice: vibrator absent -> no haptics; live engine gyro 'yes' kept")
	t.check(c["vram_mb"] == -1, "viperdevice: -1 from plugin never overwrites (vram stays unknown)")
	var tv := DeviceCaps.defaults(); tv["form_factor"] = "phone"
	DP.merge_plugin_static(tv, {"tv": 1})
	var cr := DeviceCaps.defaults(); cr["form_factor"] = "tablet"
	DP.merge_plugin_static(cr, {"chromeos": true})
	var fo := DeviceCaps.defaults()
	DP.merge_plugin_static(fo, {"hinge": 1})
	t.check(tv["form_factor"] == "tv" and cr["form_factor"] == "desktop" and fo["foldable"] == true, "viperdevice: leanback -> tv, ChromeOS -> desktop, hinge sensor -> foldable")
	var l: Dictionary = DP.merge_plugin_live({"battery_pct": -1, "charging": -1, "power_save": -1, "thermal": -1, "network": ""}, {"battery_pct": 140, "charging": 1, "power_save": 0, "thermal": 9, "network": "5g"})
	t.check(l["battery_pct"] == 100 and l["thermal"] == 6 and l["network"] == "" and l["charging"] == 1 and l["power_save"] == 0, "viperdevice: live values clamped; bad network -> unknown")
	t.check(DP.merge_plugin_live({"thermal": -1}, {}) == {"thermal": -1}, "viperdevice: no plugin -> live keys stay unknown")

	# ---------- fake singleton through the real DeviceProfile path ----------
	t.check(not Engine.has_singleton(NAME), "viperdevice: no plugin on desktop/CI by default")
	var fp := FakePlugin.new()
	fp.stat = {"android_api": 35, "ram_mb": 7680, "vram_mb": -1, "has_vibrator": 1, "camera": 1, "mic": 1, "tv": 0, "chromeos": false, "hinge": 0}
	fp.live = {"battery_pct": 22, "charging": 0, "power_save": 1, "thermal": 3, "network": "cell"}
	Engine.register_singleton(NAME, fp)
	var caps: Dictionary = DP.redetect(false)
	t.check(caps["source"] == "engine+plugin" and caps["android_api"] == 35 and caps["ram_mb"] == 7680 and caps["haptics"] == true, "viperdevice: detect() merges get_static()")
	t.check(caps["battery_pct"] == 22 and caps["power_save"] == 1 and caps["thermal"] == 3 and caps["network"] == "cell" and caps["charging"] == 0, "viperdevice: detect() merges get_live()")
	t.check(AutoConfig.power_of(caps, false)["mode"] == "saver", "viperdevice: plugin values drive PowerData (low battery / power save / thermal / cell -> saver)")
	# change -> refresh emits caps_changed once
	var got := []
	var cb := func(cc): got.append(cc)
	DP.caps_changed.connect(cb)
	fp.live = {"battery_pct": 80, "charging": 1, "power_save": 0, "thermal": 0, "network": "wifi"}
	t.check(DP.refresh_live() and got.size() == 1 and got[0]["network"] == "wifi" and got[0]["charging"] == 1, "viperdevice: refresh_live picks up changes, one caps_changed")
	t.check(not DP.refresh_live() and got.size() == 1, "viperdevice: no change -> no signal")
	# focus refresh
	var before := fp.live_calls
	DP._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	t.check(fp.live_calls == before + 1, "viperdevice: app focus refreshes live keys")
	# plugin event -> deferred, coalesced refresh (no polling)
	t.check(DP.hook_plugin() and fp.is_connected("live_changed", DP._on_plugin_event), "viperdevice: live_changed event hooked")
	DP._last_event_ms = -100000
	before = fp.live_calls
	fp.live_changed.emit(); fp.live_changed.emit(); fp.live_changed.emit()
	await t.get_tree().process_frame
	t.check(fp.live_calls == before + 1, "viperdevice: burst of plugin events -> one refresh")
	# timer: 30 s, stopped in background
	var tm: Timer = DP.get_node("LiveRefresh")
	t.check(is_equal_approx(tm.wait_time, 30.0), "viperdevice: live refresh every 30 s")
	DP._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var stopped := tm.is_stopped()
	DP._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	t.check(stopped and not tm.is_stopped(), "viperdevice: refresh timer stops in background, restarts on resume")
	DP.caps_changed.disconnect(cb)
	fp.disconnect("live_changed", DP._on_plugin_event)
	Engine.unregister_singleton(NAME)
	DP._plugin_hooked = null
	fp.free()
	t.check(DP.redetect(false)["source"] == "engine" and DP.caps()["battery_pct"] == -1, "viperdevice: plugin removed -> back to engine-only, unknowns")

	# ---------- source tree ----------
	var root := "res://android/plugins/viper_device/"
	var kt := FileAccess.get_file_as_string(root + "src/main/java/com/anterrania/viperdevice/ViperDevicePlugin.kt")
	t.check(kt.contains("fun get_static()") and kt.contains("fun get_live()") and kt.contains("@UsedByGodot") and kt.contains("SignalInfo(\"live_changed\")"), "viperdevice src: Kotlin plugin exposes get_static/get_live + live_changed")
	t.check(kt.contains("currentThermalStatus") and kt.contains("FEATURE_CAMERA_ANY") and kt.contains("FEATURE_LEANBACK") and kt.contains("org.chromium.arc") and kt.contains("ACTION_BATTERY_CHANGED") and kt.contains("TRANSPORT_CELLULAR"), "viperdevice src: thermal, camera feature, TV, ChromeOS, battery, network")
	var man := FileAccess.get_file_as_string(root + "src/main/AndroidManifest.xml")
	t.check(man.contains("org.godotengine.plugin.v2.ViperDevice") and not man.contains("android.permission.INTERNET") and not man.contains("CAMERA\""), "viperdevice src: v2 manifest, only ACCESS_NETWORK_STATE")
	var gr := FileAccess.get_file_as_string(root + "build.gradle.kts")
	var deps := gr.substr(gr.find("dependencies {"))
	t.check(deps.contains("compileOnly(\"org.godotengine:godot:4.7.2.stable\")") and not deps.contains("implementation("), "viperdevice src: no third-party runtime deps")
	t.check(FileAccess.file_exists("res://addons/viper_device/plugin.cfg") and FileAccess.get_file_as_string("res://addons/viper_device/viper_device_editor.gd").contains("_get_android_libraries"), "viperdevice: editor export plugin adds the AAR")
	var aar := "res://addons/viper_device/bin/viper-device-release.aar"
	if FileAccess.file_exists(aar):
		t.check(FileAccess.get_file_as_bytes(aar).size() < 64 * 1024, "viperdevice: AAR under 64 KB")
