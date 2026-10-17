class_name PillRow
extends PanelContainer
## Admin table row (§8): glass pill with avatar ring, primary text, ONE status chip, swipe-left actions.
## Tap -> `tapped`; swipe left reveals action pills (approve/reject/more...) -> `action(id)`; swipe right hides them.
signal tapped
signal action(id: String)

const SWIPE_PX := 80.0
var primary := ""
var secondary := ""
var chip := ""
var chip_color := PhoenixTokens.MAGENTA
var avatar_text := "◎"
var avatar_color := PhoenixTokens.MAGENTA
var actions: Array = []    # [[id, label], ...]
var _actions_box: HBoxContainer
var _press := Vector2.ZERO
var _dragging := false

func setup(p_primary: String, p_chip := "", p_actions: Array = [], p_secondary := "", p_avatar := "", p_avatar_color := PhoenixTokens.MAGENTA) -> PillRow:
	primary = p_primary; chip = p_chip; actions = p_actions; secondary = p_secondary
	avatar_text = p_avatar if p_avatar != "" else (p_primary.left(1).to_upper() if p_primary != "" else "◎")
	avatar_color = p_avatar_color
	return self

func _ready() -> void:
	custom_minimum_size.y = 76
	var sb := StyleBoxFlat.new()
	sb.bg_color = PhoenixTokens.GLASS; sb.border_color = Color(PhoenixTokens.MAGENTA, 0.35)
	sb.set_border_width_all(1); sb.set_corner_radius_all(PhoenixTokens.RADIUS.pill)
	sb.content_margin_left = 10; sb.content_margin_right = 16; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.anti_aliasing = true
	add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", PhoenixTokens.space(4)); h.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(h)
	var av := _Avatar.new(); av.text = avatar_text; av.col = avatar_color; h.add_child(av)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := Label.new(); l.text = primary; l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", PhoenixTokens.fs("body")); v.add_child(l)
	if secondary != "":
		var s := Label.new(); s.text = secondary; s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.add_theme_font_size_override("font_size", PhoenixTokens.fs("micro")); s.add_theme_color_override("font_color", PhoenixTokens.PLATINUM_DIM)
		v.add_child(s)
	h.add_child(v)
	if chip != "": h.add_child(_chip(chip, chip_color))
	_actions_box = HBoxContainer.new(); _actions_box.visible = false; _actions_box.add_theme_constant_override("separation", 8)
	for a in actions:
		var b := Button.new(); b.text = str(a[1]); b.custom_minimum_size = Vector2(96, PhoenixTokens.tap())
		var id := str(a[0])
		b.pressed.connect(func(): hide_actions(); action.emit(id))
		_actions_box.add_child(b)
	h.add_child(_actions_box)

static func _chip(t: String, c: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(c, 0.18); sb.border_color = c; sb.set_border_width_all(1)
	sb.set_corner_radius_all(PhoenixTokens.RADIUS.pill); sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb); p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new(); l.text = t.to_upper(); l.add_theme_font_size_override("font_size", PhoenixTokens.fs("micro"))
	l.add_theme_color_override("font_color", c); p.add_child(l)
	return p

func show_actions() -> void: if _actions_box and not actions.is_empty(): _actions_box.visible = true
func hide_actions() -> void: if _actions_box: _actions_box.visible = false
func actions_visible() -> bool: return _actions_box != null and _actions_box.visible

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		if e.pressed: _press = e.position; _dragging = true
		elif _dragging:
			_dragging = false
			swipe(e.position.x - _press.x, absf(e.position.y - _press.y))

## dx < -SWIPE_PX reveals actions, dx > SWIPE_PX hides them, a small move is a tap.
func swipe(dx: float, dy := 0.0) -> void:
	if dx < -SWIPE_PX and dy < SWIPE_PX: show_actions()
	elif dx > SWIPE_PX and dy < SWIPE_PX: hide_actions()
	elif absf(dx) < 12 and dy < 12: tapped.emit()

class _Avatar extends Control:
	var text := ""
	var col := Color.WHITE
	func _init() -> void: custom_minimum_size = Vector2(56, 56); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 26, Color(PhoenixTokens.OBSIDIAN, 0.9))
		draw_arc(c, 24, 0, TAU, 48, col, 3.0, true)
		var f := get_theme_default_font()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, c + Vector2(-w / 2, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, PhoenixTokens.PLATINUM)
