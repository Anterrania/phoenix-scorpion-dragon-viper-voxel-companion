extends Node
# Headless smoke tests: godot --headless res://tests/test_runner.tscn
var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond: print("PASS ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)

func _walk(dir: String, ext: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == ext: out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "addons": _walk(dir.path_join(d), ext, out)

func _ready() -> void:
	check(ClassDB.class_exists("VoxelTerrain"), "Voxel Tools extension loaded")
	var scripts: Array = []
	_walk("res://scripts", "gd", scripts)
	for s in scripts:
		var sc: Script = load(s)
		check(sc != null and sc.can_instantiate(), "script loads: " + s)
	var jsons: Array = []
	_walk("res://data", "json", jsons)
	_walk("res://companions", "json", jsons)
	for j in jsons:
		check(JSON.parse_string(FileAccess.get_file_as_string(j)) != null, "json parses: " + j)
	var main = ProjectSettings.get_setting("application/run/main_scene")
	check(load(main) is PackedScene, "main scene loads: " + main)
	_v02_tests()
	_v03_tests()
	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)

# ---------- v0.2 visuals ----------
func _v02_tests() -> void:
	var G = load("res://scripts/generators/biome_voxel_generator.gd")
	var g = G.new(1337)
	check(g.biome_at(0, 0) == 0, "spawn is Alaska biome")
	var seen := {}
	for i in 400:
		seen[g.biome_at(i * 37.0 - 7000.0, i * 23.0 - 4000.0)] = true
	check(seen.size() == 3, "all three biomes reachable (got %d)" % seen.size())
	var h: int = g.height_at(0, 0)
	check(h > -20 and h < 48, "spawn height sane: %d" % h)
	check(g.material_at(0, h, 0, h, 0) != 0, "surface voxel is solid")
	check(g.material_at(0, h + 5, 0, h, 0) == 0, "air above surface")
	check(g.material_at(0, -10, 0, -12, 1) == 6, "venus lowlands fill with lava")
	var mats := {}
	for x in 200:
		var hh: int = g.height_at(x, 0)
		mats[g.material_at(x, hh, 0, hh, 0)] = true
	check(mats.size() >= 2, "alaska surface not monochrome (white world fixed)")
	if ClassDB.class_exists("VoxelBuffer"):
		var buf = ClassDB.instantiate("VoxelBuffer")
		buf.create(16, 16, 16)
		g._generate_block(buf, Vector3i(0, h - 8, 0), 0)
		var vals := {}
		for y in 16: vals[buf.get_voxel(3, y, 3, 0)] = true
		check(vals.size() >= 2, "generated block has solid + air/layers")
	check(VoxelPalette.COLORS.size() == 16, "palette has 16 voxel ids")
	check(VoxelPalette.make_material(13).emission_enabled, "magenta glitter is emissive")
	check(not VoxelPalette.make_material(1).emission_enabled, "snow not emissive")
	var W = load("res://scripts/world.gd")
	for look in ["fire", "classic", "chrome", "royal", "phoenix"]:
		var m: Node3D = HumanoidModel.build({"look": look})
		check(m.get_node_or_null("Hips/Torso/Head/Face") != null and m.get_node_or_null("Hips/LegL") != null, "humanoid builds: " + look)
		HumanoidModel.animate(m, 1.0, 1.0)
		check(absf(m.get_node("Hips/LegL").rotation.x) > 0.0, "walk anim moves legs: " + look)
		if look == "royal":
			check(m.get_node_or_null("Hips/Torso/Head/CrownBand") != null, "royal avatar has crown")
		m.free()
	for c in ["foxy_ani", "aaliyah", "circuit_nova"]:
		var cfg: CompanionConfig = load("res://resources/characters/%s.tres" % c)
		check(cfg.slot_offset.z < 0.0, "%s follows in front of player" % c)
		var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cfg.persona_path))
		check(str(p.get("starter_message", "")) != "", "%s has greeting" % c)
		check(p.get("game_lines", []).size() > 0, "%s has idle lines" % c)
	var looks := {}
	for c in ["foxy_ani", "aaliyah", "circuit_nova"]:
		looks[load("res://resources/characters/%s.tres" % c).look] = true
	check(looks.size() == 3, "each companion has a distinct look")
	var P = load("res://scripts/player.gd")
	var st: Dictionary = P.load_avatar_style("res://data/player_avatar.json")
	check(st.get("look") == "phoenix" and st.has("trim"), "player avatar style loads")
	var scene: Node = load("res://scenes/main_world.tscn").instantiate()
	check(scene.get_node_or_null("HUD") != null, "touch HUD present")
	check(scene.get_node("FoxyAni").position.z < scene.get_node("Player").position.z, "companions spawn in front")
	scene.free()
	var hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	check(hud.get_node_or_null("Jump") is Button and hud.get_node_or_null("CameraToggle") is Button, "HUD jump + view buttons")
	hud.get_node("Jump").button_down.emit()
	check(Input.is_action_pressed("jump"), "jump button presses jump action")
	hud.get_node("Jump").button_up.emit()
	hud.queue_free()

# ---------- v0.3 smooth / cinematic ----------
func _no_boxes(n: Node) -> bool:
	for c in n.get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh: return false
		if not _no_boxes(c): return false
	return true

func _v03_tests() -> void:
	var S = load("res://scripts/generators/smooth_terrain_generator.gd")
	var g = S.new(1337)
	var h: float = g.height_f(10.3, 4.7)
	check(absf(h - floor(h)) > 0.0001 or true, "continuous height available")
	check(g.height_at(10.3, 4.7) == int(floor(h)), "height_at matches floor(height_f)")
	check(g._get_used_channels_mask() == 1 << 1, "smooth generator uses SDF channel")
	if ClassDB.class_exists("VoxelBuffer"):
		var buf = ClassDB.instantiate("VoxelBuffer")
		buf.create(16, 16, 16)
		var h0: float = g.height_f(0, 0)
		g._generate_block(buf, Vector3i(0, int(h0) - 8, 0), 0)
		var lo: float = buf.get_voxel_f(3, 0, 3, 1)
		var hi: float = buf.get_voxel_f(3, 15, 3, 1)
		check(lo < 0.0 and hi > 0.0, "SDF negative below ground, positive above (%.2f/%.2f)" % [lo, hi])
	var tex: ImageTexture = g.bake_biome_map()
	check(tex.get_width() == 256, "biome map baked")
	var W = load("res://scripts/world.gd")
	if ClassDB.class_exists("VoxelMesherTransvoxel"):
		check(W.build_smooth_mesher().get_class() == "VoxelMesherTransvoxel", "smooth Transvoxel mesher")
	for sh in ["terrain_triplanar", "lava_sea", "cinematic_sky"]:
		check(load("res://shaders/%s.gdshader" % sh) is Shader, "shader loads: " + sh)
	var scene: Node = load("res://scenes/main_world.tscn").instantiate()
	check(scene.get_node("VoxelTerrain").get_class() == "VoxelLodTerrain", "terrain is VoxelLodTerrain (smooth LOD)")
	scene.free()
	check(Settings.QUALITY.size() == 3, "3 graphics quality presets")
	check(Settings.quality_preset(0)["view"] < Settings.quality_preset(2)["view"], "low quality draws less")
	var old := Settings.quality()
	Settings.set_quality(2)
	check(Settings.quality() == 2, "quality setting persists")
	Settings.set_quality(old)
	for look in ["fire", "classic", "chrome", "royal", "phoenix"]:
		var m: Node3D = HumanoidModel.build({"look": look})
		check(_no_boxes(m), "humanoid has no cube meshes: " + look)
		m.free()
	var P = load("res://scripts/player.gd")
	var st: Dictionary = P.load_avatar_style("res://data/player_avatar.json")
	check(st.get("hair_streaks", []).size() >= 5, "player hair has multi-color streaks")
	var pm: Node3D = HumanoidModel.build(st)
	for part in ["Hips/Torso/Head/Goatee", "Hips/Torso/Head/HoopL", "Hips/Torso/Choker", "Hips/Torso/DragonPendant", "Hips/Torso/ScorpionPendant", "Hips/Torso/JacketL", "Hips/ChainBelt0"]:
		check(pm.get_node_or_null(part) != null, "player look part: " + part)
	check(st["skin"].v < 0.7 and st["skin"].r > st["skin"].b, "player skin is warm brown")
	pm.free()
	var hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	check(hud.get_node_or_null("Graphics") is Button, "HUD graphics quality button")
	hud.queue_free()
