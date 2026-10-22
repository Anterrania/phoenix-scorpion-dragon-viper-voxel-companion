class_name QuestEngine
extends RefCounted
## SBX-2: quest / mission engine (data + logic only; Foxy's journal and dialogue UI call this API).
## Concepts from open-world and RPG games (quest lines, objectives, timed missions, repeatables,
## branching follow-ups), rebuilt in our own code. Nothing here copies any game's quests or text.
##
## Definitions: res://data/sandbox/quests.json (shipped) + user-authored ones in user://sandbox/quests.json.
##   {id, title, summary, kind: "quest"|"mission", giver, region, prereq: [ids], repeatable, cooldown_s,
##    time_limit_s (missions), fail_on: ["timeout", "leave_region"], order: "any"|"sequence",
##    objectives: [{id, type, target, count, optional}], rewards: {xp: {skill: n}, tokens: n, items: [ids],
##    reputation: {group: n}}, next: [quest ids offered on completion (branches)]}
## Per-actor progress: user://sandbox/quest_state.json {actor: {qid: {status, progress, started, done_at, ...}}}
##
## API (all return "" or a Dictionary; errors are plain sentences for the UI):
##   definitions(), definition(id), available(actor, now), accept(actor, id, now), report(actor, type, target,
##   amount, now, region) -> [updates], tick(actor, now) -> [failed ids], abandon(actor, id), claim(actor, id, now)
##   -> rewards, journal(actor), track(actor, id), author(actor, def) (draft), publish(actor, id) (owner only).
## Rewards are handed back to the caller: XP goes to Foxy's skill system, tokens are free-play quest
## play tokens (earned-only, PlayTokens; credited on claim, no cash value). An Aethel Coin reward is
## refused: LegalReview "aethel_quest_reward" is LATER (off, counsel required). Rewards are fixed, never random.

const OBJECTIVE_TYPES := ["collect", "visit", "talk", "use", "build", "deliver", "defeat", "photo", "custom"]
const STATUS := ["active", "complete", "claimed", "failed", "abandoned"]
const MAX_ACTIVE := 25
const MAX_OBJECTIVES := 12

static var _authored = null
static var _state = null

static var _ship = null
static func _shipped() -> Array:
	if _ship == null: _ship = SandboxGate.data("quests").get("quests", [])
	return _ship
static func authored() -> Dictionary:
	if _authored == null:
		var d: Variant = SandboxGate.load_json("quests", {})
		_authored = d if d is Dictionary else {}
	return _authored
static func _st() -> Dictionary:
	if _state == null:
		var d: Variant = SandboxGate.load_json("quest_state", {})
		_state = d if d is Dictionary else {}
	return _state
static func _save_state() -> bool: return SandboxGate.save_json("quest_state", _st())

## Published definitions only (shipped + owner-published authored quests).
static func definitions() -> Array:
	var out: Array = _shipped().duplicate()
	for id in authored():
		if str(authored()[id].get("status", "")) == "published": out.append(authored()[id])
	return out

static func definition(id: String) -> Dictionary:
	for d in definitions():
		if str(d.get("id", "")) == id: return d
	return {}

static func validate(d: Dictionary) -> String:
	var id := str(d.get("id", ""))
	if id == "" or not id.is_valid_identifier(): return "Quest id must be letters, digits and _."
	if str(d.get("title", "")).strip_edges() == "": return "Quest needs a title."
	if not str(d.get("kind", "quest")) in ["quest", "mission"]: return "Kind must be quest or mission."
	var objs: Array = d.get("objectives", [])
	if objs.is_empty() or objs.size() > MAX_OBJECTIVES: return "Quest needs 1 to %d objectives." % MAX_OBJECTIVES
	var seen := {}
	for o in objs:
		if not (o is Dictionary) or str(o.get("id", "")) == "" or seen.has(o["id"]): return "Each objective needs a unique id."
		seen[o["id"]] = true
		if not str(o.get("type", "")) in OBJECTIVE_TYPES: return "Unknown objective type: %s." % str(o.get("type", ""))
		if int(o.get("count", 1)) < 1: return "Objective count must be at least 1."
	var r: Dictionary = d.get("rewards", {})
	# LEGAL REVIEW: no Aethel Coin quest rewards until counsel signs off.
	if r.has("aethel") and not LegalReview.allowed("aethel_quest_reward", {}): return "Aethel Coin rewards are off (legal review)."
	if int(r.get("tokens", 0)) < 0: return "Token reward can't be negative."
	if str(d.get("kind", "quest")) == "mission" and int(d.get("time_limit_s", 0)) < 0: return "Time limit can't be negative."
	return ""

# ---------- authoring ----------
## Creator tier and up can draft; the owner publishes (in-app proposal style, nothing goes live alone).
static func author(actor: Variant, d: Dictionary) -> String:
	if not SandboxGate.can(actor, "author"): return "You can't write quests at your tier."
	var err := validate(d)
	if err != "": return err
	var id := str(d["id"])
	if definition(id).size() > 0 and not authored().has(id): return "A shipped quest already uses that id."
	var copy := d.duplicate(true)
	copy["status"] = "draft"; copy["author"] = SandboxGate.id_of(actor)
	authored()[id] = copy
	return "" if SandboxGate.save_json("quests", authored()) else "Saves are sealed. Unlock first."

static func publish(actor: Variant, id: String) -> String:
	if not SandboxGate.can(actor, "publish_quest"): return "Owner unlock needed."
	if not authored().has(id): return "No draft with that id."
	authored()[id]["status"] = "published"
	return "" if SandboxGate.save_json("quests", authored()) else "Saves are sealed. Unlock first."

# ---------- player flow ----------
static func _mine(actor: Variant) -> Dictionary:
	var id := SandboxGate.id_of(actor)
	if not _st().has(id): _st()[id] = {}
	return _st()[id]

static func status_of(actor: Variant, qid: String) -> String:
	return str(_mine(actor).get(qid, {}).get("status", ""))

static func _why_not(actor: Variant, d: Dictionary, now: int) -> String:
	if d.is_empty(): return "No such quest."
	var reg := str(d.get("region", ""))
	if not SandboxGate.can(actor, "play", reg): return "You can't take quests here."
	var mine := _mine(actor)
	var qid := str(d["id"])
	var cur: Dictionary = mine.get(qid, {})
	match str(cur.get("status", "")):
		"active", "complete": return "Already on this quest."
		"claimed":
			if not bool(d.get("repeatable", false)): return "Already done."
			if now - int(cur.get("done_at", 0)) < int(d.get("cooldown_s", 0)): return "Not ready again yet."
	for p in d.get("prereq", []):
		if str(mine.get(str(p), {}).get("status", "")) != "claimed": return "Finish the earlier quest first."
	var active := 0
	for k in mine:
		if str(mine[k].get("status", "")) == "active": active += 1
	if active >= MAX_ACTIVE: return "Your journal is full."
	return ""

static func available(actor: Variant, now: int) -> Array:
	return definitions().filter(func(d): return _why_not(actor, d, now) == "")

static func accept(actor: Variant, qid: String, now: int) -> String:
	var d := definition(qid)
	var err := _why_not(actor, d, now)
	if err != "": return err
	var prog := {}
	for o in d["objectives"]: prog[str(o["id"])] = 0
	_mine(actor)[qid] = {"status": "active", "progress": prog, "started": now, "done_at": 0}
	return "" if _save_state() else "Saves are sealed. Unlock first."

static func _obj_done(o: Dictionary, prog: Dictionary) -> bool:
	return int(prog.get(str(o["id"]), 0)) >= int(o.get("count", 1))

static func _all_done(d: Dictionary, prog: Dictionary) -> bool:
	for o in d["objectives"]:
		if not bool(o.get("optional", false)) and not _obj_done(o, prog): return false
	return true

## Report a world event ("collect", "voxel_ice", 3). Advances every active quest that wants it.
## Sequence quests only advance their first unfinished required objective.
static func report(actor: Variant, type: String, target: String, amount := 1, now := 0, region := "") -> Array:
	var updates: Array = []
	var mine := _mine(actor)
	for qid in mine.keys():
		var q: Dictionary = mine[qid]
		if str(q.get("status", "")) != "active": continue
		var d := definition(str(qid))
		if d.is_empty(): continue
		var qr := str(d.get("region", ""))
		if qr != "" and region != "" and region != qr:
			if "leave_region" in d.get("fail_on", []): q["status"] = "failed"; updates.append({"quest": qid, "failed": true})
			continue
		var objs: Array = d["objectives"]
		if str(d.get("order", "any")) == "sequence":
			objs = []
			for o in d["objectives"]:
				if not _obj_done(o, q["progress"]):
					objs = [o]; break
		for o in objs:
			if str(o["type"]) != type or str(o.get("target", "")) != target or _obj_done(o, q["progress"]): continue
			var n := mini(int(q["progress"].get(str(o["id"]), 0)) + maxi(amount, 0), int(o.get("count", 1)))
			q["progress"][str(o["id"])] = n
			updates.append({"quest": qid, "objective": o["id"], "count": n, "of": int(o.get("count", 1))})
		if _all_done(d, q["progress"]):
			q["status"] = "complete"; q["done_at"] = now
			updates.append({"quest": qid, "complete": true})
	if not updates.is_empty(): _save_state()
	return updates

## Timed missions fail when time_limit_s runs out (and "timeout" is in fail_on, the default for missions).
static func tick(actor: Variant, now: int) -> Array:
	var failed: Array = []
	var mine := _mine(actor)
	for qid in mine:
		var q: Dictionary = mine[qid]
		if str(q.get("status", "")) != "active": continue
		var d := definition(str(qid))
		var lim := int(d.get("time_limit_s", 0))
		var fails: Array = d.get("fail_on", ["timeout"] if str(d.get("kind", "")) == "mission" else [])
		if lim > 0 and "timeout" in fails and now - int(q["started"]) > lim:
			q["status"] = "failed"; failed.append(qid)
	if not failed.is_empty(): _save_state()
	return failed

static func abandon(actor: Variant, qid: String) -> String:
	var q: Dictionary = _mine(actor).get(qid, {})
	if str(q.get("status", "")) != "active": return "That quest isn't active."
	q["status"] = "abandoned"
	return "" if _save_state() else "Saves are sealed. Unlock first."

## Claim once complete. Returns {"rewards": {...}, "next": [ids]} or {"error": "..."}.
static func claim(actor: Variant, qid: String, now := 0) -> Dictionary:
	var q: Dictionary = _mine(actor).get(qid, {})
	if str(q.get("status", "")) != "complete": return {"error": "Not complete yet."}
	var d := definition(qid)
	var r: Dictionary = d.get("rewards", {}).duplicate(true)
	r.erase("aethel")   # LEGAL REVIEW: never paid out by this engine (LegalReview "aethel_quest_reward" is LATER/off)
	q["status"] = "claimed"; q["done_at"] = maxi(now, int(q.get("done_at", 0)))
	if not _save_state(): q["status"] = "complete"; return {"error": "Saves are sealed. Unlock first."}
	if int(r.get("tokens", 0)) > 0: PlayTokens.earn(SandboxGate.id_of(actor), int(r["tokens"]), "quest")
	return {"rewards": r, "next": d.get("next", [])}

static func track(actor: Variant, qid: String) -> String:
	if status_of(actor, qid) != "active": return "Only active quests can be tracked."
	for k in _mine(actor): _mine(actor)[k].erase("tracked")
	_mine(actor)[qid]["tracked"] = true
	return "" if _save_state() else "Saves are sealed. Unlock first."

## Journal rows for the UI: [{id, title, kind, status, tracked, objectives: [{id, text, count, of, done}]}].
static func journal(actor: Variant) -> Array:
	var out: Array = []
	var mine := _mine(actor)
	for qid in mine:
		var d := definition(str(qid))
		if d.is_empty(): continue
		var q: Dictionary = mine[qid]
		var rows: Array = []
		for o in d["objectives"]:
			rows.append({"id": o["id"], "text": str(o.get("text", "%s %s" % [o["type"], o.get("target", "")])),
				"count": int(q["progress"].get(str(o["id"]), 0)), "of": int(o.get("count", 1)), "done": _obj_done(o, q["progress"]),
				"optional": bool(o.get("optional", false))})
		out.append({"id": qid, "title": d.get("title", ""), "kind": d.get("kind", "quest"), "status": q["status"],
			"tracked": bool(q.get("tracked", false)), "objectives": rows})
	return out

static func reset_for_tests() -> void:
	_authored = null; _state = null
