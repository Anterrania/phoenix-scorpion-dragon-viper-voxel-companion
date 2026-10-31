class_name HeavenEdits
extends RefCounted
## HEAVEN-6: Heaven is built LIVE. District layouts are data (data/heaven/districts/<island>.json);
## companions change them at runtime through their build tool, and every change streams into the
## running world (HeavenWorld rebuilds only the touched island, no restart).
## Flow:
##   1. A companion proposes an edit (tool_call / propose): validated here (types, sizes, plaza bounds).
##   2. Approval:
##      - owner standing grant (HeavenAccess "build") -> applied at once, logged;
##      - otherwise an EveCore proposal ("[heaven-edit <id>] ...") waits for the owner, and sync()
##        applies it when EveCore.decide() marks it Approved (or drops it when Rejected);
##      - "Direct a change": when the unlocked owner directs a companion, the owner's instruction is
##        the approval (proposal logged and approved in one step).
##   3. Applied edits overlay the base files in order; revision(island) bumps so the world rebuilds.
## Store: user://heaven/edits.json via SecureFile (sealed while locked). Base files are never written.
## Runs while the app is open. True 24/7 building while the owner is away needs a persistent server
## (docs/VOXEL_WORLD_PLAN.md, Heaven roadmap).

const OPS := ["add", "remove", "set"]
## HEAVEN-9: extra op on the chat tool only (never stored as an edit op).
const UNDO_OP := "undo"
const SET_KEYS := ["at", "yaw", "w", "d", "h", "r", "color", "trim", "text", "name", "n"]
const LIMITS := {"w": [1.0, 60.0], "d": [1.0, 60.0], "h": [0.5, 140.0], "r": [0.5, 40.0], "n": [3, 24]}
const MAX_APPLIED := 2000
const MAX_PENDING_PER := 20
const TOOL_NAME := "heaven_edit"
## Tool description for the companion tool registry (wired by the chat/agent owner; see
## docs/specs/foxy/HEAVEN_CLIENT.md). Coordinates are WORLD metres; the island is found from x/z/y.
const TOOL_SPEC := {
	"name": TOOL_NAME,
	"description": "Change Heaven Welcome Island: add, move/resize/recolor, or remove a piece (building, tree, lamp, fountain, sign...). Goes to the owner for approval unless you hold a standing build grant.",
	"parameters": {"op": "add | set | remove", "type": "piece type for add (see HeavenBuilder.EDITABLE)",
		"x": "world x", "y": "world y (height of the spot)", "z": "world z", "target": "piece id for set/remove",
		"yaw": "degrees", "w": "m", "d": "m", "h": "m", "r": "m", "color": "#rrggbb", "trim": "#rrggbb", "text": "sign text", "name": "label", "note": "why"},
}

static var root := "user://heaven"
static var _e = null
static var _base: Dictionary = {}     # island -> base pieces (from res://)
static var _rev: Dictionary = {}      # island -> revision counter (bumps on every applied change)
static var _seq := 0

static func _path() -> String: return root.path_join("edits.json")

static func _all() -> Dictionary:
	if _e == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_e = d if d is Dictionary else {}
		if not (_e.get("edits") is Array): _e["edits"] = []
	return _e

static func _save() -> bool: return SecureFile.write_json(_path(), _all())

static func edits(state := "") -> Array:
	return _all()["edits"].filter(func(x): return state == "" or x["state"] == state)

static func base_file(island_id: String) -> Dictionary:
	var path := "res://data/heaven/districts/%s.json" % island_id
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return d if d is Dictionary else {"pieces": []}

static func base_pieces(island_id: String) -> Array:
	if not _base.has(island_id): _base[island_id] = base_file(island_id).get("pieces", [])
	return _base[island_id]

## Base pieces + applied edits, in order. Deep copy: callers may not mutate the store.
static func pieces(island_id: String) -> Array:
	var list: Array = base_pieces(island_id).duplicate(true)
	for e in _all()["edits"]:
		if e["state"] != "applied" or e["island"] != island_id: continue
		_apply_to(list, e)
	return list

static func _apply_to(list: Array, e: Dictionary) -> void:
	match str(e["op"]):
		"add": list.append(e["piece"].duplicate(true))
		"remove":
			for i in list.size():
				if list[i]["id"] == e["target"]: list.remove_at(i); break
		"set":
			for p in list:
				if p["id"] == e["target"]:
					for k in e["set"]: p[k] = e["set"][k]
					break

static func find_piece(island_id: String, piece_id: String) -> Dictionary:
	for p in pieces(island_id):
		if p["id"] == piece_id: return p
	return {}

static func revision(island_id: String) -> int: return int(_rev.get(island_id, 0))

# ---------- validation ----------
static func _clamp_num(k: String, v: Variant) -> Variant:
	var lim: Array = LIMITS.get(k, [])
	if lim.is_empty(): return v
	return clampi(int(v), int(lim[0]), int(lim[1])) if k == "n" else clampf(float(v), float(lim[0]), float(lim[1]))

## Cleans one field. Returns [ok, value_or_reason].
static func _clean(isl: Dictionary, k: String, v: Variant) -> Array:
	match k:
		"at":
			if not (v is Array) or v.size() != 2: return [false, "Position must be [x, z]."]
			var p := Vector2(float(v[0]), float(v[1]))
			if p.length() > HeavenLayout.plaza_radius(isl) * 0.97: return [false, "That spot is off the plaza edge."]
			return [true, [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]]
		"yaw": return [true, fposmod(float(v), 360.0)]
		"color", "trim":
			var s := str(v)
			if not s.begins_with("#") or not Color.html_is_valid(s): return [false, "Colour must be #rrggbb."]
			return [true, s.left(9)]
		"text", "name":
			var t := str(v).strip_edges().left(40)
			return [true, t]
		"w", "d", "h", "r", "n": return [true, _clamp_num(k, v)]
	return [false, "Field %s can't be changed." % k]

## Validates and normalises an edit. Returns {"edit": {...}} or {"error": "..."}.
static func validate(edit: Dictionary) -> Dictionary:
	var isl := HeavenLayout.island(str(edit.get("island", "")))
	if isl.is_empty(): return {"error": "Unknown Heaven district."}
	var op := str(edit.get("op", ""))
	if not op in OPS: return {"error": "op must be add, set or remove."}
	var out := {"island": isl["id"], "op": op}
	if op == "add":
		var src: Dictionary = edit.get("piece", {})
		var t := str(src.get("type", ""))
		if not t in HeavenBuilder.EDITABLE: return {"error": "Companions can't add a '%s'." % t}
		if t == "shop" and HeavenShops.shop(str(src.get("shop", ""))).is_empty(): return {"error": "Unknown shop."}
		var piece := {"type": t}
		if t == "shop": piece["shop"] = str(src["shop"])
		for k in src:
			if k in ["type", "shop", "id"]: continue
			var r := _clean(isl, k, src[k])
			if not r[0]: return {"error": r[1]}
			piece[k] = r[1]
		if not piece.has("at"): return {"error": "Where? (position needed)"}
		out["piece"] = piece
	else:
		var target := str(edit.get("target", ""))
		if find_piece(isl["id"], target).is_empty(): return {"error": "No such piece here."}
		out["target"] = target
		if op == "set":
			var st := {}
			var src2: Dictionary = edit.get("set", {})
			for k in src2:
				var r := _clean(isl, k, src2[k])
				if not r[0]: return {"error": r[1]}
				st[k] = r[1]
			if st.is_empty(): return {"error": "Nothing to change."}
			out["set"] = st
	return {"edit": out}

static func describe(e: Dictionary) -> String:
	var isl := str(HeavenLayout.island(str(e["island"])).get("name", e["island"]))
	match str(e["op"]):
		"add": return "Add a %s in %s at %s" % [e["piece"]["type"], isl, str(e["piece"].get("at", []))]
		"remove": return "Remove %s in %s" % [e["target"], isl]
		_: return "Change %s in %s: %s" % [e["target"], isl, JSON.stringify(e.get("set", {}))]

# ---------- propose / approve / apply ----------
## A companion proposes an edit. Returns {id, state: "applied"|"pending", proposal?} or {error}.
static func propose(companion: String, edit: Dictionary, now := 0, note := "") -> Dictionary:
	if companion == "" or companion.length() > 64: return {"error": "Who is building?"}
	var v := validate(edit)
	if v.has("error"): return v
	var e: Dictionary = v["edit"]
	var pending := edits("pending").filter(func(x): return x["by"] == companion).size()
	if pending >= MAX_PENDING_PER: return {"error": "Too many changes waiting for approval."}
	if edits("applied").size() >= MAX_APPLIED: return {"error": "Heaven edit log is full (owner can compact it)."}
	_seq += 1
	e["id"] = "he_%d_%d_%d" % [now, Time.get_ticks_usec() % 1000000, _seq]
	e["by"] = companion
	e["at"] = now
	e["note"] = note.left(200)
	if e["op"] == "add": e["piece"]["id"] = "%s_%s_%s" % [e["island"], e["piece"]["type"], e["id"].trim_prefix("he_")]
	if HeavenAccess.granted("build", companion):   # standing grant held by THIS companion id
		e["state"] = "applied"; e["via"] = "standing_grant"
		_all()["edits"].append(e)
		if not _save(): _all()["edits"].pop_back(); return {"error": "Saves are sealed. Unlock first."}
		_bump(e["island"])
		return {"id": e["id"], "state": "applied", "edit": e}
	var prop := EveCore.for_companion(companion).propose_update("[heaven-edit %s] %s%s" % [e["id"], describe(e), (" (" + note.left(120) + ")") if note != "" else ""])
	e["state"] = "pending"; e["proposal"] = str(prop["id"])
	_all()["edits"].append(e)
	if not _save(): _all()["edits"].pop_back(); return {"error": "Saves are sealed. Unlock first."}
	return {"id": e["id"], "state": "pending", "proposal": prop["id"], "edit": e}

## "Direct a change": the unlocked owner tells a companion what to build. The instruction is the
## approval: the companion's proposal is logged and approved in one step, then applied.
static func owner_directs(companion: String, edit: Dictionary, now := 0, note := "") -> Dictionary:
	var r := propose(companion, edit, now, note if note != "" else "directed by the owner")
	if r.has("error") or r["state"] == "applied": return r
	if not HeavenAccess.is_owner(Tiers.SELF) or not EveCore.owner_ok():
		return r   # not an unlocked owner: stays pending for approval
	EveCore.decide(str(r["proposal"]), true)
	sync()
	var e := _edit(str(r["id"]))
	return {"id": r["id"], "state": str(e.get("state", "pending")), "proposal": r["proposal"], "edit": e}

static func _edit(id: String) -> Dictionary:
	for e in _all()["edits"]:
		if e["id"] == id: return e
	return {}

## Applies approved proposals and drops rejected ones. Returns the islands that changed.
static func sync() -> Array:
	var pend := edits("pending")
	if pend.is_empty(): return []
	var states := {}
	for p in EveCore.proposals(): states[str(p["id"])] = str(p["state"])
	var changed: Array = []
	var dirty := false
	for e in pend:
		var st := str(states.get(str(e.get("proposal", "")), "PendingApproval"))
		if st == "Approved":
			# re-validate against the CURRENT layout (another edit may have removed the target)
			var again := validate(e)
			if again.has("error"): e["state"] = "failed"; e["reason"] = again["error"]
			else:
				e["state"] = "applied"; e["via"] = "owner_approval"
				if not e["island"] in changed: changed.append(e["island"])
			dirty = true
		elif st == "Rejected":
			e["state"] = "rejected"; dirty = true
	if dirty and not _save(): _e = null; return []
	for i in changed: _bump(i)
	return changed

## Owner-only undo of an applied edit (kept in the log as "reverted", never deleted).
static func revert(actor: Variant, edit_id: String) -> String:
	if not HeavenAccess.is_owner(actor): return "Only the owner (unlocked) can undo Heaven edits."
	var e := _edit(edit_id)
	if e.is_empty() or e["state"] != "applied": return "Nothing to undo."
	e["state"] = "reverted"
	if not _save(): _e = null; return "Saves are sealed. Unlock first."
	_bump(e["island"])
	return ""

static func _bump(island_id: String) -> void: _rev[island_id] = revision(island_id) + 1

## HEAVEN-9: a companion takes back its OWN change (chat "undo that").
## - pending (waiting for the owner): withdrawn, so sync() never applies it; kept in the log.
## - applied: only when this companion holds the owner's standing build grant (it could have applied the
##   change without approval anyway). Otherwise the owner undoes it (Heaven > Direct a change > Undo).
## edit_id "" or "last" = this companion's newest pending or applied edit. Returns {id, state} or {error}.
static func companion_undo(companion: String, edit_id := "") -> Dictionary:
	var e := {}
	if edit_id == "" or edit_id == "last":
		for x in _all()["edits"]:
			if x["by"] == companion and x["state"] in ["pending", "applied"]: e = x
	else:
		e = _edit(edit_id)
	if e.is_empty() or e["by"] != companion or not e["state"] in ["pending", "applied"]:
		return {"error": "Nothing of mine to undo."}
	var was := str(e["state"])
	if was == "applied" and not HeavenAccess.granted("build", companion):
		return {"error": "That change is already approved. Only the owner can undo it (Heaven > Direct a change > Undo)."}
	e["state"] = "withdrawn" if was == "pending" else "reverted"
	e["undone_by"] = companion
	if not _save(): _e = null; return {"error": "Saves are sealed. Unlock first."}
	if was == "applied": _bump(e["island"])
	return {"id": e["id"], "state": e["state"], "edit": e}

## One plain line about a tool_call / companion_undo result, for chat (CHAT-16 canned follow-up).
static func status_line(r: Dictionary) -> String:
	if r.has("error"): return "I couldn't change Heaven: %s" % str(r["error"])
	var what := describe(r["edit"]) if r.get("edit") is Dictionary and not r["edit"].is_empty() else "the change"
	match str(r.get("state", "")):
		"applied": return "Done: %s." % what
		"pending": return "I asked the owner to approve: %s." % what
		"withdrawn": return "I took back my request: %s." % what
		"reverted": return "Undone: %s." % what
	return str(r.get("state", ""))

# ---------- companion build tool ----------
## Entry point for the companion tool registry. args per TOOL_SPEC (world coordinates).
## directed = true when the owner is directing this companion in person ("Direct a change").
static func tool_call(companion: String, args: Dictionary, now := 0, directed := false) -> Dictionary:
	var op := str(args.get("op", "add"))
	var wp := Vector3(float(args.get("x", 0.0)), float(args.get("y", HeavenLayout.walk_y(HeavenLayout.island("main_mall")))), float(args.get("z", 0.0)))
	var isl := HeavenLayout.island_at(wp)
	if isl.is_empty() and args.has("target"): isl = _island_of_piece(str(args["target"]))
	if isl.is_empty(): return {"error": "That spot is not on a Heaven island."}
	var local := HeavenLayout.frame(isl).affine_inverse() * wp
	var edit := {"island": isl["id"], "op": op}
	var fields := {}
	for k in ["yaw", "w", "d", "h", "r", "color", "trim", "text", "name", "n"]:
		if args.has(k): fields[k] = args[k]
	if op == "add":
		fields["type"] = str(args.get("type", ""))
		if args.has("shop"): fields["shop"] = args["shop"]
		fields["at"] = [local.x, local.z]
		edit["piece"] = fields
	else:
		edit["target"] = str(args.get("target", ""))
		if op == "set":
			if args.has("x") and args.has("z") and bool(args.get("move", false)): fields["at"] = [local.x, local.z]
			edit["set"] = fields
	if directed: return owner_directs(companion, edit, now, str(args.get("note", "")))
	return propose(companion, edit, now, str(args.get("note", "")))

static func _island_of_piece(piece_id: String) -> Dictionary:
	for i in HeavenLayout.islands():
		if piece_id.begins_with(str(i["id"]) + "_"): return i
	return {}

## Nearest piece to a local point on an island (for "point at a section").
static func nearest_piece(island_id: String, local: Vector2, max_dist := 25.0) -> Dictionary:
	var best := {}
	var bd := max_dist
	for p in pieces(island_id):
		var a: Array = p.get("at", [0, 0])
		var dd := local.distance_to(Vector2(float(a[0]), float(a[1])))
		if dd < bd: bd = dd; best = p
	return best

static func reset_for_tests(dir := "") -> void:
	if dir != "": root = dir
	_e = null; _base = {}; _rev = {}
