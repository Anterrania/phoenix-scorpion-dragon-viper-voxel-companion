extends RefCounted
## v0.19 tests: Second Life-style walking and turning (player + companions).

static func run(t: Node) -> void:
	_math(t)
	await _player(t)
	_companion(t)

static func _math(t: Node) -> void:
	t.check(is_equal_approx(AvatarMotion.yaw_to(Vector3(0, 0, -1)), 0.0), "v019 facing -Z is yaw 0")
	t.check(is_equal_approx(absf(AvatarMotion.yaw_to(Vector3(0, 0, 1))), PI), "v019 facing +Z is yaw PI")
	var y := AvatarMotion.turn(0.0, 1.0, 2.0, 0.1)
	t.check(is_equal_approx(y, 0.2), "v019 turn is rate-capped (%s)" % y)
	t.check(is_equal_approx(AvatarMotion.turn(0.0, 0.05, 2.0, 0.1), 0.05), "v019 turn lands exactly on the target")
	var w := AvatarMotion.turn(3.0, -3.0, 1.0, 0.1)
	t.check(w > 3.0 or w < -3.0, "v019 turn takes the short way round across PI (%s)" % w)
	var st := {"turning": false}
	t.check(is_equal_approx(AvatarMotion.idle_face(st, 0.0, deg_to_rad(40.0), 0.1), 0.0) and not st["turning"], "v019 idle: small offsets do not turn the avatar")
	var cur := 0.0
	cur = AvatarMotion.idle_face(st, cur, deg_to_rad(90.0), 0.1)
	t.check(st["turning"] and cur > 0.0, "v019 idle: well off to the side starts a turn")
	for i in 40: cur = AvatarMotion.idle_face(st, cur, deg_to_rad(90.0), 0.1)
	t.check(not st["turning"] and absf(cur - deg_to_rad(90.0)) < 0.11, "v019 idle: turns all the way, then stops")
	t.check(AvatarMotion.gait(0.0, 3.0) == AvatarMotion.SHUFFLE and AvatarMotion.gait(0.0, 0.0) == 0.0 and AvatarMotion.gait(0.8, 3.0) == 0.8, "v019 shuffle step only when turning on the spot")
	var k := AvatarMotion.keyboard(Vector2(-1, -1))
	t.check(float(k["turn"]) > 0.0 and float(k["forward"]) == 1.0, "v019 keyboard: W walks forward, A turns left")
	var cr := AvatarMotion.camera_relative(Vector2(0, -1), 0.0)
	t.check(cr.distance_to(Vector3(0, 0, -1)) < 0.001, "v019 joystick up walks away from the camera")
	var cr2 := AvatarMotion.camera_relative(Vector2(0, -1), PI / 2.0)
	t.check(cr2.distance_to(Vector3(-1, 0, 0)) < 0.001, "v019 joystick follows the camera heading (%s)" % cr2)

static func _make_player(t: Node) -> CharacterBody3D:
	var pl: CharacterBody3D
	if ClassDB.class_exists("VoxelViewer"):
		pl = load("res://scenes/player.tscn").instantiate()
	else:
		pl = CharacterBody3D.new()
		var hd := Node3D.new(); hd.name = "Head"; hd.position = Vector3(0, 0.7, 0); pl.add_child(hd)
		var cm := Camera3D.new(); cm.name = "Camera3D"; hd.add_child(cm)
		var col := CollisionShape3D.new(); col.shape = CapsuleShape3D.new(); pl.add_child(col)
		pl.set_script(load("res://scripts/player.gd"))
	return pl

static func _player(t: Node) -> void:
	var holder := Node3D.new()
	t.get_tree().root.add_child(holder)
	var pl := _make_player(t)
	holder.add_child(pl)
	await t.get_tree().process_frame
	pl.set_third_person(true)
	# joystick right: the avatar turns to face right (camera-relative), rate-capped, and the view holds
	pl.set_move_vector(Vector2(1, 0))
	var cam_heading_before: float = pl.fcam.heading(pl.rotation.y)
	var d: Vector3 = pl._walk_dir(Vector2(1, 0), 0.05)
	t.check(absf(pl.rotation.y) > 0.0 and absf(pl.rotation.y) <= AvatarMotion.TURN_RATE * 0.05 + 0.001, "v019 joystick: the avatar starts turning toward the walk direction (rate-capped)")
	t.check(absf(angle_difference(cam_heading_before, pl.fcam.heading(pl.rotation.y))) < 0.001, "v019 joystick: the camera does not jump while the body turns")
	t.check(d.distance_to(Vector3(1, 0, 0)) < 0.01, "v019 joystick: walks where the stick points relative to the camera (%s)" % d)
	for i in 40: pl._walk_dir(Vector2(1, 0), 0.05)
	t.check(absf(angle_difference(pl.rotation.y, AvatarMotion.yaw_to(Vector3(1, 0, 0)))) < 0.01, "v019 joystick: the avatar ends up facing the walk direction")
	pl.set_move_vector(Vector2.ZERO)
	# keyboard SL-style
	var y0: float = pl.rotation.y
	var kd: Vector3 = pl._walk_dir(Vector2(-1, 0), 0.1)
	t.check(angle_difference(y0, pl.rotation.y) > 0.2 and kd.length() < 0.01, "v019 keyboard: A turns the avatar left without walking")
	t.check(absf(pl._turn_speed) > 0.6, "v019 keyboard: turning on the spot plays the step")
	var fw: Vector3 = pl._walk_dir(Vector2(0, -1), 0.1)
	t.check(fw.distance_to(-pl.transform.basis.z) < 0.01, "v019 keyboard: W walks along the facing")
	# mouselook strafes like before
	pl.set_third_person(false)
	var y1: float = pl.rotation.y
	var sd: Vector3 = pl._walk_dir(Vector2(1, 0), 0.1)
	t.check(is_equal_approx(pl.rotation.y, y1) and sd.distance_to(pl.transform.basis.x) < 0.01, "v019 mouselook: D strafes, no turning")
	holder.queue_free()
	await t.get_tree().process_frame

static func _companion(t: Node) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/agent/companion_agent.gd")
	t.check(src.contains("_face_walk(d, delta)") and src.contains("_face_idle(player.global_position, delta)") and src.contains("AvatarMotion.gait("), "v019 companions use SL-style walk/turn facing")
