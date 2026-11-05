class_name AvatarMotion
extends RefCounted
## v0.19 Second Life-style walking and turning, as pure math (shared by the player and companions).
## - Avatars turn to face where they walk, at a capped turn rate (no instant snaps).
## - Standing avatars only turn toward something once it is well off to the side (hysteresis),
##   then turn all the way, like SL avatars turning to face a speaker.
## - Turning on the spot plays a small step (shuffle) instead of sliding.
## - Keyboard in third person is SL-style: W/S walk along the facing, A/D turn; the touch joystick
##   walks relative to the camera and the avatar turns to face that way.

const TURN_RATE := 7.0          # rad/s while walking
const IDLE_TURN_RATE := 4.0     # rad/s turning on the spot
const KEY_TURN_RATE := 2.4      # rad/s holding A/D (SL ~ a full turn in 2.6 s)
const IDLE_START := deg_to_rad(60.0)   # start turning toward a target this far off
const IDLE_DONE := deg_to_rad(6.0)     # stop once this close
const SHUFFLE := 0.3            # walk-cycle speed used for the turning-on-the-spot step

## Godot yaw that faces a ground direction (models face -Z).
static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

## Turn from cur toward target by at most rate*delta, the short way round.
static func turn(cur: float, target: float, rate: float, delta: float) -> float:
	var d := angle_difference(cur, target)
	var step := rate * delta
	if absf(d) <= step: return target
	return wrapf(cur + signf(d) * step, -PI, PI)

## Idle facing with hysteresis. state = {"turning": bool}. Returns the new yaw.
static func idle_face(state: Dictionary, cur: float, target: float, delta: float) -> float:
	var off := absf(angle_difference(cur, target))
	if not state.get("turning", false) and off > IDLE_START: state["turning"] = true
	if state.get("turning", false):
		cur = turn(cur, target, IDLE_TURN_RATE, delta)
		if absf(angle_difference(cur, target)) < IDLE_DONE: state["turning"] = false
	return cur

## Walk-cycle speed (0..1) given ground speed and how fast we are turning (rad/s).
static func gait(speed01: float, turn_speed: float) -> float:
	if speed01 > 0.05: return speed01
	return SHUFFLE if absf(turn_speed) > 0.6 else speed01

## Keyboard (SL): x = turn (A/D), y = walk along facing (W = -1). Returns {turn, forward}.
static func keyboard(input: Vector2) -> Dictionary:
	return {"turn": -input.x * KEY_TURN_RATE, "forward": -input.y}

## Joystick relative to the camera heading (radians). Returns the world ground direction.
static func camera_relative(input: Vector2, cam_heading: float) -> Vector3:
	return Basis(Vector3.UP, cam_heading) * Vector3(input.x, 0.0, input.y)
