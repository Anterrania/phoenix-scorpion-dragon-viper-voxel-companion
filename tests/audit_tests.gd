extends RefCounted
## 2026-10-17 audit/cleanup tests (docs/AUDIT_2026-10-17.md): one test per fixed bug or perf change.

static func run(t: Node) -> void:
	# --- bug: brain-cell revert from the admin Timeline must need the owner session ---
	var root := "user://test_audit_%d" % Time.get_ticks_usec()
	var brain_root := root.path_join("brains")
	var old_adapter := BrainCore.adapter_root
	BrainCore.adapter_root = brain_root
	ViperAdminData.root = root.path_join("viper")
	ViperAdminData.reset()
	ViperAdminData.revisions()   # hooks BrainCore.on_commit
	var persona: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companions/foxy_ani/persona.json"))
	EveCore.owner_override = true
	var b := BrainCore.new("foxy_ani", persona, brain_root)
	var cell := BrainCell.make("audit_hi", "foxy_ani", {"type": "chat_keyword", "any": ["audit"]}, {"type": "say", "text": "Audit ok."}, 0.5, "user")
	var res: Dictionary = b.propose(cell, "test")
	if res.get("status", "") == "pending": b.approve("audit_hi")
	var learned := brain_root.path_join("foxy_ani/cells/audit_hi.cell.json")
	var revs := ViperAdminData.revisions().history("brain/foxy_ani/audit_hi", "brain_cell")
	t.check(revs.size() == 1 and FileAccess.file_exists(learned), "audit: learned cell committed as a revision")
	var rn: int = revs[0]["rev"] if revs.size() == 1 else 0
	EveCore.owner_override = false
	t.check(ViperAdminData.revisions().revert(rn, "intruder") == 0 and FileAccess.file_exists(learned), "audit: brain-cell revert refused while owner session is locked")
	EveCore.owner_override = true
	t.check(ViperAdminData.revisions().revert(rn, "phoenix") > 0 and not FileAccess.file_exists(learned), "audit: brain-cell revert allowed for the unlocked owner")
	EveCore.owner_override = null
	ViperAdminData.reset()
	BrainCore.adapter_root = old_adapter

	# --- bug: TASK_TRACKER.csv was imported as a translation (3 junk .translation files shipped) ---
	var imp := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv.import")
	t.check(imp.contains("importer=\"keep\"") and not imp.contains("csv_translation"), "audit: tracker CSV kept as a plain file, not a translation")

	# --- size: export filters keep docs/tests/tools/art refs/markdown/inactive prototype out of the APK ---
	var cfg := ConfigFile.new(); cfg.load("res://export_presets.cfg")
	var ex := str(cfg.get_value("preset.0", "exclude_filter", ""))
	for f in ["docs/*", "tests/*", "tools/*", "art/*", "assets/concept_art/*", "*.md", "scenes/main.tscn"]:
		t.check(ex.contains(f), "audit: Android export excludes " + f)
	t.check(str(cfg.get_value("preset.0", "include_filter", "")).contains("data/*.json"), "audit: data json still included")

	# --- inactive code is commented out, not deleted, and carries the INACTIVE header ---
	for p in ["res://scripts/companion_agent.gd", "res://scripts/player_controller.gd", "res://scripts/generators/biome_generator.gd", "res://scripts/chat_ui.gd", "res://scripts/autoload/persona_registry.gd"]:
		var src := FileAccess.get_file_as_string(p)
		t.check(src.begins_with("# INACTIVE (2026-10-17):") and src.to_lower().contains("re-enable"), "audit: INACTIVE header + re-enable note: " + p.get_file())
	t.check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_world.tscn", "audit: main scene unchanged")

	# --- coverage: Lindex-style order book (scaffold) had no test ---
	var ex2 := CurrencyExchange.new()
	ex2.place_order("a", "buy", 10, 105); ex2.place_order("b", "sell", 4, 100); ex2.place_order("c", "sell", 10, 110)
	var fills := ex2.match_orders()
	t.check(fills.size() == 1 and fills[0]["qty"] == 4 and fills[0]["price"] == 100 and fills[0]["fee"] == 2, "audit: exchange fills at ask, 0.5% fee (scaffold)")
	t.check(ex2.bids.size() == 1 and ex2.bids[0]["qty"] == 6 and ex2.asks.size() == 1, "audit: exchange keeps unfilled remainder")

static func run_scene(t: Node) -> void:
	# --- perf: kit rings / radial menu stop redrawing every frame once settled ---
	var r: RingStat = load("res://scenes/ui/kit/ring_stat.tscn").instantiate()
	t.get_tree().root.add_child(r)
	r.set_value(0.5)
	for i in 40: await t.get_tree().process_frame
	await t.get_tree().create_timer(PhoenixTokens.MOTION.slow + 0.1).timeout
	await t.get_tree().process_frame
	t.check(not r.needs_redraw(), "audit: RingStat idle -> no per-frame redraw")
	r.caption = "changed"
	t.check(r.needs_redraw(), "audit: RingStat caption change -> redraw")
	r.queue_free()
	var m := RadialMenu.new(); t.get_tree().root.add_child(m)
	await t.get_tree().create_timer(PhoenixTokens.MOTION.base + 0.1).timeout
	await t.get_tree().process_frame
	t.check(not m.needs_redraw(), "audit: RadialMenu idle -> no per-frame redraw")
	m.set_open(false)
	await t.get_tree().create_timer(0.05).timeout
	t.check(m._t < 1.0 and m._drawn.size() > 0 and float(m._drawn[0]) < 1.0, "audit: RadialMenu redraws while closing")
	m.queue_free()
	# --- perf: admin swipe rebuilds only the shown tab ---
	ViperAdminData.root = "user://test_audit_admin_%d" % Time.get_ticks_usec()
	ViperAdminData.reset()
	var a: AdminScreen = load("res://scenes/admin/admin_screen.tscn").instantiate()
	a.write_profile = false
	t.get_tree().root.add_child(a)
	var home_first := a.home.get_child(0) if a.home.get_child_count() > 0 else null
	var n0 := a.tab_refreshes
	a.pages.go(AdminScreen.TABS.find("Wiki"))
	t.check(a.tab_refreshes == n0 + 1, "audit: admin tab change refreshes one tab")
	t.check(home_first != null and is_instance_valid(home_first) and home_first.get_parent() == a.home, "audit: Home not rebuilt when opening Wiki")
	a.pages.go(0)
	t.check(not (is_instance_valid(home_first) and home_first.get_parent() == a.home), "audit: Home rebuilt when shown again (never stale)")
	a.queue_free()
	ViperAdminData.reset()
