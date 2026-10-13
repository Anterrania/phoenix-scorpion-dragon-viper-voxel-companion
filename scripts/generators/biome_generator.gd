# VoxelGeneratorScript stub. Requires Zylann godot_voxel (module build or GDExtension 1.x).
# NOT yet run in Godot; API names follow godot_voxel docs and may need adjusting per version.
extends VoxelGeneratorScript

enum Biome { ALASKAN_SNOW_ICE, COSMIC, VENUS_FIRE, CYBERPUNK }

const CHANNEL := VoxelBuffer.CHANNEL_TYPE
# Block ids (match your VoxelBlockyLibrary order)
const AIR := 0
const STONE := 1
const SNOW := 2
const ICE := 3
const STARDUST := 4
const CRYSTAL := 5
const BASALT := 6
const LAVA := 7
const CONCRETE := 8
const NEON := 9

@export var biome: Biome = Biome.ALASKAN_SNOW_ICE
@export var base_height := 16.0
var _noise := FastNoiseLite.new()

func _init() -> void:
	_noise.frequency = 0.01

func _get_used_channels_mask() -> int:
	return 1 << CHANNEL

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0:
		return # blocky terrain: LOD 0 only in this stub
	var size := out_buffer.get_size()
	for z in size.z:
		for x in size.x:
			var wx := origin.x + x
			var wz := origin.z + z
			var h := _height(wx, wz)
			for y in size.y:
				var wy := origin.y + y
				out_buffer.set_voxel(_block_for(wx, wy, wz, h), x, y, z, CHANNEL)

func _height(x: int, z: int) -> float:
	var n := _noise.get_noise_2d(x, z)
	match biome:
		Biome.ALASKAN_SNOW_ICE: return base_height + n * 24.0      # ridged mountains
		Biome.COSMIC:           return base_height + n * 40.0      # floating-ish spikes
		Biome.VENUS_FIRE:       return base_height + absf(n) * 18.0 # calderas
		Biome.CYBERPUNK:        return base_height + floorf(n * 4.0) * 6.0 # terraced blocks
	return base_height

func _block_for(x: int, y: int, z: int, h: float) -> int:
	if y > h:
		if biome == Biome.VENUS_FIRE and y < base_height - 2:
			return LAVA
		return AIR
	var top := y > h - 1.0
	match biome:
		Biome.ALASKAN_SNOW_ICE:
			if top: return SNOW
			return ICE if y < base_height - 4 else STONE
		Biome.COSMIC:
			return CRYSTAL if top else STARDUST
		Biome.VENUS_FIRE:
			return BASALT
		Biome.CYBERPUNK:
			return NEON if top and (x + z) % 16 == 0 else CONCRETE
	return STONE
