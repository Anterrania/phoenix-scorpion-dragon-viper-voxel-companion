class_name RealisticBody
extends RefCounted
## v0.11 realistic companion body: CC0 MakeHuman/MPFB rigged human (assets/characters/mh_female.glb,
## see art/LICENSES.md) dressed + recolored from CompanionDNA style. Skin/hair/eye shaders in
## shaders/character/. Same interface as HumanoidModel: build(style) -> Node3D "Model", animate().
## Godot's importer generates mesh LODs automatically, so distant companions are cheap.

const FEMALE := "res://assets/characters/default_female.glb"
const MALE := "res://assets/characters/phoenix_player.glb"
const OUTFIT := preload("res://shaders/character/outfit.gdshader")
const SKIN_N := "res://assets/characters/skin_detail_n.png"
const SKIN_R := "res://assets/characters/skin_detail_r.png"
const HAIR_N := "res://assets/characters/hair_strand_n.png"
const HAIR_M := "res://assets/characters/hair_strand_mask.png"

## Per-character CC0 GLB (generated from avatar_dna.face by tools/mh/gen_makehuman.py), else the
## shared male/female base.
static func glb_for(style: Dictionary) -> String:
	var id := str(style.get("body_id", ""))
	var p := "res://assets/characters/%s.glb" % id
	if id != "" and ResourceLoader.exists(p): return p
	return MALE if bool(style.get("masculine", false)) else FEMALE
const EYE_TEX := "res://assets/characters/mh_eye.png"
const SKIN := preload("res://shaders/character/skin.gdshader")
const HAIR := preload("res://shaders/character/hair.gdshader")
const EYE := preload("res://shaders/character/eye.gdshader")

## v0.12 player defaults on the MakeHuman male base (owner look). Only fills keys the save lacks,
## so older saves load unchanged and nothing new is written to the save format.
static func player_style(st: Dictionary) -> Dictionary:
	var o := st.duplicate()
	if not o.has("body_id"): o["body_id"] = "phoenix_player"
	if not o.has("masculine"): o["masculine"] = true
	if not o.has("player_jewelry"): o["player_jewelry"] = true
	if not o.has("outfit_look"): o["outfit_look"] = {"top": "#0a0809", "bottom": "#0b0a0c", "studs": 0.8}
	return o

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
	var body: Node3D = load(glb_for(style)).instantiate()
	body.name = "Body"
	body.rotation.y = PI  # MakeHuman faces +Z; our models face -Z
	root.add_child(body)
	var skin: Color = style.get("skin", Color(0.9, 0.75, 0.65))
	var metal := float(style.get("skin_metal", 0.0))
	var chrome := metal > 0.5 or str(style.get("look", "")) == "chrome"
	var grad: Array = style.get("hair_gradient", [style.get("hair", Color(0.3, 0.15, 0.1))])
	var curly := bool(style.get("curly", false))
	var aura := str(style.get("aura", ""))
	var eye_y := 1.55
	for e in body.find_children("*", "MeshInstance3D", true, false):
		var en: String = e.name.to_lower()
		if (en.contains("low-poly") or en.contains("low_poly")) and (e as MeshInstance3D).mesh:
			eye_y = (e as MeshInstance3D).mesh.get_aabb().get_center().y
	body.set_meta("eye_y", eye_y)
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
			s.set_shader_parameter("eye_y", eye_y)
			s.set_shader_parameter("detail_n", load(SKIN_N)); s.set_shader_parameter("detail_r", load(SKIN_R))
			if style.has("beard"):
				s.set_shader_parameter("goatee", 1.0); s.set_shader_parameter("goatee_color", style["beard"])
			if chrome:  # v0.12: silver-blue chrome that stays blue in bright snow light
				s.set_shader_parameter("tint", Color(0.42, 0.52, 0.7)); s.set_shader_parameter("tint_mix", 0.9)
				s.set_shader_parameter("metal", 0.6); s.set_shader_parameter("rough", 0.38); s.set_shader_parameter("sss", 0.05)
			mat = s
		elif n.contains("long01") or n.contains("afro01"):
			mi.visible = n.contains("afro01") == curly
			var h := _sm(HAIR, tex)
			h.set_shader_parameter("root_color", grad[0])
			h.set_shader_parameter("tip_color", grad[grad.size() - 1])
			h.set_shader_parameter("top_y", 1.67)
			h.set_shader_parameter("tip_y", 1.46 if curly else 0.95)
			h.set_shader_parameter("glow", 0.12 if aura != "" else 0.0)
			h.set_shader_parameter("strand_n", load(HAIR_N)); h.set_shader_parameter("strand_mask", load(HAIR_M))
			h.set_shader_parameter("strand_tiling", 14.0 if curly else 6.0)
			var streaks: Array = style.get("hair_streaks", [])
			if streaks.size() >= 2:
				var uniq: Array = []
				for c in streaks:
					if not uniq.has(c): uniq.append(c)
				h.set_shader_parameter("streak_count", mini(uniq.size(), 5))
				for k in mini(uniq.size(), 5): h.set_shader_parameter("streak%d" % k, uniq[k])
			if curly: h.set_shader_parameter("alpha_cut", 0.45)
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
		elif n.contains("suit"):
			var ol: Dictionary = style.get("outfit_look", {})
			var o := ShaderMaterial.new(); o.shader = OUTFIT
			o.set_shader_parameter("albedo_tex", tex)
			var male_suit := n.contains("male_") and not n.contains("female")
			o.set_shader_parameter("split_mode", 1.0 if male_suit else 0.0)
			o.set_shader_parameter("top_color", CompanionDNA._col(ol.get("top"), style.get("jacket", style.get("top", style.get("outfit", Color(0.05, 0.05, 0.06))))))
			o.set_shader_parameter("bottom_color", CompanionDNA._col(ol.get("bottom"), style.get("pants", style.get("outfit", Color(0.05, 0.05, 0.06)))))
			o.set_shader_parameter("top_sequin", float(ol.get("top_sequin", 0.0)))
			o.set_shader_parameter("bottom_sequin", float(ol.get("bottom_sequin", 0.0)))
			o.set_shader_parameter("sequin_color", CompanionDNA._col(ol.get("sequin"), style.get("top", Color(0.6, 0.2, 0.9))))
			o.set_shader_parameter("studs", float(ol.get("studs", 0.0)))
			o.set_shader_parameter("stud_color", style.get("trim", Color(1, 0.78, 0.25)))
			o.set_shader_parameter("circuit", 1.0 if aura == "circuit_glow" else 0.0)
			o.set_shader_parameter("circuit_color", style.get("accent", Color(0.2, 0.7, 1)))
			mat = o
		else:  # shoes / boots
			var o := StandardMaterial3D.new(); o.albedo_texture = tex
			o.albedo_color = Color(0.35, 0.33, 0.33)
			o.metallic = 0.1; o.roughness = 0.35
			mat = o
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if n == "human" or n.contains("suit") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rest_pose(body)
	if style.has("player_jewelry"): _jewelry(body, style)
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


## v0.12 player jewelry on bones: gold hoops, studded choker, gold chains with dragon + scorpion pendants.
static func _jewelry(body: Node3D, style: Dictionary) -> void:
	var sk := skeleton(body)
	if sk == null: return
	var gold := StandardMaterial3D.new(); gold.albedo_color = style.get("trim", Color(0.95, 0.74, 0.25)); gold.metallic = 1.0; gold.roughness = 0.22
	var black := StandardMaterial3D.new(); black.albedo_color = Color(0.02, 0.02, 0.02); black.roughness = 0.35
	var ruby := StandardMaterial3D.new(); ruby.albedo_color = Color(1, 0.18, 0.75); ruby.emission_enabled = true; ruby.emission = ruby.albedo_color; ruby.emission_energy_multiplier = 0.6
	var head := attach_point(sk, "head", Vector3.ZERO)
	for sd in [-1.0, 1.0]:
		var hoop := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.011; tm.outer_radius = 0.0135
		hoop.mesh = tm; hoop.material_override = gold; hoop.rotation.z = PI / 2; hoop.name = "Hoop" + ("L" if sd < 0 else "R")
		hoop.position = Vector3(0.074 * sd, 0.065, 0.0); head.add_child(hoop)
	var neck := attach_point(sk, "neck_01", Vector3.ZERO)
	var ch := MeshInstance3D.new(); var cm := TorusMesh.new(); cm.inner_radius = 0.052; cm.outer_radius = 0.062
	ch.mesh = cm; ch.material_override = black; ch.name = "Choker"; ch.position = Vector3(0, 0.035, 0.005); ch.scale = Vector3(1, 1.6, 0.95); neck.add_child(ch)
	for i in 10:
		var st := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.0045; sm.height = 0.009; st.mesh = sm; st.material_override = gold
		var a := lerpf(-1.3, 1.3, i / 9.0)
		st.position = Vector3(sin(a) * 0.06, 0.035, cos(a) * 0.058); neck.add_child(st)
	var chest := attach_point(sk, "spine_03", Vector3.ZERO)
	for k in 2:
		var ring := MeshInstance3D.new(); var rm := TorusMesh.new(); rm.inner_radius = 0.085 + k * 0.03; rm.outer_radius = rm.inner_radius + 0.005
		ring.mesh = rm; ring.material_override = gold; ring.name = "Chain%d" % k
		ring.position = Vector3(0, 0.18 - k * 0.04, 0.05 + k * 0.02); ring.rotation.x = 1.15; chest.add_child(ring)
		var pend := MeshInstance3D.new(); var pm: PrimitiveMesh
		if k == 0:
			var pr := PrismMesh.new(); pr.size = Vector3(0.03, 0.04, 0.008); pm = pr
		else:
			var cy := CylinderMesh.new(); cy.top_radius = 0.014; cy.bottom_radius = 0.0; cy.height = 0.045; pm = cy
		pend.mesh = pm; pend.material_override = gold; pend.name = "DragonPendant" if k == 0 else "ScorpionPendant"
		pend.position = Vector3(0, 0.1 - k * 0.07, 0.13 + k * 0.02); pend.rotation.z = PI if k == 0 else 0.0; chest.add_child(pend)
		var gem := MeshInstance3D.new(); var gm := SphereMesh.new(); gm.radius = 0.006; gm.height = 0.012; gem.mesh = gm; gem.material_override = ruby
		gem.position = pend.position + Vector3(0, 0, 0.006); chest.add_child(gem)
	var hips := attach_point(sk, "pelvis", Vector3.ZERO)
	for k in 2:
		var belt := MeshInstance3D.new(); var bm := TorusMesh.new(); bm.inner_radius = 0.165 + k * 0.01; bm.outer_radius = bm.inner_radius + 0.006
		belt.mesh = bm; belt.material_override = gold; belt.name = "ChainBelt%d" % k
		belt.position = Vector3(0, 0.07 - k * 0.035, 0.0); belt.scale = Vector3(1, 1, 0.72); belt.rotation.x = 0.08 * (k + 1); hips.add_child(belt)

## Node that follows a bone but keeps model-space axes (rest pose), so offsets are in model units
## (x right, y up, z = character front in MakeHuman space).
static func attach_point(sk: Skeleton3D, bone: String, offset: Vector3) -> Node3D:
	var i := sk.find_bone(bone)
	var ba := BoneAttachment3D.new(); ba.name = "BA_" + bone
	ba.bone_name = bone
	sk.add_child(ba)
	var holder := Node3D.new(); holder.name = "Holder"
	if i >= 0:
		var rb := sk.get_bone_global_rest(i).basis.orthonormalized()
		holder.transform = Transform3D(rb.inverse(), rb.inverse() * offset)
	ba.add_child(holder)
	return holder
