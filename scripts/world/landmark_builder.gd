class_name LandmarkBuilder
extends RefCounted
## v0.5 placeholder landmark structures: simple ORIGINAL shapes, palette black /
## magenta / gold / platinum. Swap for real models later (YOUR INPUT HERE).

const K := preload("res://scripts/world/prop_kit.gd")
const GOLD := "#f2bd3a"
const BLACK := "#0b0910"
const MAG := "#ff2fd0"
const PLAT := "#e8e4f0"

static func build(kind: String, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	match kind:
		"sanctum": _sanctum(n, rng)
		"lagoon": _lagoon(n, rng)
		"rink": _rink(n)
		"capitol": _capitol(n)
		"throne_hall": _throne_hall(n)
		"palace": _palace(n)
		"citadel": _citadel(n, rng)
		_: _plinth(n, 4.0)
	return n

static func _plinth(n: Node3D, r: float, hex := BLACK, h := 1.0) -> void:
	K.part(n, K.cone(r, r * 1.05, h, 24), K.mat(hex, 0.0, 0.5, 0.3), Vector3(0, h * 0.5 - 0.4, 0))
	K.part(n, K.torus(r * 0.98, r * 1.04), K.mat(GOLD, 0.4, 1.0, 0.2), Vector3(0, h - 0.4, 0))
	K.collider(n, K.cyl_shape(r, h), Vector3(0, h * 0.5 - 0.4, 0))

static func _columns(n: Node3D, r: float, count: int, h: float, y: float, hex := PLAT) -> void:
	for i in count:
		var a := TAU * i / count
		K.part(n, K.cone(0.35, 0.4, h, 12), K.mat(hex, 0.0, 0.6, 0.3), Vector3(cos(a) * r, y + h * 0.5, sin(a) * r))
		K.collider(n, K.cyl_shape(0.4, h), Vector3(cos(a) * r, y + h * 0.5, sin(a) * r))

static func _dome(n: Node3D, r: float, y: float) -> void:
	K.part(n, K.sphere(r, 20), K.mat(GOLD, 0.25, 1.0, 0.2), Vector3(0, y, 0), Vector3(1, 0.8, 1))
	K.part(n, K.cone(0.0, 0.2, 2.0, 8), K.mat(MAG, 2.0), Vector3(0, y + r * 0.8 + 1.0, 0))

static func _sanctum(n: Node3D, rng: RandomNumberGenerator) -> void:
	_plinth(n, 7.0, "#c9d4ea")
	for i in 8:
		var a := TAU * i / 8.0
		var c := K.crystal_cluster(rng, ["#b48cff", PLAT][i % 2])
		c.position = Vector3(cos(a) * 6.0, 0.6, sin(a) * 6.0); c.scale = Vector3.ONE * 2.0
		n.add_child(c)
	# Abstract crystal wyvern: body, neck, head, two swept wings.
	var m := K.mat("#c8b8ff", 1.2, 0.7, 0.1)
	K.part(n, K.sphere(1.0, 14), m, Vector3(0, 3.0, 0), Vector3(1.0, 1.0, 2.0))
	K.part(n, K.cone(0.3, 0.6, 2.6, 10), m, Vector3(0, 4.6, -1.6), Vector3.ONE, Vector3(-0.6, 0, 0))
	K.part(n, K.sphere(0.6, 12), m, Vector3(0, 5.9, -2.4), Vector3(0.8, 0.7, 1.4))
	for s in [-1.0, 1.0]:
		K.part(n, K.cone(0.0, 1.6, 6.0, 4), K.mat(PLAT, 0.8, 0.9, 0.1), Vector3(s * 3.0, 4.6, 0.3), Vector3(1, 1, 0.15), Vector3(0, 0, -s * 1.1))
	K.part(n, K.cone(0.0, 0.4, 4.0, 8), m, Vector3(0, 2.6, 3.4), Vector3.ONE, Vector3(1.3, 0, 0))

static func _lagoon(n: Node3D, rng: RandomNumberGenerator) -> void:
	K.part(n, K.cone(8.0, 8.0, 0.2, 32), K.mat("#2ad0ff", 1.4, 0.2, 0.05), Vector3(0, 0.1, 0))
	for i in 14:
		var a := TAU * i / 14.0
		var r := K.rock(rng, "#15121a")
		r.position = Vector3(cos(a) * 8.6, 0.0, sin(a) * 8.6)
		n.add_child(r)
	for i in 4:
		K.part(n, K.sphere(1.0, 8), K.mat("#e8f6ff", 0.6, 0.0, 1.0), Vector3(rng.randf_range(-4, 4), 1.5 + i, rng.randf_range(-4, 4)), Vector3(1.6, 0.6, 1.6))

static func _rink(n: Node3D) -> void:
	K.part(n, K.cone(10.0, 10.0, 0.25, 40), K.mat("#d8ecff", 0.15, 0.3, 0.03), Vector3(0, 0.12, 0), Vector3(1.4, 1, 1))
	K.part(n, K.torus(9.8, 10.4), K.mat(MAG, 1.5), Vector3(0, 0.5, 0), Vector3(1.4, 1, 1))
	K.part(n, K.sphere(1.6, 16), K.mat(PLAT, 2.5), Vector3(0, 18.0, 0))  # moon lantern
	for s in [-1.0, 1.0]:  # spectator stands
		K.part(n, K.cone(3.0, 4.0, 2.0, 16), K.mat(BLACK, 0.0, 0.5, 0.3), Vector3(s * 17.0, 1.0, 0), Vector3(0.6, 1, 2.2))

static func _capitol(n: Node3D) -> void:
	_plinth(n, 10.0, BLACK, 1.6)
	K.part(n, K.cone(7.0, 8.0, 1.0, 24), K.mat(PLAT, 0.0, 0.4, 0.4), Vector3(0, 1.7, 0))
	_columns(n, 6.4, 12, 6.0, 2.2)
	K.part(n, K.cone(7.2, 7.2, 0.8, 24), K.mat(BLACK, 0.0, 0.6, 0.3), Vector3(0, 8.6, 0))
	_dome(n, 5.0, 9.0)
	for s in [-1.0, 1.0]:  # lightning spires (Stormcrown)
		K.part(n, K.cone(0.0, 0.6, 14.0, 6), K.mat(BLACK, 0.0, 0.8, 0.1), Vector3(s * 11.0, 7.0, 0))
		K.part(n, K.cone(0.0, 0.08, 6.0, 4), K.mat("#9ad8ff", 4.0), Vector3(s * 11.0, 13.0, 0))

static func _throne_hall(n: Node3D) -> void:
	_plinth(n, 9.0, BLACK, 1.0)
	var wall := K.mat(BLACK, 0.0, 0.75, 0.1)
	for i in 10:  # gothic arch ring of tall pointed pillars, open front
		var a := PI * 0.15 + (PI * 1.7) * i / 9.0
		K.part(n, K.cone(0.0, 0.9, 12.0, 6), wall, Vector3(cos(a) * 8.0, 6.6, sin(a) * 8.0))
		K.collider(n, K.cyl_shape(0.8, 12.0), Vector3(cos(a) * 8.0, 6.6, sin(a) * 8.0))
	K.part(n, K.cone(0.6, 1.4, 1.6, 12), K.mat(GOLD, 0.3, 1.0, 0.2), Vector3(0, 1.4, -5.0))  # throne seat
	K.part(n, K.cone(0.1, 1.0, 4.0, 4), K.mat(MAG, 0.8, 0.5, 0.3), Vector3(0, 4.0, -5.8), Vector3(1, 1, 0.2))
	# black crystal chandelier with magenta candle lights
	K.part(n, K.torus(2.4, 2.8), K.mat(GOLD, 0.3, 1.0, 0.2), Vector3(0, 11.0, 0))
	for i in 12:
		var a := TAU * i / 12.0
		K.part(n, K.cone(0.0, 0.25, 1.6, 6), K.mat("#14101c", 0.4, 0.9, 0.05), Vector3(cos(a) * 2.6, 10.0, sin(a) * 2.6), Vector3.ONE, Vector3(PI, 0, 0))
		K.part(n, K.sphere(0.15, 6), K.mat(MAG, 4.0), Vector3(cos(a) * 2.6, 11.4, sin(a) * 2.6))

static func _palace(n: Node3D) -> void:
	# Floating base hovering above the ground.
	K.part(n, K.cone(12.0, 2.0, 8.0, 24), K.mat("#1a1028", 0.0, 0.3, 0.6), Vector3(0, 6.0, 0))
	K.part(n, K.torus(11.6, 12.4), K.mat(MAG, 2.0), Vector3(0, 10.0, 0))
	K.part(n, K.cone(11.0, 12.0, 0.6, 24), K.mat(PLAT, 0.1, 0.5, 0.3), Vector3(0, 10.2, 0))
	_columns(n, 7.0, 16, 7.0, 10.5, GOLD)
	K.part(n, K.cone(8.0, 8.0, 1.0, 24), K.mat(BLACK, 0.0, 0.6, 0.3), Vector3(0, 18.0, 0))
	_dome(n, 6.0, 18.5)
	K.part(n, K.cone(1.4, 1.4, 10.0, 16), K.mat(MAG, 1.5, 0.0, 0.5), Vector3(0, 5.0, 0))  # light beam stair
	K.collider(n, K.cyl_shape(12.0, 0.6), Vector3(0, 10.2, 0))

static func _citadel(n: Node3D, rng: RandomNumberGenerator) -> void:
	for i in 5:  # inverted floating spire-fortresses
		var a := TAU * i / 5.0
		var p := Vector3(cos(a) * 10.0, 14.0 + rng.randf_range(-2, 4), sin(a) * 10.0)
		K.part(n, K.cone(3.0, 0.0, 10.0, 8), K.mat(BLACK, 0.0, 0.8, 0.15), p)
		K.part(n, K.cone(0.0, 2.2, 6.0, 8), K.mat(PLAT, 0.2, 0.8, 0.2), p + Vector3(0, 8.0, 0))
		K.part(n, K.sphere(0.5, 8), K.mat(MAG, 3.0), p + Vector3(0, 11.5, 0))
	K.part(n, K.sphere(4.0, 20), K.mat(GOLD, 0.6, 1.0, 0.15), Vector3(0, 22.0, 0))
	K.part(n, K.torus(6.0, 6.5), K.mat(MAG, 2.5), Vector3(0, 22.0, 0), Vector3.ONE, Vector3(0.4, 0, 0.2))
	_plinth(n, 4.0)
