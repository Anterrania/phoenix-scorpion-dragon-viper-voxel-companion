class_name HumanoidModel
extends RefCounted
## Procedural low-poly humanoid (original designs, ~20 primitive meshes, zero asset bytes).
## build(style) returns a Node3D whose parts are named for animate(): Hips, Torso, Head,
## ArmL, ArmR, LegL, LegR. style keys: skin, hair, eyes, outfit, accent, trim, look
## ("fire" | "classic" | "chrome" | "royal"), glow (accent emission). Restyle by editing style.

static func _mat(c: Color, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.35 if metal > 0.0 else 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m

static func _box(parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.name = n
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _limb(parent: Node3D, n: String, pivot: Vector3, length: float, w: float, mat: Material, end_mat: Material) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pivot
	parent.add_child(p)
	_box(p, "Seg", Vector3(w, length, w), Vector3(0, -length * 0.5, 0), mat)
	_box(p, "End", Vector3(w * 1.05, w, w * 1.15), Vector3(0, -length, 0), end_mat)
	return p

static func build(style: Dictionary) -> Node3D:
	var skin: Color = style.get("skin", Color(0.96, 0.8, 0.7))
	var hair: Color = style.get("hair", Color(0.5, 0.2, 0.7))
	var eyes: Color = style.get("eyes", Color(0.2, 1, 0.4))
	var outfit: Color = style.get("outfit", Color(0.08, 0.06, 0.1))
	var accent: Color = style.get("accent", Color(1, 0.18, 0.82))
	var trim: Color = style.get("trim", Color(1, 0.76, 0.23))
	var look: String = style.get("look", "classic")
	var glow: float = style.get("glow", 1.0)
	var chrome := look == "chrome"
	var skin_m := _mat(skin, 0.0, 0.9 if chrome else 0.0)
	var outfit_m := _mat(outfit, 0.0, 0.8 if chrome else 0.0)
	var accent_m := _mat(accent, glow)
	var trim_m := _mat(trim, 0.6, 0.9)
	var hair_m := _mat(hair, 0.4 if look in ["fire", "chrome"] else 0.0)

	var root := Node3D.new()
	root.name = "Model"
	var hips := Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0, 0.9, 0)
	root.add_child(hips)
	var torso := Node3D.new()
	torso.name = "Torso"
	hips.add_child(torso)
	_box(torso, "Chest", Vector3(0.46, 0.55, 0.26), Vector3(0, 0.3, 0), outfit_m)
	_box(torso, "Belt", Vector3(0.48, 0.07, 0.28), Vector3(0, 0.05, 0), trim_m)
	_box(torso, "Sash", Vector3(0.08, 0.5, 0.27), Vector3(0.1, 0.32, 0.005), accent_m)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.68, 0)
	torso.add_child(head)
	_box(head, "Face", Vector3(0.3, 0.32, 0.3), Vector3(0, 0.16, 0), skin_m)
	_box(head, "EyeL", Vector3(0.06, 0.05, 0.02), Vector3(-0.07, 0.18, -0.15), _mat(eyes, 2.0))
	_box(head, "EyeR", Vector3(0.06, 0.05, 0.02), Vector3(0.07, 0.18, -0.15), _mat(eyes, 2.0))
	_box(head, "HairTop", Vector3(0.34, 0.1, 0.34), Vector3(0, 0.34, 0.01), hair_m)
	_box(head, "HairBack", Vector3(0.34, 0.5 if look != "royal" else 0.3, 0.08), Vector3(0, 0.1, 0.17), hair_m)
	# Torso arms/legs
	_limb(torso, "ArmL", Vector3(-0.3, 0.55, 0), 0.55, 0.12, outfit_m, skin_m)
	_limb(torso, "ArmR", Vector3(0.3, 0.55, 0), 0.55, 0.12, outfit_m, skin_m)
	_limb(hips, "LegL", Vector3(-0.12, 0, 0), 0.82, 0.15, outfit_m, trim_m)
	_limb(hips, "LegR", Vector3(0.12, 0, 0), 0.82, 0.15, outfit_m, trim_m)
	match look:
		"fire":  # Foxy: long magenta-violet hair + ember flame crown
			_box(head, "HairSideL", Vector3(0.07, 0.45, 0.3), Vector3(-0.18, 0.05, 0.03), hair_m)
			_box(head, "HairSideR", Vector3(0.07, 0.45, 0.3), Vector3(0.18, 0.05, 0.03), hair_m)
			for i in 3:
				_box(head, "Flame%d" % i, Vector3(0.07, 0.16 + i * 0.05, 0.07), Vector3(-0.1 + i * 0.1, 0.45 + i * 0.02, 0), _mat(Color(1, 0.35 + i * 0.15, 0.1), 3.0))
		"classic":  # Aaliyah: flowing red hair
			_box(head, "HairSideL", Vector3(0.07, 0.6, 0.3), Vector3(-0.18, -0.02, 0.03), hair_m)
			_box(head, "HairSideR", Vector3(0.07, 0.6, 0.3), Vector3(0.18, -0.02, 0.03), hair_m)
		"chrome":  # Circuit Nova: blue circuit lines
			for i in 4:
				_box(torso, "Circuit%d" % i, Vector3(0.47, 0.025, 0.27), Vector3(0, 0.12 + i * 0.13, 0), accent_m)
			_box(head, "Visor", Vector3(0.31, 0.03, 0.31), Vector3(0, 0.26, 0), accent_m)
		"royal":  # Anterranian sovereign: crown, cape, phoenix/dragon crest, glitter studs
			var crown_m := _mat(trim, 1.4, 1.0)
			_box(head, "CrownBand", Vector3(0.36, 0.07, 0.36), Vector3(0, 0.42, 0), crown_m)
			for i in 5:
				var a := TAU * i / 5.0
				_box(head, "CrownPoint%d" % i, Vector3(0.05, 0.12, 0.05), Vector3(sin(a) * 0.15, 0.5, cos(a) * 0.15), crown_m)
			_box(head, "CrownGem", Vector3(0.06, 0.06, 0.02), Vector3(0, 0.43, -0.19), accent_m)
			_box(torso, "Cape", Vector3(0.52, 1.0, 0.04), Vector3(0, 0.05, 0.16), _mat(accent.darkened(0.35)))
			_box(torso, "CapeLining", Vector3(0.5, 0.98, 0.02), Vector3(0, 0.05, 0.135), _mat(Color("#dfe6f2"), 0.3, 1.0))
			_box(torso, "PauldronL", Vector3(0.18, 0.08, 0.3), Vector3(-0.3, 0.6, 0), trim_m)
			_box(torso, "PauldronR", Vector3(0.18, 0.08, 0.3), Vector3(0.3, 0.6, 0), trim_m)
			# phoenix wings crest on chest (gold V) + dragon eye gem (magenta)
			_box(torso, "CrestWingL", Vector3(0.14, 0.04, 0.02), Vector3(-0.07, 0.42, -0.14), trim_m).rotation.z = 0.5
			_box(torso, "CrestWingR", Vector3(0.14, 0.04, 0.02), Vector3(0.07, 0.42, -0.14), trim_m).rotation.z = -0.5
			_box(torso, "CrestGem", Vector3(0.06, 0.06, 0.02), Vector3(0, 0.36, -0.14), accent_m)
			for i in 6:  # platinum glitter studs
				_box(torso, "Glitter%d" % i, Vector3(0.025, 0.025, 0.01), Vector3(-0.17 + i * 0.068, 0.15 + (i % 2) * 0.1, -0.135), _mat(Color("#ffffff"), 3.0, 1.0))
	return root

## Idle breathing + walk cycle. speed01 = 0 idle .. 1 full run.
static func animate(model: Node3D, t: float, speed01: float) -> void:
	if model == null: return
	var hips := model.get_node_or_null("Hips") as Node3D
	if hips == null: return
	var swing := sin(t * 9.0) * 0.7 * speed01
	hips.position.y = 0.9 + sin(t * 2.0) * 0.015 + absf(sin(t * 9.0)) * 0.04 * speed01
	var torso := hips.get_node("Torso") as Node3D
	torso.rotation.z = sin(t * 1.3) * 0.03 * (1.0 - speed01)
	torso.get_node("Head").rotation.y = sin(t * 0.7) * 0.2 * (1.0 - speed01)
	torso.get_node("ArmL").rotation.x = swing + sin(t * 2.0) * 0.05
	torso.get_node("ArmR").rotation.x = -swing - sin(t * 2.0) * 0.05
	torso.get_node("ArmL").rotation.z = -0.08
	torso.get_node("ArmR").rotation.z = 0.08
	hips.get_node("LegL").rotation.x = -swing
	hips.get_node("LegR").rotation.x = swing
