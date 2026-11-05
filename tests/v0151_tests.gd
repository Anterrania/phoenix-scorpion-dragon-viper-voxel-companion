extends RefCounted
## v0.15.1 hotfix tests: the classic menu scrolls by touch (as guest and as owner), the owner session is
## remembered across restarts (until logout / inactivity lock), and the social app's one sign-in unlocks
## the world owner (no second unlock).

const V014 := preload("res://tests/v014_tests.gd")

## Real engine path: Input.parse_input_event in window pixels (the stretch transform applies, like a phone).
static func _touch(t: Node, p: Vector2, on: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = 0; e.pressed = on
	e.position = t.get_tree().root.get_final_transform() * p
	Input.parse_input_event(e)

static func _drag(t: Node, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = 0
	e.position = t.get_tree().root.get_final_transform() * p
	e.relative = t.get_tree().root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(e)

static func run_scroll(t: Node) -> void:
	var s = load("res://scenes/main_world.tscn").instantiate()
	t.add_child(s)
	await t.get_tree().create_timer(1.0).timeout
	var ui = s.get_node("UI")
	var prof: Node = t.get_node("/root/Profile")
	var saved_role = prof.data.get("role", null)
	for owner in [false, true]:
		prof.data["role"] = "owner" if owner else "guest"
		for pn in ["menu", "avatar"]:
			ui.show_panel(pn)
			if pn == "avatar": ui._refresh_avatar(false)
			await t.get_tree().process_frame; await t.get_tree().process_frame
			var sc: ScrollContainer = ui.panels[pn]["scroll"]
			sc.scroll_vertical = 0
			var p := sc.get_global_rect().get_center()   # lands on a menu row button: the bug case
			_touch(t, p, true)
			for i in 12:
				p.y -= 25; _drag(t, p, Vector2(0, -25))
				await t.get_tree().process_frame
			_touch(t, p, false)
			await t.get_tree().process_frame
			t.check(ui.panels[pn]["root"].visible, "v0151 %s stays open after a drag (owner=%s): the drag must not tap the row under the finger" % [pn, owner])
			t.check(sc.scroll_vertical >= 250, "v0151 %s scrolls by touch drag (owner=%s): scroll=%d" % [pn, owner, sc.scroll_vertical])
	ui.show_panel("")
	if saved_role == null: prof.data.erase("role")
	else: prof.data["role"] = saved_role
	s.queue_free()
	await t.get_tree().process_frame

static func run_session(t: Node) -> void:
	var prof: Node = t.get_node("/root/Profile")
	var saved_data: Dictionary = prof.data.duplicate(true)
	var sroot := "user://test_v0151/security"
	OwnerVault.reset_for_tests(sroot, 1000)
	OwnerLogin.reset_for_tests(sroot)
	OwnerLogin.min_iter = 1000
	OwnerLogin.record_override = V014.VECTOR
	var now := [1_800_000_000]
	OwnerVault.clock_unix = func(): return now[0]
	# fresh install: nothing to restore, first sign-in required
	t.check(not OwnerVault.has_saved_session() and not OwnerVault.restore_session(), "v0151 fresh install: no saved owner session, sign-in required")
	# the social app's one sign-in (bridge signal path) creates the vault and the session
	t.check(SocialBridge.owner_sign_in("SkorpionViper", "wrong-password-x") != "" and not OwnerVault.is_unlocked(), "v0151 one login: wrong password refused")
	t.check(SocialBridge.owner_sign_in("SkorpionViper", V014.TEST_PW) == "" and prof.is_owner(), "v0151 one login: the social sign-in unlocks the world owner")
	t.check(OwnerVault.has_saved_session(), "v0151 owner session saved for the next launch")
	# t.check(not FileAccess.get_file_as_string(sroot.path_join("session.json")).contains(V014.TEST_PW), "v0151 the password is never in the saved session")   # v0.16 QUIET: decoding ciphertext as UTF-8 printed "Unicode parsing error" noise
	t.check(not FileAccess.get_file_as_bytes(sroot.path_join("session.json")).get_string_from_ascii().contains(V014.TEST_PW), "v0151 the password is never in the saved session")
	# app restart: memory gone, saved session restores without a password
	OwnerVault._vault_cache = null; OwnerVault._session = false; OwnerVault._dek_enc = PackedByteArray(); OwnerVault._dek_mac = PackedByteArray()
	now[0] += 600
	t.check(OwnerVault.restore_session() and prof.is_owner() and OwnerVault.storage_ready(), "v0151 session restore: owner signed in again after a restart (10 min later)")
	# a tampered key is refused
	var f := FileAccess.open(sroot.path_join("session.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 1, "dek": Marshalls.raw_to_base64(CryptoBox.random_bytes(64)), "seen": now[0]})); f.close()
	OwnerVault._session = false; OwnerVault._dek_enc = PackedByteArray(); OwnerVault._dek_mac = PackedByteArray()
	t.check(not OwnerVault.restore_session() and not OwnerVault.has_saved_session(), "v0151 a forged saved session is refused and removed")
	# sign in again, then idle past the lock: no restore, password unlocks (no re-setup)
	t.check(SocialBridge.owner_sign_in("SkorpionViper", V014.TEST_PW) == "", "v0151 sign in again")
	OwnerVault._session = false
	now[0] += OwnerVault.lock_minutes() * 60 + 5
	t.check(not OwnerVault.restore_session() and not OwnerVault.has_saved_session(), "v0151 inactivity lock: an old session is not restored")
	t.check(OwnerVault.has_vault() and OwnerLogin.sign_in("SkorpionViper", V014.TEST_PW) == "" and OwnerVault.is_unlocked(), "v0151 after the lock the password unlocks the same vault (no re-setup)")
	# logout from the social app ends it everywhere and forgets the saved session
	SocialBridge.owner_logout()
	t.check(not OwnerVault.is_unlocked() and not OwnerVault.has_saved_session(), "v0151 one logout: world owner locked, saved session gone")
	OwnerVault.lock_all()
	OwnerVault.reset_for_tests("user://security")
	OwnerLogin.reset_for_tests("user://security")
	prof.data = saved_data
	prof.save()
	# source: the hidden duplicate sign-in and the bridge
	var src := FileAccess.get_file_as_string("res://scripts/ui/ui_root.gd")
	t.check(src.contains("if SocialBridge.one_login():"), "v0151 avatar screen hides the second owner sign-in when the social menu exists")
	var kt := FileAccess.get_file_as_string("res://android/plugins/viper_device/src/main/java/com/anterrania/viperdevice/ViperDevicePlugin.kt")
	t.check(kt.contains("fun ownerSignIn(") and kt.contains("social_owner_sign_in") and kt.contains("fun ownerLogout()"), "v0151 plugin bridge: one owner sign-in and logout")
