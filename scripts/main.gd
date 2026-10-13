extends Node3D
## Root script for scenes/main.tscn: gives the blocky mesher a library whose ids
## match scripts/generators/biome_generator.gd (0 air .. 9 neon).

const BLOCK_COLORS := ["#000000", "#7a7a80", "#f4f8ff", "#a9d6f0", "#3a2a5a", "#c77dff",
	"#2a2a2a", "#ff5a1a", "#55606a", "#22f0ff"]
const EMISSIVE := [5, 7, 9]

func _ready() -> void:
	var terrain := $VoxelTerrain as VoxelTerrain
	var lib := VoxelBlockyLibrary.new()
	var models: Array[VoxelBlockyModel] = []
	for i in BLOCK_COLORS.size():
		if i == 0:
			models.append(VoxelBlockyModelEmpty.new())
			continue
		var cube := VoxelBlockyModelCube.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(BLOCK_COLORS[i])
		if i in EMISSIVE:
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
		cube.set_material_override(0, mat)
		models.append(cube)
	lib.models = models
	lib.bake()
	var mesher := VoxelMesherBlocky.new()
	mesher.library = lib
	terrain.mesher = mesher
