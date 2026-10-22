class_name SegmentedPills
extends HBoxContainer
## Segmented filter pills (§8 Admin table: "Filters are segmented pills at the top").
signal changed(id: String)
var options: Array = []   # [[id, label], ...]
var selected := ""
var _group := ButtonGroup.new()

func setup(p_options: Array, initial := "") -> SegmentedPills:
	options = p_options
	selected = initial if initial != "" else (str(options[0][0]) if not options.is_empty() else "")
	for c in get_children(): c.queue_free()
	add_theme_constant_override("separation", PhoenixTokens.space(2))
	for o in options:
		var b := Button.new()
		b.text = str(o[1]); b.toggle_mode = true; b.button_group = _group
		b.custom_minimum_size = Vector2(0, PhoenixTokens.tap()); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = str(o[0]) == selected
		var id := str(o[0])
		b.pressed.connect(func(): select(id))
		add_child(b)
	return self

func select(id: String) -> void:
	if id == selected: return
	selected = id
	for i in options.size(): (get_child(i) as Button).set_pressed_no_signal(str(options[i][0]) == id)
	changed.emit(id)
