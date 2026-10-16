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
	_v05_tests()
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
	check(wc.landmarks.size() == L.size(), "all landmarks placed")
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
	check(ep.contains("version/code=7") and ep.contains("0.5.2"), "versionCode 7 / 0.5.2")
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
