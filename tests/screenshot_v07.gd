# v0.7 visual check -> user://v07_*.png
extends SceneTree
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://v07_%s.png" % n)
func _initialize():
	var s = load("res://scenes/main_world.tscn").instantiate()
	root.add_child(s)
	await create_timer(2.0).timeout
	var ui = s.get_node("UI")
	ui.show_panel("menu")
	await create_timer(1.0).timeout
	_shot("menu")
	ui.show_panel("")
	s.set_env_mode("Sunset")
	await create_timer(12.0).timeout
	_shot("hud_minimap_sunset")
	ui.show_panel("map")
	await create_timer(1.0).timeout
	ui.map_view.zoom_by(0.5)
	await create_timer(0.5).timeout
	_shot("world_map")
	ui.show_panel("settings")
	await create_timer(0.5).timeout
	_shot("settings_tabs")
	quit()
