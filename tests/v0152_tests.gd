extends RefCounted
## v0.15.2 phone hotfix tests: ONE login at launch (no PIN pad on top of the social sign-in), every list scrolls
## by finger (only the top-most one), and the landscape menu is a side sheet, not a full-width wall.

const V014 := preload("res://tests/v014_tests.gd")
const V0151 := preload("res://tests/v0151_tests.gd")

class FakePanel extends Object:
	var owner_pushes := 0
	func open_social_panel(_u := "") -> void: pass
	func get_plugin_version() -> int: return 5
	func has_social_bundle() -> bool: return true
	func set_owner_session(_on: bool) -> void: owner_pushes += 1

static func _restart_memory() -> void:
	OwnerVault._vault_cache = null; OwnerVault._session = false
	OwnerVault._dek_enc = PackedByteArray(); OwnerVault._dek_mac = PackedByteArray()

static func run(t: Node) -> void:
	var s = load("res://scenes/main_world.tscn").instantiate()
	t.add_child(s)
	await t.get_tree().create_timer(1.0).timeout
	var ui = s.get_node("UI")
	await _launch(t, ui)
	await _scroll(t, ui)
	await _landscape(t, ui)
	s.queue_free()
	await t.get_tree().process_frame

static func _launch(t: Node, ui: Node) -> void:
	var prof: Node = t.get_node("/root/Profile")
	var saved: Dictionary = prof.data.duplicate(true)
	var sroot := "user://test_v0152/security"
	OwnerVault.reset_for_tests(sroot, 1000)
	OwnerLogin.reset_for_tests(sroot)
	OwnerLogin.min_iter = 1000
	OwnerLogin.record_override = V014.VECTOR
	var now := [1_800_000_000]
	OwnerVault.clock_unix = func(): return now[0]
	var fp := FakePanel.new()
	SocialBridge.plugin_override = fp
	t.check(SocialBridge.owner_sign_in("SkorpionViper", V014.TEST_PW) == "", "v0152 owner signs in once (social)")
	# app restart within the lock window: remembered session, NO sign-in at all
	_restart_memory(); now[0] += 300
	t.check(ui._launch_unlock() == "none" and OwnerVault.storage_ready() and ui.get_node_or_null("SecurityScreen") == null, "v0152 launch with a remembered session: no PIN pad, no second login")
	# sealed vault, social menu present: the social sign-in is the ONLY login (no PIN pad on top)
	OwnerVault.lock_all(); _restart_memory()
	t.check(OwnerVault.has_vault() and not OwnerVault.storage_ready(), "v0152 setup: sealed vault")
	t.check(ui._launch_unlock() == "social" and ui.get_node_or_null("SecurityScreen") == null, "v0152 launch with the social menu: exactly one login (social), no PIN pad")
	t.check(SocialBridge.owner_sign_in("SkorpionViper", V014.TEST_PW) == "" and OwnerVault.storage_ready(), "v0152 the one social sign-in opens the sealed saves too")
	# no social menu (desktop / old plugin): the PIN pad is the one login
	OwnerVault.lock_all(); _restart_memory()
	SocialBridge.plugin_override = null
	t.check(ui._launch_unlock() == "pin" and ui.get_node_or_null("SecurityScreen") != null, "v0152 launch without the social menu: the PIN pad is the one login")
	var sec := ui.get_node_or_null("SecurityScreen")
	if sec: sec.queue_free()
	await t.get_tree().process_frame
	fp.free()
	OwnerVault.lock_all()
	OwnerVault.clock_unix = Callable()
	OwnerVault.reset_for_tests("user://security")
	OwnerLogin.reset_for_tests("user://security")
	prof.data = saved
	prof.save()

static func _scroll(t: Node, ui: Node) -> void:
	# every list in the app is a KineticScroll (plain ScrollContainer could not be dragged over buttons)
	var bad: Array = []
	for d in ["res://scripts/admin", "res://scripts/social", "res://scripts/heaven", "res://scripts/ui", "res://scripts/security"]:
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"): continue
			for line in FileAccess.get_file_as_string(d.path_join(f)).split("\n"):
				if line.strip_edges().begins_with("#"): continue
				if line.contains("ScrollContainer.new()"): bad.append(f)
	t.check(bad.is_empty(), "v0152 every list scrolls by finger (no plain ScrollContainer left): %s" % [bad])
	# the top-most list wins: the Security screen scrolls, the menu under it does not
	ui.show_panel("menu")
	await t.get_tree().process_frame
	var under: ScrollContainer = ui.panels["menu"]["scroll"]
	under.scroll_vertical = 0
	var sec: Control = ui.open_security()
	await t.get_tree().process_frame; await t.get_tree().process_frame
	var top: KineticScroll = null
	for n in t.get_tree().get_nodes_in_group("kinetic_scroll"):
		if sec.is_ancestor_of(n) and (n as Control).is_visible_in_tree(): top = n; break
	t.check(top != null, "v0152 the Security screen list is a KineticScroll")
	if top:
		var p := top.get_global_rect().get_center()
		V0151._touch(t, p, true)
		for i in 12:
			p.y -= 25; V0151._drag(t, p, Vector2(0, -25))
			await t.get_tree().process_frame
		V0151._touch(t, p, false)
		await t.get_tree().process_frame
		t.check(under.scroll_vertical == 0, "v0152 a drag on the top screen does not scroll the menu underneath (menu=%d)" % under.scroll_vertical)
		t.check(is_instance_valid(sec) and sec.visible, "v0152 a drag on the Security screen does not tap a button")
	sec.queue_free()
	ui.show_panel("")
	await t.get_tree().process_frame

static func _landscape(t: Node, ui: Node) -> void:
	var root := t.get_tree().root
	var old := root.size
	for sz in [Vector2i(2400, 1080), Vector2i(1080, 2400)]:   # 1080x2400 phone, landscape then portrait
		root.size = sz
		await t.get_tree().process_frame
		ui._layout()
		ui.show_panel("menu")
		await t.get_tree().process_frame; await t.get_tree().process_frame
		var vr: Rect2 = ui.get_viewport().get_visible_rect()
		var pc: Control = ui.panels["menu"]["pc"]
		var r := pc.get_global_rect()
		var land := vr.size.x > vr.size.y
		if land:
			t.check(r.size.x <= vr.size.x * 0.5 + 1.0, "v0152 landscape menu is a side sheet (%d of %d px wide)" % [r.size.x, vr.size.x])
		else:
			t.check(r.size.x >= vr.size.x * 0.9, "v0152 portrait menu uses the full width")
		t.check(r.position.x >= 0 and r.end.x <= vr.size.x + 1 and r.end.y <= vr.size.y + 1, "v0152 menu fits on screen (%s, %s)" % [r, vr.size])
		ui.show_panel("")
	root.size = old
	await t.get_tree().process_frame
	ui._layout()
