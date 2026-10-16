class_name CombatZone
extends Node3D
## v0.6 damage-enabled zone (SL "damage enabled" land). Everywhere else is safe.
## One zone in Venus: the Ember Arena. Creatures patrol inside it.

static var zones: Array = []   # [{center: Vector3, radius: float}]
var center := Vector3.ZERO
var radius := 30.0

static func is_damage_enabled(p: Vector3) -> bool:
	for z in zones:
		var c: Vector3 = z["center"]
		if Vector2(p.x - c.x, p.z - c.z).length() <= float(z["radius"]): return true
	return false

func setup(c: Vector3, r: float) -> void:
	name = "EmberArena"
	center = c
	radius = r
	zones.append({"center": c, "radius": r})
	var K = PropKit
	K.part(self, K.torus(r - 0.4, r + 0.4), K.mat("#ff2a2a", 3.0), Vector3(0, 0.3, 0))
	for i in 8:
		var a := TAU * i / 8.0
		K.part(self, K.cone(0.0, 0.5, 4.0, 6), K.mat("#1a0a0a", 0.0, 0.7, 0.2), Vector3(cos(a) * r, 2.0, sin(a) * r))
		K.part(self, K.sphere(0.35, 8), K.mat("#ff4a1a", 4.0), Vector3(cos(a) * r, 4.2, sin(a) * r))
	var s := PropKit.make_sign("⚔ EMBER ARENA - COMBAT ZONE", "damage ON inside the red ring · safe everywhere else")
	s.position = Vector3(0, 0, r + 3.0)
	add_child(s)

func _exit_tree() -> void:
	zones = zones.filter(func(z): return z["center"] != center)
