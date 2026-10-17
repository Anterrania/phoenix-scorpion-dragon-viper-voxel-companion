# v0.11 realistic companion check -> user://v11_*.png  (run with --resolution 720x1280)
extends SceneTree
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://v11_%s.png" % n)
func _closeup(s: Node, id: String, dist := 1.5, h := 1.25) -> void:
	for c in s.get_tree().get_nodes_in_group("companions"):
		if c.companion_id != id: continue
		c.set_physics_process(false)
		c.following = false
		var cam := Camera3D.new(); cam.name = "Closeup_" + id
		s.add_child(cam)
		var fwd: Vector3 = -c.global_basis.z
		var sk: Skeleton3D = RealisticBody.skeleton(c.model) if c.model and c.model.has_meta("realistic") else null
		var head: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head")).origin + Vector3(0, 0.07, 0)) if sk else c.global_position + Vector3(0, 0.8, 0)
		var feet: Vector3 = c.model.global_position if c.model else c.global_position
		cam.global_position = head + fwd * 0.62 + Vector3(0, 0.02, 0)
		cam.look_at(head, Vector3.UP)
		cam.fov = 32
		cam.make_current()
		await create_timer(1.2).timeout
		_shot("closeup_" + id)
		var mid := (head + feet) * 0.5
		cam.global_position = mid + (fwd * 0.92 + c.global_basis.x * 0.4).normalized() * ((head.y - feet.y) * 2.3) + Vector3(0, 0.15, 0)
		cam.look_at(mid, Vector3.UP)
		await create_timer(0.8).timeout
		_shot("full_" + id)
		cam.queue_free()
func _initialize():
	var s = load("res://scenes/main_world.tscn").instantiate()
	root.add_child(s)
	await create_timer(2.0).timeout
	var ui = s.get_node("UI")
	ui.skip_welcome() if ui.has_method("skip_welcome") else null
	ui.show_panel("")
	root.get_node("Settings").set_quality(2)
	await create_timer(8.0).timeout
	_shot("portrait_companions")
	for cl in root.find_children("*", "CanvasLayer", true, false): cl.visible = false
	for id in ["foxy_ani", "aaliyah", "circuit_nova"]: await _closeup(s, id)
	for cl in root.find_children("*", "CanvasLayer", true, false): cl.visible = true
	var p = root.get_node("Profile"); p.data["role"] = "owner"
	var core = EveCore.for_companion("foxy_ani"); core.log_chat("user", "build me a fire altar"); core.log_chat("assistant", "Rising from the flame, love.")
	core.propose_update("Brighter Venus lava glow")
	ui.show_panel("history"); await create_timer(0.5).timeout; _shot("history_panel")
	ui.show_panel("proposals"); await create_timer(0.5).timeout; _shot("proposals_panel")
	ui.show_panel("settings"); await create_timer(0.5).timeout; _shot("settings_voice_toggle")
	quit()
