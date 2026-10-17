# v0.12 avatar check -> user://v12_*.png  (run via tools/shot_isolated.sh so user:// is a throwaway dir)
extends SceneTree
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://v12_%s.png" % n)
func _head(model: Node3D, fallback: Vector3) -> Vector3:
	var sk: Skeleton3D = RealisticBody.skeleton(model) if model and model.has_meta("realistic") else null
	if sk == null: return fallback
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head")).origin + Vector3(0, 0.07 * model.global_basis.get_scale().y, 0)
func _frame(s: Node, id: String, model: Node3D, body: Node3D, expr := "") -> void:
	var cam := Camera3D.new(); s.add_child(cam)
	var fwd: Vector3 = -body.global_basis.z.normalized()
	var head := _head(model, body.global_position + Vector3(0, 0.8, 0))
	var feet: Vector3 = model.global_position
	cam.global_position = head + fwd * 0.62 + Vector3(0, 0.02, 0)
	cam.look_at(head, Vector3.UP); cam.fov = 32; cam.make_current()
	await create_timer(1.2).timeout
	_shot("closeup_" + id)
	if expr != "":
		var f := FaceDriver.for_model(model)
		if f.has_face():
			for k in [["smile", "mouthSmile"], ["talk", "viseme_aa"], ["brow", "browInnerUp"]]:
				for s2 in FaceDriver.SHAPES: f.mesh.set_blend_shape_value(f.mesh.find_blend_shape_by_name(s2), 0.0)
				f.mesh.set_blend_shape_value(f.mesh.find_blend_shape_by_name(k[1]), 1.0)
				if k[0] == "talk": f.mesh.set_blend_shape_value(f.mesh.find_blend_shape_by_name("jawOpen"), 0.5)
				body.set_process(false)
				await create_timer(0.4).timeout
				_shot("expr_%s_%s" % [k[0], id])
			body.set_process(true)
	var mid := (head + feet) * 0.5
	cam.global_position = mid + (fwd * 0.92 + body.global_basis.x.normalized() * 0.4).normalized() * ((head.y - feet.y) * 2.3) + Vector3(0, 0.15, 0)
	cam.look_at(mid, Vector3.UP)
	await create_timer(0.8).timeout
	_shot("full_" + id)
	cam.queue_free()
func _initialize():
	var isolated := OS.get_environment("PHX_ISOLATED") == "1"
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
	for c in s.get_tree().get_nodes_in_group("companions"):
		c.set_physics_process(false); c.following = false
	for c in s.get_tree().get_nodes_in_group("companions"):
		if c.companion_id in ["foxy_ani", "aaliyah", "circuit_nova"]:
			await _frame(s, c.companion_id, c.model, c, "expr" if c.companion_id == "foxy_ani" else "")
	var pl = s.get_node("Player")
	pl.set_physics_process(false)
	pl.set_third_person(true)
	pl.global_position += Vector3(0, 0, 0)
	for c in s.get_tree().get_nodes_in_group("companions"): c.visible = false
	await _frame(s, "player", pl.avatar, pl)
	for cl in root.find_children("*", "CanvasLayer", true, false): cl.visible = true
	if isolated:  # proposals/history only in a throwaway user:// so the box app data stays clean
		var p = root.get_node("Profile"); p.owner_code_hash = p.code_hash("phoenix-shot-only"); p.try_owner_unlock("phoenix-shot-only")  # test hash, throwaway user://
		var core = EveCore.for_companion("foxy_ani"); core.log_chat("user", "build me a fire altar"); core.log_chat("assistant", "Rising from the flame, love.")
		core.propose_update("Brighter Venus lava glow")
		ui.show_panel("proposals"); await create_timer(0.5).timeout; _shot("proposals_panel")
		ui.show_panel("")
		CommunityScreen.open(ui); await create_timer(1.0).timeout; _shot("community_admin")
	quit()
