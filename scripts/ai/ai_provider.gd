# Provider-agnostic AI adapter. NOT yet run in Godot.
# Default is LocalProvider (offline). Cloud providers are optional stubs; none is wired up yet.
class_name AIProvider
extends RefCounted

signal reply_ready(text: String, tool_calls: Array)

## Unique id: "local", "grok", "gemini", "copilot", "meta_llama"
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


## Cloud stub shared shape (HTTPRequest + JSON). Endpoint/key come from user Settings, never hardcoded.
class CloudProvider extends AIProvider:
	var id := "cloud"
	var endpoint := ""
	var api_key := ""
	var model := ""
	func _init(p_id: String) -> void: id = p_id
	func get_id() -> String: return id
	func is_available() -> bool: return endpoint != "" and api_key != ""
	func chat(_persona: Dictionary, _messages: Array, _tools: Array) -> void:
		# TODO: build provider-specific request (xAI / Gemini / Azure-Copilot / Meta Llama API)
		push_warning("%s provider not implemented yet; falling back" % id)
		reply_ready.emit("", [])


static func create_default() -> AIProvider:
	return LocalProvider.new()
