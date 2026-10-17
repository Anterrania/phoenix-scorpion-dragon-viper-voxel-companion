extends Node
## AgentBrain: shared LLM client, per-companion memory, and tool dispatch.
## Each CompanionAgent registers itself; AgentBrain builds the prompt from the
## companion's persona.json + memory, calls the configured endpoint, and executes
## returned tool calls against the world (VoxelTerrain) through the agent.

signal reply_ready(companion_id: String, text: String)
signal tool_executed(companion_id: String, tool: String, result: Dictionary)
signal request_failed(companion_id: String, error: String)

const MEMORY_DIR := "user://memory"
const MAX_HISTORY := 30
const MAX_TOOLS_PER_TURN := 12

## Tool names that only exist in-world. Standalone chat bots must not expose these.
const WORLD_TOOLS := ["place_voxel", "carve_area", "spawn_structure", "follow", "move_to", "build_realm"]

var _agents := {}   # id -> CompanionAgent
var _memory := {}   # id -> Dictionary (memory_export.json schema)
## Brain cells (scripts/brain): data-only rules + memory + approval-gated self-update per companion.
var brains := {}    # id -> BrainCore
## Coordination bus: group tasks go to the lead (Foxy Ani) who delegates to members.
var bus := BrainBus.new()

func _ready() -> void:
	reply_ready.connect(func(cid: String, t: String):
		if t != "": EveCore.for_companion(cid, _agents[cid].persona if _agents.has(cid) else {}).log_chat("assistant", t))
	DirAccess.make_dir_recursive_absolute(MEMORY_DIR)
	var t := Timer.new()
	t.wait_time = 10.0
	t.autostart = true
	t.timeout.connect(sync_owner_decisions)
	add_child(t)

# ---------- registration ----------
func register_agent(agent: Node) -> void:
	_agents[agent.companion_id] = agent
	_memory[agent.companion_id] = load_memory(agent.companion_id)
	var persona: Variant = agent.get("persona")
	if persona is Dictionary and not persona.is_empty():
		brains[agent.companion_id] = BrainCore.new(agent.companion_id, persona)
		bus.register(agent.companion_id, _on_bus_message.bind(agent.companion_id), persona.get("abilities", []))

func unregister_agent(agent: Node) -> void:
	_agents.erase(agent.companion_id)
	bus.unregister(agent.companion_id)

# ---------- memory ----------
func _mem_path(id: String) -> String:
	return "%s/%s.json" % [MEMORY_DIR, id]

func load_memory(id: String) -> Dictionary:
	var empty := {"schema_version": 1, "companion_id": id, "facts": [], "history": [], "relationship": {"affinity": 0}, "built_structures": [], "updated_at": ""}
	if not FileAccess.file_exists(_mem_path(id)):
		return empty
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_mem_path(id)))
	return parsed if parsed is Dictionary else empty

func save_memory(id: String) -> void:
	var m: Dictionary = _memory.get(id, {})
	m["updated_at"] = Time.get_datetime_string_from_system(true)
	var f := FileAccess.open(_mem_path(id), FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "\t"))

func remember_fact(id: String, fact: String) -> void:
	var facts: Array = _memory[id]["facts"]
	if fact not in facts:
		facts.append(fact)
	save_memory(id)

## Export to the portable sync format (companions/<id>/memory_export.json schema).
func export_memory(id: String, path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var out: Dictionary = _memory.get(id, load_memory(id)).duplicate(true)
	out["source"] = "godot"
	f.store_string(JSON.stringify(out, "\t"))
	return OK

## Import: merges facts (dedup) and appends history; never deletes local data.
func import_memory(id: String, path: String) -> Error:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or parsed.get("companion_id", "") != id:
		return ERR_INVALID_DATA
	var m: Dictionary = _memory.get(id, load_memory(id))
	for fact in parsed.get("facts", []):
		if fact not in m["facts"]:
			m["facts"].append(fact)
	m["history"].append_array(parsed.get("history", []))
	m["history"] = m["history"].slice(-MAX_HISTORY)
	_memory[id] = m
	save_memory(id)
	return OK

# ---------- chat ----------
func chat(id: String, player_text: String) -> void:
	var agent: Node = _agents.get(id)
	if agent == null:
		request_failed.emit(id, "unknown companion")
		return
	EveCore.for_companion(id, agent.persona).log_chat("user", player_text)
	if not Settings.live_ai():
		_offline_reply(id, player_text)
		return
	var persona: Dictionary = agent.persona
	var mem: Dictionary = _memory[id]
	var messages := [{"role": "system", "content": _system_prompt(persona, mem, agent)}]
	for h in mem["history"].slice(-MAX_HISTORY):
		messages.append(h)
	messages.append({"role": "user", "content": player_text})
	mem["history"].append({"role": "user", "content": player_text})

	var body := {
		"model": Settings.get_value("llm", "model"),
		"messages": messages,
		"tools": _tool_specs(BrainCore.flatten_tools(persona.get("tools", []))),
		"temperature": persona.get("temperature", 0.8),
	}
	var http := HTTPRequest.new()
	http.timeout = float(Settings.get_value("llm", "timeout_sec", 45.0))
	add_child(http)
	http.request_completed.connect(_on_chat_done.bind(id, http))
	var headers := ["Content-Type: application/json", "Authorization: Bearer %s" % Settings.api_key()]
	var err := http.request(str(Settings.get_value("llm", "endpoint")), headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		request_failed.emit(id, "HTTP request error %d" % err)

func _system_prompt(persona: Dictionary, mem: Dictionary, agent: Node) -> String:
	return "%s\n\nStyle: %s\nYou are an in-game AI companion inside a voxel world. Your position: %s. Player position: %s.\nKnown facts about the player and world: %s\nUse tools to act in the world; keep spoken replies short." % [
		persona.get("system_prompt", ""), persona.get("voice_style", ""),
		str(agent.global_position.round()), str(agent.get_player_position().round()),
		"; ".join(PackedStringArray(mem.get("facts", [])))]

func _on_chat_done(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray, id: String, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		Settings.last_chat_error = "LLM error result=%d code=%d" % [result, code]
		request_failed.emit(id, Settings.last_chat_error)
		_offline_reply(id)
		return
	Settings.last_chat_error = ""
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not (data is Dictionary) or data.get("choices", []).is_empty():
		request_failed.emit(id, "bad LLM response")
		return
	var msg: Dictionary = data["choices"][0]["message"]
	var text: String = str(msg.get("content", "")) if msg.get("content") != null else ""
	var calls: Array = msg.get("tool_calls", []) if msg.get("tool_calls") != null else []
	for i in mini(calls.size(), MAX_TOOLS_PER_TURN):
		var fn: Dictionary = calls[i].get("function", {})
		var args: Variant = JSON.parse_string(str(fn.get("arguments", "{}")))
		dispatch_tool(id, str(fn.get("name", "")), args if args is Dictionary else {})
	if text != "":
		_memory[id]["history"].append({"role": "assistant", "content": text})
	_memory[id]["history"] = _memory[id]["history"].slice(-MAX_HISTORY)
	save_memory(id)
	reply_ready.emit(id, text)

# ---------- tools ----------
func dispatch_tool(id: String, tool: String, args: Dictionary) -> Dictionary:
	var agent: Node = _agents.get(id)
	var res := {"ok": false}
	if agent == null or tool not in BrainCore.flatten_tools(agent.persona.get("tools", [])):
		res["error"] = "tool not allowed for this companion"
	elif tool == "remember":
		remember_fact(id, str(args.get("fact", "")))
		res = {"ok": true}
	elif agent.has_method("tool_" + tool):
		res = agent.call("tool_" + tool, args)
		if brains.has(id):
			brains[id].memory.log_episode("tool", {"name": tool, "ok": bool(res.get("ok")), "args": args})
		if res.get("ok") and tool in ["spawn_structure", "carve_area", "place_voxel"]:
			_memory[id]["built_structures"].append({"tool": tool, "args": args})
			_memory[id]["built_structures"] = _memory[id]["built_structures"].slice(-200)
			EveCore.for_companion(id, agent.persona).log_build(tool, args)
	else:
		res["error"] = "unknown tool"
	tool_executed.emit(id, tool, res)
	return res

const TOOL_SCHEMAS := {
	"place_voxel": {"description": "Place one voxel at absolute world coords.", "properties": {"x": {"type": "integer"}, "y": {"type": "integer"}, "z": {"type": "integer"}, "material": {"type": "integer", "description": "voxel type id 0-15, 0 = air"}}, "required": ["x", "y", "z", "material"]},
	"carve_area": {"description": "Remove voxels in a sphere.", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}, "radius": {"type": "number", "maximum": 8}}, "required": ["x", "y", "z", "radius"]},
	"spawn_structure": {"description": "Build a named structure near a point.", "properties": {"name": {"type": "string", "enum": ["tower", "hut", "arch", "pillar", "wall", "fire_altar"]}, "x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}, "material": {"type": "integer"}}, "required": ["name", "x", "y", "z"]},
	"follow": {"description": "Start or stop following the player.", "properties": {"enabled": {"type": "boolean"}}, "required": ["enabled"]},
	"move_to": {"description": "Walk to world coords.", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}}, "required": ["x", "z"]},
	"build_realm": {"description": "Ask RealmBuilder to regenerate the realm from a prompt.", "properties": {"prompt": {"type": "string"}}, "required": ["prompt"]},
	"remember": {"description": "Store a long-term fact about the player or world.", "properties": {"fact": {"type": "string"}}, "required": ["fact"]},
	"emote": {"description": "Play an animation.", "properties": {"name": {"type": "string", "enum": ["dance", "wave", "fire_cast", "idle"]}}, "required": ["name"]},
}

func _tool_specs(names: Array) -> Array:
	var out := []
	for n in names:
		if TOOL_SCHEMAS.has(n):
			var s: Dictionary = TOOL_SCHEMAS[n]
			out.append({"type": "function", "function": {"name": n, "description": s["description"], "parameters": {"type": "object", "properties": s["properties"], "required": s["required"]}}})
	return out


## v0.9: canned persona reply used whenever live chat is offline (no key, mode, or error).
func _offline_reply(id: String, player_text := "") -> void:
	var agent: Node = _agents.get(id)
	if agent == null: return
	if player_text == "":
		var h: Array = _memory[id]["history"]
		player_text = str(h.back().get("content", "")) if not h.is_empty() else ""
	var r := _brain_reply(id, player_text)
	if r == "":
		r = CannedReplies.reply(agent.persona, player_text, agent.life.recap() if "life" in agent and agent.life else "")
	if not (_memory[id]["history"].size() > 0 and _memory[id]["history"].back().get("content") == player_text):
		_memory[id]["history"].append({"role": "user", "content": player_text})
	_memory[id]["history"].append({"role": "assistant", "content": r})
	reply_ready.emit(id, r)


# ---------- brain cells + coordination (v0.10) ----------
func get_brain(id: String) -> BrainCore:
	return brains.get(id)

## Player/UI: ask the whole group to do something. Routed through the lead companion.
func group_task(command: String, text := "") -> Array:
	return bus.post_group_task({"command": command, "text": text, "from": "player"})

## Bus handler: a delegated command becomes a normal permission-checked tool call.
func _on_bus_message(msg: Dictionary, id: String) -> Dictionary:
	var agent: Node = _agents.get(id)
	if agent == null: return {"ok": false, "error": "agent gone"}
	var p: Vector3 = agent.global_position - agent.global_basis.z * 3.0
	var r: Dictionary
	match str(msg.get("command", "")):
		"follow": r = dispatch_tool(id, "follow", {"enabled": true})
		"stay": r = dispatch_tool(id, "follow", {"enabled": false})
		"build": r = dispatch_tool(id, "spawn_structure", {"name": "pillar", "x": p.x, "y": p.y, "z": p.z})
		"dig": r = dispatch_tool(id, "carve_area", {"x": p.x, "y": p.y - 1.0, "z": p.z, "radius": 2.0})
		"dance": r = dispatch_tool(id, "emote", {"name": "dance"})
		_: r = {"ok": true, "note": "acknowledged"}
	if brains.has(id):
		brains[id].memory.log_episode("delegated", {"from": str(msg.get("from", "")), "command": str(msg.get("command", "")), "ok": bool(r.get("ok"))})
	return r

## Offline: let a matching brain cell answer before canned replies. Returns "" if no cell fired.
func _brain_reply(id: String, player_text: String) -> String:
	var brain: BrainCore = brains.get(id)
	if brain == null or player_text == "": return ""
	brain.memory.log_episode("chat", {"text": player_text})
	var hit := brain.best({"type": "chat", "text": player_text},
		{"affinity": int(_memory[id].get("relationship", {}).get("affinity", 0)), "player": str(Settings.get_value("profile", "name", "friend"))})
	if hit.is_empty(): return ""
	var a: Dictionary = hit["action"]
	match a.get("type"):
		"say": return str(a.get("text", ""))
		"emote": dispatch_tool(id, "emote", {"name": a.get("name", "dance")}); return "*%s*" % a.get("name", "")
		"remember": remember_fact(id, str(a.get("fact", ""))); return ""
		"tool": dispatch_tool(id, str(a.get("name", "")), a.get("args", {})); return ""
		"delegate": group_task(str(a.get("command", "")), player_text); return ""
	return ""

## Mirror owner decisions from EveCore (MENU > Proposals) into the brains; approved cells go live.
func sync_owner_decisions() -> int:
	var n := BrainCore.sync_owner_decisions(EveCore.proposals())
	if n > 0:
		for b in brains.values(): b.reload()
	return n
