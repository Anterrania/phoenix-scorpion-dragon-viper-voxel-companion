class_name FaceDriver
extends RefCounted
## v0.12 face expressions on the MakeHuman body blend shapes (ARKit-style names + visemes, see
## tools/mh/gen_makehuman.py). Simple drivers: random blink, smile/brow set by mood, and a talk-jaw
## + viseme cycle tied to CompanionVoice speech (duration estimated from text length and TTS rate).
## The same normalized channel values (0..1) are exposed by channels() so a future physical body
## can drive face motors from them.

const SHAPES := ["eyeBlinkLeft", "eyeBlinkRight", "mouthSmile", "browInnerUp", "browOuterUp", "browDown",
	"jawOpen", "mouthPucker", "mouthPress", "mouthFrown", "noseSneer",
	"viseme_aa", "viseme_O", "viseme_E", "viseme_I", "viseme_U", "viseme_PP", "viseme_FF"]

var mesh: MeshInstance3D
var _blink_t := 2.0
var _blink := 0.0
var smile := 0.25
var brow := 0.0
var _talk_left := 0.0
var _talk_text := ""
var _talk_t := 0.0
var _ch: Dictionary = {}

static func find_face(model: Node3D) -> MeshInstance3D:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh and mi.find_blend_shape_by_name("eyeBlinkLeft") >= 0: return mi
	return null

static func for_model(model: Node3D) -> FaceDriver:
	var f := FaceDriver.new()
	f.mesh = find_face(model)
	return f

func has_face() -> bool:
	return mesh != null

## Start talk animation for a spoken line. rate: TTS rate multiplier (1.0 = normal).
func say(text: String, rate: float = 1.0) -> void:
	_talk_text = text.to_lower()
	_talk_t = 0.0
	_talk_left = clampf(text.length() * 0.065 / maxf(rate, 0.3), 0.4, 20.0)

func is_talking() -> bool:
	return _talk_left > 0.0

func set_mood(happy: float, raised: float = 0.0) -> void:
	smile = clampf(happy, 0.0, 1.0); brow = clampf(raised, -1.0, 1.0)

func channels() -> Dictionary:
	return _ch.duplicate()

func _viseme_for(c: String) -> String:
	if c in ["a", "h"]: return "viseme_aa"
	if c in ["o", "w"]: return "viseme_O"
	if c in ["e", "r", "y"]: return "viseme_E"
	if c in ["i", "s", "z", "t", "d", "n", "l", "c", "k", "g", "j"]: return "viseme_I"
	if c in ["u", "q"]: return "viseme_U"
	if c in ["m", "b", "p"]: return "viseme_PP"
	if c in ["f", "v"]: return "viseme_FF"
	return ""

func update(delta: float) -> void:
	_ch.clear()
	for s in SHAPES: _ch[s] = 0.0
	# blink: ~every 2-6 s, 0.15 s close/open
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.15; _blink_t = randf_range(2.0, 6.0)
	if _blink > 0.0:
		_blink -= delta
		var b := sin(clampf(1.0 - _blink / 0.15, 0.0, 1.0) * PI)
		_ch["eyeBlinkLeft"] = b; _ch["eyeBlinkRight"] = b
	_ch["mouthSmile"] = smile
	if brow > 0.0: _ch["browInnerUp"] = brow * 0.6; _ch["browOuterUp"] = brow
	elif brow < 0.0: _ch["browDown"] = -brow
	if _talk_left > 0.0:
		_talk_left -= delta; _talk_t += delta
		var idx := int(_talk_t / 0.065)
		var c := _talk_text.substr(idx % maxi(_talk_text.length(), 1), 1) if _talk_text != "" else "a"
		var v := _viseme_for(c)
		var open := 0.25 + 0.35 * absf(sin(_talk_t * 11.0))
		if v != "": _ch[v] = 0.85
		_ch["jawOpen"] = 0.0 if v == "viseme_PP" else open * 0.6
		_ch["mouthSmile"] = smile * 0.5
		if _talk_left <= 0.0: _talk_text = ""
	if mesh == null: return
	for s in SHAPES:
		var i := mesh.find_blend_shape_by_name(s)
		if i >= 0: mesh.set_blend_shape_value(i, _ch[s])
