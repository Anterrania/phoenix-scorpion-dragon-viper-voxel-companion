class_name SettingsScreen
extends Control
## Viper OS Settings (Admin header ⚙ / Security "Display & text size"). Four swipe tabs:
##  Display   - Large (one tap), Text size, Icon & button size, Max view, Orientation (Auto-rotate/Portrait)
##  Device    - Device check: Android permissions, mic driver, camera feeds, TTS; "Ask for permissions"
##  Voice     - voice morph preset (VoiceFx), Lip sync on/off, mic test with live level
##  Broadcast - stream entries + parcel media URL (Broadcast stub; keys saved encrypted only)
## Every size is read from PhoenixTokens, and the screen rebuilds when the display settings change.
signal closed

const TABS := ["Display", "Device", "Voice", "Broadcast"]
var pages: SwipePages
var boxes := {}
var mic: MicCapture
var mic_bar: ProgressBar
var last_msg := ""
var _margin: MarginContainer
var _building := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = PhoenixTokens.VOID; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	mic = MicCapture.new(); add_child(mic)
	mic.level.connect(func(r): if is_instance_valid(mic_bar): mic_bar.value = clampf(r * 8.0, 0.0, 1.0))
	var st := get_node_or_null("/root/Settings")
	if st: st.display_changed.connect(_rebuild_deferred)
	get_tree().on_request_permissions_result.connect(func(_p, _g): if is_instance_valid(self): refresh_tab("Device"))
	build()

func _rebuild_deferred() -> void:
	if not _building: call_deferred("build")

func build() -> void:
	_building = true
	var keep := pages.current() if pages else 0
	if _margin: remove_child(_margin); _margin.queue_free()
	_margin = MarginContainer.new(); _margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_top", PhoenixTokens.space(6)); _margin.add_theme_constant_override("margin_bottom", PhoenixTokens.space(5))
	add_child(_margin)
	DisplaySettings.attach_responsive(_margin)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.space(4)); _margin.add_child(v)
	var head := HBoxContainer.new()
	var t := Label.new(); t.text = "Settings"; t.theme_type_variation = &"TitleLabel"
	t.add_theme_font_size_override("font_size", PhoenixTokens.fs("title"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap())
	x.add_theme_font_size_override("font_size", PhoenixTokens.fs("headline"))
	x.pressed.connect(func(): mic.stop(); closed.emit(); queue_free()); head.add_child(x)
	v.add_child(head)
	pages = SwipePages.new(); pages.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(pages)
	boxes.clear()
	for n in TABS:
		var sc := ScrollContainer.new(); sc.name = n; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var b := VBoxContainer.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_constant_override("separation", PhoenixTokens.space(4)); sc.add_child(b)
		pages.add_page(n, sc); boxes[n] = b
	pages.go(keep)
	for n in TABS: refresh_tab(n)
	_building = false

# ---------- helpers (all sizes from PhoenixTokens) ----------
func _text(s: String, col := PhoenixTokens.PLATINUM, role := "body") -> Label:
	var l := Label.new(); l.text = s; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", PhoenixTokens.fs(role)); l.add_theme_color_override("font_color", col)
	return l

func _btn(s: String, f: Callable) -> Button:
	var b := Button.new(); b.text = s; b.custom_minimum_size = Vector2(0, PhoenixTokens.tap())
	b.add_theme_font_size_override("font_size", PhoenixTokens.fs("body")); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(f)
	return b

func _toggle(s: String, on: bool, f: Callable) -> CheckButton:
	var c := CheckButton.new(); c.text = s; c.button_pressed = on; c.custom_minimum_size = Vector2(0, PhoenixTokens.tap())
	c.add_theme_font_size_override("font_size", PhoenixTokens.fs("body")); c.toggled.connect(f)
	return c

func _slider(lo: float, hi: float, val: float, f: Callable) -> HSlider:
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 0.05; s.value = val
	s.custom_minimum_size = Vector2(0, PhoenixTokens.tap()); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.drag_ended.connect(func(changed): if changed: f.call(s.value))
	return s

func _pills(opts: Array, sel: String, f: Callable) -> SegmentedPills:
	var p := SegmentedPills.new(); p.setup(opts, sel)
	for b in p.get_children(): (b as Button).add_theme_font_size_override("font_size", PhoenixTokens.fs("body"))
	p.changed.connect(f)
	return p

func _clear(b: VBoxContainer) -> void:
	for c in b.get_children(): b.remove_child(c); c.queue_free()

func toast(s: String, variant := "ok") -> void:
	last_msg = s
	Toast.show_toast(self, s, variant)

func refresh_tab(n: String) -> void:
	if not boxes.has(n): return
	_clear(boxes[n])
	match n:
		"Display": _display(boxes[n])
		"Device": _device(boxes[n])
		"Voice": _voice(boxes[n])
		"Broadcast": _broadcast(boxes[n])

# ---------- Display ----------
func _display(b: VBoxContainer) -> void:
	var c := ViperKit.card("Text & buttons"); b.add_child(c)
	c.body().add_child(_toggle("Large text & buttons", DisplaySettings.is_large(), func(on): DisplaySettings.set_large(on)))
	c.body().add_child(_text("Text size  %d%%" % roundi(DisplaySettings.text_scale() * 100)))
	var ts := _slider(PhoenixTokens.TEXT_MIN, PhoenixTokens.TEXT_MAX, DisplaySettings.text_scale(), func(v): DisplaySettings.set_text_scale(v))
	ts.name = "TextSize"; c.body().add_child(ts)
	c.body().add_child(_text("Icon & button size  %d%%" % roundi(DisplaySettings.icon_scale() * 100)))
	var isz := _slider(PhoenixTokens.ICON_MIN, PhoenixTokens.ICON_MAX, DisplaySettings.icon_scale(), func(v): DisplaySettings.set_icon_scale(v))
	isz.name = "IconSize"; c.body().add_child(isz)
	c.body().add_child(_text("Smallest is the default (compact). Large is one tap above.", PhoenixTokens.PLATINUM_DIM, "label"))
	var lay := ViperKit.card("Layout"); b.add_child(lay)
	lay.body().add_child(_toggle("Max view (show the most)", DisplaySettings.max_view(), func(on): DisplaySettings.set_max_view(on)))
	lay.body().add_child(_text("Orientation", PhoenixTokens.PLATINUM, "body"))
	var opts := DisplaySettings.ORIENTATIONS.map(func(o): return [o, DisplaySettings.ORIENTATION_LABELS[o]])
	lay.body().add_child(_pills(opts, DisplaySettings.orientation(), func(o): DisplaySettings.set_orientation(o)))
	b.add_child(_btn("Reset to compact", func(): DisplaySettings.reset(); toast("Back to compact")))

# ---------- Device ----------
func _device(b: VBoxContainer) -> void:
	var rows := DeviceCheck.report()
	var c := ViperKit.card("Device check · " + DeviceCheck.summary(rows)); b.add_child(c)
	for r in rows:
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", PhoenixTokens.space(3))
		var dot := _text("●" if r["ok"] else "○", PhoenixTokens.OK if r["ok"] else PhoenixTokens.WARN)
		h.add_child(dot)
		var l := _text(str(r["label"])); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		h.add_child(_text(str(r["state"]), PhoenixTokens.PLATINUM_DIM, "label"))
		c.body().add_child(h)
	b.add_child(_btn("Ask for permissions", func(): DeviceCheck.request_all(); toast("Asked. Answer on the phone's prompt.")))
	b.add_child(_btn("Check again", func(): refresh_tab("Device")))
	b.add_child(_text("Camera and microphone are asked for when you first use them, too.", PhoenixTokens.PLATINUM_DIM, "label"))

# ---------- Voice ----------
func _voice(b: VBoxContainer) -> void:
	var st := get_node_or_null("/root/Settings")
	var c := ViperKit.card("Voice morph"); b.add_child(c)
	var opts: Array = []
	for k in VoiceFx.PRESETS: opts.append([k, VoiceFx.PRESETS[k]["label"]])
	var row1 := opts.slice(0, 3); var row2 := opts.slice(3)
	var cur := VoiceFx.current_preset()
	for row in [row1, row2]:
		var pr := SegmentedPills.new(); pr.setup(row, cur if row.any(func(o): return o[0] == cur) else "__none")
		for btn in pr.get_children(): (btn as Button).add_theme_font_size_override("font_size", PhoenixTokens.fs("body"))
		pr.changed.connect(func(id):
			if st: st.set_value("voice_fx", "preset", id)
			mic.set_preset(id); refresh_tab("Voice"))
		c.body().add_child(pr)
	c.body().add_child(_text("Changes your mic voice and the companions' speaking pitch.", PhoenixTokens.PLATINUM_DIM, "label"))
	var lip := bool(st.get_value("voice_fx", "lip_sync", true)) if st else true
	c.body().add_child(_toggle("Lip sync", lip, func(on): if st: st.set_value("voice_fx", "lip_sync", on)))
	var m := ViperKit.card("Microphone test"); b.add_child(m)
	mic_bar = ProgressBar.new(); mic_bar.max_value = 1.0; mic_bar.show_percentage = false
	mic_bar.custom_minimum_size = Vector2(0, PhoenixTokens.space(5)); m.body().add_child(mic_bar)
	m.body().add_child(_btn("Stop mic" if mic.running else "Start mic", func():
		if mic.running: mic.stop()
		elif not mic.start(): toast(mic.last_error, "warn")
		refresh_tab("Voice")))
	m.body().add_child(_toggle("Hear myself (use headphones)", mic.monitor, func(on):
		mic.monitor = on
		if mic.running: mic.start()))

# ---------- Broadcast ----------
var _bc_title: LineEdit
var _bc_url: LineEdit
var _bc_parcel: LineEdit
var _bc_key: LineEdit
func _field(ph: String, secret := false) -> LineEdit:
	var e := LineEdit.new(); e.placeholder_text = ph; e.secret = secret
	e.custom_minimum_size = Vector2(0, PhoenixTokens.tap()); e.add_theme_font_size_override("font_size", PhoenixTokens.fs("body"))
	return e

func _broadcast(b: VBoxContainer) -> void:
	var can := Tiers.can(Tiers.SELF, "broadcast")
	b.add_child(_text("Streaming isn't switched on yet. Entries and keys are saved for when it is.", PhoenixTokens.WARN, "label"))
	var c := ViperKit.card("Streams"); b.add_child(c)
	var ls := Broadcast.list()
	if ls.is_empty(): c.body().add_child(_text("No streams yet.", PhoenixTokens.PLATINUM_DIM))
	for s in ls:
		c.body().add_child(_text("%s · %s · %s%s" % [s["title"], s["parcel"], s["status"], " · key saved" if s["has_key"] else ""]))
		var sid: String = s["id"]
		c.body().add_child(_btn("Go live (owner approves)", func():
			var r := Broadcast.go_live(Tiers.SELF, sid); toast(str(r.get("error", "Approved")), "ok" if r["ok"] else "warn"); refresh_tab("Broadcast")))
	var a := ViperKit.card("Add a stream"); b.add_child(a)
	if not can:
		a.body().add_child(_text("Creators and up can add streams. Owner: unlock in Security.", PhoenixTokens.PLATINUM_DIM)); return
	_bc_title = _field("Title"); _bc_url = _field("rtmps://… ingest address"); _bc_parcel = _field("Region/parcel, e.g. welcome/stage")
	_bc_key = _field("Stream key (saved encrypted)", true)
	for e in [_bc_title, _bc_url, _bc_parcel, _bc_key]: a.body().add_child(e)
	a.body().add_child(_btn("Save stream", func(): toast(save_stream(_bc_title.text, _bc_url.text, _bc_parcel.text, _bc_key.text)); refresh_tab("Broadcast")))
	var pm := ViperKit.card("Parcel media"); b.add_child(pm)
	var mu := _field("https://… video or stream for this parcel"); var mp := _field("Region/parcel")
	pm.body().add_child(mp); pm.body().add_child(mu)
	pm.body().add_child(_btn("Set parcel media", func():
		var r := Broadcast.set_parcel_media(Tiers.SELF, mp.text.strip_edges(), mu.text.strip_edges())
		toast(str(r.get("error", "Parcel media set")), "ok" if r["ok"] else "warn")))

## Save a stream (+ optional key). Returns the message shown. Also used by tests.
func save_stream(title: String, url: String, parcel: String, key: String) -> String:
	var kind := "rtmps" if url.begins_with("rtmps://") else ("rtmp" if url.begins_with("rtmp://") else "hls")
	var r := Broadcast.add_stream(Tiers.SELF, title, kind, url.strip_edges(), parcel.strip_edges())
	if not r["ok"]: return r["error"]
	if key.strip_edges() != "":
		var k := Broadcast.set_stream_key(Tiers.SELF, r["id"], key)
		if not k["ok"]: return "Stream saved. " + str(k["error"])
	return "Stream saved"

# ---------- test helpers ----------
func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children(): _walk(c, out)

func min_tap_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if n is BaseButton and n.custom_minimum_size.y < px and not n.get_parent() is TabBar: return false
	return true

func min_font_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if (n is Label or n is Button) and n.has_theme_font_size_override("font_size") and n.get_theme_font_size("font_size") < px: return false
	return true

## Open (or focus) Settings on top of `host`'s parent overlay layer. tab: "Display", "Device", ...
static func open_in(host: Node, tab := "Display") -> SettingsScreen:
	var layer := host.get_parent() if host.get_parent() else host
	var s: SettingsScreen = layer.get_node_or_null("SettingsScreen")
	if s == null:
		s = SettingsScreen.new(); s.name = "SettingsScreen"; layer.add_child(s)
	s.pages.go(TABS.find(tab))
	return s
