class_name GlassMenu
extends VBoxContainer
## Glass menu (calm premium, docs/UI_DESIGN_LANGUAGE.md §12): a short vertical list of full-width rows.
## Each row: glyph, label, optional badge, chevron. One tap = item_selected(id). No glow on rows; the
## only accent is the magenta press tint. Rows marked `foxy` use the ember accent (ember is for Foxy only).
## Sizes, colors and timings come from PhoenixTokens (row height = TAP_MIN, label = TYPE.body).
signal item_selected(id: String)

const MAX_ROWS := 7   # §8: lists over 7 rows page instead
var _rows := {}

func _init() -> void:
	add_theme_constant_override("separation", PhoenixTokens.SPACE[2])

## Adds a row; returns its Button (or null past MAX_ROWS).
func add_item(id: String, text: String, glyph := "", badge := "", foxy := false) -> Button:
	if _rows.size() >= MAX_ROWS: return null
	var b := Button.new(); b.name = "Row_" + id
	b.custom_minimum_size = Vector2(0, PhoenixTokens.TAP_MIN)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = ("%s   %s" % [glyph, text]) if glyph != "" else text
	b.add_theme_font_size_override("font_size", PhoenixTokens.TYPE.body)
	var accent: Color = PhoenixTokens.EMBER if foxy else PhoenixTokens.MAGENTA
	for st in [["normal", 0.0, 0.0], ["hover", 0.08, 0.25], ["pressed", 0.18, 0.5], ["focus", 0.0, 0.6]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(PhoenixTokens.OBSIDIAN, 0.55).lerp(Color(accent, 0.5), st[1]) if st[1] > 0.0 else Color(PhoenixTokens.OBSIDIAN, 0.55)
		sb.set_corner_radius_all(PhoenixTokens.RADIUS.m)
		sb.content_margin_left = PhoenixTokens.SPACE[5]; sb.content_margin_right = PhoenixTokens.SPACE[5]
		if st[2] > 0.0:
			sb.border_color = Color(accent if st[0] != "focus" else PhoenixTokens.GOLD, st[2]); sb.set_border_width_all(1)
		b.add_theme_stylebox_override(st[0], sb)
	b.add_theme_color_override("font_color", PhoenixTokens.PLATINUM)
	b.add_theme_color_override("font_hover_color", PhoenixTokens.PLATINUM)
	b.add_theme_color_override("font_pressed_color", PhoenixTokens.PLATINUM)
	var tail := Label.new(); tail.name = "Tail"
	tail.text = ("%s   ›" % badge) if badge != "" else "›"
	tail.add_theme_color_override("font_color", PhoenixTokens.GOLD if badge != "" else PhoenixTokens.PLATINUM_DIM)
	tail.add_theme_font_size_override("font_size", PhoenixTokens.TYPE.body)
	tail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	tail.offset_left = -PhoenixTokens.SPACE[7] * 2; tail.offset_right = -PhoenixTokens.SPACE[5]
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tail)
	b.pressed.connect(func(): item_selected.emit(id))
	add_child(b); _rows[id] = b
	return b

func row(id: String) -> Button: return _rows.get(id)
func ids() -> Array: return _rows.keys()
func set_badge(id: String, badge: String) -> void:
	var b: Button = _rows.get(id)
	if b == null: return
	var t: Label = b.get_node("Tail")
	t.text = ("%s   ›" % badge) if badge != "" else "›"
	t.add_theme_color_override("font_color", PhoenixTokens.GOLD if badge != "" else PhoenixTokens.PLATINUM_DIM)
