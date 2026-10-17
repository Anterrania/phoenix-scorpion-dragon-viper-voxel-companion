class_name SoftParticle
extends RefCounted
## v0.11 soft round particle look: generated radial-gradient texture, additive, billboarded,
## vertex-color tinted, unshaded. Every GPUParticles3D draw pass must use this (never untextured quads).

static var _tex: Texture2D
static var _mats := {}

static func texture() -> Texture2D:
	if _tex: return _tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5)
	t.width = 64; t.height = 64
	_tex = t
	return t

## additive=true for embers/sparkles/glow; false (alpha) for snow and dust.
static func material(additive := true) -> StandardMaterial3D:
	if _mats.has(additive): return _mats[additive]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[additive] = m
	return m

static func quad(size: float, additive := true) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = material(additive)
	return q

## Fix any particle node in a subtree that draws untextured quads. Returns count fixed.
static func sanitize(root: Node) -> int:
	var n := 0
	for p in root.find_children("*", "GPUParticles3D", true, false):
		var mesh: Mesh = p.draw_pass_1
		var ok := false
		if mesh and mesh.get("material") is BaseMaterial3D:
			ok = (mesh.material as BaseMaterial3D).albedo_texture != null
		if not ok:
			var s := 0.05
			if mesh is QuadMesh: s = maxf((mesh as QuadMesh).size.x, 0.02)
			p.draw_pass_1 = quad(s, true)
			n += 1
	return n
