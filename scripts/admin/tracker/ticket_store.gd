class_name TicketStore
extends RefCounted
## Trac-style tickets stored in <root>/tickets.json; every change is an SVN-style revision.
## Workflow (Trac default): new -> assigned -> accepted -> closed, closed -> reopened -> assigned/accepted/closed.

const TYPES := ["defect", "enhancement", "task"]
const PRIORITIES := ["P0", "P1", "P2", "P3"]
const RESOLUTIONS := ["fixed", "invalid", "wontfix", "duplicate", "worksforme"]
const WORKFLOW := {
	"new": ["assigned", "accepted", "closed"],
	"assigned": ["accepted", "new", "closed"],
	"accepted": ["assigned", "closed"],
	"closed": ["reopened"],
	"reopened": ["assigned", "accepted", "closed"],
}
const SEED_PATH := "res://data/admin/tickets_seed.json"

var revs: RevisionStore
var path: String
var tickets := {}   # int id -> Dictionary

func _init(p_revs: RevisionStore, seed_if_empty := true) -> void:
	revs = p_revs
	path = revs.root.path_join("tickets.json")
	_load()
	revs.register_applier("ticket", _apply)
	if tickets.is_empty() and seed_if_empty: seed_from_res()

func _load() -> void:
	tickets.clear()
	var d: Variant = SecureFile.read_json(path)
	if d is Array:
		for t in d: tickets[int(t["id"])] = t

func _save() -> void:
	var arr: Array = []
	var ids := tickets.keys(); ids.sort()
	for id in ids: arr.append(tickets[id])
	SecureFile.write_json(path, arr, "\t")

func seed_from_res() -> int:
	if not FileAccess.file_exists(SEED_PATH): return 0
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEED_PATH))
	if not (d is Array): return 0
	for t in d:
		var tk := _normalize(t)
		tk["id"] = int(t.get("id", next_id()))
		tickets[tk["id"]] = tk
	_save()
	revs.commit("ticket", "ticket/", null, {"seeded": tickets.size()}, "Seed %d tickets from docs/TASK_TRACKER.csv" % tickets.size(), "system")
	return tickets.size()

func next_id() -> int:
	var m := 0
	for id in tickets: m = maxi(m, int(id))
	return m + 1

static func _normalize(t: Dictionary) -> Dictionary:
	var ty := str(t.get("type", "task"))
	var pr := str(t.get("priority", "P2"))
	return {"id": int(t.get("id", 0)), "type": ty if ty in TYPES else "task",
		"summary": str(t.get("summary", "")).left(200), "description": str(t.get("description", "")).left(4000),
		"status": str(t.get("status", "new")) if str(t.get("status", "new")) in WORKFLOW else "new",
		"resolution": str(t.get("resolution", "")), "priority": pr if pr in PRIORITIES else "P2",
		"component": str(t.get("component", "general")).left(40), "milestone": str(t.get("milestone", "")).left(40),
		"owner": str(t.get("owner", "")).left(40), "reporter": str(t.get("reporter", "local")).left(40),
		"comments": t.get("comments", []) if t.get("comments", []) is Array else [],
		"revisions": t.get("revisions", []) if t.get("revisions", []) is Array else []}

func create(fields: Dictionary, author := "local") -> int:
	if str(fields.get("summary", "")).strip_edges() == "": return 0
	var t := _normalize(fields)
	t["id"] = next_id()
	t["status"] = "new"
	t["reporter"] = author.left(40)
	tickets[t["id"]] = t
	_save()
	t["revisions"].append(revs.commit("ticket", "ticket/%d" % t["id"], null, t.duplicate(true), "Ticket #%d created: %s" % [t["id"], t["summary"]], author))
	_save()
	return t["id"]

func get_ticket(id: int) -> Dictionary: return tickets.get(id, {})

func can_transition(id: int, to: String) -> bool:
	var t := get_ticket(id)
	return not t.is_empty() and to in WORKFLOW.get(t["status"], [])

## Returns the revision number, or 0 if the transition is not allowed.
func transition(id: int, to: String, author := "local", resolution := "fixed", owner := "") -> int:
	if not can_transition(id, to): return 0
	if to == "closed" and resolution not in RESOLUTIONS: return 0
	var t: Dictionary = tickets[id]
	var before := t.duplicate(true)
	var from: String = t["status"]
	t["status"] = to
	t["resolution"] = resolution if to == "closed" else ""
	if to == "assigned" and owner != "": t["owner"] = owner.left(40)
	if to == "accepted": t["owner"] = author.left(40)
	return _commit(id, before, "#%d %s -> %s" % [id, from, to], author)

func update(id: int, fields: Dictionary, author := "local") -> int:
	if not tickets.has(id): return 0
	var t: Dictionary = tickets[id]
	var before := t.duplicate(true)
	for k in ["summary", "description", "priority", "component", "milestone", "type"]:
		if fields.has(k): t[k] = str(fields[k])
	if t["priority"] not in PRIORITIES or t["type"] not in TYPES: tickets[id] = before; return 0
	return _commit(id, before, "#%d updated" % id, author)

## Comments may reference revisions (r42), other tickets (#12) and wiki pages; links are parsed on render.
func comment(id: int, text: String, author := "local") -> int:
	text = text.strip_edges().left(2000)
	if not tickets.has(id) or text == "": return 0
	var t: Dictionary = tickets[id]
	var before := t.duplicate(true)
	t["comments"].append({"author": author.left(40), "t": RevisionStore.local_iso(), "text": text})
	for m in RegEx.create_from_string("\\br(\\d+)\\b").search_all(text):
		var rv := int(m.get_string(1))
		if rv not in t["revisions"]: t["revisions"].append(rv)
	return _commit(id, before, "#%d comment" % id, author)

func _commit(id: int, before: Dictionary, msg: String, author: String) -> int:
	var t: Dictionary = tickets[id]
	var after := t.duplicate(true)
	var rv := revs.commit("ticket", "ticket/%d" % id, before, after, msg, author)
	if rv > 0: t["revisions"].append(rv)
	_save()
	return rv

func _apply(p: String, content: Variant) -> bool:
	var id := int(p.trim_prefix("ticket/"))
	if id <= 0: return false
	if content == null: tickets.erase(id)
	elif content is Dictionary: tickets[id] = _normalize(content); tickets[id]["id"] = id
	else: return false
	_save()
	return true

func query(status := "", milestone := "") -> Array:
	var out: Array = []
	var ids := tickets.keys(); ids.sort()
	for id in ids:
		var t: Dictionary = tickets[id]
		if (status == "" or t["status"] == status) and (milestone == "" or t["milestone"] == milestone): out.append(t)
	return out

func counts_by_status() -> Dictionary:
	var c := {}
	for s in WORKFLOW: c[s] = 0
	for t in tickets.values(): c[t["status"]] = int(c.get(t["status"], 0)) + 1
	return c
