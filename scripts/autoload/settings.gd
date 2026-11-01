extends Node
## User-editable settings persisted to user://settings.cfg.
## API keys are entered by the user at runtime (settings UI) and NEVER committed.

const PATH := "user://settings.cfg"
var cfg := ConfigFile.new()

const DEFAULTS := {
	"llm": {
		# Any OpenAI-compatible chat-completions endpoint works.
		# Example Grok/xAI endpoint: https://api.x.ai/v1/chat/completions (model e.g. "grok-4").
		"endpoint": "https://api.x.ai/v1/chat/completions",
		"model": "grok-4",
		# api_key: NOT stored here (SEC-FIX-2). See set_api_key() / secrets.bin.
		"timeout_sec": 45.0,
		# v0.5: "canned" = offline persona replies; "live" = call the endpoint above.
		# LAI-3: "local" = on-device model (LocalLLM, no key) is the default; live stays optional, canned is the last fallback.
		# "mode": "canned",
		"mode": "local",
	},
	# LAI-3: on-device AI (LocalLLM). model "auto" = catalog default (data/ai/local_models.json).
	"local_ai": {"model": "auto", "wifi_only": true, "auto_download": true, "enabled": true},
	"content": {"mature_cosmetics_enabled": false, "age_confirmed": false},
	"ui": {"show_menu_on_start": false, "show_labels": false, "compact": true},
	# "voice": {"tts_enabled": true, "push_to_talk": false},
	# v0.13 VOICE-2: customizable from the start. pitch/rate multiply each companion's own voice;
	# locale "" = companion's own; voice_id "" = automatic pick (CompanionVoice.pick_voice).
	"voice": {"tts_enabled": true, "push_to_talk": false, "pitch": 1.0, "rate": 1.0, "locale": "", "voice_id": ""},
	# v0.13 PERSONA-1: "foxy" (default) or "none" (PersonaPresets).
	"persona": {"preset": "foxy"},
	# v0.13 BRAIN: record chat turns + in-world scene changes to the local hash-chained ledger.
	"brain": {"record": true, "scene_snapshots": true},
	"input": {"autocorrect": true, "capitalize": true, "ai_suggest": true},   # v0.13.1 TYPE-1
	"look": {"glam": "subtle"},   # v0.13.1 GLAM-1: off | subtle | full
	# Royalty-free default (Kevin MacLeod, incompetech.com, CC BY 4.0). YOUR INPUT HERE: your station URL.
	"music": {"enabled": true, "volume_db": -12.0, "url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Local%20Forecast%20-%20Elevator.mp3", "user_url": "", "soundcloud_url": "", "everywhere": true, "muted": false, "sc_client_id": "", "sc_client_secret": ""},
	"sync": {"endpoint": ""},
	"hotreload": {"allow_user_overrides": true},
	"graphics": {"quality": 1},  # 0 Low, 1 Medium, 2 High
	# Display / accessibility (DisplaySettings). Compact by default; Settings > Display > Large.
	"display": {"text_scale": 1.0, "icon_scale": 1.0, "max_view": false, "orientation": "auto"},
	# Voice morph preset (VoiceFx.PRESETS) for mic/voice chat + lip sync on/off.
	"voice_fx": {"preset": "natural", "lip_sync": true, "mic_gate": 0.02},
}

## Emitted by DisplaySettings.apply() after text/icon scale, Max view or orientation change.
signal display_changed

signal quality_changed(level: int)
const QUALITY_NAMES := ["LOW", "MED", "HIGH"]
## Per-level presets: terrain view distance (m), LOD levels, camera far, render scale,
## glow, sun shadows, MSAA.
const QUALITY := [
	{"view": 256, "lods": 4, "far": 900.0, "scale": 0.7, "glow": false, "shadows": false, "msaa": 0},
	{"view": 512, "lods": 5, "far": 1600.0, "scale": 0.85, "glow": true, "shadows": false, "msaa": 0},
	{"view": 1024, "lods": 6, "far": 3000.0, "scale": 1.0, "glow": true, "shadows": true, "msaa": 1},
]

func quality() -> int:
	return clampi(int(get_value("graphics", "quality", 1)), 0, 2)

func quality_preset(level: int = -1) -> Dictionary:
	return QUALITY[quality() if level < 0 else clampi(level, 0, 2)]

func set_quality(level: int) -> void:
	set_value("graphics", "quality", clampi(level, 0, 2))
	quality_changed.emit(quality())

func cycle_quality() -> int:
	set_quality((quality() + 1) % 3)
	return quality()

func _ready() -> void:
	if cfg.load(PATH) != OK:
		for section in DEFAULTS:
			for key in DEFAULTS[section]:
				cfg.set_value(section, key, DEFAULTS[section][key])
		cfg.save(PATH)
	DisplaySettings.apply()   # scale tokens/theme + orientation before any UI is built
	migrate_api_key()

func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	if section == "llm" and key == "api_key": return user_api_key()   # SEC-FIX-2: never from settings.cfg
	var d: Variant = DEFAULTS.get(section, {}).get(key, fallback)
	return cfg.get_value(section, key, d)

func set_value(section: String, key: String, value: Variant) -> void:
	if section == "llm" and key == "api_key": set_api_key(str(value)); return   # SEC-FIX-2
	cfg.set_value(section, key, value)
	cfg.save(PATH)

func mature_enabled() -> bool:
	return bool(get_value("content", "mature_cosmetics_enabled", false)) and bool(get_value("content", "age_confirmed", false))

## Live AI only when the user picked "live" AND entered a key (config hook for later).
func live_ai() -> bool:
	# CHAT-2: same rule as chat_status() (was: status said "offline_mode" while live_ai() was true with a build key).
	# return (str(get_value("llm", "mode", "canned")) == "live" or (build_default_key() != "" and not cfg.has_section_key("llm", "mode_set"))) and has_api_key()
	return effective_mode() == "live" and has_api_key() and llm_endpoint() != ""

## CHAT-2: "live" when the user picked live, or a build-time key exists and the user never chose a mode.
## LAI-3: otherwise "local" (on-device model). "canned" only when the user explicitly picked offline replies;
## an old saved "canned" without mode_set was just the previous default, so it migrates to "local".
# func effective_mode() -> String:
# 	if str(get_value("llm", "mode", "canned")) == "live": return "live"
# 	if build_default_key() != "" and not cfg.has_section_key("llm", "mode_set"): return "live"
# 	return "canned"
func effective_mode() -> String:
	var m := str(get_value("llm", "mode", "local"))
	if m == "live": return "live"
	if build_default_key() != "" and not cfg.has_section_key("llm", "mode_set"): return "live"
	if m == "canned" and bool(cfg.get_value("llm", "mode_set", false)): return "canned"
	return "local"

## LAI-3: the LocalLLM autoload, or null (unit tests that run without it).
func local_llm() -> Node:
	return get_node_or_null("/root/LocalLLM") if is_inside_tree() else null

## LAI-3: chat should go to the on-device model (not live, not explicit canned, model usable now).
func local_ai() -> bool:
	if live_ai() or effective_mode() == "canned": return false
	var l := local_llm()
	return l != null and l.can_chat()

## CHAT-3: Settings UI key entry. Entering a key turns live chat on unless the user explicitly chose
## offline replies (mode_set). Before this, a pasted key did nothing until the mode button was found.
func set_api_key_from_ui(k: String) -> void:
	set_api_key(k)
	last_chat_error = ""
	if k.strip_edges() != "" and not bool(cfg.get_value("llm", "mode_set", false)):
		set_value("llm", "mode", "live")

## CHAT-4: validated endpoint. Trims, adds https:// when no scheme was typed, "" if unusable.
func llm_endpoint() -> String:
	return normalize_endpoint(str(get_value("llm", "endpoint", "")))

static func normalize_endpoint(raw: String) -> String:
	var e := raw.strip_edges()
	if e == "": return ""
	if not e.contains("://"): e = "https://" + e
	if not (e.begins_with("https://") or e.begins_with("http://")): return ""
	var host := e.split("://", true, 1)[1].split("/")[0]
	if host == "" or host.contains(" ") or not (host.contains(".") or host.begins_with("localhost")): return ""
	return e

## CHAT-5: plain-language reason for a failed live request (HTTPRequest result + HTTP code + body).
static func chat_error_text(result: int, code: int, body := "") -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE: return "can't find the AI server (DNS / no internet). Check Wi-Fi or data and the endpoint."
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR: return "can't connect to the AI server. Check your connection."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "secure connection failed (TLS). Check the phone's date/time."
		HTTPRequest.RESULT_TIMEOUT: return "the AI server took too long to answer."
		HTTPRequest.RESULT_NO_RESPONSE, HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, HTTPRequest.RESULT_REQUEST_FAILED: return "the AI server sent no usable answer."
	if result != HTTPRequest.RESULT_SUCCESS: return "network error (%d)." % result
	var msg := ""
	var d: Variant = JSON.parse_string(body) if body != "" else null
	if d is Dictionary:
		var e: Variant = d.get("error")
		msg = str(e.get("message", "")) if e is Dictionary else (str(e) if e != null else "")
	msg = msg.left(160)
	match code:
		401, 403: return "the API key was rejected (%d). Re-enter it in Settings › Companion AI." % code
		404: return "endpoint or model not found (404). Check the endpoint and model in Settings."
		429: return "rate limit or credits used up (429). Try again later."
	if code >= 500: return "the AI service is having trouble (%d)." % code
	if code >= 400: return "request refused (%d)%s" % [code, (": " + msg) if msg != "" else "."]
	return ""

func has_api_key() -> bool:
	return api_key() != ""


# ---------- v0.9 live chat ----------
## Optional build-time default key: res://config/llm_default.local.cfg ([llm] api_key=...).
## That file is gitignored, so no secret is ever committed. User settings always win.
const BUILD_DEFAULT := "res://config/llm_default.local.cfg"

static func build_default_key() -> String:
	if not FileAccess.file_exists(BUILD_DEFAULT): return ""
	var c := ConfigFile.new()
	if c.load(BUILD_DEFAULT) != OK: return ""
	return str(c.get_value("llm", "api_key", "")).strip_edges()

func api_key() -> String:
	var k := user_api_key()
	return k if k != "" else build_default_key()

# ---------- SEC-FIX-2: API key in an encrypted store ----------
## The user's key lives in <OwnerVault.root>/secrets.bin, sealed with the vault data key
## (CryptoBox, same as SecureFile). It is NEVER written in plaintext: with no vault / key loaded it is
## held in memory only, and sealed as soon as the owner unlocks or sets a PIN.
## One-time migration: a plaintext [llm] api_key found in settings.cfg is moved into the store and
## blanked from settings.cfg (immediately in memory; on disk as soon as it is sealed).
var _secret_mem := ""        # current key (memory)
var _secret_loaded := false  # sealed store has been read
var _secret_dirty := false   # memory value not yet sealed to disk
var _hooked := false

static func secrets_path() -> String: return OwnerVault.root.path_join("secrets.bin")

func _hook_vault() -> void:
	if _hooked: return
	_hooked = true
	OwnerVault.on_storage_ready.append(func(): _secret_loaded = false; flush_secrets())

## Move a plaintext key out of settings.cfg. Safe to call repeatedly.
func migrate_api_key() -> void:
	_hook_vault()
	if not cfg.has_section_key("llm", "api_key"): return
	var legacy := str(cfg.get_value("llm", "api_key", "")).strip_edges()
	if legacy != "" and user_api_key() == "":
		_secret_mem = legacy; _secret_dirty = true
	if legacy == "" or flush_secrets():
		# flush_secrets() already erases the plaintext key; erasing again logged "nonexistent key".
		if cfg.has_section_key("llm", "api_key"): cfg.erase_section_key("llm", "api_key")
		cfg.save(PATH)

func _read_store() -> void:
	if _secret_loaded or not OwnerVault.storage_ready(): return
	_secret_loaded = true
	if _secret_dirty or not FileAccess.file_exists(secrets_path()): return
	var k := OwnerVault.dek()
	var st := {}
	var p := CryptoBox.open(k["enc"], k["mac"], FileAccess.get_file_as_bytes(secrets_path()), st)
	var d: Variant = JSON.parse_string(p.get_string_from_utf8()) if st["ok"] else null
	if d is Dictionary: _secret_mem = str(d.get("llm_api_key", ""))
	elif not st["ok"]: push_error("Settings: secrets store failed its integrity check; key not loaded")

func user_api_key() -> String:
	_read_store()
	return _secret_mem.strip_edges()

func set_api_key(k: String) -> void:
	_hook_vault()
	_read_store()
	_secret_mem = k.strip_edges(); _secret_dirty = true
	flush_secrets()

## Seal the in-memory key to disk. False if no data key is loaded (stays in memory only).
func flush_secrets() -> bool:
	if not OwnerVault.storage_ready(): return not _secret_dirty
	_read_store()
	if _secret_dirty:
		var k := OwnerVault.dek()
		DirAccess.make_dir_recursive_absolute(secrets_path().get_base_dir())
		var tmp := secrets_path() + ".tmp"
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		if f == null: return false
		f.store_buffer(CryptoBox.seal(k["enc"], k["mac"], JSON.stringify({"llm_api_key": _secret_mem}).to_utf8_buffer()))
		f.close()
		SecureFile.replace_file(tmp, secrets_path())
		_secret_dirty = false
	if cfg.has_section_key("llm", "api_key"):
		cfg.erase_section_key("llm", "api_key"); cfg.save(PATH)
	return true

func reset_secrets_for_tests() -> void:
	_secret_mem = ""; _secret_loaded = false; _secret_dirty = false

## "live" | "offline_no_key" | "offline_mode" | "offline_error" | "local_<LocalLLM.state>" (LAI-3)
const LocalLlmScript := preload("res://scripts/ai/local_llm.gd")
var last_chat_error := ""
func chat_status() -> String:
	# LAI-3: local mode reports the on-device model ("local_ready", "local_downloading", ...).
	var em := effective_mode()
	if em == "canned": return "offline_mode"
	if em == "local":
		var l := local_llm()
		return l.status() if l else "local_unsupported"
	# CHAT-2: a sealed key exists but the vault is locked -> say so (was reported as "no API key").
	if api_key() == "": return "offline_locked" if OwnerVault.has_vault() and not OwnerVault.storage_ready() and FileAccess.file_exists(secrets_path()) else "offline_no_key"
	if effective_mode() != "live": return "offline_mode"
	if llm_endpoint() == "": return "offline_endpoint"
	if last_chat_error != "": return "offline_error"
	return "live"

static func chat_status_text(st: String) -> String:
	if st.begins_with("local_"):
		var ml := Engine.get_main_loop()
		var l: Node = ml.root.get_node_or_null("LocalLLM") if ml is SceneTree else null
		return LocalLlmScript.status_text(st, l.dl_done_mb if l else 0.0, l.dl_total_mb if l else 0.0)
	match st:
		"live": return "● LIVE CHAT online"
		"offline_no_key": return "○ CHAT OFFLINE: no API key. Add it in Settings › Companion AI (stays on this phone)."
		"offline_mode": return "○ CHAT OFFLINE: AI mode is set to offline replies (Settings)."
		"offline_locked": return "○ CHAT OFFLINE: unlock with your PIN to load your saved API key."
		"offline_endpoint": return "○ CHAT OFFLINE: the AI endpoint in Settings › Companion AI isn't a valid web address."
		_: return "○ CHAT OFFLINE: could not reach the AI service. Offline replies until it's back."
