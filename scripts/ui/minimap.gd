class_name Minimap
extends Control
## v0.7 corner minimap: terrain, player arrow, companions (magenta), creatures (red),
## landmarks (gold), combat zones (red ring). +/- zoom, tap to open world map.
signal open_map
var world: Node
var player: Node3D
var zoom := 160.0   # metres from centre to edge
const SIZE := 230.0

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	for z in [["+", -1.0, 0.0], ["−", 1.0, 52.0]]:
		var b := Button.new()
		b.text = z[0]
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(SIZE - 50, 4 + z[2])
		b.size = Vector2(46, 46)
		b.add_theme_font_size_override("font_size", 28)
		var f: float = z[1]
		b.pressed.connect(func(): zoom = clampf(zoom * (1.6 if f > 0 else 0.625), 40.0, 1200.0); queue_redraw())
		add_child(b)

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		open_map.emit()
		accept_event()

func w2m(p: Vector3) -> Vector2:
	var c := player.global_position if player else Vector3.ZERO
	return Vector2(SIZE, SIZE) * 0.5 + Vector2(p.x - c.x, p.z - c.z) / zoom * SIZE * 0.5

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.01, 0.05, 0.85))
	var g = world.generator if world and "generator" in world else null
	var tex := MapData.texture(g)
	if tex and player:
		var c := Vector2(player.global_position.x, player.global_position.z)
		var uv0 := MapData.world_to_uv(c - Vector2(zoom, zoom))
		var uv1 := MapData.world_to_uv(c + Vector2(zoom, zoom))
		var src := Rect2(uv0 * MapData.RES, (uv1 - uv0) * MapData.RES)
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), src)
	if world:
		for z in CombatZone.zones:
			draw_arc(w2m(z["center"]), float(z["radius"]) / zoom * SIZE * 0.5, 0, TAU, 32, Color(1, 0.2, 0.2), 3.0)
		var wc = world.get_node_or_null("WorldContent")
		if wc:
			for l in wc.landmarks:
				var m := w2m(l["position"])
				draw_colored_polygon(PackedVector2Array([m + Vector2(0, -7), m + Vector2(7, 0), m + Vector2(0, 7), m + Vector2(-7, 0)]), Color("#ffd04a"))
		for c in get_tree().get_nodes_in_group("companions"):
			draw_circle(w2m(c.global_position), 5.0, Color(1, 0.2, 0.85))
		for c in get_tree().get_nodes_in_group("creatures"):
			if c.alive(): draw_circle(w2m(c.global_position), 4.0, Color(1, 0.1, 0.1))
	if player:
		var ctr := size * 0.5
		var cam := player.get_node_or_null("Head/Camera3D") as Node3D
		var yaw: float = cam.global_rotation.y if cam else player.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var right := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([ctr + fwd * 12, ctr - fwd * 7 + right * 7, ctr - fwd * 3, ctr - fwd * 7 - right * 7]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.18, 0.82), false, 3.0)
	draw_string(get_theme_default_font(), Vector2(8, SIZE - 10), "%dm" % int(zoom), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
