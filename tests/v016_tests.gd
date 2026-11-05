extends RefCounted
## v0.16 tests: the top bar never runs under the minimap (anything off-screen goes into "More ▾", any size or
## orientation), Android notifications through the plugin (Android 13+ permission asked once), and the
## Scorpion Viper v0.43 bundle (one top menu + More ▾ + notifications) is the one shipped in the app.

class FakeNotify extends Object:
	var version := 6
	var perm := "default"
	var posted: Array = []
	var requested := 0
	var prepared := 0
	func get_plugin_version() -> int: return version
	func has_social_bundle() -> bool: return true
	func open_social_panel(_p := "") -> bool: return true
	func set_owner_session(_on: bool) -> void: pass
	func notify_permission() -> String: return perm
	func request_notify_permission() -> void: requested += 1
	func prepare_social_panel() -> bool: prepared += 1; return true
	func post_notification(title: String, body: String, tag: String) -> bool:
		if perm != "granted": return false
		posted.append([title, body, tag]); return true

static func run(t: Node) -> void:
	_notify(t)
	_sources(t)
	var s = load("res://scenes/main_world.tscn").instantiate()
	t.add_child(s)
	await t.get_tree().create_timer(1.0).timeout
	var ui = s.get_node("UI")
	await _more(t, ui)
	_launch_notify(t, ui)
	s.queue_free()
	await t.get_tree().process_frame

static func _more(t: Node, ui: Node) -> void:
	var root := t.get_tree().root
	var old := root.size
	var saw_more := false
	var saw_all := false
	for sz in [Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(2400, 1080), Vector2i(1280, 720)]:
		root.size = sz
		await t.get_tree().process_frame
		ui._layout()
		await t.get_tree().process_frame; await t.get_tree().process_frame
		var vr: Rect2 = ui.get_viewport().get_visible_rect()
		var room: float = ui.top_bar_room()
		var right := 0.0
		for b in ui.top_bar.get_children():
			if (b as Control).visible: right = maxf(right, (b as Control).get_global_rect().end.x)
		var tag := "%dx%d" % [sz.x, sz.y]
		t.check(right <= 12.0 + room + 1.0, "v016 %s top bar stays clear of the minimap (ends at %d, room %d)" % [tag, right, 12.0 + room])
		var over: Array = ui.top_overflow()
		t.check(ui.top_more.visible == not over.is_empty(), "v016 %s More ▾ shows only when something is off-screen (%s)" % [tag, over])
		t.check(ui.top_bar.get_node("Top_menu").visible, "v016 %s the ☰ menu button is always on the bar" % tag)
		if over.is_empty(): saw_all = true; continue
		saw_more = true
		ui._toggle_top_more()
		await t.get_tree().process_frame; await t.get_tree().process_frame
		var m: Control = ui.top_menu
		t.check(m != null and m.get_child_count() == 1, "v016 %s More ▾ opens a dropdown" % tag)
		if m == null: continue
		var pc: Control = m.get_child(0)
		var r := pc.get_global_rect()
		t.check(r.position.x >= 0 and r.position.y >= 0 and r.end.x <= vr.size.x + 1 and r.end.y <= vr.size.y + 1, "v016 %s dropdown is on screen (%s in %s)" % [tag, r, vr.size])
		var rows: Array = []
		for n in pc.find_children("*", "Button", true, false): rows.append((n as Button).text)
		t.check(rows.size() == over.size(), "v016 %s dropdown lists every hidden button (%s)" % [tag, rows])
		t.check(pc.find_children("*", "KineticScroll", true, false).size() == 1, "v016 %s dropdown scrolls by finger if long" % tag)
		# a row runs the same action and closes the dropdown (wardrobe -> its panel)
		var wb: Button = null
		for n in pc.find_children("*", "Button", true, false):
			if (n as Button).text.contains("Wardrobe"): wb = n
		if wb:
			wb.emit_signal("pressed")
			await t.get_tree().process_frame
			t.check(ui.panels["wardrobe"]["root"].visible and (ui.top_menu == null or not is_instance_valid(ui.top_menu)), "v016 %s dropdown row opens Wardrobe and closes" % tag)
			ui.show_panel("")
		else:
			ui._close_top_more()
		# tap outside closes it
		ui._toggle_top_more()
		await t.get_tree().process_frame
		var ev := InputEventMouseButton.new(); ev.pressed = true; ev.button_index = MOUSE_BUTTON_LEFT
		ui.top_menu.gui_input.emit(ev)
		await t.get_tree().process_frame
		t.check(ui.top_menu == null, "v016 %s a tap outside closes More ▾" % tag)
	t.check(saw_more and saw_all, "v016 narrow screens use More ▾, wide ones show every button (more=%s all=%s)" % [saw_more, saw_all])
	root.size = old
	await t.get_tree().process_frame
	ui._layout()

static func _notify(t: Node) -> void:
	var fp := FakeNotify.new()
	SocialBridge.plugin_override = fp
	t.check(SocialBridge.notify_permission() == "default", "v016 notify permission read from the plugin")
	t.check(not SocialBridge.notify("Nova", "hi", "message") and fp.posted.is_empty(), "v016 nothing is posted before the Android 13+ permission")
	t.check(SocialBridge.setup_notifications(false) == "requested" and fp.requested == 1 and fp.prepared == 1, "v016 first launch asks once and starts the social alert watcher")
	t.check(SocialBridge.setup_notifications(true) == "asked" and fp.requested == 1, "v016 never asks a second time")
	fp.perm = "granted"
	t.check(SocialBridge.setup_notifications(true) == "granted", "v016 granted: no prompt")
	t.check(SocialBridge.notify("Nova sent you a message", "x".repeat(500), "message") and fp.posted.size() == 1 and String(fp.posted[0][1]).length() == 200, "v016 a message notification posts (long text trimmed)")
	SocialBridge.notify("Live", "Foxy is live", "bogus")
	t.check(fp.posted.size() == 2 and fp.posted[1][2] == "message", "v016 an unknown kind falls back to the Messages channel")
	t.check(not SocialBridge.notify("   ", "x", "live"), "v016 an empty title is not posted")
	for k in ["friend", "live", "announcement"]: SocialBridge.notify("t " + k, "b", k)
	t.check(fp.posted.size() == 5 and fp.posted[4][2] == "announcement", "v016 friend / live / announcement channels")
	fp.version = 5
	t.check(SocialBridge.notify_permission() == "unsupported" and SocialBridge.setup_notifications(false) == "unsupported", "v016 an older plugin (v5) is left alone")
	SocialBridge.plugin_override = null
	t.check(SocialBridge.notify_permission() == "unsupported" and not SocialBridge.notify("a", "b"), "v016 desktop: no plugin, no crash")
	fp.free()

static func _launch_notify(t: Node, ui: Node) -> void:
	var fp := FakeNotify.new()
	SocialBridge.plugin_override = fp
	var was: Variant = Settings.get_value("notify", "asked", false)
	Settings.set_value("notify", "asked", false)
	t.check(ui._setup_notify() == "requested" and bool(Settings.get_value("notify", "asked", false)), "v016 launch asks for notifications once and remembers it")
	t.check(ui._setup_notify() == "asked" and fp.requested == 1, "v016 the next launch does not ask again")
	Settings.set_value("notify", "asked", was)
	SocialBridge.plugin_override = null
	fp.free()

static func _sources(t: Node) -> void:
	var kt := FileAccess.get_file_as_string("res://android/plugins/viper_device/src/main/java/com/anterrania/viperdevice/ViperDevicePlugin.kt")
	t.check(kt.contains("fun get_plugin_version(): Int = 6") and kt.contains("fun post_notification(") and kt.contains("fun notify(title: String"), "v016 plugin v6 posts notifications (Godot + social bridge)")
	t.check(kt.contains("POST_NOTIFICATIONS") and kt.contains("Build.VERSION.SDK_INT >= 33"), "v016 plugin asks for POST_NOTIFICATIONS on Android 13+")
	var man := FileAccess.get_file_as_string("res://android/plugins/viper_device/src/main/AndroidManifest.xml")
	t.check(man.contains("android.permission.POST_NOTIFICATIONS"), "v016 POST_NOTIFICATIONS in the plugin manifest")
	t.check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("permissions/post_notifications=true"), "v016 export preset requests POST_NOTIFICATIONS")
	var js := ""
	for f in DirAccess.get_files_at("res://social_web/bundle/assets"):
		if f.ends_with(".js"): js += FileAccess.get_file_as_string("res://social_web/bundle/assets/" + f)
	t.check(js.contains("more-menu") and js.contains("viper-notified-v1") and js.contains("account-menu"), "v016 shipped social bundle is v0.43 (More ▾, account menu, notifications)")
	t.check(js.contains("__OWNER_PASS_HASH__"), "v016 committed bundle holds the placeholder, never the owner hash")
