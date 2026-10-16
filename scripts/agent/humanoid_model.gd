class_name HumanoidModel
extends RefCounted
## v0.3 SMOOTH procedural humanoid (no cubes). Built from capsules, spheres, tapered cylinders
## and tori with PBR materials (leather, sequins, gold, skin with subsurface tint, hair sheen).
## Zero asset bytes, original design. Part names are stable for animate() and tests:
##   Hips, Hips/Torso, Hips/Torso/Head, Head/Face, ArmL/ArmR (+Fore), LegL/LegR (+Shin).
## style keys: skin, hair, eyes, outfit, accent, trim, look ("fire"|"classic"|"chrome"|"royal"|
## "phoenix"), glow, pants, horns, curly, chains, plus phoenix keys: hair_streaks (Array[Color]),
## beard (Color), jacket, top, earrings, choker, pendants.

static var _cache := {}

static func _mat(c: Color, glow := 0.0, metal := 0.0, rough := -1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), glow, metal, rough]
	if _cache.has(key): return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough if rough >= 0.0 else (0.28 if metal > 0.5 else 0.6)
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_cache[key] = m
	return m

static func _skin_mat(c: Color, metal: float) -> StandardMaterial3D:
	var m := _mat(c, 0.0, metal, 0.45 if metal < 0.5 else 0.25).duplicate()
	m.rim = 0.4
	m.rim_tint = 0.2
	m.backlight_enabled = metal < 0.5
	m.backlight = Color(0.5, 0.15, 0.08)
	return m

static func _hair_mat(c: Color, glow: float) -> StandardMaterial3D:
	var m := _mat(c, glow, 0.15, 0.35).duplicate()
	m.anisotropy_enabled = true
	m.anisotropy = 0.7
	return m

static func _mi(parent: Node3D, n: String, mesh: Mesh, pos: Vector3, mat: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = n
	mi.position = pos
	mi.scale = scl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _capsule(r: float, h: float, seg := 12) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = seg
	c.rings = 4
	return c

static func _sphere(r: float, seg := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s

static func _cyl(top: float, bottom: float, h: float, seg := 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func _torus(r: float, thick: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - thick
	t.outer_radius = r
	t.rings = 24
	t.ring_segments = 6
	return t

## Two-segment limb: pivot (upper) -> child "Fore"/"Shin" pivot (lower) -> hand/foot.
static func _limb(parent: Node3D, n: String, pivot: Vector3, upper: float, lower: float, r: float, mat: Material, lower_mat: Material, end_mat: Material, is_leg: bool) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pivot
	parent.add_child(p)
	_mi(p, "Seg", _cyl(r, r * 0.82, upper), Vector3(0, -upper * 0.5, 0), mat)
	_mi(p, "Joint", _sphere(r * 0.86, 10), Vector3(0, -upper, 0), lower_mat)
	var low := Node3D.new()
	low.name = "Shin" if is_leg else "Fore"
	low.position = Vector3(0, -upper, 0)
	p.add_child(low)
	_mi(low, "Seg", _cyl(r * 0.82, r * 0.62, lower), Vector3(0, -lower * 0.5, 0), lower_mat)
	if is_leg:  # boot
		_mi(low, "End", _capsule(r * 0.72, r * 3.2, 10), Vector3(0, -lower - r * 0.3, -r * 0.6), end_mat).rotation.x = PI / 2
	else:  # hand
		_mi(low, "End", _sphere(r * 0.75, 10), Vector3(0, -lower - r * 0.4, 0), end_mat, Vector3(0.8, 1.25, 0.6))
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
	var phoenix := look == "phoenix" or style.has("hair_streaks")
	var pants: Color = style.get("pants", outfit)
	var masc := bool(style.get("masculine", phoenix))
	var skin_m := _skin_mat(skin, float(style.get("skin_metal", 0.9 if chrome else 0.0)))
	var leather := _mat(outfit, 0.0, 0.1 if not chrome else 0.85, 0.32)
	var pants_m := _mat(pants, style.get("pants_glow", 0.0), 0.15, 0.35)
	var accent_m := _mat(accent, glow, 0.3, 0.3)
	var gold_m := _mat(trim, 0.35, 1.0, 0.22)
	var hair_m := _hair_mat(hair, 0.35 if look in ["fire", "chrome"] else 0.0)
	var top_c: Color = style.get("top", accent)
	var sequin_m := _mat(top_c, 0.6, 0.85, 0.18)
	var sh := 0.21 if masc else 0.18  # shoulder half-width

	var root := Node3D.new()
	root.name = "Model"
	var hips := Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0, 0.9, 0)
	root.add_child(hips)
	_mi(hips, "Pelvis", _sphere(0.16, 14), Vector3(0, 0.02, 0), pants_m, Vector3(1.05 if masc else 1.15, 0.7, 0.75))
	var torso := Node3D.new()
	torso.name = "Torso"
	hips.add_child(torso)
	# Torso: tapered chest + waist, smooth
	_mi(torso, "Waist", _cyl(0.15, 0.15, 0.22), Vector3(0, 0.15, 0), sequin_m if phoenix else leather, Vector3(1.0, 1, 0.72))
	_mi(torso, "Chest", _capsule(sh * 0.82, 0.44, 16), Vector3(0, 0.4, 0), sequin_m if phoenix else leather, Vector3(1.05, 1, 0.62))
	if not masc:
		_mi(torso, "Bust", _capsule(0.07, 0.24, 10), Vector3(0, 0.43, -0.07), leather, Vector3(1, 1, 0.8)).rotation.z = PI / 2
	_mi(torso, "Belt", _torus(0.165, 0.025), Vector3(0, 0.06, 0), gold_m, Vector3(1, 1, 0.75))
	_mi(torso, "Neck", _cyl(0.05, 0.06, 0.12), Vector3(0, 0.66, 0), skin_m)
	# Head
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.7, 0)
	torso.add_child(head)
	_mi(head, "Face", _sphere(0.115, 20), Vector3(0, 0.13, 0), skin_m, Vector3(0.88, 1.08, 0.98))
	_mi(head, "Jaw", _sphere(0.085, 14), Vector3(0, 0.06, -0.025), skin_m, Vector3(1.0 if masc else 0.9, 0.8, 1.0))
	_mi(head, "Nose", _capsule(0.014, 0.05, 6), Vector3(0, 0.12, -0.112), skin_m).rotation.x = -0.25
	var eye_white := _mat(Color(0.92, 0.9, 0.88), 0.0, 0.0, 0.2)
	var iris_m := _mat(eyes, 0.9, 0.0, 0.1)
	var liner := _mat(Color(0.03, 0.02, 0.03), 0.0, 0.0, 0.6)
	for side in [-1.0, 1.0]:
		var nm := "L" if side < 0 else "R"
		_mi(head, "EyeWhite" + nm, _sphere(0.018, 10), Vector3(0.038 * side, 0.15, -0.093), eye_white, Vector3(1.3, 0.8, 0.6))
		_mi(head, "Eye" + nm, _sphere(0.011, 8), Vector3(0.038 * side, 0.15, -0.104), iris_m)
		_mi(head, "Liner" + nm, _capsule(0.005, 0.05, 6), Vector3(0.038 * side, 0.162, -0.1), liner).rotation.z = PI / 2 + 0.15 * side
		_mi(head, "Brow" + nm, _capsule(0.008 if masc else 0.005, 0.05, 6), Vector3(0.04 * side, 0.18, -0.1), _mat(hair.darkened(0.4))).rotation.z = PI / 2 - 0.2 * side
		_mi(head, "Ear" + nm, _sphere(0.022, 8), Vector3(0.1 * side, 0.13, 0.0), skin_m, Vector3(0.5, 1.0, 0.8))
	_mi(head, "Lips", _capsule(0.011, 0.045, 6), Vector3(0, 0.068, -0.103), _mat(skin.darkened(0.25), 0.0, 0.0, 0.4)).rotation.z = PI / 2
	# Hair: scalp cap + flowing strands (smooth capsules, streak colors)
	var streaks: Array = style.get("hair_streaks", [hair])
	_mi(head, "HairTop", _sphere(0.125, 16), Vector3(0, 0.16, 0.012), hair_m, Vector3(0.95, 0.95, 1.0))
	var long := look in ["fire", "classic", "phoenix"] or phoenix
	var strands := 26 if long else 12
	for i in strands:
		var a := lerpf(-2.3, 2.3, float(i) / float(strands - 1))  # around sides/back
		var length := (0.42 if long else 0.18) + 0.08 * sin(i * 2.3)
		var col: Color = streaks[i % streaks.size()]
		var st := _mi(head, "Strand%d" % i, _capsule(0.03, length, 8), Vector3(sin(a) * 0.11, 0.15 - length * 0.38, cos(a) * 0.1 + 0.015), _hair_mat(col, 0.15 if phoenix else 0.0))
		st.rotation = Vector3(-cos(a) * 0.18 + 0.05 * sin(i * 1.7), 0, sin(a) * 0.22 + 0.06 * cos(i * 3.1))
		if phoenix:  # wild wavy: second offset layer
			var w := _mi(st, "Wave", _capsule(0.022, length * 0.6, 6), Vector3(0.02 * sin(i), -length * 0.35, 0.01), st.material_override)
			w.rotation.z = 0.25 * sin(i * 1.3)
	if phoenix:  # wild fringe framing the face
		for i in 6:
			var s := -1.0 if i % 2 == 0 else 1.0
			_mi(head, "Fringe%d" % i, _capsule(0.02, 0.2, 6), Vector3(s * (0.07 + 0.012 * i), 0.15, -0.075), _hair_mat(streaks[(i + 2) % streaks.size()], 0.15)).rotation = Vector3(-0.3, 0, s * (0.25 + 0.05 * i))
	# Arms / legs
	var sleeve := _mat(outfit, 0.0, 0.1, 0.32) if phoenix else (leather if not chrome else skin_m)
	_limb(torso, "ArmL", Vector3(-sh - 0.04, 0.58, 0), 0.28, 0.26, 0.05 if masc else 0.042, sleeve, sleeve if phoenix else skin_m, skin_m, false)
	_limb(torso, "ArmR", Vector3(sh + 0.04, 0.58, 0), 0.28, 0.26, 0.05 if masc else 0.042, sleeve, sleeve if phoenix else skin_m, skin_m, false)
	_limb(hips, "LegL", Vector3(-0.09, -0.02, 0), 0.42, 0.4, 0.075 if masc else 0.068, pants_m, pants_m, _mat(Color(0.03, 0.03, 0.035), 0.0, 0.3, 0.25), true)
	_limb(hips, "LegR", Vector3(0.09, -0.02, 0), 0.42, 0.4, 0.075 if masc else 0.068, pants_m, pants_m, _mat(Color(0.03, 0.03, 0.035), 0.0, 0.3, 0.25), true)
	for nm in ["ArmL", "ArmR"]:
		_mi(torso.get_node(nm), "Shoulder", _sphere(0.065 if masc else 0.055, 12), Vector3.ZERO, sleeve)
	if style.get("horns", false):
		for s in [-1.0, 1.0]:
			_mi(head, "Horn" + ("L" if s < 0 else "R"), _cyl(0.003, 0.022, 0.16, 8), Vector3(0.06 * s, 0.29, -0.01), gold_m).rotation.z = -0.4 * s
	if style.get("curly", false):
		for i in 16:
			var a := TAU * i / 16.0
			_mi(head, "Curl%d" % i, _sphere(0.06, 10), Vector3(cos(a) * 0.12, 0.2 + sin(i * 1.7) * 0.06, sin(a) * 0.11 + 0.02), hair_m)
	if style.get("chains", false) or phoenix:
		for i in 3:
			_mi(torso, "Chain%d" % i, _torus(0.1 + i * 0.022, 0.006), Vector3(0, 0.6 - i * 0.04, -0.03 - i * 0.012), gold_m, Vector3(1, 1, 0.8)).rotation.x = 1.2
	if phoenix:
		_build_phoenix_extras(head, torso, hips, style, gold_m, leather, accent_m, trim)
	match look:
		"fire":
			for i in 3:
				_mi(head, "Flame%d" % i, _cyl(0.0, 0.025, 0.12 + i * 0.03, 8), Vector3(-0.05 + i * 0.05, 0.29 + i * 0.01, -0.02), _mat(Color(1, 0.35 + i * 0.15, 0.1), 3.0))
		"chrome":
			for i in 4:
				_mi(torso, "Circuit%d" % i, _torus(0.16, 0.006), Vector3(0, 0.22 + i * 0.1, 0), accent_m, Vector3(1.05, 1, 0.65))
			_mi(head, "Visor", _torus(0.12, 0.01), Vector3(0, 0.18, 0), accent_m)
		"royal", "phoenix":
			if look == "royal" or style.get("crown", false):
				var crown_m := _mat(trim, 1.2, 1.0, 0.15)
				_mi(head, "CrownBand", _torus(0.12, 0.018), Vector3(0, 0.26, 0.01), crown_m, Vector3(1, 2.2, 1))
				for i in 5:
					var a := TAU * i / 5.0
					_mi(head, "CrownPoint%d" % i, _cyl(0.0, 0.018, 0.07, 6), Vector3(sin(a) * 0.115, 0.31, cos(a) * 0.115 + 0.01), crown_m)
				_mi(head, "CrownGem", _sphere(0.018, 8), Vector3(0, 0.27, -0.12), accent_m)
			if look == "royal":
				_mi(torso, "Cape", _cyl(0.24, 0.32, 1.0, 16), Vector3(0, 0.1, 0.06), _mat(accent.darkened(0.35), 0.0, 0.1, 0.5), Vector3(1, 1, 0.45))
				for s in [-1.0, 1.0]:
					_mi(torso, "Pauldron" + ("L" if s < 0 else "R"), _sphere(0.08, 12), Vector3((sh + 0.04) * s, 0.6, 0), gold_m, Vector3(1.1, 0.6, 1.1))
	return root

## Phoenix (player) specifics from art/references/player_phoenix: goatee, gold hoops, studded
## choker, dragon + scorpion pendants, open black moto jacket w/ gold studs + embroidery.
static func _build_phoenix_extras(head: Node3D, torso: Node3D, hips: Node3D, style: Dictionary, gold_m: Material, leather: Material, accent_m: Material, trim: Color) -> void:
	var beard_m := _hair_mat(style.get("beard", Color(0.03, 0.02, 0.02)), 0.0)
	_mi(head, "Goatee", _cyl(0.028, 0.004, 0.1, 10), Vector3(0, 0.0, -0.085), beard_m).rotation.x = 0.15
	_mi(head, "Mustache", _capsule(0.007, 0.06, 6), Vector3(0, 0.085, -0.105), beard_m).rotation.z = PI / 2
	for s in [-1.0, 1.0]:
		_mi(head, "Hoop" + ("L" if s < 0 else "R"), _torus(0.02, 0.003), Vector3(0.105 * s, 0.09, -0.005), gold_m).rotation.z = PI / 2
	var black := _mat(Color(0.02, 0.02, 0.02), 0.0, 0.2, 0.3)
	_mi(torso, "Choker", _torus(0.058, 0.012), Vector3(0, 0.68, 0), black, Vector3(1, 1.6, 1))
	for i in 8:
		var a := lerpf(-1.3, 1.3, i / 7.0)
		_mi(torso, "ChokerStud%d" % i, _sphere(0.006, 6), Vector3(sin(a) * 0.06, 0.68, -cos(a) * 0.06), gold_m)
	_mi(torso, "DragonPendant", _torus(0.025, 0.008), Vector3(0, 0.47, -0.135), gold_m).rotation.x = PI / 2
	_mi(torso, "DragonPendantGem", _sphere(0.012, 8), Vector3(0, 0.47, -0.14), accent_m)
	_mi(torso, "ScorpionPendant", _capsule(0.012, 0.06, 6), Vector3(0.03, 0.4, -0.14), gold_m).rotation.z = 0.5
	# Open moto jacket: two front panels + back over the sequin top
	var jacket_m := _mat(style.get("jacket", Color(0.03, 0.025, 0.03)), 0.0, 0.15, 0.3)
	for s in [-1.0, 1.0]:
		var nm := "L" if s < 0 else "R"
		var p := _mi(torso, "Jacket" + nm, _capsule(0.1, 0.5, 10), Vector3(0.1 * s, 0.38, -0.04), jacket_m, Vector3(1, 1, 0.75))
		p.rotation.z = 0.1 * s
		_mi(torso, "Lapel" + nm, _capsule(0.02, 0.26, 6), Vector3(0.06 * s, 0.5, -0.11), jacket_m).rotation.z = 0.45 * s
		for i in 4:  # gold studs on shoulders
			_mi(torso, "Stud%s%d" % [nm, i], _sphere(0.008, 6), Vector3((0.13 + i * 0.025) * s, 0.63 - i * 0.004, -0.04), gold_m)
		# gold phoenix/dragon embroidery: flowing emissive curves on the jacket
		for i in 3:
			_mi(torso, "Embroidery%s%d" % [nm, i], _capsule(0.006, 0.12, 6), Vector3(0.16 * s, 0.25 + i * 0.08, -0.09), _mat(trim, 0.8, 1.0, 0.2)).rotation.z = (0.6 - i * 0.4) * s
	_mi(torso, "JacketBack", _capsule(0.2, 0.52, 12), Vector3(0, 0.38, 0.04), jacket_m, Vector3(1.05, 1, 0.5))
	for i in 2:  # gold chain belts
		_mi(hips, "ChainBelt%d" % i, _torus(0.17 + i * 0.01, 0.006), Vector3(0, 0.0 - i * 0.04, 0), gold_m, Vector3(1, 1, 0.75)).rotation.z = 0.06 * (1 - 2 * i)

## Idle breathing + walk cycle. speed01 = 0 idle .. 1 full run.
static func animate(model: Node3D, t: float, speed01: float) -> void:
	if model == null: return
	var hips := model.get_node_or_null("Hips") as Node3D
	if hips == null: return
	var ph := t * 8.0
	var swing := sin(ph) * 0.6 * speed01
	hips.position.y = 0.9 + sin(t * 2.0) * 0.01 + absf(sin(ph)) * 0.03 * speed01
	hips.rotation.y = sin(ph) * 0.08 * speed01
	var torso := hips.get_node("Torso") as Node3D
	torso.rotation.y = -sin(ph) * 0.12 * speed01
	torso.rotation.z = sin(t * 1.3) * 0.02 * (1.0 - speed01)
	torso.scale.y = 1.0 + sin(t * 2.0) * 0.006
	torso.get_node("Head").rotation.y = sin(t * 0.7) * 0.2 * (1.0 - speed01)
	var al := torso.get_node("ArmL") as Node3D
	var ar := torso.get_node("ArmR") as Node3D
	al.rotation = Vector3(swing + sin(t * 2.0) * 0.04, 0, -0.1)
	ar.rotation = Vector3(-swing - sin(t * 2.0) * 0.04, 0, 0.1)
	al.get_node("Fore").rotation.x = -0.25 - maxf(swing, 0.0) * 0.6
	ar.get_node("Fore").rotation.x = -0.25 - maxf(-swing, 0.0) * 0.6
	var ll := hips.get_node("LegL") as Node3D
	var lr := hips.get_node("LegR") as Node3D
	ll.rotation.x = -swing
	lr.rotation.x = swing
	ll.get_node("Shin").rotation.x = maxf(sin(ph + 1.2), 0.0) * 0.9 * speed01
	lr.get_node("Shin").rotation.x = maxf(sin(ph + PI + 1.2), 0.0) * 0.9 * speed01
