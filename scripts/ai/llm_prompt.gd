class_name LlmPrompt
extends RefCounted
## On-device chat prompt (ChatML, the Qwen2.5 chat format) + tool-call parsing for LocalLLM.
## Pure functions, no engine state: unit-tested in tests/local_ai_tests.gd.
##
## Prompt layout is cache-friendly: the system block (persona, style, facts, tools) stays the same between
## turns, so the native engine reuses its KV cache and only processes the new turn. Volatile context
## (positions, brain-cell hint) rides on the latest user message instead.

const IM_START := "<|im_start|>"
const IM_END := "<|im_end|>"
const MAX_FACTS := 12
const MAX_FACT_CHARS := 160
const CHARS_PER_TOKEN := 3.2   # conservative estimate for budgeting (real count comes from the engine)

## Qwen2.5's own tool instructions (hermes style), so the model sees the format it was trained on.
const TOOLS_HEAD := "# Tools\n\nYou may call one or more functions to assist with the user query.\n\nYou are provided with function signatures within <tools></tools> XML tags:\n<tools>\n"
const TOOLS_TAIL := "\n</tools>\n\nFor each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:\n<tool_call>\n{\"name\": <function-name>, \"arguments\": <args-json-object>}\n</tool_call>"

## Tools whose coordinates are optional for the on-device model (AgentBrain fills "in front of me").
const SPATIAL := ["place_voxel", "carve_area", "spawn_structure"]

## persona: persona.json. facts: Array[String]. tools: Array of OpenAI-style specs (AgentBrain._tool_specs).
static func system_block(persona: Dictionary, facts: Array, tools: Array, player_name := "") -> String:
	var s := str(persona.get("system_prompt", "You are a friendly companion.")).strip_edges()
	var style := str(persona.get("voice_style", "")).strip_edges()
	if style != "": s += "\nStyle: " + style
	s += "\nYou are an AI companion living inside the Viper OS voxel world, running fully on this phone. Reply in 1-3 short sentences, in character. Never mention being a language model."
	if not tools.is_empty():
		s += " Use a tool only when the player asks you to do something in the world; you can still talk while you act."
	if player_name != "": s += "\nThe player's name is %s." % player_name
	var fs := PackedStringArray()
	for f in facts.slice(-MAX_FACTS):
		var t := str(f).strip_edges().left(MAX_FACT_CHARS)
		if t != "": fs.append(t)
	if not fs.is_empty(): s += "\nThings you remember: " + "; ".join(fs) + "."
	if not tools.is_empty():
		var lines := PackedStringArray()
		for spec in tools: lines.append(JSON.stringify(spec))
		s += "\n\n" + TOOLS_HEAD + "\n".join(lines) + TOOLS_TAIL
	return s

## Local tool specs: same tools as the live path, but coordinates optional (small models rarely know them).
static func local_tool_specs(specs: Array) -> Array:
	var out := []
	for s in specs:
		var d: Dictionary = s.duplicate(true)
		var fn: Dictionary = d.get("function", {})
		if str(fn.get("name", "")) in SPATIAL:
			var req: Array = fn.get("parameters", {}).get("required", [])
			fn["parameters"]["required"] = req.filter(func(k): return not (k in ["x", "y", "z"]))
			fn["description"] = str(fn.get("description", "")) + " Coordinates are optional: leave them out to act right in front of you."
		out.append(d)
	return out

## history: Array of {role, content} (user/assistant only). context: one-line volatile context or "".
## budget_tokens: prompt budget; oldest history turns are dropped first. Returns {prompt, kept, est_tokens}.
static func build(system: String, history: Array, user_text: String, context := "", budget_tokens := 1700) -> Dictionary:
	var head := "%ssystem\n%s%s\n" % [IM_START, system, IM_END]
	var last := user_text if context == "" else "[%s]\n%s" % [context, user_text]
	var tail := "%suser\n%s%s\n%sassistant\n" % [IM_START, last, IM_END, IM_START]
	var used := estimate_tokens(head) + estimate_tokens(tail)
	var turns := PackedStringArray()
	var kept := 0
	for i in range(history.size() - 1, -1, -1):
		var h: Variant = history[i]
		if not (h is Dictionary): continue
		var role := str(h.get("role", ""))
		var content := strip_tool_markup(str(h.get("content", ""))).strip_edges()
		if not (role in ["user", "assistant"]) or content == "": continue
		var t := "%s%s\n%s%s\n" % [IM_START, role, content, IM_END]
		var cost := estimate_tokens(t)
		if used + cost > budget_tokens: break
		used += cost
		turns.append(t)
		kept += 1
	turns.reverse()
	return {"prompt": head + "".join(turns) + tail, "kept": kept, "est_tokens": used}

static func estimate_tokens(s: String) -> int:
	return int(ceil(s.length() / CHARS_PER_TOKEN)) + 1

static var _CALL_RE := RegEx.create_from_string("(?s)<tool_call>\\s*(.*?)\\s*(?:</tool_call>|$)")
static var _ARGLIKE_RE := RegEx.create_from_string("^\\{?\\s*\"?\\w+\"?\\s*:\\s*(true|false|null|-?[0-9.]+|\"[^\"]*\")\\s*\\}?$")
static var _BARE_RE := RegEx.create_from_string("(?m)^\\s*(\\{\\s*\"name\"\\s*:.*\\})\\s*$")

## Parse a finished reply: {"text": visible reply, "calls": [{name, args}]}.
## allowed: tool names this companion may use (anything else is dropped here; AgentBrain checks again).
static func parse(raw: String, allowed: Array = []) -> Dictionary:
	var calls := []
	for m in _CALL_RE.search_all(raw):
		_add_call(calls, m.get_string(1), allowed)
	var text := strip_tool_markup(raw)
	# Small models sometimes skip the tags and print the bare JSON object on its own line.
	if calls.is_empty():
		for m in _BARE_RE.search_all(text):
			if _add_call(calls, m.get_string(1), allowed):
				text = text.replace(m.get_string(0), "")
	text = clean_text(text)
	# 0.5B sometimes answers "follow me" with just an argument fragment ("enabled: true"): not worth showing.
	if _ARGLIKE_RE.search(text) != null: text = ""
	return {"text": text, "calls": calls}

static func _add_call(calls: Array, js: String, allowed: Array) -> bool:
	var d: Variant = JSON.parse_string(js)
	if not (d is Dictionary): return false
	var name := str(d.get("name", ""))
	if name == "" or (not allowed.is_empty() and not (name in allowed)): return false
	var a: Variant = d.get("arguments", d.get("parameters", {}))
	if a is String: a = JSON.parse_string(a)
	calls.append({"name": name, "args": a if a is Dictionary else {}})
	return true

## Removes complete and trailing-unfinished <tool_call> blocks and chat-format tokens.
static func strip_tool_markup(s: String) -> String:
	var out := _CALL_RE.sub(s, "", true)
	for tok in [IM_END, IM_START, "<|endoftext|>", "</tool_call>"]:
		out = out.replace(tok, "")
	return out

## Visible text while streaming: hides tool calls and a half-typed "<tool…" tag at the end.
static func visible(partial: String) -> String:
	var s := strip_tool_markup(partial)
	var lt := s.rfind("<")
	if lt >= 0 and not s.substr(lt).contains(">") and "<tool_call>".begins_with(s.substr(lt).left(11)):
		s = s.left(lt)
	return clean_text(s)

static func clean_text(s: String) -> String:
	var t := s.strip_edges()
	while t.contains("\n\n\n"): t = t.replace("\n\n\n", "\n\n")
	return t

## Small on-device models sometimes pick a tool the player never asked for (desktop smoke: "build me a fire
## altar" -> follow). A tool call only runs if the player's message has one of the tool's trigger words.
## Unknown tools (no entry) are allowed. Brain cells still handle exact commands before the model runs.
const TOOL_TRIGGERS := {
	"spawn_structure": ["build", "make", "create", "spawn", "construct", "raise", "tower", "hut", "arch", "pillar", "wall", "altar"],
	"place_voxel": ["place", "put", "block", "voxel", "build", "add"],
	"carve_area": ["dig", "carve", "clear", "remove", "hole", "mine", "tunnel", "flatten"],
	"follow": ["follow", "come", "with me", "stay", "stop", "wait", "keep up"],
	"move_to": ["go", "move", "walk", "come", "run", "over there", "head"],
	"build_realm": ["realm", "world", "island", "landscape", "terrain"],
	"remember": ["remember", "forget", "note", "my name", "i like", "i love", "i hate", "favorite", "favourite", "call me", "i am", "i'm"],
	"emote": ["dance", "wave", "cast", "spin", "celebrate", "emote", "show me", "fire", "idle", "twirl"],
	"heaven_edit": ["build", "add", "put", "place", "plant", "make", "remove", "delete", "take away", "change", "move",
		"paint", "color", "colour", "bigger", "taller", "smaller", "shorter", "rename", "undo", "take back", "heaven"],
}

static func plausible(tool: String, player_text: String) -> bool:
	if not TOOL_TRIGGERS.has(tool): return true
	var t := player_text.to_lower()
	for w in TOOL_TRIGGERS[tool]:
		if t.contains(w): return true
	return false

## CHAT-16: follow-up prompt after tools ran. Qwen2.5 format: the assistant turn that called the tools, then
## a user turn with one <tool_response> per result, then a fresh assistant turn for the spoken answer.
static func followup(prompt: String, raw_reply: String, results: Array) -> String:
	var lines := PackedStringArray()
	for r in results: lines.append("<tool_response>\n%s\n</tool_response>" % JSON.stringify(r))
	return "%s%s%s\n%suser\n%s%s\n%sassistant\n" % [prompt, raw_reply.strip_edges(), IM_END, IM_START, "\n".join(lines), IM_END, IM_START]
