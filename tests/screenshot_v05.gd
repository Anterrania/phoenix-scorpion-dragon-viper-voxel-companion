# v0.5 visual check: xvfb-run godot -s res://tests/screenshot_v05.gd -> user://v05_*.png
extends SceneTree
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://v05_%s.png" % n)
func _initialize():
	var s = load("res://scenes/main_world.tscn").instantiate()
	root.add_child(s)
	await create_timer(3.0).timeout
	var ui = s.get_node("UI")
	ui.show_panel("avatar")
	await create_timer(2.0).timeout
	_shot("avatar_creator")
	ui.show_panel("")
	var p: Node3D = s.get_node("Player")
	var wc = s.get_node("WorldContent")
	var l: Dictionary = wc.landmark_by_id("crystal_wyvern_sanctum")
	ui.teleport(l["position"] + Vector3(0, 0, 22))
	await create_timer(16.0).timeout
	_shot("world")
	ui.show_panel("wardrobe")
	await create_timer(2.0).timeout
	_shot("wardrobe")
	quit()
