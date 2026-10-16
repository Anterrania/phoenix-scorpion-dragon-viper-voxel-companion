# v0.9 portrait visual check -> user://v09_*.png  (run with --resolution 720x1280)
extends SceneTree
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://v09_%s.png" % n)
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
	ui.skip_welcome() if ui.has_method("skip_welcome") else null
	ui.show_panel("")
	root.get_node("Settings").set_quality(2)
	await create_timer(8.0).timeout
	_shot("portrait_hud_snow")
	ui.show_panel("menu"); await create_timer(0.5).timeout; _shot("compact_menu")
	ui.show_panel("map"); ui.map_view.mpp = 8.0; ui.map_view.queue_redraw(); await create_timer(0.5).timeout; _shot("map_zoomed_out")
	ui.map_view.mpp = 1.5; ui.map_view.queue_redraw(); await create_timer(0.5).timeout; _shot("map_zoomed_in")
	ui.show_panel("estate"); await create_timer(0.5).timeout; _shot("estate_controls")
	ui.show_panel("chat"); await create_timer(0.5).timeout; _shot("chat_offline")
	ui.show_panel("land"); await create_timer(0.3).timeout
	ui.land_op = "raise"; for i in 6: ui.land_apply()
	await create_timer(1.5).timeout; _shot("land_tools")
	ui.show_panel("")
	var gen = s.generator
	ui.teleport(_find(gen, 1, true))
	await create_timer(8.0).timeout
	_shot("venus_flowing_lava")
	ui.teleport(_find(gen, 2, true))
	await create_timer(8.0).timeout
	_shot("cosmic_water_foam")
	quit()
