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

	# --- bug: a static `reload()` on a class_name is shadowed by Script.reload() (Estate.reload on unlock) ---
	var c := ConfigFile.new(); c.set_value("region:audit", "water_height", 9.0)
	Estate._cfg = c
	Estate.reload_data()
	t.check(Estate._cfg == null, "audit: Estate.reload_data() drops the cached config")
	t.check(not FileAccess.get_file_as_string("res://scripts/world/estate.gd").contains("static func reload()"), "audit: Estate has no static reload() (would be Script.reload)")
	t.check(FileAccess.get_file_as_string("res://scripts/autoload/profile.gd").contains("Estate.reload_data()"), "audit: Profile unlock hook calls Estate.reload_data()")
	var bad := _shadowing_statics()
	t.check(bad.is_empty(), "audit: no class_name static func shadows a built-in Script/Object method %s" % [bad])

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

## Static funcs on class_name scripts that share a name with a method of Script/GDScript/Resource/Object.
## Calling them as ClassName.method() runs the built-in instead (found with Estate.reload, 2026-10-17).
const BUILTIN := ["reload", "can_instantiate", "get_base_script", "get_global_name", "get_instance_base_type",
	"get_property_default_value", "get_script_constant_map", "get_script_method_list", "get_script_property_list",
	"get_script_signal_list", "get_source_code", "has_script_signal", "has_source_code", "instance_has", "is_abstract",
	"is_tool", "set_source_code", "new", "duplicate", "emit_changed", "get_rid", "take_over_path", "reset_state",
	"get_path", "set_path", "get_name", "get", "set", "call", "callv", "connect", "disconnect", "free", "get_class",
	"is_class", "notification", "to_string", "get_meta", "set_meta", "has_meta", "has_method", "has_signal",
	"emit_signal", "get_property_list", "get_method_list", "get_signal_list", "get_script", "set_script",
	"get_instance_id", "call_deferred", "set_deferred", "tr", "tr_n"]
static func _shadowing_statics() -> Array:
	var out: Array = []
	var files: Array = []
	_walk("res://scripts", files)
	var re := RegEx.create_from_string("(?m)^static func (\\w+)")
	for f in files:
		var src := FileAccess.get_file_as_string(f)
		if not src.contains("\nclass_name ") and not src.begins_with("class_name "): continue
		for m in re.search_all(src):
			if m.get_string(1) in BUILTIN: out.append("%s:%s" % [f.get_file(), m.get_string(1)])
	return out

static func _walk(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"): out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir): _walk(dir.path_join(d), out)
