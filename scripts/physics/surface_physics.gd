class_name SurfacePhysics
extends RefCounted
## v0.4 shared physics rules (pure functions so they are unit-testable headless).
## - Liquid surface at generator.LAVA_LEVEL behaves per biome:
##     Alaska  -> frozen sea ICE: solid, very slippery
##     Venus   -> LAVA: damages, burns upward and shoves you back toward shore
##     Cosmic  -> starlight WATER: buoyant, slows you
## - Ground safety net: never let a body sink below the analytic terrain height
##   (covers the moments before voxel collision meshes are generated).
## - Separation steering so companions never overlap each other or the player.

enum Surface { GROUND, ICE, LAVA, WATER }
const ICE_ACCEL := 1.6        # m/s^2 of control on ice (ground is instant)
const GROUND_ACCEL := 40.0
const LAVA_DPS := 18.0
const LAVA_PUSH := 9.0
const BUOYANCY := 14.0
const WATER_DRAG := 3.0
const SEPARATION_RADIUS := 1.6
const SEPARATION_STRENGTH := 4.0

static func surface_at(gen, pos: Vector3) -> int:
	if gen == null: return Surface.GROUND
	var h: float = gen.height_f(pos.x, pos.z)
	var sea: float = float(gen.LAVA_LEVEL)
	if h >= sea or pos.y > sea + 1.2: return Surface.GROUND
	match int(gen.biome_at(pos.x, pos.z)):
		0: return Surface.ICE
		1: return Surface.LAVA
		_: return Surface.WATER

static func accel_for(surface: int) -> float:
	return ICE_ACCEL if surface == Surface.ICE else GROUND_ACCEL

## Blend current horizontal velocity toward the wanted one; ice keeps momentum.
static func steer(vel: Vector3, wanted: Vector3, surface: int, delta: float) -> Vector3:
	var a := accel_for(surface) * delta
	if surface == Surface.WATER: wanted *= 0.55
	var h := Vector2(vel.x, vel.z).move_toward(Vector2(wanted.x, wanted.z), a)
	return Vector3(h.x, vel.y, h.y)

## Downhill direction toward higher ground (shore) using the analytic height field.
static func shore_dir(gen, pos: Vector3) -> Vector3:
	var e := 2.0
	var gx: float = gen.height_f(pos.x + e, pos.z) - gen.height_f(pos.x - e, pos.z)
	var gz: float = gen.height_f(pos.x, pos.z + e) - gen.height_f(pos.x, pos.z - e)
	var d := Vector3(gx, 0, gz)
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD

## Applies liquid/ice + ground safety. Returns {velocity, position, damage}.
static func apply(gen, pos: Vector3, vel: Vector3, delta: float, foot := 0.85) -> Dictionary:
	var out := {"velocity": vel, "position": pos, "damage": 0.0, "surface": Surface.GROUND}
	if gen == null: return out
	var s := surface_at(gen, pos)
	out.surface = s
	var sea := float(gen.LAVA_LEVEL)
	var feet := pos.y - foot
	match s:
		Surface.ICE:
			if feet < sea:
				pos.y = sea + foot
				if vel.y < 0.0: vel.y = 0.0
		Surface.LAVA:
			if feet < sea + 0.3:
				out.damage = LAVA_DPS * delta
				var push := shore_dir(gen, pos) * LAVA_PUSH
				vel.x = push.x; vel.z = push.z
				vel.y = maxf(vel.y, 6.0)
		Surface.WATER:
			if feet < sea:
				vel.y += BUOYANCY * delta
				vel.y -= vel.y * WATER_DRAG * delta
	var ground: float = gen.height_f(pos.x, pos.z)
	if pos.y - foot < ground - 0.5:   # fell through: snap back on top
		pos.y = ground + foot + 0.1
		vel.y = maxf(vel.y, 0.0)
	out.velocity = vel
	out.position = pos
	return out

## Simple boids-style separation from neighbours (horizontal only).
static func separation(me: Vector3, others: Array, radius := SEPARATION_RADIUS) -> Vector3:
	var push := Vector3.ZERO
	for o in others:
		var d: Vector3 = me - (o as Vector3)
		d.y = 0
		var l := d.length()
		if l < radius:
			if l < 0.01: d = Vector3(randf() - 0.5, 0, randf() - 0.5); l = 0.01
			push += d.normalized() * (radius - l) / radius
	return push * SEPARATION_STRENGTH
