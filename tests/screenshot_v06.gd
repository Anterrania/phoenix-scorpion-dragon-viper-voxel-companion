# v0.6 visual check -> user://v06_*.png
extends SceneTree
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://v06_%s.png" % n)
func _initialize():
	var s = load("res://scenes/main_world.tscn").instantiate()
	root.add_child(s)
	await create_timer(3.0).timeout
	var ui = s.get_node("UI")
	ui.show_panel("")
	var p: Node3D = s.get_node("Player")
	var wc = s.get_node("WorldContent")
	ui.teleport(wc.arena.global_position + Vector3(0, 0, 8))
	for c in root.get_tree().get_nodes_in_group("creatures"):
		c.global_position = p.global_position + Vector3(randf_range(-4, 4), 0, -12)
	await create_timer(5.0).timeout
	p.fire_bolt()
	await create_timer(0.15).timeout
	_shot("combat")
	ui.teleport(wc.pen.global_position + Vector3(-6, 0, -8))
	p.rotation.y = PI * 0.8
	p.set_pose("wave", 10.0)
	await create_timer(8.0).timeout
	_shot("wyrmlings_titler")
	ui.show_panel("wyrm")
	await create_timer(1.0).timeout
	_shot("breeding")
	quit()
