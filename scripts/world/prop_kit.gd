class_name PropKit
extends RefCounted
## v0.5 smooth (non-boxy) procedural props built from primitive meshes.
## Shared meshes/materials are cached so hundreds of props stay cheap on phones.

static var _mats := {}
static var _meshes := {}

static func mat(hex: String, emit := 0.0, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [hex, emit, metal, rough]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

static func sphere(r: float, seg := 10) -> SphereMesh:
	var k := "s%.2f_%d" % [r, seg]
	if not _meshes.has(k):
		var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = seg; s.rings = maxi(seg / 2, 4)
		_meshes[k] = s
	return _meshes[k]

static func cone(top: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	var k := "c%.2f_%.2f_%.2f_%d" % [top, bottom, h, seg]
	if not _meshes.has(k):
		var c := CylinderMesh.new(); c.top_radius = top; c.bottom_radius = bottom; c.height = h; c.radial_segments = seg; c.rings = 1
		_meshes[k] = c
	return _meshes[k]

static func torus(inner: float, outer: float) -> TorusMesh:
	var k := "t%.2f_%.2f" % [inner, outer]
	if not _meshes.has(k):
		var t := TorusMesh.new(); t.inner_radius = inner; t.outer_radius = outer; t.rings = 24; t.ring_segments = 10
		_meshes[k] = t
	return _meshes[k]

static func part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi

## Solid collider so the player can't walk through big props.
static func collider(parent: Node3D, shape: Shape3D, pos := Vector3.ZERO) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.position = pos
	sb.add_child(cs)
	parent.add_child(sb)

static func cyl_shape(r: float, h: float) -> CylinderShape3D:
	var s := CylinderShape3D.new(); s.radius = r; s.height = h
	return s

# ---------------- props ----------------
static func rock(rng: RandomNumberGenerator, tint := "#5a5466") -> Node3D:
	var n := Node3D.new(); n.name = "Rock"
	var s := rng.randf_range(0.6, 1.8)
	part(n, sphere(1.0, 9), mat(tint, 0.0, 0.05, 0.9), Vector3(0, 0.25 * s, 0), Vector3(s * rng.randf_range(0.9, 1.5), s * rng.randf_range(0.5, 0.8), s), Vector3(0, rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
	part(n, sphere(0.6, 8), mat(tint, 0.0, 0.05, 0.85), Vector3(0.7 * s, 0.1, 0.3 * s), Vector3.ONE * s * 0.8)
	if s > 1.1: collider(n, cyl_shape(s, s), Vector3(0, 0.4 * s, 0))
	return n

static func crystal_cluster(rng: RandomNumberGenerator, hex := "#ff2fd2") -> Node3D:
	var n := Node3D.new(); n.name = "CrystalCluster"
	var m := mat(hex, 2.2, 0.6, 0.12)
	for i in rng.randi_range(3, 6):
		var h := rng.randf_range(0.6, 2.2)
		part(n, cone(0.0, 0.22, 1.0, 6), m, Vector3(rng.randf_range(-0.5, 0.5), h * 0.45, rng.randf_range(-0.5, 0.5)), Vector3(1, h, 1), Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45)))
	return n

static func spruce(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new(); n.name = "Spruce"
	var h := rng.randf_range(4.0, 8.0)
	part(n, cone(0.12, 0.22, 1.0, 7), mat("#3a2618", 0.0, 0.0, 0.95), Vector3(0, h * 0.15, 0), Vector3(1, h * 0.3, 1))
	var needle := mat("#1d3a2c", 0.0, 0.0, 0.85)
	var snow := mat("#e8f0f8", 0.0, 0.0, 0.6)
	for i in 4:
		var t := float(i) / 4.0
		var r := lerpf(1.6, 0.5, t) * h / 6.0
		part(n, cone(0.0, r, h * 0.35, 9), needle, Vector3(0, h * (0.25 + t * 0.62), 0))
		part(n, cone(0.0, r * 0.55, h * 0.12, 9), snow, Vector3(0, h * (0.36 + t * 0.62), 0))
	collider(n, cyl_shape(0.3, h * 0.5), Vector3(0, h * 0.25, 0))
	return n

static func shrub(rng: RandomNumberGenerator, hex := "#3c5a3a") -> Node3D:
	var n := Node3D.new(); n.name = "Shrub"
	var m := mat(hex, 0.0, 0.0, 0.9)
	for i in 3:
		part(n, sphere(0.5, 8), m, Vector3(rng.randf_range(-0.4, 0.4), 0.3, rng.randf_range(-0.4, 0.4)), Vector3(1, 0.7, 1) * rng.randf_range(0.7, 1.2))
	return n

static func lava_vent(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new(); n.name = "LavaVent"
	var s := rng.randf_range(0.8, 1.6)
	part(n, cone(0.6 * s, 1.6 * s, 1.2 * s, 12), mat("#1a1012", 0.0, 0.1, 0.8), Vector3(0, 0.5 * s, 0))
	part(n, cone(0.55 * s, 0.55 * s, 0.1, 12), mat("#ff5a14", 4.0), Vector3(0, 1.1 * s, 0))
	part(n, sphere(0.5, 8), mat("#ff8a2a", 1.5, 0.0, 1.0), Vector3(0, 1.6 * s, 0), Vector3(0.6, 1.4, 0.6) * s)
	collider(n, cyl_shape(1.2 * s, 1.2 * s), Vector3(0, 0.5 * s, 0))
	return n

static func obsidian_spire(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new(); n.name = "ObsidianSpire"
	var h := rng.randf_range(5.0, 14.0)
	var m := mat("#0c0a10", 0.0, 0.7, 0.08)
	part(n, cone(0.0, h * 0.12, h, 7), m, Vector3(0, h * 0.5 - 0.5, 0), Vector3.ONE, Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU, rng.randf_range(-0.1, 0.1)))
	part(n, cone(0.0, h * 0.06, h * 0.5, 7), m, Vector3(h * 0.12, h * 0.25 - 0.5, 0), Vector3.ONE, Vector3(0, 0, -0.25))
	part(n, cone(0.0, h * 0.01, h * 0.6, 4), mat("#ff2a60", 2.0), Vector3(0, h * 0.4, 0))
	collider(n, cyl_shape(h * 0.1, h), Vector3(0, h * 0.5, 0))
	return n

static func floating_island(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new(); n.name = "FloatingIsland"
	var r := rng.randf_range(3.0, 7.0)
	part(n, cone(r, 0.3, r * 1.4, 12), mat("#2a1650", 0.0, 0.2, 0.7), Vector3(0, -r * 0.7, 0))
	part(n, cone(r * 0.98, r, 0.4, 12), mat("#6a3ac0", 0.4, 0.3, 0.5), Vector3(0, 0.15, 0))
	for i in 3:
		var c := crystal_cluster(rng, ["#ff2fd2", "#b48cff", "#e8e4f0"][i])
		c.position = Vector3(rng.randf_range(-r * 0.5, r * 0.5), 0.3, rng.randf_range(-r * 0.5, r * 0.5))
		n.add_child(c)
	n.set_meta("bob", rng.randf() * TAU)
	return n

## Billboard sign + post. Every placeholder says YOUR INPUT HERE.
static func make_sign(title: String, sub := "") -> Node3D:
	var n := Node3D.new(); n.name = "Sign"
	part(n, cone(0.08, 0.1, 3.0, 8), mat("#f2bd3a", 0.3, 1.0, 0.25), Vector3(0, 1.5, 0))
	var l := Label3D.new()
	l.name = "Text"
	l.text = "%s\n%s\n★ YOUR INPUT HERE ★" % [title, sub] if sub != "" else "%s\n★ YOUR INPUT HERE ★" % title
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position.y = 3.6
	l.font_size = 64
	l.pixel_size = 0.008
	l.outline_size = 16
	l.modulate = Color("#ffd04a")
	l.outline_modulate = Color(0.08, 0.0, 0.08)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_child(l)
	return n
