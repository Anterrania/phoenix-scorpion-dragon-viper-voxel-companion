class_name ParticleFX
extends RefCounted
## v0.8 GPU particle factory. Every effect scales by graphics quality
## (Low 30%, Med 65%, High 100%) and reads a shared wind vector.

const QUALITY_SCALE := [0.3, 0.65, 1.0]
static var wind := Vector3(1.2, 0, 0.4)

static func amount(base: int, quality: int) -> int:
	return maxi(4, int(round(base * QUALITY_SCALE[clampi(quality, 0, 2)])))

## Gusty wind: smooth sine blend, deterministic for tests.
static func wind_at(t: float) -> Vector3:
	var g := 0.6 + 0.4 * sin(t * 0.35) + 0.25 * sin(t * 1.3)
	return Vector3(cos(t * 0.05), 0, sin(t * 0.05)) * 2.2 * g

static func _quad(size: float, col: Color, emit: float, additive := true) -> QuadMesh:
	# v0.11: soft round radial texture, billboarded, unshaded; additive for glows. Brightness
	# from emit is folded into the color (HDR albedo) since unshaded materials ignore emission.
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = SoftParticle.material(additive).duplicate()
	var boost := 1.0 + minf(emit, 6.0) * 0.25 if additive else 1.0
	m.albedo_color = Color(col.r * boost, col.g * boost, col.b * boost, col.a)
	q.material = m
	return q

static var _dot_tex: GradientTexture2D
static func _dot() -> GradientTexture2D:
	if _dot_tex == null:
		_dot_tex = GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5); _dot_tex.fill_to = Vector2(0.5, 0.0)
		_dot_tex.width = 32; _dot_tex.height = 32
	return _dot_tex

static func _fade() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1,1,1,0), Color(1,1,1,1), Color(1,1,1,1), Color(1,1,1,0)])
	var t := GradientTexture1D.new(); t.gradient = g
	return t

static func make(kind: String, quality: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = kind
	var m := ParticleProcessMaterial.new()
	m.color_ramp = _fade()
	var w := wind
	match kind:
		"snow":
			p.amount = amount(900, quality); p.lifetime = 6.0
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(22, 1, 22)
			m.gravity = Vector3(0, -1.4, 0) + w
			m.turbulence_enabled = quality > 0
			m.turbulence_noise_strength = 0.6
			m.scale_min = 0.6; m.scale_max = 1.4
			p.draw_pass_1 = _quad(0.07, Color(1, 1, 1, 0.9), 0.0, false)
			p.position = Vector3(0, 12, 0)
		"embers":
			p.amount = amount(260, quality); p.lifetime = 4.0
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(20, 2, 20)
			m.gravity = Vector3(0, 1.1, 0) + w * 0.7
			m.turbulence_enabled = quality > 0
			m.turbulence_noise_strength = 1.2
			m.scale_min = 0.4; m.scale_max = 1.2
			p.draw_pass_1 = _quad(0.06, Color("#ff7a1a"), 4.0)
			p.position = Vector3(0, -1, 0)
		"ash":
			p.amount = amount(400, quality); p.lifetime = 7.0
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(24, 1, 24)
			m.gravity = Vector3(0, -0.5, 0) + w
			p.draw_pass_1 = _quad(0.05, Color(0.25, 0.22, 0.22, 0.8), 0.0, false)
			p.position = Vector3(0, 10, 0)
		"lava_sparks":
			p.amount = amount(120, quality); p.lifetime = 1.6
			m.direction = Vector3.UP; m.spread = 25.0
			m.initial_velocity_min = 4.0; m.initial_velocity_max = 9.0
			m.gravity = Vector3(0, -9.8, 0) + w * 0.3
			p.draw_pass_1 = _quad(0.08, Color("#ffb040"), 6.0)
		"star_dust":
			p.amount = amount(600, quality); p.lifetime = 8.0
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 18.0
			m.gravity = Vector3(0, 0.15, 0) + w * 0.2
			m.turbulence_enabled = quality > 0
			m.turbulence_noise_strength = 0.4
			m.hue_variation_min = -0.1; m.hue_variation_max = 0.1
			p.draw_pass_1 = _quad(0.05, Color("#ff7ae8"), 3.0)
			p.position = Vector3(0, 3, 0)
		"footstep_dust":
			p.amount = amount(24, quality); p.lifetime = 0.8
			p.emitting = false; p.one_shot = false
			m.direction = Vector3(0, 1, 0); m.spread = 70.0
			m.initial_velocity_min = 0.4; m.initial_velocity_max = 1.2
			m.gravity = Vector3(0, -0.6, 0) + w * 0.3
			m.scale_min = 1.0; m.scale_max = 2.5
			p.draw_pass_1 = _quad(0.18, Color(0.85, 0.85, 0.9, 0.45), 0.0, false)
		"bolt_trail":
			p.amount = amount(60, quality); p.lifetime = 0.5
			p.local_coords = false
			m.spread = 180.0; m.initial_velocity_max = 0.6
			m.gravity = Vector3(0, 0.8, 0)
			p.draw_pass_1 = _quad(0.16, Color("#ff5a1a"), 5.0)
		"bolt_impact":
			p.amount = amount(70, quality); p.lifetime = 0.7
			p.one_shot = true; p.explosiveness = 1.0
			m.spread = 180.0; m.initial_velocity_min = 3.0; m.initial_velocity_max = 8.0
			m.gravity = Vector3(0, -6, 0)
			p.draw_pass_1 = _quad(0.12, Color("#ff2fd0"), 6.0)
		"wing_sparkle":
			p.amount = amount(50, quality); p.lifetime = 1.2
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(0.7, 0.4, 0.05)
			m.gravity = Vector3(0, -0.4, 0)
			p.local_coords = false
			p.draw_pass_1 = _quad(0.04, Color("#ffd86a"), 5.0)
		_:
			return null
	p.process_material = m
	p.visibility_aabb = AABB(Vector3(-30, -15, -30), Vector3(60, 40, 60))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Which ambient effects each biome uses (0 Alaska, 1 Venus, 2 Cosmic).
static func biome_effects(biome: int) -> Array:
	return [["snow"], ["embers", "ash"], ["star_dust"]][clampi(biome, 0, 2)]
