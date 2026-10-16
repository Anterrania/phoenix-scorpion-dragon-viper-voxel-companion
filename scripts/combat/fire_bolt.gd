class_name FireBolt
extends Node3D
## v0.6 fire-bolt magic projectile. Damages creatures it reaches.
const SPEED := 28.0
const DAMAGE := 15.0
var dir := Vector3.FORWARD
var life := 1.6

func _init(d: Vector3) -> void:
	dir = d.normalized()
	var K = PropKit
	K.part(self, K.sphere(0.22, 10), K.mat("#ff6a1a", 6.0), Vector3.ZERO)
	K.part(self, K.cone(0.2, 0.0, 0.9, 8), K.mat("#ff2fd0", 3.0), Vector3(0, 0, 0.5), Vector3.ONE, Vector3(PI / 2, 0, 0))
	trail = ParticleFX.make("bolt_trail", Settings.quality())
	add_child(trail)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff6a1a"); light.light_energy = 2.0; light.omni_range = 5.0
	add_child(light)
var trail: GPUParticles3D

## v0.8 burst of magenta sparks where the bolt lands; frees itself.
func spawn_impact() -> void:
	var p := ParticleFX.make("bolt_impact", Settings.quality())
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _process(delta: float) -> void:
	global_position += dir * SPEED * delta
	life -= delta
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.alive() and c.global_position.distance_to(global_position) < 1.4:
			c.hit(DAMAGE)
			life = 0.0
			spawn_impact()
			break
	if life <= 0.0: queue_free()
