class_name CompanionVoice
extends RefCounted
## v0.10 per-companion voice. persona.json "voice": {profile, pitch, rate, locale, cloud_voice_id, tts_enabled}.
## Uses Android/desktop TTS via DisplayServer.tts_speak. Settings voice/tts_enabled is the global mute.
## Cloud hook: if Settings voice/cloud_endpoint is set, cloud_hook is called instead (stub; no endpoint shipped).

static var cloud_hook: Callable = Callable()  # func(profile: Dictionary, text: String) -> void
static var last_spoken := {}  # for tests / UI

static func profile(persona: Dictionary) -> Dictionary:
	var v: Variant = persona.get("voice", {})
	var vd: Dictionary = v if v is Dictionary else {}
	return {"profile": str(vd.get("profile", EveCore.DEFAULT_VOICE)), "pitch": clampf(float(vd.get("pitch", 1.0)), 0.5, 2.0),
		"rate": clampf(float(vd.get("rate", 1.0)), 0.5, 2.0), "locale": str(vd.get("locale", "en")),
		"cloud_voice_id": str(vd.get("cloud_voice_id", "")), "enabled": bool(vd.get("tts_enabled", true))}

static func muted() -> bool:
	return not bool(Settings.get_value("voice", "tts_enabled", true))

static func set_muted(on: bool) -> void:
	Settings.set_value("voice", "tts_enabled", not on)
	if on and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): DisplayServer.tts_stop()

## Returns the route taken: "muted", "cloud", "tts", or "no_tts".
static func speak(id: String, persona: Dictionary, text: String) -> String:
	var p := profile(persona)
	last_spoken = {"id": id, "text": text, "profile": p}
	if muted() or not p["enabled"] or text.strip_edges() == "": return "muted"
	if str(Settings.get_value("voice", "cloud_endpoint", "")) != "" and cloud_hook.is_valid():
		cloud_hook.call(p, text); return "cloud"
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): return "no_tts"
	var voices := DisplayServer.tts_get_voices()
	if voices.is_empty(): return "no_tts"
	var pick: Dictionary = voices[absi(hash(id)) % voices.size()]
	for v in voices:  # prefer matching locale (Eve -> en-CA)
		if str(v.get("language", "")).replace("_", "-").to_lower().begins_with(p["locale"].to_lower()): pick = v; break
	DisplayServer.tts_speak(text, pick["id"], 70, p["pitch"], p["rate"])
	return "tts"
