extends RefCounted
## Device compatibility + PowerData (COMPAT-1..8, COMPAT-PWR-1..6): DeviceCaps schema and scoring,
## AutoConfig mapping with fake profiles, override rules, FeatureRegistry, Net, Dormancy, admin screen, docs.

## Fake profiles: one per class / form factor (DEVICE_COMPAT.md §7).
static func fakes() -> Dictionary:
	var base := {"schema": 1, "os": "Android", "touch": true, "renderer": "mobile", "compute": "vulkan", "astc": true, "etc2": true, "dpi": 420, "network": "wifi"}
	var f := {}
	f["low_phone"] = base.merged({"ram_mb": 2048, "cpu_cores": 4, "compute": "gles3", "renderer": "gl_compatibility", "gpu": "Mali-G52", "gpu_vendor": "ARM", "astc": false, "screen_w": 720, "screen_h": 1600, "refresh_hz": 60.0, "dpi": 270}, true)
	f["mid_phone"] = base.merged({"ram_mb": 4096, "cpu_cores": 8, "gpu": "Adreno (TM) 619", "gpu_vendor": "Qualcomm", "screen_w": 1080, "screen_h": 2400, "refresh_hz": 60.0}, true)
	f["high_phone"] = base.merged({"ram_mb": 8192, "cpu_cores": 8, "gpu": "Adreno (TM) 740", "gpu_vendor": "Qualcomm", "screen_w": 1080, "screen_h": 2340, "refresh_hz": 120.0}, true)
	f["ultra_phone"] = base.merged({"ram_mb": 12288, "cpu_cores": 8, "gpu": "Adreno (TM) 830", "gpu_vendor": "Qualcomm", "screen_w": 1440, "screen_h": 3120, "refresh_hz": 120.0, "dpi": 500}, true)
	f["tablet"] = base.merged({"ram_mb": 8192, "cpu_cores": 8, "gpu": "Mali-G710", "gpu_vendor": "ARM", "screen_w": 1600, "screen_h": 2560, "dpi": 274, "refresh_hz": 90.0}, true)
	f["foldable"] = base.merged({"ram_mb": 12288, "cpu_cores": 8, "gpu": "Adreno (TM) 750", "screen_w": 1812, "screen_h": 2176, "dpi": 374, "refresh_hz": 120.0}, true)
	f["tv"] = base.merged({"touch": false, "ram_mb": 2048, "cpu_cores": 4, "gpu": "Mali-G31", "compute": "gles3", "renderer": "gl_compatibility", "astc": false, "screen_w": 1920, "screen_h": 1080, "dpi": 72, "gamepads": 1}, true)
	f["chromebook"] = base.merged({"keyboard": true, "mouse": true, "ram_mb": 8192, "cpu_cores": 8, "gpu": "Intel(R) UHD", "screen_w": 1920, "screen_h": 1080, "dpi": 166}, true)
	f["desktop"] = {"schema": 1, "os": "Linux", "touch": false, "keyboard": true, "mouse": true, "ram_mb": 32768, "cpu_cores": 16, "renderer": "forward_plus", "compute": "vulkan", "gpu": "NVIDIA GeForce RTX 4070", "gpu_vendor": "NVIDIA", "screen_w": 2560, "screen_h": 1440, "dpi": 109, "refresh_hz": 144.0, "network": "wifi"}
	for k in f:
		var c: Dictionary = f[k]
		c["diag_in"] = DeviceCaps.diagonal_in(int(c["screen_w"]), int(c["screen_h"]), int(c["dpi"]))
		c["form_factor"] = DeviceCaps.form_factor_of(c["os"], c.get("touch", false), c["diag_in"], c.get("keyboard", false), c.get("mouse", false))
		c["foldable"] = DeviceCaps.foldable_of(c["os"], c.get("touch", false), c["screen_w"], c["screen_h"], c["diag_in"])
	return f

static func run(t: Node) -> void:
	var F := fakes()
	# ---------- schema ----------
	var d := DeviceCaps.defaults()
	for k in ["vram_mb", "storage_free_mb", "locale", "orientation", "safe_area", "haptics", "network", "xr", "schema", "thermal", "compute", "form_factor", "battery_pct", "power_save", "charging"]:
		t.check(d.has(k), "compat schema: key " + k)
	t.check(d["safe_area"] is Rect2i and d["thermal"] == -1 and d["network"] == "" and d["schema"] == 1, "compat schema: unknown values are -1 / '' / Rect2i")
	var n := DeviceCaps.normalize({"ram_mb": 4096.0, "network": "5g", "thermal": 9, "form_factor": "watch"})
	t.check(n.size() == d.size() and n["ram_mb"] is int and n["network"] == "" and n["thermal"] == 6 and n["form_factor"] == "phone", "compat schema: normalize fills every key and clamps bad values")
	t.check(DeviceCaps.normalize({})["schema"] == 1, "compat schema: pre-schema caps upgrade to 1")
	var fut := {"schema": 2, "new_key": 5}
	t.check(DeviceCaps.is_newer(fut) and DeviceCaps.normalize(fut)["new_key"] == 5, "compat schema: newer schema keeps unknown keys, still usable")
	var js: Dictionary = DeviceCaps.normalize(JSON.parse_string(JSON.stringify(DeviceCaps.to_json_safe(DeviceCaps.normalize({"safe_area": Rect2i(0, 80, 1080, 2200)})))))
	t.check(js["safe_area"] == Rect2i(0, 80, 1080, 2200), "compat schema: safe_area survives a JSON round trip")
	# ---------- pure helpers ----------
	t.check(DeviceCaps.compute_of("mobile", true) == "vulkan" and DeviceCaps.compute_of("gl_compatibility", false) == "gles3" and DeviceCaps.compute_of("dummy", false) == "none", "compat: compute classification")
	t.check(DeviceCaps.android_api_of("14") == 34 and DeviceCaps.android_api_of("12L") == 32 and DeviceCaps.android_api_of("8.1.0") == 26 and DeviceCaps.android_api_of("x") == -1, "compat: Android release -> API level")
	t.check(DeviceCaps.orientation_of(1080, 2400) == "portrait" and DeviceCaps.orientation_of(2400, 1080) == "landscape" and DeviceCaps.orientation_of(-1, 0) == "", "compat: orientation")
	# ---------- classes + form factors ----------
	var want := {"low_phone": ["low", "phone"], "mid_phone": ["mid", "phone"], "high_phone": ["high", "phone"], "ultra_phone": ["ultra", "phone"],
		"tablet": ["high", "tablet"], "foldable": ["ultra", "tablet"], "tv": ["low", "tv"], "chromebook": ["high", "desktop"], "desktop": ["ultra", "desktop"]}
	for k in want:
		var c := DeviceCaps.normalize(F[k])
		t.check(c["capability_class"] == want[k][0], "compat class: %s -> %s (got %s, score %d)" % [k, want[k][0], c["capability_class"], c["capability_score"]])
		t.check(c["form_factor"] == want[k][1], "compat form: %s -> %s (got %s)" % [k, want[k][1], c["form_factor"]])
	t.check(DeviceCaps.normalize(F["foldable"])["foldable"] and not DeviceCaps.normalize(F["tablet"])["foldable"], "compat form: foldable detected only on the near-square inner screen")
	t.check(DeviceCaps.capability_class({"ram_mb": 2500, "cpu_cores": 16, "compute": "vulkan", "renderer": "forward_plus", "gpu": "GeForce"}) == "low", "compat class: < 3 GB RAM is always low")
	t.check(DeviceCaps.capability_class({"ram_mb": 5000, "cpu_cores": 16, "compute": "vulkan", "renderer": "forward_plus", "gpu": "GeForce", "refresh_hz": 144.0, "astc": true}) == "high", "compat class: < 6 GB RAM is at most high")
	t.check(DeviceCaps.score({}) >= 0 and DeviceCaps.score(F["desktop"]) <= 100, "compat score: bounded 0..100")
	# ---------- AutoConfig mapping ----------
	var tiers := {"low_phone": "low", "mid_phone": "med", "high_phone": "high", "ultra_phone": "ultra"}
	for k in tiers: t.check(AutoConfig.derive(F[k])["tier"] == tiers[k], "autoconfig: %s recommends tier %s" % [k, tiers[k]])
	t.check(AutoConfig.derive(F["mid_phone"])["ui_scale"] == 1.0 and AutoConfig.derive(F["tablet"])["ui_scale"] > 1.0 and AutoConfig.derive(F["tv"])["ui_scale"] > AutoConfig.derive(F["desktop"])["ui_scale"], "autoconfig: compact on phones, larger on tablet/desktop, largest on TV")
	t.check(AutoConfig.derive(F["mid_phone"])["input_scheme"] == "touch" and AutoConfig.derive(F["tv"])["input_scheme"] == "gamepad" and AutoConfig.derive(F["desktop"])["input_scheme"] == "kbm", "autoconfig: input scheme touch / gamepad (TV) / kbm (desktop)")
	t.check(AutoConfig.derive(F["mid_phone"].merged({"gamepads": 1}, true))["input_scheme"] == "gamepad", "autoconfig: a gamepad on a phone switches to gamepad")
	t.check(AutoConfig.derive(F["mid_phone"].merged({"xr": true}, true))["input_scheme"] == "xr", "autoconfig: XR runtime -> xr scheme")
	t.check(AutoConfig.derive(F["desktop"])["perf_profile"] == "performance" and AutoConfig.derive(F["mid_phone"])["perf_profile"] == "balanced", "autoconfig: desktop performance, phone balanced")
	var lb: Dictionary = AutoConfig.derive(F["low_phone"])["budgets"]; var ub: Dictionary = AutoConfig.derive(F["ultra_phone"])["budgets"]
	t.check(lb["companion_ai_hz"] < ub["companion_ai_hz"] and lb["particle_budget"] < ub["particle_budget"] and lb["view_distance_hint"] < ub["view_distance_hint"], "autoconfig: budgets scale with class")
	t.check(lb["fps_cap_hint"] == 30 and ub["fps_cap_hint"] == 60, "autoconfig: low phones cap at 30 fps, others 60 (balanced)")
	t.check(AutoConfig.derive(F["tv"])["budgets"]["streaming_threads"] <= 3, "autoconfig: streaming threads <= cores - 1")
	# ---------- prefs win ----------
	var man := AutoConfig.derive(F["low_phone"], {"tier": "ultra", "input_scheme": "kbm", "perf_profile": "performance", "ui_scale": 1.4})
	t.check(man["tier"] == "ultra" and man["tier_manual"] and man["input_scheme"] == "kbm" and man["perf_profile"] == "performance" and man["ui_scale"] == 1.4, "autoconfig: manual choices always win")
	# ---------- features ----------
	FeatureRegistry.reset_for_tests()
	var lf: Dictionary = AutoConfig.derive(F["low_phone"])["features"]
	t.check(not lf["compute_effects"]["on"] and lf["compute_effects"]["reason"].contains("Vulkan"), "features: compute effects off on GLES3 with a reason")
	t.check(not lf["hi_res_textures"]["on"] and lf["hi_res_textures"]["reason"].contains("GB"), "features: hi-res textures off under 6 GB with a reason")
	t.check(lf["voice_chat"]["on"] and lf["camera_capture"]["on"], "features: unknown mic/camera never disables (Android needs permission first)")
	var nf: Dictionary = FeatureRegistry.evaluate(DeviceCaps.normalize({"mic": 0, "camera": 0, "gyro": 0, "network": "none"}))
	t.check(not nf["voice_chat"]["on"] and not nf["camera_capture"]["on"] and not nf["gyro_look"]["on"] and not nf["live_ai"]["on"], "features: definite no mic/camera/gyro/network disables")
	t.check(not nf["xr_mode"]["on"] and nf["xr_mode"]["reason"] != "", "features: XR future item off without a headset")
	FeatureRegistry.register("tv_only_test", "TV thing", {"form_factors": ["tv"]})
	t.check(FeatureRegistry.evaluate(DeviceCaps.normalize(F["tv"]))["tv_only_test"]["on"] and not FeatureRegistry.evaluate(DeviceCaps.normalize(F["mid_phone"]))["tv_only_test"]["on"], "features: systems can register their own requirements")
	FeatureRegistry.reset_for_tests()

static func run_overrides(t: Node) -> void:
	var F := fakes()
	var ac: Node = t.get_node("/root/AutoConfig")
	var dp: Node = t.get_node("/root/DeviceProfile")
	var saved_store: ConfigFile = ac.store
	var st := ConfigFile.new()
	st.set_value("graphics", "quality", 1)   # what Settings writes on first run
	ac.store = st
	dp.set_fake(F["high_phone"])
	var p: Dictionary = ac.apply(true)
	t.check(st.get_value("graphics", "quality") == 2 and "legacy_quality" in p["applied"], "overrides: untouched default gets the auto value")
	dp.set_fake(F["low_phone"]); p = ac.apply(true)
	t.check(st.get_value("graphics", "quality") == 0, "overrides: auto value follows the device while untouched")
	st.set_value("graphics", "quality", 2)   # the user picks High by hand
	dp.set_fake(F["mid_phone"]); p = ac.apply(true)
	t.check(st.get_value("graphics", "quality") == 2 and "legacy_quality" in p["kept"], "overrides: a manual choice is never overwritten")
	ac.choose("input_scheme", "gamepad")
	t.check(ac.last_plan["input_scheme"] == "gamepad" and ac.last_plan["input_manual"], "overrides: choose() pins the input scheme")
	ac.choose("data_saver", "on")
	t.check(ac.last_plan["data_mode"] == "saver", "overrides: Data saver On forces saver on Wi-Fi")
	var aq := _FakeAQ.new(); aq.name = "AutoQuality"; t.get_tree().root.add_child(aq)
	ac.apply(true)
	t.check(aq.recommended == "med" and aq.profile != "", "AutoQuality hook: recommends the tier + power profile while in auto")
	aq.mode = "high"; aq.recommended = ""
	ac.apply(true)
	t.check(aq.recommended == "" and "tier" in ac.last_plan["kept"], "AutoQuality hook: a manual tier in Foxy's governor is left alone")
	ac.reset_to_auto()
	t.check(aq.mode == "auto" and str(st.get_value("compat", "input_scheme")) == "auto" and str(st.get_value("compat", "data_saver")) == "auto", "overrides: Reset to auto clears every choice")
	aq.queue_free(); t.get_tree().root.remove_child(aq)
	# live change -> caps_changed -> apply (no polling)
	var before: int = ac.apply_count
	dp.set_fake(F["mid_phone"].merged({"gamepads": 1}, true))
	t.check(ac.apply_count > before and ac.last_plan["input_scheme"] == "gamepad", "autoconfig: re-applies on caps_changed (gamepad connected)")
	dp.set_fake(null)
	ac.store = saved_store
	ac.apply()

class _FakeAQ extends Node:
	var mode := "auto"; var recommended := ""; var profile := ""; var fps := 0
	func set_tier(n: String) -> void: mode = n
	func get_tier() -> String: return "med" if mode == "auto" else mode
	func get_mode() -> String: return mode
	func recommend_tier(n: String) -> void: recommended = n
	func set_power_profile(p: String) -> void: profile = p
	func set_fps_cap_hint(f: int) -> void: fps = f

## PowerData + data saver + dormancy (COMPAT-PWR).
static func run_power(t: Node) -> void:
	var F := fakes()
	var mid: Dictionary = F["mid_phone"]
	var normal := AutoConfig.derive(mid)
	t.check(normal["power_mode"] == "balanced-saver" and normal["data_mode"] == "normal", "power: default is balanced-saver")
	var scen := {"battery 20%": {"battery_pct": 20}, "power saver": {"power_save": 1}, "thermal 3": {"thermal": 3}, "mobile data": {"network": "cell"}}
	for k in scen:
		var p := AutoConfig.derive(mid.merged(scen[k], true))
		var b: Dictionary = p["budgets"]; var nb: Dictionary = normal["budgets"]
		t.check(p["power_mode"] == "saver" and not (p["power_reasons"] as Array).is_empty(), "power: %s -> saver with a reason" % k)
		t.check(b["companion_ai_hz"] < nb["companion_ai_hz"] and b["sim_tick_hz"] <= nb["sim_tick_hz"] and b["script_budget_ms"] <= nb["script_budget_ms"] and b["sync_send_hz"] < nb["sync_send_hz"] and b["streaming_threads"] <= nb["streaming_threads"], "power: %s steps down AI / sim / script / sync / streaming" % k)
		t.check(b["image_px"] < nb["image_px"] and b["media_audio_kbps"] < nb["media_audio_kbps"] and b["fps_cap_hint"] == 30, "power: %s lowers images, bitrate and the fps hint" % k)
	t.check(AutoConfig.derive(mid.merged({"battery_pct": 20, "charging": 1}, true))["power_mode"] != "saver", "power: low battery while charging is not a saver trigger")
	t.check(AutoConfig.derive(mid.merged({"thermal": 2}, true))["power_mode"] == "balanced-saver", "power: thermal below 3 stays balanced")
	var full := AutoConfig.derive(mid.merged({"charging": 1, "network": "wifi"}, true))
	t.check(full["power_mode"] == "full" and full["budgets"]["prefetch"] and full["data_mode"] == "full", "power: charger + Wi-Fi -> full quality and prefetch")
	var bg := AutoConfig.derive(mid, {}, true)
	var bb: Dictionary = bg["budgets"]
	t.check(bg["power_mode"] == "background" and bb["companion_ai_hz"] == 0 and bb["sim_tick_hz"] == 0 and bb["script_budget_ms"] == 0 and bb["streaming_threads"] == 0 and bb["keepalive_s"] > 0, "power: background pauses sims, scripts, streaming; keepalive only")
	t.check(AutoConfig.derive(mid, {"perf_profile": "performance"}, true)["perf_profile"] == "battery_saver", "power: background pause applies even with a manual profile")
	var cell := AutoConfig.derive(mid.merged({"network": "cell"}, true))
	t.check(cell["data_mode"] == "saver" and not cell["budgets"]["autoplay"] and cell["budgets"]["thumbnails_only"] and cell["budgets"]["defer_large_downloads"], "data saver: on cell no autoplay, thumbnails only, big downloads wait for Wi-Fi")
	t.check(AutoConfig.derive(mid.merged({"network": "cell"}, true), {"data_saver": "off"})["data_mode"] == "normal", "data saver: Off wins over cell")
	t.check(AutoConfig.derive(mid, {"data_saver": "on"})["data_mode"] == "saver", "data saver: On wins over Wi-Fi")
	# ---------- Net ----------
	var saved_mode: String = Net.mode
	Net.set_data_mode("saver")
	t.check(Net.media_kbps("audio") == 64 and Net.thumbnails_only() and not Net.autoplay_ok() and not Net.large_download_ok(10 * 1024 * 1024) and Net.large_download_ok(1024), "net: saver mode readers")
	Net.set_data_mode("bogus"); t.check(Net.mode == "normal", "net: unknown mode falls back to normal")
	Net.set_data_mode(saved_mode)
	var msgs := []
	for i in 50: msgs.append({"id": i, "pos": [i, 0, 0], "kind": "move"})
	var frame := Net.pack(msgs)
	t.check(frame[1] == 1 and frame.size() < JSON.stringify(msgs).length(), "net: batch is deflate-compressed (%d bytes)" % frame.size())
	t.check(Net.unpack(frame) == JSON.parse_string(JSON.stringify(msgs)), "net: pack/unpack round trip")
	t.check(Net.pack([{"a": 1}])[1] == 0 and Net.unpack(Net.pack([{"a": 1}])).size() == 1, "net: tiny frames stay raw")
	t.check(Net.unpack(PackedByteArray([1, 2, 3])).is_empty(), "net: junk frames rejected")
	var a := {"hp": 10, "pos": [1, 2], "gone": true}; var b2 := {"hp": 9, "pos": [1, 2], "new": "x"}
	var dl := Net.delta(a, b2)
	t.check(dl["set"].size() == 2 and dl["del"] == ["gone"] and Net.apply_delta(a, dl) == b2, "net: state delta sends only changes and rebuilds the state")
	t.check(Net.is_empty_delta(Net.delta(b2, b2)), "net: no change -> empty delta")
	var root := "user://test_net_%d" % Time.get_ticks_usec()
	var saved_root: String = Net.cache_root
	Net.reset_cache_for_tests(root)
	var u := "https://example.invalid/a.json"
	t.check(Net.request_headers(u).is_empty(), "http cache: no validators before the first fetch")
	Net.on_response(u, 200, PackedStringArray(["ETag: \"v1\"", "Last-Modified: Sat, 17 Oct 2026 10:00:00 GMT"]), "hello".to_utf8_buffer())
	var hs := Net.request_headers(u)
	t.check("If-None-Match: \"v1\"" in hs and hs.size() == 2, "http cache: ETag + Last-Modified revalidation headers")
	t.check(Net.on_response(u, 304, PackedStringArray(), PackedByteArray()).get_string_from_utf8() == "hello", "http cache: 304 returns the cached body")
	Net.on_response("https://example.invalid/n", 200, PackedStringArray(["ETag: x", "Cache-Control: no-store"]), "s".to_utf8_buffer())
	t.check(Net.request_headers("https://example.invalid/n").is_empty(), "http cache: no-store is respected")
	Net.reset_cache_for_tests(saved_root)
	Net.reset_session(); Net.count(1048576, 1048576)
	t.check(Net.session_mb() == 2.0, "net: session data counter")
	Net.reset_session()
	# ---------- Dormancy ----------
	Dormancy.reset_for_tests()
	var got := {"e": 0.0, "n": 0}
	Dormancy.register("region_a", Vector3.ZERO, func(e): got["e"] = e; got["n"] += 1, 50.0, "region")
	Dormancy.update([Vector3(10, 0, 0)], 0.0)
	t.check(not Dormancy.is_dormant("region_a"), "dormancy: awake with a viewer nearby")
	Dormancy.update([Vector3(55, 0, 0)], 1.0)
	t.check(not Dormancy.is_dormant("region_a"), "dormancy: hysteresis band keeps it awake")
	Dormancy.update([Vector3(500, 0, 0)], 2.0); Dormancy.update([Vector3(500, 0, 0)], 5.0)
	t.check(not Dormancy.is_dormant("region_a"), "dormancy: waits SLEEP_DELAY before sleeping")
	var r := Dormancy.update([Vector3(500, 0, 0)], 13.0)
	t.check(Dormancy.is_dormant("region_a") and r["slept"] == ["region_a"], "dormancy: sleeps with no viewer")
	r = Dormancy.update([Vector3(0, 0, 0)], 3613.0)
	t.check(r["woke"] == ["region_a"] and got["n"] == 1 and is_equal_approx(got["e"], 3600.0), "dormancy: ONE catch-up call with the elapsed time (no tick replay)")
	Dormancy.set_background(true, 4000.0)
	t.check(Dormancy.is_dormant("region_a") and Dormancy.update([Vector3.ZERO], 4001.0)["woke"].is_empty(), "dormancy: background sleeps everything; nothing wakes while backgrounded")
	Dormancy.set_background(false, 4100.0); Dormancy.update([Vector3.ZERO], 4100.0)
	t.check(not Dormancy.is_dormant("region_a") and got["n"] == 2, "dormancy: foreground + viewer wakes and catches up")
	Dormancy.reset_for_tests()
	t.check(is_equal_approx(Dormancy.ff_decay(100.0, 60.0, 120.0), 25.0) and is_equal_approx(Dormancy.ff_toward(0.0, 10.0, 30.0, 30.0), 5.0), "dormancy math: decay and ease-toward by half-life")
	t.check(Dormancy.ff_linear(90.0, 1.0, 50.0, 0.0, 100.0) == 100.0 and Dormancy.ff_ticks(10.0, 2.0) == 20 and Dormancy.ff_ticks(1e9, 1.0, 500) == 500, "dormancy math: clamped linear and capped ticks")

static func run_ui(t: Node) -> void:
	var s := DeviceCompatScreen.open(t.get_tree().root)
	await t.get_tree().process_frame
	for n in ["BatteryData", "Applied", "FeaturesOff", "Detected", "Redetect", "ResetAuto", "DataSaver_auto", "DataSaver_on", "DataSaver_off"]:
		t.check(s.find_child(n, true, false) != null, "device ui: has " + n)
	t.check(s.min_font_ok(PhoenixTokens.TYPE["label"]) and s.min_tap_ok(PhoenixTokens.TAP_MIN), "device ui: compact sizes, taps >= TAP_MIN")
	t.check(s.find_child("*LineEdit*", true, false) == null, "device ui: read-only (no text fields)")
	var dp: Node = t.get_node("/root/DeviceProfile")
	var n0: int = dp.detect_count
	(s.find_child("Redetect", true, false) as Button).pressed.emit()
	t.check(dp.detect_count == n0 + 1, "device ui: Re-detect runs detection")
	s.queue_free()
	await t.get_tree().process_frame

static func run_docs(t: Node) -> void:
	for f in ["res://docs/modules/DEVICE_COMPAT.md", "res://docs/modules/POWER_AND_DATA.md", "res://docs/specs/foxy/device_profile_caps.md", "res://docs/specs/foxy/power_data.md", "res://docs/specs/foxy/device_compat_client.md", "res://docs/wiki/device-compatibility.md", "res://docs/wiki/battery-and-data.md"]:
		t.check(FileAccess.file_exists(f), "compat docs: " + f.get_file())
	var dc := FileAccess.get_file_as_string("res://docs/modules/DEVICE_COMPAT.md")
	t.check(dc.contains("never uploaded") and dc.contains("Android TV") and dc.contains("ChromeOS"), "compat docs: privacy statement + platform matrix")
	var vp := FileAccess.get_file_as_string("res://docs/modules/VIEWER_PARITY.md")
	t.check(vp.contains("## Device compatibility") and vp.contains("## Power & data"), "compat docs: parity table sections")
	var idx := FileAccess.get_file_as_string("res://docs/wiki/INDEX.md")
	t.check(idx.contains("device-compatibility.md") and idx.contains("battery-and-data.md"), "compat docs: wiki INDEX links")
	var csv := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	t.check(csv.contains("\nCOMPAT-1,") and csv.contains("\nCOMPAT-PWR-1,") and not csv.contains("\r"), "compat docs: tracker rows, LF endings")
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	t.check(wiki is Dictionary and wiki.has("DeviceCompat") and wiki.has("DeviceCompatibility") and wiki.has("PowerAndData"), "compat docs: wiki seed pages")
