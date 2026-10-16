class_name WorldMapView
extends Control
## v0.7 full-screen world map: drag to pan, pinch / +/- to zoom, region grid with
## names, landmark icons + labels, "you are here", tap (no drag) to teleport.
signal teleport_requested(xz: Vector2)
var world: Node
var player: Node3D
var center := Vector2.ZERO     # world xz at view centre
var mpp := 6.0                 # metres per pixel
var _press := Vector2.ZERO
var _moved := false
var _touches := {}
var _pinch_d := 0.0

func w2s(xz: Vector2) -> Vector2:
	return size * 0.5 + (xz - center) / mpp

func s2w(sp: Vector2) -> Vector2:
	return center + (sp - size * 0.5) * mpp

func zoom_by(f: float) -> void:
	mpp = clampf(mpp * f, 0.5, 40.0)
	queue_redraw()

func focus(xz: Vector2) -> void:
	center = xz
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1: _press = e.position; _moved = false
			else: _pinch_d = _pinch_dist()
		else:
			_touches.erase(e.index)
			if _touches.is_empty() and not _moved:
				teleport_requested.emit(s2w(e.position))
		accept_event()
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() >= 2:
			var d := _pinch_dist()
			if _pinch_d > 0.0 and d > 0.0: zoom_by(_pinch_d / d)
			_pinch_d = d
			_moved = true
		else:
			if e.position.distance_to(_press) > 14.0: _moved = true
			if _moved:
				center -= e.relative * mpp
				queue_redraw()
		accept_event()
	elif e is InputEventMagnifyGesture:
		zoom_by(1.0 / e.factor)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_by(0.85 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.18)

func _pinch_dist() -> float:
	var v := _touches.values()
	return (v[0] as Vector2).distance_to(v[1]) if v.size() >= 2 else 0.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04))
	var g = world.generator if world and "generator" in world else null
	var tex := MapData.texture(g)
	if tex:
		var a := w2s(Vector2(-MapData.HALF, -MapData.HALF))
		var b := w2s(Vector2(MapData.HALF, MapData.HALF))
		draw_texture_rect(tex, Rect2(a, b - a), false)
	# region grid
	var font := get_theme_default_font()
	var tl := s2w(Vector2.ZERO)
	var br := s2w(size)
	var R := MapData.REGION
	var x0 := floorf(tl.x / R) * R
	while x0 <= br.x:
		draw_line(Vector2(w2s(Vector2(x0, 0)).x, 0), Vector2(w2s(Vector2(x0, 0)).x, size.y), Color(1, 1, 1, 0.18), 1.0)
		x0 += R
	var z0 := floorf(tl.y / R) * R
	while z0 <= br.y:
		draw_line(Vector2(0, w2s(Vector2(0, z0)).y), Vector2(size.x, w2s(Vector2(0, z0)).y), Color(1, 1, 1, 0.18), 1.0)
		z0 += R
	if mpp < 8.0:
		var gx := floorf(tl.x / R) * R
		while gx <= br.x:
			var gz := floorf(tl.y / R) * R
			while gz <= br.y:
				draw_string(font, w2s(Vector2(gx, gz)) + Vector2(4, 16), MapData.region_name(Vector3(gx + 1, 0, gz + 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.5))
				gz += R
			gx += R
	for z in CombatZone.zones:
		var c: Vector3 = z["center"]
		draw_arc(w2s(Vector2(c.x, c.z)), float(z["radius"]) / mpp, 0, TAU, 40, Color(1, 0.2, 0.2), 3.0)
	var wc = world.get_node_or_null("WorldContent") if world else null
	if wc:
		for l in wc.landmarks:
			var p: Vector3 = l["position"]
			var m := w2s(Vector2(p.x, p.z))
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -10), m + Vector2(10, 0), m + Vector2(0, 10), m + Vector2(-10, 0)]), Color("#ffd04a"))
			draw_string(font, m + Vector2(13, 6), str(l["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffe9a8"))
	if player:
		var me := w2s(Vector2(player.global_position.x, player.global_position.z))
		draw_circle(me, 10.0, Color(1, 0.18, 0.82))
		draw_arc(me, 16.0, 0, TAU, 24, Color.WHITE, 3.0)
		draw_string(font, me + Vector2(18, -12), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
