class_name MovementModel
extends RefCounted
## v0.8 character controller math (pure, unit-testable).
## Acceleration/deceleration with air control, coyote time + jump buffering,
## swimming in starlight water, and ragdoll-lite knockback that decays.

const ACCEL := 32.0        # m/s^2 on ground when speeding up
const DECEL := 44.0        # m/s^2 on ground when stopping
const AIR_ACCEL := 9.0     # reduced air control
const COYOTE := 0.12       # s you can still jump after leaving a ledge
const JUMP_BUFFER := 0.12  # s a jump press is remembered before landing
const SNAP_LENGTH := 0.45  # m floor snapping for slopes / steps
const SWIM_SPEED := 3.2
const SWIM_UP := 3.5
const SWIM_GRAVITY := 1.2
const KNOCK_DECAY := 5.0
const TILT_MAX := 0.6      # rad, ragdoll-lite lean

## Horizontal velocity blend: faster start, crisper stop, little control in the air.
static func horizontal(vel: Vector3, wanted: Vector3, on_floor: bool, delta: float) -> Vector3:
	var h := Vector2(vel.x, vel.z)
	var w := Vector2(wanted.x, wanted.z)
	var rate := AIR_ACCEL
	if on_floor:
		rate = ACCEL if w.length() > 0.01 and w.dot(h) >= 0.0 else DECEL
	h = h.move_toward(w, rate * delta)
	return Vector3(h.x, vel.y, h.y)

## Jump state machine. state = {coyote: float, buffer: float}. Returns true when a jump fires.
static func jump_tick(state: Dictionary, on_floor: bool, pressed: bool, delta: float) -> bool:
	state.coyote = COYOTE if on_floor else maxf(float(state.get("coyote", 0.0)) - delta, 0.0)
	state.buffer = JUMP_BUFFER if pressed else maxf(float(state.get("buffer", 0.0)) - delta, 0.0)
	if state.buffer > 0.0 and state.coyote > 0.0:
		state.buffer = 0.0
		state.coyote = 0.0
		return true
	return false

## Swimming: slow gravity, steer in 3D, hold jump to rise.
static func swim(vel: Vector3, wanted: Vector3, rise: bool, delta: float) -> Vector3:
	var w := wanted.normalized() * SWIM_SPEED if wanted.length() > 0.01 else Vector3.ZERO
	w.y = SWIM_UP if rise else -SWIM_GRAVITY
	return vel.lerp(w, clampf(delta * 3.0, 0.0, 1.0))

## Knockback impulse decays exponentially; returns new impulse.
static func decay_knock(knock: Vector3, delta: float) -> Vector3:
	var k := knock * exp(-KNOCK_DECAY * delta)
	return Vector3.ZERO if k.length() < 0.05 else k

## Ragdoll-lite lean angle (rad) for a given knock impulse in local space.
static func tilt_for(knock_local: Vector3) -> Vector2:
	return Vector2(clampf(knock_local.z * 0.06, -TILT_MAX, TILT_MAX), clampf(-knock_local.x * 0.06, -TILT_MAX, TILT_MAX))
