@tool
class_name RadialMenu
extends Control
## Ring of big round icon buttons around a central hub. Tap hub to open/close; tap item emits item_selected(id).
signal item_selected(id: String)
@export var items: Array[String] = ["Build", "Map", "Chat", "Music", "Land", "Exit"]
@export var glyphs: Array[String] = ["⬢", "◎", "✦", "♪", "▲", "⏻"]
@export var open := true: set = set_open
@export var button_radius := 36.0
var _t := 1.0
var _hover := -1
func _ready() -> void: custom_minimum_size = Vector2(320, 320)
func set_open(v: bool) -> void:
	open = v
	if is_inside_tree() and not Engine.is_editor_hint():
		create_tween().tween_property(self, "_t", 1.0 if v else 0.0, PhoenixTokens.MOTION.base).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else: _t = 1.0 if v else 0.0
func _item_pos(i: int) -> Vector2:
	var r := (minf(size.x, size.y) / 2.0 - button_radius - 4) * _t
	return size / 2.0 + Vector2.from_angle(-PI / 2.0 + TAU * i / maxi(items.size(), 1)) * r
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if e.position.distance_to(size / 2.0) < button_radius * 1.2: set_open(not open); accept_event(); return
		for i in items.size():
			if open and e.position.distance_to(_item_pos(i)) < button_radius:
				_hover = i; item_selected.emit(items[i]); accept_event(); return
func _process(_d: float) -> void: queue_redraw()
func _draw() -> void:
	var c := size / 2.0
	var f := get_theme_default_font()
	draw_arc(c, (minf(size.x, size.y) / 2.0 - button_radius - 4) * _t, 0, TAU, 96, Color(PhoenixTokens.MAGENTA, 0.25 * _t), 2.0, true)
	for i in items.size():
		var p := _item_pos(i)
		var hot := i == _hover
		draw_circle(p, button_radius, Color(PhoenixTokens.OBSIDIAN, 0.85 * _t))
		draw_arc(p, button_radius, 0, TAU, 48, (PhoenixTokens.GOLD if hot else PhoenixTokens.MAGENTA) * Color(1, 1, 1, _t), 2.5, true)
		var g := glyphs[i] if i < glyphs.size() else items[i].left(1)
		var gw := f.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(f, p + Vector2(-gw / 2.0, 9), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, PhoenixTokens.PLATINUM * Color(1, 1, 1, _t))
	# hub: ember core
	for k in 4: draw_circle(c, button_radius * (1.5 - k * 0.12), Color(PhoenixTokens.EMBER, 0.08))
	draw_circle(c, button_radius, PhoenixTokens.VOID)
	draw_arc(c, button_radius, 0, TAU, 48, PhoenixTokens.GOLD, 3.0, true)
	var hw := f.get_string_size("✕" if open else "☰", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(f, c + Vector2(-hw / 2.0, 10), "✕" if open else "☰", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, PhoenixTokens.PLATINUM)
