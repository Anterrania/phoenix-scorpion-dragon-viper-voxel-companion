class_name CompanionBroadcast
extends RefCounted
## v0.14 LIVE-2: Companions Live as a broadcast. A rolling, persisted log of each companion's IN-WORLD
## activity: idle / building (CompanionLife actions), talking to each other (scripted banter from their
## persona game_lines, shown as speech bubbles too) and talking with viewers who opted in.
## What is NEVER in it: the owner's chats with companions (AgentBrain replies are not routed here, and
## nothing here reads chat history), anything from a real camera or microphone, or a viewer who did not opt in.
## Members (resident tier and up) can watch; guests see the companion list only (CompanionLive.page).
## "24/7" here means it keeps logging whenever the app is running and the log survives restarts; an
## always-on server is HEAVEN-10 (not built).

const MAX := 400
const MAX_TEXT := 200
const KINDS := ["idle", "building", "talking", "viewer"]
const BLOCKED_WORDS := ["nsfw", "nude", "naked", "sex", "porn", "explicit"]   # broadcast is general-audience
static var root := "user://social"
static var now_override := -1
static var _db = null

static func _now() -> int: return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())
static func _path() -> String: return root.path_join("broadcast.json")
static func db() -> Dictionary:
	if _db == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_db = d if d is Dictionary else {}
		if not _db.has("log"): _db["log"] = []
		if not _db.has("opt_in"): _db["opt_in"] = {}
	return _db
static func _save() -> void: SecureFile.write_json(_path(), db())
static func reset_for_tests(p_root: String) -> void:
	root = p_root; _db = null; now_override = -1

static func enabled() -> bool: return bool(Settings.get_value("companions", "broadcast", true))

static func clean(t: String) -> String:
	var s := t.strip_edges().replace("\n", " ").left(MAX_TEXT)
	var low := s.to_lower()
	for w in BLOCKED_WORDS:
		if low.contains(w): return ""
	return s

static func _add(e: Dictionary) -> Dictionary:
	if not enabled(): return {}
	e["t"] = _now()
	var l: Array = db()["log"]
	l.append(e)
	while l.size() > MAX: l.pop_front()
	_save()
	return e

## Activity line from CompanionLife ("built a hut", "is resting"...). Build verbs -> building, else idle.
static func activity(cid: String, what: String) -> Dictionary:
	var w := clean(what)
	if cid == "" or w == "": return {}
	var low := w.to_lower()
	var kind := "building" if (low.contains("buil") or low.contains("plac") or low.contains("carv") or low.contains("rais") or low.contains("craft")) else "idle"
	return _add({"cid": cid, "kind": kind, "text": w})

## Companion-to-companion banter: one scripted line each, from their persona game_lines.
static func banter(a: String, b: String, seed := -1) -> Array:
	if a == "" or b == "" or a == b: return []
	var la: Array = CompanionsScreen.persona_of(a).get("game_lines", [])
	var lb: Array = CompanionsScreen.persona_of(b).get("game_lines", [])
	if la.is_empty() or lb.is_empty(): return []
	var k := seed if seed >= 0 else _now()
	var out: Array = []
	var e1 := _add({"cid": a, "kind": "talking", "to": b, "text": clean(str(la[k % la.size()]))})
	var e2 := _add({"cid": b, "kind": "talking", "to": a, "text": clean(str(lb[(k + 1) % lb.size()]))})
	if not e1.is_empty(): out.append(e1)
	if not e2.is_empty(): out.append(e2)
	return out

## Viewers choose whether their in-world speech to companions may appear on the broadcast.
static func set_opt_in(viewer: Variant, on: bool) -> void:
	var id := Tiers.actor_id(viewer)
	if id == "": return
	db()["opt_in"][id] = on
	_save()
static func opted_in(viewer: Variant) -> bool: return bool(db()["opt_in"].get(Tiers.actor_id(viewer), false))

## A viewer talks to a companion in the world. Shown only if the viewer opted in; the companion answers
## with one of its scripted lines (not the AI chat, which stays private).
static func viewer_say(viewer: Variant, cid: String, text: String) -> Dictionary:
	var id := Tiers.actor_id(viewer)
	if not opted_in(viewer): return {"ok": false, "error": "Turn on 'Show my words on Companions Live' first."}
	if not Tiers.can(viewer, "message"): return {"ok": false, "error": "Members only."}
	var s := clean(text)
	if s == "": return {"ok": false, "error": "That can't go on the broadcast."}
	var e := _add({"cid": cid, "kind": "viewer", "from": id, "text": s})
	var lines: Array = CompanionsScreen.persona_of(cid).get("game_lines", [])
	var reply := {}
	if not lines.is_empty(): reply = _add({"cid": cid, "kind": "talking", "to": id, "text": clean(str(lines[_now() % lines.size()]))})
	return {"ok": not e.is_empty(), "error": "" if not e.is_empty() else "Broadcast is off.", "entry": e, "reply": reply}

static func recent(cid := "", n := 20) -> Array:
	var out: Array = []
	for e in db()["log"]:
		if cid == "" or str(e.get("cid", "")) == cid or str(e.get("to", "")) == cid: out.append(e)
	return out.slice(-n)

static func status(cid: String) -> String:
	var r := recent(cid, 1)
	return str(r[0].get("kind", "idle")) if not r.is_empty() else "idle"

## In-world ticker: every PERIOD seconds two nearby companions trade a line (bubbles + broadcast).
class Ticker extends Node:
	const PERIOD := 45.0
	const NEAR := 14.0
	var _t := 0.0
	func _process(dt: float) -> void:
		_t += dt
		if _t < PERIOD: return
		_t = 0.0
		if not CompanionBroadcast.enabled() or AutonomyGuard.paused(): return
		var cs: Array = get_tree().get_nodes_in_group("companions")
		for i in cs.size():
			for j in range(i + 1, cs.size()):
				var a: Node3D = cs[i]; var b: Node3D = cs[j]
				if a.global_position.distance_to(b.global_position) > NEAR: continue
				var said := CompanionBroadcast.banter(str(a.get("companion_id")), str(b.get("companion_id")))
				if said.size() == 2:
					if a.has_method("show_bubble"): a.show_bubble(str(said[0]["text"]))
					if b.has_method("show_bubble"): b.show_bubble(str(said[1]["text"]))
				return
