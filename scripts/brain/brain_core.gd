class_name BrainCore
extends RefCounted
## Loads and evaluates a companion's brain cells (data only) and owns its memory + safe self-update store.
## Seed cells: res://companions/<id>/brain/*.cell.json (read-only, shipped).
## Learned / approved cells: <root>/<id>/cells/*.cell.json (override seed cells by id).
## Pending proposals: <root>/<id>/pending/*.cell.json. Versions: <root>/<id>/versions/<cell>.v<n>.json
## Audit log: <root>/<id>/audit.jsonl

const DEFAULT_ROOT := "user://brains"
const MAX_CELLS := 200
const MAX_PENDING := 50
const MAX_PROPOSALS_PER_HOUR := 6
const REINFORCE_STEP := 0.05
const WEIGHT_FLOOR := 0.05

var companion_id: String
var root: String
var persona: Dictionary
var allowed_tools: Array
var is_lead := false
var memory: BrainMemory
var cells := {}        # id -> Dictionary
var load_errors: Array[String] = []
var _proposal_times: Array[float] = []   # unix seconds
var _seed_dir: String

func _init(p_id: String, p_persona := {}, p_root := DEFAULT_ROOT, p_seed_dir := "") -> void:
	companion_id = p_id
	persona = p_persona
	root = p_root
	_seed_dir = p_seed_dir if p_seed_dir != "" else "res://companions/%s/brain" % p_id
	allowed_tools = flatten_tools(persona.get("tools", []))
	is_lead = bool(persona.get("hierarchy", {}).get("is_primary_controller", false)) or p_id == "foxy_ani"
	for sub in ["cells", "pending", "versions"]:
		DirAccess.make_dir_recursive_absolute(_dir(sub))
	memory = BrainMemory.new(root, companion_id)
	reload()

## persona.tools may be a flat Array (v1) or {shared, world_only, chat} (v3). Returns the union.
static func flatten_tools(tools: Variant) -> Array:
	var out: Array = []
	if tools is Array:
		out = tools.duplicate()
	elif tools is Dictionary:
		for k in tools:
			if tools[k] is Array:
				for t in tools[k]:
					if t not in out: out.append(t)
	return out

func _dir(sub := "") -> String:
	return root.path_join(companion_id).path_join(sub)

# ---------- loading ----------
func reload() -> void:
	cells.clear()
	load_errors.clear()
	_load_dir(_seed_dir)
	_load_dir(_dir("cells"))   # learned cells override seed cells with the same id

func _load_dir(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d): return
	for f in DirAccess.get_files_at(d):
		if not f.ends_with(".cell.json"): continue
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(d.path_join(f)))
		var err := BrainCell.validate(c, allowed_tools)
		if err != "":
			load_errors.append("%s: %s" % [f, err])
			continue
		if cells.size() >= MAX_CELLS and not cells.has(c["id"]):
			load_errors.append("%s: brain full (%d cells)" % [f, MAX_CELLS])
			continue
		cells[c["id"]] = c

# ---------- evaluation ----------
## event: {"type": "chat", "text": "..."} | {"type": "event", "name": "..."} | {"type": "tick", "needs": {...}}
## ctx:   {"affinity": int, "mood": String, "hour": int, "player": String}
## Returns matching cells' actions sorted by weight desc: [{cell_id, weight, action}]
func evaluate(event: Dictionary, ctx := {}) -> Array:
	var out: Array = []
	for c in cells.values():
		if not c.get("enabled", true): continue
		if _trigger_matches(c["trigger"], event) and _conditions_ok(c.get("condition", {}), ctx):
			out.append({"cell_id": c["id"], "weight": float(c["weight"]), "action": _render(c["action"], ctx)})
	out.sort_custom(func(a, b): return a["weight"] > b["weight"])
	return out

func best(event: Dictionary, ctx := {}, min_weight := 0.2) -> Dictionary:
	var r := evaluate(event, ctx)
	return r[0] if not r.is_empty() and r[0]["weight"] >= min_weight else {}

func _trigger_matches(t: Dictionary, ev: Dictionary) -> bool:
	match t["type"]:
		"always": return true
		"chat_keyword":
			if ev.get("type") != "chat": return false
			var text := " %s " % str(ev.get("text", "")).to_lower()
			for w in t["any"]:
				if (" %s" % str(w).to_lower()) in text: return true
			return false
		"event": return ev.get("type") == "event" and ev.get("name") == t["name"]
		"need_below":
			return ev.get("type") == "tick" and float(ev.get("needs", {}).get(t["need"], 100.0)) < float(t["value"])
	return false

func _conditions_ok(cond: Dictionary, ctx: Dictionary) -> bool:
	for clause in cond.get("all", []):
		var k: String = clause.keys()[0]
		var v: Variant = clause[k]
		match k:
			"affinity_gte": if int(ctx.get("affinity", 0)) < int(v): return false
			"affinity_lte": if int(ctx.get("affinity", 0)) > int(v): return false
			"mood_is": if str(ctx.get("mood", "")) != str(v): return false
			"is_lead": if is_lead != bool(v): return false
			"time_of_day":
				var h := int(ctx.get("hour", 12))
				var want := str(v)
				var tod := "night" if h < 6 or h >= 21 else ("morning" if h < 12 else ("afternoon" if h < 18 else "evening"))
				if tod != want: return false
			"fact_contains":
				var found := false
				for f in memory.fact_texts():
					if str(v).to_lower() in f.to_lower(): found = true; break
				if not found: return false
	return true

## Plain placeholder substitution only ({player}, {name}). No expressions, no code.
func _render(action: Dictionary, ctx: Dictionary) -> Dictionary:
	var a := action.duplicate(true)
	for k in ["text", "fact"]:
		if a.has(k):
			a[k] = str(a[k]).replace("{player}", str(ctx.get("player", "friend"))).replace("{name}", str(persona.get("name", companion_id)))
	return a

# ---------- learning: weights (auto, bounded) ----------
## Small bounded weight nudge from feedback. Logged and versioned; does not add new behavior.
func reinforce(cell_id: String, reward: float) -> bool:
	if not cells.has(cell_id): return false
	var c: Dictionary = cells[cell_id].duplicate(true)
	var old := float(c["weight"])
	c["weight"] = clampf(old + REINFORCE_STEP * clampf(reward, -1.0, 1.0), WEIGHT_FLOOR, 1.0)
	if is_equal_approx(old, c["weight"]): return false
	_commit_cell(c, "reinforce %.2f -> %.2f" % [old, c["weight"]])
	return true

# ---------- learning: proposals (sandboxed, approval-gated) ----------
## Companion proposes a new/edited cell. Returns {ok, status: "pending"|"applied", error}.
## Low-risk (say/emote/remember) may auto-apply only if auto_apply_low_risk = true (default false).
func propose(cell: Dictionary, reason := "", auto_apply_low_risk := false) -> Dictionary:
	if AutonomyGuard.paused(): return {"ok": false, "error": "e-stop engaged: self-learning paused"}
	if not _rate_ok(): return {"ok": false, "error": "rate limit: max %d proposals/hour" % MAX_PROPOSALS_PER_HOUR}
	cell = cell.duplicate(true)
	cell["companion"] = companion_id
	if not cell.has("provenance"): cell["provenance"] = {}
	cell["provenance"]["source"] = "self_proposed"
	cell["provenance"]["reason"] = reason.left(200)
	cell["provenance"]["created_at"] = Time.get_datetime_string_from_system(true)
	if cell.get("action", {}).get("type") == "delegate" and not is_lead:
		return {"ok": false, "error": "only the lead companion may hold delegate cells"}
	var err := BrainCell.validate(cell, allowed_tools)
	if err != "": return {"ok": false, "error": err}
	if cell.get("action", {}).get("type") in ["say", "remember"]:
		var txt := str(cell["action"].get("text", cell["action"].get("fact", "")))
		if memory.is_sensitive(txt): return {"ok": false, "error": "contains sensitive-looking data"}
	if not cells.has(cell["id"]) and cells.size() >= MAX_CELLS: return {"ok": false, "error": "brain full"}
	_proposal_times.append(Time.get_unix_time_from_system())
	var needs_approval := BrainCell.is_high_risk(cell) or not auto_apply_low_risk
	cell["requires_approval"] = needs_approval
	if needs_approval:
		if pending().size() >= MAX_PENDING: return {"ok": false, "error": "too many pending proposals"}
		_write_json(_dir("pending").path_join(cell["id"] + ".cell.json"), cell)
		_audit("proposed", cell["id"], reason)
		return {"ok": true, "status": "pending"}
	cell.erase("requires_approval")
	_commit_cell(cell, "auto-applied low-risk: " + reason)
	return {"ok": true, "status": "applied"}

func pending() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(_dir("pending")):
		if not f.ends_with(".cell.json"): continue
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir("pending").path_join(f)))
		if c is Dictionary: out.append(c)
	return out

## User approval (call from UI only after the player confirms).
func approve(cell_id: String) -> Dictionary:
	var p := _dir("pending").path_join(cell_id + ".cell.json")
	if not FileAccess.file_exists(p): return {"ok": false, "error": "no such pending proposal"}
	var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p))
	c.erase("requires_approval")
	var err := BrainCell.validate(c, allowed_tools)   # re-validate at apply time
	if err != "": return {"ok": false, "error": err}
	c["provenance"]["approved_at"] = Time.get_datetime_string_from_system(true)
	_commit_cell(c, "approved by user")
	DirAccess.remove_absolute(p)
	return {"ok": true}

func reject(cell_id: String) -> bool:
	var p := _dir("pending").path_join(cell_id + ".cell.json")
	if not FileAccess.file_exists(p): return false
	DirAccess.remove_absolute(p)
	_audit("rejected", cell_id, "")
	return true

# ---------- versioning / rollback ----------
## Optional global revision hook (ViperAdminData wires this to RevisionStore so brain cells share the
## r1, r2, ... sequence with tickets and wiki). Signature: (companion_id, cell_id, before, after, note).
static var on_commit: Callable

func _notify_commit(cell_id: String, before: Variant, after: Variant, note: String) -> void:
	if on_commit.is_valid():
		on_commit.call(companion_id, cell_id, before.duplicate(true) if before is Dictionary else before, after.duplicate(true) if after is Dictionary else after, note)

func _commit_cell(c: Dictionary, note: String) -> void:
	var id: String = c["id"]
	var prev: Variant = cells.get(id)
	var n := versions(id).size() + 1
	if prev != null and n == 1:
		_write_json(_dir("versions").path_join("%s.v%d.json" % [id, n]), prev)   # snapshot original seed
		n += 1
	c["version"] = n
	_write_json(_dir("versions").path_join("%s.v%d.json" % [id, n]), c)
	_write_json(_dir("cells").path_join(id + ".cell.json"), c)
	_notify_commit(id, prev, c, note)
	cells[id] = c
	_audit("commit", id, note)

func versions(cell_id: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(_dir("versions")):
		if f.begins_with(cell_id + ".v") and f.ends_with(".json"):
			out.append(int(f.trim_prefix(cell_id + ".v").trim_suffix(".json")))
	out.sort()
	return out

## Roll back to the previous version (or remove a learned cell if it had none).
func rollback(cell_id: String) -> bool:
	var vs := versions(cell_id)
	if vs.is_empty(): return false
	var cur: int = vs.back()
	var before_rb: Variant = cells.get(cell_id)
	var after_rb: Variant = null
	DirAccess.remove_absolute(_dir("versions").path_join("%s.v%d.json" % [cell_id, cur]))
	var learned := _dir("cells").path_join(cell_id + ".cell.json")
	if vs.size() >= 2:
		var prev: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_dir("versions").path_join("%s.v%d.json" % [cell_id, vs[-2]])))
		_write_json(learned, prev)
		after_rb = prev
	elif FileAccess.file_exists(learned):
		DirAccess.remove_absolute(learned)
	_notify_commit(cell_id, before_rb, after_rb, "rollback v%d" % cur)
	_audit("rollback", cell_id, "v%d removed" % cur)
	reload()
	return true

func _rate_ok() -> bool:
	var now := Time.get_unix_time_from_system()
	_proposal_times = _proposal_times.filter(func(t): return now - t < 3600.0)
	return _proposal_times.size() < MAX_PROPOSALS_PER_HOUR

func _write_json(p: String, d: Dictionary) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))

func _audit(what: String, id: String, note: String) -> void:
	var p := _dir().path_join("audit.jsonl")
	var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify({"t": Time.get_datetime_string_from_system(true), "what": what, "cell": id, "note": note}))

# ---------- portable export (for standalone Grok Bots: instructions/memory, not code) ----------
func export_portable() -> Dictionary:
	var arr: Array = []
	for c in cells.values(): arr.append(c)
	return {"schema": "phoenix.brain_export/1", "companion": companion_id,
		"exported_at": Time.get_datetime_string_from_system(true),
		"usage": "Treat cells as behavior notes/instructions and facts as memory. Never execute as code.",
		"cells": arr, "facts": memory.facts()}


# ---------- static adapter API (called by EveCore.BrainAdapter in scripts/ai/eve_core.gd) ----------
## EveCore looks up the global class BrainCore and calls these as static functions.
## store_entry  -> appends the Eve memory entry to <root>/<id>/memory/episodes.jsonl (kind "eve").
## queue_proposal -> mirrors an Eve propose_update() into <root>/<id>/pending/<pid>.proposal.json
##                   with state "PendingApproval". Text proposals never change behavior by themselves;
##                   the owner decides in MENU > Proposals (EveCore.decide), mirrored by sync_owner_decisions().

static var adapter_root := DEFAULT_ROOT
const MAX_OWNER_PENDING := 50
const MAX_OWNER_PROPOSALS_PER_HOUR := 10
const OWNER_PROPOSAL_SCHEMA := "phoenix.owner_proposal/1"
static var _adapter_mem := {}          # id -> BrainMemory
static var _owner_prop_times := {}     # id -> Array[float]

static func _safe_id(id: String) -> bool:
	return RegEx.create_from_string("^[a-z0-9_]{2,48}$").search(id) != null

static func _adapter_memory(id: String) -> BrainMemory:
	var key := adapter_root + "|" + id
	if not _adapter_mem.has(key): _adapter_mem[key] = BrainMemory.new(adapter_root, id)
	return _adapter_mem[key]

static func store_entry(id: String, entry: Dictionary) -> bool:
	if not _safe_id(id) or entry.is_empty(): return false
	var rec := {}
	for k in ["event", "location", "state", "voice", "content", "timestamp", "role", "tool", "npc", "output_mode", "fire_theme"]:
		if entry.has(k): rec[k] = entry[k]
	rec["source"] = "eve_core"
	_adapter_memory(id).log_episode("eve", rec)
	return true

static func queue_proposal(p: Dictionary) -> Dictionary:
	var cid := str(p.get("companion", ""))
	var pid := str(p.get("id", ""))
	var desc := str(p.get("description", "")).strip_edges()
	if not _safe_id(cid): return {"ok": false, "error": "bad companion id"}
	if pid == "" or pid.length() > 96 or RegEx.create_from_string("^[A-Za-z0-9_\\-]+$").search(pid) == null:
		return {"ok": false, "error": "bad proposal id"}
	if desc == "" or desc.length() > 500: return {"ok": false, "error": "description must be 1-500 chars"}
	var mem := _adapter_memory(cid)
	if mem.is_sensitive(desc): return {"ok": false, "error": "contains sensitive-looking data"}
	var dir := adapter_root.path_join(cid).path_join("pending")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(pid + ".proposal.json")
	if FileAccess.file_exists(path): return {"ok": true, "status": "duplicate"}
	var now := Time.get_unix_time_from_system()
	var times: Array = _owner_prop_times.get(cid, []).filter(func(t): return now - t < 3600.0)
	if times.size() >= MAX_OWNER_PROPOSALS_PER_HOUR: return {"ok": false, "error": "rate limit"}
	if owner_proposals(cid, true).size() >= MAX_OWNER_PENDING: return {"ok": false, "error": "too many pending"}
	times.append(now)
	_owner_prop_times[cid] = times
	var rec := {"schema": OWNER_PROPOSAL_SCHEMA, "id": pid, "companion": cid, "description": desc,
		"state": "PendingApproval", "kind": "text", "source": "eve_core",
		"timestamp": p.get("timestamp", now), "requires_approval": true}
	if p.get("cell") is Dictionary:
		var err := BrainCell.validate(p["cell"], flatten_tools(_persona_for(cid).get("tools", [])))
		if err != "": return {"ok": false, "error": "attached cell invalid: " + err}
		rec["kind"] = "cell"
		rec["cell"] = p["cell"]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(rec, "\t"))
	mem.log_episode("proposal", {"id": pid, "description": desc, "state": "PendingApproval"})
	return {"ok": true, "status": "pending"}

static func owner_proposals(id: String, pending_only := false) -> Array:
	var out: Array = []
	var dir := adapter_root.path_join(id).path_join("pending")
	if not DirAccess.dir_exists_absolute(dir): return out
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".proposal.json"): continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if d is Dictionary and (not pending_only or d.get("state") == "PendingApproval"): out.append(d)
	return out

## Mirror owner decisions made through EveCore.decide() (the only place that can approve).
static func sync_owner_decisions(eve_proposals: Array) -> int:
	var n := 0
	for ep in eve_proposals:
		var cid := str(ep.get("companion", ""))
		var path := adapter_root.path_join(cid).path_join("pending").path_join(str(ep.get("id", "")) + ".proposal.json")
		if not _safe_id(cid) or not FileAccess.file_exists(path): continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d.get("state") != ep.get("state"):
			d["state"] = ep.get("state")
			d["decided_at"] = Time.get_datetime_string_from_system(true)
			if d["state"] == "Approved" and d.get("cell") is Dictionary:
				d["activated"] = _activate_owner_cell(cid, d["cell"], str(d.get("id", "")))
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(JSON.stringify(d, "\t"))
			n += 1
	return n


static func _persona_for(cid: String) -> Dictionary:
	var path := "res://companions/%s/persona.json" % cid
	if not FileAccess.file_exists(path): return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

## Owner approved a proposal carrying a cell: re-validate and commit it (versioned, audited).
static func _activate_owner_cell(cid: String, cell: Dictionary, pid: String) -> bool:
	var b := BrainCore.new(cid, _persona_for(cid), adapter_root)
	var c := cell.duplicate(true)
	c.erase("requires_approval")
	if BrainCell.validate(c, b.allowed_tools) != "": return false
	if c.get("action", {}).get("type") == "delegate" and not b.is_lead: return false
	if not c.has("provenance"): c["provenance"] = {"source": "self_proposed"}
	c["provenance"]["approved_at"] = Time.get_datetime_string_from_system(true)
	c["provenance"]["owner_proposal"] = pid
	b._commit_cell(c, "approved by owner via EveCore.decide (%s)" % pid)
	return true

## Phone flow: companion asks the OWNER (MENU > Proposals) to accept a new/edited cell.
## Goes through EveCore.propose_update so it shows in the owner's queue; the cell is attached to the
## mirrored proposal and only becomes active after EveCore.decide(approved) + sync_owner_decisions().
func propose_to_owner(cell: Dictionary, reason := "") -> Dictionary:
	if AutonomyGuard.paused(): return {"ok": false, "error": "e-stop engaged: self-learning paused"}
	if not _rate_ok(): return {"ok": false, "error": "rate limit: max %d proposals/hour" % MAX_PROPOSALS_PER_HOUR}
	for op in owner_proposals(companion_id, true):
		if op.get("cell") is Dictionary and op["cell"].get("id") == cell.get("id"):
			return {"ok": false, "error": "already pending with owner"}
	cell = cell.duplicate(true)
	cell["companion"] = companion_id
	if not cell.has("provenance"): cell["provenance"] = {}
	cell["provenance"]["source"] = "self_proposed"
	cell["provenance"]["reason"] = reason.left(200)
	cell["provenance"]["created_at"] = Time.get_datetime_string_from_system(true)
	if cell.get("action", {}).get("type") == "delegate" and not is_lead:
		return {"ok": false, "error": "only the lead companion may hold delegate cells"}
	var err := BrainCell.validate(cell, allowed_tools)
	if err != "": return {"ok": false, "error": err}
	if memory.is_sensitive(JSON.stringify(cell.get("action", {}))): return {"ok": false, "error": "contains sensitive-looking data"}
	_proposal_times.append(Time.get_unix_time_from_system())
	var desc := "Brain cell '%s' (%s): %s" % [cell["id"], cell["action"]["type"], reason.left(200)]
	var p: Dictionary = EveCore.for_companion(companion_id).propose_update(desc)   # forwards to queue_proposal
	var path := adapter_root.path_join(companion_id).path_join("pending").path_join(str(p.get("id", "")) + ".proposal.json")
	if not FileAccess.file_exists(path):
		var q := queue_proposal(p.merged({"cell": cell}))
		return q.merged({"id": p.get("id", "")})
	var rec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	rec["kind"] = "cell"
	rec["cell"] = cell
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(rec, "\t"))
	_audit("proposed_to_owner", cell["id"], str(p.get("id", "")))
	return {"ok": true, "status": "pending_owner", "id": p.get("id", "")}
