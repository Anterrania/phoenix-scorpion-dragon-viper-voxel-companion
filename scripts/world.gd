extends Node3D
## v0.3 main world: SMOOTH voxel terrain (VoxelLodTerrain + Transvoxel + SDF generator),
## triplanar PBR biome shader, cinematic alien sky (planet, moons, stars), height fog,
## ACES tonemapping, bloom and color grading. Graphics quality Low/Med/High via Settings.

@onready var terrain: Node = $VoxelTerrain
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var sea: MeshInstance3D = get_node_or_null("FluidSea")
@onready var player: Node3D = get_node_or_null("Player")

const SmoothGen := preload("res://scripts/generators/smooth_terrain_generator.gd")
const TERRAIN_SHADER := preload("res://shaders/terrain_triplanar.gdshader")
const SEA_SHADER := preload("res://shaders/lava_sea.gdshader")
const SKY_SHADER := preload("res://shaders/cinematic_sky.gdshader")
## sky top, horizon, ground, fog, sun color, sun energy, planet color, star strength
const AMBIENCE := {
	0: ["#0b1a3c", "#8fb1d8", "#c9d6e4", "#9fb6d2", "#fff1dc", 1.25, "#9a7fd8", 0.5],  # Alaska
	1: ["#1c0508", "#d4521f", "#2a0806", "#8a2e1c", "#ffb27a", 1.5, "#f0b060", 0.25],  # Venus
	2: ["#03010d", "#4a1f8a", "#0c0620", "#2b1257", "#e4d0ff", 0.9, "#ff5ad8", 1.2],   # Cosmic
}
var generator
var current_biome := -1
var sky_mat: ShaderMaterial
var terrain_mat: ShaderMaterial
var _check := 0.0

func _ready() -> void:
	generator = SmoothGen.new(1337)
	_setup_environment()
	_setup_materials()
	if not ClassDB.class_exists("VoxelLodTerrain"):
		push_error("godot_voxel not found: install the GDExtension. See docs/SETUP_GUIDE.md")
		return
	terrain.mesher = build_smooth_mesher()
	terrain.generator = generator
	terrain.material = terrain_mat
	terrain.generate_collisions = true
	terrain.collision_lod_count = 1
	terrain.lod_distance = 48.0
	apply_quality(Settings.quality())
	Settings.quality_changed.connect(apply_quality)
	RealmBuilder.realm_ready.connect(apply_realm)
	_place_on_ground(player)
	for c in get_children():
		if "config" in c and c is Node3D: _place_on_ground(c)
	_update_biome(true)
	_spawn_props()
	_spawn_content()

const PropsScript := preload("res://scripts/physics/physics_props.gd")
func _spawn_props() -> void:
	var props := PropsScript.new()
	props.name = "PhysicsProps"
	add_child(props)
	props.setup(generator, Vector3(0, 0, -8))

const ContentScript := preload("res://scripts/world/world_content.gd")
func _spawn_content() -> void:
	var wc := ContentScript.new()
	wc.name = "WorldContent"
	add_child(wc)
	wc.setup(generator, player)

static func build_smooth_mesher():
	var m = ClassDB.instantiate("VoxelMesherTransvoxel")
	m.mesh_optimization_enabled = true
	return m

func _detail_tex() -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	nt.noise = fn
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	nt.generate_mipmaps = true
	return nt

func _setup_materials() -> void:
	var biome_map: Texture2D = generator.bake_biome_map()
	var detail := _detail_tex()
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = TERRAIN_SHADER
	terrain_mat.set_shader_parameter("biome_map", biome_map)
	terrain_mat.set_shader_parameter("detail", detail)
	if sea:
		var pm := PlaneMesh.new()
		pm.size = Vector2(4000, 4000)
		sea.mesh = pm
		var sm := ShaderMaterial.new()
		sm.shader = SEA_SHADER
		sm.set_shader_parameter("biome_map", biome_map)
		sm.set_shader_parameter("detail", detail)
		sea.material_override = sm
		sea.position.y = generator.LAVA_LEVEL
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _setup_environment() -> void:
	var e: Environment = env.environment
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_intensity = 0.7
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Cheap "volumetric-like" atmosphere: depth fog with aerial perspective + ground haze.
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_density = 0.0016
	e.fog_aerial_perspective = 0.55
	e.fog_sky_affect = 0.15
	e.fog_height = 6.0
	e.fog_height_density = 0.02
	# Color grading
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 1.1
	sun.rotation_degrees = Vector3(-28, 35, 0)
	sun.light_angular_distance = 0.6
	sun.directional_shadow_max_distance = 60.0

func apply_quality(level: int) -> void:
	var q: Dictionary = Settings.quality_preset(level)
	if "view_distance" in terrain:
		terrain.view_distance = int(q["view"])
		terrain.lod_count = int(q["lods"])
	if player:
		var vv := player.get_node_or_null("VoxelViewer")
		if vv: vv.view_distance = int(q["view"])
		var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
		if cam: cam.far = float(q["far"])
	env.environment.glow_enabled = bool(q["glow"])
	sun.shadow_enabled = bool(q["shadows"])
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(q["scale"])
		vp.msaa_3d = Viewport.MSAA_2X if int(q["msaa"]) > 0 else Viewport.MSAA_DISABLED

func _place_on_ground(n: Node3D) -> void:
	if n and generator:
		var p := n.global_position
		n.global_position = Vector3(p.x, maxf(generator.height_f(p.x, p.z), generator.LAVA_LEVEL) + 2.0, p.z)

func biome_name(b: int) -> String:
	return ["Alaskan Aurora Tundra", "Venus Fire Wastes", "Cosmic Glitter Expanse"][b]

func _process(delta: float) -> void:
	if sea and player:
		sea.global_position.x = snappedf(player.global_position.x, 64.0)
		sea.global_position.z = snappedf(player.global_position.z, 64.0)
	_env_tick(delta)
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_update_biome(false)

# ---------- v0.7 environment: region default / preset / day-night cycle ----------
var env_mode := "region"   # "region" | "cycle" | preset name
var hour := 10.0

func set_env_mode(m: String) -> void:
	env_mode = m
	if m == "region":
		sun.rotation_degrees.x = -28.0
		env.environment.ambient_light_energy = 1.0
		_update_biome(true)
	elif m != "cycle": apply_env(EnvPresets.PRESETS[m], 2.0)

func apply_env(a: Array, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	for pair in [["top_color", a[0]], ["horizon_color", a[1]], ["ground_color", a[2]]]:
		var from: Color = sky_mat.get_shader_parameter(pair[0]) if sky_mat.get_shader_parameter(pair[0]) is Color else Color(pair[1])
		if dur <= 0.05: sky_mat.set_shader_parameter(pair[0], Color(pair[1]))
		else: tw.tween_method(func(c: Color): sky_mat.set_shader_parameter(pair[0], c), from, Color(pair[1]), dur)
	sky_mat.set_shader_parameter("star_strength", float(a[7]))
	env.environment.fog_light_color = Color(a[3])
	sun.light_color = Color(a[4])
	sun.light_energy = float(a[5])
	sun.rotation_degrees.x = float(a[6])
	env.environment.ambient_light_energy = float(a[8])
	if dur <= 0.05: tw.kill()

func _env_tick(delta: float) -> void:
	hour = fposmod(hour + delta * 24.0 / EnvPresets.DAY_SECONDS, 24.0)
	if env_mode == "cycle":
		apply_env(EnvPresets.cycle_values(hour), 0.0)

func _update_biome(force: bool) -> void:
	if generator == null or player == null: return
	if env_mode != "region": return
	var b: int = generator.biome_at(player.global_position.x, player.global_position.z)
	if b == current_biome and not force: return
	current_biome = b
	var a: Array = AMBIENCE[b]
	var dur := 0.01 if force else 2.5
	var tw := create_tween().set_parallel(true)
	for pair in [["top_color", a[0]], ["horizon_color", a[1]], ["ground_color", a[2]], ["planet_color", a[6]]]:
		var from: Color = sky_mat.get_shader_parameter(pair[0]) if sky_mat.get_shader_parameter(pair[0]) is Color else Color(pair[1])
		tw.tween_method(func(c: Color): sky_mat.set_shader_parameter(pair[0], c), from, Color(pair[1]), dur)
	sky_mat.set_shader_parameter("star_strength", float(a[7]))
	tw.tween_property(env.environment, "fog_light_color", Color(a[3]), dur)
	tw.tween_property(sun, "light_color", Color(a[4]), dur)
	tw.tween_property(sun, "light_energy", float(a[5]), dur)

## Realm presets / LLM realms restyle ambience; terrain stays the biome generator.
func apply_realm(p: Dictionary) -> void:
	if p.is_empty(): return
	var pal: Dictionary = p.get("palette", {})
	if pal.has("fog"):
		env.environment.fog_light_color = Color(pal["fog"])
	env.environment.fog_density = clampf(float(p.get("ambience", {}).get("fog_density", 0.002)), 0.0, 0.05)

func get_voxel_tool():
	return terrain.get_voxel_tool() if terrain else null
