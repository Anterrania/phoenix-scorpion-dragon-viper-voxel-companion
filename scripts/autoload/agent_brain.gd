extends Node
## AgentBrain: shared LLM client, per-companion memory, and tool dispatch.
## Each CompanionAgent registers itself; AgentBrain builds the prompt from the
## companion's persona.json + memory, calls the configured endpoint, and executes
## returned tool calls against the world (VoxelTerrain) through the agent.

signal reply_ready(companion_id: String, text: String)
signal tool_executed(companion_id: String, tool: String, result: Dictionary)
signal request_failed(companion_id: String, error: String)
## CHAT-6: true while a live request for this companion is in flight (UI shows "thinking…").
signal thinking(companion_id: String, active: bool)
## LAI-4: on-device replies stream; text so far (tool-call markup hidden). reply_ready still ends every turn.
signal reply_partial(companion_id: String, text: String)

const MEMORY_DIR := "user://memory"
const MAX_HISTORY := 30
const MAX_TOOLS_PER_TURN := 12

## Tool names that only exist in-world. Standalone chat bots must not expose these.
# const WORLD_TOOLS := ["place_voxel", "carve_area", "spawn_structure", "follow", "move_to", "build_realm"]
const WORLD_TOOLS := ["place_voxel", "carve_area", "spawn_structure", "follow", "move_to", "build_realm", "heaven_edit"]
## HEAVEN-9: Heaven layout edits from chat (HeavenEdits.tool_call). Every companion that can build
## (spawn_structure) gets it. Edits always go through the owner's approval (EveCore proposal) unless the
## companion holds the owner's standing "build" grant (HeavenAccess). Chat never self-approves.
const HEAVEN_TOOL := "heaven_edit"
## CHAT-16: after tools run, the results go back to the model for one follow-up reply (Settings llm/tool_followup).
const FOLLOWUP_MAX_TOKENS := 96

var _agents := {}   # id -> CompanionAgent
var _memory := {}   # id -> Dictionary (memory_export.json schema)
## Brain cells (scripts/brain): data-only rules + memory + approval-gated self-update per companion.
var brains := {}    # id -> BrainCore
## Coordination bus: group tasks go to the lead (Foxy Ani) who delegates to members.
var bus := BrainBus.new()

func _ready() -> void:
	Profile.changed.connect(func(): CompanionTiers.seed_once(Profile.is_owner()))  # v0.12: first owner unlock -> companions Builder
	reply_ready.connect(func(cid: String, t: String):
		if t != "": EveCore.for_companion(cid, _agents[cid].persona if _agents.has(cid) else {}).log_chat("assistant", t))
	DirAccess.make_dir_recursive_absolute(MEMORY_DIR)
	var lt := Timer.new(); lt.name = "LearnTimer"; lt.wait_time = LEARN_INTERVAL_SEC; lt.autostart = true; add_child(lt)
	lt.timeout.connect(learn_all)
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

## Tool names this companion may use: persona tools, plus heaven_edit for builders (HEAVEN-9).
func tools_of(agent: Node) -> Array:
	var t := BrainCore.flatten_tools(agent.persona.get("tools", []) if agent.get("persona") is Dictionary else [])
	if "spawn_structure" in t and not HEAVEN_TOOL in t: t.append(HEAVEN_TOOL)
	return t

# ---------- memory ----------
func _mem_path(id: String) -> String:
	return "%s/%s.json" % [MEMORY_DIR, id]

func load_memory(id: String) -> Dictionary:
	var empty := {"schema_version": 1, "companion_id": id, "facts": [], "history": [], "relationship": {"affinity": 0}, "built_structures": [], "updated_at": ""}
	if not SecureFile.exists(_mem_path(id)):
		return empty
	var parsed: Variant = SecureFile.read_json(_mem_path(id))
	return parsed if parsed is Dictionary else empty

## Re-read chat memory from disk (encrypted saves just became readable after the owner unlock).
func reload_brains() -> void:
	for id in _memory.keys(): _memory[id] = load_memory(id)

func save_memory(id: String) -> void:
	var m: Dictionary = _memory.get(id, {})
	m["updated_at"] = Time.get_datetime_string_from_system(true)
	SecureFile.write_text(_mem_path(id), JSON.stringify(m, "\t"))

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
## CHAT-7: test seam. When valid, called as transport.call(url, headers, body_json) instead of HTTPRequest and
## must return {"result": int, "code": int, "body": String}. Tests use a mock provider; production leaves it empty.
var transport: Callable = Callable()
var _pending := {}   # id -> true while a live request is in flight
var _queued := {}    # id -> Array of player texts typed while waiting (sent in order)

func is_thinking(id: String) -> bool:
	return _pending.has(id)

## Contract (CHAT-1): every chat() call ends in exactly one reply_ready(id, text) with non-empty text
## (live answer, tool summary, or offline persona reply). request_failed is extra info, never the only signal.
func chat(id: String, player_text: String) -> void:
	var agent: Node = _agents.get(id)
	if agent == null:
		request_failed.emit(id, "unknown companion")
		return
	player_text = player_text.strip_edges()
	if player_text == "": return
	if _pending.has(id):
		if not _queued.has(id): _queued[id] = []
		_queued[id].append(player_text)
		return
	EveCore.for_companion(id, agent.persona).log_chat("user", player_text)
	_learn_signals(id, player_text)
	if Settings.live_ai() and brains.has(id): brains[id].memory.log_episode("chat", {"text": player_text})
	# if not Settings.live_ai():
	# 	_offline_reply(id, player_text)
	# 	return
	# LAI-4: live (optional key) -> on-device model (default, no key) -> canned persona replies (last fallback).
	if not Settings.live_ai():
		if Settings.local_ai(): _local_chat(id, player_text)
		else: _offline_reply(id, player_text)
		return
	var persona: Dictionary = agent.persona
	var mem: Dictionary = _memory[id]
	var messages := [{"role": "system", "content": _system_prompt(persona, mem, agent)}]
	for h in mem["history"].slice(-MAX_HISTORY):
		if h is Dictionary and str(h.get("role", "")) in ["user", "assistant"] and str(h.get("content", "")) != "":
			messages.append({"role": h["role"], "content": str(h["content"])})
	messages.append({"role": "user", "content": player_text})
	mem["history"].append({"role": "user", "content": player_text})

	var body := {
		"model": Settings.get_value("llm", "model"),
		"messages": messages,
		"temperature": persona.get("temperature", 0.8),
	}
	# var specs := _tool_specs(BrainCore.flatten_tools(persona.get("tools", [])))
	var specs := _tool_specs(tools_of(agent))   # HEAVEN-9: + heaven_edit for builders
	if not specs.is_empty(): body["tools"] = specs   # CHAT-8: some endpoints 400 on an empty tools array
	_pending[id] = true
	thinking.emit(id, true)
	_live_body[id] = body   # CHAT-16: kept for the follow-up turn after tool calls
	# Old inline transport/HTTPRequest code moved into _send_live() so the CHAT-16 follow-up reuses it.
	var err := _send_live(body, func(r: int, c: int, b: String): _handle_chat_response(id, r, c, b))
	if err != OK:
		# CHAT-1: was request_failed only -> the chat sat silent forever.
		_live_failed(id, "couldn't start the request (error %d). Check the endpoint in Settings." % err)

var _live_body := {}   # id -> last live request body (CHAT-16)

## One live request (test transport or HTTPRequest). on_done(result, code, body) is always called later,
## unless the request couldn't start (returns the error; on_done is then never called).
func _send_live(body: Dictionary, on_done: Callable) -> Error:
	var url := Settings.llm_endpoint()
	var headers := ["Content-Type: application/json", "Authorization: Bearer %s" % Settings.api_key()]
	if transport.is_valid():
		var r: Variant = transport.call(url, headers, JSON.stringify(body))
		var rd: Dictionary = r if r is Dictionary else {}
		on_done.call_deferred(int(rd.get("result", HTTPRequest.RESULT_NO_RESPONSE)), int(rd.get("code", 0)), str(rd.get("body", "")))
		return OK
	var http := HTTPRequest.new()
	http.timeout = float(Settings.get_value("llm", "timeout_sec", 45.0))
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray):
		http.queue_free(); on_done.call(result, code, raw.get_string_from_utf8()))
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK: http.queue_free()
	return err

func _system_prompt(persona: Dictionary, mem: Dictionary, agent: Node) -> String:
	var at: Variant = agent.get("global_position")
	var pp: Variant = agent.call("get_player_position") if agent.has_method("get_player_position") else Vector3.ZERO
	return "%s\n\nStyle: %s\nYou are an in-game AI companion inside a voxel world. Your position: %s. Player position: %s.\nKnown facts about the player and world: %s\nUse tools to act in the world; keep spoken replies short.%s" % [
		persona.get("system_prompt", ""), persona.get("voice_style", ""),
		str((at if at is Vector3 else Vector3.ZERO).round()), str((pp if pp is Vector3 else Vector3.ZERO).round()),
		"; ".join(PackedStringArray(mem.get("facts", []))), (" " + _heaven_hint(agent)) if _heaven_hint(agent) != "" else ""]

## HEAVEN-9: one line telling the model it is in Heaven and how to change it ("" elsewhere).
func _heaven_hint(agent: Node) -> String:
	if not (HEAVEN_TOOL in tools_of(agent)): return ""
	var at: Variant = agent.get("global_position")
	if not (at is Vector3) or not HeavenLayout.contains(at): return ""
	var isl := HeavenLayout.district_at(at)
	return "You are in Heaven (%s). To change Heaven use heaven_edit; the owner approves each change unless you hold a build grant, so say whether it is done or waiting." % str(isl.get("name", "Heaven"))

## CHAT-16: replaced by the lambda in _send_live() (same behaviour, shared with the follow-up turn).
# func _on_chat_done(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray, id: String, http: HTTPRequest) -> void:
# 	http.queue_free()
# 	_handle_chat_response(id, result, code, raw.get_string_from_utf8())

## Old handler kept for reference (CHAT-1/5): bad responses emitted request_failed with no reply, and a
## non-Dictionary choices[0] crashed the parse.
# func _on_chat_done(result, code, _h, raw, id, http):
# 	http.queue_free()
# 	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
# 		Settings.last_chat_error = "LLM error result=%d code=%d" % [result, code]
# 		request_failed.emit(id, Settings.last_chat_error); _offline_reply(id); return
# 	Settings.last_chat_error = ""
# 	var data = JSON.parse_string(raw.get_string_from_utf8())
# 	if not (data is Dictionary) or data.get("choices", []).is_empty():
# 		request_failed.emit(id, "bad LLM response"); return
# 	... dispatch tool_calls, append history, save_memory, reply_ready.emit(id, text)

func _handle_chat_response(id: String, result: int, code: int, body: String) -> void:
	if not _agents.has(id):
		_pending.erase(id); _queued.erase(id); thinking.emit(id, false)
		return
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400 or code < 200:
		var why := Settings.chat_error_text(result, code, body)
		_live_failed(id, why if why != "" else "unexpected reply (HTTP %d)." % code)
		return
	var data: Variant = JSON.parse_string(body)
	var msg: Variant = null
	if data is Dictionary and data.get("choices") is Array and not data["choices"].is_empty() and data["choices"][0] is Dictionary:
		msg = data["choices"][0].get("message")
	if not (msg is Dictionary):
		_live_failed(id, "the AI service sent a reply the app couldn't read.")
		return
	Settings.last_chat_error = ""
	var text: String = str(msg.get("content", "")).strip_edges() if msg.get("content") is String else ""
	var calls: Array = msg.get("tool_calls") if msg.get("tool_calls") is Array else []
	var done := []
	var results := []   # CHAT-16: [{call_id, name, args_json, res}]
	for i in mini(calls.size(), MAX_TOOLS_PER_TURN):
		if not (calls[i] is Dictionary): continue
		var fn: Variant = calls[i].get("function", {})
		if not (fn is Dictionary): continue
		var a: Variant = fn.get("arguments", "{}")
		var args: Variant = a if a is Dictionary else JSON.parse_string(str(a))
		var tname := str(fn.get("name", ""))
		var res := dispatch_tool(id, tname, args if args is Dictionary else {})
		done.append(("*%s*" % tname.replace("_", " ")) if res.get("ok") else ("(couldn't %s: %s)" % [tname.replace("_", " "), str(res.get("error", "?"))]))
		var cid := str(calls[i].get("id", ""))
		results.append({"call_id": cid if cid != "" else "call_%d" % i, "name": tname,
			"args_json": a if a is String else JSON.stringify(args if args is Dictionary else {}), "res": res})
	if text == "" and not done.is_empty(): text = " ".join(PackedStringArray(done))   # CHAT-9: tool-only turns used to show an empty line
	if text == "":
		_live_failed(id, "the AI answered with an empty message.")
		return
	# CHAT-16: tools ran -> one follow-up request with the results so the companion answers about what happened.
	var fallback := _with_tool_notes(text, results)   # canned follow-up if the model can't answer
	if not results.is_empty() and followup_enabled() and _live_body.has(id):
		_live_followup(id, msg, results, fallback)
		return
	_live_save_finish(id, fallback)

func _live_save_finish(id: String, text: String) -> void:
	_memory[id]["history"].append({"role": "assistant", "content": text})
	_memory[id]["history"] = _memory[id]["history"].slice(-MAX_HISTORY)
	save_memory(id)
	_finish(id, text)

# ---------- CHAT-16: tool results back to the model ----------
func followup_enabled() -> bool: return bool(Settings.get_value("llm", "tool_followup", true))

## What the model sees for one tool result: ok / error / state / say, no internals, small.
static func result_for_model(name: String, res: Dictionary) -> Dictionary:
	var out := {"tool": name, "ok": bool(res.get("ok", false))}
	for k in ["error", "state", "say", "note"]:
		if res.has(k): out[k] = str(res[k]).left(240)
	return out

## Canned follow-up: the model's own line plus any result line it didn't already say (heaven_edit "say").
static func _with_tool_notes(text: String, results: Array) -> String:
	var out := text
	for r in results:
		var say := str(r["res"].get("say", ""))
		if say != "" and not out.contains(say): out = (out + " " + say).strip_edges()
	return out

## Live path: assistant message with its tool_calls + one "tool" message per result, tool_choice none.
func _live_followup(id: String, msg: Dictionary, results: Array, fallback: String) -> void:
	var body: Dictionary = _live_body[id].duplicate(true)
	var tcs := []
	for r in results:
		tcs.append({"id": r["call_id"], "type": "function", "function": {"name": r["name"], "arguments": r["args_json"]}})
	body["messages"].append({"role": "assistant", "content": msg.get("content") if msg.get("content") is String else null, "tool_calls": tcs})
	for r in results:
		body["messages"].append({"role": "tool", "tool_call_id": r["call_id"], "content": JSON.stringify(result_for_model(r["name"], r["res"]))})
	body["tool_choice"] = "none"   # answer in words; tools already ran this turn
	body["max_tokens"] = 200
	var err := _send_live(body, func(rr: int, c: int, b: String): _on_live_followup(id, rr, c, b, fallback))
	if err != OK: _live_save_finish(id, fallback)

## Follow-up answer. Any problem (network, empty, more tool calls) -> the canned fallback. Never request_failed:
## the turn itself worked and the tools already ran.
func _on_live_followup(id: String, result: int, code: int, body: String, fallback: String) -> void:
	if not _agents.has(id):
		_pending.erase(id); _queued.erase(id); thinking.emit(id, false)
		return
	var text := ""
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 400:
		var data: Variant = JSON.parse_string(body)
		if data is Dictionary and data.get("choices") is Array and not data["choices"].is_empty() and data["choices"][0] is Dictionary:
			var m: Variant = data["choices"][0].get("message")
			if m is Dictionary and m.get("content") is String: text = str(m["content"]).strip_edges()
	_live_save_finish(id, text if text != "" else fallback)

## Live call failed: record why, tell the UI, then answer offline so the player always gets a reply.
func _live_failed(id: String, why: String) -> void:
	Settings.last_chat_error = why
	request_failed.emit(id, why)
	# LAI-4: a failed live call tries the on-device model before canned replies.
	if Settings.effective_mode() != "canned" and Settings.local_llm() and Settings.local_llm().can_chat() and _agents.has(id):
		var h: Array = _memory[id]["history"]
		_local_chat(id, str(h.back().get("content", "")) if not h.is_empty() else "", true)
		return
	_pending.erase(id)
	thinking.emit(id, false)
	_offline_reply(id)

func _finish(id: String, text: String) -> void:
	_pending.erase(id)
	thinking.emit(id, false)
	reply_ready.emit(id, text)
	var q: Array = _queued.get(id, [])
	if not q.is_empty():
		var nxt: String = q.pop_front()
		if q.is_empty(): _queued.erase(id)
		chat(id, nxt)

## Live probe for Settings › "Test AI connection". cb.call(ok: bool, message: String).
func test_connection(cb: Callable) -> void:
	if not Settings.has_api_key(): cb.call(false, Settings.chat_status_text(Settings.chat_status())); return
	var url := Settings.llm_endpoint()
	if url == "": cb.call(false, Settings.chat_status_text("offline_endpoint")); return
	var headers := ["Content-Type: application/json", "Authorization: Bearer %s" % Settings.api_key()]
	var body := JSON.stringify({"model": Settings.get_value("llm", "model"), "messages": [{"role": "user", "content": "ping"}], "max_tokens": 4})
	var report := func(result: int, code: int, b: String) -> void:
		var why := Settings.chat_error_text(result, code, b)
		Settings.last_chat_error = why
		cb.call(why == "", "Live AI connected." if why == "" else "Live AI not working: " + why)
	if transport.is_valid():
		var r: Variant = transport.call(url, headers, body)
		var rd: Dictionary = r if r is Dictionary else {}
		report.call_deferred(int(rd.get("result", HTTPRequest.RESULT_NO_RESPONSE)), int(rd.get("code", 0)), str(rd.get("body", "")))
		return
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray):
		http.queue_free(); report.call(result, code, raw.get_string_from_utf8()))
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free(); report.call(HTTPRequest.RESULT_CANT_CONNECT, 0, "")

# ---------- tools ----------
func dispatch_tool(id: String, tool: String, args: Dictionary) -> Dictionary:
	var agent: Node = _agents.get(id)
	var res := {"ok": false}
	if AutonomyGuard.paused():
		res["error"] = "e-stop engaged: tools paused"
	# elif agent == null or tool not in BrainCore.flatten_tools(agent.persona.get("tools", [])):
	elif agent == null or tool not in tools_of(agent):
		res["error"] = "tool not allowed for this companion"
	elif _land_error(id, tool, args, agent) != "":
		res["error"] = _land_error(id, tool, args, agent)   # audit 2026-10-17: Tiers.can(id, build|land, parcel)
	elif tool == "remember":
		remember_fact(id, str(args.get("fact", "")))
		res = {"ok": true}
	elif tool == HEAVEN_TOOL:
		res = _heaven_edit(id, args)
		if brains.has(id):
			brains[id].memory.log_episode("tool", {"name": tool, "ok": bool(res.get("ok")), "args": args})
		if res.get("ok") and str(res.get("state", "")) == "applied":
			EveCore.for_companion(id, agent.persona).log_build(tool, args)
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

## HEAVEN-9: heaven_edit from chat. directed = false ALWAYS: a companion acting from chat goes through the
## owner's approval (EveCore.propose_update; owner decides in MENU > Proposals or Heaven > Direct a change)
## unless it holds the owner's standing build grant. op "undo" takes back the companion's own change
## (HeavenEdits.companion_undo). Result: {ok, state, edit_id, proposal?, say} or {ok: false, error, say}.
func _heaven_edit(id: String, args: Dictionary) -> Dictionary:
	var r: Dictionary
	if str(args.get("op", "add")) == HeavenEdits.UNDO_OP:
		r = HeavenEdits.companion_undo(id, str(args.get("target", "")))
	else:
		r = HeavenEdits.tool_call(id, args, int(Time.get_unix_time_from_system()), false)
	var out := {"ok": not r.has("error"), "say": HeavenEdits.status_line(r)}
	if r.has("error"):
		out["error"] = str(r["error"])
		return out
	out["state"] = str(r.get("state", ""))
	out["edit_id"] = str(r.get("id", ""))
	if r.has("proposal"): out["proposal"] = str(r["proposal"])
	if out["state"] == "pending": out["note"] = "waiting for the owner's approval"
	return out

## World-changing tools need Tiers.can(companion, "build"|"land", parcel) (LandGate.TOOL_ACTIONS).
func _land_error(id: String, tool: String, args: Dictionary, agent: Node) -> String:
	var at: Variant = agent.get("global_position")
	return LandGate.companion_tool_error(id, tool, args, at if at is Vector3 else Vector3.ZERO)

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

## HEAVEN-9: heaven_edit schema (built at runtime: the piece types come from HeavenBuilder.EDITABLE).
static func heaven_schema() -> Dictionary:
	var num := {"type": "number"}
	return {"description": "Change Heaven Welcome Island while you are in Heaven: add a piece, change one (move, resize, recolor, rename), remove one, or undo your own last change. Each change goes to the owner for approval unless you hold a build grant.",
		"properties": {"op": {"type": "string", "enum": HeavenEdits.OPS + [HeavenEdits.UNDO_OP]},
			"type": {"type": "string", "enum": HeavenBuilder.EDITABLE, "description": "piece type for add"},
			"x": num, "y": num, "z": num, "target": {"type": "string", "description": "piece id for set/remove; for undo an edit id or 'last'"},
			"yaw": num, "w": num, "d": num, "h": num, "r": num,
			"color": {"type": "string", "description": "#rrggbb"}, "trim": {"type": "string", "description": "#rrggbb"},
			"text": {"type": "string", "description": "sign text"}, "name": {"type": "string"}, "shop": {"type": "string"},
			"move": {"type": "boolean", "description": "set: move the piece to x/z"}, "note": {"type": "string", "description": "why"}},
		"required": ["op"]}

func _tool_specs(names: Array) -> Array:
	var out := []
	for n in names:
		# if TOOL_SCHEMAS.has(n):
		# 	var s: Dictionary = TOOL_SCHEMAS[n]
		if TOOL_SCHEMAS.has(n) or n == HEAVEN_TOOL:
			var s: Dictionary = TOOL_SCHEMAS[n] if TOOL_SCHEMAS.has(n) else heaven_schema()
			out.append({"type": "function", "function": {"name": n, "description": s["description"], "parameters": {"type": "object", "properties": s["properties"], "required": s["required"]}}})
	return out


## v0.9: canned persona reply used whenever live chat is offline (no key, mode, or error).
## LAI-4: skip_brain = the brain cell already ran this turn (on-device path), so its action isn't repeated.
func _offline_reply(id: String, player_text := "", skip_brain := false) -> void:
	var agent: Node = _agents.get(id)
	if agent == null: return
	if player_text == "":
		var h: Array = _memory[id]["history"]
		player_text = str(h.back().get("content", "")) if not h.is_empty() else ""
	var r := "" if skip_brain else _brain_reply(id, player_text)
	if r == "":
		r = CannedReplies.reply(agent.persona, player_text, agent.life.recap() if "life" in agent and agent.life else "")
	if not (_memory[id]["history"].size() > 0 and _memory[id]["history"].back().get("content") == player_text):
		_memory[id]["history"].append({"role": "user", "content": player_text})
	if r == "": r = "…"   # CHAT-1: never emit an empty reply
	_memory[id]["history"].append({"role": "assistant", "content": r})
	_memory[id]["history"] = _memory[id]["history"].slice(-MAX_HISTORY)
	save_memory(id)   # CHAT-10: offline turns were never saved
	_finish(id, r)


# ---------- LAI-4: on-device chat (LocalLLM) ----------
const LOCAL_MAX_TOOLS := 3
const LOCAL_RETRY_BUDGET := 0.55   # context_full: retry with this share of the prompt budget (fewer old turns)

## On-device turn: brain cell first (exact commands stay instant), then the local model with persona, memory facts,
## recent history and the companion's tools. Tool calls go through dispatch_tool (permissions + Tiers.can/LandGate).
## Ends in exactly one reply_ready, like every other path. logged: the player's line is already in history.
func _local_chat(id: String, player_text: String, logged := false) -> void:
	var agent: Node = _agents.get(id)
	if agent == null: return
	var persona: Dictionary = agent.persona
	var mem: Dictionary = _memory[id]
	_pending[id] = true
	thinking.emit(id, true)
	var act := _brain_act(id, player_text)
	if not logged: mem["history"].append({"role": "user", "content": player_text})
	var allowed := _local_tools(agent)
	var specs := LlmPrompt.local_tool_specs(_tool_specs(allowed))
	var sys := LlmPrompt.system_block(persona, mem.get("facts", []), specs, str(Settings.get_value("profile", "name", "")))
	var hist: Array = mem["history"].slice(-MAX_HISTORY, -1)
	_local_run(id, sys, hist, player_text, _local_context(agent, act), allowed, act, Settings.local_llm().prompt_budget(), 0)

func _local_run(id: String, sys: String, hist: Array, text: String, ctx: String, allowed: Array, act: Dictionary, budget: int, attempt: int) -> void:
	var llm: Node = Settings.local_llm()
	var agent: Node = _agents.get(id)
	var b := LlmPrompt.build(sys, hist, text, ctx, budget)
	var opts := {"temperature": float(agent.persona.get("temperature", 0.7)) if agent else 0.7, "top_p": 0.9}
	llm.generate(b["prompt"], opts,
		func(partial: String): reply_partial.emit(id, LlmPrompt.visible(partial)),
		# func(res: Dictionary): _on_local_done(id, res, [sys, hist, text, ctx, allowed, act, budget, attempt]))
		func(res: Dictionary): _on_local_done(id, res, [sys, hist, text, ctx, allowed, act, budget, attempt, b["prompt"]]))   # CHAT-16: + prompt

func _on_local_done(id: String, res: Dictionary, run: Array) -> void:
	if not _agents.has(id):
		_pending.erase(id); _queued.erase(id); thinking.emit(id, false)
		return
	var err := str(res.get("error", ""))
	if err == "context_full" and int(run[7]) < 2:
		_local_run(id, run[0], run[1], run[2], run[3], run[4], run[5], int(int(run[6]) * LOCAL_RETRY_BUDGET), int(run[7]) + 1)
		return
	var act: Dictionary = run[5]
	var parsed := LlmPrompt.parse(str(res.get("text", "")), run[4])
	if err != "" and str(parsed["text"]) == "" and parsed["calls"].is_empty():
		request_failed.emit(id, "on-device AI: " + err)
		_pending.erase(id)
		thinking.emit(id, false)
		var say := str(act.get("say", ""))
		if say != "": _local_save_finish(id, say)
		else: _offline_reply(id, str(run[2]), true)
		return
	var done := []
	var results := []   # CHAT-16
	var n := 0
	for c in parsed["calls"]:
		var tname := str(c["name"])
		if n >= LOCAL_MAX_TOOLS or tname == str(act.get("did", "")) or not LlmPrompt.plausible(tname, str(run[2])): continue
		var args := _local_args(_agents[id], tname, c["args"])
		if tname == "remember" and str(args["fact"]).strip_edges() == "": continue
		n += 1
		var r := dispatch_tool(id, tname, args)
		done.append(("*%s*" % tname.replace("_", " ")) if r.get("ok") else ("(couldn't %s: %s)" % [tname.replace("_", " "), str(r.get("error", "?"))]))
		results.append({"name": tname, "res": r})
	var text := str(parsed["text"])
	if text == "": text = str(act.get("say", ""))
	if text == "" and not done.is_empty(): text = " ".join(PackedStringArray(done))
	if text == "": text = str(act.get("reply", ""))
	if text == "":
		_pending.erase(id); thinking.emit(id, false)
		_offline_reply(id, str(run[2]), true)
		return
	# CHAT-16 (on-device): a second, short generation only when the results need explaining (the model said
	# nothing itself, a tool failed, or a tool has news such as "waiting for approval"). Saves battery otherwise.
	var fallback := _with_tool_notes(text, results)
	if _local_needs_followup(str(parsed["text"]), results) and run.size() > 8 and Settings.local_llm() and Settings.local_llm().can_chat():
		var fr := []
		for r in results: fr.append(result_for_model(r["name"], r["res"]))
		var prompt2 := LlmPrompt.followup(str(run[8]), str(res.get("text", "")), fr)
		Settings.local_llm().generate(prompt2, {"max_tokens": FOLLOWUP_MAX_TOKENS, "temperature": 0.6, "top_p": 0.9},
			func(partial: String): reply_partial.emit(id, LlmPrompt.visible(partial)),
			func(res2: Dictionary): _on_local_followup(id, res2, run[4], fallback))
		return
	_local_save_finish(id, fallback)

static func _local_needs_followup(model_text: String, results: Array) -> bool:
	if results.is_empty() or not bool(Settings.get_value("llm", "tool_followup", true)): return false
	if model_text.strip_edges() == "": return true
	for r in results:
		if not r["res"].get("ok", false) or r["res"].has("say"): return true
	return false

func _on_local_followup(id: String, res: Dictionary, allowed: Array, fallback: String) -> void:
	if not _agents.has(id):
		_pending.erase(id); _queued.erase(id); thinking.emit(id, false)
		return
	var t := ""
	if str(res.get("error", "")) == "": t = str(LlmPrompt.parse(str(res.get("text", "")), allowed)["text"])   # calls ignored: tools already ran
	_local_save_finish(id, t if t != "" else fallback)

func _local_save_finish(id: String, text: String) -> void:
	_memory[id]["history"].append({"role": "assistant", "content": text})
	_memory[id]["history"] = _memory[id]["history"].slice(-MAX_HISTORY)
	save_memory(id)
	_finish(id, text)

## Tools offered to the on-device model: the persona's tools that this companion can actually run.
func _local_tools(agent: Node) -> Array:
	# return BrainCore.flatten_tools(agent.persona.get("tools", [])).filter(func(t): return t == "remember" or agent.has_method("tool_" + str(t)))
	return tools_of(agent).filter(func(t): return t == "remember" or t == HEAVEN_TOOL or agent.has_method("tool_" + str(t)))

## Volatile context for the latest user message (keeps the system block cache-friendly).
func _local_context(agent: Node, act: Dictionary) -> String:
	var parts := PackedStringArray()
	var at: Variant = agent.get("global_position")
	var pp: Variant = agent.call("get_player_position") if agent.has_method("get_player_position") else null
	if at is Vector3: parts.append("You are at %s." % str(at.round()))
	if pp is Vector3: parts.append("Player is at %s." % str(pp.round()))
	if str(act.get("did", "")) != "": parts.append("You just did: %s (don't call it again)." % str(act["did"]).replace("_", " "))
	if str(act.get("say", "")) != "": parts.append("Idea for your reply: " + str(act["say"]).left(160))
	var hh := _heaven_hint(agent)   # HEAVEN-9
	if hh != "": parts.append(hh)
	return " ".join(parts)

## Small models leave out or garble arguments: fill coordinates ("right in front of me") and safe defaults.
func _local_args(agent: Node, tool: String, args: Dictionary) -> Dictionary:
	var a := args.duplicate()
	var front := Vector3.ZERO
	if agent is Node3D: front = agent.global_position - agent.global_basis.z * 3.0
	if tool in ["place_voxel", "carve_area", "spawn_structure", "move_to"]:
		var target := front
		if tool == "move_to" and agent.has_method("get_player_position"):
			var pp: Variant = agent.call("get_player_position")
			if pp is Vector3: target = pp
		for k in ["x", "y", "z"]:
			var v: Variant = a.get(k)
			if not (v is float or v is int): a[k] = target[["x", "y", "z"].find(k)]
	match tool:
		"carve_area": a["radius"] = clampf(float(a.get("radius", 2.0)) if (a.get("radius") is float or a.get("radius") is int) else 2.0, 1.0, 8.0)
		"spawn_structure":
			var names: Array = TOOL_SCHEMAS["spawn_structure"]["properties"]["name"]["enum"]
			if not (str(a.get("name", "")) in names): a["name"] = "fire_altar" if "altar" in str(a.get("name", "")) else "pillar"
		"place_voxel": if not (a.get("material") is float or a.get("material") is int): a["material"] = 1
		"emote":
			if not (str(a.get("name", "")) in TOOL_SCHEMAS["emote"]["properties"]["name"]["enum"]): a["name"] = "wave"
		"follow": a["enabled"] = bool(a.get("enabled", true))
		"remember": a["fact"] = str(a.get("fact", "")).left(200)
		"build_realm": a["prompt"] = str(a.get("prompt", "")).left(200)
		HEAVEN_TOOL:   # HEAVEN-9: small models guess; validation in HeavenEdits still has the last word
			var op := str(a.get("op", "add"))
			a["op"] = op if op in HeavenEdits.OPS + [HeavenEdits.UNDO_OP] else "add"
			if a["op"] in ["add", "set"]:
				for k in ["x", "y", "z"]:
					var v: Variant = a.get(k)
					if not (v is float or v is int): a[k] = front[["x", "y", "z"].find(k)]
			if a["op"] == "add" and not (str(a.get("type", "")) in HeavenBuilder.EDITABLE):
				var w := str(a.get("type", "")).to_lower()
				a["type"] = HeavenDirector.TYPE_WORDS.get(w, HeavenDirector.TYPE_WORDS.get(w.trim_suffix("s"), w))
			if a.has("note"): a["note"] = str(a["note"]).left(200)
	return a


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
	return str(_brain_act(id, player_text).get("reply", ""))

## LAI-4: same as the old _brain_reply, but also says what happened so the on-device model can talk about it:
## {"reply": old return value, "say": cell's line or "", "did": tool/command that ran or ""}.
func _brain_act(id: String, player_text: String) -> Dictionary:
	var brain: BrainCore = brains.get(id)
	if brain == null or player_text == "": return {}
	brain.memory.log_episode("chat", {"text": player_text})
	var hit := brain.best({"type": "chat", "text": player_text},
		{"affinity": int(_memory[id].get("relationship", {}).get("affinity", 0)), "player": str(Settings.get_value("profile", "name", "friend"))})
	if hit.is_empty(): return {}
	last_cell[id] = str(hit.get("cell_id", ""))
	var a: Dictionary = hit["action"]
	match a.get("type"):
		"say": return {"reply": str(a.get("text", "")), "say": str(a.get("text", ""))}
		"emote": dispatch_tool(id, "emote", {"name": a.get("name", "dance")}); return {"reply": "*%s*" % a.get("name", ""), "did": "emote"}
		"remember": remember_fact(id, str(a.get("fact", ""))); return {"did": "remember"}
		"tool": dispatch_tool(id, str(a.get("name", "")), a.get("args", {})); return {"did": str(a.get("name", ""))}
		"delegate": group_task(str(a.get("command", "")), player_text); return {"did": "group " + str(a.get("command", ""))}
	return {}


# ---------- v0.10 self-learning (feeds BrainCore episodes; BrainLearner does the learning) ----------
const LEARN_INTERVAL_SEC := 120.0
var last_cell := {}       # id -> last brain cell that answered (for feedback)
var last_learn := {}      # id -> last BrainLearner report
static var _TAUGHT := RegEx.create_from_string("(?i)^\\s*when i say ['\"]?(.+?)['\"]?\\s*,?\\s*(?:you\\s+)?(?:say|reply|answer)\\s+['\"]?(.+?)['\"]?\\s*$")
const GOOD_WORDS := ["good job", "nice", "perfect", "love it", "thank you", "thanks", "yes!"]
const BAD_WORDS := ["no that", "don't do that", "stop that", "wrong", "not that"]

## Turn player chat into learner episodes: "when I say X, reply Y" -> taught; praise/scolding -> feedback on last cell.
func _learn_signals(id: String, text: String) -> void:
	var brain: BrainCore = brains.get(id)
	if brain == null: return
	var m := _TAUGHT.search(text)
	if m: brain.memory.log_episode("taught", {"when": m.get_string(1), "reply": m.get_string(2)})
	var lc := str(last_cell.get(id, ""))
	if lc == "": return
	var tl := text.to_lower()
	for w in GOOD_WORDS:
		if tl.contains(w): brain.memory.log_episode("feedback", {"cell_id": lc, "reward": 1.0}); return
	for w in BAD_WORDS:
		if tl.contains(w): brain.memory.log_episode("feedback", {"cell_id": lc, "reward": -1.0}); return

## Run BrainLearner for one companion. Proposals land in BrainCore pending (owner approves in MENU > Proposals).
func learn_now(id: String) -> Dictionary:
	var brain: BrainCore = brains.get(id)
	if brain == null: return {}
	if AutonomyGuard.paused(): return {"paused": true, "proposed": []}
	var r := BrainLearner.learn(brain, 200, false, true)  # via_owner: lands in MENU > Proposals
	last_learn[id] = r
	for pid in r.get("proposed", []):
		EveCore.for_companion(id, brain.persona)._log("Cell Proposed", "Brain", "PendingApproval", str(pid))
	return r

func learn_all() -> void:
	for id in brains: learn_now(id)

## Companion's own building choice: highest-weight enabled cell (learned or seed) whose action is a
## spawn_structure tool, or an event "free_build" cell. Returns structure name or "".
func build_choice(id: String) -> String:
	var brain: BrainCore = brains.get(id)
	if brain == null: return ""
	var best_w := -1.0
	var out := ""
	for c in brain.cells.values():
		var a: Dictionary = c.get("action", {})
		if c.get("enabled", true) and a.get("type") == "tool" and a.get("name") == "spawn_structure" and float(c.get("weight", 0)) > best_w:
			best_w = float(c.get("weight", 0)); out = str(a.get("args", {}).get("name", ""))
	return out
## Mirror owner decisions from EveCore (MENU > Proposals) into the brains; approved cells go live.
func sync_owner_decisions() -> int:
	var n := BrainCore.sync_owner_decisions(EveCore.proposals())
	if n > 0:
		for b in brains.values(): b.reload()
	return n
