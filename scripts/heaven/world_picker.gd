class_name WorldPicker
extends Control
## HEAVEN-5: grids = realms. Glass picker opened from the ☰ menu (🌐 Worlds) and the Community
## shell's Overview card. Lists data/heaven/grids.json; Enter travels there; "Make this my start
## world" stores Settings world/start_realm (Heaven is the default for every user).
signal closed

const DATA := "res://data/heaven/grids.json"
static var _grids: Array = []

static func grids() -> Array:
	if _grids.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_grids = d.get("grids", []) if d is Dictionary else []
		_grids = _grids + CompanionHomes.grids()   # v0.14 HOME-1: one home realm per court companion
	return _grids

static func grid(id: String) -> Dictionary:
	for g in grids():
		if g["id"] == id: return g
	return {}

static func default_id() -> String:
	for g in grids():
		if bool(g.get("default", false)): return str(g["id"])
	return "heaven"

static func start_realm() -> String:
	var s := str(Settings.get_value("world", "start_realm", default_id()))
	return s if not grid(s).is_empty() else default_id()

static func set_start_realm(id: String) -> bool:
	if grid(id).is_empty(): return false
	Settings.set_value("world", "start_realm", id)
	return true

## Where a grid's entry is: {"kind": "heaven"|"welcome"|"ground", "pos": Vector3 (ground: y = 0, caller snaps)}.
## "biome:N" spirals out from the origin (128 m steps) to the nearest column of that biome.
static func target(g: Dictionary, gen: Object = null) -> Dictionary:
	var e: Variant = g.get("enter", [0, 0])
	if e is String and e == "heaven": return {"kind": "heaven", "pos": HeavenLayout.spawn_point()}
	if e is String and e == "welcome": return {"kind": "welcome", "pos": WelcomeIsland.spawn_point()}
	if e is String and str(e).begins_with("home:"): return CompanionHomes.target(str(e).trim_prefix("home:"), gen)   # v0.14 HOME-1
	if e is String and str(e).begins_with("biome:"):
		var want := int(str(e).trim_prefix("biome:"))
		if gen and gen.has_method("biome_at"):
			for ring in range(0, 32):
				var r := ring * 128.0
				var steps := maxi(1, ring * 8)
				for k in steps:
					var a := TAU * k / steps
					var x := cos(a) * r; var z := sin(a) * r
					if int(gen.biome_at(x, z)) == want: return {"kind": "ground", "pos": Vector3(x, 0, z)}
		return {"kind": "ground", "pos": Vector3.ZERO}
	if e is Array and e.size() == 2: return {"kind": "ground", "pos": Vector3(float(e[0]), 0, float(e[1]))}
	return {"kind": "ground", "pos": Vector3.ZERO}

## Travel there through the UI root (keeps teleport history and companion follow).
static func enter(ui: Node, id: String) -> String:
	var g := grid(id)
	if g.is_empty(): return "Unknown world."
	var w = ui.get("world") if ui else null
	var gen = w.get("generator") if w else null
	var t := target(g, gen)
	CompanionHomes.clear_visitors(w)   # v0.14 HOME-1: last trip's visitors go home
	match t["kind"]:
		"heaven":
			var hw: Node = w.get_node_or_null("HeavenWorld") if w else null
			if hw and hw.has_method("go_spawn"):
				ui.teleport(t["pos"], true)
				hw.go_spawn()
			else: ui.teleport(t["pos"], true)
			CompanionHomes.heaven_court(ui)
		"welcome": ui.go_welcome(false)
		"companion_home":
			ui.teleport(t["pos"])
			CompanionHomes.arrive(ui, str(t["companion"]))
		_: ui.teleport(t["pos"])
	return ""

static func open(parent: Node) -> WorldPicker:
	var ex := parent.get_node_or_null("WorldPicker")
	if ex: return ex
	var s := WorldPicker.new(); s.name = "WorldPicker"
	parent.add_child(s)
	return s

var body: VBoxContainer

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
	var t := Label.new(); t.text = "🌐 Worlds"; t.theme_type_variation = &"TitleLabel"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN, PhoenixTokens.TAP_MIN)
	x.pressed.connect(func(): closed.emit(); queue_free()); head.add_child(x)
	v.add_child(head)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", PhoenixTokens.SPACE[3]); sc.add_child(body)
	refresh()

func refresh() -> void:
	for ch in body.get_children(): body.remove_child(ch); ch.queue_free()
	var start := start_realm()
	for g in grids():
		var c := ViperKit.card(str(g["name"]) + ("  ★ start" if g["id"] == start else ""))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(c)
		HeavenScreen._text(c.body(), str(g.get("about", "")))
		var id := str(g["id"])
		HeavenScreen._btn(c.body(), "Enter", func(): _enter(id), "Enter_" + id)
		if id != start: HeavenScreen._btn(c.body(), "Make this my start world", func(): set_start_realm(id); refresh(), "Start_" + id)

func _enter(id: String) -> void:
	var ui := get_parent()
	while ui and not ui.has_method("teleport"): ui = ui.get_parent()
	if ui: enter(ui, id)
	closed.emit(); queue_free()

static func reset_for_tests() -> void: _grids = []
