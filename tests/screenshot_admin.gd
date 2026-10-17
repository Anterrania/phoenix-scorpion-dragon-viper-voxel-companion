# Admin screenshots: godot --resolution 720x1280 -s res://tests/screenshot_admin.gd -- <out_dir>
# Uses a throwaway user://viper_shot root; never touches the real profile.
extends SceneTree
func _initialize():
	var out := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	ViperAdminData.root = "user://viper_shot"
	if DirAccess.dir_exists_absolute(ViperAdminData.root):
		for f in DirAccess.get_files_at(ViperAdminData.root): DirAccess.remove_absolute(ViperAdminData.root.path_join(f))
	ViperAdminData.reset()
	var a: AdminScreen = load("res://scenes/admin/admin_screen.tscn").instantiate()
	a.write_profile = false
	root.add_child(a)
	await create_timer(0.5).timeout
	for i in AdminScreen.TABS.size():
		a.pages.go(i)
		if i == 1: a.ticket_list.row(0).show_actions()
		await create_timer(1.0).timeout
		var p := out.path_join("admin_%d_%s.png" % [i, AdminScreen.TABS[i].to_lower()])
		root.get_viewport().get_texture().get_image().save_png(p)
		print("saved ", p)
	a._on_link("wiki:VoxelArchitecture")
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(out.path_join("admin_5_wiki_page.png"))
	quit()
