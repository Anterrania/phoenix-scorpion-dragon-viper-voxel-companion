class_name FirestormCam
extends RefCounted
## v0.18 Firestorm-style third-person camera (Second Life viewer feel), as pure state + math.
## - Orbit: dragging turns the camera around the avatar without turning the avatar (alt-cam).
## - Zoom: mouse wheel / pinch, smooth; zooming all the way in drops into mouselook (first person),
##   zooming out from first person comes back to third person.
## - Snap back: once you walk, the orbit eases back behind the avatar (Firestorm "reset camera on move").
## - Collision: the camera never goes through terrain or walls; it slides in front of what is in the way.
## - Smoothing: position follows with a critically damped lerp (ComfortPrefs camera_smoothing).

const DIST_MIN := 0.9          # m; closer than this = mouselook
const DIST_MAX := 24.0
const DIST_DEFAULT := 3.4
const PITCH_MIN := -1.35       # rad, looking up from below
const PITCH_MAX := 1.2         # rad, looking down from above
const PITCH_DEFAULT := 0.16
const SHOULDER := Vector3(0.0, 0.55, 0.0)   # orbit pivot above the body origin
const SIDE := 0.35             # m over-the-shoulder offset (scaled down when zoomed in)
const RETURN_RATE := 2.6       # rad/s the orbit eases back behind the avatar while walking
const RETURN_DELAY := 0.6      # s after the last orbit drag before the snap back starts
const MARGIN := 0.25           # m kept between the camera and what it hit

var yaw := 0.0                 # orbit around the avatar, relative to the body heading (0 = behind)
var pitch := PITCH_DEFAULT
var dist := DIST_DEFAULT
var dist_target := DIST_DEFAULT
var since_orbit := 99.0
var mouselook := false
var _pos := Vector3.ZERO
var _has_pos := false

## Drag (radians). Orbits in third person; in mouselook the caller turns the body/head instead.
func orbit(d: Vector2) -> void:
	yaw = wrapf(yaw - d.x, -PI, PI)
	pitch = clampf(pitch + d.y, PITCH_MIN, PITCH_MAX)
	since_orbit = 0.0

## factor < 1 zooms in, > 1 zooms out. Returns "mouselook", "third" or "" when the mode changed.
func zoom(factor: float) -> String:
	if mouselook:
		if factor > 1.0:
			mouselook = false
			dist_target = DIST_MIN * 1.6
			dist = dist_target
			return "third"
		return ""
	dist_target = clampf(dist_target * factor, DIST_MIN * 0.99, DIST_MAX)
	if dist_target <= DIST_MIN:
		mouselook = true
		dist_target = DIST_MIN
		return "mouselook"
	return ""

## Escape / reset view: behind the avatar at the default distance.
func reset() -> void:
	yaw = 0.0
	pitch = PITCH_DEFAULT
	dist_target = DIST_DEFAULT
	since_orbit = 99.0
	_has_pos = false

## Per frame. moving = the avatar is walking/flying under player control.
func tick(delta: float, moving: bool) -> void:
	since_orbit += delta
	if moving and since_orbit > RETURN_DELAY:
		yaw = move_toward(yaw, 0.0, RETURN_RATE * delta)
	dist = lerpf(dist, dist_target, clampf(delta * 10.0, 0.0, 1.0))

## Where the camera wants to be (no collision): pivot + orbit around the body heading.
static func ideal(pivot: Vector3, body_yaw: float, cam_yaw: float, cam_pitch: float, distance: float) -> Vector3:
	var b := Basis(Vector3.UP, body_yaw + cam_yaw) * Basis(Vector3.RIGHT, -cam_pitch)
	var side := SIDE * clampf((distance - DIST_MIN) / 2.0, 0.0, 1.0)
	return pivot + b * Vector3(side, 0.0, distance)

## Pull the camera in front of whatever sits between pivot and wanted. hit = Vector3 or null.
static func collide(pivot: Vector3, wanted: Vector3, hit: Variant) -> Vector3:
	if hit == null: return wanted
	var to := wanted - pivot
	var d := (hit as Vector3).distance_to(pivot)
	if d >= to.length(): return wanted
	return pivot + to.normalized() * maxf(d - MARGIN, 0.2)

## Smoothed follow. smoothing 0 = rigid, 1 = floaty. Snaps on the first frame or after a teleport.
func follow(target: Vector3, delta: float, smoothing: float) -> Vector3:
	if not _has_pos or _pos.distance_to(target) > 30.0:
		_pos = target
		_has_pos = true
		return _pos
	var rate := lerpf(40.0, 8.0, clampf(smoothing, 0.0, 1.0))
	_pos = _pos.lerp(target, 1.0 - exp(-rate * delta))
	return _pos

## Camera heading on the ground plane (radians, world), used to steer walking relative to the view.
func heading(body_yaw: float) -> float:
	return body_yaw + yaw
