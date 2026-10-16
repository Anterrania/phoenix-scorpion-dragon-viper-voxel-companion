# Visual smoke test (needs a display): xvfb-run godot -s res://tests/screenshot.gd
# Saves user://v03_*.png (third person spawn, companions view, Venus, Cosmic).
extends SceneTree
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://v03_%s.png" % n)
func _initialize():
	var s = load("res://scenes/main_world.tscn").instantiate()
	root.add_child(s)
	var p: Node3D = s.get_node("Player")
	await create_timer(14.0).timeout
	_shot("alaska_tp")
	p.rotate_y(PI)
	p.get_node("Head").rotation.x = -0.15
	await create_timer(4.0).timeout
	_shot("player_face")
	for spot in [["venus", -1.0], ["cosmic", 1.0]]:
		var g = s.generator
		var found := Vector2.ZERO
		for i in 4000:
			var x: float = spot[1] * (300.0 + i * 13.0)
			var z: float = (i % 50) * 37.0 - 900.0
			if g.biome_at(x, z) == (1 if spot[0] == "venus" else 2) and g.biome_at(x + 60, z) == g.biome_at(x, z):
				found = Vector2(x, z); break
		p.global_position = Vector3(found.x, g.height_f(found.x, found.y) + 3.0, found.y)
		p.get_node("Head").rotation.x = 0.05
		await create_timer(14.0).timeout
		_shot(spot[0])
	quit()
