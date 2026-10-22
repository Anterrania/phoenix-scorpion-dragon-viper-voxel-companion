extends RefCounted
## RND render pipeline tests (docs/modules/RENDERING.md): tier table, AutoQuality knob
## registration (fake AutoQuality), legacy fallback, governor, particle budget, greedy mesher,
## foliage scatter, generator band-fill parity, shader variants, docs/tracker/wiki.

## Stand-in for Foxy's AutoQuality autoload (scripts/render/auto_quality.gd), same API.
class FakeAQ extends Node:
	signal tier_changed(tier)
	var knobs := {}
	var tier := "high"
	var mode := "high"
	func register_knob(id: String, setter: Callable, levels: Dictionary) -> void:
		knobs[id] = {"setter": setter, "levels": levels}
	func get_tier() -> String: return tier
	func get_mode() -> String: return mode
	func set_tier(t: String) -> void:
		mode = t
		tier = "med" if t == "auto" else t
		for id in knobs: knobs[id].setter.call(knobs[id].levels[tier])
		tier_changed.emit(tier)

## Stand-in for world.gd (only the members RenderPipeline reads).
class FakeWorld extends Node3D:
	var terrain: Node = null
	var terrain_mat := ShaderMaterial.new()
	var sky_mat := ShaderMaterial.new()
	var env: WorldEnvironment = null
	var sun := DirectionalLight3D.new()
	var waves := MeshInstance3D.new()
	var player: Node3D = null
	var foliage: FoliageScatter = null

static func run(t: Node) -> void:
	# ---------- tier table ----------
	var ok := true
	for id in RenderTiers.knob_ids():
		for tr in RenderTiers.TIERS:
			if not RenderTiers.levels(id).has(tr): ok = false
	t.check(ok and RenderTiers.knob_ids().size() >= 25, "render: every knob has low/med/high/ultra levels")
	t.check(RenderTiers.TIERS == ["low", "med", "high", "ultra"], "render: tier names match AutoQuality")
	t.check(RenderTiers.sanitize("auto") == "med" and RenderTiers.sanitize("bogus") == "med", "render: auto/unknown never an effective tier -> mid fallback")
	var mono := true
	for id in ["terrain.view_distance", "camera.far", "foliage.range", "props.range", "particles.budget", "view.render_scale", "sky.cloud_octaves"]:
		var prev := -INF
		for tr in RenderTiers.TIERS:
			var v := float(RenderTiers.value(id, tr))
			if v < prev: mono = false
			prev = v
	t.check(mono, "render: cost knobs never decrease from low to ultra")
	t.check(RenderTiers.from_legacy(0) == "low" and RenderTiers.from_legacy(1) == "med" and RenderTiers.from_legacy(2) == "high", "render: legacy LOW/MED/HIGH map to tiers")
	t.check(RenderTiers.to_legacy("ultra") == 2 and RenderTiers.to_legacy("low") == 0, "render: tier -> legacy index")
	t.check(not RenderTiers.renderer_supports("ssao", "mobile") and not RenderTiers.renderer_supports("ssr", "mobile") and RenderTiers.renderer_supports("ssao", "forward_plus"), "render: SSAO/SSR are Forward+ only (no-op on Mobile)")
	t.check(RenderTiers.renderer_supports("compute", "mobile") and not RenderTiers.renderer_supports("compute", "gl_compatibility"), "render: compute needs Vulkan, not Compatibility")
	t.check(RenderTiers.scaling_mode("fsr", 0.8, "mobile") == Viewport.SCALING_3D_MODE_FSR, "render: FSR1 below native scale on Mobile")
	t.check(RenderTiers.scaling_mode("fsr2", 0.8, "mobile") == Viewport.SCALING_3D_MODE_FSR, "render: FSR2 falls back to FSR1 on Mobile")
	t.check(RenderTiers.scaling_mode("fsr", 1.0, "mobile") == Viewport.SCALING_3D_MODE_BILINEAR, "render: no upscaler at native scale")
	t.check(RenderTiers.msaa_mode(2) == Viewport.MSAA_2X and RenderTiers.msaa_mode(0) == Viewport.MSAA_DISABLED, "render: MSAA mapping")
	t.check(RenderTiers.shadow_mode(4) == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and RenderTiers.shadow_mode(1) == DirectionalLight3D.SHADOW_ORTHOGONAL, "render: shadow split mapping")
	t.check(RenderTiers.value("terrain.lod_fade", "low") == 0.0 and RenderTiers.value("terrain.lod_fade", "med") == 0.0, "render: LOD fade (discard) off on low/med")
	t.check(not RenderTiers.value("water.depth_fx", "med") and RenderTiers.value("water.depth_fx", "high"), "render: depth water from high")
	t.check(RenderTiers.sky_variant(0) == 1 and RenderTiers.sky_variant(1) == 0 and RenderTiers.sky_variant(2) == 2, "render: aurora over Alaska, starfield over Cosmic")
	t.check(RenderTiers.sky_variant(1, "aurora") == 1 and RenderTiers.sky_variant(0, "standard") == 0, "render: realm sky override")
	# ---------- governor ----------
	var g := FrameGovernor.new(33.3)
	for i in FrameGovernor.WINDOW: g.push(20.0)
	t.check(is_equal_approx(g.mult, 1.0), "governor: fast frames keep full scale")
	var changed := false
	for i in FrameGovernor.WINDOW: changed = g.push(45.0) or changed
	t.check(changed and is_equal_approx(g.mult, 0.95), "governor: slow window drops one step")
	for i in FrameGovernor.WINDOW * 20: g.push(60.0)
	t.check(is_equal_approx(g.mult, FrameGovernor.MIN_MULT) and g.wants_lower_tier(), "governor: floors at MIN_MULT then asks for a lower tier")
	for i in FrameGovernor.WINDOW * (FrameGovernor.RAISE_WINDOWS - 1): g.push(10.0)
	t.check(is_equal_approx(g.mult, FrameGovernor.MIN_MULT), "governor: recovery is slow (hysteresis)")
	for i in FrameGovernor.WINDOW: g.push(10.0)
	t.check(g.mult > FrameGovernor.MIN_MULT, "governor: recovers after sustained headroom")
	t.check(is_equal_approx(FrameGovernor.p90(PackedFloat32Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 100])), 9.0), "governor: p90 ignores one spike")
	# ---------- particle budget ----------
	ParticleBudget.clear()
	ParticleBudget.configure(1000, 400)
	t.check(ParticleBudget.request("snow", 900) == 400, "particles: clamped to per-emitter cap")
	t.check(ParticleBudget.request("embers", 400) == 400 and ParticleBudget.request("dust", 400) == 200, "particles: pool total never exceeded")
	t.check(ParticleBudget.used() == 1000 and ParticleBudget.left() == 0, "particles: used/left")
	t.check(ParticleBudget.request("late", 50) == 0, "particles: empty pool grants nothing")
	ParticleBudget.release("snow")
	t.check(ParticleBudget.request("late", 50) == 50 and ParticleBudget.request("snow", 300) == 300, "particles: release returns budget")
	t.check(ParticleBudget.request("snow", 300) == 300 and ParticleBudget.used() == 950, "particles: re-request replaces the old grant")
	ParticleBudget.clear()
	ParticleBudget.configure(int(RenderTiers.value("particles.budget", "med")), int(RenderTiers.value("particles.emitter_cap", "med")))
	# ---------- greedy mesher ----------
	var dims := Vector3i(4, 4, 4)
	var cube := PackedByteArray(); cube.resize(64); cube.fill(1)
	t.check(GreedyMesher.naive_face_count(cube, dims) == 96, "greedy: 4^3 cube has 96 naive faces")
	t.check(GreedyMesher.mesh_quads(cube, dims).size() == 6, "greedy: 4^3 cube merges to 6 quads")
	var two := cube.duplicate()
	for z in 4:
		for y in 4:
			for x in 2: two[GreedyMesher.idx(dims, x, y, z)] = 2
	var q2 := GreedyMesher.mesh_quads(two, dims)
	t.check(q2.size() == 10, "greedy: two materials never merge (10 quads)")
	var am := GreedyMesher.build_mesh(cube, dims, {1: Color.RED})
	var arr: Array = am.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var wind_ok := true
	for i in range(0, ids.size(), 3):
		var c := (v[ids[i + 1]] - v[ids[i]]).cross(v[ids[i + 2]] - v[ids[i]])
		if c.dot(nn[ids[i]]) >= 0.0: wind_ok = false
	t.check(ids.size() == 36 and wind_ok, "greedy: 12 tris, clockwise front faces (Godot winding)")
	var aabb := am.get_aabb()
	t.check(aabb.size.is_equal_approx(Vector3(4, 4, 4)), "greedy: mesh bounds match the voxels")
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var bd := Vector3i(16, 8, 16)
	var build := PackedByteArray(); build.resize(bd.x * bd.y * bd.z)
	for z in bd.z:
		for x in bd.x:
			var hh := 2 + int(rng.randi() % 3)
			for y in hh: build[GreedyMesher.idx(bd, x, y, z)] = 1 + (1 if y == hh - 1 else 0)
	var naive := GreedyMesher.naive_face_count(build, bd)
	var greedy := GreedyMesher.mesh_quads(build, bd).size()
	t.check(greedy < naive * 0.6, "greedy: terrain-like build cuts faces by 40%%+ (%d -> %d)" % [naive, greedy])
	# ---------- foliage scatter (pure) ----------
	var flat := func(x, z): return 5.0
	var biome := func(x, z): return 0
	var a1 := FoliageScatter.scatter(Vector2i(2, -3), 100, flat, biome, -3.0)
	var a2 := FoliageScatter.scatter(Vector2i(2, -3), 100, flat, biome, -3.0)
	t.check(a1.size() == 100 and a1[7].pos == a2[7].pos, "foliage: deterministic per cell")
	var inside := true
	for p in a1:
		if p.pos.x < 2 * FoliageScatter.CELL or p.pos.x >= 3 * FoliageScatter.CELL: inside = false
	t.check(inside, "foliage: points stay inside their cell")
	t.check(FoliageScatter.scatter(Vector2i.ZERO, 50, func(x, z): return -10.0, biome, -3.0).is_empty(), "foliage: nothing under water/lava")
	t.check(FoliageScatter.scatter(Vector2i.ZERO, 50, func(x, z): return x * 2.0, biome, -1e9).is_empty(), "foliage: nothing on steep slopes")
	t.check(FoliageScatter.cells_radius(60.0) == 2 and FoliageScatter.cells_radius(10.0) == 1, "foliage: cell radius from view range")
	for k in FoliageScatter.KINDS:
		var m := FoliageScatter.make_mesh(k)
		t.check(m.get_surface_count() == 1 and m.get_aabb().size.y < 0.6, "foliage: tiny mesh " + k)
	# ---------- shaders ----------
	var ter := (load("res://shaders/terrain_triplanar.gdshader") as Shader)
	var terf := (load("res://shaders/terrain_triplanar_fade.gdshader") as Shader)
	var inc := FileAccess.get_file_as_string("res://shaders/include/terrain_triplanar.gdshaderinc")
	t.check(inc.contains("u_transition_mask") and inc.contains("CUSTOM0"), "terrain: Transvoxel seam stitching in vertex()")
	t.check(inc.contains("curvature_ao") and inc.contains("caustics") and inc.contains("detail_far"), "terrain: curvature AO, caustics, distance-gated detail")
	t.check(terf.code.contains("#define LOD_FADE") and not ter.code.contains("LOD_FADE"), "terrain: discard only in the fade variant")
	var uni := func(sh: Shader) -> Array: return sh.get_shader_uniform_list().map(func(u): return u.name)
	t.check("u_lod_fade" in uni.call(terf) and not ("u_lod_fade" in uni.call(ter)), "terrain: u_lod_fade uniform only in the fade variant")
	t.check("u_transition_mask" in uni.call(ter) and "detail_far" in uni.call(ter), "terrain: default variant compiles the include")
	var sea := (load("res://shaders/lava_sea.gdshader") as Shader)
	var sead := (load("res://shaders/lava_sea_depth.gdshader") as Shader)
	var winc := FileAccess.get_file_as_string("res://shaders/include/fluid_sea.gdshaderinc")
	t.check(sead.code.contains("#define DEPTH_FX") and not sea.code.contains("DEPTH_FX") and winc.contains("hint_depth_texture"), "water: depth texture only in the high-tier variant")
	t.check("clarity" in uni.call(sead) and not ("clarity" in uni.call(sea)), "water: depth-fade uniforms compile only in the variant")
	t.check("sky_top_reflect" in uni.call(sea), "water: sky-gradient reflection on every tier")
	var sky := (load("res://shaders/cinematic_sky.gdshader") as Shader)
	t.check(sky.code.contains("AT_CUBEMAP_PASS") and "sky_variant" in uni.call(sky) and "aurora_strength" in uni.call(sky), "sky: aurora/starfield variants skipped in the radiance pass")
	t.check((load("res://shaders/foliage_sway.gdshader") as Shader).code.contains("MODEL_MATRIX"), "foliage: per-instance sway shader")
	# ---------- generator band fill == reference ----------
	if ClassDB.class_exists("VoxelBuffer"):
		var gen = load("res://scripts/generators/smooth_terrain_generator.gd").new(1337)
		var bad := 0
		var r2 := RandomNumberGenerator.new(); r2.seed = 5
		for i in 18:
			var lod := i % 6; var s := 1 << lod
			var bx := r2.randi_range(-6, 6) * 16 * s; var bz := r2.randi_range(-6, 6) * 16 * s
			var h: float = gen.height_f(bx, bz)
			var o := Vector3i(bx, int(floor(h / (16.0 * s))) * 16 * s + r2.randi_range(-1, 1) * 8 * s, bz)
			var b1 = ClassDB.instantiate("VoxelBuffer"); b1.create(19, 19, 19)
			var b2 = ClassDB.instantiate("VoxelBuffer"); b2.create(19, 19, 19)
			gen._generate_block(b1, o, lod); gen._generate_block_reference(b2, o, lod)
			for z in range(0, 19, 2):
				for y in 19:
					for x in range(0, 19, 2):
						if absf(b1.get_voxel_f(x, y, z, 1) - b2.get_voxel_f(x, y, z, 1)) > 0.0001: bad += 1
		t.check(bad == 0, "generator: band fill == reference SDF (18 blocks, all LODs)")
	# ---------- docs / tracker / wiki ----------
	var doc := FileAccess.get_file_as_string("res://docs/modules/RENDERING.md")
	for kw in ["greedy", "Transvoxel", "occlusion", "visibility range", "MultiMesh", "compute", "triplanar", "SDFGI", "fog", "caustics", "aurora", "particle", "MSAA", "FSR", "ubershader", "ASTC", "thermal", "AutoQuality", "register_knob"]:
		t.check(doc.to_lower().contains(kw.to_lower()), "RENDERING.md covers " + kw)
	var par := FileAccess.get_file_as_string("res://docs/modules/VIEWER_PARITY.md")
	t.check(par.contains("Rendering") and par.contains("RND-"), "parity table has a rendering section")
	var csv := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	t.check(csv.contains("\nRND-1,") and not csv.contains("\r"), "tracker: RND rows, LF endings")
	t.check(FileAccess.file_exists("res://docs/wiki/graphics-settings.md"), "wiki: graphics settings page")
	t.check(FileAccess.file_exists("res://docs/specs/foxy/RENDER_QUALITY_HOOKS.md"), "spec for Foxy: AutoQuality hooks")

static func run_scene(t: Node) -> void:
	var tree := t.get_tree()
	await tree.process_frame
	# ---------- pipeline with a fake AutoQuality ----------
	var w := FakeWorld.new()
	w.env = WorldEnvironment.new(); w.env.environment = Environment.new()
	var sk := Sky.new(); sk.sky_material = w.sky_mat; w.env.environment.sky = sk
	w.add_child(w.env); w.add_child(w.sun); w.add_child(w.waves)
	var wm := ShaderMaterial.new(); wm.shader = load(RenderPipeline.SHADER_SEA); w.waves.material_override = wm
	w.terrain_mat.shader = load(RenderPipeline.SHADER_TERRAIN)
	tree.root.add_child(w)
	var aq := FakeAQ.new()
	var p := RenderPipeline.new()
	w.add_child(p)
	p.setup(w, aq)
	t.check(p.registered and aq.knobs.size() == RenderTiers.knob_ids().size(), "pipeline: registers every world knob with AutoQuality")
	var prefixed := true
	for id in aq.knobs:
		if not str(id).begins_with(RenderPipeline.KNOB_PREFIX): prefixed = false
	t.check(prefixed, "pipeline: knob ids namespaced world.*")
	t.check(aq.knobs["world.terrain.view_distance"].levels == RenderTiers.levels("terrain.view_distance"), "pipeline: levels keyed by tier")
	t.check(p.tier == "high" and w.sun.shadow_enabled and w.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "pipeline: applies AutoQuality's current tier on register")
	t.check((w.waves.material_override as ShaderMaterial).shader.resource_path == RenderPipeline.SHADER_SEA_DEPTH, "pipeline: high -> depth water variant")
	t.check(w.terrain_mat.shader.resource_path == RenderPipeline.SHADER_TERRAIN_FADE, "pipeline: high -> LOD fade terrain variant")
	aq.set_tier("low")
	t.check(p.tier == "low" and not w.sun.shadow_enabled, "pipeline: tier_changed low turns shadows off")
	t.check(w.terrain_mat.shader.resource_path == RenderPipeline.SHADER_TERRAIN and (w.waves.material_override as ShaderMaterial).shader.resource_path == RenderPipeline.SHADER_SEA, "pipeline: low -> no-discard terrain, plain water")
	t.check(float(w.terrain_mat.get_shader_parameter("curvature_ao")) == 0.0 and int(w.sky_mat.get_shader_parameter("cloud_octaves")) == 2, "pipeline: low shader knobs")
	t.check(w.env.environment.sky.process_mode == Sky.PROCESS_MODE_INCREMENTAL and w.env.environment.sky.radiance_size == Sky.RADIANCE_SIZE_32, "pipeline: low sky radiance 32, incremental")
	t.check(ParticleBudget.budget == 400 and ParticleBudget.emitter_cap == 150, "pipeline: low particle budget")
	t.check(RenderPipeline.props_range == 70.0, "pipeline: low prop draw distance")
	t.check((w.waves.mesh as PlaneMesh).subdivide_width == 48, "pipeline: low wave mesh")
	t.check(not w.env.environment.ssao_enabled and not w.env.environment.ssr_enabled, "pipeline: never enables SSAO/SSR on Mobile")
	t.check(not p.auto_mode() and is_equal_approx(p.effective_scale(), 0.7), "pipeline: manual mode ignores the governor")
	aq.set_tier("auto")
	t.check(p.auto_mode() and p.tier == "med", "pipeline: auto mode tracked")
	for i in FrameGovernor.WINDOW: p._process(0.05)
	t.check(p.effective_scale() < 0.8 and is_equal_approx(t.get_viewport().scaling_3d_scale, p.effective_scale()), "pipeline: auto mode trims render scale on slow frames")
	t.check(t.get_viewport().scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR, "pipeline: med upscales with FSR1")
	# restore the real viewport for later tests
	t.get_viewport().scaling_3d_scale = 1.0
	t.get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	t.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	# ---------- fallback without AutoQuality ----------
	t.check(RenderPipeline.find_auto_quality(tree) == null or RenderPipeline.find_auto_quality(tree).has_method("register_knob"), "pipeline: AutoQuality lookup is guarded")
	var junk := Node.new(); junk.name = "AutoQuality"
	var had := tree.root.get_node_or_null("AutoQuality")
	if had == null:
		tree.root.add_child(junk)
		t.check(RenderPipeline.find_auto_quality(tree) == null, "pipeline: an AutoQuality without the API is ignored")
		junk.queue_free()
	else: junk.free()
	await tree.process_frame
	var w2 := FakeWorld.new()
	w2.env = WorldEnvironment.new(); w2.env.environment = Environment.new(); w2.add_child(w2.env); w2.add_child(w2.sun); w2.add_child(w2.waves)
	tree.root.add_child(w2)
	var p2 := RenderPipeline.new(); w2.add_child(p2)
	var old := Settings.quality()
	Settings.set_quality(1)
	if RenderPipeline.find_auto_quality(tree) == null:
		p2.setup(w2)
		t.check(p2.aq == null and p2.tier == "med", "pipeline: no AutoQuality -> legacy MED = mid defaults")
		Settings.set_quality(0)
		t.check(p2.tier == "low", "pipeline: legacy quality change still applies without AutoQuality")
	Settings.set_quality(old)
	w.queue_free(); w2.queue_free()
	await tree.process_frame
	t.get_viewport().scaling_3d_scale = 1.0
	t.get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	t.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	# ---------- foliage node ----------
	var gen = load("res://scripts/generators/smooth_terrain_generator.gd").new(1337) if ClassDB.class_exists("VoxelGeneratorScript") else null
	if gen:
		var pl := Node3D.new(); tree.root.add_child(pl)
		var f := FoliageScatter.new(); tree.root.add_child(f)
		f.setup(gen, pl)
		f.view_range = 60.0; f.density = 0.6
		f.stream(true)
		var cells := (2 * FoliageScatter.cells_radius(60.0) + 1)
		t.check(f.draw_count() <= cells * cells * 3 and f.instance_count() > 0, "foliage: one MultiMesh per biome per cell (%d draws, %d instances)" % [f.draw_count(), f.instance_count()])
		var vr := true
		for c in f.get_children():
			for mmi in c.get_children():
				if (mmi as GeometryInstance3D).visibility_range_end != 60.0 or (mmi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: vr = false
		t.check(vr, "foliage: distance-culled, no shadows")
		var before := f.instance_count()
		f.set_density(0.3); f.stream(true)
		t.check(f.instance_count() < before, "foliage: density knob lowers instances")
		f.set_density(0.0); f.stream(true)
		t.check(f.instance_count() == 0, "foliage: density 0 removes all cover")
		f.queue_free(); pl.queue_free()
		await tree.process_frame
