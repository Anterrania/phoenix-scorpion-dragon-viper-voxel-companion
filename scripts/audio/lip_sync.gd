class_name LipSync
extends RefCounted
## Mouth/jaw sync for companions and avatars. Two sources:
##  - amplitude: RMS of real audio (mic for voice chat, or any clip on a Godot bus) -> jaw envelope
##    with a noise gate, fast attack, slower release. Used whenever real samples exist.
##  - text: for system TTS (no samples reach Godot) a viseme timeline from the spoken text, started
##    on the TTS "utterance started" callback and re-aligned on word boundaries, stopped on "ended".
## Output: normalized channels (jawOpen + viseme_*) in the same names as v0.12 FaceDriver.SHAPES, so
## it drives FaceDriver (patches/face_driver_lip_sync.patch), any blend-shape mesh, or the low-poly
## HumanoidModel jaw.

const CHAR_SEC := 0.065           # same pacing as FaceDriver.say()
const VISEMES := ["viseme_aa", "viseme_O", "viseme_E", "viseme_I", "viseme_U", "viseme_PP", "viseme_FF"]

var gate := 0.02                  # RMS below this = silence
var gain := 6.0                   # RMS -> jaw
var attack := 0.03                # s to open
var release := 0.12               # s to close
var env := 0.0                    # amplitude envelope 0..1
var _text := ""
var _rate := 1.0
var _t := 0.0
var _len := 0.0
var _talking := false
var _amp_live := 0.0              # seconds of fresh amplitude data left (amplitude wins over text)
var channels := {}

# ---------- amplitude ----------
static func rms(frames: PackedVector2Array) -> float:
	if frames.is_empty(): return 0.0
	var acc := 0.0
	for f in frames: acc += (f.x * f.x + f.y * f.y) * 0.5
	return sqrt(acc / frames.size())

## Feed one block of audio level. delta = block duration in seconds.
func feed_rms(level: float, delta: float) -> float:
	var target := clampf((level - gate) * gain, 0.0, 1.0) if level > gate else 0.0
	var tau := attack if target > env else release
	env = lerpf(env, target, clampf(delta / maxf(tau, 0.001), 0.0, 1.0))
	_amp_live = 0.25
	return env

func feed_frames(frames: PackedVector2Array, mix_rate := 44100.0) -> float:
	return feed_rms(rms(frames), frames.size() / maxf(mix_rate, 1.0))

# ---------- text (TTS) ----------
static func viseme_for(c: String) -> String:
	if c in ["a", "h"]: return "viseme_aa"
	if c in ["o", "w"]: return "viseme_O"
	if c in ["e", "r", "y"]: return "viseme_E"
	if c in ["i", "s", "z", "t", "d", "n", "l", "c", "k", "g", "j", "x"]: return "viseme_I"
	if c in ["u", "q"]: return "viseme_U"
	if c in ["m", "b", "p"]: return "viseme_PP"
	if c in ["f", "v"]: return "viseme_FF"
	return ""

func start_text(text: String, rate := 1.0) -> void:
	_text = text.to_lower(); _rate = maxf(rate, 0.3); _t = 0.0
	_len = clampf(text.length() * CHAR_SEC / _rate, 0.3, 30.0)
	_talking = _text.strip_edges() != ""

## TTS word boundary: jump to the character the engine is speaking (fixes drift on long lines).
func on_boundary(char_pos: int) -> void:
	if _talking: _t = clampf(char_pos * CHAR_SEC / _rate, 0.0, _len)

func stop() -> void:
	_talking = false; _text = ""

func is_talking() -> bool: return _talking or env > 0.05

# ---------- output ----------
func update(delta: float) -> Dictionary:
	channels = {"jawOpen": 0.0}
	for v in VISEMES: channels[v] = 0.0
	if _amp_live > 0.0:
		_amp_live -= delta
		channels["jawOpen"] = env * 0.8
		if env > 0.05: channels["viseme_aa"] = env * 0.6
	elif _talking:
		_t += delta
		if _t >= _len: stop()
		else:
			var idx := int(_t / (CHAR_SEC / _rate))
			var c := _text.substr(clampi(idx, 0, _text.length() - 1), 1)
			var v := viseme_for(c)
			if v != "": channels[v] = 0.85
			# closed lips on m/b/p and at spaces between words, otherwise open with a syllable wobble
			channels["jawOpen"] = 0.0 if v in ["viseme_PP", ""] else 0.3 + 0.3 * absf(sin(_t * 11.0))
	else:
		env = lerpf(env, 0.0, clampf(delta / release, 0.0, 1.0))
	return channels

## Push channels to a target: a FaceDriver-like object (drive(ch)), a blend-shape mesh, or a
## HumanoidModel (Hips/Torso/Head/Jaw node). Returns what it drove: "driver"|"mesh"|"jaw"|"none".
func apply_to(target: Object) -> String:
	if target == null: return "none"
	if target.has_method("drive"):
		target.call("drive", channels); return "driver"
	if target is MeshInstance3D:
		var mi := target as MeshInstance3D
		var n := 0
		for k in channels:
			var i := mi.find_blend_shape_by_name(k)
			if i >= 0: mi.set_blend_shape_value(i, channels[k]); n += 1
		return "mesh" if n > 0 else "none"
	if target is Node3D:
		var jaw := (target as Node3D).get_node_or_null("Hips/Torso/Head/Jaw") as Node3D
		if jaw == null: return "none"
		if not jaw.has_meta("rest_y"): jaw.set_meta("rest_y", jaw.position.y)
		var o := float(channels.get("jawOpen", 0.0))
		jaw.position.y = float(jaw.get_meta("rest_y")) - 0.02 * o
		jaw.scale.y = 0.8 * (1.0 + 0.35 * o)
		return "jaw"
	return "none"
