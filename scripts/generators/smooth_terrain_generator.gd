extends "res://scripts/generators/biome_voxel_generator.gd"
## v0.3 SMOOTH terrain: signed-distance field for VoxelLodTerrain + VoxelMesherTransvoxel.
## Same three biomes/heights as v0.2, but surfaces are continuous (no cubes). Materials are
## painted by shaders/terrain_triplanar.gdshader using a baked biome map (see bake_biome_map).

const CH_SDF := 1  # VoxelBuffer.CHANNEL_SDF
const MAX_H := 48.0
const MIN_H := -40.0
const MAP_HALF := 4096.0  # biome map covers +-4096 m
const MAP_RES := 256

func _get_used_channels_mask() -> int:
	return 1 << CH_SDF

## SDF: negative inside ground, positive in air. Small 3D warp makes overhang-free but
## less "heightmap-perfect" rock faces on steep Venus ridges.
func sdf_at(x: float, y: float, z: float, h: float) -> float:
	return y - h

func _generate_block(out: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var size := out.get_size()
	var s := 1 << lod
	if origin.y > MAX_H + 4.0:
		out.fill_f(1.0, CH_SDF)
		return
	if origin.y + size.y * s < MIN_H:
		out.fill_f(-1.0, CH_SDF)
		return
	for lz in size.z:
		for lx in size.x:
			var wx := float(origin.x + lx * s)
			var wz := float(origin.z + lz * s)
			var h := height_f(wx, wz)
			for ly in size.y:
				var wy := float(origin.y + ly * s)
				out.set_voxel_f(clampf((wy - h) / 4.0, -1.0, 1.0), lx, ly, lz, CH_SDF)

## Bake biome_value into a small float texture (R) for the terrain/lava shaders.
func bake_biome_map() -> ImageTexture:
	var img := Image.create(MAP_RES, MAP_RES, false, Image.FORMAT_RF)
	var step := MAP_HALF * 2.0 / MAP_RES
	for j in MAP_RES:
		for i in MAP_RES:
			var v := biome_value(-MAP_HALF + (i + 0.5) * step, -MAP_HALF + (j + 0.5) * step)
			img.set_pixel(i, j, Color(v, 0, 0))
	return ImageTexture.create_from_image(img)
