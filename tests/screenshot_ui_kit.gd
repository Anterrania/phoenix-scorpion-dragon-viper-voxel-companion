# UI kit demo screenshot: godot --resolution 720x1280 -s res://tests/screenshot_ui_kit.gd -- <out.png>
extends SceneTree
func _initialize():
	var out := "user://ui_kit_demo.png"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	root.add_child(load("res://scenes/ui/kit/kit_demo.tscn").instantiate())
	await create_timer(1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out); quit()
