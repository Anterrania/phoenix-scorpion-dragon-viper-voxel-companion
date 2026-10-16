# v0.8 visual check -> user://v08_*.png
extends SceneTree
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://v08_%s.png" % n)
func _find(gen, b: int, water := false) -> Vector3:
	for r in range(200, 4000, 100):
		for i in 24:
			var a := TAU * i / 24.0
			var x := cos(a) * r; var z := sin(a) * r
			if int(gen.biome_at(x, z)) == b and (not water or gen.height_f(x, z) < gen.LAVA_LEVEL - 1.0):
				return Vector3(x, 0, z)
	return _find(gen, b, false) if water else Vector3(300, 0, 300)
func _initialize():
	var s = load("res://scenes/main_world.tscn").instantiate()
	root.add_child(s)
	await create_timer(2.0).timeout
	var ui = s.get_node("UI")
	ui.show_panel("")
	root.get_node("Settings").set_quality(2)
	await create_timer(8.0).timeout
	_shot("alaska_snow_clouds")
	var gen = s.generator
	ui.teleport(_find(gen, 1))
	await create_timer(8.0).timeout
	_shot("venus_embers")
	s.player.fire_bolt()
	await create_timer(0.25).timeout
	_shot("fire_bolt_trail")
	ui.teleport(_find(gen, 2, true))
	await create_timer(8.0).timeout
	_shot("cosmic_water_stardust")
	quit()
