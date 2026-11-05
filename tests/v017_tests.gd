extends RefCounted
## v0.17 tests: Viper brand (name, icons, boot splash, boot animation) + fresh first run defaults.

static func run(t: Node) -> void:
	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	t.check(ep.contains("package/name=\"Viper\"") and ep.contains("package/unique_name=\"com.anterrania.phoenixvoxel\""), "v017 app name Viper, package id unchanged")
	for f in ["icon_192", "adaptive_foreground_432", "adaptive_background_432", "adaptive_monochrome_432", "viper_crest"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/brand/%s.png" % f))
		t.check(img != null and not img.is_empty(), "v017 brand image " + f)
	t.check(str(ProjectSettings.get_setting("application/boot_splash/image", "")) == "res://assets/brand/viper_crest.png", "v017 boot splash is the crest")
	t.check(FileAccess.file_exists("res://assets/brand/viper_boot.ogv") and FileAccess.get_file_as_bytes("res://assets/brand/viper_boot.ogv").size() < 1500000, "v017 boot animation present and small")
	t.check(not BootIntro.should_play(), "v017 boot animation skipped headless (tests/CI)")
	var b := BootIntro.new()
	t.get_tree().root.add_child(b)
	await t.get_tree().process_frame
	b.finish()
	await t.get_tree().create_timer(0.8).timeout
	t.check(not is_instance_valid(b), "v017 boot animation skips/finishes and frees itself")
	# fresh first run: no PIN, guest profile, owner sign-in still available
	t.check(OwnerLogin.has_method("sign_in"), "v017 owner sign-in available on first run")
