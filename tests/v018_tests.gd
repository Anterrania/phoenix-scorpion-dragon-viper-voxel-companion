extends RefCounted
## v0.18 tests: Firestorm-style camera (orbit, zoom to mouselook and back, snap back on move,
## collision, smoothing) + the player wiring (pinch, wheel, orbit does not spin the avatar).

static func run(t: Node) -> void:
	_math(t)
	await _player(t)

static func _math(t: Node) -> void:
	var c := FirestormCam.new()
	t.check(is_equal_approx(c.dist, FirestormCam.DIST_DEFAULT) and c.yaw == 0.0 and not c.mouselook, "v018 cam starts behind the avatar at the default distance")
	var p := Vector3(0, 1, 0)
	var behind := FirestormCam.ideal(p, 0.0, 0.0, 0.0, 4.0)
	t.check(behind.z > 3.5 and absf(behind.y - 1.0) < 0.01, "v018 yaw 0 puts the camera behind (+Z, Godot forward is -Z) (%s)" % behind)
	var above := FirestormCam.ideal(p, 0.0, 0.0, 0.8, 4.0)
	t.check(above.y > 2.5, "v018 positive pitch lifts the camera to look down (%s)" % above)
	var side := FirestormCam.ideal(p, 0.0, PI / 2.0, 0.0, 4.0)
	t.check(absf(side.x) > 3.5, "v018 orbit 90 degrees moves the camera to the side (%s)" % side)
	t.check(FirestormCam.ideal(p, 0.0, 0.0, 0.0, 4.0).distance_to(p) > 3.9, "v018 distance respected")
	c.orbit(Vector2(0.5, 10.0))
	t.check(c.pitch <= FirestormCam.PITCH_MAX and c.since_orbit == 0.0, "v018 orbit pitch clamped")
	c.orbit(Vector2(0.0, -20.0))
	t.check(c.pitch >= FirestormCam.PITCH_MIN, "v018 orbit pitch clamped from below")
	# snap back: only while moving and after the drag delay
	c.yaw = 1.0; c.since_orbit = 0.0
	c.tick(0.1, true)
	t.check(is_equal_approx(c.yaw, 1.0), "v018 no snap back right after an orbit drag")
	for i in 30: c.tick(0.1, true)
	t.check(absf(c.yaw) < 0.001, "v018 orbit eases back behind the avatar while walking")
	c.yaw = 1.0
	for i in 30: c.tick(0.1, false)
	t.check(is_equal_approx(c.yaw, 1.0), "v018 standing still keeps the orbit (look around your avatar)")
	# zoom
	var z := FirestormCam.new()
	t.check(z.zoom(2.0) == "" and z.dist_target > FirestormCam.DIST_DEFAULT, "v018 zoom out")
	for i in 40: z.zoom(10.0)
	t.check(z.dist_target <= FirestormCam.DIST_MAX, "v018 zoom out capped")
	var mode := ""
	for i in 80:
		var r := z.zoom(0.8)
		if r != "": mode = r
	t.check(mode == "mouselook" and z.mouselook, "v018 zooming all the way in drops into mouselook")
	t.check(z.zoom(0.5) == "", "v018 zooming in further in mouselook does nothing")
	t.check(z.zoom(1.3) == "third" and not z.mouselook and z.dist_target > FirestormCam.DIST_MIN, "v018 zooming out of mouselook returns to third person")
	for i in 30: z.tick(0.1, false)
	t.check(absf(z.dist - z.dist_target) < 0.01, "v018 zoom eases to its target")
	# collision
	var want := Vector3(0, 1, 5)
	t.check(FirestormCam.collide(p, want, null) == want, "v018 no hit, camera where it wants")
	var pulled := FirestormCam.collide(p, want, Vector3(0, 1, 2))
	t.check(pulled.z < 2.0 and pulled.z > 1.0, "v018 wall between: camera in front of the wall (%s)" % pulled)
	t.check(FirestormCam.collide(p, want, Vector3(0, 1, 9)) == want, "v018 hit beyond the camera is ignored")
	t.check(FirestormCam.collide(p, want, Vector3(0, 1, 0.05)).distance_to(p) >= 0.19, "v018 hit at the pivot keeps a minimum gap")
	# smoothing
	var f := FirestormCam.new()
	t.check(f.follow(Vector3(1, 2, 3), 0.016, 0.5) == Vector3(1, 2, 3), "v018 follow snaps on the first frame")
	var mid := f.follow(Vector3(2, 2, 3), 0.016, 0.5)
	t.check(mid.x > 1.0 and mid.x < 2.0, "v018 follow is smoothed")
	t.check(f.follow(Vector3(100, 2, 3), 0.016, 0.5) == Vector3(100, 2, 3), "v018 follow snaps after a teleport")
	var rigid := FirestormCam.new(); rigid.follow(Vector3.ZERO, 0.016, 0.0)
	var floaty := FirestormCam.new(); floaty.follow(Vector3.ZERO, 0.016, 1.0)
	t.check(rigid.follow(Vector3(1, 0, 0), 0.016, 0.0).x > floaty.follow(Vector3(1, 0, 0), 0.016, 1.0).x, "v018 comfort smoothing makes the camera floatier")
	var pd := {0: Vector2(0, 0), 1: Vector2(30, 40)}
	t.check(is_equal_approx(load("res://scripts/player.gd").pinch_distance(pd), 50.0), "v018 pinch distance")

static func _player(t: Node) -> void:
	var pl: CharacterBody3D
	if ClassDB.class_exists("VoxelViewer"):
		pl = load("res://scenes/player.tscn").instantiate()
	else:   # no VoxelTools on this machine: same script, same Head/Camera3D layout, no VoxelViewer
		pl = CharacterBody3D.new()
		var hd := Node3D.new(); hd.name = "Head"; hd.position = Vector3(0, 0.7, 0); pl.add_child(hd)
		var cm := Camera3D.new(); cm.name = "Camera3D"; hd.add_child(cm)
		var col := CollisionShape3D.new(); col.shape = CapsuleShape3D.new(); pl.add_child(col)
		pl.set_script(load("res://scripts/player.gd"))
	var holder := Node3D.new()
	t.get_tree().root.add_child(holder)
	holder.add_child(pl)
	await t.get_tree().process_frame
	pl.set_third_person(true)
	await t.get_tree().process_frame
	var cam: Camera3D = pl.camera
	t.check(cam.top_level and cam.global_position.distance_to(pl.global_position) > 1.5, "v018 third person: camera placed behind the avatar")
	var body_yaw: float = pl.rotation.y
	pl._look(Vector2(0.8, 0.0))
	await t.get_tree().process_frame
	t.check(is_equal_approx(pl.rotation.y, body_yaw) and absf(pl.fcam.yaw) > 0.5, "v018 dragging orbits the camera, the avatar does not spin")
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_WHEEL_UP; ev.pressed = true
	var before: float = pl.fcam.dist_target
	pl._unhandled_input(ev)
	t.check(pl.fcam.dist_target < before, "v018 mouse wheel zooms in")
	for i in 60: pl._zoom(0.8)
	t.check(not pl.third_person and not cam.top_level, "v018 zoomed in to mouselook = first person")
	pl._zoom(1.5)
	t.check(pl.third_person and cam.top_level, "v018 zoom out of mouselook = third person")
	# pinch on the look side (right half) at phone sizes
	var root := t.get_tree().root
	var old_size := root.size
	for sz in [Vector2(720, 1280), Vector2(1080, 2400), Vector2(2400, 1080)]:
		root.size = Vector2i(sz)
		await t.get_tree().process_frame
		sz = pl.get_viewport().get_visible_rect().size   # what the player actually measures
		var x0: float = sz.x * 0.6
		var a := InputEventScreenTouch.new(); a.index = 0; a.pressed = true; a.position = Vector2(x0, sz.y * 0.5)
		var b := InputEventScreenTouch.new(); b.index = 1; b.pressed = true; b.position = Vector2(x0 + 100, sz.y * 0.5)
		pl._unhandled_input(a); pl._unhandled_input(b)
		var d0: float = pl.fcam.dist_target
		for k in 4:
			var dr := InputEventScreenDrag.new(); dr.index = 1; dr.position = Vector2(x0 + 100 + 60 * (k + 1), sz.y * 0.5)
			pl._unhandled_input(dr)
		t.check(pl.fcam.dist_target < d0 or not pl.third_person, "v018 %dx%d pinch apart zooms in" % [sz.x, sz.y])
		for e in [a, b]:
			var up := InputEventScreenTouch.new(); up.index = e.index; up.pressed = false; up.position = e.position
			pl._unhandled_input(up)
		t.check(pl._pinch.is_empty() and pl._look_index == -1, "v018 %dx%d pinch released cleanly" % [sz.x, sz.y])
		if not pl.third_person: pl._zoom(1.5)
	root.size = old_size
	holder.queue_free()
	await t.get_tree().process_frame
