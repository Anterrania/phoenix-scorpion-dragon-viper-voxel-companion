extends RefCounted
## v0.15 tests: the social app is the menu (world actions bridge + classic fallback), portrait menu fixes
## (smooth kinetic scroll, scrollbar gutter, radial hidden behind panels), keyboard avoidance hooks.

class FakeUi extends Node:
	var ran: Array = []
	func menu_action(id: String) -> void: ran.append(id)

static func run(t: Node) -> void:
	# World actions offered to the social menu
	var s = load("res://scenes/main_world.tscn").instantiate()
	t.add_child(s)
	await t.get_tree().create_timer(1.0).timeout
	var ui = s.get_node("UI")
	var acts: Array = ui.menu_actions()
	var ids: Array = acts.map(func(a): return a["id"])
	t.check(ids[0] == "play" and ids.has("travel") and ids.has("_worlds") and ids.has("_companions") and ids.has("avatar") and ids.has("settings") and ids.has("menu_classic"), "v015 world actions: play, teleport, worlds, companions, avatar, settings, classic")
	t.check(not ids.has("_open_social_app") and not ids.has("_social") and not ids.has(""), "v015 world actions never loop back to the social app")
	for a in acts: t.check(SocialBridge._ident(String(a["id"])), "v015 action id is a safe ident: " + String(a["id"]))
	t.check(ui.SOCIAL_MENU, "v015 social menu on by default (const fallback flag present)")
	# Desktop (no plugin): ☰ falls back to the Godot menu
	ui.show_panel("menu")
	t.check(ui.panels["menu"]["root"].visible, "v015 no embedded panel: classic Godot menu opens")
	t.check(ui.radial == null or not ui.radial.visible, "v015 radial hidden while a menu list is open")
	# Dispatch
	ui.menu_action("play")
	t.check(not ui.is_open() and (ui.radial == null or ui.radial.visible), "v015 play closes the menu and brings the radial back")
	ui.menu_action("settings")
	t.check(ui.panels["settings"]["root"].visible, "v015 menu_action opens a panel")
	ui.menu_action("menu_classic")
	t.check(ui.panels["menu"]["root"].visible, "v015 Classic menu action opens the Godot menu")
	ui.show_panel("")
	# Scrollbar gutter
	var body: Control = ui.panels["menu"]["body"]
	t.check(body.get_parent() is MarginContainer and (body.get_parent() as MarginContainer).get_theme_constant("margin_right") >= 14, "v015 list has a right gutter for the scrollbar")
	var sc: KineticScroll = ui.panels["menu"]["scroll"]
	t.check(sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "v015 scrollbar only when needed")
	t.check(ui.has_method("_keyboard_tick") and ui.has_method("_reveal_focus"), "v015 keyboard avoidance hooks")
	s.queue_free()
	# Action signal whitelist
	var f := FakeUi.new()
	SocialBridge._on_action("travel", f)
	SocialBridge._on_action("bad id;x", f)
	SocialBridge._on_action("", f)
	t.check(f.ran == ["travel"], "v015 social world action: only safe ids reach the menu")
	f.free()
	# Plugin source: world actions + IME insets, panel kept alive
	var kt := FileAccess.get_file_as_string("res://android/plugins/viper_device/src/main/java/com/anterrania/viperdevice/ViperDevicePlugin.kt")
	t.check(kt.contains("fun worldAction(") and kt.contains("fun worldActions()") and kt.contains("social_world_action") and kt.contains("id !in actionIds"), "v015 plugin: whitelisted world actions over the JS bridge")
	t.check(kt.contains("WindowInsets.Type.ime()") and kt.contains("SOFT_INPUT_ADJUST_RESIZE"), "v015 plugin: keyboard-aware panel")
	t.check(kt.contains("fun get_plugin_version(): Int = 4"), "v015 plugin v4")

## v0.15.1 BOOT: the embedded social bundle must be self-consistent (v0.15.0 shipped an index.html whose
## /assets/index-*.js was not in the bundle, so the panel sat on the splash).
static func run_bundle(t: Node) -> void:
	var root := "res://social_web/bundle"
	var html := FileAccess.get_file_as_string(root + "/index.html")
	t.check(html.contains("<html"), "v0151 social bundle has index.html")
	var re := RegEx.new()
	re.compile("(?:src|href)=\"(/assets/[^\"]+)\"")
	var refs := re.search_all(html)
	t.check(refs.size() > 0, "v0151 social index.html references its scripts")
	for m in refs:
		t.check(FileAccess.file_exists(root + m.get_string(1)), "v0151 social asset present: " + m.get_string(1))
	t.check(html.contains("boot-error"), "v0151 social boot error screen instead of a stuck splash")
