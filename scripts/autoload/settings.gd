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
		"api_key": "",
		"timeout_sec": 45.0,
	},
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

func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	var d: Variant = DEFAULTS.get(section, {}).get(key, fallback)
	return cfg.get_value(section, key, d)

func set_value(section: String, key: String, value: Variant) -> void:
	cfg.set_value(section, key, value)
	cfg.save(PATH)

func has_api_key() -> bool:
	return str(get_value("llm", "api_key", "")).strip_edges() != ""
