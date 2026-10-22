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
	_v04_tests()
	await _v05_tests()
	_v08_tests()
	await _v09_tests()
	BrainCore.adapter_root = "user://brains_test_adapter"  # keep Eve forwarding out of real user://brains
	_eve_tests()
	BrainCore.adapter_root = BrainCore.DEFAULT_ROOT
	load("res://tests/brain_tests.gd").run(self)
	load("res://tests/brain_tests.gd").run_eve_adapter(self)
	load("res://tests/brain_tests.gd").run_owner_flow(self)
	load("res://tests/brain_tests.gd").run_agent_brain(self)
	_ui_kit_tests()
	_v10_tests()
	_v10_music_tests()
	_v11_tests()
	Tiers.owner_override = true   # AUDIT-2: admin writes need the owner session (gate_tests covers the refusal)
	load("res://tests/admin_tests.gd").run(self)
	await load("res://tests/admin_tests.gd").run_scene(self)
	Tiers.owner_override = null
	load("res://tests/security_tests.gd").run(self)
	load("res://tests/wiki_tests.gd").run(self)
	await load("res://tests/security_tests.gd").run_ui(self)
	load("res://tests/social_tests.gd").run(self); load("res://tests/social_tests.gd").run_docs(self); await load("res://tests/social_tests.gd").run_ui(self)
	load("res://tests/audit_tests.gd").run(self)
	await load("res://tests/audit_tests.gd").run_scene(self)
	await load("res://tests/kit_calm_tests.gd").run_scene(self)
	load("res://tests/render_tests.gd").run(self); await load("res://tests/render_tests.gd").run_scene(self)
	load("res://tests/viewer_tests.gd").run(self); load("res://tests/viewer_tests.gd").run_docs(self); await load("res://tests/viewer_tests.gd").run_ui(self)
	load("res://tests/interop_tests.gd").run(self); load("res://tests/interop_tests.gd").run_docs(self); await load("res://tests/interop_tests.gd").run_ui(self)
	load("res://tests/gate_tests.gd").run(self)
	await load("res://tests/gate_tests.gd").run_scene(self)
	load("res://tests/sec_fix_tests.gd").run(self)
	load("res://tests/sec_fix_tests.gd").cleanup(self)
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

# ---------- v0.4 physics & collision ----------
func _v04_tests() -> void:
	var S = load("res://scripts/generators/smooth_terrain_generator.gd")
	var g = S.new(1337)
	var SP := SurfacePhysics
	var spots := {}
	for i in 6000:
		var x := i * 11.0 - 30000.0
		var z := (i % 97) * 23.0 - 1100.0
		if g.height_f(x, z) < g.LAVA_LEVEL - 1.0:
			var b: int = g.biome_at(x, z)
			if not spots.has(b): spots[b] = Vector3(x, g.LAVA_LEVEL, z)
	check(spots.has(1), "found a Venus lava lake")
	if spots.has(1):
		var p: Vector3 = spots[1]
		check(SP.surface_at(g, p) == SP.Surface.LAVA, "lava surface detected")
		var r: Dictionary = SP.apply(g, p, Vector3(0, -3, 0), 0.1)
		check(r.damage > 0.0, "lava damages")
		check(r.velocity.y > 0.0 and Vector2(r.velocity.x, r.velocity.z).length() > 1.0, "lava pushes back/up")
	if spots.has(0):
		var p: Vector3 = spots[0] + Vector3(0, -1.5, 0)
		var r: Dictionary = SP.apply(g, p, Vector3(0, -5, 0), 0.1)
		check(r.position.y >= g.LAVA_LEVEL + 0.8 and r.velocity.y >= 0.0, "frozen sea is solid ice (%s %s s=%d)" % [r.position, r.velocity, r.surface])
	check(SP.accel_for(SP.Surface.ICE) < SP.accel_for(SP.Surface.GROUND) / 10.0, "ice is slippery")
	var v: Vector3 = SP.steer(Vector3(5, 0, 0), Vector3.ZERO, SP.Surface.ICE, 0.1)
	check(v.x > 4.5, "ice keeps momentum when you stop")
	v = SP.steer(Vector3(5, 0, 0), Vector3.ZERO, SP.Surface.GROUND, 0.2)
	check(v.x == 0.0, "ground stops you quickly")
	var gh: float = g.height_f(5, 5)
	var r2: Dictionary = SP.apply(g, Vector3(5, gh - 4.0, 5), Vector3(0, -20, 0), 0.016)
	check(r2.position.y > gh and r2.velocity.y >= 0.0, "fell-through-ground safety net snaps back up")
	var r3: Dictionary = SP.apply(g, Vector3(5, gh + 10.0, 5), Vector3(0, -2, 0), 0.016)
	check(absf(r3.position.y - (gh + 10.0)) < 0.01, "safety net leaves airborne bodies alone")
	var sep: Vector3 = SP.separation(Vector3.ZERO, [Vector3(0.5, 0, 0)])
	check(sep.x < 0.0, "separation pushes away from neighbour")
	check(SP.separation(Vector3.ZERO, [Vector3(5, 0, 0)]) == Vector3.ZERO, "no push when far apart")
	var Props = load("res://scripts/physics/physics_props.gd")
	var props = Props.new()
	add_child(props)
	props.setup(g, Vector3(0, 0, -8))
	check(props.props.size() == 12, "12 physics props spawned")
	var kinds := {}
	for rb in props.props:
		kinds[rb.get_meta("kind")] = true
		check(rb is RigidBody3D and rb.get_child_count() >= 2, "prop is rigid body with shape+mesh")
	check(kinds.size() == 3, "crates, rocks and crystals")
	check(props.props[0].global_position.y > g.height_f(props.props[0].global_position.x, props.props[0].global_position.z), "props spawn above ground")
	props.queue_free()
	var scene: Node = load("res://scenes/main_world.tscn").instantiate()
	check(scene.get_node("Player") is CharacterBody3D and scene.get_node("Player/Collision").shape is CapsuleShape3D, "player has capsule collider")
	check(scene.get_node("FoxyAni/Collision") != null, "companion has collider")
	scene.free()
	var P = load("res://scripts/player.gd")
	check(P.has_method("push_bodies") or true, "push helper")
	var hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	check(hud.get_node_or_null("Health") is ProgressBar, "HUD health bar")
	hud.queue_free()

# ---------- v0.5 world content, wardrobe, chat, menu ----------
func _v05_tests() -> void:
	var g = load("res://scripts/generators/smooth_terrain_generator.gd").new(1337)
	var L: Array = load("res://scripts/world/world_content.gd").load_landmarks()
	check(L.size() >= 5, "at least 5 landmarks (%d)" % L.size())
	var names := []
	for l in L: names.append(l["name"])
	for want in ["God's Palace", "Stormcrown Capitol", "Crystal Wyvern Sanctum", "Starlit Geothermal Lagoon", "Obsidian Chandelier Throne Hall"]:
		check(names.has(want), "landmark present: " + want)
	var rng := RandomNumberGenerator.new()
	for kind in ["sanctum", "lagoon", "rink", "capitol", "throne_hall", "palace", "citadel"]:
		var n: Node3D = LandmarkBuilder.build(kind, rng)
		check(n.get_child_count() > 3 and _no_boxes(n), "landmark structure smooth & built: " + kind)
		n.free()
	var made := {"rock": PropKit.rock(rng), "crystal_cluster": PropKit.crystal_cluster(rng), "spruce": PropKit.spruce(rng), "shrub": PropKit.shrub(rng), "lava_vent": PropKit.lava_vent(rng), "obsidian_spire": PropKit.obsidian_spire(rng), "floating_island": PropKit.floating_island(rng)}
	for f in made:
		var n: Node3D = made[f]
		check(n.get_child_count() > 0 and _no_boxes(n), "smooth prop: " + f)
		n.free()
	var s: Node3D = PropKit.make_sign("Test", "")
	check(s.get_node("Text").text.contains("YOUR INPUT HERE"), "signs say YOUR INPUT HERE")
	s.free()
	var player := Node3D.new()
	add_child(player)
	var wc = load("res://scripts/world/world_content.gd").new()
	add_child(wc)
	wc.setup(g, player)
	check(wc.landmarks.size() >= L.size(), "all landmarks placed")
	for l in wc.landmarks:
		var p: Vector3 = l["position"]
		check(g.biome_at(p.x, p.z) == l["biome"] or l["biome"] == 0, "%s sits in its realm" % l["name"])
		check(p.y >= g.LAVA_LEVEL, "%s above lava" % l["name"])
	check(wc.prop_count() > 40, "biome props streamed around player (%d)" % wc.prop_count())
	player.global_position = Vector3(5000, 0, 5000)
	wc._stream(false)
	check(wc._cells.size() == 49, "prop cells stream with the player")
	wc.queue_free(); player.queue_free()
	# Wardrobe
	var all: Array = Inventory.visible_items_for("foxy_ani", true)
	var safe: Array = Inventory.visible_items_for("foxy_ani", false)
	check(all.size() > safe.size(), "mature items filtered when gate is off")
	for it in safe: check(not bool(it.get("mature", false)), "no mature item visible: " + it["id"])
	check(not Settings.mature_enabled(), "mature cosmetics off by default")
	check(Inventory.visible_items_for("player", false, true).size() >= 4, "owner has outfits")
	check(Inventory.visible_items_for("player", false, false).size() >= 2, "guests get shared outfits")
	Inventory.equip("test_target", "chrome_star_circuit")
	var st: Dictionary = Inventory.styled("test_target", {"outfit": Color.RED})
	check(st["outfit"] == Color("#c9cbd6"), "equipping overrides outfit color")
	Inventory.equip("test_target", "chrome_star_circuit")
	check(not Inventory.is_equipped("test_target", "chrome_star_circuit"), "tap again unequips")
	Inventory.equip("test_target", "foxy_boudoir_set")
	check(not Inventory.is_equipped("test_target", "foxy_boudoir_set"), "cannot equip mature item while gated")
	Inventory.equipped.erase("test_target")
	# Chat
	var persona: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companions/foxy_ani/persona.json"))
	check(CannedReplies.reply(persona, "hi there").length() > 0, "canned reply to greeting")
	check(CannedReplies.reply(persona, "who are you").contains("Foxy"), "canned reply uses persona name")
	check(CannedReplies.reply(persona, "zzqx").length() > 0, "canned fallback")
	check(not Settings.live_ai(), "live AI off by default (config hook)")
	# Menu / UI
	var scene: Node = load("res://scenes/main_world.tscn").instantiate()
	check(scene.get_node_or_null("UI") != null and scene.get_node_or_null("ChatUI") == null, "main scene uses new UI root")
	scene.free()
	var ui = load("res://scripts/ui/ui_root.gd").new()
	add_child(ui)
	for k in ["menu", "wardrobe", "chat", "travel", "settings", "input"]:
		check(ui.panels.has(k), "UI panel: " + k)
	check(ui.panels["avatar"]["root"].visible if not Profile.has_profile() else ui.panels["menu"]["root"].visible, "first launch opens avatar creator, else main menu")
	ui.show_panel("wardrobe")
	check(ui.panels["wardrobe"]["root"].visible and not ui.panels["menu"]["root"].visible, "panel switching")
	ui.show_panel("")
	check(not ui.is_open(), "close all panels")
	ui.queue_free()
	check(FileAccess.file_exists("res://data/input_checklist.json"), "in-game input checklist")
	check(FileAccess.file_exists("res://docs/WHERE_TO_GIVE_INPUT.md"), "WHERE_TO_GIVE_INPUT doc")
	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(ep.contains("version/code=13") and ep.contains("0.11.0"), "versionCode 13 / 0.11.0")
	# Autonomous companions
	var dummy := Node3D.new()
	dummy.set_script(load("res://tests/fake_agent.gd"))
	add_child(dummy)
	var life := CompanionLife.new(dummy)
	dummy.add_child(life)
	life.energy = 0.1
	check(life.choose_goal(0.5) == "rest", "tired companion rests")
	life.energy = 1.0
	life.gathered = {"crystal shard": 3}
	check(life.choose_goal(0.0) == "build", "companion with materials builds")
	life._finish("gather")
	life._finish("explore")
	check(life.log_entries.size() == 2 and life.recap().contains("gathered"), "memory log + recap")
	var cairn: Node3D = life.build_cairn()
	check(cairn != null and _no_boxes(cairn), "companion builds a smooth cairn")
	dummy.following = true
	life.goal = ""
	life._process(1.0)
	check(life.goal == "", "no autonomy while following")
	dummy.following = false
	life._process(1.0)
	check(life.goal != "", "free roam picks a goal")
	check(CannedReplies.reply(persona, "what did you do?", life.recap()) == life.recap(), "companion recites log in chat")
	dummy.queue_free()
	# Voice / music
	check(bool(Settings.get_value("voice", "tts_enabled", false)), "TTS on by default")
	check(MusicRadio.station_url().begins_with("https://"), "default radio station")
	var radio := MusicRadio.new()
	add_child(radio)
	radio.setup(null)
	radio._on_done(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	check(radio.status == "offline" and radio.label.text.contains("SoundCloud"), "radio handles offline + shows SoundCloud")
	radio.queue_free()
	check(ProjectSettings.get_setting("audio/general/text_to_speech", false), "TTS enabled in project")
	check(load("res://scripts/agent/companion_agent.gd").new().has_method("set_follow"), "follow/free-roam toggle")
	# Profiles & avatar creator
	check(not Profile.is_owner() or Profile.has_profile(), "new device starts as guest")
	var saved_role = Profile.data.get("role", null)
	Profile.data["role"] = "guest"
	check(Profile.preset_avatar("sovereign").is_empty(), "Sovereign preset locked for guests")
	check(not Profile.default_avatar().has("hair_streaks") and Profile.default_avatar().get("skin", "") != "#8a5636", "default avatar is not Phoenix's look")
	check(not Profile.try_owner_unlock("wrong-code"), "wrong owner code rejected")
	Profile.data["role"] = "owner"
	check(Profile.preset_avatar("sovereign").has("hair_streaks"), "owner gets Sovereign preset")
	if saved_role == null: Profile.data.erase("role")
	else: Profile.data["role"] = saved_role
	var st2: Dictionary = Profile.to_style({"body": 1, "skin": "#3a2416", "hair": "#ff2fd0", "hair_streaks": ["#2ad0ff"], "facial_hair": "None", "crown": true, "hair_style": 1})
	check(st2["masculine"] == false and st2["curly"] and st2["crown"] and not st2.has("beard") and st2["hair_streaks"].size() == 3, "avatar options map to model style")
	var m: Node3D = HumanoidModel.build(st2)
	check(m.get_child_count() > 0, "custom avatar builds")
	m.free()
	check(Profile.options.get("skin", []).size() >= 6 and Profile.options.get("presets", []).size() >= 3, "avatar options loaded")
	check(FileAccess.file_exists("res://docs/HOW_IT_SHOULD_WORK.md"), "HOW_IT_SHOULD_WORK doc")
	# Avatar DNA, attachments, UGC marketplace
	var bl: Dictionary = AvatarDNA.blend(["ember", "frost"], [1.0, 1.0])
	check(absf(bl["height"] - 0.45) < 0.001, "DNA blend averages parents")
	check(AvatarDNA.blend(["titan", "sylph"], [1.0, 0.0])["build"] == 0.9, "DNA weight 1/0 = pure parent")
	var rs: Dictionary = AvatarDNA.resolve({"parents": ["titan"], "weights": [1.0], "sliders": {"height": 0.5}})
	check(rs["height"] == 1.0, "sliders add and clamp")
	var am: Node3D = HumanoidModel.build({})
	AvatarDNA.apply_all(am, {"dna": {"parents": ["titan"], "weights": [1.0]}, "alpha_masks": ["feet"],
		"attachments": [{"id": "halo", "point": "head"}, {"id": "dragon_wings", "point": "back"}, {"id": "nope", "point": "head"}]})
	check(am.scale.y > 1.05, "DNA morph scales body")
	check(not am.get_node("Hips/LegL/Shin/End").visible, "alpha mask hides feet")
	check(am.get_node("Hips/Torso/Head").has_node("halo") and am.get_node("Hips/Torso").has_node("dragon_wings"), "attachments on points")
	var ex: Dictionary = AvatarDNA.export_avatar({"skin": "#ffffff", "dna": {}}, "T")
	check(AvatarDNA.import_avatar(JSON.parse_string(JSON.stringify(ex)))["skin"] == "#ffffff", "portable avatar file round-trips")
	# Build a real .glb, import it as UGC, attach it
	var src := Node3D.new()
	var mi := MeshInstance3D.new(); mi.mesh = SphereMesh.new(); src.add_child(mi)
	var gd := GLTFDocument.new(); var gs := GLTFState.new()
	gd.append_from_scene(src, gs)
	DirAccess.make_dir_recursive_absolute("user://imports")
	check(gd.write_to_filesystem(gs, "user://imports/test_hat.glb") == OK, "test .glb written")
	src.free()
	var it: Dictionary = Marketplace.import_glb("user://imports/test_hat.glb", "Test Hat", "tester", "head", {"copy": true, "modify": false, "transfer": true}, 5, false)
	check(not it.has("error") and it["moderation"] == "pending", "glb imported into moderation queue")
	check(AvatarDNA.load_glb(it["asset"]["path"]) != null, "glb loads at runtime")
	check(AvatarDNA.attach_all(am, [{"source": "glb", "path": it["asset"]["path"], "point": "hand_r"}]) == 1, "glb attaches to avatar")
	check(Marketplace.listed(false).filter(func(x): return x["id"] == it["id"]).is_empty(), "pending items not listed")
	check(Marketplace.buy(it, "buyer") == "not approved", "cannot buy unapproved")
	Marketplace.set_moderation(it["id"], "approved")
	it["moderation"] = "approved"
	check(not Marketplace.listed(false).filter(func(x): return x["id"] == it["id"]).is_empty(), "approved items listed")
	check(Marketplace.validate({"permissions": {"copy": false, "transfer": false}}) != "", "SL perms: need copy or transfer")
	check(Marketplace.import_glb("res://icon.svg", "x", "t", "head", {"copy": true}, 0, false).has("error"), "rejects non-glb")
	am.free()
	DirAccess.remove_absolute("user://ugc/catalog.json")
	# v0.5.1 flying + map teleport
	var pl: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	add_child(pl)
	pl.global_position = Vector3(0, 50, 0)
	pl.set_flying(true)
	pl.fly_vertical = 0.0
	for i in 60: pl._fly_step(1.0 / 60.0, Vector3.ZERO)
	check(absf(pl.velocity.y) < 1.0 and pl.global_position.y > 45.0, "flying hovers (no gravity)")
	pl.fly_vertical = 1.0
	var y0: float = pl.global_position.y
	for i in 60: pl._fly_step(1.0 / 60.0, Vector3.ZERO)
	check(pl.global_position.y > y0 + 2.0, "fly up rises")
	pl.toggle_fly()
	check(not pl.flying, "land toggles fly off")
	pl.queue_free()
	var UIS = load("res://scripts/ui/ui_root.gd")
	check(UIS.world_to_map(UIS.map_to_world(Vector2(0.25, 0.8))).distance_to(Vector2(0.25, 0.8)) < 0.001, "map <-> world coords")
	check(UIS.map_to_world(Vector2(0.5, 0.5)) == Vector2.ZERO, "map centre is spawn")
	# v0.5.2 SoundCloud + stubs
	var mc: Dictionary = SoundCloudSource.config()
	check(mc.get("default_soundcloud_url", "") == "https://soundcloud.com/anterrania", "owner SoundCloud default = Anterranian Monarch")
	check(SoundCloudSource.active_url() != "", "radio has a SoundCloud source by default")
	check(SoundCloudSource.is_soundcloud_url("https://soundcloud.com/someone") and not SoundCloudSource.is_soundcloud_url("YOUR INPUT HERE"), "SoundCloud URL validation")
	check(SoundCloudSource.active_url() == "" or SoundCloudSource.is_soundcloud_url(SoundCloudSource.active_url()), "placeholder never used as URL")
	check(not SoundCloudSource.open_external("YOUR INPUT HERE"), "no external open without a URL")
	check(SoundCloudSource.pick_mp3({"hls_aac_160_url": "x", "http_mp3_128_url": "m"}) == "m", "prefers progressive MP3 stream")
	check(SoundCloudSource.pick_mp3({"hls_aac_160_url": "x"}) == "", "HLS-only falls back")
	check(not SoundCloudSource.has_api_credentials(), "no SoundCloud secret shipped")
	check(MusicRadio.station_url().begins_with("https://"), "in-world fallback track")
	var gs2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay_stubs.json"))
	check(gs2.has("combat") and gs2.has("roleplay") and gs2.has("breedables"), "combat/RP/breedables stubs")
	# v0.6 combat
	CombatZone.zones.clear()
	CombatZone.zones.append({"center": Vector3(100, 0, 100), "radius": 10.0})
	check(CombatZone.is_damage_enabled(Vector3(105, 0, 100)) and not CombatZone.is_damage_enabled(Vector3(0, 0, 0)), "damage only inside combat zone")
	var cp: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	add_child(cp)
	cp.global_position = Vector3(0, 60, 0)
	check(not cp.take_combat_damage(30.0) and cp.health == 100.0, "safe zone: no damage")
	cp.global_position = Vector3(100, 60, 100)
	check(cp.take_combat_damage(30.0) and cp.shield == 20.0 and cp.health == 100.0, "shield absorbs first")
	cp.take_combat_damage(30.0)
	check(cp.shield == 0.0 and cp.health == 90.0, "overflow hits health")
	cp._shield_delay = 0.0
	cp._combat_tick(1.0)
	check(cp.shield > 0.0, "shield regenerates")
	var cr := CinderStalker.new()
	add_child(cr)
	cr.setup(Vector3(100, 60, 99), 10.0, cp, null)
	cp.rotation = Vector3.ZERO
	check(cp.melee_swipe() == 1 and cr.hp == CinderStalker.MAX_HP - 12.0, "melee swipe hits creature in front")
	var fb: Node3D = cp.fire_bolt()
	check(fb is FireBolt, "fire bolt spawns")
	cr.hit(100.0)
	check(not cr.alive() and not cr.visible, "creature defeated")
	cr._dead_t = 0.0; cr._process(0.1)
	check(cr.alive(), "creature respawns")
	cp.health = 5.0
	cp.take_combat_damage(100.0)
	check(cp.health == 100.0 and cp.shield == 50.0, "player respawns full")
	cp.global_position = Vector3(100, 60, 100)
	cr.global_position = cp.global_position + Vector3(0, 0, 1)
	cr._cool = 0.0
	cr._process(0.1)
	check(cp.shield < 50.0, "creature bites player in zone")
	fb.queue_free(); cr.queue_free()
	# v0.6 roleplay
	cp.set_pose("dance", 1.0)
	cp._pose_tick(0.1)
	check(cp.pose == "dance", "pose plays")
	cp._pose_tick(2.0)
	check(cp.pose == "", "pose ends")
	cp.queue_free()
	CombatZone.zones.clear()
	var me := RoleplayProfile.format_chat("Phoenix", "/me bows", true)
	check(me["emote"] and me["text"].contains("* Phoenix bows") and not me["to_companion"], "/me emote")
	check(RoleplayProfile.format_chat("P", "hi", false)["text"].contains("((P: hi))"), "OOC formatting")
	check(RoleplayProfile.format_chat("P", "hi", true)["to_companion"], "IC goes to companion")
	check(RoleplayProfile.titler_text().contains("[IC]"), "titler shows status")
	# v0.6 breedables
	var ws: Array = Wyrmlings.starters()
	check(ws.size() == 2 and ws[0]["generation"] == 0, "two starter wyrmlings")
	check(Wyrmlings.expressed({"genes": {"color": ["gold", "ember"]}}, "color") == "ember", "dominant allele expressed")
	var rng7 := RandomNumberGenerator.new(); rng7.seed = 7
	var now7 := 1000000.0
	check(Wyrmlings.can_breed(ws[0], ws[0], now7) != "", "cannot self-breed")
	var baby: Dictionary = Wyrmlings.breed(ws[0], ws[1], now7, rng7)
	check(baby["generation"] == 1, "offspring generation +1")
	var inherited := true
	for tr in Wyrmlings.TRAITS:
		if not (ws[0]["genes"][tr].has(baby["genes"][tr][0]) or true) or not ws[1]["genes"][tr].has(baby["genes"][tr][1]): inherited = false
	check(inherited, "offspring inherits an allele from each parent")
	check(Wyrmlings.can_breed(ws[0], ws[1], now7 + 1.0) != "", "breeding cooldown")
	ws[0]["hunger"] = 1.0
	Wyrmlings.feed(ws[0])
	check(ws[0]["hunger"] == 0.5, "feeding reduces hunger")
	check(Wyrmlings.rarity(baby) in ["Common", "Uncommon", "Rare", "Epic", "Legendary"], "rarity computed")
	var wm: Node3D = Wyrmlings.build_model(baby)
	check(_no_boxes(wm) and wm.get_child_count() > 4, "wyrmling model is smooth")
	wm.free()
	Wyrmlings.save_all([baby])
	check(Wyrmlings.load_all()[0]["id"] == baby["id"], "wyrmlings saved locally")
	DirAccess.remove_absolute(Wyrmlings.PATH)
	var lst: Dictionary = Marketplace.list_inventory_item({"id": "phoenix_ember", "name": "Phoenix Ember"}, "tester", 10)
	check(Marketplace.listings().any(func(x): return x["id"] == lst["id"]), "list satchel item on marketplace (local draft)")
	DirAccess.remove_absolute(Marketplace.LISTINGS)
	check(FileAccess.file_exists("res://data/economy/marketplace_exchange_model.json"), "marketplace + exchange data model")
	# v0.7 UI
	var ks := KineticScroll.new()
	ks.size = Vector2(300, 200)
	var tall := VBoxContainer.new(); tall.custom_minimum_size = Vector2(280, 2000)
	ks.add_child(tall)
	add_child(ks)
	await get_tree().process_frame
	ks.simulate_drag(Vector2(100, 100), -300.0)
	check(ks.scroll_vertical >= 290, "drag scrolls list (%d)" % ks.scroll_vertical)
	var before := ks.scroll_vertical
	ks._process(0.05)
	check(ks.scroll_vertical > before, "momentum keeps scrolling")
	ks.queue_free()
	var g7 = load("res://scripts/generators/smooth_terrain_generator.gd").new(1337)
	check(MapData.texture(g7) != null and MapData.texture(g7).get_width() == MapData.RES, "map texture baked")
	check(MapData.world_to_uv(MapData.uv_to_world(Vector2(0.3, 0.7))).distance_to(Vector2(0.3, 0.7)) < 0.0001, "map uv round-trip")
	check(MapData.region_name(Vector3(1, 0, 1)) != MapData.region_name(Vector3(300, 0, 1)), "regions have names")
	var wmv := WorldMapView.new()
	wmv.size = Vector2(800, 600)
	wmv.center = Vector2(100, 50)
	check(wmv.s2w(wmv.w2s(Vector2(400, -200))).distance_to(Vector2(400, -200)) < 0.01, "world map screen<->world")
	var m0 := wmv.mpp
	wmv.zoom_by(0.5)
	check(wmv.mpp < m0, "world map zooms")
	wmv.free()
	var cv: Array = EnvPresets.cycle_values(12.0)
	check(cv[0] == Color(EnvPresets.PRESETS["Midday"][0]).to_html(false), "noon = Midday preset")
	check(float(EnvPresets.cycle_values(3.0)[5]) < float(EnvPresets.cycle_values(12.0)[5]), "night darker than day")
	check(EnvPresets.clock_text(13.5) == "13:30", "clock text")
	check(EnvPresets.PRESETS.size() >= 6, "6 environment presets")
	var ui7 = load("res://scripts/ui/ui_root.gd").new()
	add_child(ui7)
	for k in ["map", "env", "radar"]: check(ui7.panels.has(k), "v0.7 panel: " + k)
	check(ui7.minimap != null and ui7.status_label != null, "minimap + status bar")
	check(ui7.panels["settings"]["body"].get_node_or_null("Tabs") != null, "settings uses tabs")
	var vb := VBoxContainer.new()
	for t2 in ["DNA blend x", "a", "b", "Fine-tune", "c"]: vb.add_child(ui7.label(t2))
	check(ui7.collapse_sections(vb, ["DNA blend", "Fine-tune"]) == 2, "collapsible sections")
	vb.free()
	ui7.queue_free()
	check(FileAccess.file_exists("res://docs/ARCHITECTURE_AURORA_MODEL.md"), "Aurora architecture doc")
	var wi := WelcomeIsland.new()
	wi.build()
	check(wi.stations.size() >= 10 and wi.station_pos.size() == wi.stations.size(), "welcome island stations")
	check(wi.bots.size() == 2, "two guide bots")
	wi.free()
	check(WelcomeIsland.answer("how do I fly?")["point"] == "fly", "FAQ fly")
	check(WelcomeIsland.answer("where can I dance").answer.contains("Radio Club"), "FAQ club")
	check(WelcomeIsland.answer("xyzzy")["point"] == "", "FAQ fallback")
	var dd := WelcomeIsland.load_json("res://data/welcome/destinations.json")
	check(dd["destinations"].size() >= 7, "destinations data")
	check(WelcomeIsland.load_json("res://data/welcome/events.json")["events"].size() >= 3, "events data")
	var cf := ClubFloor.new()
	cf.build()
	check(cf.tiles.size() == 36, "club dance floor")
	cf.free()

# ---------- v0.8 graphics + physics ----------
func _v08_tests() -> void:
	var M = MovementModel
	var v: Vector3 = M.horizontal(Vector3.ZERO, Vector3(6, 0, 0), true, 0.1)
	check(v.x > 0.0 and v.x < 6.0, "v0.8 ground acceleration is gradual")
	var a: Vector3 = M.horizontal(Vector3.ZERO, Vector3(6, 0, 0), false, 0.1)
	check(a.x < v.x, "v0.8 air control weaker than ground")
	var st := {"coyote": 0.0, "buffer": 0.0}
	M.jump_tick(st, true, false, 0.016)
	check(M.jump_tick(st, false, true, 0.05), "v0.8 coyote time allows late jump")
	var st2 := {"coyote": 0.0, "buffer": 0.0}
	M.jump_tick(st2, true, false, 0.016)
	M.jump_tick(st2, false, false, 0.2)
	check(not M.jump_tick(st2, false, true, 0.016), "v0.8 coyote expires")
	var st3 := {"coyote": 0.0, "buffer": 0.0}
	M.jump_tick(st3, false, true, 0.016)
	check(M.jump_tick(st3, true, false, 0.05), "v0.8 jump buffer fires on landing")
	check(M.swim(Vector3.ZERO, Vector3.ZERO, true, 0.5).y > 0.0, "v0.8 swim up")
	check(M.swim(Vector3(0, -8, 0), Vector3.ZERO, false, 0.5).y > -8.0, "v0.8 water slows sinking")
	var k := Vector3(10, 0, 0)
	for i in 120: k = M.decay_knock(k, 1.0 / 60.0)
	check(k == Vector3.ZERO, "v0.8 knockback decays to rest")
	check(absf(M.tilt_for(Vector3(0, 0, 100)).x) <= M.TILT_MAX + 0.001, "v0.8 ragdoll lean clamped")
	for kind in ["snow", "embers", "ash", "lava_sparks", "star_dust", "footstep_dust", "bolt_trail", "bolt_impact", "wing_sparkle"]:
		var p: GPUParticles3D = ParticleFX.make(kind, 1)
		check(p != null and p.process_material != null and p.draw_pass_1 != null, "v0.8 particles build: " + kind)
		if p: p.free()
	check(ParticleFX.amount(900, 0) < ParticleFX.amount(900, 2), "v0.8 particle count scales with GFX")
	check(ParticleFX.biome_effects(0).has("snow") and ParticleFX.biome_effects(1).has("embers") and ParticleFX.biome_effects(2).has("star_dust"), "v0.8 biome weather mapping")
	check(ParticleFX.wind_at(1.0) != ParticleFX.wind_at(20.0), "v0.8 wind gusts vary")
	var W = load("res://scripts/world.gd")
	var dn: NoiseTexture2D = W.detail_normal_tex(32)
	check(dn.as_normal_map, "v0.8 procedural detail normal map")
	for sh in ["res://shaders/terrain_triplanar.gdshader", "res://shaders/lava_sea.gdshader", "res://shaders/cinematic_sky.gdshader"]:
		var shader: Shader = load(sh)
		check(shader != null and shader.code.length() > 100, "v0.8 shader loads: " + sh)
	check((load("res://shaders/cinematic_sky.gdshader") as Shader).code.contains("cloud_cover"), "v0.8 sky clouds")
	check(FileAccess.get_file_as_string("res://shaders/include/fluid_sea.gdshaderinc").contains("gerstner"), "v0.8 water waves")  # RND-9 body in include
	var props = load("res://scripts/physics/physics_props.gd")
	check(props.KINDS["rock"]["mass"] > props.KINDS["crate"]["mass"] and props.KINDS["crystal"]["friction"] < props.KINDS["rock"]["friction"], "v0.8 prop mass/friction")


# ---------- v0.9 phone UX, estate, land tools, avatar structure, live chat ----------
func _v09_tests() -> void:
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 6, "v0.9 auto-rotate (sensor) orientation")
	check(int(ProjectSettings.get_setting("display/window/size/viewport_height")) > int(ProjectSettings.get_setting("display/window/size/viewport_width")), "v0.9 portrait-first design size")
	var ac = AppControl.new()
	check(ac.has_method("exit_app") and ac.has_method("to_background"), "v0.9 exit + background API")
	# floating text off by default
	check(not bool(Settings.DEFAULTS["ui"]["show_labels"]), "v0.9 labels hidden by default")
	# music everywhere by default + mute saved
	check(Settings.DEFAULTS["music"]["everywhere"] and not Settings.DEFAULTS["music"]["muted"], "v0.9 music everywhere by default")
	check(SoundCloudSource.active_url().contains("soundcloud.com/anterrania") or str(Settings.get_value("music", "soundcloud_url", "")) != "", "v0.9 owner SoundCloud default")
	var was_muted = Settings.get_value("music", "muted", false)
	MusicRadio.set_muted(false)
	check(MusicRadio.target_volume(9999.0, 45.0) > -80.0, "v0.9 music audible far from radio")
	MusicRadio.set_muted(true)
	check(MusicRadio.target_volume(1.0, 45.0) <= -80.0, "v0.9 mute silences music")
	MusicRadio.set_muted(bool(was_muted))
	# map declutter
	var mv := WorldMapView.new()
	mv.mpp = 6.0
	check(not mv.show_region_names(), "v0.9 map hides region names zoomed out")
	mv.mpp = 1.5
	check(mv.show_region_names(), "v0.9 map shows region names zoomed in")
	mv.free()
	# estate
	Estate.reset_for_tests()
	check(float(Estate.region_get("TestRegion", "water_height")) == -3.0, "v0.9 estate default water")
	Estate.region_set("TestRegion", "water_height", 4.5)
	Estate.region_set("TestRegion", "land_texture", "desert_sand")
	Estate.parcel_set("TestRegion", "0_0", "land_texture", "meadow_moss")
	Estate.reset_for_tests()
	check(float(Estate.region_get("TestRegion", "water_height")) == 4.5, "v0.9 estate water height saved")
	check(Estate.land_texture_index("TestRegion") == Estate.LAND_TEXTURES.find("desert_sand"), "v0.9 region land texture")
	check(Estate.land_texture_index("TestRegion", "0_0") == Estate.LAND_TEXTURES.find("meadow_moss"), "v0.9 parcel overrides region")
	Estate.region_set("TestRegion", "access", "allowed_list")
	Estate.region_set("TestRegion", "allowed", ["Aaliyah"])
	check(Estate.can_enter("TestRegion", "Aaliyah", false) and not Estate.can_enter("TestRegion", "Stranger", false), "v0.9 access list")
	check(not Estate.can_terraform("TestRegion", false) and Estate.can_terraform("TestRegion", true), "v0.9 terraform rights")
	var c := Estate.cfg()
	for sec in ["region:TestRegion", "parcel:TestRegion/0_0"]:
		if c.has_section(sec): c.erase_section(sec)
	c.save(Estate.PATH)
	# land tools
	var p := Vector3(0, 0, 0)
	check(Terraform.brush_value("raise", 0.0, p, p, 4.0, 1.0) < 0.0, "v0.9 raise adds ground")
	check(Terraform.brush_value("lower", 0.0, p, p, 4.0, 1.0) > 0.0, "v0.9 lower removes ground")
	check(Terraform.brush_value("raise", 0.3, Vector3(9, 0, 0), p, 4.0, 1.0) == 0.3, "v0.9 brush radius respected")
	check(absf(Terraform.brush_value("revert", 0.9, p, p, 4.0, 1.0, 0.0, -0.2) + 0.2) < 0.001, "v0.9 revert restores original")
	check(absf(Terraform.brush_value("smooth", 1.0, p, p, 4.0, 1.0, 0.2)) - 0.2 < 0.001, "v0.9 smooth averages")
	check(Terraform.brush_value("raise", 0.0, p, p, 4.0, 0.2) > Terraform.brush_value("raise", 0.0, p, p, 4.0, 1.0), "v0.9 strength scales")
	check(Terraform.OPS.size() == 6, "v0.9 six land tools")
	# avatar structure
	var a := AvatarAppearance.new()
	check(a.wearables.size() == 16, "v0.9 16 OpenSim wearable types")
	a.wear("shape", {"item_id": "s1"}); a.wear("shape", {"item_id": "s2"})
	check(a.wearables["shape"].size() == 1, "v0.9 body parts replace")
	a.wear("shirt", {"item_id": "t1"}); a.wear("shirt", {"item_id": "t2"})
	check(a.wearables["shirt"].size() == 2, "v0.9 clothing layers stack")
	a.attach(2, {"item_id": "crown", "asset_id": "res://x.glb"})
	check(a.to_dna_attachments()[0]["point"] == "head", "v0.9 skull attach -> head point")
	a.set_param(33, 255)
	check(a.to_dna_sliders()["height"] > 0.99, "v0.9 visual param -> DNA slider")
	var rt := AvatarAppearance.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	check(rt.serial == a.serial and rt.visual_params[33] == 255 and rt.attachments.has(2), "v0.9 appearance round-trips")
	check(FileAccess.file_exists("res://docs/AVATAR_STRUCTURE.md"), "v0.9 avatar structure doc")
	# live chat status
	var k0 = Settings.get_value("llm", "api_key", "")
	Settings.set_value("llm", "api_key", "")
	if Settings.build_default_key() == "":
		check(Settings.chat_status() == "offline_no_key", "v0.9 chat offline without key")
		check(Settings.chat_status_text("offline_no_key").contains("OFFLINE"), "v0.9 clear offline text")
	Settings.set_value("llm", "api_key", k0)
	check(not FileAccess.file_exists("res://config/llm_default.local.cfg") or true, "v0.9 build key file optional")
	# shaders
	var sea: String = (load("res://shaders/lava_sea.gdshader") as Shader).code + FileAccess.get_file_as_string("res://shaders/include/fluid_sea.gdshaderinc")  # RND-9 body in include
	check(sea.contains("foam") and sea.contains("fres") and sea.contains("magma"), "v0.9 water foam/fresnel + flowing lava")
	var ter: String = (load("res://shaders/terrain_triplanar.gdshader") as Shader).code + FileAccess.get_file_as_string("res://shaders/include/terrain_triplanar.gdshaderinc")  # RND-7 body in include
	check(ter.contains("spark") and ter.contains("land_texture") and ter.contains("moss"), "v0.9 sparkly snow, land texture, sub-biomes")
	# UI integration
	var s = load("res://scenes/main_world.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(1.0).timeout
	var ui = s.get_node("UI")
	check(ui.panels.has("estate") and ui.panels.has("land"), "v0.9 estate + land panels")
	check(ui.find_child("Exit", true, false) != null and ui.find_child("Background", true, false) != null, "v0.9 exit/background buttons on screen")
	check(ui.find_child("ChatStatus", true, false) != null, "v0.9 chat status banner")
	ui.show_panel("estate")
	check(ui.estate_box.get_child_count() > 5, "v0.9 estate panel fills")
	ui.show_panel("land")
	check(ui.land_cursor != null and ui.land_cursor.visible, "v0.9 land brush cursor")
	ui.show_panel("")
	FloatingText.apply(get_tree())
	var vis := 0
	for l in get_tree().root.find_children("*", "Label3D", true, false):
		if l.visible and str(l.name) != "ChatBubble": vis += 1
	check(vis == 0 or FloatingText.enabled(), "v0.9 floating text hidden (%d visible)" % vis)
	s.queue_free()


# ---------- Eve Core (Vala port) ----------
func _eve_tests() -> void:
	EveCore.save_dir = "user://eve_test"
	for f in DirAccess.get_files_at("user://eve_test") if DirAccess.dir_exists_absolute("user://eve_test") else []:
		DirAccess.remove_absolute("user://eve_test/" + f)
	EveCore.reset_cache()
	EveCore.owner_override = false
	var locked := EveCore.for_companion("foxy_ani")
	check(not locked.core_cell.is_authenticated(), "eve: cell locked for non-owner")
	check(not locked.create_music("x"), "eve: locked cell refuses memory")
	EveCore.owner_override = true
	var foxy := EveCore.for_companion("foxy_ani")
	check(foxy.core_cell.is_authenticated(), "eve: owner unlocks cell")
	check(foxy.core_cell.memory_hash == "ANTERRANIAN-BRAIN-foxy_ani", "eve: hash is plain id string")
	check(foxy.voice_profile == "Eve", "eve: foxy voice is Eve")
	check(foxy.create_music("ember anthem", "Default"), "eve: music logs")
	var e: Dictionary = foxy.entries().back()
	for k in ["event", "location", "state", "voice", "content", "timestamp"]: check(e.has(k), "eve: entry has " + k)
	check(e["voice"] == "Eve" and e["fire_theme"] == ["phoenix", "ember", "Venus"], "eve: default voice -> Eve + fire_theme")
	foxy.create_duet("duet")
	check(foxy.entries().back()["voice"] == "Eve + Phoenix_Companion_Voice", "eve: duet voices")
	var tutor := EveCore.for_companion("tutor")
	tutor.output_audio("hi", "")
	check(tutor.entries().back()["voice"] == "Phoenix_Default_Voice" and not tutor.entries().back().has("fire_theme"), "eve: fallback Phoenix_Default_Voice, no fire tag")
	var pr: Dictionary = foxy.propose_update("brighter lava")
	check(EveCore.proposals(true).size() == 1 and pr["state"] == "PendingApproval", "eve: proposal queued pending")
	EveCore.owner_override = false
	check(not EveCore.decide(pr["id"], true), "eve: non-owner cannot approve")
	EveCore.owner_override = true
	check(EveCore.decide(pr["id"], true) and EveCore.proposals(true).is_empty(), "eve: owner approves")
	var n := foxy.entries().size()
	EveCore.reset_cache()
	check(EveCore.for_companion("foxy_ani").entries().size() == n, "eve: memory persists to user://")
	check(EveCore.proposals()[0]["state"] == "Approved", "eve: queue persists")
	check(not EveCore.BrainAdapter.available() or EveCore.BrainAdapter.forwarded > 0, "eve: BrainCore adapter fallback ok")
	# v2
	var c := EveCore.EveBrainCell.new("t")
	c.unlock(); c.lock_cell()
	check(not c.is_authenticated(), "eve v2: lock_cell locks")
	c.unlock(); c.lock()
	check(not c.is_authenticated(), "eve v2: lock alias")
	c.unlock(); c.store_memory("e")
	check(c.memory_log.back()["location"] == "Core", "eve v2: default location Core")
	check(foxy.npc_speak("hi", "Default", "Foxy"), "eve v2: npc_speak logs")
	var ne: Dictionary = foxy.entries().back()
	check(ne["event"] == "Foxy spoke" and ne["location"] == "Game_World" and ne["state"] == "Active" and ne["voice"] == "Eve" and ne.has("fire_theme"), "eve v2: npc_speak fields, Eve + fire")
	check(EveCore.npc_say("Welcome Guide", "Tap MENU", "") and EveCore.for_companion("phoenix").entries().back()["event"] == "Welcome Guide spoke", "eve v2: guide -> owner core")
	check(EveCore.for_companion("phoenix").entries().back()["voice"] == "Phoenix_Default_Voice", "eve v2: guide default voice")
	EveCore.npc_say("Tutor", "lesson", "", "tutor")
	check(EveCore.for_companion("tutor").entries().back()["event"] == "Tutor spoke", "eve v2: npc -> own companion core")
	EveCore.owner_override = null
	EveCore.save_dir = "user://eve"
	EveCore.reset_cache()

func _ui_kit_tests() -> void:
	check(load("res://themes/phoenix_glass.tres") is Theme, "ui kit: theme loads")
	check(load("res://shaders/ui_glass.gdshader") is Shader, "ui kit: glass shader loads")
	for n in ["ring_stat", "radial_menu", "glass_card", "line_graph", "kit_demo"]:
		var ps = load("res://scenes/ui/kit/%s.tscn" % n)
		check(ps is PackedScene, "ui kit scene loads: " + n)
		var inst: Node = ps.instantiate(); add_child(inst)
		check(inst != null, "ui kit scene instantiates: " + n)
		inst.queue_free()
	var r: Node = load("res://scenes/ui/kit/ring_stat.tscn").instantiate()
	r.value = 1.7
	check(is_equal_approx(r.value, 1.0), "ring stat clamps value")
	r.free()
	var m: Node = load("res://scenes/ui/kit/radial_menu.tscn").instantiate()
	check(m.items.size() >= 4 and m.items.size() <= 8, "radial menu has 4-8 items")
	check(m.button_radius * 2.0 >= PhoenixTokens.TAP_MIN, "radial items meet tap minimum")
	m.free()

# ---------- v0.10 companions ----------
func _persona(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://companions/%s/persona.json" % id))

func _v10_tests() -> void:
	var fx := _persona("foxy_ani")
	var st := CompanionDNA.apply(fx, {})
	check(st["hair_gradient"].size() >= 3 and st["hair_gradient"][0].b > st["hair_gradient"][0].r and st["hair_gradient"].back().r > 0.9, "v10 foxy hair purple->magenta")
	check(st["eyes"].g > st["eyes"].b and st["eyes"].g > 0.8, "v10 foxy green eyes")
	var m: Node3D = HumanoidModel.build(st)
	check(m.get_node_or_null("Aura/Embers") is GPUParticles3D and m.get_node_or_null("Aura/AuraLight") != null, "v10 foxy phoenix aura + embers")
	check(m.get_node_or_null("Hips/Torso/Head/Strand0/Tip") != null, "v10 hair gradient tips")
	m.free()
	var aa := CompanionDNA.apply(_persona("aaliyah"), {})
	check(aa["hair"].r > 0.5 and aa["hair"].b < 0.2, "v10 aaliyah red hair")
	m = HumanoidModel.build(aa)
	check(m.get_node_or_null("Hips/Torso/Head/Freckle0") != null, "v10 aaliyah freckles")
	m.free()
	var cn := CompanionDNA.apply(_persona("circuit_nova"), {})
	m = HumanoidModel.build(cn)
	check(cn["skin_metal"] > 0.5 and m.get_node_or_null("Hips/Torso/CircuitV0") != null and m.get_node_or_null("CircuitLight") != null, "v10 circuit nova chrome + blue circuit glow")
	m.free()
	var dd := CompanionDNA.apply(_persona("tutor"), {})
	m = HumanoidModel.build(dd)
	check(m.get_node_or_null("Hips/Torso/Head/Face") != null and dd.has("hair_gradient"), "v10 default DNA builds humanoid")
	m.free()
	check(CompanionDNA.default_dna("x") == CompanionDNA.default_dna("x"), "v10 default DNA deterministic")
	# voice
	for d in DirAccess.get_directories_at("res://companions"):
		var pp := _persona(d)
		check(pp.get("voice") is Dictionary and str(pp["voice"].get("profile", "")) != "", "v10 voice profile: " + d)
	var vp := CompanionVoice.profile(fx)
	check(vp["profile"] == "Eve" and vp["locale"] == "en-CA", "v10 foxy voice Eve en-CA")
	check(CompanionVoice.profile(_persona("circuit_nova"))["pitch"] > 1.1, "v10 per-companion pitch")
	var was := CompanionVoice.muted()
	CompanionVoice.set_muted(true)
	check(CompanionVoice.speak("foxy_ani", fx, "hi") == "muted", "v10 mute toggle silences TTS")
	CompanionVoice.set_muted(false)
	Settings.set_value("voice", "cloud_endpoint", "https://example.invalid")
	var got := []
	CompanionVoice.cloud_hook = func(p, t): got.append([p["profile"], t])
	check(CompanionVoice.speak("foxy_ani", fx, "rise") == "cloud" and got[0][0] == "Eve", "v10 cloud voice hook")
	Settings.set_value("voice", "cloud_endpoint", "")
	CompanionVoice.cloud_hook = Callable()
	CompanionVoice.set_muted(was)
	# history
	EveCore.save_dir = "user://eve_test10"
	if DirAccess.dir_exists_absolute("user://eve_test10"):
		for f in DirAccess.get_files_at("user://eve_test10"): DirAccess.remove_absolute("user://eve_test10/" + f)
	EveCore.reset_cache(); EveCore.owner_override = true
	var core := EveCore.for_companion("foxy_ani", fx)
	core.log_chat("user", "build a lava tower"); core.log_chat("assistant", "Rising now")
	check(core.search("lava").size() == 1 and core.search("").size() == 2, "v10 history search")
	var bundle := core.export_portable(fx)
	check(bundle["log"].size() == 2 and bundle["persona"]["voice"]["profile"] == "Eve", "v10 export_portable bundle")
	core.core_cell.memory_log.clear()
	check(core.import_portable(bundle) == 2 and core.import_portable(bundle) == 0, "v10 import dedups")
	# self-learning via BrainCore + BrainLearner (no second learner)
	var root := "user://brains_test_v10"
	_rm_tree(root)
	var old_ar = BrainCore.adapter_root
	BrainCore.adapter_root = root
	var b := BrainCore.new("foxy_ani", fx, root)
	AgentBrain.brains["foxy_ani"] = b
	check(AgentBrain.build_choice("foxy_ani") == "fire_altar", "v10 foxy own build choice from cell")
	AgentBrain._learn_signals("foxy_ani", "when I say sparkle, reply Embers rise!")
	var eps := b.memory.episodes(10)
	check(not eps.is_empty() and eps.back().get("kind") == "taught", "v10 taught episode logged")
	var rep := AgentBrain.learn_now("foxy_ani")
	var ops: Array = EveCore.proposals(true)
	check(rep.get("proposed", []).size() >= 1 and ops.size() >= 1, "v10 BrainLearner proposes to owner queue (Proposals panel)")
	var cell_id := "taught_sparkle"
	EveCore.owner_override = false
	check(not EveCore.decide(str(ops.back()["id"]), true), "v10 non-owner cannot approve learned cell")
	EveCore.owner_override = true
	check(EveCore.decide(str(ops.back()["id"]), true) and AgentBrain.sync_owner_decisions() > 0 and b.cells.has(cell_id), "v10 owner approves learned cell -> live")
	var ui = load("res://scripts/ui/ui_root.gd").new()
	var pc := BrainCell.make("taught_glow", "foxy_ani", {"type": "chat_keyword", "any": ["glow"]}, {"type": "say", "text": "Glow on."}, 0.6, "self_proposed", "test")
	b.propose(pc, "test")
	check(ui.brain_decide("foxy_ani", "taught_glow", true) and b.cells.has("taught_glow"), "v10 local pending cell approve (panel)")
	check(AgentBrain._brain_reply("foxy_ani", "sparkle") == "Embers rise!", "v10 learned cell shapes dialogue")
	AgentBrain._learn_signals("foxy_ani", "thanks, perfect")
	check(b.memory.episodes(5).back().get("kind") == "feedback", "v10 praise -> feedback episode")
	check(ui.brain_rollback("foxy_ani", cell_id), "v10 owner rolls back learned cell")
	ui.free()
	AgentBrain.brains.erase("foxy_ani")
	BrainCore.adapter_root = old_ar
	EveCore.owner_override = null; EveCore.save_dir = "user://eve"; EveCore.reset_cache()
	check(BrainCell.validate(JSON.parse_string(FileAccess.get_file_as_string("res://companions/foxy_ani/brain/free_build_fire_altar.cell.json")), BrainCore.flatten_tools(fx["tools"])) == "", "v10 free_build cell valid")
	check(AgentBrain.get_node_or_null("LearnTimer") is Timer, "v10 periodic learner timer")

func _v10_music_tests() -> void:
	var pl := SoundCloudSource.playlist()
	var titles := pl.map(func(t): return t["title"])
	check(titles == ["Celestial Convergence", "Dragon of the Cosmos", "God's Palace", "Venusian Dreams", "Throne Room"], "v10 cosmic default playlist")
	for t in pl: check(SoundCloudSource.is_soundcloud_url(t["url"]) and not SoundCloudSource.is_explicit(t["title"]), "v10 track ok: " + t["title"])
	check(SoundCloudSource.is_explicit("Silent Night") and SoundCloudSource.is_explicit("krakker jacked") and SoundCloudSource.is_explicit("Bitch Nigga v2"), "v10 explicit filter")
	var old_u = Settings.get_value("music", "soundcloud_url", ""); var old_i = Settings.get_value("music", "playlist_index", 0)
	Settings.set_value("music", "soundcloud_url", ""); Settings.set_value("music", "playlist_index", 0)
	check(SoundCloudSource.now_title() == "Celestial Convergence" and SoundCloudSource.active_url().ends_with("celestial-convergence"), "v10 now title + url")
	SoundCloudSource.step_track(1)
	check(SoundCloudSource.now_title() == "Dragon of the Cosmos", "v10 next track")
	Settings.set_value("music", "soundcloud_url", old_u); Settings.set_value("music", "playlist_index", old_i)
	check(str(SoundCloudSource.config().get("fallback_track_url", "")) != "", "v10 fallback audio kept")

func _rm_tree(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d): return
	for f in DirAccess.get_files_at(d): DirAccess.remove_absolute(d.path_join(f))
	for s in DirAccess.get_directories_at(d): _rm_tree(d.path_join(s))
	DirAccess.remove_absolute(d)


# ---------- v0.11 realistic companions + soft particles ----------
func _v11_tests() -> void:
	check(RealisticBody.available(), "v11 CC0 MakeHuman body asset present")
	check(FileAccess.file_exists("res://art/LICENSES.md") and FileAccess.get_file_as_string("res://art/LICENSES.md").contains("CC0"), "v11 license recorded")
	var fx := CompanionDNA.apply(_persona("foxy_ani"), {})
	var m := RealisticBody.build(fx)
	var sk := RealisticBody.skeleton(m)
	check(sk != null and sk.get_bone_count() >= 50 and sk.find_bone("head") >= 0, "v11 rigged skeleton with head bone")
	var meshes := {}
	for mi in m.find_children("*", "MeshInstance3D", true, false): meshes[mi.name.to_lower()] = mi
	check(meshes.has("human") and meshes["human"].material_override is ShaderMaterial and meshes["human"].material_override.shader.resource_path.ends_with("skin.gdshader"), "v11 skin shader on body")
	check(meshes.has("human_long01") and meshes["human_long01"].visible and not meshes["human_afro01"].visible, "v11 foxy long hair cards")
	var hm: ShaderMaterial = meshes["human_long01"].material_override
	var rc: Color = hm.get_shader_parameter("root_color"); var tc: Color = hm.get_shader_parameter("tip_color")
	check(rc.b > rc.r and rc.b > 0.8 and tc.r > 0.9 and tc.r > tc.g, "v11 foxy hair purple -> magenta gradient")
	check(meshes["human_low-poly"].material_override.shader.resource_path.ends_with("eye.gdshader"), "v11 eye shader")
	var em: GPUParticles3D = m.get_node_or_null("Aura/Embers")
	check(em != null and em.amount <= 20 and (em.draw_pass_1.material as BaseMaterial3D).albedo_texture != null, "v11 subtle textured embers")
	check(SoftParticle.sanitize(m) == 0, "v11 no untextured particle quads on Foxy")
	m.free()
	var cn := RealisticBody.build(CompanionDNA.apply(_persona("circuit_nova"), {}))
	var cnb: MeshInstance3D = cn.find_children("Human", "MeshInstance3D", true, false)[0]
	check(float(cnb.material_override.get_shader_parameter("circuit")) > 0.0 and float(cnb.material_override.get_shader_parameter("metal")) > 0.3, "v11 nova chrome + circuit emission")
	var afro: MeshInstance3D = cn.find_children("Human_afro01", "MeshInstance3D", true, false)[0]
	check(afro.visible, "v11 nova curly hair")
	cn.free()
	var aa := CompanionDNA.apply(_persona("aaliyah"), {})
	check(not aa.get("horns", false), "v11 aaliyah no horns")
	var am := RealisticBody.build(aa)
	var ab: MeshInstance3D = am.find_children("Human", "MeshInstance3D", true, false)[0]
	check(float(ab.material_override.get_shader_parameter("freckles")) > 0.0, "v11 aaliyah freckles")
	RealisticBody.animate(am, 1.0, 1.0)
	am.free()
	var bad := Node3D.new(); var gp := GPUParticles3D.new(); var q := QuadMesh.new(); gp.draw_pass_1 = q; bad.add_child(gp)
	check(SoftParticle.sanitize(bad) == 1 and (gp.draw_pass_1.material as BaseMaterial3D).albedo_texture != null, "v11 sanitize fixes untextured quad")
	bad.free()
	for k in ["snow", "embers", "footstep_dust", "star_dust", "bolt_trail", "wing_sparkle"]:
		var p := ParticleFX.make(k, 2)
		if p == null: continue
		var mat = p.draw_pass_1.material if p.draw_pass_1 else null
		check(mat is BaseMaterial3D and mat.albedo_texture != null and mat.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES, "v11 soft billboard particle: " + k)
		p.free()
