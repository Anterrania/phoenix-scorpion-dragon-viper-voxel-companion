class_name RealisticBody
extends RefCounted
## v0.11 realistic companion body: CC0 MakeHuman/MPFB rigged human (assets/characters/mh_female.glb,
## see art/LICENSES.md) dressed + recolored from CompanionDNA style. Skin/hair/eye shaders in
## shaders/character/. Same interface as HumanoidModel: build(style) -> Node3D "Model", animate().
## Godot's importer generates mesh LODs automatically, so distant companions are cheap.

const FEMALE := "res://assets/characters/mh_female.glb"
const EYE_TEX := "res://assets/characters/mh_eye.png"
const SKIN := preload("res://shaders/character/skin.gdshader")
const HAIR := preload("res://shaders/character/hair.gdshader")
const EYE := preload("res://shaders/character/eye.gdshader")

static func available() -> bool:
	return ResourceLoader.exists(FEMALE)

static func _tex_of(mi: MeshInstance3D) -> Texture2D:
	var m := mi.mesh.surface_get_material(0)
	return m.albedo_texture if m is BaseMaterial3D else null

static func _sm(sh: Shader, tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("albedo_tex", tex)
	return m

static func build(style: Dictionary) -> Node3D:
	var root := Node3D.new(); root.name = "Model"
	var body: Node3D = load(FEMALE).instantiate()
	body.name = "Body"
	body.rotation.y = PI  # MakeHuman faces +Z; our models face -Z
	root.add_child(body)
	var skin: Color = style.get("skin", Color(0.9, 0.75, 0.65))
	var metal := float(style.get("skin_metal", 0.0))
	var chrome := metal > 0.5 or str(style.get("look", "")) == "chrome"
	var grad: Array = style.get("hair_gradient", [style.get("hair", Color(0.3, 0.15, 0.1))])
	var curly := bool(style.get("curly", false))
	var aura := str(style.get("aura", ""))
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var n: String = mi.name.to_lower()
		var tex := _tex_of(mi)
		var mat: Material
		if n == "human":
			var s := _sm(SKIN, tex)
			s.set_shader_parameter("tint", skin.darkened(0.32) if chrome else skin)
			s.set_shader_parameter("tint_mix", 0.92 if chrome else 0.4)
			s.set_shader_parameter("metal", 0.35 if chrome else 0.0)
			s.set_shader_parameter("sss", 0.1 if chrome else 0.4)
			s.set_shader_parameter("freckles", 1.0 if style.get("freckles", false) else 0.0)
			s.set_shader_parameter("circuit", 1.0 if aura == "circuit_glow" else 0.0)
			s.set_shader_parameter("circuit_color", style.get("accent", Color(0.2, 0.7, 1)))
			mat = s
		elif n.contains("long01") or n.contains("afro01"):
			mi.visible = n.contains("afro01") == curly
			var h := _sm(HAIR, tex)
			h.set_shader_parameter("root_color", grad[0])
			h.set_shader_parameter("tip_color", grad[grad.size() - 1])
			h.set_shader_parameter("top_y", 1.67)
			h.set_shader_parameter("tip_y", 1.46 if curly else 0.95)
			h.set_shader_parameter("glow", 0.12 if aura != "" else 0.0)
			mat = h
		elif n.contains("low-poly") or n.contains("low_poly") or n.contains("eye"):
			if n.contains("eyebrow") or n.contains("eyelash"):
				var b := StandardMaterial3D.new(); b.albedo_texture = tex
				b.albedo_color = (grad[0] as Color).darkened(0.55) if n.contains("eyebrow") else Color(0.05, 0.03, 0.04)
				b.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; b.alpha_scissor_threshold = 0.3
				b.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat = b
			else:
				var e := _sm(EYE, load(EYE_TEX))
				e.set_shader_parameter("iris", style.get("eyes", Color(0.3, 0.6, 0.3)))
				e.set_shader_parameter("glow", 0.6 if chrome else 0.15)
				mat = e
		else:  # outfit + shoes: PBR, tinted toward DNA outfit/top colors
			var o := StandardMaterial3D.new(); o.albedo_texture = tex
			var oc: Color = style.get("top", style.get("outfit", Color.WHITE)) if n.contains("suit") else style.get("outfit", Color(0.1, 0.1, 0.1))
			o.albedo_color = oc.lightened(0.35)
			o.metallic = 0.35 if chrome else 0.05
			o.roughness = 0.45
			o.normal_enabled = false
			if n.contains("suit") and aura == "circuit_glow":
				o.emission_enabled = true; o.emission = (style.get("accent", Color(0.2, 0.7, 1)) as Color); o.emission_energy_multiplier = 0.25
			mat = o
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if n == "human" or n.contains("suit") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rest_pose(body)
	if aura == "phoenix_fire": _fire_aura(root)
	elif aura == "circuit_glow":
		var l := OmniLight3D.new(); l.name = "CircuitLight"; l.light_color = style.get("accent", Color(0.2, 0.7, 1)); l.light_energy = 0.35; l.omni_range = 1.6
		l.position.y = 1.2; root.add_child(l)
	root.set_meta("realistic", true)
	return root

static func skeleton(model: Node3D) -> Skeleton3D:
	var a := model.find_children("*", "Skeleton3D", true, false)
	return a[0] if not a.is_empty() else null

## A-pose -> relaxed arms at the sides.
static func _rest_pose(body: Node3D) -> void:
	var sk := skeleton(body)
	if sk == null: return
	sk.set_meta("rest_rot", {})
	for side in ["l", "r"]:
		var i := sk.find_bone("upperarm_" + side)
		if i < 0: continue
		var s := 1.0 if side == "l" else -1.0
		# rotate about the bone's parent-space forward axis to drop the arm ~50 degrees
		var par := sk.get_bone_parent(i)
		var pg: Basis = sk.get_bone_global_rest(par).basis.orthonormalized() if par >= 0 else Basis()
		var rest: Basis = sk.get_bone_rest(i).basis.orthonormalized()
		var nb: Basis = pg.inverse() * Basis(Vector3(0, 0, 1), deg_to_rad(-42.0) * s) * pg * rest
		var q := nb.get_rotation_quaternion()
		sk.set_bone_pose_rotation(i, q)
		sk.get_meta("rest_rot")["upperarm_" + side] = q

## Subtle phoenix aura: warm low light + a few soft additive embers rising from the shoulders.
static func _fire_aura(root: Node3D) -> void:
	var aura := Node3D.new(); aura.name = "Aura"; root.add_child(aura)
	var l := OmniLight3D.new(); l.name = "AuraLight"; l.light_color = Color(1, 0.5, 0.2); l.light_energy = 0.35; l.omni_range = 2.0
	l.position = Vector3(0, 1.0, 0.35); aura.add_child(l)
	var p := GPUParticles3D.new(); p.name = "Embers"; p.amount = 14; p.lifetime = 2.2; p.position.y = 1.15
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 0.28
	pm.direction = Vector3.UP; pm.spread = 30.0; pm.initial_velocity_min = 0.08; pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.12, 0); pm.scale_min = 0.6; pm.scale_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(1, 0.7, 0.3, 0), Color(1, 0.55, 0.2, 0.9), Color(1, 0.15, 0.55, 0)])
	var gt := GradientTexture1D.new(); gt.gradient = g; pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = SoftParticle.quad(0.035, true)
	aura.add_child(p)

## Procedural idle/walk on the rig (no baked clips needed).
static func animate(model: Node3D, t: float, speed01: float) -> void:
	var sk := skeleton(model)
	if sk == null: return
	var rr: Dictionary = sk.get_meta("rest_rot", {})
	var sw := sin(t * 7.0) * 0.55 * speed01
	var breathe := sin(t * 1.6) * 0.02
	for pair in [["thigh_l", sw], ["thigh_r", -sw], ["calf_l", maxf(0.0, -sw) * 0.9], ["calf_r", maxf(0.0, sw) * 0.9], ["spine_02", breathe]]:
		var i := sk.find_bone(pair[0])
		if i < 0: continue
		var q := sk.get_bone_rest(i).basis.get_rotation_quaternion()
		sk.set_bone_pose_rotation(i, q * Quaternion(Vector3(1, 0, 0), float(pair[1])))
	for side in ["l", "r"]:
		var i := sk.find_bone("upperarm_" + side)
		if i < 0 or not rr.has("upperarm_" + side): continue
		var a := (-sw if side == "l" else sw) * 0.6 + sin(t * 1.6) * 0.03
		sk.set_bone_pose_rotation(i, rr["upperarm_" + side] * Quaternion(Vector3(1, 0, 0), a))
