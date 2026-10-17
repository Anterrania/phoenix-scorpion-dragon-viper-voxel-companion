@tool
class_name RingStat
extends Control
## Circular stat ring: value 0..1, gold->magenta arc, big centered number, one short label.
@export_range(0.0, 1.0) var value := 0.72: set = set_value
@export var caption := "XP"
@export var display_text := ""
@export var ring_width := 14.0
@export var color_a := PhoenixTokens.GOLD
@export var color_b := PhoenixTokens.MAGENTA
var _shown := 0.0
func _ready() -> void:
	custom_minimum_size = Vector2(160, 160); _shown = value
func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	if is_inside_tree() and not Engine.is_editor_hint():
		create_tween().tween_property(self, "_shown", value, PhoenixTokens.MOTION.slow).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else: _shown = value
func _process(_d: float) -> void: queue_redraw()
func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - ring_width
	draw_circle(c, r + ring_width * 0.5, Color(PhoenixTokens.GLASS, 0.5))
	draw_arc(c, r, 0, TAU, 96, Color(1, 1, 1, 0.08), ring_width, true)
	var steps := 48
	var a0 := -PI / 2.0
	for i in steps:
		var t0 := float(i) / steps * _shown
		var t1 := float(i + 1) / steps * _shown
		draw_arc(c, r, a0 + t0 * TAU, a0 + t1 * TAU, 4, color_a.lerp(color_b, t1), ring_width, true)
	if _shown > 0.0:
		var e := c + Vector2.from_angle(a0 + _shown * TAU) * r
		draw_circle(e, ring_width * 0.9, Color(color_b, 0.25))
		draw_circle(e, ring_width * 0.45, PhoenixTokens.PLATINUM)
	var f := get_theme_default_font()
	var txt := display_text if display_text != "" else "%d%%" % roundi(_shown * 100)
	var fs := int(r * 0.55)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(f, c + Vector2(-w / 2.0, fs * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PhoenixTokens.PLATINUM)
	var cw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, PhoenixTokens.TYPE.micro).x
	draw_string(f, c + Vector2(-cw / 2.0, fs * 0.3 + 22), caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, PhoenixTokens.TYPE.micro, PhoenixTokens.PLATINUM_DIM)
