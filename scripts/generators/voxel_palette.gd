class_name VoxelPalette
extends RefCounted
## Colors for the 16 blocky voxel ids (index = id). Black/magenta/gold/platinum house palette.
## "glow" ids are emissive so the mobile glow pass makes them sparkle.
const COLORS := ["#000000", "#eef4fb", "#9fd2f0", "#4d6b4a", "#3a3a48", "#121018", "#ff4a12", "#3b2626",
	"#8a1f4a", "#ff5a1a", "#ffc23a", "#3b1f6e", "#dfe6f2", "#ff2fd0", "#160c2c", "#22f0ff"]
const GLOW := {6: 2.2, 9: 2.5, 10: 3.0, 12: 1.6, 13: 3.0, 15: 2.0}
const METAL := {10: 0.9, 12: 1.0, 5: 0.3}

static var _grain: Texture2D

## Tiny runtime noise texture (no APK cost) applied triplanar for a hand-painted grain.
static func grain() -> Texture2D:
	if _grain == null:
		var t := NoiseTexture2D.new()
		t.width = 64
		t.height = 64
		t.seamless = true
		var n := FastNoiseLite.new()
		n.frequency = 0.15
		t.noise = n
		var g := Gradient.new()
		g.set_color(0, Color(0.78, 0.78, 0.82))
		g.set_color(1, Color(1, 1, 1))
		t.color_ramp = g
		_grain = t
	return _grain

static func make_material(id: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLORS[id])
	mat.albedo_texture = grain()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.85
	if METAL.has(id):
		mat.metallic = METAL[id]
		mat.roughness = 0.3
	if GLOW.has(id):
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = GLOW[id]
	return mat
