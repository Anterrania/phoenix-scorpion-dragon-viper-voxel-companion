class_name SignupStepper
extends VBoxContainer
## Sign-up stepper (§8): ring progress with the step count, ONE question per screen
## (name -> avatar -> voice -> realm -> done), 64 px inputs, primary pill at the bottom,
## back by swiping right (or the ‹ pill), phoenix burst on completion. Local only: emits `completed(data)`.
signal completed(data: Dictionary)
const STEPS := ["name", "avatar", "voice", "realm", "done"]
const RING := preload("res://scenes/ui/kit/ring_stat.tscn")
const VOICES := [["warm", "Warm"], ["bright", "Bright"], ["deep", "Deep"], ["whisper", "Whisper"]]
var step := 0
var data := {"name": "", "handle": "", "avatar": "wanderer", "voice": "warm", "realm": "alaskan_tundra"}
var ring: RingStat
var _q: Label
var _body: VBoxContainer
var _err: Label
var _next: Button
var _press_x := 0.0
var burst: CPUParticles2D

func _init() -> void:
	add_theme_constant_override("separation", PhoenixTokens.space(5))
	var rc := CenterContainer.new(); add_child(rc)
	ring = RING.instantiate(); ring.custom_minimum_size = Vector2(160, 160); rc.add_child(ring)
	_q = Label.new(); _q.theme_type_variation = &"TitleLabel"; _q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_q)
	_body = VBoxContainer.new(); _body.size_flags_vertical = Control.SIZE_EXPAND_FILL; _body.add_theme_constant_override("separation", 12)
	add_child(_body)
	_err = Label.new(); _err.add_theme_color_override("font_color", PhoenixTokens.ERR); _err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_err)
	var nav := HBoxContainer.new(); nav.add_theme_constant_override("separation", 12)
	var back := Button.new(); back.text = "‹"; back.custom_minimum_size = Vector2(64, 64); back.pressed.connect(prev)
	_next = Button.new(); _next.custom_minimum_size = Vector2(0, 64); _next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(next)
	nav.add_child(back); nav.add_child(_next); add_child(nav)
	burst = CPUParticles2D.new(); burst.emitting = false; burst.one_shot = true; burst.amount = 64; burst.lifetime = 0.8
	burst.explosiveness = 0.95; burst.spread = 180; burst.initial_velocity_min = 180; burst.initial_velocity_max = 420
	burst.gravity = Vector2(0, -60); burst.scale_amount_min = 3; burst.scale_amount_max = 6
	var g := Gradient.new(); g.set_color(0, PhoenixTokens.VENUS); g.set_color(1, Color(PhoenixTokens.PHOENIX, 0)); g.add_point(0.5, PhoenixTokens.EMBER)
	burst.color_ramp = g
	rc.add_child(burst)

func _ready() -> void: _render()

func prefill(d: Dictionary) -> void:
	for k in data: if d.has(k): data[k] = d[k]
	if is_inside_tree(): _render()

static func validate(field: String, d: Dictionary) -> String:
	match field:
		"name":
			if str(d.get("name", "")).strip_edges().length() < 2: return "Name needs at least 2 letters."
			if RegEx.create_from_string("^[A-Za-z0-9_]{3,24}$").search(str(d.get("handle", "")).trim_prefix("@")) == null: return "Handle: 3–24 letters, digits or _."
		"voice":
			if not VOICES.any(func(v): return v[0] == d.get("voice")): return "Pick a voice."
		"realm":
			if not FileAccess.file_exists("res://data/realm_presets/%s.json" % d.get("realm", "")): return "Pick a realm."
	return ""

func next() -> void:
	if step == STEPS.size() - 1: return
	_collect()
	var e := validate(STEPS[step], data)
	_err.text = e
	if e != "": return
	step += 1
	_render()
	if STEPS[step] == "done":
		burst.position = ring.size / 2; burst.restart()
		completed.emit(data.duplicate())

func prev() -> void:
	if step > 0 and STEPS[step] != "done": step -= 1; _err.text = ""; _render()

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		if e.pressed: _press_x = e.position.x
		elif e.position.x - _press_x > 120: prev()

var _inputs := {}
func _collect() -> void:
	for k in _inputs:
		var w = _inputs[k]
		if w is LineEdit: data[k] = w.text.strip_edges().trim_prefix("@") if k == "handle" else w.text.strip_edges()

func _field(key: String, ph: String) -> LineEdit:
	var e := LineEdit.new(); e.placeholder_text = ph; e.text = str(data.get(key, "")); e.custom_minimum_size.y = 64
	e.max_length = 24; e.add_theme_font_size_override("font_size", PhoenixTokens.fs("headline"))
	e.text_submitted.connect(func(_t): next())
	_inputs[key] = e
	return e

func _choices(key: String, opts: Array) -> void:
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	var group := ButtonGroup.new()
	for o in opts:
		var b := Button.new(); b.text = str(o[1]); b.toggle_mode = true; b.button_group = group
		b.custom_minimum_size = Vector2(0, 72); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = data.get(key) == o[0]
		var id = o[0]
		b.pressed.connect(func(): data[key] = id)
		grid.add_child(b)
	_body.add_child(grid)

func _render() -> void:
	if _body == null: return
	for c in _body.get_children(): _body.remove_child(c); c.queue_free()
	_inputs.clear()
	ring.value = float(step + 1) / STEPS.size()
	ring.display_text = "%d/%d" % [step + 1, STEPS.size()]
	ring.caption = STEPS[step]
	_next.text = "Next" if step < STEPS.size() - 2 else ("Finish" if step == STEPS.size() - 2 else "Done ✓")
	_next.disabled = STEPS[step] == "done"
	match STEPS[step]:
		"name":
			_q.text = "What should we call you?"
			_body.add_child(_field("name", "Display name"))
			_body.add_child(_field("handle", "Handle (letters, digits, _)"))
		"avatar":
			_q.text = "Choose your look"
			var opts: Array = []
			var o: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/avatar_options.json"))
			if o is Dictionary:
				for p in o.get("presets", []):
					if not bool(p.get("owner_only", false)): opts.append([p["id"], p.get("label", p.get("name", p["id"]))])
			_choices("avatar", opts)
		"voice":
			_q.text = "Pick a voice"
			_choices("voice", VOICES)
		"realm":
			_q.text = "Where do you begin?"
			var rs: Array = []
			for f in DirAccess.get_files_at("res://data/realm_presets"):
				if f.ends_with(".json"): rs.append([f.get_basename(), f.get_basename().replace("_", " ").capitalize()])
			_choices("realm", rs)
		"done":
			_q.text = "Welcome, %s." % data["name"]
			var l := Label.new(); l.text = "Saved on this device only. No account was created anywhere."
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_color_override("font_color", PhoenixTokens.PLATINUM_DIM); _body.add_child(l)
