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
	panels["avatar"] = _build_avatar()
	panels["map"] = _build_map()
	AgentBrain.reply_ready.connect(_on_reply)
	if not Profile.has_profile(): show_panel("avatar")  # first launch: make YOUR avatar
	else: show_panel("menu" if bool(Settings.get_value("ui", "show_menu_on_start", true)) else "")

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
	if n == "avatar": _refresh_avatar()
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
	h.add_child(btn("◎ MAP", func(): show_panel("map"), 170))
	add_child(h)

# ---------- main menu ----------
func _build_menu() -> Dictionary:
	var p := _panel("Phoenix Scorpion Dragon Viper · v0.5")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Anterrania — Flamma. Ordo. Aeterna.", 28, MAG))
	for row in [["▶ Play", "" ], ["🧑 My Avatar & Profile", "avatar"], ["👜 Wardrobe & Satchel", "wardrobe"], ["💬 Talk to Companions", "chat"], ["🧭 Teleport: Landmarks", "travel"], ["◎ World Map (tap to teleport)", "map"], ["⚙ Settings", "settings"], ["★ Where to give input", "input"]]:
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

# ---------- avatar creator (first launch, per device) ----------
var av := {}
var av_name: LineEdit
var av_list: VBoxContainer
var av_preview: Node3D

func _build_avatar() -> Dictionary:
	var p := _panel("Create Your Avatar")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Everyone builds their own look. Saved on this phone only.", 24, MAG))
	av_name = LineEdit.new()
	av_name.placeholder_text = "Your name"
	av_name.custom_minimum_size = Vector2(0, 76)
	av_name.add_theme_font_size_override("font_size", FS)
	b.add_child(av_name)
	av_list = VBoxContainer.new()
	b.add_child(av_list)
	return p

func _cycle(key: String, opts: Array) -> void:
	var i := opts.find(av.get(key, opts[0]))
	av[key] = opts[(i + 1) % opts.size()]
	_preview()
	_refresh_avatar(false)

func _preview() -> void:
	if player and player.has_method("refresh_avatar"):
		Profile.data["avatar"] = av.duplicate(true)  # live preview without saving
		player.refresh_avatar()

func _refresh_avatar(reload := true) -> void:
	if reload:
		av = Profile.avatar().duplicate(true)
		av_name.text = Profile.data.get("name", "")
	for c in av_list.get_children(): c.queue_free()
	var O: Dictionary = Profile.options
	var presets := HBoxContainer.new()
	for pr in O.get("presets", []):
		if bool(pr.get("owner_only", false)) and not Profile.is_owner(): continue
		var pid: String = pr["id"]
		presets.add_child(btn("Preset: " + str(pr["name"]), func():
			av = Profile.preset_avatar(pid)
			_preview()
			_refresh_avatar(false)))
	av_list.add_child(presets)
	var body_names: Array = O.get("body", ["Masculine", "Feminine"])
	av_list.add_child(btn("Body type: " + str(body_names[int(av.get("body", 0)) % body_names.size()]), func():
		av["body"] = (int(av.get("body", 0)) + 1) % body_names.size()
		_preview()
		_refresh_avatar(false)))
	var styles: Array = O.get("hair_style", ["Straight", "Curly"])
	av_list.add_child(btn("Hair style: " + str(styles[int(av.get("hair_style", 0)) % styles.size()]), func():
		av["hair_style"] = (int(av.get("hair_style", 0)) + 1) % styles.size()
		_preview()
		_refresh_avatar(false)))
	for row in [["skin", "Skin tone"], ["hair", "Hair color"], ["eyes", "Eyes"], ["facial_hair", "Facial hair"], ["outfit", "Jacket / outfit"], ["top", "Top"], ["pants", "Pants"], ["accent", "Glow accent"], ["trim", "Metal trim (palette)"]]:
		var key: String = row[0]
		var opts: Array = O.get(key, [])
		if opts.is_empty(): continue
		var h := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(70, 70)
		var cur := str(av.get(key, opts[0]))
		sw.color = Color(cur) if cur.begins_with("#") else Color(0.2, 0.2, 0.2)
		h.add_child(sw)
		var bt := btn("%s ▶ %s" % [row[1], cur if not cur.begins_with("#") else "next"], func(): _cycle(key, opts))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(bt)
		av_list.add_child(h)
	av_list.add_child(label("Hair streaks (tap to add/remove, multi-color)", 26, GOLD))
	var sh := HBoxContainer.new()
	for c in O.get("streaks", []):
		var col: String = c
		var on: bool = (av.get("hair_streaks", []) as Array).has(col)
		var sb := btn("✔" if on else " ", func():
			var arr: Array = av.get("hair_streaks", [])
			if arr.has(col): arr.erase(col)
			else: arr.append(col)
			if arr.is_empty(): av.erase("hair_streaks")
			else: av["hair_streaks"] = arr
			_preview()
			_refresh_avatar(false), 84)
		sb.add_theme_stylebox_override("normal", _style(Color(col), GOLD if on else MAG))
		sh.add_child(sb)
	av_list.add_child(sh)
	var acc := HBoxContainer.new()
	for a in O.get("accessories", []):
		var k: String = a
		acc.add_child(btn(("✔ " if bool(av.get(k, false)) else "") + k.capitalize(), func():
			av[k] = not bool(av.get(k, false))
			_preview()
			_refresh_avatar(false)))
	av_list.add_child(acc)
	_dna_section()
	av_list.add_child(btn("💾 Save my avatar & play", func():
		Profile.save_profile(av_name.text, av)
		show_panel("")))
	av_list.add_child(label("Profile: %s · role: %s" % [Profile.display_name(), Profile.role().to_upper()], 24))
	if not Profile.is_owner():
		var oh := HBoxContainer.new()
		var code := LineEdit.new()
		code.placeholder_text = "Owner code (world owner only)"
		code.secret = true
		code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code.custom_minimum_size = Vector2(0, 72)
		code.add_theme_font_size_override("font_size", 26)
		oh.add_child(code)
		oh.add_child(btn("Unlock", func():
			if Profile.try_owner_unlock(code.text): _refresh_avatar(false), 170))
		av_list.add_child(oh)
	av_list.add_child(input_tag("YOUR INPUT HERE: more hair styles, body sliders, tattoos, wings?"))

# ---------- DNA blend, sliders, attachments, .glb import ----------
func _dna_section() -> void:
	var P := AvatarDNA.parents()
	var ids: Array = P.keys()
	if ids.is_empty(): return
	var dna: Dictionary = av.get("dna", {"parents": [ids[0], ids[1]], "weights": [0.5, 0.5], "sliders": {}})
	av["dna"] = dna
	av_list.add_child(label("DNA blend — pick parent looks and mix them", 28, GOLD))
	for i in 3:
		var idx := i
		var cur: String = str(dna["parents"][i]) if i < dna["parents"].size() else "(none)"
		var h := HBoxContainer.new()
		h.add_child(btn("Parent %d: %s" % [i + 1, P.get(cur, {}).get("name", cur)], func():
			var arr: Array = dna["parents"]
			var opts: Array = ids + (["(none)"] if idx == 2 else [])
			var nxt: String = opts[(opts.find(cur) + 1) % opts.size()]
			if idx < arr.size():
				if nxt == "(none)": arr.resize(2); (dna["weights"] as Array).resize(2)
				else: arr[idx] = nxt
			else:
				arr.append(nxt); dna["weights"].append(0.33)
			_preview(); _refresh_avatar(false), 380))
		if i < dna["parents"].size():
			h.add_child(_slider(float(dna["weights"][i]), 0.0, 1.0, func(v): dna["weights"][idx] = v; _preview()))
		av_list.add_child(h)
	av_list.add_child(label("Fine-tune", 26, GOLD))
	for sname in AvatarDNA.SLIDERS:
		var sn: String = sname
		var h := HBoxContainer.new()
		var l := label(sn.capitalize(), 24)
		l.custom_minimum_size = Vector2(240, 0)
		h.add_child(l)
		h.add_child(_slider(float(dna["sliders"].get(sn, 0.0)), -1.0, 1.0, func(v): dna["sliders"][sn] = v; _preview()))
		av_list.add_child(h)
	av_list.add_child(label("Attachments (SL-style points)", 28, GOLD))
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(AvatarDNA.DNA_PATH))
	var atts: Array = av.get("attachments", [])
	var row := HFlowContainer.new()
	for a in (d.get("builtin_attachments", []) if d is Dictionary else []):
		var aid: String = a["id"]
		var pt: String = a["point"]
		var on := atts.any(func(x): return x.get("id", "") == aid)
		row.add_child(btn(("✔ " if on else "") + "%s (%s)" % [a["name"], pt], func():
			var arr: Array = av.get("attachments", [])
			var f := arr.filter(func(x): return x.get("id", "") == aid)
			if f.is_empty(): arr.append({"id": aid, "point": pt, "source": "builtin"})
			else: arr.erase(f[0])
			av["attachments"] = arr
			_preview(); _refresh_avatar(false)))
	av_list.add_child(row)
	var masks := HFlowContainer.new()
	masks.add_child(label("Alpha masks:", 24))
	for mk in AvatarDNA.MASKS:
		var m: String = mk
		var am: Array = av.get("alpha_masks", [])
		masks.add_child(btn(("✔ " if am.has(m) else "") + m, func():
			var arr: Array = av.get("alpha_masks", [])
			if arr.has(m): arr.erase(m)
			else: arr.append(m)
			av["alpha_masks"] = arr
			_preview(); _refresh_avatar(false)))
	av_list.add_child(masks)
	av_list.add_child(btn("📦 Import .glb wearable (from app imports / Download folder)", _import_glb))
	av_list.add_child(btn("📤 Export avatar file (avatar DNA + attachments)", func():
		var f := FileAccess.open("user://my_avatar.anterrania.json", FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(AvatarDNA.export_avatar(av, av_name.text), "  "))
		av_list.add_child(label("Saved user://my_avatar.anterrania.json", 22, GOLD))))

func _slider(v: float, lo: float, hi: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = 0.05; s.value = v
	s.custom_minimum_size = Vector2(320, 60)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	return s

func _import_glb() -> void:
	var found := ""
	for dir in ["user://imports", "/storage/emulated/0/Download", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)]:
		if dir == "" or not DirAccess.dir_exists_absolute(dir): continue
		for f in DirAccess.get_files_at(dir):
			if f.get_extension().to_lower() == "glb": found = dir.path_join(f); break
		if found != "": break
	if found == "":
		av_list.add_child(label("No .glb found. Put one in the phone's Download folder (or user://imports) and try again.", 22, Color(1, 0.6, 0.6)))
		return
	var item := Marketplace.import_glb(found, found.get_file().get_basename(), Profile.display_name(), "head", {"copy": true, "modify": true, "transfer": false}, 0, false)
	if item.has("error"):
		av_list.add_child(label("Import failed: " + str(item["error"]), 22, Color(1, 0.6, 0.6)))
		return
	var arr: Array = av.get("attachments", [])
	arr.append({"id": item["id"], "point": "head", "source": "glb", "path": item["asset"]["path"]})
	av["attachments"] = arr
	_preview()
	_refresh_avatar(false)

# ---------- world map: tap anywhere to teleport (SL-style map TP) ----------
const MAP_HALF := 1500.0  # metres shown each side of the origin
var map_rect: TextureRect

func _build_map() -> Dictionary:
	var p := _panel("World Map — tap to teleport")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Alaska = blue/white · Venus = orange · Cosmic = purple · ◆ landmarks", 22, GOLD))
	map_rect = TextureRect.new()
	map_rect.custom_minimum_size = Vector2(520, 520)
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	map_rect.gui_input.connect(_map_input)
	b.add_child(map_rect)
	call_deferred("_draw_map")
	return p

static func map_to_world(uv: Vector2) -> Vector2:
	return (uv * 2.0 - Vector2.ONE) * MAP_HALF

static func world_to_map(xz: Vector2) -> Vector2:
	return (xz / MAP_HALF + Vector2.ONE) * 0.5

func _draw_map() -> void:
	var g = world.generator if world and "generator" in world else null
	if g == null: return
	var n := 160
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var cols := [Color("#a8c4e0"), Color("#d4602a"), Color("#5a2a9a")]
	for y in n:
		for x in n:
			var w := map_to_world(Vector2(x + 0.5, y + 0.5) / n)
			var h: float = g.height_f(w.x, w.y)
			var c: Color = cols[g.biome_at(w.x, w.y)]
			if h < g.LAVA_LEVEL: c = c.darkened(0.5)
			img.set_pixel(x, y, c.lightened(clampf(h / 120.0, 0.0, 0.3)))
	var wc = world.get_node_or_null("WorldContent")
	if wc:
		for l in wc.landmarks:
			var lp: Vector3 = l["position"]
			var m := world_to_map(Vector2(lp.x, lp.z)) * n
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var px: Vector2i = Vector2i(m) + d
				if px.x >= 0 and px.y >= 0 and px.x < n and px.y < n: img.set_pixelv(px, Color("#ffd04a"))
	map_rect.texture = ImageTexture.create_from_image(img)

func _map_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if not pressed: return
	var r := map_rect.size
	var side := minf(r.x, r.y)
	var off := (r - Vector2(side, side)) * 0.5
	var uv := ((e.position as Vector2) - off) / side
	if uv.x < 0 or uv.y < 0 or uv.x > 1 or uv.y > 1: return
	var w := map_to_world(uv)
	teleport(Vector3(w.x, 0, w.y))
