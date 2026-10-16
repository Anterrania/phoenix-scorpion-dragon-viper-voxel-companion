extends Node3D
## Main world: VoxelTerrain (Zylann godot_voxel) with the v0.2 colored biome generator,
## procedural sky, glow for glitter sparkle, and per-biome ambience near the player.

@onready var terrain: Node = $VoxelTerrain
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var player: Node3D = get_node_or_null("Player")

const BiomeGen := preload("res://scripts/generators/biome_voxel_generator.gd")
## sky top, horizon, ground, fog, sun color, sun energy
const AMBIENCE := {
	0: ["#0e1840", "#6a8fc8", "#cfdcea", "#8aa2c4", "#fff0d8", 1.0],   # Alaska aurora day
	1: ["#2a0612", "#ff6a2a", "#3b0a0a", "#a8342a", "#ffb070", 1.3],   # Venus fire
	2: ["#06021a", "#7a2fd0", "#120830", "#3a1a6e", "#e0c8ff", 0.8],   # Cosmic
}
var generator
var current_biome := -1
var _sky_mat: ProceduralSkyMaterial
var _check := 0.0

func _ready() -> void:
	_setup_environment()
	if not ClassDB.class_exists("VoxelTerrain"):
		push_error("godot_voxel not found: install the GDExtension. See docs/SETUP_GUIDE.md")
		return
	terrain.mesher = build_blocky_mesher()
	generator = BiomeGen.new(1337)
	terrain.generator = generator
	if "max_view_distance" in terrain:
		terrain.max_view_distance = 96
	RealmBuilder.realm_ready.connect(apply_realm)
	_place_on_ground(player)
	for c in get_children():
		if "config" in c and c is Node3D: _place_on_ground(c)
	_update_biome(true)

func _setup_environment() -> void:
	var e: Environment = env.environment
	_sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.15
	e.glow_hdr_threshold = 0.9
	e.fog_enabled = true
	e.fog_density = 0.004
	sun.shadow_enabled = false  # mobile perf; voxel AO-free look is fine for v0.2
	sun.rotation_degrees = Vector3(-50, 35, 0)

func _place_on_ground(n: Node3D) -> void:
	if n and generator:
		var p := n.global_position
		n.global_position = Vector3(p.x, generator.height_at(p.x, p.z) + 3.0, p.z)

func biome_name(b: int) -> String:
	return ["Alaskan Aurora Tundra", "Venus Fire Wastes", "Cosmic Glitter Expanse"][b]

func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_update_biome(false)

func _update_biome(force: bool) -> void:
	if generator == null or player == null: return
	var b: int = generator.biome_at(player.global_position.x, player.global_position.z)
	if b == current_biome and not force: return
	current_biome = b
	var a: Array = AMBIENCE[b]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sky_mat, "sky_top_color", Color(a[0]), 2.0)
	tw.tween_property(_sky_mat, "sky_horizon_color", Color(a[1]), 2.0)
	tw.tween_property(_sky_mat, "ground_horizon_color", Color(a[1]), 2.0)
	tw.tween_property(_sky_mat, "ground_bottom_color", Color(a[2]), 2.0)
	tw.tween_property(env.environment, "fog_light_color", Color(a[3]), 2.0)
	tw.tween_property(sun, "light_color", Color(a[4]), 2.0)
	tw.tween_property(sun, "light_energy", float(a[5]), 2.0)

## Realm presets / LLM realms now restyle ambience; terrain stays the biome generator.
func apply_realm(p: Dictionary) -> void:
	if p.is_empty(): return
	var pal: Dictionary = p.get("palette", {})
	if pal.has("fog"):
		env.environment.fog_light_color = Color(pal["fog"])
	env.environment.fog_density = clampf(float(p.get("ambience", {}).get("fog_density", 0.006)), 0.0, 0.05)

func get_voxel_tool():
	return terrain.get_voxel_tool() if terrain else null

static func build_blocky_mesher():
	var lib = ClassDB.instantiate("VoxelBlockyLibrary")
	var models := []
	for i in VoxelPalette.COLORS.size():
		if i == 0:
			models.append(ClassDB.instantiate("VoxelBlockyModelEmpty"))
			continue
		var cube = ClassDB.instantiate("VoxelBlockyModelCube")
		cube.set_material_override(0, VoxelPalette.make_material(i))
		models.append(cube)
	lib.models = models
	lib.bake()
	var mesher = ClassDB.instantiate("VoxelMesherBlocky")
	mesher.library = lib
	return mesher
