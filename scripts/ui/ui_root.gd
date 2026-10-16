extends CanvasLayer
## v0.5 phone-friendly UI: main menu, wardrobe/satchel, companion chat, travel,
## settings, and the "Where to give input" checklist. Built in code (no .tscn edits).

@export var player_path: NodePath
@export var world_path: NodePath
var player: Node3D
var world: Node
var panels := {}
var chat_log: RichTextLabel
var chat_input: LineEdit
var chat_target: Node = null
var wardrobe_target := "player"
var wardrobe_list: VBoxContainer
var target_row: HBoxContainer

const MAG := Color(1, 0.18, 0.82)
const GOLD := Color(1, 0.82, 0.29)
const FS := 30

func _ready() -> void:
	layer = 10
	player = get_node_or_null(player_path)
	world = get_node_or_null(world_path)
	_topbar()
	panels["menu"] = _build_menu()
	panels["wardrobe"] = _build_wardrobe()
	panels["chat"] = _build_chat()
	panels["travel"] = _build_travel()
	panels["settings"] = _build_settings()
	panels["input"] = _build_input()
	AgentBrain.reply_ready.connect(_on_reply)
	show_panel("menu" if bool(Settings.get_value("ui", "show_menu_on_start", true)) else "")

# ---------- helpers ----------
func _style(bg: Color, border := MAG, radius := 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(14)
	return sb

func btn(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, 84)
	b.add_theme_font_size_override("font_size", FS)
	b.add_theme_stylebox_override("normal", _style(Color(0.08, 0.03, 0.1, 0.9)))
	b.add_theme_stylebox_override("hover", _style(Color(0.16, 0.05, 0.18, 0.95)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.05, 0.28, 0.95), GOLD))
	b.pressed.connect(cb)
	return b

func label(text: String, size := FS, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func input_tag(text := "YOUR INPUT HERE") -> Label:
	var l := label("★ " + text, 24, GOLD)
	l.tooltip_text = "Placeholder - tell Foxy in chat what you want here."
	return l

## Full-screen dimmed panel with title, scrollable body VBox and Close button.
func _panel(title: String) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pc.offset_left = 60; pc.offset_right = -60; pc.offset_top = 30; pc.offset_bottom = -30
	pc.add_theme_stylebox_override("panel", _style(Color(0.05, 0.02, 0.07, 0.95), MAG, 26))
	root.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var head := HBoxContainer.new()
	var t := label(title, 44, GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(btn("✕ Close", func(): show_panel(""), 200))
	v.add_child(head)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	sc.add_child(body)
	add_child(root)
	root.visible = false
	return {"root": root, "body": body, "box": v}

func show_panel(n: String) -> void:
	for k in panels:
		panels[k]["root"].visible = k == n
	if n == "wardrobe": _refresh_wardrobe()
	if n == "chat" and chat_target == null: _pick_chat(_companions().front() if not _companions().is_empty() else null)

func is_open() -> bool:
	for k in panels:
		if panels[k]["root"].visible: return true
	return false

func _companions() -> Array:
	return get_tree().get_nodes_in_group("companions")

func _topbar() -> void:
	var h := HBoxContainer.new()
	h.name = "TopBar"
	h.position = Vector2(24, 58)
	h.add_theme_constant_override("separation", 10)
	h.add_child(btn("☰ MENU", func(): show_panel("menu"), 170))
	h.add_child(btn("👜 BAG", func(): show_panel("wardrobe"), 170))
	h.add_child(btn("💬 TALK", func(): show_panel("chat"), 170))
	add_child(h)

# ---------- main menu ----------
func _build_menu() -> Dictionary:
	var p := _panel("Phoenix Scorpion Dragon Viper · v0.5")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Anterrania — Flamma. Ordo. Aeterna.", 28, MAG))
	for row in [["▶ Play", "" ], ["👜 Wardrobe & Satchel", "wardrobe"], ["💬 Talk to Companions", "chat"], ["🧭 Travel to Landmarks", "travel"], ["⚙ Settings", "settings"], ["★ Where to give input", "input"]]:
		var target: String = row[1]
		b.add_child(btn(row[0], func(): show_panel(target)))
	b.add_child(label("Everything gold-starred (★ YOUR INPUT HERE) is a placeholder waiting for your decision.", 24, GOLD))
	return p

# ---------- wardrobe ----------
func _build_wardrobe() -> Dictionary:
	var p := _panel("Wardrobe & Satchel")
	var b: VBoxContainer = p["body"]
	target_row = HBoxContainer.new()
	b.add_child(target_row)
	wardrobe_list = VBoxContainer.new()
	wardrobe_list.add_theme_constant_override("separation", 8)
	b.add_child(wardrobe_list)
	return p

func _refresh_wardrobe() -> void:
	for c in target_row.get_children(): c.queue_free()
	for c in wardrobe_list.get_children(): c.queue_free()
	var targets := [["You", "player"]]
	for c in _companions(): targets.append([str(c.persona.get("display_name", c.persona.get("name", c.name))).split(" ")[0], c.companion_id])
	for t in targets:
		var tid: String = t[1]
		var bt := btn(("● " if tid == wardrobe_target else "") + t[0], func():
			wardrobe_target = tid
			_refresh_wardrobe(), 160)
		target_row.add_child(bt)
	wardrobe_list.add_child(label("Outfits & colors for: %s" % wardrobe_target, 28, GOLD))
	for it in Inventory.items_for(wardrobe_target):
		var id: String = it["id"]
		var on := Inventory.is_equipped(wardrobe_target, id)
		var row := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(60, 60)
		sw.color = Color(str(it.get("style", {}).get("outfit", it.get("style", {}).get("accent", it.get("style", {}).get("trim", "#ffffff")))))
		row.add_child(sw)
		var bt := btn(("✔ " if on else "") + "%s  [%s]" % [it["name"], it["slot"]], func():
			Inventory.equip(wardrobe_target, id)
			_refresh_wardrobe())
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bt)
		wardrobe_list.add_child(row)
	if not Settings.mature_enabled():
		wardrobe_list.add_child(label("18+ outfits are hidden (Settings › Mature cosmetics, off by default).", 22, Color(0.8, 0.7, 0.9)))
	wardrobe_list.add_child(input_tag("YOUR INPUT HERE: who wears which catalog outfit? Which pieces next?"))
	wardrobe_list.add_child(label("Satchel", 32, GOLD))
	for s in Inventory.satchel:
		wardrobe_list.add_child(label("• %s ×%d — %s" % [s["name"], int(s.get("count", 1)), s.get("desc", "")], 26))

# ---------- chat ----------
func _build_chat() -> Dictionary:
	var p := _panel("Talk to Companions")
	var b: VBoxContainer = p["body"]
	var who := HBoxContainer.new()
	who.name = "Who"
	b.add_child(who)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.fit_content = false
	chat_log.custom_minimum_size = Vector2(0, 300)
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.add_theme_font_size_override("normal_font_size", 28)
	chat_log.add_theme_font_size_override("bold_font_size", 28)
	b.add_child(chat_log)
	var quick := HBoxContainer.new()
	for q in ["Hi!", "Who are you?", "Where should we go?", "Outfit?"]:
		var qq: String = q
		quick.add_child(btn(qq, func(): _send(qq)))
	b.add_child(quick)
	var modes := HBoxContainer.new()
	follow_btn = btn("Mode: Follow me", func():
		if chat_target:
			chat_target.set_follow(not chat_target.following)
			_update_follow())
	follow_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(follow_btn)
	modes.add_child(btn("All follow", func(): _all_follow(true), 190))
	modes.add_child(btn("All roam", func(): _all_follow(false), 190))
	b.add_child(modes)
	var row := HBoxContainer.new()
	var ptt := btn("🎤 Hold", func(): pass, 150)
	ptt.button_down.connect(_ptt_down)
	ptt.button_up.connect(_ptt_up)
	row.add_child(ptt)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Type to your companion…"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size = Vector2(0, 80)
	chat_input.add_theme_font_size_override("font_size", FS)
	chat_input.text_submitted.connect(_send)
	row.add_child(chat_input)
	row.add_child(btn("Send", func(): _send(chat_input.text), 160))
	b.add_child(row)
	b.add_child(input_tag("YOUR INPUT HERE: offline replies are canned from persona files - tell Foxy what each companion should say. Live AI: Settings."))
	call_deferred("_fill_who", who)
	return p

func _fill_who(who: HBoxContainer) -> void:
	for c in _companions():
		var cc: Node = c
		who.add_child(btn(str(c.persona.get("name", c.name)).split(" ")[0], func(): _pick_chat(cc), 160))

var follow_btn: Button
func _update_follow() -> void:
	if follow_btn and chat_target:
		follow_btn.text = "Mode: " + ("Follow me" if chat_target.following else "Free roam (living AI)")

func _all_follow(on: bool) -> void:
	for c in _companions(): c.set_follow(on)
	_update_follow()

## Push-to-talk hook (stub). Future: Android speech-to-text plugin -> _send(text);
## voice chat via WebRTC/Vivox-style server. Mic permission stays off until then.
signal push_to_talk(active: bool)
func _ptt_down() -> void:
	push_to_talk.emit(true)
	if chat_log: chat_log.append_text("[color=#ffd04a]🎤 Voice input coming soon - type for now. (YOUR INPUT HERE: voice chat priority?)[/color]\n")
func _ptt_up() -> void:
	push_to_talk.emit(false)

func _pick_chat(c: Node) -> void:
	chat_target = c
	_update_follow()
	if c and chat_log:
		chat_log.append_text("[color=#ffd04a]— talking to %s (%s) —[/color]\n" % [c.persona.get("name", c.name), "live AI" if Settings.live_ai() else "offline replies"])

func _send(t: String) -> void:
	if t.strip_edges() == "" or chat_target == null: return
	chat_log.append_text("[b]You:[/b] %s\n" % t)
	chat_input.clear()
	chat_target.talk(t)

func _on_reply(id: String, text: String) -> void:
	if chat_target and chat_target.companion_id == id and chat_log:
		chat_log.append_text("[color=#ff8de8]%s:[/color] %s\n" % [chat_target.persona.get("name", id), text])

# ---------- travel ----------
func _build_travel() -> Dictionary:
	var p := _panel("Travel to Landmarks")
	call_deferred("_fill_travel", p["body"])
	return p

func _fill_travel(b: VBoxContainer) -> void:
	var wc: Node = world.get_node_or_null("WorldContent") if world else null
	b.add_child(btn("🏠 Spawn (Alaskan Aurora Tundra)", func(): teleport(Vector3(0, 0, 0))))
	if wc == null: return
	for l in wc.landmarks:
		var pos: Vector3 = l["position"]
		var realm: String = ["Alaska", "Venus", "Cosmic"][int(l["biome"])]
		b.add_child(btn("%s  ·  %s" % [l["name"], realm], func(): teleport(pos + Vector3(0, 0, 20))))
		b.add_child(input_tag("YOUR INPUT HERE: " + " / ".join(PackedStringArray(l["input"]))))

func teleport(p: Vector3) -> void:
	if player == null: return
	var g = world.generator if world and "generator" in world else null
	var y := p.y
	if g: y = maxf(g.height_f(p.x, p.z), g.LAVA_LEVEL) + 3.0
	player.global_position = Vector3(p.x, y, p.z)
	if "velocity" in player: player.velocity = Vector3.ZERO
	for c in _companions():
		c.global_position = player.global_position + Vector3(randf_range(-3, 3), 1.0, randf_range(-3, 3))
	show_panel("")

# ---------- settings ----------
func _build_settings() -> Dictionary:
	var p := _panel("Settings")
	var b: VBoxContainer = p["body"]
	var q := btn("", func(): pass)
	q.text = "Graphics: " + Settings.QUALITY_NAMES[Settings.quality()]
	q.pressed.connect(func(): q.text = "Graphics: " + Settings.QUALITY_NAMES[Settings.cycle_quality()])
	b.add_child(q)
	var cam := btn("Switch 1st / 3rd person", func(): if player and player.has_method("toggle_camera"): player.toggle_camera())
	b.add_child(cam)
	var menu_start := CheckButton.new()
	menu_start.text = "Show this menu when the app starts"
	menu_start.add_theme_font_size_override("font_size", FS)
	menu_start.button_pressed = bool(Settings.get_value("ui", "show_menu_on_start", true))
	menu_start.toggled.connect(func(on): Settings.set_value("ui", "show_menu_on_start", on))
	b.add_child(menu_start)
	b.add_child(label("Companion AI", 32, GOLD))
	var mode := btn("", func(): pass)
	var upd := func(): mode.text = "AI mode: " + ("LIVE (uses API key)" if str(Settings.get_value("llm", "mode", "canned")) == "live" else "OFFLINE canned replies")
	upd.call()
	mode.pressed.connect(func():
		Settings.set_value("llm", "mode", "canned" if str(Settings.get_value("llm", "mode", "canned")) == "live" else "live")
		upd.call())
	b.add_child(mode)
	for f in [["endpoint", "LLM endpoint (OpenAI-compatible)", false], ["model", "Model", false], ["api_key", "API key (stored only on this phone)", true]]:
		b.add_child(label(f[1], 24))
		var le := LineEdit.new()
		le.text = str(Settings.get_value("llm", f[0], ""))
		le.secret = f[2]
		le.custom_minimum_size = Vector2(0, 72)
		le.add_theme_font_size_override("font_size", 26)
		var key: String = f[0]
		le.text_changed.connect(func(t): Settings.set_value("llm", key, t.strip_edges()))
		b.add_child(le)
	b.add_child(label("Voice & Music", 32, GOLD))
	for t in [["voice", "tts_enabled", "Companions speak out loud (text-to-speech)"], ["music", "enabled", "Phoenix Radio music"]]:
		var cb := CheckButton.new()
		cb.text = t[2]
		cb.add_theme_font_size_override("font_size", FS)
		cb.button_pressed = bool(Settings.get_value(t[0], t[1], true))
		var sec: String = t[0]
		var k: String = t[1]
		cb.toggled.connect(func(on): Settings.set_value(sec, k, on))
		b.add_child(cb)
	b.add_child(label("Your radio station URL (MP3/OGG) — ★ YOUR INPUT HERE", 24, GOLD))
	var rl := LineEdit.new()
	rl.text = str(Settings.get_value("music", "user_url", ""))
	rl.placeholder_text = "https://… (blank = royalty-free default)"
	rl.custom_minimum_size = Vector2(0, 72)
	rl.add_theme_font_size_override("font_size", 26)
	rl.text_submitted.connect(func(t):
		Settings.set_value("music", "user_url", t.strip_edges())
		var wc = world.get_node_or_null("WorldContent") if world else null
		if wc and wc.radio: wc.radio.tune(MusicRadio.station_url()))
	b.add_child(rl)
	b.add_child(label("Content", 32, GOLD))
	var age := CheckButton.new()
	age.text = "I confirm I am 18 or older"
	age.add_theme_font_size_override("font_size", FS)
	age.button_pressed = bool(Settings.get_value("content", "age_confirmed", false))
	age.toggled.connect(func(on): Settings.set_value("content", "age_confirmed", on))
	b.add_child(age)
	var mat := CheckButton.new()
	mat.text = "Mature cosmetics (18+, off by default)"
	mat.add_theme_font_size_override("font_size", FS)
	mat.button_pressed = bool(Settings.get_value("content", "mature_cosmetics_enabled", false))
	mat.toggled.connect(func(on): Settings.set_value("content", "mature_cosmetics_enabled", on))
	b.add_child(mat)
	b.add_child(input_tag("YOUR INPUT HERE: music volume, controls layout, language - tell Foxy what settings you want."))
	return p

# ---------- where to give input ----------
func _build_input() -> Dictionary:
	var p := _panel("★ Where to give input")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Tell Foxy your choices in chat. Full list: docs/WHERE_TO_GIVE_INPUT.md", 24, MAG))
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/input_checklist.json"))
	if d is Dictionary:
		for s in d.get("sections", []):
			b.add_child(label(str(s["title"]), 32, GOLD))
			for it in s["items"]:
				b.add_child(label("☐ " + str(it), 26))
	return p
