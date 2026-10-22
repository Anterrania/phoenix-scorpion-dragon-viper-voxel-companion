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
		# v0.5: "canned" = offline persona replies (default); "live" = call the endpoint above.
		"mode": "canned",
	},
	"content": {"mature_cosmetics_enabled": false, "age_confirmed": false},
	"ui": {"show_menu_on_start": false, "show_labels": false, "compact": true},
	"voice": {"tts_enabled": true, "push_to_talk": false},
	# Royalty-free default (Kevin MacLeod, incompetech.com, CC BY 4.0). YOUR INPUT HERE: your station URL.
	"music": {"enabled": true, "volume_db": -12.0, "url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Local%20Forecast%20-%20Elevator.mp3", "user_url": "", "soundcloud_url": "", "everywhere": true, "muted": false, "sc_client_id": "", "sc_client_secret": ""},
	"sync": {"endpoint": ""},
	"hotreload": {"allow_user_overrides": true},
	"graphics": {"quality": 1},  # 0 Low, 1 Medium, 2 High
}

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
	return (str(get_value("llm", "mode", "canned")) == "live" or (build_default_key() != "" and not cfg.has_section_key("llm", "mode_set"))) and has_api_key()

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
		cfg.erase_section_key("llm", "api_key")
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

## "live" | "offline_no_key" | "offline_mode" | "offline_error"
var last_chat_error := ""
func chat_status() -> String:
	if api_key() == "": return "offline_no_key"
	if str(get_value("llm", "mode", "canned")) != "live": return "offline_mode"
	if last_chat_error != "": return "offline_error"
	return "live"

static func chat_status_text(st: String) -> String:
	match st:
		"live": return "● LIVE CHAT online"
		"offline_no_key": return "○ CHAT OFFLINE: no API key. Add it in Settings › Companion AI (stays on this phone)."
		"offline_mode": return "○ CHAT OFFLINE: AI mode is set to offline replies (Settings)."
		_: return "○ CHAT OFFLINE: could not reach the AI service. Offline replies until it's back."
