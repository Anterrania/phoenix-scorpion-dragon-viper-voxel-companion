extends Node3D
## Main world: configures VoxelTerrain (Zylann godot_voxel) from realm params.

@onready var terrain: Node = $VoxelTerrain
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun

const VOXEL_CHANNEL := 0  # VoxelBuffer.CHANNEL_TYPE

func _ready() -> void:
	if not ClassDB.class_exists("VoxelTerrain"):
		push_error("godot_voxel not found: use the Godot build with the voxel module or install the GDExtension. See docs/SETUP_GUIDE.md")
		return
	terrain.mesher = _build_blocky_mesher()
	RealmBuilder.realm_ready.connect(apply_realm)
	apply_realm(RealmBuilder.load_preset("alaskan_tundra"))

func apply_realm(p: Dictionary) -> void:
	if p.is_empty() or terrain == null:
		return
	var n: Dictionary = p["noise"]
	var noise := FastNoiseLite.new()
	noise.seed = int(n.get("seed", 1337))
	noise.frequency = float(n.get("frequency", 0.01))
	noise.fractal_octaves = int(n.get("octaves", 4))
	var gen = ClassDB.instantiate("VoxelGeneratorNoise2D")
	gen.channel = VOXEL_CHANNEL
	gen.noise = noise
	gen.height_start = float(n.get("base_height", 0))
	gen.height_range = float(n.get("height_scale", 32))
	terrain.generator = gen
	var pal: Dictionary = p.get("palette", {})
	env.environment.background_color = Color(pal.get("sky", "#202040"))
	env.environment.fog_light_color = Color(pal.get("fog", "#808090"))
	env.environment.fog_density = float(p.get("ambience", {}).get("fog_density", 0.01))
	sun.light_energy = float(p.get("ambience", {}).get("light_energy", 1.0))

func get_voxel_tool():
	return terrain.get_voxel_tool() if terrain else null

## 16 voxel types (godot_voxel 1.x API). 0 = air, 9 = emissive fire.
const MATERIAL_COLORS := ["#000000", "#e8eef5", "#6b7d5a", "#3d5c3a", "#a9d6f0", "#7a6a5a", "#2a2a3a",
	"#ff2fd0", "#22f0ff", "#ff5a1a", "#ffb000", "#7c3aed", "#c0c8d8", "#b02030", "#101820", "#f5f0e0"]

func _build_blocky_mesher():
	var lib = ClassDB.instantiate("VoxelBlockyLibrary")
	var models := []
	for i in MATERIAL_COLORS.size():
		if i == 0:
			models.append(ClassDB.instantiate("VoxelBlockyModelEmpty"))
			continue
		var cube = ClassDB.instantiate("VoxelBlockyModelCube")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(MATERIAL_COLORS[i])
		if i in [7, 8, 9, 10]:
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 1.5
		cube.set_material_override(0, mat)
		models.append(cube)
	lib.models = models
	lib.bake()
	var mesher = ClassDB.instantiate("VoxelMesherBlocky")
	mesher.library = lib
	return mesher
