class_name DeviceCheck
extends RefCounted
## Device check (Settings > Device): Android permissions, mic/audio input, camera feeds, TTS,
## vibration, notifications. Runtime requests go through OS.request_permission(s); results arrive on
## SceneTree.on_request_permissions_result. Everything here also runs on desktop/headless, where
## permissions show "n/a (not Android)".
##
## Android permission names declared in export_presets.cfg [preset.0.options] (tests keep them in sync).
const ANDROID := {
	"camera": "android.permission.CAMERA",
	"microphone": "android.permission.RECORD_AUDIO",
	"audio_settings": "android.permission.MODIFY_AUDIO_SETTINGS",
	"notifications": "android.permission.POST_NOTIFICATIONS",
	"photos": "android.permission.READ_MEDIA_IMAGES",
	"videos": "android.permission.READ_MEDIA_VIDEO",
	"music_files": "android.permission.READ_MEDIA_AUDIO",
	"storage_legacy": "android.permission.READ_EXTERNAL_STORAGE",
	"internet": "android.permission.INTERNET",
	"network_state": "android.permission.ACCESS_NETWORK_STATE",
	"vibrate": "android.permission.VIBRATE",
}
## Normal (install-time) permissions: granted by declaring them, never prompted.
const NORMAL := ["audio_settings", "internet", "network_state", "vibrate"]
## export_presets.cfg option key for each permission.
const PRESET_KEYS := {"camera": "camera", "microphone": "record_audio", "audio_settings": "modify_audio_settings",
	"notifications": "post_notifications", "photos": "read_media_images", "videos": "read_media_video",
	"music_files": "read_media_audio", "storage_legacy": "read_external_storage", "internet": "internet",
	"network_state": "access_network_state", "vibrate": "vibrate"}
const LABELS := {"camera": "Camera", "microphone": "Microphone", "audio_settings": "Audio routing",
	"notifications": "Notifications", "photos": "Photos", "videos": "Videos", "music_files": "Music files",
	"storage_legacy": "Storage (Android 12 and older)", "internet": "Internet", "network_state": "Network status",
	"vibrate": "Vibration"}

static var granted_override = null   # tests: Array of granted Android permission names
static var platform_override := ""   # tests: "Android" to simulate a phone
static var requests: Array = []      # permissions requested this session (tests + UI)

static func is_android() -> bool:
	return (platform_override if platform_override != "" else OS.get_name()) == "Android"

static func granted() -> PackedStringArray:
	if granted_override != null: return PackedStringArray(granted_override)
	return OS.get_granted_permissions() if OS.get_name() == "Android" else PackedStringArray()

## "granted" | "ask" (dangerous, not yet granted) | "n/a" (not Android).
static func permission_state(key: String) -> String:
	if not is_android(): return "n/a"
	if key in NORMAL: return "granted"
	return "granted" if ANDROID.get(key, "") in granted() else "ask"

## Ask for one permission in context (e.g. before mic capture). Returns true if already granted.
static func ensure(key: String) -> bool:
	if not is_android(): return true
	if permission_state(key) == "granted": return true
	requests.append(key)
	if OS.get_name() == "Android": return OS.request_permission(ANDROID[key])
	return false

## Ask for every dangerous permission the export declares (Device check > "Ask for permissions").
static func request_all() -> bool:
	if not is_android(): return true
	requests.append("all")
	return OS.request_permissions() if OS.get_name() == "Android" else false

static func audio_input_enabled() -> bool:
	return bool(ProjectSettings.get_setting("audio/driver/enable_input", false))

static func camera_feeds() -> int:
	if not ClassDB.class_exists("CameraServer"): return 0
	CameraServer.monitoring_feeds = true    # Godot 4.4+: feeds are only listed while monitoring
	return CameraServer.get_feed_count()

static func tts_voices() -> int:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): return 0
	return DisplayServer.tts_get_voices().size()

## Device detection belongs to Foxy's DeviceProfile autoload (caps()). Read it when present;
## otherwise fall back to the local probes below. Returns {} when DeviceProfile is absent.
static func device_caps() -> Dictionary:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree): return {}
	var dp: Node = (ml as SceneTree).root.get_node_or_null("DeviceProfile")
	if dp == null or not dp.has_method("caps"): return {}
	var c: Variant = dp.call("caps")
	return c if c is Dictionary else {}

static func orientation_name() -> String:
	var caps := device_caps()
	if str(caps.get("orientation", "")) != "": return str(caps["orientation"]).capitalize()
	if DisplayServer.get_name() == "headless": return DisplaySettings.ORIENTATION_LABELS.get(DisplaySettings.orientation(), "Auto-rotate")
	match DisplayServer.screen_get_orientation():
		DisplayServer.SCREEN_SENSOR: return "Auto-rotate"
		DisplayServer.SCREEN_PORTRAIT: return "Portrait"
		DisplayServer.SCREEN_LANDSCAPE: return "Landscape"
	return "Rotating"

## Rows for the Device check panel: {key, label, state, detail, ok}. state is shown in the UI.
static func report() -> Array:
	var rows: Array = []
	for k in ["camera", "microphone", "notifications", "photos", "videos", "music_files", "internet", "vibrate"]:
		var st := permission_state(k)
		rows.append({"key": k, "label": LABELS[k], "state": {"granted": "Allowed", "ask": "Not allowed yet", "n/a": "n/a (not Android)"}[st],
			"ok": st != "ask", "detail": ANDROID[k]})
	var ai := audio_input_enabled()
	rows.append({"key": "audio_input", "label": "Audio input (mic driver)", "state": "On" if ai else "Off", "ok": ai,
		"detail": "Project setting audio/driver/enable_input"})
	var mic := AudioServer.get_input_device_list()
	rows.append({"key": "mic_devices", "label": "Mic devices", "state": "%d found" % mic.size(), "ok": mic.size() > 0,
		"detail": ", ".join(mic)})
	var feeds := camera_feeds()
	rows.append({"key": "camera_feeds", "label": "Camera feeds", "state": "%d found" % feeds, "ok": feeds > 0,
		"detail": "CameraServer (needs Camera allowed on Android)"})
	var tv := tts_voices()
	rows.append({"key": "tts", "label": "Text-to-speech voices", "state": "%d voices" % tv, "ok": tv > 0, "detail": "DisplayServer TTS"})
	rows.append({"key": "orientation", "label": "Screen", "state": orientation_name(), "ok": true,
		"detail": "Settings > Display > Orientation"})
	var caps := device_caps()
	for k in ["form_factor", "compute", "network", "thermal"]:
		if caps.has(k):
			var v: Variant = caps[k]
			rows.append({"key": "caps_" + k, "label": k.capitalize(), "state": "Unknown" if (str(v) == "" or str(v) == "-1") else str(v),
				"ok": true, "detail": "DeviceProfile.caps()"})
	return rows

## Short summary for headers: "7 of 12 ready".
static func summary(rows: Array = []) -> String:
	if rows.is_empty(): rows = report()
	return "%d of %d ready" % [rows.filter(func(r): return r["ok"]).size(), rows.size()]
