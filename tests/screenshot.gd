# Visual smoke test (needs a display): godot --rendering-driver opengl3 -s res://tests/screenshot.gd
extends SceneTree
func _initialize():
	var s = load("res://scenes/main_world.tscn").instantiate()
	root.add_child(s)
	await create_timer(10.0).timeout
	root.get_viewport().get_texture().get_image().save_png("user://v02_tp.png")
	s.get_node("Player").rotate_y(PI)
	await create_timer(3.0).timeout
	root.get_viewport().get_texture().get_image().save_png("user://v02_back.png")
	s.get_node("Player").global_position = Vector3(-3000, 40, 0)
	await create_timer(10.0).timeout
	root.get_viewport().get_texture().get_image().save_png("user://v02_far.png")
	quit()
