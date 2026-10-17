class_name Social
extends RefCounted
## Viper OS social layer (docs/modules/SOCIAL.md). Clean-room reimplementation of community-platform
## CONCEPTS (profiles, friends, mail, groups, feed, moderation) in our own GDScript. No Boonex/Dolphin
## code, assets, schema or PHP. LocalServices mode: one encrypted local store on the phone
## (SecureFile -> user://social/social.json). Grid mode (later) swaps the store for a grid service
## behind this same API.
##
## Every call that does something checks Tiers.can(actor, action, ...). Every result is a Dictionary
## {"ok": bool, "error": String, ...}. Blocks always apply (both directions). Companions are social
## members, but their public posts go to the owner approval queue (EveCore.propose_update) and are
## published only after the owner approves in MENU > Proposals; nothing goes out directly.
##
## Roadmap features are stubbed behind the same API and return {"ok": false, "error": "INACTIVE", ...}.

const MAX_TEXT := 2000
const MAX_MSG := 1000
const MAX_FEED := 500
const MAX_INBOX := 300
const MAX_PICKS := 10
const GROUP_ROLES := ["owner", "officer", "member"]
const PROPOSAL_TAG := "SOCIAL_POST "
const EXAMPLE_TAG := "[EXAMPLE]"

static var root := "user://social"
static var _db = null
static var _hooked := false

# ---------- store ----------
static func _path() -> String: return root.path_join("social.json")

static func db() -> Dictionary:
	if not _hooked:
		_hooked = true
		OwnerVault.on_storage_ready.append(reload_data)
	if _db == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_db = d if d is Dictionary else {}
		for k in ["profiles", "friends", "follows", "blocks", "inbox", "outbox", "groups", "feed", "notes", "reports"]:
			if not _db.has(k): _db[k] = [] if k in ["outbox", "feed", "reports"] else {}
		if not _db.has("seq"): _db["seq"] = 0
	return _db

static func reload_data() -> void: _db = null; Tiers.reload_roles()

static func _save() -> bool: return SecureFile.write_json(_path(), db())

static func _next(prefix: String) -> String:
	db()["seq"] = int(db()["seq"]) + 1
	return "%s%d" % [prefix, db()["seq"]]

static func _ok(extra := {}) -> Dictionary:
	var r := {"ok": true, "error": ""}; r.merge(extra); return r
static func _err(e: String) -> Dictionary: return {"ok": false, "error": e}
static func _now() -> int: return int(Time.get_unix_time_from_system())

## Plain text only: trims, caps length, neutralises BBCode so nothing renders as markup.
static func clean(text: String, cap := MAX_TEXT) -> String:
	return text.strip_edges().left(cap).replace("[", "(").replace("]", ")")

static func _id(actor: Variant) -> String: return Tiers.actor_id(actor)

static func _commit(rollback: Dictionary, result: Dictionary) -> Dictionary:
	if _save(): return result
	_db = rollback
	return _err("Saves are sealed. Unlock first.")

static func _snap() -> Dictionary: return db().duplicate(true)

# ---------- profiles (Second Life style: about, interests, picks) ----------
## Public view of a profile. viewer optional: blocked viewers get {} (as if it does not exist).
static func profile(id: String, viewer: Variant = null) -> Dictionary:
	var p: Dictionary = db()["profiles"].get(id, {})
	if p.is_empty(): return {}
	if viewer != null and is_blocked(_id(viewer), id): return {}
	var out := p.duplicate(true)
	out["tier"] = Tiers.assigned_tier(id)
	out["tier_label"] = Tiers.label(out["tier"])
	out["groups"] = groups_of(id)
	out["friends"] = friends_of(id).size()
	out["followers"] = followers_of(id).size()
	return out

## fields: display_name, about, interests (Array), avatar_ref, kind. Own profile only;
## the owner's profile and companions' profiles need the owner unlock.
static func set_profile(actor: Variant, id: String, fields: Dictionary) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "edit_profile", id): return _err("Not allowed.")
	if me != id and Tiers.tier_of(actor) != "owner": return _err("Not allowed.")
	var snap := _snap()
	var p: Dictionary = db()["profiles"].get(id, {"id": id, "display_name": id, "about": "", "interests": [], "picks": [], "created": _now(),
		"kind": "companion" if Tiers.is_bot(id) else "player"})
	if fields.has("display_name"):
		var n := clean(str(fields["display_name"]), 40)
		if n == "": return _err("Name can't be empty.")
		p["display_name"] = n
	if fields.has("about"): p["about"] = clean(str(fields["about"]), 1000)
	if fields.has("interests") and fields["interests"] is Array:
		p["interests"] = (fields["interests"] as Array).slice(0, 12).map(func(x): return clean(str(x), 32))
	if fields.has("avatar_ref"): p["avatar_ref"] = clean(str(fields["avatar_ref"]), 120)
	if fields.has("kind") and str(fields["kind"]) in ["player", "companion", "example"]: p["kind"] = str(fields["kind"])
	p["updated"] = _now()
	db()["profiles"][id] = p
	return _commit(snap, _ok({"profile": p.duplicate(true)}))

## Picks tab: {title, region, parcel?, note}. Max 10.
static func add_pick(actor: Variant, id: String, pick: Dictionary) -> Dictionary:
	if not db()["profiles"].has(id): return _err("No profile.")
	if not Tiers.can(actor, "edit_profile", id) or (_id(actor) != id and Tiers.tier_of(actor) != "owner"): return _err("Not allowed.")
	var picks: Array = db()["profiles"][id]["picks"]
	if picks.size() >= MAX_PICKS: return _err("Up to %d picks." % MAX_PICKS)
	var t := clean(str(pick.get("title", "")), 60)
	if t == "": return _err("A pick needs a title.")
	var snap := _snap()
	picks.append({"title": t, "region": clean(str(pick.get("region", "")), 60), "parcel": clean(str(pick.get("parcel", "")), 20), "note": clean(str(pick.get("note", "")), 280)})
	return _commit(snap, _ok({"picks": picks.duplicate(true)}))

static func remove_pick(actor: Variant, id: String, index: int) -> Dictionary:
	if not Tiers.can(actor, "edit_profile", id) or (_id(actor) != id and Tiers.tier_of(actor) != "owner"): return _err("Not allowed.")
	var picks: Array = db()["profiles"].get(id, {}).get("picks", [])
	if index < 0 or index >= picks.size(): return _err("No such pick.")
	var snap := _snap(); picks.remove_at(index)
	return _commit(snap, _ok())

# ---------- blocks ----------
static func is_blocked(a: String, b: String) -> bool:
	return b in db()["blocks"].get(a, []) or a in db()["blocks"].get(b, [])

static func block(actor: Variant, other: String) -> Dictionary:
	var me := _id(actor)
	if me == "" or other == "" or other == me: return _err("Can't block that.")
	var snap := _snap()
	var l: Array = db()["blocks"].get(me, [])
	if not other in l: l.append(other)
	db()["blocks"][me] = l
	_unfriend(me, other)
	db()["follows"][me] = db()["follows"].get(me, []).filter(func(x): return x != other)
	db()["follows"][other] = db()["follows"].get(other, []).filter(func(x): return x != me)
	return _commit(snap, _ok())   # blocking never needs a tier: safety first

static func unblock(actor: Variant, other: String) -> Dictionary:
	var me := _id(actor)
	var snap := _snap()
	db()["blocks"][me] = db()["blocks"].get(me, []).filter(func(x): return x != other)
	return _commit(snap, _ok())

# ---------- friends + followers ----------
static func _key(a: String, b: String) -> String: return a + "|" + b if a < b else b + "|" + a

static func _unfriend(a: String, b: String) -> void: db()["friends"].erase(_key(a, b))

static func friend_request(actor: Variant, to: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "friend"): return _err("Not allowed.")
	if to == me or to == "": return _err("Pick someone else.")
	if is_blocked(me, to): return _err("Not available.")
	var k := _key(me, to)
	var f: Dictionary = db()["friends"].get(k, {})
	if f.get("state") == "accepted": return _err("Already friends.")
	if f.get("state") == "pending" and f.get("from") == to: return friend_accept(actor, to)
	var snap := _snap()
	db()["friends"][k] = {"state": "pending", "from": me, "t": _now()}
	_note(to, "friend", "%s sent a friend request." % _name(me))
	return _commit(snap, _ok())

static func friend_accept(actor: Variant, from: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "friend"): return _err("Not allowed.")
	var k := _key(me, from)
	var f: Dictionary = db()["friends"].get(k, {})
	if f.get("state") != "pending" or f.get("from") != from: return _err("No request from them.")
	if is_blocked(me, from): return _err("Not available.")
	var snap := _snap()
	f["state"] = "accepted"; f["t"] = _now()
	_note(from, "friend", "%s accepted your friend request." % _name(me))
	return _commit(snap, _ok())

static func friend_remove(actor: Variant, other: String) -> Dictionary:
	var snap := _snap(); _unfriend(_id(actor), other)
	return _commit(snap, _ok())

static func friends_of(id: String) -> Array:
	var out: Array = []
	for k in db()["friends"]:
		var f: Dictionary = db()["friends"][k]
		var ab: PackedStringArray = k.split("|")
		if f["state"] == "accepted" and id in ab: out.append(ab[1] if ab[0] == id else ab[0])
	return out

static func friend_requests(id: String) -> Array:
	var out: Array = []
	for k in db()["friends"]:
		var f: Dictionary = db()["friends"][k]
		if f["state"] == "pending" and f["from"] != id and id in k.split("|"): out.append(f["from"])
	return out

static func follow(actor: Variant, target: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	if target == me or is_blocked(me, target): return _err("Not available.")
	var snap := _snap()
	var l: Array = db()["follows"].get(me, [])
	if not target in l: l.append(target)
	db()["follows"][me] = l
	return _commit(snap, _ok())

static func unfollow(actor: Variant, target: String) -> Dictionary:
	var me := _id(actor); var snap := _snap()
	db()["follows"][me] = db()["follows"].get(me, []).filter(func(x): return x != target)
	return _commit(snap, _ok())

static func followers_of(id: String) -> Array:
	var out: Array = []
	for who in db()["follows"]:
		if id in db()["follows"][who]: out.append(who)
	return out

# ---------- messages (local inbox + offline queue) ----------
## Delivered at once to a local member's inbox. Unknown recipients (other devices, grid later) wait
## in the offline outbox until flush_outbox() can deliver them.
static func send_message(actor: Variant, to: String, text: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "message"): return _err("Not allowed.")
	var body := clean(text, MAX_MSG)
	if body == "" or to == "" or to == me: return _err("Write a message and pick someone.")
	if is_blocked(me, to): return _err("Not available.")
	var snap := _snap()
	var m := {"id": _next("m"), "from": me, "to": to, "text": body, "t": _now(), "read": false}
	var state := "delivered"
	if db()["profiles"].has(to): _deliver(m)
	else:
		state = "queued"
		db()["outbox"].append(m)
		if db()["outbox"].size() > MAX_INBOX: db()["outbox"].pop_front()
	return _commit(snap, _ok({"id": m["id"], "state": state}))

static func _deliver(m: Dictionary) -> void:
	var box: Array = db()["inbox"].get(m["to"], [])
	box.append(m)
	if box.size() > MAX_INBOX: box.pop_front()
	db()["inbox"][m["to"]] = box
	_note(m["to"], "message", "New message from %s." % _name(m["from"]))

static func flush_outbox() -> int:
	var keep: Array = []; var n := 0
	for m in db()["outbox"]:
		if db()["profiles"].has(m["to"]) and not is_blocked(m["from"], m["to"]): _deliver(m); n += 1
		elif not is_blocked(m["from"], m["to"]): keep.append(m)
	db()["outbox"] = keep
	if n > 0: _save()
	return n

static func inbox(actor: Variant, unread_only := false) -> Array:
	var me := _id(actor)
	return db()["inbox"].get(me, []).filter(func(m): return not is_blocked(me, m["from"]) and (not unread_only or not m["read"])).duplicate(true)

static func outbox(actor: Variant) -> Array:
	var me := _id(actor)
	return db()["outbox"].filter(func(m): return m["from"] == me).duplicate(true)

static func mark_read(actor: Variant, msg_id: String) -> Dictionary:
	for m in db()["inbox"].get(_id(actor), []):
		if m["id"] == msg_id:
			var snap := _snap(); m["read"] = true
			return _commit(snap, _ok())
	return _err("No such message.")

# ---------- notifications ----------
static func _note(to: String, kind: String, text: String) -> void:
	var l: Array = db()["notes"].get(to, [])
	l.append({"t": _now(), "kind": kind, "text": clean(text, 200), "read": false})
	if l.size() > 100: l.pop_front()
	db()["notes"][to] = l

## Public notify hook (Foxy's toasts read notifications()). System/staff only.
static func notify(actor: Variant, to: String, kind: String, text: String) -> Dictionary:
	if not (Tiers.can(actor, "moderate") or _id(actor) == "system"): return _err("Not allowed.")
	var snap := _snap(); _note(to, kind, text)
	return _commit(snap, _ok())

static func notifications(actor: Variant, unread_only := true) -> Array:
	return db()["notes"].get(_id(actor), []).filter(func(n): return not unread_only or not n["read"]).duplicate(true)

static func notifications_clear(actor: Variant) -> Dictionary:
	var snap := _snap()
	for n in db()["notes"].get(_id(actor), []): n["read"] = true
	return _commit(snap, _ok())

# ---------- groups (roles, notices, land via Estate) ----------
static func group(gid: String) -> Dictionary: return db()["groups"].get(gid, {}).duplicate(true)

static func is_member(gid: String, id: String) -> bool:
	return db()["groups"].get(gid, {}).get("members", {}).has(id)

static func groups_of(id: String) -> Array:
	var out: Array = []
	for gid in db()["groups"]:
		var g: Dictionary = db()["groups"][gid]
		if g["members"].has(id): out.append({"id": gid, "name": g["name"], "role": g["members"][id], "tag": g.get("tag", "")})
	return out

static func all_groups() -> Array:
	var out: Array = []
	for gid in db()["groups"]: out.append(group(gid))
	return out

## opts: charter, tag (<= 8 chars, shown over avatars), open (anyone may join).
static func group_create(actor: Variant, name: String, opts := {}) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "group_create"): return _err("Creator tier or higher can create groups.")
	var n := clean(name, 48)
	if n == "": return _err("Name the group.")
	for gid in db()["groups"]:
		if str(db()["groups"][gid]["name"]).to_lower() == n.to_lower(): return _err("That name is taken.")
	var snap := _snap()
	var gid := _next("g")
	db()["groups"][gid] = {"id": gid, "name": n, "charter": clean(str(opts.get("charter", "")), 1000), "tag": clean(str(opts.get("tag", "")), 8),
		"open": bool(opts.get("open", true)), "founder": me, "members": {me: "owner"}, "notice": {}, "land": [], "created": _now()}
	return _commit(snap, _ok({"id": gid}))

static func group_join(actor: Variant, gid: String) -> Dictionary:
	var me := _id(actor)
	var g: Dictionary = db()["groups"].get(gid, {})
	if g.is_empty(): return _err("No such group.")
	if not Tiers.can(actor, "group_join"): return _err("Not allowed.")
	if is_blocked(me, str(g["founder"])): return _err("Not available.")
	if not g["open"] and not g.get("invites", []).has(me): return _err("Invite only.")
	var snap := _snap(); g["members"][me] = "member"
	g["invites"] = g.get("invites", []).filter(func(x): return x != me)
	return _commit(snap, _ok())

static func group_invite(actor: Variant, gid: String, who: String) -> Dictionary:
	if not _group_officer(actor, gid): return _err("Officers only.")
	var snap := _snap()
	var g: Dictionary = db()["groups"][gid]
	var inv: Array = g.get("invites", [])
	if not who in inv: inv.append(who)
	g["invites"] = inv
	_note(who, "group", "Invited to %s." % g["name"])
	return _commit(snap, _ok())

static func group_leave(actor: Variant, gid: String) -> Dictionary:
	var me := _id(actor)
	var g: Dictionary = db()["groups"].get(gid, {})
	if not g.get("members", {}).has(me): return _err("Not a member.")
	if g["members"][me] == "owner" and g["members"].values().count("owner") == 1 and g["members"].size() > 1: return _err("Hand ownership to someone first.")
	var snap := _snap(); g["members"].erase(me)
	return _commit(snap, _ok())

static func _group_officer(actor: Variant, gid: String) -> bool:
	var g: Dictionary = db()["groups"].get(gid, {})
	if g.is_empty(): return false
	if Tiers.can(actor, "moderate"): return true
	return str(g["members"].get(_id(actor), "")) in ["owner", "officer"]

## Group owners set any role; officers can only make members.
static func group_set_role(actor: Variant, gid: String, member: String, role: String) -> Dictionary:
	if not role in GROUP_ROLES: return _err("Unknown role.")
	if not _group_officer(actor, gid) or not is_member(gid, member): return _err("Not allowed.")
	var g: Dictionary = db()["groups"][gid]
	var my_role := str(g["members"].get(_id(actor), ""))
	if my_role != "owner" and not Tiers.can(actor, "moderate") and role != "member": return _err("Only the group owner can promote.")
	var snap := _snap(); g["members"][member] = role
	return _commit(snap, _ok())

static func group_notice(actor: Variant, gid: String, text: String) -> Dictionary:
	if not _group_officer(actor, gid): return _err("Officers only.")
	var body := clean(text, 1000)
	if body == "": return _err("Write a notice.")
	var snap := _snap()
	var g: Dictionary = db()["groups"][gid]
	g["notice"] = {"text": body, "by": _id(actor), "t": _now()}
	for m in g["members"]:
		if m != _id(actor): _note(m, "group", "%s: new notice." % g["name"])
	return _commit(snap, _ok())

## Group-owned land: the parcel becomes group_only and the group's members may enter (and build when
## terraform is "group"). Owner or estate manager only (Tiers "land" on that parcel).
static func group_claim_land(actor: Variant, gid: String, region: String, parcel: String, terraform := "group") -> Dictionary:
	if not db()["groups"].has(gid): return _err("No such group.")
	if not Tiers.can(actor, "land", {"region": region, "parcel": parcel}): return _err("Owner or estate manager only.")
	if not terraform in Estate.TERRAFORM: return _err("Unknown build rule.")
	var snap := _snap()
	var g: Dictionary = db()["groups"][gid]
	var key := region + "/" + parcel
	if not key in g["land"]: g["land"].append(key)
	var res := _commit(snap, _ok({"land": key}))
	if res["ok"]:
		Estate.parcel_set(region, parcel, "group", gid)
		Estate.parcel_set(region, parcel, "access", "group_only")
		Estate.parcel_set(region, parcel, "terraform", terraform)
	return res

# ---------- activity feed ----------
## opts: visibility "public" | "friends" | "group:<gid>", kind (status|snapshot|build), media_ref.
## Companions: the post waits in the owner approval queue (EveCore.propose_update) as
## state "pending_approval"; it publishes only once the owner approves in MENU > Proposals.
static func post(actor: Variant, text: String, opts := {}) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "post"): return _err("Residents and up can post.")
	var body := clean(text)
	if body == "": return _err("Write something.")
	var vis := str(opts.get("visibility", "public"))
	if not (vis in ["public", "friends"] or (vis.begins_with("group:") and is_member(vis.substr(6), me))): return _err("Pick who can see it.")
	var snap := _snap()
	var p := {"id": _next("p"), "author": me, "text": body, "t": _now(), "visibility": vis,
		"kind": clean(str(opts.get("kind", "status")), 16), "media_ref": clean(str(opts.get("media_ref", "")), 200), "state": "published"}
	if Tiers.is_bot(me):
		p["state"] = "pending_approval"
		p["proposal_id"] = EveCore.for_companion(me).propose_update(PROPOSAL_TAG + p["id"] + ": " + body.left(280))["id"]
	db()["feed"].append(p)
	if db()["feed"].size() > MAX_FEED: db()["feed"].pop_front()
	return _commit(snap, _ok({"id": p["id"], "state": p["state"]}))

## Publish / reject companion posts after the owner's decision in MENU > Proposals.
static func sync_approvals() -> int:
	var states := {}
	for pr in EveCore.proposals(): states[pr["id"]] = pr["state"]
	var n := 0
	for p in db()["feed"]:
		if p["state"] == "pending_approval" and states.has(p.get("proposal_id", "")):
			match states[p["proposal_id"]]:
				"Approved": p["state"] = "published"; n += 1
				"Rejected": p["state"] = "rejected"; n += 1
	if n > 0: _save()
	return n

static func _visible(p: Dictionary, viewer: String) -> bool:
	if p["state"] != "published" or is_blocked(viewer, p["author"]): return false
	var v := str(p["visibility"])
	if v == "public" or p["author"] == viewer: return true
	if v == "friends": return viewer in friends_of(p["author"])
	if v.begins_with("group:"): return is_member(v.substr(6), viewer)
	return false

## Newest first. Guests see public posts only.
static func feed(viewer: Variant, limit := 20, author := "") -> Array:
	if not Tiers.can(viewer, "browse"): return []
	sync_approvals()
	var me := _id(viewer)
	var out: Array = []
	for i in range(db()["feed"].size() - 1, -1, -1):
		var p: Dictionary = db()["feed"][i]
		if (author == "" or p["author"] == author) and _visible(p, me): out.append(p.duplicate())
		if out.size() >= limit: break
	return out

static func pending_posts() -> Array:
	return db()["feed"].filter(func(p): return p["state"] == "pending_approval").duplicate(true)

static func delete_post(actor: Variant, pid: String) -> Dictionary:
	for p in db()["feed"]:
		if p["id"] == pid:
			if p["author"] != _id(actor) and not Tiers.can(actor, "moderate"): return _err("Not allowed.")
			var snap := _snap(); p["state"] = "deleted"
			return _commit(snap, _ok())
	return _err("No such post.")

# ---------- reports + moderation queue ----------
## kind: post | profile | message | group. Anyone (even guests) can report.
static func report(actor: Variant, kind: String, target_id: String, reason: String) -> Dictionary:
	if not Tiers.can(actor, "report"): return _err("Not allowed.")
	if not kind in ["post", "profile", "message", "group"] or target_id == "": return _err("Pick what to report.")
	var snap := _snap()
	var r := {"id": _next("r"), "reporter": _id(actor), "kind": kind, "target": target_id, "reason": clean(reason, 500), "state": "open", "t": _now()}
	db()["reports"].append(r)
	return _commit(snap, _ok({"id": r["id"]}))

## Moderators only (staff, estate managers, unlocked owner).
static func reports(actor: Variant, state := "open") -> Array:
	if not Tiers.can(actor, "moderate"): return []
	return db()["reports"].filter(func(r): return state == "" or r["state"] == state).duplicate(true)

## decision: "hide" (hides the reported post / clears the profile about), "dismiss".
static func moderate(actor: Variant, report_id: String, decision: String) -> Dictionary:
	if not Tiers.can(actor, "moderate"): return _err("Moderators only.")
	if not decision in ["hide", "dismiss"]: return _err("Unknown decision.")
	for r in db()["reports"]:
		if r["id"] == report_id and r["state"] == "open":
			var snap := _snap()
			if decision == "hide":
				if r["kind"] == "post":
					for p in db()["feed"]:
						if p["id"] == r["target"]: p["state"] = "hidden"
				elif r["kind"] == "profile" and db()["profiles"].has(r["target"]):
					if r["target"] == Tiers.OWNER_ID and Tiers.tier_of(actor) != "owner": return _err("Only the owner can change the owner profile.")
					db()["profiles"][r["target"]]["about"] = ""
			r["state"] = "actioned" if decision == "hide" else "dismissed"
			r["by"] = _id(actor); r["decided"] = _now()
			return _commit(snap, _ok())
	return _err("No open report with that id.")

# ---------- membership hooks ----------
static func membership_of(id: String) -> Dictionary:
	var t := Tiers.assigned_tier(id)
	var m := Tiers.membership(t).duplicate()
	m["tier"] = t; m["label"] = Tiers.label(t)
	return m

static func stats() -> Dictionary:
	var pub := 0
	for p in db()["feed"]:
		if p["state"] == "published": pub += 1
	return {"members": db()["profiles"].size(), "groups": db()["groups"].size(), "posts": pub,
		"pending_posts": pending_posts().size(), "open_reports": db()["reports"].filter(func(r): return r["state"] == "open").size(),
		"queued_messages": db()["outbox"].size()}

static func _name(id: String) -> String: return str(db()["profiles"].get(id, {}).get("display_name", id))

# ---------- example data (clearly labelled, owner action only, no real people) ----------
static func seed_examples(actor: Variant) -> Dictionary:
	if Tiers.tier_of(actor) != "owner": return _err("Owner unlock needed.")
	var snap := _snap()
	for e in [["example_resident", "Example Resident"], ["example_creator", "Example Creator"]]:
		db()["profiles"][e[0]] = {"id": e[0], "display_name": EXAMPLE_TAG + " " + e[1], "about": "Example data for testing. Not a real person.",
			"interests": ["building"], "picks": [{"title": "Welcome Island", "region": "welcome", "parcel": "", "note": "Example pick."}], "created": _now(), "kind": "example"}
	return _commit(snap, _ok())

static func clear_examples(actor: Variant) -> Dictionary:
	if Tiers.tier_of(actor) != "owner": return _err("Owner unlock needed.")
	var snap := _snap()
	for id in db()["profiles"].keys():
		if db()["profiles"][id].get("kind") == "example": db()["profiles"].erase(id)
	return _commit(snap, _ok())

# ---------- ROADMAP stubs (INACTIVE) ----------
## INACTIVE: each stub checks the tier first (so callers learn the rule now) and then returns
## {"ok": false, "error": "INACTIVE", "roadmap": "..."}. See docs/modules/SOCIAL.md "Roadmap".
static func _inactive(actor: Variant, action: String, what: String) -> Dictionary:
	if not Tiers.can(actor, action): return _err("Not allowed.")
	return {"ok": false, "error": "INACTIVE", "roadmap": what}

static func forum_post(actor: Variant, _forum: String, _title: String, _text: String) -> Dictionary: return _inactive(actor, "forum_post", "Forums: topics + replies, moderation queue (Phase 2).")
static func blog_post(actor: Variant, _title: String, _text: String) -> Dictionary: return _inactive(actor, "blog_post", "Blogs on profiles (Phase 2).")
static func album_add(actor: Variant, _album: String, _media_ref: String) -> Dictionary: return _inactive(actor, "album", "Photo/video albums incl. in-world snapshots (Phase 2; needs media storage + upload review).")
static func event_create(actor: Variant, _title: String, _when_unix: int, _where: String) -> Dictionary: return _inactive(actor, "event_create", "Events, merged with the events board (Phase 2).")
static func event_rsvp(actor: Variant, _event_id: String) -> Dictionary: return _inactive(actor, "event_rsvp", "Event RSVPs (Phase 2).")
static func poll_create(actor: Variant, _question: String, _options: Array) -> Dictionary: return _inactive(actor, "poll_create", "Polls (Phase 2).")
static func poll_vote(actor: Variant, _poll_id: String, _option: int) -> Dictionary: return _inactive(actor, "poll_vote", "Poll voting (Phase 2).")
static func classified_post(actor: Variant, _title: String, _text: String, _slot: String) -> Dictionary: return _inactive(actor, "classified", "Classifieds tied to ad slots; Aethel Coin pricing needs LEGAL REVIEW (Phase 3).")

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _db = null
