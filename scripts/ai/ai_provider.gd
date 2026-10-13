# Provider-agnostic AI adapter. NOT yet run in Godot.
# Reasoning backends: LocalProvider (offline, default) and GrokProvider (optional, online).
# Copilot / Gemini / Meta AI are NOT backends; they are data importers (see data_importer.gd).
class_name AIProvider
extends RefCounted

signal reply_ready(text: String, tool_calls: Array)

## Unique id: "local" or "grok"
func get_id() -> String: return "base"
func is_available() -> bool: return false
func requires_network() -> bool: return true

## messages: Array of {role, content}. tools: Array of {name, description, params}.
## Must emit reply_ready exactly once.
func chat(_persona: Dictionary, _messages: Array, _tools: Array) -> void:
	push_error("AIProvider.chat not implemented")
	reply_ready.emit("", [])


## Offline default: rule-based now; llama.cpp GDExtension later (small GGUF model on device).
class LocalProvider extends AIProvider:
	var llama = null # future: llama.cpp GDExtension node/object
	func get_id() -> String: return "local"
	func is_available() -> bool: return true
	func requires_network() -> bool: return false
	func chat(persona: Dictionary, messages: Array, _tools: Array) -> void:
		var last: String = messages.back().get("content", "").to_lower() if messages.size() > 0 else ""
		var calls: Array = []
		var text := "%s is listening." % persona.get("name", "Companion")
		if "build" in last:
			calls.append({"name": "place_voxel", "args": {}}); text = "On it, building!"
		elif "dig" in last:
			calls.append({"name": "carve_area", "args": {"radius": 2}}); text = "Digging here."
		elif "follow" in last:
			calls.append({"name": "follow", "args": {}}); text = "Right behind you."
		reply_ready.emit(text, calls)


## Optional online backend: Grok (xAI API). Endpoint/key from user Settings, never hardcoded.
class GrokProvider extends AIProvider:
	var endpoint := ""
	var api_key := ""
	var model := ""
	func get_id() -> String: return "grok"
	func is_available() -> bool: return endpoint != "" and api_key != ""
	func chat(_persona: Dictionary, _messages: Array, _tools: Array) -> void:
		# TODO: HTTPRequest to xAI chat completions with tool definitions.
		push_warning("Grok provider not implemented yet; falling back to local")
		reply_ready.emit("", [])


static func create_default() -> AIProvider:
	return LocalProvider.new()
