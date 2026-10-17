# Security + PIN pad screenshots (needs autoloads, so run as a scene):
#   godot --resolution 720x1280 res://tests/screenshot_security.tscn -- <out_dir>
# Throwaway roots only; never touches the real vault or profile.
extends Node
func _ready():
	var out := "user://"
	if OS.get_cmdline_user_args().size() > 0: out = OS.get_cmdline_user_args()[0]
	OwnerVault.reset_for_tests("user://shot_sec_%d" % Time.get_ticks_usec(), 1000)
	ViperAdminData.root = "user://shot_sec_viper_%d" % Time.get_ticks_usec()
	AutonomyGuard.reset_for_tests(OwnerVault.root.path_join("estop.json"))
	OwnerVault.setup("246810", true)
	var s: SecurityScreen = load("res://scenes/admin/security_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("security_panel.png"))
	OwnerVault.lock(); s.refresh()
	var pad := s.open_pad("unlock")
	for k in "246": pad.press(k)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("pin_pad.png"))
	get_tree().quit()
