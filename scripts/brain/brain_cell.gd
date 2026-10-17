class_name BrainCell
extends RefCounted
## Brain cell = one small DATA rule (JSON). Never code. Schema: data/schema/brain_cell.schema.json
##   { "schema": "phoenix.brain_cell/1", "id": "greet_hello", "companion": "foxy_ani",
##     "trigger":   {"type": "chat_keyword", "any": ["hello", "hi"]},
##     "condition": {"all": [{"affinity_gte": -20}]},
##     "action":    {"type": "say", "text": "Hey {player}! Rise from the flame."},
##     "weight": 0.6, "version": 1, "enabled": true,
##     "provenance": {"source": "seed", "author": "dev", "created_at": "...", "reason": "..."} }
## Standalone Grok Bots read the same files as memory/instructions; nothing here is executable.

const SCHEMA_ID := "phoenix.brain_cell/1"
const MAX_BYTES := 4096
const TRIGGER_TYPES := ["chat_keyword", "event", "need_below", "always"]
const ACTION_TYPES := ["say", "emote", "remember", "tool", "delegate"]
## Actions that change what the companion DOES in the world -> always need user approval when self-proposed.
const HIGH_RISK_ACTIONS := ["tool", "delegate"]
const CONDITION_KEYS := ["affinity_gte", "affinity_lte", "fact_contains", "mood_is", "is_lead", "time_of_day"]
const SOURCES := ["seed", "user", "self_proposed", "import"]
const ID_PATTERN := "^[a-z0-9_]{2,48}$"
const EMOTES := ["dance", "wave", "fire_cast", "idle"]

## Returns "" if valid, else a human-readable error. `allowed_tools` = persona tool whitelist.
static func validate(c: Variant, allowed_tools: Array = []) -> String:
	if not (c is Dictionary): return "cell is not an object"
	if JSON.stringify(c).length() > MAX_BYTES: return "cell larger than %d bytes" % MAX_BYTES
	if c.get("schema", "") != SCHEMA_ID: return "schema must be " + SCHEMA_ID
	var re := RegEx.create_from_string(ID_PATTERN)
	if re.search(str(c.get("id", ""))) == null: return "bad id (a-z0-9_, 2-48 chars)"
	var t: Variant = c.get("trigger")
	if not (t is Dictionary) or t.get("type") not in TRIGGER_TYPES: return "bad trigger.type"
	if t["type"] == "chat_keyword":
		var any: Variant = t.get("any")
		if not (any is Array) or any.is_empty() or any.size() > 16: return "chat_keyword needs 1-16 'any' words"
		for w in any:
			if not (w is String) or w.length() > 40: return "keyword must be a short string"
	if t["type"] == "event" and not (t.get("name") is String): return "event trigger needs name"
	if t["type"] == "need_below" and not (t.get("need") is String and (t.get("value") is float or t.get("value") is int)): return "need_below needs need+value"
	var cond: Variant = c.get("condition", {"all": []})
	if not (cond is Dictionary) or not (cond.get("all", []) is Array): return "condition must be {all: [...]}"
	for clause in cond.get("all", []):
		if not (clause is Dictionary) or clause.size() != 1 or clause.keys()[0] not in CONDITION_KEYS:
			return "unknown condition clause: %s" % str(clause)
	var a: Variant = c.get("action")
	if not (a is Dictionary) or a.get("type") not in ACTION_TYPES: return "bad action.type"
	match a["type"]:
		"say":
			if not (a.get("text") is String) or a["text"].length() > 400: return "say.text must be <=400 chars"
		"emote":
			if a.get("name") not in EMOTES: return "unknown emote"
		"remember":
			if not (a.get("fact") is String) or a["fact"].length() > 300: return "remember.fact must be <=300 chars"
		"tool":
			if not (a.get("name") is String): return "tool action needs name"
			if not allowed_tools.is_empty() and a["name"] not in allowed_tools: return "tool not in persona whitelist: " + str(a["name"])
			if not (a.get("args", {}) is Dictionary): return "tool args must be object"
		"delegate":
			if not (a.get("to") is String) or not (a.get("command") is String): return "delegate needs to+command"
	var w: Variant = c.get("weight")
	if not (w is float or w is int) or float(w) < 0.0 or float(w) > 1.0: return "weight must be 0..1"
	var p: Variant = c.get("provenance")
	if not (p is Dictionary) or p.get("source") not in SOURCES: return "provenance.source required"
	return ""

static func is_high_risk(c: Dictionary) -> bool:
	return c.get("action", {}).get("type", "") in HIGH_RISK_ACTIONS

static func make(id: String, companion: String, trigger: Dictionary, action: Dictionary, weight: float, source: String, reason := "") -> Dictionary:
	return {"schema": SCHEMA_ID, "id": id, "companion": companion, "trigger": trigger,
		"condition": {"all": []}, "action": action, "weight": clampf(weight, 0.0, 1.0),
		"version": 1, "enabled": true,
		"provenance": {"source": source, "author": companion if source == "self_proposed" else source,
			"created_at": Time.get_datetime_string_from_system(true), "reason": reason}}
