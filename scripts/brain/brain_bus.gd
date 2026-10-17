class_name BrainBus
extends RefCounted
## Tiny in-process message bus for companion coordination.
## Group tasks go to the LEAD (Foxy Ani), who splits/delegates them to members.
## Messages are plain dictionaries; handlers are Callables registered by companions.

signal message(topic: String, msg: Dictionary)

const MAX_LOG := 200
var lead_id := "foxy_ani"
var _subs := {}        # companion_id -> Callable(msg) -> Dictionary
var _abilities := {}   # companion_id -> PackedStringArray (lowercased keywords)
var history: Array = []

func register(companion_id: String, handler: Callable, abilities: Array = []) -> void:
	_subs[companion_id] = handler
	var kw := PackedStringArray()
	for a in abilities:
		for w in str(a).to_lower().replace(",", " ").replace("/", " ").split(" ", false): kw.append(w)
	_abilities[companion_id] = kw

func unregister(companion_id: String) -> void:
	_subs.erase(companion_id)
	_abilities.erase(companion_id)

func send(to: String, msg: Dictionary) -> Dictionary:
	_log("direct", msg.merged({"to": to}))
	if not _subs.has(to): return {"ok": false, "error": "no such companion: " + to}
	return _subs[to].call(msg)

## Player/UI posts a group task. Lead decides who does what.
## task: {"command": "build"|"dig"|"follow"|..., "text": "free text", "from": "player"}
func post_group_task(task: Dictionary) -> Array:
	_log("group_task", task)
	if not _subs.has(lead_id): return [{"ok": false, "error": "lead companion not present"}]
	var plan := plan_delegation(task)
	var results: Array = []
	for step in plan:
		var r := send(step["to"], {"type": "delegate", "from": lead_id, "command": step["command"], "text": task.get("text", "")})
		results.append(r.merged({"to": step["to"], "command": step["command"]}))
	return results

## Simple ability-keyword routing. Lead always takes part; members whose abilities match the text join.
## Falls back to everyone for "follow"/"stay" style commands.
func plan_delegation(task: Dictionary) -> Array:
	var cmd := str(task.get("command", ""))
	var words := str(task.get("text", "")).to_lower()
	var plan: Array = [{"to": lead_id, "command": cmd}]
	for id in _subs:
		if id == lead_id: continue
		var match_ability := false
		for kw in _abilities.get(id, []):
			if kw.length() >= 4 and kw in words: match_ability = true; break
		if match_ability or cmd in ["follow", "stay"]:
			plan.append({"to": id, "command": cmd})
	return plan

func _log(topic: String, msg: Dictionary) -> void:
	history.append({"topic": topic, "msg": msg})
	if history.size() > MAX_LOG: history = history.slice(-MAX_LOG)
	message.emit(topic, msg)
