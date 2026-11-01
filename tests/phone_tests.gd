extends RefCounted
## Phone display + device + voice + media tests (feature/phone-display-media).
## Display scale/clamp/persistence/orientation, export permissions, DeviceCheck, VoiceFx chains,
## CompanionVoice pick + utterance sync, LipSync, BeatDetector + DanceTimeline, Broadcast gate +
## encrypted keys, Settings screen in compact and Large. Restores every static/setting it touches.

class FakeStore:
	signal display_changed
	var d := {}
	var changes := 0
	func _init() -> void: display_changed.connect(func(): changes += 1)
	func get_value(sec: String, key: String, fb: Variant = null) -> Variant: return d.get(sec + "/" + key, fb)
	func set_value(sec: String, key: String, v: Variant) -> void: d[sec + "/" + key] = v

class FakeFace:
	var got := {}
	func drive(ch: Dictionary) -> void: got = ch.duplicate()

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func _restore_display() -> void:
	DisplaySettings.store = null
	DisplaySettings.apply()

# ---------- display ----------
static func run_display(t: Node) -> void:
	t.check(PhoenixTokens.TAP_MIN == 56 and PhoenixTokens.TYPE.label == 15 and PhoenixTokens.TYPE.micro == 13, "display: compact base sizes (56 px taps, 15/13 px type)")
	var fs := FakeStore.new()
	DisplaySettings.store = fs
	DisplaySettings.apply()
	t.check(is_equal_approx(PhoenixTokens.text_scale, 1.0) and PhoenixTokens.tap() == 56 and PhoenixTokens.fs("micro") == 13, "display: default is COMPACT")
	t.check(not DisplaySettings.is_large() and DisplaySettings.orientation() == "auto" and not DisplaySettings.max_view(), "display: defaults compact, auto-rotate, normal view")
	DisplaySettings.set_large(true)
	t.check(PhoenixTokens.tap() == 80 and PhoenixTokens.fs("micro") >= 18 and PhoenixTokens.fs("label") >= 18, "display: Large = 80 px taps, type >= 18 px (micro %d)" % PhoenixTokens.fs("micro"))
	t.check(DisplaySettings.is_large() and PhoenixTokens.is_large(), "display: Large reported on")
	DisplaySettings.set_large(false)
	t.check(PhoenixTokens.tap() == 56 and not DisplaySettings.is_large(), "display: Large off -> compact")
	t.check(is_equal_approx(DisplaySettings.set_text_scale(0.2), PhoenixTokens.TEXT_MIN), "display: text scale clamps at the smallest usable size")
	t.check(is_equal_approx(DisplaySettings.set_text_scale(9.0), PhoenixTokens.TEXT_MAX), "display: text scale clamps at max")
	t.check(is_equal_approx(DisplaySettings.set_icon_scale(-3.0), PhoenixTokens.ICON_MIN) and is_equal_approx(DisplaySettings.set_icon_scale(5.0), PhoenixTokens.ICON_MAX), "display: icon scale clamps")
	fs.d["display/text_scale"] = "garbage"
	t.check(is_equal_approx(DisplaySettings.text_scale(), PhoenixTokens.TEXT_MIN), "display: corrupt stored value falls back to compact")
	DisplaySettings.set_text_scale(1.5)
	t.check(PhoenixTokens.fs("body") == 27 and PhoenixTokens.fs(20) == 30, "display: fs() follows the text scale")
	var th: Theme = load(DisplaySettings.THEME_PATH)
	var base: Dictionary = th.get_meta("base_font_sizes")
	t.check(th.default_font_size == int(round(int(base["__default"]) * 1.5)), "display: theme font sizes scale (default %d)" % th.default_font_size)
	DisplaySettings.set_max_view(true)
	t.check(PhoenixTokens.space(5) == 12 and PhoenixTokens.space(5) < PhoenixTokens.SPACE[5], "display: Max view tightens spacing")
	t.check(fs.changes >= 5, "display: display_changed emitted on every change")
	t.check(DisplaySettings.set_orientation("portrait") == "portrait" and DisplaySettings.last_orientation == DisplayServer.SCREEN_PORTRAIT, "orientation: Portrait locks upright")
	t.check(DisplaySettings.set_orientation("landscape_only") == "auto" and DisplaySettings.last_orientation == DisplayServer.SCREEN_SENSOR, "orientation: unknown -> Auto-rotate (sensor)")
	t.check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR, "orientation: project is sensor (auto-rotate), not landscape-only")
	t.check(str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand", "orientation: stretch aspect expand (layouts get the real size)")
	DisplaySettings.reset()
	t.check(is_equal_approx(PhoenixTokens.text_scale, 1.0) and is_equal_approx(PhoenixTokens.space_scale, 1.0) and th.default_font_size == int(base["__default"]), "display: reset -> compact, theme back to base")
	# layout helpers
	t.check(DisplaySettings.is_portrait_size(Vector2(720, 1280)) and not DisplaySettings.is_portrait_size(Vector2(1280, 720)), "layout: portrait/landscape detection")
	t.check(DisplaySettings.side_margin(Vector2(720, 1280)) == PhoenixTokens.space(5) and DisplaySettings.side_margin(Vector2(2400, 1080)) == 720, "layout: landscape centers a readable column")
	t.check(DisplaySettings.columns_for(720) == 2 and DisplaySettings.columns_for(1280) == 4, "layout: grid columns follow width")
	for vp in [Vector2(720, 1280), Vector2(1280, 720), Vector2(2400, 1080)]:
		var a := ViperRadial.anchor_for(vp)
		var half := ViperRadial.CLOSED_PX / 2.0
		t.check(a.x + half <= vp.x and a.y - half >= 0 and a.y + half <= vp.y, "layout: radial hub on screen at %s" % vp)
	# rescale_tree for hard-coded screens (main HUD patch): no compounding, follows Large
	var box := VBoxContainer.new()
	var hb := Button.new(); hb.custom_minimum_size.y = 80; hb.add_theme_font_size_override("font_size", 24); box.add_child(hb)
	var hl := Label.new(); hl.add_theme_font_size_override("font_size", 32); box.add_child(hl)
	DisplaySettings.rescale_tree(box, 0.75, 0.7)
	DisplaySettings.rescale_tree(box, 0.75, 0.7)
	t.check(hb.get_theme_font_size("font_size") == 18 and hl.get_theme_font_size("font_size") == 24 and hb.custom_minimum_size.y == 56, "rescale: HUD 24/32 px, 80 px -> compact 18/24 px, 56 px (no compounding)")
	DisplaySettings.set_large(true); DisplaySettings.rescale_tree(box, 0.75, 0.7)
	t.check(hb.get_theme_font_size("font_size") >= 24 and hb.custom_minimum_size.y >= 80, "rescale: Large grows HUD text + buttons")
	box.free()
	_restore_display()
	# real Settings persistence (user://settings.cfg in the test's XDG dir)
	var st: Node = t.get_node("/root/Settings")
	var old: Variant = st.get_value("display", "text_scale", 1.0)
	DisplaySettings.set_text_scale(1.25)
	var c := ConfigFile.new(); c.load(st.PATH)
	t.check(is_equal_approx(float(c.get_value("display", "text_scale", 0.0)), 1.25), "display: text scale persists to settings.cfg")
	st.set_value("display", "text_scale", old); DisplaySettings.apply()

# ---------- device / permissions ----------
static func run_device(t: Node) -> void:
	var cfg := ConfigFile.new()
	var txt := FileAccess.get_file_as_string("res://export_presets.cfg")
	t.check(cfg.parse(txt) == OK, "export: export_presets.cfg parses")
	for k in DeviceCheck.PRESET_KEYS:
		t.check(bool(cfg.get_value("preset.0.options", "permissions/" + DeviceCheck.PRESET_KEYS[k], false)), "export: Android permission declared: " + k)
	t.check(DeviceCheck.audio_input_enabled(), "audio: audio/driver/enable_input is on (mic capture)")
	t.check(bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)), "audio: TTS enabled")
	t.check(DeviceCheck.permission_state("camera") == "n/a" and DeviceCheck.ensure("microphone"), "device: desktop/headless -> n/a, nothing to ask")
	DeviceCheck.platform_override = "Android"
	DeviceCheck.granted_override = ["android.permission.RECORD_AUDIO"]
	t.check(DeviceCheck.permission_state("microphone") == "granted" and DeviceCheck.permission_state("camera") == "ask", "device: Android mic granted, camera still to ask")
	t.check(DeviceCheck.permission_state("internet") == "granted" and DeviceCheck.permission_state("vibrate") == "granted", "device: normal permissions granted at install")
	DeviceCheck.requests.clear()
	t.check(not DeviceCheck.ensure("camera") and DeviceCheck.requests == ["camera"], "device: ensure() asks for a missing permission in context")
	var rows := DeviceCheck.report()
	t.check(rows.size() >= 12 and rows.any(func(r): return r["key"] == "camera_feeds") and rows.any(func(r): return r["key"] == "audio_input"), "device: report lists permissions, mic driver, camera feeds, TTS")
	t.check(DeviceCheck.summary(rows).contains(" of %d ready" % rows.size()), "device: summary line")
	DeviceCheck.platform_override = ""; DeviceCheck.granted_override = null; DeviceCheck.requests.clear()

# ---------- voice ----------
static func run_voice(t: Node) -> void:
	var ch := VoiceFx.build_chain("dragon")
	t.check(ch.size() == 2 and ch[0] is AudioEffectPitchShift and ch[1] is AudioEffectEQ6, "voicefx: chain = pitch shift + formant EQ")
	t.check(is_equal_approx((ch[0] as AudioEffectPitchShift).pitch_scale, 0.68) and (ch[0] as AudioEffectPitchShift).fft_size == AudioEffectPitchShift.FFT_SIZE_1024, "voicefx: dragon pitch 0.68, low-latency FFT")
	t.check((ch[1] as AudioEffectEQ6).get_band_gain_db(4) < 0.0 and (ch[1] as AudioEffectEQ6).get_band_gain_db(1) > 0.0, "voicefx: deeper formant cuts highs, lifts chest")
	t.check(VoiceFx.formant_gains(0.7)[4] > 0.0, "voicefx: brighter formant lifts highs")
	t.check(is_equal_approx((VoiceFx.build_chain({"pitch": 9.0})[0] as AudioEffectPitchShift).pitch_scale, VoiceFx.PITCH_MAX), "voicefx: pitch clamped")
	var bus := "VoiceFXTest"
	var i := VoiceFx.ensure_bus("fae", bus)
	t.check(i >= 0 and AudioServer.get_bus_effect_count(i) == 2 and AudioServer.get_bus_effect(i, 0) is AudioEffectPitchShift, "voicefx: bus built with the chain")
	VoiceFx.ensure_bus("natural", bus)
	t.check(AudioServer.get_bus_effect_count(i) == 0, "voicefx: natural = no effects (no CPU)")
	AudioServer.add_bus_effect(i, AudioEffectCapture.new())
	VoiceFx.ensure_bus("deep", bus)
	t.check(AudioServer.get_bus_effect_count(i) == 3 and AudioServer.get_bus_effect(i, 2) is AudioEffectCapture, "voicefx: capture kept after the chain on rebuild")
	AudioServer.remove_bus(i)
	var tp := VoiceFx.tts_params({"pitch": 1.8, "rate": 1.0}, "fae")
	t.check(tp["pitch"] <= VoiceFx.PITCH_MAX and tp["rate"] > 1.0, "voicefx: TTS pitch/rate folded and clamped")
	# CompanionVoice voice pick (bug: every 'en' companion got the same first voice)
	var voices := [{"id": "v1", "language": "en_US"}, {"id": "v2", "language": "en-GB"}, {"id": "v3", "language": "en_CA"}, {"id": "v4", "language": "fr_FR"}]
	var picks := {}
	for id in ["foxy_ani", "aaliyah", "circuit_nova", "storyteller", "celestia_nyx", "seraph_halcyon"]:
		var v := CompanionVoice.pick_voice(id, "en", voices)
		t.check(str(v["language"]).begins_with("en"), "voice pick: %s gets an English voice" % id)
		picks[v["id"]] = true
	t.check(picks.size() >= 2, "voice pick: companions no longer all share one voice (%d voices used)" % picks.size())
	t.check(CompanionVoice.pick_voice("x", "en-ca", voices)["id"] == "v3" and CompanionVoice.pick_voice("x", "en_CA", voices)["id"] == "v3", "voice pick: locale match normalizes en_CA / en-ca")
	t.check(CompanionVoice.pick_voice("x", "de-AT", voices) != {}, "voice pick: missing locale still picks a voice")
	t.check(CompanionVoice.pick_voice("foxy_ani", "en", voices) == CompanionVoice.pick_voice("foxy_ani", "en", voices), "voice pick: stable per companion")
	# utterance sync
	var st: Node = t.get_node("/root/Settings")
	var was_on: Variant = st.get_value("voice", "tts_enabled", true)
	st.set_value("voice", "tts_enabled", true)
	var route := CompanionVoice.speak("t_comp", {"voice": {"pitch": 1.1}}, "Hello Phoenix")
	var utt := int(CompanionVoice.last_spoken.get("utt", -1))
	t.check(route in ["tts", "tts_default", "no_tts"] and utt > 0 and CompanionVoice.talk_state("t_comp")["state"] == "queued", "voice sync: line queued with an utterance id (not talking yet)")
	var evs: Array = []
	var l := func(cid, ev, data): evs.append([cid, ev, data["char"]])
	CompanionVoice.listeners.append(l)
	CompanionVoice.utterance_event(utt, "started")
	t.check(CompanionVoice.is_speaking("t_comp"), "voice sync: talking starts on TTS 'started'")
	CompanionVoice.utterance_event(utt, "boundary", 6)
	t.check(CompanionVoice.talk_state("t_comp")["char"] == 6, "voice sync: word boundary tracked")
	CompanionVoice.utterance_event(utt, "ended")
	t.check(not CompanionVoice.is_speaking("t_comp") and evs.size() == 3 and evs[1] == ["t_comp", "boundary", 6], "voice sync: stops on 'ended'; listeners get every event")
	CompanionVoice.utterance_event(utt + 999, "started")
	t.check(not CompanionVoice.is_speaking("t_comp"), "voice sync: unknown utterance ignored")
	CompanionVoice.listeners.erase(l)
	st.set_value("voice", "tts_enabled", was_on)

# ---------- lip sync ----------
static func run_lipsync(t: Node) -> void:
	var ls := LipSync.new()
	var loud := PackedVector2Array(); loud.resize(512); loud.fill(Vector2(0.3, 0.3))
	var quiet := PackedVector2Array(); quiet.resize(512); quiet.fill(Vector2(0.005, 0.005))
	t.check(is_equal_approx(LipSync.rms(loud), 0.3) and LipSync.rms(PackedVector2Array()) == 0.0, "lipsync: RMS of a block")
	for k in 6: ls.feed_frames(loud)
	var open: float = ls.update(0.016)["jawOpen"]
	t.check(open > 0.4, "lipsync: loud audio opens the jaw (%.2f)" % open)
	for k in 30: ls.feed_frames(quiet)
	t.check(ls.update(0.016)["jawOpen"] < 0.05, "lipsync: noise gate + release closes the jaw")
	var ls2 := LipSync.new()
	ls2.start_text("mama", 1.0)
	t.check(ls2.update(0.01)["viseme_PP"] > 0.5 and ls2.channels["jawOpen"] == 0.0, "lipsync: 'm' closes the lips (PP viseme)")
	ls2.update(LipSync.CHAR_SEC)
	t.check(ls2.channels["viseme_aa"] > 0.5 and ls2.channels["jawOpen"] > 0.2, "lipsync: 'a' opens (aa viseme)")
	ls2.on_boundary(3)
	t.check(ls2.update(0.001)["viseme_aa"] > 0.5, "lipsync: boundary re-aligns to the spoken character")
	ls2.update(5.0)
	t.check(not ls2.is_talking() and ls2.update(0.01)["jawOpen"] == 0.0, "lipsync: stops at the end of the line")
	var ff := FakeFace.new()
	ls.feed_frames(loud); ls.update(0.016)
	t.check(ls.apply_to(ff) == "driver" and ff.got.has("jawOpen") and ff.got.has("viseme_aa"), "lipsync: drives a FaceDriver-style drive(channels)")
	var m: Node3D = HumanoidModel.build({"look": "phoenix"})
	var jaw := m.get_node("Hips/Torso/Head/Jaw") as Node3D
	var y0 := jaw.position.y
	for k in 6: ls.feed_frames(loud)
	ls.update(0.016)
	t.check(ls.apply_to(m) == "jaw" and jaw.position.y < y0, "lipsync: low-poly avatar jaw moves")
	m.free()
	t.check(ls.apply_to(null) == "none", "lipsync: null target safe")
	var mc := MicCapture.new()
	t.check(mc.lip is LipSync and not mc.running, "mic: capture node builds (start needs a phone mic)")
	mc.free()

# ---------- beat detection + dance ----------
static func run_dance(t: Node) -> void:
	for bpm in [120.0, 90.0, 140.0]:
		var s := BeatDetector.click_track(bpm, 8.0, 22050.0)
		var a := BeatDetector.analyze_samples(s, 22050.0)
		t.check(absf(float(a["bpm"]) - bpm) <= 3.0, "beat: %d BPM click track -> %.1f BPM" % [bpm, a["bpm"]])
		t.check(a["onsets"].size() >= int(bpm / 60.0 * 8.0) - 2, "beat: onsets found at %d BPM (%d)" % [bpm, a["onsets"].size()])
		if bpm == 120.0:
			var b: Array = a["beats"]
			t.check(b.size() >= 14 and absf((b[5] - b[4]) - 0.5) < 0.02, "beat: beat grid every 0.5 s")
			var d := DanceTimeline.from_analysis(a, 42)
			var d2 := DanceTimeline.from_analysis(a, 42)
			t.check(d.entries.size() == b.size(), "dance: one move per beat")
			t.check(d.entries.map(func(e): return e["move"]) == d2.entries.map(func(e): return e["move"]), "dance: same seed -> same routine (group dances in sync)")
			var smp := d.sample(float(b[3]) + 0.25)
			t.check(smp["beat"] == 3 and absf(smp["phase"] - 0.5) < 0.05, "dance: sample() finds beat + phase")
			t.check(d.sample(-1.0)["move"] == "idle", "dance: idle before the first beat")
			var m: Node3D = HumanoidModel.build({"look": "fire"})
			var before := [m.get_node("Hips").transform, m.get_node("Hips/Torso/ArmL").transform, m.get_node("Hips/LegL").transform, m.get_node("Hips/Torso/ArmR").transform]
			var moved := false
			for k in 8:
				d.apply(m, float(b[k]) + 0.25)
				var after := [m.get_node("Hips").transform, m.get_node("Hips/Torso/ArmL").transform, m.get_node("Hips/LegL").transform, m.get_node("Hips/Torso/ArmR").transform]
				if after != before: moved = true
			t.check(moved, "dance: routine poses the avatar")
			m.free()
	var silent := PackedFloat32Array(); silent.resize(22050 * 3)
	var z := BeatDetector.analyze_samples(silent, 22050.0)
	t.check(z["onsets"].is_empty() and z["beats"].is_empty(), "beat: silence -> no beats")
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = 22050
	var pcm := PackedByteArray(); var ct := BeatDetector.click_track(100.0, 6.0, 22050.0); pcm.resize(ct.size() * 2)
	for k in ct.size(): pcm.encode_s16(k * 2, int(clampf(ct[k], -1.0, 1.0) * 32767.0))
	w.data = pcm
	t.check(absf(float(BeatDetector.analyze_wav(w)["bpm"]) - 100.0) <= 3.0, "beat: AudioStreamWAV input")

# ---------- broadcast stub ----------
static func run_broadcast(t: Node) -> void:
	var root := "user://test_media_%d" % Time.get_ticks_usec()
	var saved_vault := OwnerVault.root
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	Tiers.reset_for_tests(root.path_join("social")); Social.reset_for_tests(root.path_join("social"))
	Broadcast.reset_for_tests(root.path_join("media"))
	Estate.reset_for_tests(); Estate._cfg = ConfigFile.new()   # in-memory estate, never saved here
	Estate.cfg().set_value("parcel:stage/1_1", "allowed", ["ex_cre_ok"])
	Tiers.owner_override = false
	t.check(Tiers.ACTIONS.has("broadcast") and Tiers.default_matrix()["creator"].has("broadcast") and not Tiers.default_matrix()["resident"].has("broadcast"), "tiers: 'broadcast' is a creator+ action")
	t.check(not Broadcast.add_stream("stranger", "x", "rtmps", "rtmps://a.example/live", "stage/1_1")["ok"], "broadcast: guest refused")
	Tiers.owner_override = true
	Tiers.set_tier("ex_cre", "creator"); Tiers.set_tier("ex_cre_ok", "creator"); Tiers.set_tier("ex_staff", "staff")
	Tiers.owner_override = false
	t.check(not Tiers.can("ex_cre", "broadcast", "stage/1_1") and Tiers.can("ex_cre_ok", "broadcast", "stage/1_1"), "broadcast: creator needs media rights on the parcel (allow list)")
	t.check(Tiers.can("ex_staff", "broadcast", "stage/1_1"), "broadcast: staff can broadcast on estate land")
	t.check(not Broadcast.add_stream("ex_cre_ok", "Show", "rtmps", "javascript:alert(1)", "stage/1_1")["ok"], "broadcast: bad URL refused")
	t.check(not Broadcast.add_stream("ex_cre_ok", "Show", "bogus", "rtmps://a.example/live", "stage/1_1")["ok"], "broadcast: unknown kind refused")
	var r := Broadcast.add_stream("ex_cre_ok", "Concert", "rtmps", "rtmps://a.example/live2", "stage/1_1")
	t.check(r["ok"] and Broadcast.list("stage/1_1").size() == 1, "broadcast: stream entry saved")
	var sid: String = r["id"]
	t.check(not Broadcast.set_stream_key("ex_cre_ok", sid, "live_abcd_1234")["ok"], "broadcast: key refused while saves aren't encrypted")
	t.check(not FileAccess.file_exists(root.path_join("media/stream_keys.json")), "broadcast: no plaintext key file")
	t.check(not Broadcast.go_live("ex_cre_ok", sid)["ok"] and Broadcast.find(sid)["status"] == "awaiting_owner", "broadcast: go live waits for the owner")
	t.check(OwnerVault.setup_for_tests("246810") == "" and OwnerVault.storage_ready(), "broadcast: owner vault for the key test")
	Estate._cfg = ConfigFile.new(); Estate.cfg().set_value("parcel:stage/1_1", "allowed", ["ex_cre_ok"])   # vault setup reloads Estate
	var k := Broadcast.set_stream_key("ex_cre_ok", sid, "live_abcd_1234")
	t.check(k["ok"] and k["hint"] == "••••1234" and SecureFile.is_sealed_file(root.path_join("media/stream_keys.json")), "broadcast: stream key stored ENCRYPTED")
	t.check(not FileAccess.get_file_as_bytes(root.path_join("media/stream_keys.json")).get_string_from_ascii().contains("live_abcd"), "broadcast: key not readable in the file")
	t.check(not JSON.stringify(Broadcast.list()).contains("live_abcd") and Broadcast.list()[0]["has_key"], "broadcast: list() never returns keys")
	Tiers.owner_override = true
	t.check(Broadcast.stream_key_for_encoder(sid) == "live_abcd_1234", "broadcast: encoder reads key with owner session")
	t.check(Broadcast.go_live(Tiers.OWNER_ID, sid)["ok"] and Broadcast.find(sid)["status"] == "approved", "broadcast: owner approves (encoder INACTIVE)")
	Tiers.owner_override = false
	t.check(Broadcast.stream_key_for_encoder(sid) == "", "broadcast: no key without owner session")
	t.check(Broadcast.set_parcel_media("ex_cre_ok", "stage/1_1", "https://www.youtube.com/embed/xyz", "youtube")["ok"] and Broadcast.media_for("stage/1_1")["kind"] == "youtube", "broadcast: parcel media URL set")
	t.check(not Broadcast.set_parcel_media("ex_cre", "stage/1_1", "https://x.example/v.mp4")["ok"], "broadcast: parcel media needs rights")
	t.check(not Broadcast.set_parcel_media("ex_cre_ok", "stage/1_1", "http://insecure.example/v.mp4", "video")["ok"], "broadcast: parcel video must be https")
	Broadcast.reset_for_tests(root.path_join("media"))
	t.check(Broadcast.list().size() == 1 and Broadcast.media_for("stage/1_1")["url"].contains("youtube"), "broadcast: entries persist (encrypted saves)")
	# restore
	Tiers.owner_override = null
	OwnerVault.reset_for_tests(saved_vault, CryptoBox.DEFAULT_ITERATIONS)
	SecureFile.reset_for_tests()
	Tiers.reset_for_tests("user://social"); Social.reset_for_tests("user://social")
	Broadcast.reset_for_tests("user://media")
	Estate.reset_for_tests()
	_rm_tree(root)

# ---------- settings screen ----------
static func run_ui(t: Node) -> void:
	var root := "user://test_media_ui_%d" % Time.get_ticks_usec()
	Broadcast.reset_for_tests(root)
	var fs := FakeStore.new()
	DisplaySettings.store = fs
	DisplaySettings.apply()
	var s := SettingsScreen.new()
	t.get_tree().root.add_child(s)
	await t.get_tree().process_frame
	t.check(s.pages.count() == 4 and SettingsScreen.TABS == ["Display", "Device", "Voice", "Broadcast"], "settings ui: Display, Device, Voice, Broadcast tabs")
	t.check(s.min_tap_ok(56) and s.min_font_ok(13), "settings ui: compact taps >= 56 px, type >= 13 px")
	t.check(s.boxes["Display"].find_child("TextSize", true, false) is HSlider and s.boxes["Display"].find_child("IconSize", true, false) is HSlider, "settings ui: text + icon size sliders")
	DisplaySettings.set_large(true)
	s.build()   # display_changed rebuilds on the next frame; build now for the check
	await t.get_tree().process_frame
	t.check(s.min_tap_ok(80) and s.min_font_ok(18), "settings ui: Large -> taps >= 80 px, type >= 18 px")
	t.check(s.boxes["Device"].get_child_count() >= 3, "settings ui: device check panel built")
	var msg := s.save_stream("Show", "rtmps://a.example/live", "stage/1_1", "")
	t.check(msg != "Stream saved", "settings ui: locked phone can't add a stream (%s)" % msg)
	s.queue_free()
	var a: Control = load("res://scenes/admin/admin_screen.tscn").instantiate()
	t.get_tree().root.add_child(a)
	await t.get_tree().process_frame
	var gear := a.find_child("Settings", true, false) as Button
	t.check(gear != null and gear.text == "⚙", "admin: ⚙ Settings in the header")
	gear.pressed.emit()
	await t.get_tree().process_frame
	t.check(t.get_tree().root.get_node_or_null("SettingsScreen") is SettingsScreen, "admin: ⚙ opens Settings")
	t.get_tree().root.get_node("SettingsScreen").queue_free()
	a.queue_free()
	await t.get_tree().process_frame
	DisplaySettings.set_large(false)
	_restore_display()
	Broadcast.reset_for_tests("user://media")
	_rm_tree(root)

# ---------- docs ----------
static func run_docs(t: Node) -> void:
	t.check(FileAccess.file_exists("res://docs/modules/MEDIA_BROADCAST.md"), "docs: MEDIA_BROADCAST spec")
	var spec := FileAccess.get_file_as_string("res://docs/modules/MEDIA_BROADCAST.md")
	for w in ["YouTube", "SoundCloud", "OAuth", "RTMP", "Tiers.can", "owner", "BeatDetector", "Built", "Planned"]:
		t.check(spec.contains(w), "docs: spec covers " + w)
	for p in ["display-settings", "device-check", "media-broadcast"]:
		var txt := FileAccess.get_file_as_string("res://docs/wiki/%s.md" % p)
		t.check(txt.begins_with("---\ntitle: ") and txt.contains("\nslug: %s\n" % p) and txt.contains("\nstatus: "), "wiki: %s page with front matter" % p)
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	for n in ["DisplaySettings", "DeviceCheck", "MediaBroadcast"]:
		t.check(wiki is Dictionary and wiki.has(n), "wiki seed: " + n)
	var tk: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/tickets_seed.json"))
	var n := 0
	for x in tk:
		if str(x.get("milestone", "")).begins_with("PHONE-"): n += 1
	t.check(n >= 6, "tracker: PHONE-* rows seeded (%d)" % n)
