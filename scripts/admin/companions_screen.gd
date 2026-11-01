class_name CompanionsScreen
extends Control
## v0.13 ADMIN-COMP: the voxel companion menu, moved into the Viper OS admin panel (owner only).
## Opened from Admin > Home > "Companions", from the main menu "🧬 Companions" entry (a redirect), and
## from the radial. Everything it shows used to live in the main menu; those panels still exist and the
## buttons here open them, so no old entry point breaks.
## Sections: companions here (talk) · add a companion (cinematic intro) · companion panels (moved from the
## main menu) · Brain Cell core (lock, versioned memories, ledger check, recall) · personality · voice.
## Not the owner (or locked)? The screen shows a lock card with an Unlock button and nothing else.

signal closed

const SUMMONED_KEY := "summoned"
## Main-menu companion panels now reached from here: [label, ui_root panel id]
const MOVED := [["💬 Talk", "chat"], ["🧑 Avatar", "avatar"], ["🎭 Roleplay", "rp"], ["🐉 Wyrmlings", "wyrm"],
	["📜 Proposals", "proposals"], ["🕮 History", "history"], ["◉ Nearby", "radar"], ["📡 Live", "_live"]]

var ui: Node = null          # ui_root (CanvasLayer) when opened in the app; null in some tests
var body: VBoxContainer
var status: Label
var recall_out: Label
var intro_speed := 1.0

static func open(host: Node, p_ui: Node = null) -> CompanionsScreen:
	var existing := host.get_node_or_null("CompanionsScreen")
	if existing and not existing.is_queued_for_deletion(): return existing
	var s := CompanionsScreen.new()
	s.name = "CompanionsScreen"
	s.ui = p_ui if p_ui != null else (host if host.has_method("show_panel") else null)
	host.add_child(s)
	return s

static func allowed() -> bool: return Tiers.owner_session()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = PhoenixTokens.VOID; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "bottom"]: m.add_theme_constant_override("margin_" + s, PhoenixTokens.space(5))
	m.add_theme_constant_override("margin_top", PhoenixTokens.space(6))
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.space(4)); m.add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new(); title.text = "Companions"; title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var close := Button.new(); close.text = "✕"; close.name = "Close"
	close.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap())
	close.pressed.connect(func(): closed.emit(); queue_free())
	head.add_child(close); v.add_child(head)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(status)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", PhoenixTokens.space(3)); sc.add_child(body)
	DisplaySettings.attach_responsive(m)
	refresh()

func _h(t: String) -> void:
	var l := Label.new(); l.text = t; l.add_theme_color_override("font_color", PhoenixTokens.GOLD)
	l.add_theme_font_size_override("font_size", 30)
	body.add_child(l)

func _p(t: String) -> Label:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(l)
	return l

func _b(t: String, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(0, PhoenixTokens.tap())
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	(parent if parent else body).add_child(b)
	return b

func _row() -> HFlowContainer:
	var r := HFlowContainer.new(); r.add_theme_constant_override("h_separation", 8); body.add_child(r)
	return r

func toast(t: String) -> void:
	if status: status.text = t

func companions_here() -> Array:
	return get_tree().get_nodes_in_group("companions") if is_inside_tree() else []

func refresh() -> void:
	for c in body.get_children(): c.queue_free()
	if not allowed():
		_h("Owner only")
		_p("The companion menu lives in the admin panel now. Unlock with your owner PIN to open it.")
		_b("🔓 Unlock", func():
			if ui and ui.has_method("open_unlock_prompt"): ui.open_unlock_prompt()
			queue_free())
		return
	# --- companions here
	_h("Here with you")
	var here := companions_here()
	if here.is_empty(): _p("No companions nearby.")
	for c in here:
		var cid := str(c.get("companion_id"))
		var nm := str(c.persona.get("display_name", c.persona.get("name", cid))) if c.get("persona") is Dictionary else cid
		_b("💬 %s  ·  %d memories" % [nm, MemoryVault.count(cid)], func(): talk_to(c))
	# --- add
	_h("Add a companion")
	var r := _row()
	for cid in available_to_add():
		var b := _b("✦ " + str(cid).replace("_", " ").capitalize(), func(): add_companion(cid), r)
		b.size_flags_horizontal = Control.SIZE_FILL
	# --- moved panels
	_h("Companion panels")
	var r2 := _row()
	for it in MOVED:
		var target: String = it[1]
		var b2 := _b(it[0], func(): open_panel(target), r2)
		b2.size_flags_horizontal = Control.SIZE_FILL
	# --- brain core
	_h("Brain Cell core")
	_p("Locked to companions: %s. Memories are versioned; nothing is ever overwritten or deleted." % ("yes" if MemoryVault.ai_locked() else "NO (owner opened a write window)"))
	var vr := InteractionLedger.verify()
	_p("Ledger: %d records, chain %s." % [vr["length"], "intact" if vr["ok"] else "BROKEN at %d (%s)" % [vr["broken_at"], vr["reason"]]])
	var r3 := _row()
	_b("Open AI writes 10 min", func():
		var e := MemoryVault.owner_unlock_ai(600)
		refresh()
		toast(e if e != "" else "Companions may add memories for 10 minutes."), r3).size_flags_horizontal = Control.SIZE_FILL
	_b("🔒 Lock now", func(): MemoryVault.lock(); toast("Brain Cell locked."); refresh(), r3).size_flags_horizontal = Control.SIZE_FILL
	var q := LineEdit.new(); q.placeholder_text = "Recall: type something to find similar memories"; body.add_child(q)
	recall_out = _p("")
	q.text_submitted.connect(func(t): recall_out.text = recall_text(t))
	# --- personality
	_h("Starting personality")
	var r4 := _row()
	for pr in [["foxy", "🔥 Foxy Ani Firecaster Gray"], ["none", "○ No personality"]]:
		var pid: String = pr[0]
		var b4 := _b(("● " if PersonaPresets.preset() == pid else "") + pr[1], func(): PersonaPresets.set_preset(pid); refresh(), r4)
		b4.size_flags_horizontal = Control.SIZE_FILL
	# --- voice
	_h("Voice")
	for k in [["pitch", "Pitch"], ["rate", "Speed"]]:
		var key: String = k[0]
		_p("%s: %.2f" % [k[1], float(Settings.get_value("voice", key, 1.0))])
		var s := HSlider.new(); s.min_value = 0.5; s.max_value = 2.0; s.step = 0.05
		s.value = float(Settings.get_value("voice", key, 1.0)); s.custom_minimum_size = Vector2(0, 48)
		s.drag_ended.connect(func(_c): Settings.set_value("voice", key, s.value); refresh())
		body.add_child(s)
	_b("▶ Test voice", func():
		var route := CompanionVoice.speak("voice_test", {"voice": {}}, "Rise from the flame.")
		toast("Voice route: " + route))

func open_panel(target: String) -> void:
	if target == "_live":
		LiveFeedScreen.open(ui if ui else get_parent())
		queue_free()
		return
	if ui and ui.has_method("show_panel"):
		ui.show_panel(target)
		queue_free()

func talk_to(c: Node) -> void:
	if ui and ui.has_method("_pick_chat"):
		ui._pick_chat(c)
		ui.show_panel("chat")
	queue_free()

func recall_text(q: String) -> String:
	var lines := PackedStringArray()
	for c in companions_here():
		for hit in PatternRecall.recall(str(c.get("companion_id")), q, 3):
			lines.append("%s%s: %s (%.2f)" % ["✨ déjà vu · " if hit["deja_vu"] else "", c.get("companion_id"), str(hit["text"]).left(80), hit["score"]])
	return "\n".join(lines) if not lines.is_empty() else "Nothing similar yet."

## Persona folders under res://companions not already in the world.
func available_to_add() -> Array:
	var here := {}
	for c in companions_here(): here[str(c.get("companion_id"))] = true
	var out: Array = []
	for d in DirAccess.get_directories_at("res://companions"):
		if FileAccess.file_exists("res://companions/%s/persona.json" % d) and not here.has(d): out.append(d)
	return out

## Add a companion to the world near the player and play the cinematic intro.
func add_companion(cid: String) -> Dictionary:
	var r := CompanionsScreen.summon(ui, cid, intro_speed)
	toast(str(r.get("error", "Welcome, %s." % cid)))
	if not r.has("error"): queue_free()
	return r

static func persona_of(cid: String) -> Dictionary:
	var p := "res://companions/%s/persona.json" % cid
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
	return d if d is Dictionary else {}

## Owner-only. Spawns scenes/companion_agent.tscn with a CompanionConfig for that persona.
## intro: play CompanionIntro over ui. remember: keep it in Settings so it comes back next launch.
static func summon(p_ui: Node, cid: String, p_intro_speed := 1.0, intro := true, remember := true) -> Dictionary:
	if not allowed(): return {"error": "Owner unlock needed."}
	return _spawn(p_ui, cid, p_intro_speed, intro, remember)

static func _spawn(p_ui: Node, cid: String, p_intro_speed: float, intro: bool, remember: bool) -> Dictionary:
	var persona := persona_of(cid)
	if persona.is_empty(): return {"error": "No such companion."}
	var world: Node = p_ui.get("world") if p_ui else null
	var player: Node3D = p_ui.get("player") if p_ui else null
	if world == null or not world.is_inside_tree(): return {"error": "No world loaded."}
	for c in world.get_tree().get_nodes_in_group("companions"):
		if str(c.get("companion_id")) == str(persona.get("id", cid)): return {"error": "Already here."}
	var cfg := CompanionConfig.new()
	cfg.persona_path = "res://companions/%s/persona.json" % cid
	cfg.body_color = Color(PhoenixTokens.MAGENTA_DEEP); cfg.accent_color = Color(PhoenixTokens.GOLD)
	cfg.slot_offset = Vector3(randf_range(-4, 4), 0, randf_range(-5, -2))
	var n: Node3D = load("res://scenes/companion_agent.tscn").instantiate()
	n.set("config", cfg)
	if player: n.set("player_path", player.get_path())
	n.set("world_path", world.get_path())
	n.name = "Summoned_" + cid
	world.add_child(n)
	n.global_position = (player.global_position if player else Vector3.ZERO) + Vector3(randf_range(-3, 3), 2.0, randf_range(-4, -2))
	if remember:
		var list: Array = Settings.get_value("companions", SUMMONED_KEY, [])
		if not cid in list:
			list.append(cid)
			Settings.set_value("companions", SUMMONED_KEY, list)
	if bool(Settings.get_value("brain", "scene_snapshots", true)):
		SceneSnapshots.capture("companion_join", {"companion": cid}, cid)
	var out := {"ok": true, "node": n}
	if intro and p_ui: out["intro"] = CompanionIntro.play(p_ui, cid, persona, p_intro_speed)
	return out

## Bring back companions the owner added in earlier sessions (no intro). Only ids the owner saved
## through summon() are in the list, so this needs no unlock at launch.
static func restore(p_ui: Node) -> int:
	var n := 0
	for cid in Settings.get_value("companions", SUMMONED_KEY, []):
		if not CompanionsScreen._spawn(p_ui, str(cid), 1.0, false, false).has("error"): n += 1
	return n
