# Live physics check (needs a display): xvfb-run godot -s res://tests/physics_sim.gd
# Runs the real world for ~20 s, walks the player forward, then verifies collision results
# and saves user://v04_physics.png.
extends SceneTree
func _initialize():
	var s = load("res://scenes/main_world.tscn").instantiate()
	root.add_child(s)
	var p: CharacterBody3D = s.get_node("Player")
	await create_timer(10.0).timeout
	p.set_move_vector(Vector2(0, -1))
	await create_timer(4.0).timeout
	p.set_move_vector(Vector2.ZERO)
	await create_timer(4.0).timeout
	var fails := 0
	var g = s.generator
	var gh: float = g.height_f(p.global_position.x, p.global_position.z)
	var ok: bool = p.global_position.y > gh - 0.2 and p.global_position.y < gh + 3.0
	print("player y=%.2f ground=%.2f on_floor=%s %s" % [p.global_position.y, gh, p.is_on_floor(), "PASS" if ok else "FAIL"])
	if not ok: fails += 1
	var comps := get_nodes_in_group("companions")
	var min_d := 99.0
	for a in comps:
		for b in comps + [p]:
			if a != b: min_d = minf(min_d, Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length())
		var ch: float = g.height_f(a.global_position.x, a.global_position.z)
		if a.global_position.y < ch - 0.2: fails += 1; print("FAIL companion under ground ", a.name)
	print("companions=%d min_separation=%.2f %s" % [comps.size(), min_d, "PASS" if min_d > 0.7 else "FAIL"])
	if min_d <= 0.7: fails += 1
	var awake := 0
	for rb in s.get_node("PhysicsProps").props:
		if not rb.freeze: awake += 1
		var rh: float = g.height_f(rb.global_position.x, rb.global_position.z)
		if rb.global_position.y < rh - 0.6: fails += 1; print("FAIL prop under ground ", rb.name)
	print("props awake on collision=%d/12" % awake)
	if awake == 0: fails += 1
	p.rotate_y(PI); p.get_node("Head").rotation.x = -0.25
	await create_timer(2.0).timeout
	root.get_viewport().get_texture().get_image().save_png("user://v04_physics.png")
	print("SIM FAILURES: ", fails)
	quit(1 if fails else 0)
