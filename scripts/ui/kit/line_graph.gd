@tool
class_name LineGraph
extends Control
## Minimal line graph: smooth magenta line, gold last point, faint fill, 3 ghost gridlines, no axis clutter.
@export var points: PackedFloat32Array = [3, 5, 4, 7, 6, 9, 8, 12, 11, 14]
@export var line_color := PhoenixTokens.MAGENTA
func _ready() -> void: custom_minimum_size = Vector2(280, 140)
func set_points(p: PackedFloat32Array) -> void: points = p; queue_redraw()
func _draw() -> void:
	if points.size() < 2: return
	var lo := points[0]; var hi := points[0]
	for v in points: lo = minf(lo, v); hi = maxf(hi, v)
	var span := maxf(hi - lo, 0.0001)
	var pad := 8.0
	for k in 3:
		var y := pad + (size.y - pad * 2) * (k + 1) / 4.0
		draw_line(Vector2(pad, y), Vector2(size.x - pad, y), Color(1, 1, 1, 0.06), 1.0)
	var pts := PackedVector2Array()
	for i in points.size():
		pts.append(Vector2(pad + (size.x - pad * 2) * i / (points.size() - 1), size.y - pad - (size.y - pad * 2) * (points[i] - lo) / span))
	var fill := pts.duplicate(); fill.append(Vector2(size.x - pad, size.y - pad)); fill.append(Vector2(pad, size.y - pad))
	draw_colored_polygon(fill, Color(line_color, 0.12))
	draw_polyline(pts, Color(line_color, 0.25), 8.0, true)
	draw_polyline(pts, line_color, 3.0, true)
	draw_circle(pts[-1], 9.0, Color(PhoenixTokens.GOLD, 0.3))
	draw_circle(pts[-1], 5.0, PhoenixTokens.GOLD)
