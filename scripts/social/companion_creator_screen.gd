class_name CompanionCreatorScreen
extends Control
## v0.14 CREATE-1: the "Create your own companion" form. Members fill in a name, role, personality, home
## realm and palette; Create plays the cinematic reveal (CompanionIntro) in front of them.
## Non-members see what membership unlocks and a note that they can talk with the owner's companions.

var form: VBoxContainer
var status: Label
var realm := "cosmic"
var palette := "phoenix"

static func open(host: Node) -> CompanionCreatorScreen:
	var e := host.get_node_or_null("CompanionCreatorScreen")
	if e and not e.is_queued_for_deletion(): return e
	var s := CompanionCreatorScreen.new(); s.name = "CompanionCreatorScreen"
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
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; m.add_child(sc)
	form = VBoxContainer.new(); form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", PhoenixTokens.space(3)); sc.add_child(form)
	var head := HBoxContainer.new(); form.add_child(head)
	var t := Label.new(); t.text = "✨ Create your own companion"; t.theme_type_variation = &"TitleLabel"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap())
	x.pressed.connect(queue_free); head.add_child(x)
	status = Label.new(); status.name = "Status"; status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; form.add_child(status)
	if not CompanionCreator.is_member("self"):
		status.text = "Members only (Premium / Creator). Members design an original companion and watch it arrive in a cinematic reveal.\nYou can meet and talk with the owner's companions in their home realms and in Heaven."
		return
	var nm := _field("Name", "Name"); var role := _field("Role", "Role (e.g. explorer, builder, singer)")
	var pers := _field("Personality", "Personality in a sentence")
	form.add_child(_pills("Home realm", CompanionCreator.REALMS, func(id): realm = id, realm))
	form.add_child(_pills("Palette", CompanionCreator.PALETTES.keys(), func(id): palette = id, palette))
	var go := Button.new(); go.name = "Create"; go.text = "Create & reveal"; go.custom_minimum_size.y = PhoenixTokens.tap()
	go.pressed.connect(func():
		var r := CompanionCreator.create("self", {"name": nm.text, "role": role.text, "personality": pers.text, "home_realm": realm, "palette": palette})
		if not r["ok"]: status.text = r["error"]; return
		var ui := get_parent()
		while ui and not ui.has_method("teleport"): ui = ui.get_parent()
		if ui: CompanionCreator.reveal(ui, r["id"])
		queue_free())
	form.add_child(go)
	form.add_child(_note("Your companion is an original character, general audience, and saved on this device."))

func _field(n: String, ph: String) -> LineEdit:
	var l := LineEdit.new(); l.name = n; l.placeholder_text = ph; l.custom_minimum_size.y = PhoenixTokens.tap()
	form.add_child(l)
	return l

func _note(t: String) -> Label:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", PhoenixTokens.PLATINUM_DIM)
	return l

func _pills(title: String, ids: Array, on: Callable, cur: String) -> Control:
	var v := VBoxContainer.new()
	v.add_child(_note(title))
	var opts: Array = ids.map(func(i): return [str(i), str(i).replace("_", " ").capitalize()])
	var seg := SegmentedPills.new().setup(opts, cur)
	seg.changed.connect(on)
	v.add_child(seg)
	return v
