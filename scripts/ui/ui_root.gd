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
const FS := 24  # v0.9 compact menus (tap targets stay >= 80 px)

func _ready() -> void:
	layer = 10
	player = get_node_or_null(player_path)
	world = get_node_or_null(world_path)
	_topbar()
	_status_and_minimap()
	panels["menu"] = _build_menu()
	panels["wardrobe"] = _build_wardrobe()
	panels["chat"] = _build_chat()
	panels["travel"] = _build_travel()
	panels["settings"] = _build_settings()
	panels["input"] = _build_input()
	panels["avatar"] = _build_avatar()
	panels["map"] = _build_map()
	panels["music"] = _build_music()
	panels["rp"] = _build_rp()
	panels["env"] = _build_env()
	panels["radar"] = _build_radar()
	panels["wyrm"] = _build_wyrm()
	panels["welcome"] = _build_welcome()
	panels["help"] = _build_help()
	panels["dest"] = _build_dest()
	panels["estate"] = _build_estate()
	panels["land"] = _build_land()
	panels["proposals"] = _build_proposals()
	panels["history"] = _build_history()
	_viper_radial()
	get_viewport().size_changed.connect(_layout)
	_layout()
	# AgentBrain.request_failed.connect(func(_id, _e): _update_chat_status())   # CHAT-11: now also shows the reason in the log
	AgentBrain.request_failed.connect(_on_chat_failed)
	AgentBrain.thinking.connect(_on_thinking)
	AgentBrain.reply_partial.connect(_on_reply_partial)   # LAI-6: on-device replies stream into the status line
	var lt := Timer.new(); lt.wait_time = 2.0; lt.autostart = true; add_child(lt)
	lt.timeout.connect(func(): FloatingText.apply(get_tree()))
	call_deferred("_apply_labels")
	if not bool(Settings.get_value("welcome", "done", false)): call_deferred("go_welcome", false)
	AgentBrain.reply_ready.connect(_on_reply)
	if OwnerVault.has_vault() and not OwnerVault.storage_ready(): call_deferred("open_unlock_prompt")
	if not Profile.has_profile(): show_panel("avatar")  # first launch: make YOUR avatar
	else: show_panel("menu" if bool(Settings.get_value("ui", "show_menu_on_start", false)) else "")

func _apply_labels() -> void:
	FloatingText.apply(get_tree())

# ---------- v0.9 portrait-first layout ----------
var menu_grid: GridContainer
var land_cursor: MeshInstance3D
func portrait() -> bool:
	return AppControl.is_portrait(get_viewport())

func _layout() -> void:
	var por := portrait()
	for k in panels:
		var pc: PanelContainer = panels[k].get("pc")
		if pc == null: continue
		var m := 12.0 if por else 80.0
		pc.offset_left = m; pc.offset_right = -m
		pc.offset_top = 40.0; pc.offset_bottom = -12.0
		if panels[k].get("land", false): pc.offset_top = get_viewport().get_visible_rect().size.y * (0.52 if por else 0.35)
	if menu_grid: menu_grid.columns = 2 if por else 4

## Android back gesture: close the open panel, otherwise send the app to the background.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_open(): show_panel("")
		else: AppControl.to_background(get_tree())
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if get_tree().paused: AppControl.resume(get_tree())

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
	b.custom_minimum_size = Vector2(min_w, 80)
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
	pc.offset_left = 12; pc.offset_right = -12; pc.offset_top = 40; pc.offset_bottom = -12
	pc.add_theme_stylebox_override("panel", _style(Color(0.05, 0.02, 0.07, 0.95), MAG, 26))
	root.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var head := HBoxContainer.new()
	var t := label(title, 32, GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(btn("✕", func(): show_panel(""), 96))
	v.add_child(head)
	var sc := KineticScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	sc.add_child(body)
	add_child(root)
	root.visible = false
	return {"root": root, "body": body, "box": v, "scroll": sc, "pc": pc}

func show_panel(n: String) -> void:
	for k in panels:
		panels[k]["root"].visible = k == n
	if n == "wardrobe": _refresh_wardrobe()
	if n == "avatar": _refresh_avatar()
	if n == "rp": _refresh_rp()
	if n == "radar": _refresh_radar()
	if n == "map" and map_view and player: map_view.focus(Vector2(player.global_position.x, player.global_position.z))
	if n == "wyrm": _refresh_wyrm()
	if n == "chat": _update_chat_status()
	if n == "estate": _refresh_estate()
	if n == "proposals": _refresh_proposals()
	if n == "history": _refresh_history()
	if land_cursor: land_cursor.visible = n == "land"
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
	h.position = Vector2(12, 52)
	h.add_theme_constant_override("separation", 8)
	for pair in [["☰", "menu"], ["💬", "chat"], ["◎", "map"], ["⛰", "land"], ["👜", "wardrobe"]]:
		var tgt: String = pair[1]
		var b := btn(pair[0], func(): show_panel(tgt), 68)
		b.add_theme_font_size_override("font_size", 34)
		h.add_child(b)
	var mute := btn("♪" if not bool(Settings.get_value("music", "muted", false)) else "🔇", func(): pass, 68)
	mute.name = "Mute"
	mute.add_theme_font_size_override("font_size", 34)
	mute.pressed.connect(func():
		var m := not bool(Settings.get_value("music", "muted", false))
		MusicRadio.set_muted(m)
		mute.text = "🔇" if m else "♪")
	h.add_child(mute)
	add_child(h)
	# Exit + Background: always on screen, top-right under the minimap, big targets.
	var sys := HBoxContainer.new()
	sys.name = "SystemButtons"
	sys.anchor_left = 1.0; sys.anchor_right = 1.0
	sys.offset_left = -Minimap.SIZE - 16; sys.offset_right = -16
	sys.offset_top = 52 + Minimap.SIZE + 8
	sys.alignment = BoxContainer.ALIGNMENT_END
	sys.add_theme_constant_override("separation", 8)
	var bg := btn("⤓ BG", func(): AppControl.to_background(get_tree()), 108)
	bg.name = "Background"
	var ex := btn("✕ EXIT", func(): AppControl.exit_app(get_tree()), 108)
	ex.name = "Exit"
	ex.add_theme_stylebox_override("normal", _style(Color(0.25, 0.02, 0.08, 0.9), GOLD))
	for x in [bg, ex]:
		x.add_theme_font_size_override("font_size", 22)
		sys.add_child(x)
	add_child(sys)

# ---------- main menu ----------
func _build_menu() -> Dictionary:
	var p := _panel("Phoenix · v0.11")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Anterrania — Flamma. Ordo. Aeterna.", 26, MAG))
	var grid := GridContainer.new()
	menu_grid = grid
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for row in [["▶ Play", ""], ["🧑 Avatar", "avatar"], ["👜 Wardrobe", "wardrobe"], ["💬 Talk", "chat"], ["🎭 Roleplay", "rp"], ["🐉 Wyrmlings", "wyrm"],
			["🧭 Teleport", "travel"], ["◎ World Map", "map"], ["◉ Nearby", "radar"], ["☀ Environment", "env"], ["♪ Music", "music"], ["🏝 Welcome Island", "welcome"], ["🗺 Destinations", "dest"], ["❓ Help", "help"], ["⛰ Land Tools", "land"], ["🏛 Region / Estate", "estate"], ["⚙ Settings", "settings"], ["★ Your input", "input"], ["📜 Proposals", "proposals"], ["🕮 History", "history"], ["🛡 Viper Admin", "_admin"], ["👥 Community", "_community"], ["⚖ Land & Safety", "_landsafety"], ["⇄ Interop", "_interop"], ["⤓ Background", "_bg"], ["✕ Exit app", "_exit"]]:
		var target: String = row[1]
		var t := btn(row[0], func():
			if target == "_bg": AppControl.to_background(get_tree())
			elif target == "_exit": AppControl.exit_app(get_tree())
			elif target == "_admin": open_admin()
			elif target == "_community": CommunityScreen.open(self)
			elif target == "_landsafety": LandSafetyScreen.open(self, _est_region(), Estate.parcel_id(player.global_position) if player else "0_0", player.global_position if player else Vector3.ZERO)
			elif target == "_interop": InteropScreen.open(self)
			else: show_panel(target))
		t.custom_minimum_size = Vector2(0, 96)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	b.add_child(grid)
	b.add_child(label("Gold ★ YOUR INPUT HERE tags mark placeholders waiting for your decision.", 22, GOLD))
	return p

## Radial launcher (right edge, vertically centred). Admin 12 o'clock -> dashboard,
## Security 2 o'clock -> lock/audit panel, then Chat, Map, Proposals, Menu.
var radial: ViperRadial
func _viper_radial() -> void:
	radial = ViperRadial.new()
	radial.name = "ViperRadial"
	add_child(radial)
	var vp := get_viewport().get_visible_rect().size
	radial._anchor_center = Vector2(vp.x - 76, vp.y * 0.55)
	radial._resize()
	radial.item_selected.connect(_on_radial)

func _on_radial(id: String) -> void:
	radial.open = false
	if id == "Admin": open_admin()
	elif id == "Security": open_security()
	else: show_panel({"Chat": "chat", "Map": "map", "Proposals": "proposals", "Menu": "menu"}.get(id, ""))

func open_security() -> SecurityScreen:
	var existing := get_node_or_null("SecurityScreen")
	if existing: return existing
	var s: SecurityScreen = load("res://scenes/admin/security_screen.tscn").instantiate()
	add_child(s)
	return s

## App start with encrypted saves: big PIN pad, or continue as guest (memories stay sealed).
func open_unlock_prompt() -> void:
	var s := open_security()
	var pad := s.open_pad("unlock")
	pad.prompt.text = "Welcome back. Enter your PIN to open your companions' memories."

## Viper OS admin overlay (tickets / wiki / revisions / reports / local profile). Local-only.
func open_admin() -> Control:
	var existing := get_node_or_null("AdminScreen")
	if existing: return existing
	var a: Control = load("res://scenes/admin/admin_screen.tscn").instantiate()
	add_child(a)
	if a.get("pages"): a.pages.go(0)   # dashboard
	return a

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
		var it: Dictionary = s
		var r := HBoxContainer.new()
		var l := label("• %s ×%d — %s" % [it["name"], int(it.get("count", 1)), it.get("desc", "")], 24)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(btn("List on Marketplace", func():
			Marketplace.list_inventory_item(it, Profile.display_name(), 10)
			wardrobe_list.add_child(label("Draft listing saved: %s (store opens with the server)." % it["name"], 22, GOLD)), 300))
		wardrobe_list.add_child(r)

# ---------- chat ----------
func _build_chat() -> Dictionary:
	var p := _panel("Talk to Companions")
	var b: VBoxContainer = p["body"]
	chat_status = label("", 22, GOLD)
	chat_status.name = "ChatStatus"
	b.add_child(chat_status)
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
	var quick := HFlowContainer.new()
	for q in ["Hi!", "Who are you?", "Where should we go?", "Outfit?"]:
		var qq: String = q
		quick.add_child(btn(qq, func(): _send(qq)))
	b.add_child(quick)
	var modes := HFlowContainer.new()
	follow_btn = btn("Mode: Follow me", func():
		if chat_target:
			chat_target.set_follow(not chat_target.following)
			_update_follow())
	follow_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(follow_btn)
	modes.add_child(btn("All follow", func(): _all_follow(true), 190))
	modes.add_child(btn("All roam", func(): _all_follow(false), 190))
	var icb := btn("IC", func(): pass, 120)
	icb.pressed.connect(func():
		chat_ic = not chat_ic
		icb.text = "IC" if chat_ic else "OOC")
	modes.add_child(icb)
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
		# chat_log.append_text("[color=#ffd04a]— talking to %s (%s) —[/color]\n" % [c.persona.get("name", c.name), "live AI" if Settings.chat_status() == "live" else "chat offline: persona replies"])
		var st := Settings.chat_status()
		chat_log.append_text("[color=#ffd04a]— talking to %s (%s) —[/color]\n" % [c.persona.get("name", c.name), "live AI" if st == "live" else ("on-device AI" if st in LOCAL_OK else "chat offline: persona replies")])
	if Settings.local_llm(): Settings.local_llm().warm_up()   # LAI-6: load the model while the player types

var chat_ic := true
var chat_status: Label
const LOCAL_OK := ["local_ready", "local_downloaded", "local_loading"]   # LAI-6: on-device AI usable (green)
var _partial := ""
func _update_chat_status() -> void:
	if chat_status == null: return
	var st := Settings.chat_status()
	chat_status.text = Settings.chat_status_text(st)
	# chat_status.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if st == "live" else Color(1, 0.55, 0.55))
	chat_status.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if st == "live" or st in LOCAL_OK else (GOLD if st == "local_downloading" else Color(1, 0.55, 0.55)))
	if st == "offline_error" and Settings.last_chat_error != "": chat_status.text += "\n" + Settings.last_chat_error
	if chat_target and AgentBrain.is_thinking(chat_target.companion_id):
		chat_status.text += ("\n%s: %s…" % [_short_name(chat_target), _partial.right(160)]) if _partial != "" else "\n%s is thinking…" % _short_name(chat_target)

## LAI-6: streamed on-device text (tool markup already hidden). The full reply still lands in the log via _on_reply.
func _on_reply_partial(id: String, text: String) -> void:
	if chat_target == null or chat_target.companion_id != id: return
	_partial = text
	_update_chat_status()

## BBCode-safe text for the chat log (CHAT-12: a "[" in a message used to break or restyle the log).
static func _bb(t: String) -> String:
	return t.replace("[", "[lb]")

func _short_name(c: Node) -> String:
	return str(c.persona.get("name", c.name)).split(" ")[0]

func _send(t: String) -> void:
	if t.strip_edges() == "": return
	# CHAT-13: was a silent return when no companion was picked yet.
	if chat_target == null and not _companions().is_empty(): _pick_chat(_companions().front())
	if chat_target == null:
		chat_log.append_text("[color=#ffd04a]No companion is nearby to talk to yet.[/color]\n")
		return
	var f := RoleplayProfile.format_chat(_bb(Profile.display_name()), _bb(t), chat_ic)
	chat_log.append_text(f["text"] + "\n")
	chat_input.clear()
	if f.get("emote", false) and player and player.has_method("set_pose"): player.set_pose("wave", 2.0)
	if f["to_companion"]: chat_target.talk(t)
	elif not chat_ic: chat_log.append_text("[color=#9aa0b8](OOC: not sent to %s. Tap OOC to switch back to IC.)[/color]\n" % _short_name(chat_target))   # CHAT-13

func _on_reply(id: String, text: String) -> void:
	if chat_target and chat_target.companion_id == id: _partial = ""
	if text.strip_edges() == "": return
	if chat_target and chat_target.companion_id == id and chat_log:
		chat_log.append_text("[color=#ff8de8]%s:[/color] %s\n" % [_bb(str(chat_target.persona.get("name", id))), _bb(text)])
	_update_chat_status()

func _on_chat_failed(id: String, why: String) -> void:
	if chat_target and chat_target.companion_id == id and chat_log:
		if why.begins_with("on-device AI"): chat_log.append_text("[color=#ff8c8c](%s. Persona reply below.)[/color]\n" % _bb(why))   # LAI-6
		else: chat_log.append_text("[color=#ff8c8c](Live AI unavailable: %s Offline reply below.)[/color]\n" % _bb(why))
	_update_chat_status()

func _on_thinking(_id: String, _active: bool) -> void:
	_update_chat_status()

## LAI-6: On-device AI block (Settings › Companion AI): status + download progress, download / cancel,
## model pick, Wi-Fi-only, delete. Mobile data needs a second tap (the file is 400 MB+).
func _build_local_ai(b: VBoxContainer) -> void:
	var llm: Node = Settings.local_llm()
	if llm == null: return
	b.add_child(label("On-device AI (no key, runs on this phone)", 26, GOLD))
	var st := label("", 22)
	b.add_child(st)
	var dl := btn("", func(): pass)
	var pick := btn("", func(): pass)
	var confirm := [false]
	var refresh := func():
		var m: Dictionary = llm.model()
		st.text = Settings.chat_status_text(llm.status()) + "\n%s · %s · %d MB" % [m.get("name", "?"), m.get("license", ""), int(int(m.get("size", 0)) / 1048576)]
		if llm.last_error != "" and llm.state == "error": st.text += "\n" + llm.last_error
		dl.text = "Cancel download" if llm.state == "downloading" else ("Downloaded ✓" if llm.is_downloaded() else ("Tap again: download over mobile data" if confirm[0] else "Download now"))
		pick.text = "Model: " + str(m.get("name", "?"))
	dl.pressed.connect(func():
		if llm.state == "downloading": llm.cancel_download()
		elif not llm.is_downloaded():
			if not llm.start_download(confirm[0]) and llm.state == "waiting_wifi": confirm[0] = true
			else: confirm[0] = false
		refresh.call())
	pick.pressed.connect(func():
		var ids: Array = llm.models().map(func(x): return str(x["id"]))
		if ids.is_empty(): return
		llm.set_pref("model", ids[(ids.find(llm.model_id()) + 1) % ids.size()])
		confirm[0] = false
		refresh.call()
		_update_chat_status())
	b.add_child(dl)
	b.add_child(pick)
	var wifi := CheckButton.new()
	wifi.text = "Download only on Wi-Fi"
	wifi.add_theme_font_size_override("font_size", FS)
	wifi.button_pressed = bool(llm.pref("wifi_only"))
	wifi.toggled.connect(func(on): llm.set_pref("wifi_only", on); refresh.call())
	b.add_child(wifi)
	b.add_child(btn("Delete downloaded model", func(): llm.delete_model(); refresh.call(); _update_chat_status()))
	llm.state_changed.connect(func(_s): if is_instance_valid(st): refresh.call(); _update_chat_status())
	llm.progress_changed.connect(func(_d, _t): if is_instance_valid(st): refresh.call())
	refresh.call()

# ---------- travel ----------
func _build_travel() -> Dictionary:
	var p := _panel("Travel to Landmarks")
	call_deferred("_fill_travel", p["body"])
	return p

func _fill_travel(b: VBoxContainer) -> void:
	var wc: Node = world.get_node_or_null("WorldContent") if world else null
	b.add_child(btn("🏠 Spawn (Alaskan Aurora Tundra)", func(): teleport(Vector3(0, 0, 0))))
	_fill_my_landmarks(b)
	if wc == null: return
	for l in wc.landmarks:
		var pos: Vector3 = l["position"]
		var realm: String = ["Alaska", "Venus", "Cosmic"][int(l["biome"])]
		b.add_child(btn("%s  ·  %s" % [l["name"], realm], func(): teleport(pos + Vector3(0, 0, 20))))
		b.add_child(input_tag("YOUR INPUT HERE: " + " / ".join(PackedStringArray(l["input"]))))

## v0.13 personal landmarks, Set Home and teleport history (Landmarks store, SL-style).
func _fill_my_landmarks(b: VBoxContainer) -> void:
	var r := _est_region()
	if Landmarks.has_home():
		var hm := Landmarks.home()
		b.add_child(btn("⌂ Go home  ·  %s" % hm["region"], func(): teleport(Landmarks.to_vec(hm), true)))
	b.add_child(btn("📍 Save landmark here", func():
		var res := Landmarks.save_here("", r, player.global_position) if player else {"ok": false, "error": "No player."}
		_toast_or_warn(res["ok"], "Landmark saved.", str(res.get("error", "")))
		show_panel("")))
	b.add_child(btn("⌂ Set home to here", func():
		var e := Landmarks.set_home(r, player.global_position) if player else "No player."
		_toast_or_warn(e == "", "Home set.", e)
		show_panel("")))
	for l in Landmarks.list().slice(-8):
		var lv := Landmarks.to_vec(l)
		b.add_child(btn("📍 %s  ·  %s" % [l["name"], l["region"]], func(): teleport(lv, true)))
	var hist := Landmarks.history(5)
	if not hist.is_empty(): b.add_child(label("Teleport history", 22, GOLD))
	for h in hist:
		var hv := Landmarks.to_vec(h)
		b.add_child(btn("↺ %s  (%d, %d)" % [h["region"], roundi(hv.x), roundi(hv.z)], func(): teleport(hv, true)))

func _toast_or_warn(ok: bool, good: String, bad: String) -> void:
	Toast.show_toast(self, good if ok else bad, "ok" if ok else "warn")

func teleport(p: Vector3, exact := false) -> void:
	if player == null: return
	var g = world.generator if world and "generator" in world else null
	var y := p.y
	if g and not exact: y = maxf(g.height_f(p.x, p.z), g.LAVA_LEVEL) + 3.0
	player.global_position = Vector3(p.x, y, p.z)
	ModerationLists.on_teleport("self")   # temporary derenders come back after a teleport (VIEWER-3)
	if "velocity" in player: player.velocity = Vector3.ZERO
	Landmarks.record_teleport(_est_region(), player.global_position)   # SL-style teleport history
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
	var vm := CheckButton.new()
	vm.text = "Companion voices (TTS)"
	vm.add_theme_font_size_override("font_size", FS)
	vm.button_pressed = not CompanionVoice.muted()
	vm.toggled.connect(func(on): CompanionVoice.set_muted(not on))
	b.add_child(vm)
	var lab := CheckButton.new()
	lab.text = "Show floating names & labels"
	lab.add_theme_font_size_override("font_size", FS)
	lab.button_pressed = FloatingText.enabled()
	lab.toggled.connect(func(on): FloatingText.set_enabled(on, get_tree()))
	b.add_child(lab)
	b.add_child(label("Companion AI", 32, GOLD))
	var mode := btn("", func(): pass)
	# var upd := func(): mode.text = "AI mode: " + ("LIVE (uses API key)" if str(Settings.get_value("llm", "mode", "canned")) == "live" else "OFFLINE canned replies")
	# LAI-6: three modes, on-device first. Tap cycles On-device -> Live -> Offline replies.
	var upd := func(): mode.text = "AI mode: " + {"local": "ON-DEVICE (no key, private)", "live": "LIVE (uses API key)", "canned": "OFFLINE canned replies"}[Settings.effective_mode()]
	upd.call()
	mode.pressed.connect(func():
		# Settings.set_value("llm", "mode", "canned" if str(Settings.get_value("llm", "mode", "canned")) == "live" else "live")
		Settings.set_value("llm", "mode", {"local": "live", "live": "canned", "canned": "local"}[Settings.effective_mode()])
		Settings.set_value("llm", "mode_set", true)
		Settings.last_chat_error = ""
		upd.call()
		_update_chat_status())
	b.add_child(mode)
	for f in [["endpoint", "LLM endpoint (OpenAI-compatible)", false], ["model", "Model", false], ["api_key", "API key (stored only on this phone)", true]]:
		b.add_child(label(f[1], 24))
		var le := LineEdit.new()
		le.text = str(Settings.get_value("llm", f[0], ""))
		le.secret = f[2]
		le.custom_minimum_size = Vector2(0, 72)
		le.add_theme_font_size_override("font_size", 26)
		var key: String = f[0]
		# le.text_changed.connect(func(t): Settings.set_value("llm", key, t.strip_edges()))
		# CHAT-3: a pasted key switches live chat on (unless offline was chosen); the mode label follows.
		le.text_changed.connect(func(t):
			if key == "api_key": Settings.set_api_key_from_ui(t)
			else: Settings.set_value("llm", key, t.strip_edges()); Settings.last_chat_error = ""
			upd.call()
			_update_chat_status())
		if key == "endpoint": le.placeholder_text = "https://api.x.ai/v1/chat/completions"
		b.add_child(le)
	var probe := label("", 22, GOLD)
	b.add_child(btn("Test AI connection", func():
		probe.text = "Testing…"
		AgentBrain.test_connection(func(ok: bool, m: String):
			probe.text = m
			probe.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if ok else Color(1, 0.55, 0.55))
			_update_chat_status())))
	b.add_child(probe)
	_build_local_ai(b)
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
	tabify(b, "Display", ["Companion AI", "Voice & Music", "Content"])
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
	for c in av_list.get_children():
		av_list.remove_child(c); c.queue_free()
	var O: Dictionary = Profile.options
	var presets := HBoxContainer.new()
	for pr in O.get("presets", []):
		if bool(pr.get("owner_only", false)) and not Profile.is_owner_device(): continue
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
			if Profile.try_owner_unlock(code.text):
				_refresh_avatar(false)
				if OwnerVault.needs_pin_setup(): open_security().open_pad("setup"), 170))
		av_list.add_child(oh)
	av_list.add_child(input_tag("YOUR INPUT HERE: more hair styles, body sliders, tattoos, wings?"))
	collapse_sections(av_list, ["Hair streaks", "DNA blend", "Fine-tune", "Attachments"])

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

# ---------- v0.7 full-screen world map ----------
var map_view: WorldMapView
var map_search: LineEdit
var map_results: HBoxContainer

func _build_map() -> Dictionary:
	var p := _panel("World Map")
	var box: VBoxContainer = p["box"]
	p["scroll"].visible = false   # the map itself pans; no list scrolling here
	var tools := HBoxContainer.new()
	map_search = LineEdit.new()
	map_search.placeholder_text = "Search landmarks…"
	map_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_search.custom_minimum_size = Vector2(0, 72)
	map_search.add_theme_font_size_override("font_size", 26)
	map_search.text_changed.connect(func(_t): _map_search_results())
	tools.add_child(map_search)
	tools.add_child(btn("+", func(): map_view.zoom_by(0.7), 90))
	tools.add_child(btn("−", func(): map_view.zoom_by(1.4), 90))
	tools.add_child(btn("◎ Me", func(): map_view.focus(Vector2(player.global_position.x, player.global_position.z)), 130))
	box.add_child(tools)
	map_results = HBoxContainer.new()
	box.add_child(map_results)
	map_view = WorldMapView.new()
	map_view.world = world
	map_view.player = player
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.clip_contents = true
	map_view.teleport_requested.connect(func(xz: Vector2): teleport(Vector3(xz.x, 0, xz.y)))
	box.add_child(map_view)
	box.add_child(label("Drag to pan · pinch or +/− to zoom · tap to teleport · grid = 256 m regions", 20, GOLD))
	return p

func _map_search_results() -> void:
	for c in map_results.get_children(): c.queue_free()
	var q := map_search.text.strip_edges().to_lower()
	var wc = world.get_node_or_null("WorldContent") if world else null
	if q == "" or wc == null: return
	for l in wc.landmarks:
		if str(l["name"]).to_lower().contains(q):
			var pos: Vector3 = l["position"]
			map_results.add_child(btn(str(l["name"]), func(): map_view.focus(Vector2(pos.x, pos.z)), 0))

static func map_to_world(uv: Vector2) -> Vector2:
	return MapData.uv_to_world(uv)

static func world_to_map(xz: Vector2) -> Vector2:
	return MapData.world_to_uv(xz)

# ---------- v0.7 environment panel ----------
func _build_env() -> Dictionary:
	var p := _panel("☀ Environment")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Pick a sky. Region default follows the realm you're in; Day/Night runs a 24-minute day.", 22, MAG))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for m in ["Region default", "Day/Night cycle"] + EnvPresets.PRESETS.keys():
		var mode: String = {"Region default": "region", "Day/Night cycle": "cycle"}.get(m, m)
		var bt := btn(m, func():
			if world and world.has_method("set_env_mode"): world.set_env_mode(mode)
			show_panel(""))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(bt)
	b.add_child(grid)
	return p

# ---------- v0.7 nearby radar ----------
var radar_box: VBoxContainer
func _build_radar() -> Dictionary:
	var p := _panel("📡 Nearby (radar)")
	radar_box = p["body"]
	return p

func radar_entries() -> Array:
	var out: Array = []
	if player == null: return out
	for c in _companions():
		out.append({"name": str(c.persona.get("name", c.name)), "kind": "Companion", "node": c, "dist": c.global_position.distance_to(player.global_position)})
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.alive(): out.append({"name": "Cinder Stalker", "kind": "Creature", "node": c, "dist": c.global_position.distance_to(player.global_position)})
	out.sort_custom(func(a, b): return a["dist"] < b["dist"])
	return out

func _refresh_radar() -> void:
	for c in radar_box.get_children(): c.queue_free()
	radar_box.add_child(label("Other players will appear here when multiplayer arrives.", 22, MAG))
	for e in radar_entries():
		var n: Node3D = e["node"]
		radar_box.add_child(btn("%s  ·  %s  ·  %d m  →  go" % [e["name"], e["kind"], int(e["dist"])], func(): teleport(n.global_position + Vector3(3, 0, 3))))

# ---------- v0.7 status bar + minimap ----------
var status_label: Label
var minimap: Minimap
func _status_and_minimap() -> void:
	var bar := PanelContainer.new()
	bar.name = "StatusBar"
	bar.anchor_left = 0.0; bar.anchor_right = 1.0
	bar.offset_left = 340; bar.offset_right = -8; bar.offset_top = 2; bar.offset_bottom = 40
	var sb := _style(Color(0.04, 0.02, 0.06, 0.75), Color(1, 0.18, 0.82, 0.6), 12)
	sb.set_content_margin_all(6)
	bar.add_theme_stylebox_override("panel", sb)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label = label("", 18, Color(1, 0.95, 0.85))
	status_label.clip_text = true
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bar.add_child(status_label)
	add_child(bar)
	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap.world = world
	minimap.player = player
	minimap.anchor_left = 1.0; minimap.anchor_right = 1.0
	minimap.offset_left = -Minimap.SIZE - 16; minimap.offset_right = -16
	minimap.offset_top = 52; minimap.offset_bottom = 52 + Minimap.SIZE
	minimap.open_map.connect(func(): show_panel("map"))
	add_child(minimap)
	var tm := Timer.new(); tm.wait_time = 0.5; tm.autostart = true; add_child(tm)
	tm.timeout.connect(update_status)

func status_text() -> String:
	if player == null: return ""
	var g = world.generator if world and "generator" in world else null
	var realm: String = MapData.REALMS[g.biome_at(player.global_position.x, player.global_position.z)] if g else "?"
	var hr: float = world.hour if world and "hour" in world else 12.0
	return "%s · %s · %s" % [MapData.region_name(player.global_position), realm.split(" ")[0], EnvPresets.clock_text(hr)]

func update_status() -> void:
	if status_label: status_label.text = status_text()

# ---------- music: SoundCloud ----------
func _radio():
	var wc = world.get_node_or_null("WorldContent") if world else null
	return wc.radio if wc else null

func _build_music() -> Dictionary:
	var p := _panel("♪ Music — SoundCloud")
	var b: VBoxContainer = p["body"]
	for opt in [["muted", "Mute music"], ["everywhere", "Play everywhere (not just near the radio)"]]:
		var cb := CheckButton.new()
		var k: String = opt[0]
		cb.text = opt[1]
		cb.add_theme_font_size_override("font_size", FS)
		cb.button_pressed = bool(Settings.get_value("music", k, k == "everywhere"))
		cb.toggled.connect(func(on): Settings.set_value("music", k, on))
		b.add_child(cb)
	var now := label("♪ Now: " + SoundCloudSource.now_title(), 28, GOLD)
	now.name = "NowTitle"
	b.add_child(now)
	var nav := HBoxContainer.new()
	for d in [[-1, "⏮ Prev"], [1, "Next ⏭"]]:
		var dd: int = d[0]
		nav.add_child(btn(d[1], func():
			SoundCloudSource.step_track(dd)
			now.text = "♪ Now: " + SoundCloudSource.now_title()
			var r = _radio()
			if r: r.start(), 160))
	b.add_child(nav)
	b.add_child(label(str(SoundCloudSource.config().get("default_playlist_name", "")), 20))
	b.add_child(label("Phoenix Radio streams from SoundCloud. Default = the owner's SoundCloud. Put your own SoundCloud profile/playlist link below.", 24, MAG))
	b.add_child(btn("▶ Play on SoundCloud (opens SoundCloud app)", func():
		var r = _radio()
		if r == null or not r.play_on_soundcloud():
			b.add_child(label("No SoundCloud link yet - add one below (owner default: YOUR INPUT HERE).", 22, Color(1, 0.6, 0.6)))))
	b.add_child(label("Your SoundCloud URL", 26, GOLD))
	var u := LineEdit.new()
	u.text = str(Settings.get_value("music", "soundcloud_url", ""))
	u.placeholder_text = "https://soundcloud.com/your-name  (blank = owner's default)"
	u.custom_minimum_size = Vector2(0, 72)
	u.add_theme_font_size_override("font_size", 24)
	u.text_submitted.connect(func(t):
		Settings.set_value("music", "soundcloud_url", t.strip_edges())
		var r = _radio()
		if r: r.start())
	b.add_child(u)
	b.add_child(label("In-game playback (optional): SoundCloud API Client ID / Secret (Artist Pro). Stored only on this phone.", 22))
	for k in [["sc_client_id", false], ["sc_client_secret", true]]:
		var le := LineEdit.new()
		le.placeholder_text = k[0]
		le.secret = k[1]
		le.text = str(Settings.get_value("music", k[0], ""))
		le.custom_minimum_size = Vector2(0, 64)
		var key: String = k[0]
		le.text_changed.connect(func(t): Settings.set_value("music", key, t.strip_edges()))
		b.add_child(le)
	b.add_child(label("Without API keys, songs play in the SoundCloud app; the radio keeps a royalty-free track in-world.", 22))
	return p

# ---------- roleplay: character sheet, titler, poses ----------
var rp_box: VBoxContainer
func _build_rp() -> Dictionary:
	var p := _panel("🎭 Character Sheet & Titler")
	rp_box = p["body"]
	return p

func _refresh_rp() -> void:
	for c in rp_box.get_children(): c.queue_free()
	var d := RoleplayProfile.sheet()
	rp_box.add_child(label("Name: " + Profile.display_name() + "   (change in My Avatar)", 26, GOLD))
	for f in ["title", "species", "faction", "bio"]:
		var key: String = f
		rp_box.add_child(label(key.capitalize() + (" (floats above you)" if key == "title" else ""), 24))
		var le := LineEdit.new()
		le.text = str(d[key])
		le.custom_minimum_size = Vector2(0, 68)
		le.add_theme_font_size_override("font_size", 26)
		le.text_changed.connect(func(t): d[key] = t)
		rp_box.add_child(le)
	var st := btn("Status: " + str(d["status"]), func(): pass)
	st.pressed.connect(func():
		d["status"] = {"IC": "OOC", "OOC": "AFK", "AFK": "IC"}.get(d["status"], "IC")
		st.text = "Status: " + str(d["status"]))
	rp_box.add_child(st)
	rp_box.add_child(btn("💾 Save sheet & update titler", func():
		RoleplayProfile.save_sheet(d)
		if player and player.has_method("refresh_titler"): player.refresh_titler()
		show_panel("")))
	rp_box.add_child(label("Poses & emotes", 28, GOLD))
	var row := HBoxContainer.new()
	for po in ["wave", "bow", "sit", "dance"]:
		var pp: String = po
		row.add_child(btn(pp.capitalize(), func():
			if player: player.set_pose(pp, 6.0)
			show_panel("")))
	rp_box.add_child(row)
	rp_box.add_child(label("Tip: in TALK, tap IC/OOC to switch; start with /me for an emote (e.g. /me bows to the court).", 22))

# ---------- breedables: Ember Wyrmlings ----------
var wyrm_box: VBoxContainer
var wyrm_pick: Array = []
func _build_wyrm() -> Dictionary:
	var p := _panel("🐉 Ember Wyrmlings")
	wyrm_box = p["body"]
	return p

func _pen():
	var wc = world.get_node_or_null("WorldContent") if world else null
	return wc.pen if wc else null

func _refresh_wyrm() -> void:
	for c in wyrm_box.get_children(): c.queue_free()
	var pen = _pen()
	if pen == null: return
	wyrm_box.add_child(label("Tap two wyrmlings to select, feed them, then Breed. Offspring inherit color, horn and wings.", 22, MAG))
	for w in pen.list:
		var ww: Dictionary = w
		var sel := wyrm_pick.has(ww["id"])
		var row := HBoxContainer.new()
		var sw := ColorRect.new(); sw.custom_minimum_size = Vector2(60, 60)
		sw.color = Color(Wyrmlings.COLORS[Wyrmlings.expressed(ww, "color")])
		row.add_child(sw)
		var info := "%s%s · Gen %d · %s · %s, %s horn, %s wings · hunger %d%%" % ["✔ " if sel else "", ww["name"], int(ww["generation"]), Wyrmlings.rarity(ww),
			Wyrmlings.expressed(ww, "color"), Wyrmlings.expressed(ww, "horn"), Wyrmlings.expressed(ww, "wing"), int(float(ww["hunger"]) * 100)]
		var b := btn(info, func():
			if wyrm_pick.has(ww["id"]): wyrm_pick.erase(ww["id"])
			else:
				wyrm_pick.append(ww["id"])
				if wyrm_pick.size() > 2: wyrm_pick.pop_front()
			_refresh_wyrm())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		row.add_child(b)
		row.add_child(btn("🍖 Feed", func():
			Wyrmlings.feed(ww); pen.save(); _refresh_wyrm(), 150))
		wyrm_box.add_child(row)
	wyrm_box.add_child(btn("💞 Breed selected pair", func():
		if wyrm_pick.size() < 2:
			wyrm_box.add_child(label("Select two wyrmlings first.", 22, Color(1, 0.6, 0.6))); return
		var a: Dictionary = pen.list.filter(func(x): return x["id"] == wyrm_pick[0])[0]
		var b2: Dictionary = pen.list.filter(func(x): return x["id"] == wyrm_pick[1])[0]
		var now := Time.get_unix_time_from_system()
		var why := Wyrmlings.can_breed(a, b2, now)
		if why != "":
			wyrm_box.add_child(label(why, 22, Color(1, 0.6, 0.6))); return
		var baby := Wyrmlings.breed(a, b2, now)
		pen.list.append(baby); pen.save(); pen.rebuild()
		wyrm_pick.clear()
		_refresh_wyrm()
		wyrm_box.add_child(label("A new wyrmling hatched: %s (Gen %d, %s)!" % [baby["name"], baby["generation"], Wyrmlings.rarity(baby)], 26, GOLD))))
	wyrm_box.add_child(input_tag("YOUR INPUT HERE: more traits, names, selling for Aethel Coin?"))

# ---------- v0.7 tabs + collapsible sections ----------
## Split a body's children into tabs at header labels; tab buttons on top.
func tabify(body: VBoxContainer, first: String, headers: Array) -> Dictionary:
	var groups := {first: VBoxContainer.new()}
	var order := [first]
	var cur: VBoxContainer = groups[first]
	for c in body.get_children():
		body.remove_child(c)
		if c is Label and headers.has(c.text):
			cur = VBoxContainer.new()
			groups[c.text] = cur
			order.append(c.text)
			c.queue_free()
			continue
		cur.add_child(c)
	var bar := HBoxContainer.new()
	bar.name = "Tabs"
	body.add_child(bar)
	for k in order:
		var key: String = k
		var g: VBoxContainer = groups[key]
		g.add_theme_constant_override("separation", 10)
		body.add_child(g)
		g.visible = key == first
		var tb := btn(key, func():
			for o in groups: groups[o].visible = o == key, 0)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(tb)
	return groups

## Make header labels tappable to collapse/expand the controls after them.
var open_sections := {}
func collapse_sections(body: VBoxContainer, headers: Array, start_closed := true) -> int:
	var made := 0
	var kids := body.get_children()
	var i := 0
	while i < kids.size():
		var c: Node = kids[i]
		if c is Label and headers.any(func(h): return c.text.begins_with(h)):
			var sec := VBoxContainer.new()
			var title: String = c.text
			var idx := c.get_index()
			var j := i + 1
			while j < kids.size() and not (kids[j] is Label and headers.any(func(h): return kids[j].text.begins_with(h))) and not (kids[j] is Button and kids[j].text.begins_with("💾")):
				body.remove_child(kids[j]); sec.add_child(kids[j]); j += 1
			sec.visible = bool(open_sections.get(title, not start_closed))
			var hb := btn(("▼ " if sec.visible else "▶ ") + title, func(): pass)
			hb.pressed.connect(func():
				sec.visible = not sec.visible
				open_sections[title] = sec.visible
				hb.text = ("▼ " if sec.visible else "▶ ") + title)
			body.remove_child(c); c.queue_free()
			body.add_child(hb); body.move_child(hb, idx)
			body.add_child(sec); body.move_child(sec, idx + 1)
			made += 1
			i = j
		else:
			i += 1
	return made

# ---------- v0.7 Welcome Island, guide bots, destinations ----------
var welcome_box: VBoxContainer
var help_out: Label
var help_in: LineEdit
func go_welcome(open_panel := true) -> void:
	teleport(WelcomeIsland.spawn_point(), true)
	if open_panel: show_panel("welcome")

func _build_welcome() -> Dictionary:
	var p := _panel("🏝 Welcome Island")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Walk the glowing ring of stations. Each one teaches a basic skill.", 24, GOLD))
	b.add_child(btn("🏝 Go to / Return to Welcome Island", func(): go_welcome(false)))
	b.add_child(btn("⏭ Skip tutorial (go to main world)", skip_welcome))
	for st in WelcomeIsland.load_json(WelcomeIsland.DATA).get("stations", []):
		var id: String = st["id"]
		b.add_child(btn("%s\n%s" % [st["title"], st["text"]], func(): _goto_station(id)))
	return p

func skip_welcome() -> void:
	Settings.set_value("welcome", "done", true)
	teleport(Vector3(0, 0, 0))

func _goto_station(id: String) -> void:
	var wc: Node = world.get_node_or_null("WorldContent") if world else null
	if wc and wc.welcome and wc.welcome.station_pos.has(id):
		var sp: Vector3 = wc.welcome.station_pos[id]
		teleport(sp + (WelcomeIsland.origin() - sp).normalized() * 3.0 + Vector3(0, 2, 0), true)

func _build_help() -> Dictionary:
	var p := _panel("❓ Help: Welcome Guide & Help Desk")
	var b: VBoxContainer = p["body"]
	for bot in WelcomeIsland.load_json(WelcomeIsland.FAQ).get("bots", []):
		b.add_child(label("%s: %s" % [bot["name"], bot["greeting"]], 24, Color(str(bot["color"]))))
	help_in = LineEdit.new()
	help_in.placeholder_text = "Ask a question (e.g. how do I fly?)"
	help_in.custom_minimum_size = Vector2(0, 96)
	help_in.add_theme_font_size_override("font_size", 28)
	help_in.text_submitted.connect(func(t): ask_help(t))
	b.add_child(help_in)
	b.add_child(btn("Ask", func(): ask_help(help_in.text)))
	help_out = label("", 26)
	help_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(help_out)
	for q in ["How do I fly?", "Where is the map?", "Combat rules?", "Where can I dance?", "Any events?"]:
		var qq: String = q
		b.add_child(btn(q, func(): ask_help(qq)))
	return p

var help_point := ""
func ask_help(q: String) -> String:
	var r := WelcomeIsland.answer(q)
	help_point = r["point"]
	EveCore.npc_say("Welcome Guide", str(r["answer"]))
	if help_out: help_out.text = "Guide: " + str(r["answer"]) + ("\n(Station: %s. Open Welcome Island to go there.)" % help_point if help_point != "" else "")
	return r["answer"]

func resolve_target(t: String) -> Vector3:
	if t == "welcome": return WelcomeIsland.spawn_point()
	if t == "spawn": return Vector3.ZERO
	var wc: Node = world.get_node_or_null("WorldContent") if world else null
	if wc:
		var l: Dictionary = wc.landmark_by_id(t)
		if not l.is_empty(): return l["position"] + Vector3(0, 0, 14)
	return Vector3.ZERO

func goto_target(t: String) -> void:
	if t == "welcome": go_welcome(false)
	else: teleport(resolve_target(t))

func _build_dest() -> Dictionary:
	var p := _panel("🗺 Destination Guide")
	var b: VBoxContainer = p["body"]
	var d := WelcomeIsland.load_json("res://data/welcome/destinations.json")
	for cat in d.get("categories", []):
		var sec := VBoxContainer.new()
		sec.name = str(cat)
		b.add_child(label("▸ " + str(cat), 30, GOLD))
		for x in d.get("destinations", []):
			if x["category"] != cat: continue
			var t: String = x["target"]
			b.add_child(btn("%s  ·  %s  →  go" % [x["name"], x["blurb"]], func(): goto_target(t)))
	b.add_child(label("📅 Events board", 34, MAG))
	for e in WelcomeIsland.load_json("res://data/welcome/events.json").get("events", []):
		var w: String = e["where"]
		b.add_child(btn("%s\n%s · host: %s\n%s  →  go" % [e["title"], e["when"], e["host"], e["desc"]], func(): goto_target(w)))
	return p

# ---------- v0.9 Region / Estate (SL/OpenSim "Region/Estate" + "About Land") ----------
var estate_box: VBoxContainer
var estate_scope := "region"  # "region" | "parcel"
func _build_estate() -> Dictionary:
	var p := _panel("🏛 Region / Estate")
	estate_box = p["body"]
	return p

func _est_region() -> String:
	return world.current_region() if world and world.has_method("current_region") else "Spawn"

func _est_get(key: String) -> Variant:
	var r := _est_region()
	return Estate.parcel_get(r, Estate.parcel_id(player.global_position), key) if estate_scope == "parcel" and player else Estate.region_get(r, key)

func _est_set(key: String, v: Variant) -> void:
	var r := _est_region()
	if estate_scope == "parcel" and player: Estate.parcel_set(r, Estate.parcel_id(player.global_position), key, v)
	else: Estate.region_set(r, key, v)
	if world and world.has_method("apply_estate"): world.apply_estate()

func _cycle_btn(title: String, key: String, opts: Array) -> Button:
	var b := btn("", func(): pass)
	var upd := func(): b.text = "%s: %s" % [title, str(_est_get(key)).replace("_", " ")]
	upd.call()
	b.pressed.connect(func():
		var i := opts.find(str(_est_get(key)))
		_est_set(key, opts[(i + 1) % opts.size()])
		upd.call())
	return b

func _check(title: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = title
	c.add_theme_font_size_override("font_size", FS)
	c.button_pressed = bool(_est_get(key))
	c.toggled.connect(func(on): _est_set(key, on))
	return c

func _refresh_estate() -> void:
	if estate_box == null: return
	for c in estate_box.get_children(): c.queue_free()
	var b := estate_box
	var r := _est_region()
	b.add_child(label("Region: %s   ·   Parcel %s" % [r, Estate.parcel_id(player.global_position) if player else "?"], 22, MAG))
	var sc := btn("Editing: " + ("THIS PARCEL (overrides region)" if estate_scope == "parcel" else "WHOLE REGION"), func():
		estate_scope = "parcel" if estate_scope == "region" else "region"
		_refresh_estate())
	b.add_child(sc)
	b.add_child(label("Ground", 26, GOLD))
	b.add_child(_cycle_btn("Land texture", "land_texture", Estate.LAND_TEXTURES))
	b.add_child(label("Water height: %.1f m" % float(_est_get("water_height")), 22))
	b.add_child(_slider(float(_est_get("water_height")), -20.0, 20.0, func(v): _est_set("water_height", v)))
	b.add_child(label("Sun & time", 26, GOLD))
	b.add_child(_check("Fixed sun (no day cycle)", "sun_fixed"))
	b.add_child(label("Sun hour (fixed sun)", 22))
	b.add_child(_slider(float(_est_get("sun_hour")), 0.0, 24.0, func(v): _est_set("sun_hour", v)))
	b.add_child(label("Access", 26, GOLD))
	b.add_child(_cycle_btn("Who can enter", "access", Estate.ACCESS))
	b.add_child(_cycle_btn("Who can terraform", "terraform", Estate.TERRAFORM))
	b.add_child(_check("Allow flying", "allow_fly"))
	b.add_child(_check("Allow building", "allow_build"))
	b.add_child(_check("Damage (combat) on", "allow_damage"))
	b.add_child(_check("Allow push", "allow_push"))
	b.add_child(_check("Allow landmarks", "allow_landmark"))
	b.add_child(_check("Allow Set Home", "allow_set_home"))
	b.add_child(_check("Show in search", "show_in_search"))
	b.add_child(_cycle_btn("Maturity", "maturity", Estate.MATURITY))
	b.add_child(label("Covenant (estate rules)", 22))
	var cv := TextEdit.new()
	cv.custom_minimum_size = Vector2(0, 160)
	cv.add_theme_font_size_override("font_size", 22)
	cv.text = Estate.covenant(r)
	cv.editable = Tiers.can(Tiers.SELF, "land", r)
	cv.focus_exited.connect(func():
		if cv.editable and cv.text != Estate.covenant(r):
			var e := Estate.set_covenant(r, cv.text)
			if e != "": Toast.show_toast(self, e, "warn"))
	b.add_child(cv)
	b.add_child(label("Allowed avatars (comma separated)", 22))
	var al := LineEdit.new()
	al.custom_minimum_size = Vector2(0, 68)
	al.add_theme_font_size_override("font_size", 22)
	al.text = ", ".join(PackedStringArray(_est_get("allowed")))
	al.text_submitted.connect(func(t): _est_set("allowed", Array(t.split(",", false)).map(func(x): return x.strip_edges())))
	b.add_child(al)
	b.add_child(label("Media & music", 26, GOLD))
	for f in [["music_url", "Parcel music URL (SoundCloud or MP3; blank = owner's SoundCloud)"], ["media_url", "Parcel media URL (video/web, future)"]]:
		b.add_child(label(f[1], 22))
		var le := LineEdit.new()
		le.custom_minimum_size = Vector2(0, 68)
		le.add_theme_font_size_override("font_size", 22)
		le.text = str(_est_get(f[0]))
		var k: String = f[0]
		le.text_submitted.connect(func(t): _est_set(k, t.strip_edges()))
		le.focus_exited.connect(func(): _est_set(k, le.text.strip_edges()))
		b.add_child(le)
	b.add_child(label("Saved on this phone. Grid sync comes with the region server.", 20))

# ---------- v0.9 Land tools (viewer "Edit Terrain": raise/lower/flatten/smooth/noise/revert) ----------
var land_op := "raise"
var land_size := 4.0
var land_strength := 0.5
var land_info: Label
func _build_land() -> Dictionary:
	var p := _panel("⛰ Land Tools")
	var b: VBoxContainer = p["body"]
	# keep the world visible behind: land panel is a bottom sheet
	(p["root"].get_child(0) as ColorRect).color = Color(0, 0, 0, 0)
	p["root"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	(p["root"].get_child(0) as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE
	p["land"] = true
	var grid := GridContainer.new()
	grid.columns = 3
	for op in Terraform.OPS:
		var o: String = op
		var t := btn("%s %s" % [Terraform.ICONS[o], o.capitalize()], func():
			land_op = o
			_land_info())
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	b.add_child(grid)
	b.add_child(label("Brush size", 22))
	b.add_child(_slider(land_size, Terraform.MIN_SIZE, Terraform.MAX_SIZE, func(v): land_size = v; _land_info()))
	b.add_child(label("Strength", 22))
	b.add_child(_slider(land_strength, 0.05, 1.0, func(v): land_strength = v; _land_info()))
	var go := btn("APPLY (hold to keep sculpting)", func(): pass)
	go.custom_minimum_size = Vector2(0, 110)
	var rep := Timer.new(); rep.wait_time = 0.15; add_child(rep)
	rep.timeout.connect(land_apply)
	go.button_down.connect(func(): land_apply(); rep.start())
	go.button_up.connect(rep.stop)
	b.add_child(go)
	land_info = label("", 22, MAG)
	b.add_child(land_info)
	_land_info()
	land_cursor = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0
	land_cursor.mesh = sm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 0.18, 0.82, 0.18)
	m.emission_enabled = true; m.emission = Color(1, 0.18, 0.82); m.emission_energy_multiplier = 0.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	land_cursor.material_override = m
	land_cursor.visible = false
	if world: world.call_deferred("add_child", land_cursor)
	return p

func _land_info() -> void:
	if land_info: land_info.text = "%s · size %.1f m · strength %d%% · brush sits in front of you" % [land_op.capitalize(), land_size, int(land_strength * 100)]

func land_target() -> Vector3:
	if player == null: return Vector3.ZERO
	var f := -player.global_transform.basis.z
	f.y = 0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var p := player.global_position + f * (land_size + 3.0)
	var g = world.generator if world and "generator" in world else null
	if g: p.y = g.height_f(p.x, p.z)
	return p

func land_apply() -> int:
	if world == null or not world.has_method("terraform"): return 0
	if not Estate.can_terraform(_est_region(), true):
		if land_info: land_info.text = "Terraform not allowed in this region."
		return 0
	var n: int = world.terraform(land_op, land_target(), land_size, land_strength)
	if n > 0: EveCore.for_companion(EveCore.OWNER_ID).log_build("terraform:" + str(land_op), {"pos": str(land_target().round()), "size": land_size, "changed": n})
	return n

func _process(_d: float) -> void:
	if land_cursor and land_cursor.visible:
		land_cursor.global_position = land_target()
		land_cursor.scale = Vector3.ONE * land_size


# ---------- Eve Core owner-approval queue ----------
var proposals_list: VBoxContainer
func _build_proposals() -> Dictionary:
	var p := _panel("Proposals")
	var b: VBoxContainer = p["body"]
	b.add_child(label("Companion update proposals waiting for your OK.", 22, GOLD))
	proposals_list = VBoxContainer.new()
	proposals_list.add_theme_constant_override("separation", 8)
	b.add_child(proposals_list)
	return p

func _refresh_proposals() -> void:
	if proposals_list == null: return
	for c in proposals_list.get_children(): c.queue_free()
	var all: Array = EveCore.proposals()
	if all.is_empty(): proposals_list.add_child(label("No proposals yet.", FS))
	for i in range(all.size() - 1, maxi(-1, all.size() - 31), -1):
		var pr: Dictionary = all[i]
		proposals_list.add_child(label("%s — %s [%s]" % [pr["companion"], pr["description"], pr["state"]], FS))
		if pr["state"] == "PendingApproval":
			var row := HBoxContainer.new()
			var pid: String = pr["id"]
			row.add_child(btn("✔ Approve", func(): EveCore.decide(pid, true); BrainCore.sync_owner_decisions(EveCore.proposals()); _refresh_proposals(), 160))
			row.add_child(btn("✖ Reject", func(): EveCore.decide(pid, false); BrainCore.sync_owner_decisions(EveCore.proposals()); _refresh_proposals(), 160))
			proposals_list.add_child(row)
	_refresh_brain_proposals()

## v0.10: BrainCore learned-cell proposals (from BrainLearner) + rollback of learned cells. Owner only.
func brain_decide(id: String, cell_id: String, approve: bool) -> bool:
	var b: BrainCore = AgentBrain.get_brain(id)
	if b == null or not EveCore.owner_ok(): return false
	var ok: bool = b.approve(cell_id).get("ok", false) if approve else b.reject(cell_id)
	if ok: EveCore.for_companion(id, b.persona)._log("Cell " + ("Approved" if approve else "Rejected"), "Brain", "Approved" if approve else "Rejected", cell_id)
	return ok

func brain_rollback(id: String, cell_id: String) -> bool:
	var b: BrainCore = AgentBrain.get_brain(id)
	if b == null or not EveCore.owner_ok(): return false
	var ok := b.rollback(cell_id)
	if ok: EveCore.for_companion(id, b.persona)._log("Cell Rolled Back", "Brain", "Active", cell_id)
	return ok

func _refresh_brain_proposals() -> void:
	proposals_list.add_child(label("— Learned brain cells —", 22, GOLD))
	for id in AgentBrain.brains:
		var b: BrainCore = AgentBrain.brains[id]
		var cid: String = id
		for c in b.pending():
			var cell_id := str(c.get("id", ""))
			proposals_list.add_child(label("%s learned: %s → %s (%s)" % [cid, JSON.stringify(c.get("trigger", {})).left(60), JSON.stringify(c.get("action", {})).left(60), c.get("provenance", {}).get("reason", "")], 20))
			var row := HBoxContainer.new()
			row.add_child(btn("✔ Approve", func(): brain_decide(cid, cell_id, true); _refresh_proposals(), 160))
			row.add_child(btn("✖ Reject", func(): brain_decide(cid, cell_id, false); _refresh_proposals(), 160))
			proposals_list.add_child(row)
		for cell_id in b.cells:
			if b.versions(cell_id).is_empty(): continue
			var ccid: String = cell_id
			var row2 := HBoxContainer.new()
			row2.add_child(label("%s · %s v%d w%.2f" % [cid, ccid, b.versions(ccid).back(), float(b.cells[ccid].get("weight", 0))], 20))
			row2.add_child(btn("↶ Roll back", func(): brain_rollback(cid, ccid); _refresh_proposals(), 160))
			proposals_list.add_child(row2)


# ---------- v0.10 History (per-companion memory timeline) ----------
var history_target := "foxy_ani"
var history_query := ""
var history_row: HBoxContainer
var history_list: VBoxContainer
var history_status: Label
func _build_history() -> Dictionary:
	var p := _panel("History")
	var b: VBoxContainer = p["body"]
	history_row = HBoxContainer.new(); b.add_child(history_row)
	var search := LineEdit.new()
	search.placeholder_text = "Search memories…"
	search.add_theme_font_size_override("font_size", FS)
	search.text_changed.connect(func(t): history_query = t; _refresh_history())
	b.add_child(search)
	var io := HBoxContainer.new()
	io.add_child(btn("⤒ Export", func(): _history_io(true), 160))
	io.add_child(btn("⤓ Import", func(): _history_io(false), 160))
	b.add_child(io)
	history_status = label("", 20, GOLD); b.add_child(history_status)
	history_list = VBoxContainer.new(); b.add_child(history_list)
	return p

static func history_export_path(id: String) -> String:
	return "user://exports/%s_portable.json" % id

func _persona_of(id: String) -> Dictionary:
	for c in _companions():
		if c.companion_id == id: return c.persona
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://companions/%s/persona.json" % id)) if FileAccess.file_exists("res://companions/%s/persona.json" % id) else null
	return d if d is Dictionary else {}

func _history_io(export: bool) -> void:
	var core := EveCore.for_companion(history_target, _persona_of(history_target))
	var path := history_export_path(history_target)
	if export:
		DirAccess.make_dir_recursive_absolute("user://exports")
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(core.export_portable(_persona_of(history_target)), "  "))
		history_status.text = "Exported to " + ProjectSettings.globalize_path(path)
	else:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		history_status.text = ("Imported %d entries" % core.import_portable(d)) if d is Dictionary else "No export file at " + path
	_refresh_history()

func _refresh_history() -> void:
	if history_list == null: return
	for c in history_row.get_children(): c.queue_free()
	for c in history_list.get_children(): c.queue_free()
	var ids: Array = [EveCore.OWNER_ID]
	for c in _companions(): ids.append(c.companion_id)
	if not ids.has(history_target): history_target = ids[0]
	for id in ids:
		var cid: String = id
		history_row.add_child(btn(("● " if cid == history_target else "") + cid.split("_")[0].capitalize(), func(): history_target = cid; _refresh_history(), 120))
	var es: Array = EveCore.for_companion(history_target, _persona_of(history_target)).search(history_query)
	if es.is_empty(): history_list.add_child(label("No memories yet." if EveCore.owner_ok() else "Locked: enter the owner code to view memories.", FS))
	for i in range(es.size() - 1, maxi(-1, es.size() - 61), -1):
		var e: Dictionary = es[i]
		history_list.add_child(label("%s  %s · %s\n%s" % [Time.get_datetime_string_from_unix_time(int(e.get("timestamp", 0)), true), e.get("event", ""), e.get("voice", ""), str(e.get("content", "")).left(160)], 20))
