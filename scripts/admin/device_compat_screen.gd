class_name DeviceCompatScreen
extends Control
## Settings > Device & compatibility (admin Home menu > ▣ Device). READ-ONLY report of what DeviceProfile
## detected and what AutoConfig applied, plus three actions: Re-detect, Reset to auto, Data saver Auto/On/Off.
## Sections: Battery & data · Applied · Features off · Detected · Device check (the phone branch's
## DeviceCheck rows, reused when that script is on main; no second permissions panel).
## When feature/phone-display-media merges, its SettingsScreen "Device" tab should call
## DeviceCompatScreen.build_into(box) and this standalone screen can be marked INACTIVE.
## PRIVACY: values shown here stay on the phone. Nothing is uploaded.
signal closed

var body: VBoxContainer
var last_msg := ""

static func open(parent: Node) -> DeviceCompatScreen:
	var ex := parent.get_node_or_null("DeviceCompatScreen")
	if ex: return ex
	var s := DeviceCompatScreen.new(); s.name = "DeviceCompatScreen"
	parent.add_child(s)
	return s

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = PhoenixTokens.VOID; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "bottom"]: m.add_theme_constant_override("margin_" + s, PhoenixTokens.SPACE[4])
	m.add_theme_constant_override("margin_top", PhoenixTokens.SPACE[5])
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.SPACE[3]); m.add_child(v)
	var head := HBoxContainer.new()
	var t := Label.new(); t.text = "Device & compatibility"; t.theme_type_variation = &"TitleLabel"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN, PhoenixTokens.TAP_MIN)
	x.pressed.connect(func(): closed.emit(); queue_free()); head.add_child(x)
	v.add_child(head)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", PhoenixTokens.SPACE[3]); sc.add_child(body)
	var ac := get_node_or_null("/root/AutoConfig")
	if ac: ac.applied.connect(func(_p): if is_instance_valid(self): refresh())
	refresh()

func refresh() -> void:
	for ch in body.get_children(): body.remove_child(ch); ch.queue_free()
	build_into(body, self)

# ---------- shared builder (also for the phone branch's Settings > Device tab) ----------
static func _row(box: Control, k: String, v: String, warn := false) -> void:
	var h := HBoxContainer.new()
	var a := Label.new(); a.text = k; a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_font_size_override("font_size", PhoenixTokens.TYPE["label"]); a.add_theme_color_override("font_color", PhoenixTokens.PLATINUM_DIM)
	var b := Label.new(); b.text = v; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_size_override("font_size", PhoenixTokens.TYPE["label"]); b.add_theme_color_override("font_color", PhoenixTokens.WARN if warn else PhoenixTokens.PLATINUM)
	h.add_child(a); h.add_child(b); box.add_child(h)

static func _btn(text: String, f: Callable, nm := "") -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, PhoenixTokens.TAP_MIN)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.add_theme_font_size_override("font_size", PhoenixTokens.TYPE["body"])
	if nm != "": b.name = nm
	b.pressed.connect(f)
	return b

static func _unk(v: Variant) -> String:
	if v is int and v == -1: return "unknown"
	if v is float and v < 0.0: return "unknown"
	if v is String and v == "": return "unknown"
	return str(v)

static func _tri(v: int) -> String: return {-1: "unknown", 0: "no", 1: "yes"}.get(v, "unknown")

## Fills box with the report. host gets toasts; may be null.
static func build_into(box: Control, host: Node = null) -> void:
	var tree := box.get_tree() if box.is_inside_tree() else Engine.get_main_loop() as SceneTree
	var ac: Node = tree.root.get_node_or_null("AutoConfig") if tree else null
	var dp: Node = tree.root.get_node_or_null("DeviceProfile") if tree else null
	if ac == null or dp == null:
		var l := Label.new(); l.text = "Device detection is not running."; box.add_child(l); return
	var plan: Dictionary = ac.last_plan if not ac.last_plan.is_empty() else ac.apply()
	var c: Dictionary = DeviceCaps.normalize(dp.caps())
	var toast := func(t: String): if host and host.is_inside_tree(): Toast.show_toast(host, t, "ok")

	# Battery & data
	var ps: Dictionary = ac.power_summary()
	var bd := ViperKit.card("Battery & data"); bd.name = "BatteryData"; box.add_child(bd)
	_row(bd.body(), "Mode", ps["mode"])
	_row(bd.body(), "Why", ps["why"])
	_row(bd.body(), "Data this session", "%.2f MB" % ps["data_mb"])
	_row(bd.body(), "Media quality", {"full": "High", "normal": "Standard", "saver": "Low (data saver)"}.get(ps["data_mode"], ps["data_mode"]))
	var ds := HBoxContainer.new(); ds.name = "DataSaver"; bd.body().add_child(ds)
	for opt in AutoConfig_DATA_SAVER():
		var b := _btn("Data saver: " + opt.capitalize() if opt == ps["data_saver"] else opt.capitalize(), func(): ac.choose("data_saver", opt); toast.call("Data saver: " + opt.capitalize()), "DataSaver_" + opt)
		b.disabled = opt == ps["data_saver"]
		ds.add_child(b)

	# Applied
	var ap := ViperKit.card("Applied"); ap.name = "Applied"; box.add_child(ap)
	_row(ap.body(), "Device class", "%s (score %d)" % [str(c["capability_class"]).capitalize(), int(c["capability_score"])])
	_row(ap.body(), "Graphics tier", str(plan["tier"]) + (" (your choice)" if plan["tier_manual"] else " (auto)"))
	_row(ap.body(), "Text & icon size", "%.2f×" % float(plan["ui_scale"]) + (" (your choice)" if plan["ui_scale_manual"] else " (auto)"))
	_row(ap.body(), "Controls", {"touch": "Touch", "gamepad": "Gamepad", "kbm": "Keyboard + mouse", "xr": "XR"}.get(plan["input_scheme"], plan["input_scheme"]) + (" (your choice)" if plan["input_manual"] else " (auto)"))
	_row(ap.body(), "Performance", str(plan["perf_profile"]).replace("_", " ").capitalize() + (" (your choice)" if plan["perf_manual"] else " (auto)"))
	var bu: Dictionary = plan["budgets"]
	_row(ap.body(), "Companion AI / sims", "%d Hz / %d Hz" % [bu["companion_ai_hz"], bu["sim_tick_hz"]])
	_row(ap.body(), "View distance hint", "%d m" % bu["view_distance_hint"])
	_row(ap.body(), "Frame cap hint", "%d fps" % bu["fps_cap_hint"])
	if not (plan.get("kept", []) as Array).is_empty(): _row(ap.body(), "Kept your settings", ", ".join(plan["kept"]))

	# Features off
	var off: Array = []
	for id in plan["features"]:
		if not plan["features"][id]["on"]: off.append(id)
	var fo := ViperKit.card("Features off on this device (%d)" % off.size()); fo.name = "FeaturesOff"; box.add_child(fo)
	if off.is_empty(): _row(fo.body(), "All features", "available")
	for id in off: _row(fo.body(), plan["features"][id]["label"], plan["features"][id]["reason"], true)

	# Detected
	var de := ViperKit.card("Detected"); de.name = "Detected"; box.add_child(de)
	_row(de.body(), "System", "%s %s%s" % [_unk(c["os"]), c["os_version"], (" (API %d)" % c["android_api"]) if int(c["android_api"]) > 0 else ""])
	_row(de.body(), "Model", _unk(c["model"]))
	_row(de.body(), "CPU", "%s cores, %s" % [_unk(c["cpu_cores"]), _unk(c["arch"])])
	_row(de.body(), "Memory", ("%.1f GB" % (int(c["ram_mb"]) / 1024.0)) if int(c["ram_mb"]) > 0 else "unknown")
	_row(de.body(), "GPU", "%s · %s" % [_unk(c["gpu"]), _unk(c["gpu_vendor"])])
	_row(de.body(), "Renderer", "%s · compute %s · ASTC %s" % [_unk(c["renderer"]), c["compute"], "yes" if c["astc"] else "no"])
	_row(de.body(), "Screen", ("%d×%d · %d dpi · %.0f Hz" % [c["screen_w"], c["screen_h"], c["dpi"], c["refresh_hz"]]) if int(c["screen_w"]) > 0 else "unknown")
	_row(de.body(), "Form", str(c["form_factor"]).capitalize() + (" (foldable)" if c["foldable"] else "") + (" · " + c["orientation"] if c["orientation"] != "" else ""))
	_row(de.body(), "Input", "touch %s · keyboard %s · gamepads %d" % ["yes" if c["touch"] else "no", "yes" if c["keyboard"] else "no", c["gamepads"]])
	_row(de.body(), "Sensors", "gyro %s · accelerometer %s · vibration %s" % [_tri(c["gyro"]), _tri(c["accelerometer"]), "yes" if c["haptics"] else "no"])
	_row(de.body(), "Camera / mic", "%s / %s" % [_tri(c["camera"]), _tri(c["mic"])])
	_row(de.body(), "Battery", ("%d%%" % c["battery_pct"]) if int(c["battery_pct"]) >= 0 else "unknown (needs the Android plugin)")
	_row(de.body(), "Network", _unk(c["network"]))
	_row(de.body(), "Free storage", ("%.1f GB" % (int(c["storage_free_mb"]) / 1024.0)) if int(c["storage_free_mb"]) > 0 else "unknown")
	_row(de.body(), "Privacy", "Stays on this device. Never uploaded.")

	# Device check (phone branch), reused when present
	const DC := "res://scripts/app/device_check.gd"
	if ResourceLoader.exists(DC):
		var dcs: Script = load(DC)
		var dc := ViperKit.card("Device check · " + str(dcs.call("summary"))); dc.name = "DeviceCheck"; box.add_child(dc)
		for r in dcs.call("report"): _row(dc.body(), str(r["label"]), str(r["state"]), not bool(r["ok"]))

	var acts := HBoxContainer.new(); acts.name = "Actions"; box.add_child(acts)
	acts.add_child(_btn("Re-detect", func(): dp.redetect(); toast.call("Re-detected"), "Redetect"))
	acts.add_child(_btn("Reset to auto", func(): ac.reset_to_auto(); toast.call("Back to automatic settings"), "ResetAuto"))

static func AutoConfig_DATA_SAVER() -> Array: return ["auto", "on", "off"]

# ---------- test helpers (same checks as the other admin screens) ----------
func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children(): _walk(c, out)

func min_font_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if (n is Label or n is Button) and n.is_visible_in_tree() and (n as Control).get_theme_font_size("font_size") < px: return false
	return true

func min_tap_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if n is BaseButton and n.custom_minimum_size.y < px: return false
	return true
