class_name LiveFeedScreen
extends Control
## v0.13.1 LIVE-1: the "Companions Live" feed (Social.feed(viewer, "live")). One card per companion
## with their latest creations; "Share" posts it as the companion -> owner approval queue.

var list: VBoxContainer
var status: Label

static func open(host: Node) -> LiveFeedScreen:
	var e := host.get_node_or_null("LiveFeedScreen")
	if e and not e.is_queued_for_deletion(): return e
	var s := LiveFeedScreen.new(); s.name = "LiveFeedScreen"
	host.add_child(s)
	return s

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = PhoenixTokens.VOID; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	add_child(GlamFx.sparkle_layer("ui"))
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "bottom", "top"]: m.add_theme_constant_override("margin_" + s, PhoenixTokens.space(5))
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.space(3)); m.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	var title := Label.new(); title.text = "📡 Companions Live"; title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var mk := Button.new(); mk.text = "✨ Create"; mk.name = "CreateCompanion"   # v0.14 CREATE-1 (members)
	mk.custom_minimum_size = Vector2(0, PhoenixTokens.tap())
	mk.pressed.connect(func(): CompanionCreatorScreen.open(get_parent())); head.add_child(mk)
	var close := Button.new(); close.text = "✕"; close.name = "Close"
	close.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap())
	close.pressed.connect(queue_free); head.add_child(close)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(status)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", PhoenixTokens.space(3)); sc.add_child(list)
	refresh()

func refresh() -> void:
	for c in list.get_children(): c.queue_free()
	var extra: Array = []
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group("companions"): extra.append(str(c.get("companion_id")))
	var page := CompanionLive.page("self", extra)
	if not page["ok"]:
		status.text = str(page["error"]); return
	status.text = "%d companions · live in-world activity (never private chats)" % page["items"].size()
	var opt := CheckButton.new(); opt.text = "Show my words on Companions Live"; opt.name = "OptIn"
	opt.button_pressed = CompanionBroadcast.opted_in("self")
	opt.toggled.connect(func(on): CompanionBroadcast.set_opt_in("self", on))
	list.add_child(opt)
	for it in page["items"]:
		var card := PanelContainer.new()
		var cv := VBoxContainer.new(); card.add_child(cv)
		var nm := Label.new(); nm.text = ("🔴 LIVE · " if it["live"] else "") + str(it["author_name"])
		nm.add_theme_color_override("font_color", PhoenixTokens.GOLD); cv.add_child(nm)
		var tx := Label.new(); tx.text = str(it["text"]); tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cv.add_child(tx)
		# v0.14 LIVE-2: status + the latest in-world lines (companions and opted-in viewers)
		var st := Label.new(); st.text = {"idle": "💤 idle", "building": "🧱 building", "talking": "💬 talking", "viewer": "💬 with viewers"}.get(str(it.get("status", "idle")), "💤 idle")
		cv.add_child(st)
		for e in it.get("broadcast", []).slice(-4):
			var ln := Label.new(); ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var who := str(e.get("from", e.get("cid", "")))
			ln.text = "%s%s: %s" % [who, (" → " + str(e["to"])) if e.has("to") else "", str(e.get("text", ""))]
			cv.add_child(ln)
		var meta := Label.new(); meta.text = "%d creations" % it["creations"] + (" · %d chats" % it["chats"] if it.has("chats") else "")
		meta.add_theme_color_override("font_color", PhoenixTokens.PLATINUM); cv.add_child(meta)
		var cid := str(it["author"])
		var sh := Button.new(); sh.text = "Share to feed (you approve first)"
		sh.custom_minimum_size = Vector2(0, PhoenixTokens.tap())
		sh.pressed.connect(func():
			var r := CompanionLive.share(cid)
			status.text = "Waiting for your approval in Proposals." if r.get("ok", false) else str(r.get("error", "")))
		cv.add_child(sh)
		list.add_child(card)
