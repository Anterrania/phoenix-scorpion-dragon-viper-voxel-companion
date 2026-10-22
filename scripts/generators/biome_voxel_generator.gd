extends VoxelGeneratorScript
## v0.2 colored biome terrain. Three regions blended by a low-frequency noise:
##   ALASKA (snow/ice/moss, platinum glitter), VENUS (obsidian/ash/lava, gold glitter),
##   COSMIC (violet/starfield, magenta glitter + cyan crystals).
## Pure helpers (biome_at, height_at, material_at) are static-free so tests can call them.

const CH := 0  # VoxelBuffer.CHANNEL_TYPE
enum { AIR, SNOW, ICE, MOSS, STONE, OBSIDIAN, LAVA, ASH, VENUS_ROCK, FIRE, GOLD, COSMIC, PLATINUM, MAGENTA, STARFIELD, CRYSTAL }
enum Biome { ALASKA, VENUS, COSMIC }
const LAVA_LEVEL := -3

var _height := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _biome := FastNoiseLite.new()

func _init(seed_value: int = 1337) -> void:
	seed_for_ores = seed_value
	_height.seed = seed_value
	_height.frequency = 0.008
	_height.fractal_octaves = 4
	_detail.seed = seed_value + 7
	_detail.frequency = 0.05
	_biome.seed = seed_value + 99
	_biome.frequency = 0.0035
	_biome.fractal_octaves = 2

func _get_used_channels_mask() -> int:
	return 1 << CH

## Spawn (0,0) is forced into Alaska so the first view is the snowy home realm.
func biome_value(x: float, z: float) -> float:
	var v := _biome.get_noise_2d(x, z) * 2.2
	var spawn_pull := clampf(1.0 - Vector2(x, z).length() / 90.0, 0.0, 1.0)
	return lerpf(v, 0.0, spawn_pull)

func biome_at(x: float, z: float) -> int:
	var v := biome_value(x, z)
	if v < -0.35: return Biome.VENUS
	if v > 0.35: return Biome.COSMIC
	return Biome.ALASKA

func height_at(x: float, z: float) -> int:
	return int(floor(height_f(x, z)))

## Continuous surface height (used by the v0.3 smooth SDF terrain).
func height_f(x: float, z: float) -> float:
	var v := biome_value(x, z)
	var n := _height.get_noise_2d(x, z)
	var d := _detail.get_noise_2d(x, z)
	var alaska := 4.0 + n * 14.0 + d * 1.5
	var venus := -2.0 + absf(n) * 22.0 - 4.0 + d * 2.0      # ridged volcanic
	var cosmic := 6.0 + n * 10.0 + pow(maxf(d, 0.0), 2.0) * 18.0  # floating-spire bumps
	var h := alaska
	if v < 0.0:
		h = lerpf(alaska, venus, smoothstep(-0.15, -0.55, v))
	else:
		h = lerpf(alaska, cosmic, smoothstep(0.15, 0.55, v))
	return h

static func _hash(x: int, z: int) -> int:
	var h := (x * 73856093) ^ (z * 19349663)
	return absi(h) % 997

## Material for voxel at world y inside a column with surface height h.
func material_at(x: int, y: int, z: int, h: int, biome: int) -> int:
	if y > h:
		if biome == Biome.VENUS and y <= LAVA_LEVEL: return LAVA
		return AIR
	var depth := h - y
	var sparkle := depth == 0 and _hash(x, z) < 22
	match biome:
		Biome.VENUS:
			if sparkle: return GOLD
			if depth == 0: return VENUS_ROCK if h > 6 else ASH
			return OBSIDIAN if depth < 4 else STONE
		Biome.COSMIC:
			if sparkle: return MAGENTA
			if depth == 0: return CRYSTAL if _hash(z, x) < 6 else COSMIC
			return STARFIELD
		_:
			if sparkle: return PLATINUM
			if depth == 0: return (SNOW if _hash(z, x) > 160 else MOSS) if h > 6 else (MOSS if h > 1 else ICE)
			return MOSS if depth < 3 else STONE

## LIFE-6 geology hook: ore under this voxel ("" = none). Render voxel ids are unchanged; ores are a
## query layer (Geology) the server and mining tool share. Biome -> realm: ALASKA alaskan_tundra,
## VENUS venus_fire, COSMIC cosmic.
const BIOME_REALM := ["alaskan_tundra", "venus_fire", "cosmic"]
var seed_for_ores := 1337
func ore_at(x: int, y: int, z: int) -> String:
	var h := height_at(x, z)
	return Geology.deposit_at(BIOME_REALM[biome_at(x, z)], x, y, z, h, seed_for_ores)

func _generate_block(out: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var size := out.get_size()
	var s := 1 << lod
	if origin.y > 48:
		return  # all air above the tallest spire
	if origin.y + size.y * s < -40:
		out.fill(STONE, CH)
		return
	for lz in size.z:
		for lx in size.x:
			var wx := origin.x + lx * s
			var wz := origin.z + lz * s
			var h := height_at(wx, wz)
			var b := biome_at(wx, wz)
			for ly in size.y:
				var wy := origin.y + ly * s
				var m := material_at(wx, wy, wz, h, b)
				if m != AIR:
					out.set_voxel(m, lx, ly, lz, CH)
