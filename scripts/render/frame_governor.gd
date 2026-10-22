class_name FrameGovernor
extends RefCounted
## RND-2 frame-time / thermal feedback (pure logic, no scene access).
## Feed it frame times; it answers with a render-scale multiplier inside the current tier.
## Phones throttle when hot, which shows up as rising frame times, so frame time is the
## thermal signal (Godot has no portable thermal API). Hysteresis: drop fast, recover slowly.
##
## Used by RenderPipeline only while AutoQuality's mode is "auto". Tier steps (low/med/high)
## stay with AutoQuality; this only trims resolution between steps, never below MIN_MULT.

const MIN_MULT := 0.75
const STEP := 0.05
const WINDOW := 60            # frames per decision
const DROP_RATIO := 1.12      # p90 above target * this -> drop one step
const RAISE_RATIO := 0.80     # p90 below target * this for RAISE_WINDOWS windows -> raise
const RAISE_WINDOWS := 5

var target_ms := 33.3         # 30 fps default on phones; 16.7 when the user picks 60
var mult := 1.0
var _samples: PackedFloat32Array = []
var _good := 0
var drops := 0

func _init(target := 33.3) -> void:
	target_ms = target

func reset() -> void:
	mult = 1.0; _samples.clear(); _good = 0

static func p90(samples: PackedFloat32Array) -> float:
	if samples.is_empty(): return 0.0
	var s := samples.duplicate()
	s.sort()
	return s[clampi(int(ceil(s.size() * 0.9)) - 1, 0, s.size() - 1)]

## Returns true when mult changed on this sample.
func push(frame_ms: float) -> bool:
	_samples.append(frame_ms)
	if _samples.size() < WINDOW: return false
	var p := p90(_samples)
	_samples.clear()
	var before := mult
	if p > target_ms * DROP_RATIO:
		_good = 0
		mult = maxf(MIN_MULT, snappedf(mult - STEP, 0.01))
		if mult < before: drops += 1
	elif p < target_ms * RAISE_RATIO:
		_good += 1
		if _good >= RAISE_WINDOWS:
			_good = 0
			mult = minf(1.0, snappedf(mult + STEP, 0.01))
	else:
		_good = 0
	return not is_equal_approx(mult, before)

## Under sustained pressure at MIN_MULT, AutoQuality should step the tier down.
func wants_lower_tier() -> bool:
	return is_equal_approx(mult, MIN_MULT) and drops >= 3
