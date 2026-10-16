extends Node3D
## v0.4 pushable RigidBody props (crates, rocks, crystals) scattered near spawn.
## Props start frozen and wake once the voxel collision under them exists, so they
## never fall through terrain that is still loading.

@export var count := 12
@export var radius := 14.0
var generator
var props: Array[RigidBody3D] = []

const KINDS := {
	"crate":   {"mass": 8.0,  "color": Color("#2b1a10"), "trim": Color("#ffc23a"), "emit": 0.0},
	"rock":    {"mass": 30.0, "color": Color("#4a4458"), "trim": Color("#c9c3d8"), "emit": 0.0},
	"crystal": {"mass": 4.0,  "color": Color("#ff2fd2"), "trim": Color("#e6e6f0"), "emit": 2.0},
}

func setup(gen, center: Vector3) -> void:
	generator = gen
	var kinds := KINDS.keys()
	for i in count:
		var a := TAU * float(i) / count
		var r := radius * (0.55 + 0.45 * fmod(i * 0.618, 1.0))
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = generator.height_f(p.x, p.z) + 1.5 if generator else center.y
		props.append(make_prop(kinds[i % kinds.size()], p))

func make_prop(kind: String, pos: Vector3) -> RigidBody3D:
	var k: Dictionary = KINDS[kind]
	var rb := RigidBody3D.new()
	rb.name = "%s_%d" % [kind, props.size()]
	rb.mass = k.mass
	rb.freeze = true
	rb.continuous_cd = true
	rb.set_meta("kind", kind)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8 if kind != "crystal" else 0.3
	pm.bounce = 0.1
	rb.physics_material_override = pm
	var col := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = k.color
	mat.metallic = 0.6 if kind == "crystal" else 0.1
	mat.roughness = 0.15 if kind == "crystal" else 0.8
	if k.emit > 0.0:
		mat.emission_enabled = true
		mat.emission = k.color
		mat.emission_energy_multiplier = k.emit
	match kind:
		"crate":
			var bs := BoxShape3D.new(); bs.size = Vector3(1, 1, 1); col.shape = bs
			var bm := BoxMesh.new(); bm.size = bs.size; mi.mesh = bm
		"rock":
			var ss := SphereShape3D.new(); ss.radius = 0.7; col.shape = ss
			var sm := SphereMesh.new(); sm.radius = 0.7; sm.height = 1.1; sm.radial_segments = 9; sm.rings = 5; mi.mesh = sm
		"crystal":
			var cs := CylinderShape3D.new(); cs.radius = 0.3; cs.height = 1.4; col.shape = cs
			var pr := CylinderMesh.new(); pr.top_radius = 0.02; pr.bottom_radius = 0.35; pr.height = 1.4; pr.radial_segments = 6; mi.mesh = pr
	mi.material_override = mat
	rb.add_child(col)
	rb.add_child(mi)
	add_child(rb)
	rb.global_position = pos
	return rb

func _physics_process(_d: float) -> void:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	for rb in props:
		if not is_instance_valid(rb): continue
		if rb.freeze and space:
			var q := PhysicsRayQueryParameters3D.create(rb.global_position, rb.global_position + Vector3.DOWN * 4.0)
			q.exclude = [rb.get_rid()]
			if not space.intersect_ray(q).is_empty():
				rb.freeze = false
		elif generator:
			var g: float = generator.height_f(rb.global_position.x, rb.global_position.z)
			if rb.global_position.y < g - 1.0:  # safety net
				rb.global_position.y = g + 1.0
				rb.linear_velocity = Vector3.ZERO
