extends Node
## SCAFFOLD: resolves canonical companion ids (e.g. "foxy-ani-firecaster-grey")
## to res://companions/<dir>/persona.json via companions/registry.json.
## Same persona file is read by the 3D companion and exported for the Grok Bot form.
## Not yet registered as an autoload in project.godot (add manually when wiring).

const REGISTRY_PATH := "res://companions/registry.json"
var _map: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if f == null:
		push_warning("persona registry missing: %s" % REGISTRY_PATH)
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_map = data.get("companions", {})

func persona_path(id: String) -> String:
	if _map.has(id):
		return "res://companions/%s/persona.json" % _map[id]["dir"]
	return "res://companions/%s/persona.json" % id.replace("-", "_")

func load_persona(id: String) -> Dictionary:
	var f := FileAccess.open(persona_path(id), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}
