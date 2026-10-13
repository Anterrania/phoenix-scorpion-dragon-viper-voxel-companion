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
}

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
