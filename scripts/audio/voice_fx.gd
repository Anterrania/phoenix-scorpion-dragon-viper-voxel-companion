class_name VoiceFx
extends RefCounted
## Voice morphing: pitch shift + formant tilt.
##
## Where it applies (important, measured against Godot 4.7):
## - Audio that plays THROUGH Godot (mic capture for voice chat / the voice changer, cloud TTS clips,
##   music): a real effect chain on an audio bus -> AudioEffectPitchShift (pitch) + AudioEffectEQ6
##   (formant tilt: lifts or lowers the 1-10 kHz "vocal tract" bands against the 100-320 Hz chest).
## - Android/desktop system TTS (DisplayServer.tts_speak) plays OUTSIDE Godot's mixer, so bus effects
##   can't touch it. For TTS the preset is folded into tts_speak's own pitch/rate (tts_params()).
##   Formant can't be changed on system TTS; the preset's voice_bias picks a different system voice.

const BUS := "VoiceFX"
const PITCH_MIN := 0.5
const PITCH_MAX := 2.0
## pitch: multiplier. formant: -1 (deeper, darker) .. +1 (smaller, brighter). rate: TTS speed.
const PRESETS := {
	"natural": {"label": "Natural", "pitch": 1.0, "formant": 0.0, "rate": 1.0},
	"deep": {"label": "Deep", "pitch": 0.82, "formant": -0.4, "rate": 0.95},
	"bright": {"label": "Bright", "pitch": 1.18, "formant": 0.35, "rate": 1.03},
	"dragon": {"label": "Dragon", "pitch": 0.68, "formant": -0.8, "rate": 0.9},
	"fae": {"label": "Fae", "pitch": 1.4, "formant": 0.7, "rate": 1.08},
	"radio": {"label": "Radio", "pitch": 1.0, "formant": 0.5, "rate": 1.0, "band": true},
}
const EQ_BANDS_HZ := [32, 100, 320, 1000, 3200, 10000]

static func preset(name: String) -> Dictionary:
	return PRESETS.get(name, PRESETS["natural"])

static func clamp_pitch(p: float) -> float: return clampf(p, PITCH_MIN, PITCH_MAX)
static func clamp_formant(f: float) -> float: return clampf(f, -1.0, 1.0)

## EQ6 gains (dB) for a formant tilt. +1 = +6 dB at 3.2-10 kHz, -4 dB at 100 Hz (and the inverse).
static func formant_gains(f: float, band := false) -> Array:
	f = clamp_formant(f)
	var g := [-2.0 * f, -4.0 * f, -1.5 * f, 1.5 * f, 6.0 * f, 5.0 * f]
	if band: g[0] = -24.0; g[1] = -12.0; g[5] = minf(g[5], -12.0)   # "radio": cut lows + top
	return g

## Effect chain for a preset or explicit {pitch, formant}. Pitch shift uses FFT 1024 (about 23 ms at
## 44.1 kHz: low enough latency for live voice; 2048 sounds smoother but lags lips).
static func build_chain(p: Variant) -> Array:
	var d: Dictionary = preset(p) if p is String else p
	var out: Array = []
	var ps := AudioEffectPitchShift.new()
	ps.pitch_scale = clamp_pitch(float(d.get("pitch", 1.0)))
	ps.fft_size = AudioEffectPitchShift.FFT_SIZE_1024
	ps.oversampling = 4
	out.append(ps)
	var eq := AudioEffectEQ6.new()
	var g := formant_gains(float(d.get("formant", 0.0)), bool(d.get("band", false)))
	for i in 6: eq.set_band_gain_db(i, g[i])
	out.append(eq)
	return out

## Create (or rebuild) a bus with the chain. Returns the bus index. Natural = no effects (cheapest).
static func ensure_bus(p: Variant = "natural", bus := BUS, send := "Master") -> int:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		AudioServer.add_bus(); i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus); AudioServer.set_bus_send(i, send)
	for k in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
		if not AudioServer.get_bus_effect(i, k) is AudioEffectCapture: AudioServer.remove_bus_effect(i, k)
	var d: Dictionary = preset(p) if p is String else p
	if is_equal_approx(float(d.get("pitch", 1.0)), 1.0) and is_zero_approx(float(d.get("formant", 0.0))) and not d.get("band", false):
		return i
	var at := 0
	for fx in build_chain(d): AudioServer.add_bus_effect(i, fx, at); at += 1
	return i

## System TTS: fold the preset into tts_speak pitch/rate (both clamped to the TTS-safe range).
static func tts_params(persona_voice: Dictionary, p := "natural") -> Dictionary:
	var d := preset(p)
	return {"pitch": clamp_pitch(float(persona_voice.get("pitch", 1.0)) * float(d["pitch"])),
		"rate": clampf(float(persona_voice.get("rate", 1.0)) * float(d["rate"]), 0.5, 2.0)}

static func current_preset() -> String:
	var ml := Engine.get_main_loop()
	var s: Node = ml.root.get_node_or_null("Settings") if ml is SceneTree else null
	var n := str(s.get_value("voice_fx", "preset", "natural")) if s else "natural"
	return n if PRESETS.has(n) else "natural"
