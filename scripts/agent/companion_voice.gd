class_name CompanionVoice
extends RefCounted
## v0.10 per-companion voice. persona.json "voice": {profile, pitch, rate, locale, cloud_voice_id, tts_enabled}.
## Uses Android/desktop TTS via DisplayServer.tts_speak. Settings voice/tts_enabled is the global mute.
## Cloud hook: if Settings voice/cloud_endpoint is set, cloud_hook is called instead (stub; no endpoint shipped).
##
## 2026-10-17 voice fixes (VOICE-1):
## - Voice pick: the locale loop used to override the per-companion hash, so every "en" companion got
##   the FIRST English voice (all sounded the same). Now: filter by locale, then hash within matches.
## - Locale match normalizes "en_CA" / "en-ca" on both sides.
## - Morph: Settings voice_fx/preset (VoiceFx) folds into TTS pitch/rate (system TTS can't take bus
##   effects; see VoiceFx).
## - Sync: each line gets an utterance id; TTS started/boundary/ended callbacks drive talk_state(), so
##   lip sync starts when the phone actually starts speaking and stops when it ends (it used to run on
##   a length estimate from the moment the line was queued, so lips moved early and drifted).

static var cloud_hook: Callable = Callable()  # func(profile: Dictionary, text: String) -> void
static var last_spoken := {}  # for tests / UI
static var _next_utt := 1
static var _utt := {}          # utterance id -> {"id": companion id, "text": String}
static var _talk := {}         # companion id -> {"state": "queued"|"speaking"|"done", "text", "char", "utt"}
static var _hooked := false
static var listeners: Array[Callable] = []   # func(companion_id, event, data) - LipSync hookups

static func profile(persona: Dictionary) -> Dictionary:
	var v: Variant = persona.get("voice", {})
	var vd: Dictionary = v if v is Dictionary else {}
	return {"profile": str(vd.get("profile", EveCore.DEFAULT_VOICE)), "pitch": clampf(float(vd.get("pitch", 1.0)), 0.5, 2.0),
		"rate": clampf(float(vd.get("rate", 1.0)), 0.5, 2.0), "locale": str(vd.get("locale", "en")),
		"cloud_voice_id": str(vd.get("cloud_voice_id", "")), "enabled": bool(vd.get("tts_enabled", true)),
		"fx": str(vd.get("fx", ""))}

static func muted() -> bool:
	return not bool(Settings.get_value("voice", "tts_enabled", true))

static func set_muted(on: bool) -> void:
	Settings.set_value("voice", "tts_enabled", not on)
	if on and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): DisplayServer.tts_stop()

static func _norm_locale(s: String) -> String: return s.replace("_", "-").to_lower()

## Pick a system voice: matching locale first, then a stable per-companion choice among them.
static func pick_voice(id: String, locale: String, voices: Array) -> Dictionary:
	if voices.is_empty(): return {}
	var want := _norm_locale(locale)
	var pool := voices.filter(func(v): return _norm_locale(str(v.get("language", ""))).begins_with(want))
	if pool.is_empty() and want.contains("-"):   # en-CA missing -> any en
		var base := want.split("-")[0]
		pool = voices.filter(func(v): return _norm_locale(str(v.get("language", ""))).begins_with(base))
	if pool.is_empty(): pool = voices
	return pool[absi(hash(id)) % pool.size()]

static func _hook() -> void:
	if _hooked or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): return
	_hooked = true
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_STARTED, func(u): utterance_event(int(u), "started"))
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, func(u): utterance_event(int(u), "ended"))
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, func(u): utterance_event(int(u), "ended"))
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_BOUNDARY, func(pos, u): utterance_event(int(u), "boundary", int(pos)))

## TTS callback router (public so tests and the cloud path can drive it).
static func utterance_event(utt: int, ev: String, pos := 0) -> void:
	var u: Dictionary = _utt.get(utt, {})
	if u.is_empty(): return
	var cid: String = u["id"]
	var st: Dictionary = _talk.get(cid, {})
	if int(st.get("utt", -1)) != utt and ev != "ended": return
	match ev:
		"started": st["state"] = "speaking"; st["char"] = 0
		"boundary": st["char"] = pos
		"ended":
			_utt.erase(utt)
			if int(st.get("utt", -1)) == utt: st["state"] = "done"
	_talk[cid] = st
	for l in listeners:
		if l.is_valid(): l.call(cid, ev, {"text": u["text"], "char": pos, "rate": float(st.get("rate", 1.0))})

static func talk_state(id: String) -> Dictionary: return _talk.get(id, {"state": "done"})
static func is_speaking(id: String) -> bool: return talk_state(id).get("state") == "speaking"

## Returns the route taken: "muted", "cloud", "tts", or "no_tts".
static func speak(id: String, persona: Dictionary, text: String) -> String:
	var p := profile(persona)
	var fx := VoiceFx.tts_params(p, p["fx"] if p["fx"] != "" else VoiceFx.current_preset())
	last_spoken = {"id": id, "text": text, "profile": p, "tts": fx}
	if muted() or not p["enabled"] or text.strip_edges() == "": return "muted"
	var utt := _next_utt; _next_utt += 1
	_utt[utt] = {"id": id, "text": text}
	_talk[id] = {"state": "queued", "text": text, "char": 0, "utt": utt, "rate": fx["rate"]}
	last_spoken["utt"] = utt
	if str(Settings.get_value("voice", "cloud_endpoint", "")) != "" and cloud_hook.is_valid():
		cloud_hook.call(p, text); return "cloud"
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): return "no_tts"
	var voices := DisplayServer.tts_get_voices()
	if voices.is_empty(): return "no_tts"
	_hook()
	var pick := pick_voice(id, p["locale"], voices)
	last_spoken["voice_id"] = pick.get("id", "")
	DisplayServer.tts_speak(text, pick["id"], 70, fx["pitch"], fx["rate"], utt)
	return "tts"
