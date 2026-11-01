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
##
## 2026-10-17 social-media parity (SMP-*, docs/modules/SOCIAL_MEDIA_PARITY.md): post kinds (photo,
## clip, story, repost), threads/replies, quotes, reposts, reactions, bookmarks, hashtags + mentions,
## polls, scheduled posts, drafts, lists, pages, events, ranked + paged feeds (Social.feed(viewer,
## cursor)), stories with 24 h expiry + highlights + close friends, ghost posts, sounds/remix/duet/
## stitch as data, search/explore/trending, badges (internal), privacy (account, mute, restrict,
## hidden words, follow requests), age gating for mature content, context notes, creator analytics,
## auto-hold + grouped moderation queue. DMs live in SocialDM (social_dm.gd), media in MediaTools.
## Concepts only: no code, assets or trademarks from any of those platforms.

const MAX_TEXT := 2000
const MAX_MSG := 1000
const MAX_FEED := 1000
const MAX_INBOX := 300
const MAX_PICKS := 10
const GROUP_ROLES := ["owner", "officer", "member"]
const KINDS := ["status", "snapshot", "build", "photo", "clip", "story", "repost"]
const REACTIONS := ["like", "love", "laugh", "wow", "sad", "angry", "support"]
const STORY_TTL := 86400          # stories + ghost posts: 24 h, then archive (author only)
const EDIT_WINDOW := 3600         # posts can be edited for 1 h, history kept
const MAX_EDITS := 5
const MAX_MEDIA := 10             # carousel / multi-image
const MAX_LAYERS := 20            # sticker / text overlay layers (data only; Foxy renders)
const MAX_CLIP_S := 600
const MAX_STITCH_S := 5
const REPLY_POLICIES := ["everyone", "following", "mentioned", "nobody"]
const POLL_MIN := 2
const POLL_MAX := 4
const POLL_MAX_H := 168
const SCHEDULE_MAX_DAYS := 90
const MAX_DRAFTS := 50
const REPORT_HOLD := 3            # distinct open reports that auto-hold a post for review
const REPORT_KINDS := ["post", "profile", "message", "group", "story", "clip", "reply", "event", "page", "dm"]
const BADGES := ["verified", "official", "staff", "creator", "companion"]   # internal, owner-granted, never sold
const FEED_MODES := ["for_you", "following", "latest", "explore", "clips"]
const FEED_PREFIX_MODES := ["list:", "tag:", "author:", "group:", "sound:"]
const RANKED_MODES := ["for_you", "explore", "clips"]
const HALF_LIFE_H := 6.0
const PRIVACY_DEFAULTS := {"account": "public", "dm": "everyone", "mentions": "everyone", "story_replies": "everyone",
	"read_receipts": true, "show_activity": true}
const PRIVACY_CHOICES := {"account": ["public", "friends", "private"], "dm": ["everyone", "following", "friends", "nobody"],
	"mentions": ["everyone", "following", "nobody"], "story_replies": ["everyone", "following", "off"]}
const EVENT_RSVP := ["going", "interested", "declined"]
const EVENT_TAG := "SOCIAL_EVENT "
const PROPOSAL_TAG := "SOCIAL_POST "
const EXAMPLE_TAG := "[EXAMPLE]"

static var root := "user://social"
static var _db = null
static var _hooked := false
static var now_override := -1          # tests: fixed clock (unix seconds)
static var age_override = null         # tests: {id: bool} forces age_ok() for those ids
static var report_hooks: Array = []    # Callables called with each new report Dictionary (admin badges, toasts)
static var notify_listeners: Array = []   # Callables(batch: {member_id: [notes]}): one call per saved action, no polling
static var data_mode_override := ""    # tests: "full" | "normal" | "saver" (else Net.mode)
static var _batch := {}

# ---------- store ----------
static func _path() -> String: return root.path_join("social.json")

static func db() -> Dictionary:
	if not _hooked:
		_hooked = true
		OwnerVault.on_storage_ready.append(reload_data)
	if _db == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_db = d if d is Dictionary else {}
		for k in ["profiles", "friends", "follows", "blocks", "inbox", "outbox", "groups", "feed", "notes", "reports",
				"bookmarks", "drafts", "lists", "pages", "events", "mutes", "restricts", "close_friends", "privacy",
				"hidden_words", "feed_prefs", "follow_t", "follow_requests", "highlights", "sounds", "notify_prefs",
				"context_notes", "modlog"]:
			if not _db.has(k): _db[k] = [] if k in ["outbox", "feed", "reports", "modlog"] else {}
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
static func _now() -> int: return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())

## Plain text only: trims, caps length, neutralises BBCode so nothing renders as markup.
static func clean(text: String, cap := MAX_TEXT) -> String:
	return text.strip_edges().left(cap).replace("[", "(").replace("]", ")")

static func _id(actor: Variant) -> String: return Tiers.actor_id(actor)

static func _commit(rollback: Dictionary, result: Dictionary) -> Dictionary:
	if _save():
		flush_notify_batch()
		return result
	_db = rollback
	_batch.clear()
	return _err("Saves are sealed. Unlock first.")

## Notifications are pushed in batches: everything one action caused goes out in ONE call to each
## listener after it is saved (Foxy's toasts / badge counts subscribe here instead of polling).
## Returns how many members were in the batch.
static func flush_notify_batch() -> int:
	if _batch.is_empty(): return 0
	var b := _batch.duplicate(true)
	_batch.clear()
	for l in notify_listeners:
		if l is Callable and (l as Callable).is_valid(): (l as Callable).call(b)
	return b.size()

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

## Private accounts: the follow becomes a request the target approves (follow_approve). Returns
## {ok, state: "following" | "requested"}. Pages ("page:N") can be followed like members.
static func follow(actor: Variant, target: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	if target == "" or target == me or is_blocked(me, target): return _err("Not available.")
	if is_following(me, target): return _ok({"state": "following"})
	var snap := _snap()
	if privacy_of(target)["account"] == "private" and not me in friends_of(target):
		var rq: Array = db()["follow_requests"].get(target, [])
		if not me in rq: rq.append(me)
		db()["follow_requests"][target] = rq
		_note(target, "follow_request", "%s asked to follow you." % _name(me), me)
		return _commit(snap, _ok({"state": "requested"}))
	_add_follow(me, target)
	_note(target, "follow", "%s followed you." % _name(me), me)
	return _commit(snap, _ok({"state": "following"}))

static func _add_follow(me: String, target: String) -> void:
	var l: Array = db()["follows"].get(me, [])
	if not target in l: l.append(target)
	db()["follows"][me] = l
	db()["follow_t"][me + ">" + target] = _now()

static func is_following(a: String, b: String) -> bool: return b in db()["follows"].get(a, [])

static func follow_requests(actor: Variant) -> Array: return db()["follow_requests"].get(_id(actor), []).duplicate()

static func follow_approve(actor: Variant, who: String, yes := true) -> Dictionary:
	var me := _id(actor)
	var rq: Array = db()["follow_requests"].get(me, [])
	if not who in rq: return _err("No request from them.")
	var snap := _snap()
	rq.erase(who)
	if yes and not is_blocked(me, who):
		_add_follow(who, me)
		_note(who, "follow", "%s approved your follow request." % _name(me), me)
	return _commit(snap, _ok())

static func unfollow(actor: Variant, target: String) -> Dictionary:
	var me := _id(actor); var snap := _snap()
	db()["follows"][me] = db()["follows"].get(me, []).filter(func(x): return x != target)
	db()["follow_t"].erase(me + ">" + target)
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
## from: who caused it. Skipped when the recipient muted or blocked them, or turned that kind off.
## Notifications for a page go to the page owner.
static func _note(to: String, kind: String, text: String, from := "") -> void:
	if to.begins_with("page:"): to = str(db()["pages"].get(to, {}).get("owner", ""))
	if to == "" or to == from: return
	if from != "" and (is_blocked(to, from) or is_muted(to, from)): return
	if db()["notify_prefs"].get(to, {}).get(kind, true) == false: return
	var l: Array = db()["notes"].get(to, [])
	var n := {"t": _now(), "kind": kind, "text": clean(text, 200), "read": false, "from": from}
	l.append(n)
	var bl: Array = _batch.get(to, []); bl.append(n.duplicate()); _batch[to] = bl
	if l.size() > 100: l.pop_front()
	db()["notes"][to] = l

## Public notify hook (Foxy's toasts read notifications()). System/staff only.
static func notify(actor: Variant, to: String, kind: String, text: String) -> Dictionary:
	if not (Tiers.can(actor, "moderate") or _id(actor) == "system"): return _err("Not allowed.")
	var snap := _snap(); _note(to, kind, text)
	return _commit(snap, _ok())

static func notifications(actor: Variant, unread_only := true) -> Array:
	return db()["notes"].get(_id(actor), []).filter(func(n): return not unread_only or not n["read"]).duplicate(true)

## prefs: {kind: bool}, e.g. {"like": false}. Kinds: friend, follow, follow_request, message, group,
## mention, reply, quote, repost, like, poll, event, story, remix, moderation.
static func set_notify_prefs(actor: Variant, prefs: Dictionary) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	var snap := _snap()
	var cur: Dictionary = db()["notify_prefs"].get(me, {})
	for k in prefs: cur[clean(str(k), 24)] = bool(prefs[k])
	db()["notify_prefs"][me] = cur
	return _commit(snap, _ok())

## Unread notifications grouped by kind ("3 people reacted"): [{kind, count, from: [ids <= 5], latest}].
## For one badge refresh instead of walking the whole list.
static func notifications_grouped(actor: Variant) -> Array:
	var g := {}
	for n in notifications(actor, true):
		var k := str(n["kind"])
		if not g.has(k): g[k] = {"kind": k, "count": 0, "from": [], "latest": 0, "text": ""}
		g[k]["count"] += 1
		if str(n.get("from", "")) != "" and not n["from"] in g[k]["from"] and g[k]["from"].size() < 5: g[k]["from"].append(n["from"])
		if int(n["t"]) >= int(g[k]["latest"]): g[k]["latest"] = int(n["t"]); g[k]["text"] = n["text"]
	var out: Array = g.values()
	out.sort_custom(func(a, b): return a["latest"] > b["latest"])
	return out

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

## opts: charter, tag (<= 8 chars, shown over avatars), open (anyone may join), rules (Array, <= 10),
## mature (members must pass age_ok; only age-verified creators can make one).
static func group_create(actor: Variant, name: String, opts := {}) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "group_create"): return _err("Creator tier or higher can create groups.")
	var n := clean(name, 48)
	if n == "": return _err("Name the group.")
	for gid in db()["groups"]:
		if str(db()["groups"][gid]["name"]).to_lower() == n.to_lower(): return _err("That name is taken.")
	var mature := bool(opts.get("mature", false))
	if mature and not age_ok(me): return _err("Mature groups need an age-verified creator.")
	var snap := _snap()
	var gid := _next("g")
	db()["groups"][gid] = {"id": gid, "name": n, "charter": clean(str(opts.get("charter", "")), 1000), "tag": clean(str(opts.get("tag", "")), 8),
		"open": bool(opts.get("open", true)), "founder": me, "members": {me: "owner"}, "notice": {}, "land": [], "created": _now(),
		"rules": _clean_list(opts.get("rules", []), 10, 280), "mature": mature, "requests": []}
	return _commit(snap, _ok({"id": gid}))

static func group_join(actor: Variant, gid: String) -> Dictionary:
	var me := _id(actor)
	var g: Dictionary = db()["groups"].get(gid, {})
	if g.is_empty(): return _err("No such group.")
	if not Tiers.can(actor, "group_join"): return _err("Not allowed.")
	if is_blocked(me, str(g["founder"])): return _err("Not available.")
	if bool(g.get("mature", false)) and not age_ok(me): return _err("Age-restricted group.")
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

## Group rules (<= 10 lines) and join requests for invite-only groups (officers approve).
static func group_set_rules(actor: Variant, gid: String, rules: Array) -> Dictionary:
	if not _group_officer(actor, gid): return _err("Officers only.")
	var snap := _snap()
	db()["groups"][gid]["rules"] = _clean_list(rules, 10, 280)
	return _commit(snap, _ok())

static func group_request_join(actor: Variant, gid: String) -> Dictionary:
	var me := _id(actor)
	var g: Dictionary = db()["groups"].get(gid, {})
	if g.is_empty(): return _err("No such group.")
	if not Tiers.can(actor, "group_join"): return _err("Not allowed.")
	if is_blocked(me, str(g["founder"])) or g["members"].has(me): return _err("Not available.")
	if bool(g.get("mature", false)) and not age_ok(me): return _err("Age-restricted group.")
	var snap := _snap()
	var rq: Array = g.get("requests", [])
	if not me in rq: rq.append(me)
	g["requests"] = rq
	for m in g["members"]:
		if str(g["members"][m]) in ["owner", "officer"]: _note(m, "group", "%s asked to join %s." % [_name(me), g["name"]], me)
	return _commit(snap, _ok({"state": "requested"}))

static func group_approve(actor: Variant, gid: String, who: String, yes := true) -> Dictionary:
	if not _group_officer(actor, gid): return _err("Officers only.")
	var g: Dictionary = db()["groups"][gid]
	var rq: Array = g.get("requests", [])
	if not who in rq: return _err("No request from them.")
	var snap := _snap()
	rq.erase(who)
	if yes: g["members"][who] = "member"; _note(who, "group", "Welcome to %s." % g["name"])
	return _commit(snap, _ok())

## Officers remove a post from their group (logged in the mod log).
static func group_remove_post(actor: Variant, gid: String, pid: String) -> Dictionary:
	if not _group_officer(actor, gid): return _err("Officers only.")
	var p := _find(pid)
	if p.is_empty() or str(p.get("visibility", "")) != "group:" + gid: return _err("Not a post in this group.")
	var snap := _snap()
	p["state"] = "hidden"
	_log(actor, "group_remove_post", pid)
	return _commit(snap, _ok())

static func _clean_list(v: Variant, n: int, cap: int) -> Array:
	var out: Array = []
	if v is Array:
		for x in (v as Array).slice(0, n):
			var c := clean(str(x), cap)
			if c != "": out.append(c)
	return out

# ---------- age gating (mature content) ----------
## True when this viewer may see mature content:
## - the unlocked owner: yes; guests, locked owner, companions/bots: never;
## - this device's non-owner player ("self" -> "local"): Settings.mature_enabled() (self-confirmed age +
##   the mature toggle, same check the wardrobe uses);
## - other members: owner-set age_verified AND their own mature opt-in on the profile.
## RLV-style Restrictions adult flag: see _restrictions_adult().
static func age_ok(viewer: Variant) -> bool:
	var id := _id(viewer)
	if id == "": return false
	if age_override is Dictionary and age_override.has(id): return bool(age_override[id])
	var t := Tiers.tier_of(id)
	if t == "owner": return true
	if t == "guest" or Tiers.is_bot(id): return false
	if id == "local": return _settings_mature() or (_restrictions_adult(id) and bool(db()["profiles"].get(id, {}).get("mature_opt_in", false)))
	var p: Dictionary = db()["profiles"].get(id, {})
	return bool(p.get("age_verified", false)) and bool(p.get("mature_opt_in", false))

## The RLV-style Restrictions module (scripts/security/restrictions.gd, on main) stores a SELF-confirmed
## adult flag. Accepted only for this device's own player (plus their mature opt-in); other members
## always need the owner's age_verified.
static func _restrictions_adult(id: String) -> bool:
	return bool(Restrictions.db()["subjects"].get(id, {}).get("adult", false))

static func _settings_mature() -> bool:
	var ml := Engine.get_main_loop()
	var s: Node = ml.root.get_node_or_null("Settings") if ml is SceneTree else null
	return s != null and s.has_method("mature_enabled") and bool(s.mature_enabled())

## Owner only (unlocked).
static func set_age_verified(actor: Variant, id: String, on: bool) -> Dictionary:
	if Tiers.tier_of(actor) != "owner": return _err("Owner unlock needed.")
	if not db()["profiles"].has(id): return _err("No profile.")
	var snap := _snap()
	db()["profiles"][id]["age_verified"] = on
	_log(actor, "age_verified" if on else "age_unverified", id)
	return _commit(snap, _ok())

## Members opt in to seeing mature content themselves (still needs age_verified).
static func set_mature_opt_in(actor: Variant, on: bool) -> Dictionary:
	var me := _id(actor)
	if not db()["profiles"].has(me) or not Tiers.can(actor, "edit_profile", me): return _err("Not allowed.")
	var snap := _snap()
	db()["profiles"][me]["mature_opt_in"] = on
	return _commit(snap, _ok())

# ---------- badges (internal only) ----------
## Badges are granted by the unlocked owner only. Never sold, never tied to a subscription.
static func set_badge(actor: Variant, id: String, badge: String, on := true) -> Dictionary:
	if Tiers.tier_of(actor) != "owner": return _err("Owner unlock needed.")
	if not badge in BADGES: return _err("Unknown badge.")
	var rec: Dictionary = db()["pages"].get(id, {}) if id.begins_with("page:") else db()["profiles"].get(id, {})
	if rec.is_empty(): return _err("No such profile or page.")
	var snap := _snap()
	var b: Array = rec.get("badges", [])
	if on and not badge in b: b.append(badge)
	if not on: b.erase(badge)
	rec["badges"] = b
	_log(actor, "badge_" + ("add_" if on else "remove_") + badge, id)
	return _commit(snap, _ok())

static func badges_of(id: String) -> Array:
	var rec: Dictionary = db()["pages"].get(id, {}) if id.begins_with("page:") else db()["profiles"].get(id, {})
	var b: Array = rec.get("badges", []).duplicate()
	if Tiers.is_bot(id) and not "companion" in b: b.append("companion")
	return b

# ---------- privacy: account, mute, restrict, close friends, hidden words ----------
static func privacy_of(id: String) -> Dictionary:
	var out := PRIVACY_DEFAULTS.duplicate()
	out.merge(db()["privacy"].get(id, {}), true)
	return out

## fields: account (public|friends|private), dm (everyone|following|friends|nobody),
## mentions (everyone|following|nobody), story_replies (everyone|following|off), read_receipts, show_activity.
static func set_privacy(actor: Variant, fields: Dictionary) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "edit_profile", me): return _err("Not allowed.")
	var cur: Dictionary = db()["privacy"].get(me, {}).duplicate()
	for k in fields:
		if PRIVACY_CHOICES.has(k):
			if not str(fields[k]) in PRIVACY_CHOICES[k]: return _err("Unknown choice for %s." % k)
			cur[k] = str(fields[k])
		elif k in ["read_receipts", "show_activity"]: cur[k] = bool(fields[k])
		else: return _err("Unknown setting %s." % k)
	var snap := _snap()
	db()["privacy"][me] = cur
	return _commit(snap, _ok({"privacy": privacy_of(me)}))

## action "": no tier needed (mute / restrict are safety tools, like block).
static func _list_toggle(table: String, actor: Variant, other: String, on: bool, action := "") -> Dictionary:
	var me := _id(actor)
	if me == "" or other == "" or other == me: return _err("Pick someone else.")
	if action != "" and not Tiers.can(actor, action): return _err("Not allowed.")
	var snap := _snap()
	var l: Array = db()[table].get(me, [])
	if on and not other in l: l.append(other)
	if not on: l.erase(other)
	db()[table][me] = l
	return _commit(snap, _ok())

## Mute: you stop seeing them (feeds, stories, notifications). They are not told.
static func mute(actor: Variant, other: String) -> Dictionary: return _list_toggle("mutes", actor, other, true)
static func unmute(actor: Variant, other: String) -> Dictionary: return _list_toggle("mutes", actor, other, false)
static func is_muted(a: String, b: String) -> bool: return b in db()["mutes"].get(a, [])
## Restrict: their replies on your posts are visible only to them and you; their DMs land in requests;
## they don't see your read receipts. They are not told.
static func restrict(actor: Variant, other: String) -> Dictionary: return _list_toggle("restricts", actor, other, true)
static func unrestrict(actor: Variant, other: String) -> Dictionary: return _list_toggle("restricts", actor, other, false)
static func is_restricted(a: String, b: String) -> bool: return b in db()["restricts"].get(a, [])
## Close friends: audience for close_friends stories and posts.
static func close_friends_add(actor: Variant, other: String) -> Dictionary: return _list_toggle("close_friends", actor, other, true, "follow")
static func close_friends_remove(actor: Variant, other: String) -> Dictionary: return _list_toggle("close_friends", actor, other, false, "follow")
static func close_friends(actor: Variant) -> Array: return db()["close_friends"].get(_id(actor), []).duplicate()

## Hidden words (<= 200): replies on your posts, mentions and DM requests containing them are filtered
## out for you; posts containing them are left out of your feeds.
static func set_hidden_words(actor: Variant, words: Array) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	var snap := _snap()
	db()["hidden_words"][me] = _clean_list(words, 200, 40).map(func(w): return str(w).to_lower())
	return _commit(snap, _ok())

static func hidden_words(actor: Variant) -> Array: return db()["hidden_words"].get(_id(actor), []).duplicate()

static func hidden_word_hit(owner_id: String, text: String) -> bool:
	var l := text.to_lower()
	for w in db()["hidden_words"].get(owner_id, []):
		if str(w) != "" and l.contains(str(w)): return true
	return false

## Feed controls: show more / less of a hashtag topic for 1, 3 or 7 days (0 = until removed).
static func set_feed_pref(actor: Variant, tag: String, more: bool, days := 7) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	if not days in [0, 1, 3, 7]: return _err("Pick 1, 3 or 7 days.")
	var t := _norm_tag(tag)
	if t == "": return _err("Pick a topic.")
	var snap := _snap()
	var cur: Dictionary = db()["feed_prefs"].get(me, {})
	cur[t] = {"w": 1 if more else -1, "until": 0 if days == 0 else _now() + days * 86400}
	db()["feed_prefs"][me] = cur
	return _commit(snap, _ok())

static func clear_feed_pref(actor: Variant, tag: String) -> Dictionary:
	var snap := _snap()
	db()["feed_prefs"].get(_id(actor), {}).erase(_norm_tag(tag))
	return _commit(snap, _ok())

static func _account_ok(author: String, viewer: String) -> bool:
	if author == viewer or author.begins_with("page:"): return true
	match str(privacy_of(author)["account"]):
		"friends": return viewer in friends_of(author)
		"private": return is_following(viewer, author) or viewer in friends_of(author)
	return true

# ---------- posts: status, photo, clip, story, replies, quotes, polls, scheduling ----------
static var _re_tag: RegEx = null
static var _re_mention: RegEx = null

static var _re_word: RegEx = null

static func _norm_tag(t: String) -> String:
	var s := t.strip_edges().trim_prefix("#").to_lower().left(50)
	if _re_tag == null: _regex()
	return s if _re_word.search(s) != null else ""

static func _regex() -> void:
	_re_word = RegEx.new(); _re_word.compile("^\\w{1,50}$")
	_re_tag = RegEx.new(); _re_tag.compile("#(\\w{1,50})")
	_re_mention = RegEx.new(); _re_mention.compile("@([A-Za-z0-9_.:\\-]{1,40})")

static func parse_tags(text: String) -> Array:
	if _re_tag == null: _regex()
	var out: Array = []
	for m in _re_tag.search_all(text):
		var t := m.get_string(1).to_lower()
		if not t in out: out.append(t)
	return out.slice(0, 30)

static func parse_mentions(text: String) -> Array:
	if _re_mention == null: _regex()
	var out: Array = []
	for m in _re_mention.search_all(text):
		var t := m.get_string(1).trim_suffix(".")
		if not t in out: out.append(t)
	return out.slice(0, 20)

static func _find(pid: String) -> Dictionary:
	var f: Array = db()["feed"]
	for i in range(f.size() - 1, -1, -1):
		if f[i]["id"] == pid: return f[i]
	return {}

static func _seq(p: Dictionary) -> int: return int(str(p["id"]).substr(1))

static func _expired(p: Dictionary) -> bool:
	return int(p.get("expires_at", 0)) > 0 and _now() >= int(p["expires_at"])

## media: [{ref, alt, type: image|video, w, h, thumb_ref, duration_s}] (<= 10). Legacy media_ref still works.
static func _clean_media(opts: Dictionary) -> Dictionary:
	var items: Array = []
	if opts.get("media") is Array:
		if (opts["media"] as Array).size() > MAX_MEDIA: return {"ok": false, "error": "Up to %d photos or clips." % MAX_MEDIA}
		for m in opts["media"]:
			if not m is Dictionary: return {"ok": false, "error": "Bad media item."}
			var ref := clean(str(m.get("ref", "")), 200)
			var ty := str(m.get("type", "image"))
			if ref == "" or not ty in ["image", "video"]: return {"ok": false, "error": "Bad media item."}
			items.append({"ref": ref, "type": ty, "alt": clean(str(m.get("alt", "")), 1000), "w": maxi(0, int(m.get("w", 0))),
				"h": maxi(0, int(m.get("h", 0))), "thumb_ref": clean(str(m.get("thumb_ref", "")), 200),
				"low_ref": clean(str(m.get("low_ref", "")), 200), "duration_s": clampf(float(m.get("duration_s", 0.0)), 0.0, MAX_CLIP_S)})
	elif str(opts.get("media_ref", "")) != "":
		items.append({"ref": clean(str(opts["media_ref"]), 200), "type": "video" if str(opts.get("kind", "")) == "clip" else "image", "alt": clean(str(opts.get("alt", "")), 1000), "w": 0, "h": 0, "thumb_ref": "", "duration_s": 0.0})
	return {"ok": true, "items": items}

## Sticker / text overlay layers as data (Foxy's editor renders them). Positions are 0..1 of the frame.
static func _clean_layers(v: Variant) -> Array:
	var out: Array = []
	if not v is Array: return out
	for l in (v as Array).slice(0, MAX_LAYERS):
		if not l is Dictionary or not str(l.get("type", "")) in ["text", "sticker", "mention", "tag", "location", "poll", "link"]: continue
		out.append({"type": str(l["type"]), "x": clampf(float(l.get("x", 0.5)), 0.0, 1.0), "y": clampf(float(l.get("y", 0.5)), 0.0, 1.0),
			"scale": clampf(float(l.get("scale", 1.0)), 0.1, 8.0), "rot": fmod(float(l.get("rot", 0.0)), 360.0),
			"text": clean(str(l.get("text", "")), 200), "ref": clean(str(l.get("ref", "")), 200), "style": clean(str(l.get("style", "")), 32)})
	return out

## Social.post(actor, text, opts) -> {ok, id, state}. state: published | pending_approval | scheduled.
## opts (all optional):
##  kind: status | snapshot | build | photo | clip | story      (reposts: Social.repost)
##  visibility: public | friends | close_friends | group:<gid>   (replies inherit their parent's)
##  media: [{ref, alt, type, w, h, thumb_ref, duration_s}] (<= 10, carousel) or legacy media_ref
##  layers: sticker/text overlays as data      alt: alt text for a legacy media_ref
##  reply_to: post id      quote_of: post id      reply_policy: everyone | following | mentioned | nobody
##  poll: {options: [2..4 strings], hours: 1..168}  (needs the poll_create tier)
##  publish_at: unix time (scheduled)      mature: true (age-gated)      spoiler: true      ghost: true (24 h)
##  as_page: "page:N" (post as a page you admin)
##  clip only: duration_s, sound: {id} or {title}, remix_of: {pid, mode: duet | stitch | remix, start_s, end_s},
##             allow_remix (default true), allow_comments (default true)
## story: expires 24 h after it goes live; visibility public | friends | close_friends; never in feeds
##        (stories_tray); highlight: "name" adds it to a highlight once live.
## Companions: every post waits for the owner (EveCore.propose_update -> MENU > Proposals).
static func post(actor: Variant, text: String, opts := {}) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "post"): return _err("Residents and up can post.")
	var kind := str(opts.get("kind", "status"))
	if not kind in KINDS or kind == "repost": return _err("Unknown post kind.")
	var body := clean(text)
	var mr := _clean_media(opts)
	if not mr["ok"]: return _err(mr["error"])
	var media: Array = mr["items"]
	if body == "" and media.is_empty() and not opts.has("poll"): return _err("Write something.")
	if kind in ["photo", "clip"] and media.is_empty(): return _err("Add a photo or clip.")
	if kind == "clip" and not media.any(func(m): return m["type"] == "video"): return _err("A clip needs a video.")
	var now := _now()
	var p := {"id": "", "author": me, "text": body, "t": now, "visibility": "public", "kind": kind,
		"media_ref": media[0]["ref"] if not media.is_empty() else "", "media": media, "layers": _clean_layers(opts.get("layers", [])),
		"state": "published", "tags": parse_tags(body), "mentions": parse_mentions(body).filter(func(x): return x != me),
		"reactions": {}, "reposts": [], "views_total": 0, "spoiler": bool(opts.get("spoiler", false))}
	if opts.has("as_page"):
		var pg: Dictionary = db()["pages"].get(str(opts["as_page"]), {})
		if pg.is_empty() or not me in pg["admins"]: return _err("Page admins only.")
		p["author"] = pg["id"]; p["by"] = me
	var vis := str(opts.get("visibility", "public"))
	# replies inherit the parent's audience; ghost posts / stories route replies to DMs instead
	if opts.has("reply_to"):
		var par := _find(str(opts["reply_to"]))
		if par.is_empty() or not _visible(par, me) or par["kind"] in ["story", "repost"]: return _err("Can't reply to that.")
		if bool(par.get("ghost", false)): return _err("Ghost post replies go to DMs: use SocialDM.post_reply_dm.")
		var root := _find(str(par.get("root", par["id"])))
		if root.is_empty(): root = par
		if not _reply_allowed(root, me): return _err("Replies are limited on this post.")
		p["reply_to"] = par["id"]; p["root"] = root["id"]; vis = str(par["visibility"])
		var ra := str(root["author"])
		if ra.begins_with("page:"): ra = str(db()["pages"].get(ra, {}).get("owner", ""))
		if ra != me and is_restricted(ra, me): p["limited_to"] = [me, ra]; p["restricted"] = true
		elif ra != me and hidden_word_hit(ra, body): p["limited_to"] = [me]; p["filtered"] = true
	elif kind == "story":
		if not vis in ["public", "friends", "close_friends"]: return _err("Stories: public, friends or close friends.")
	elif not (vis in ["public", "friends", "close_friends"] or (vis.begins_with("group:") and is_member(vis.substr(6), me))): return _err("Pick who can see it.")
	if p.has("by") and vis != "public": return _err("Page posts are public.")
	p["visibility"] = vis
	if opts.has("quote_of"):
		var q := _find(str(opts["quote_of"]))
		if q.is_empty() or not _visible(q, me) or str(q["visibility"]) != "public" or q["kind"] in ["story", "repost"]: return _err("Can't quote that.")
		p["quote_of"] = q["id"]
	var rp := str(opts.get("reply_policy", "everyone"))
	if not rp in REPLY_POLICIES: return _err("Unknown reply setting.")
	p["reply_policy"] = rp if bool(opts.get("allow_comments", true)) else "nobody"
	if bool(opts.get("mature", false)):
		if not age_ok(me): return _err("Only age-verified members can post mature content.")
		p["mature"] = true
	if bool(opts.get("ghost", false)):
		if kind != "status" and kind != "photo": return _err("Ghost posts: text or photo only.")
		p["ghost"] = true
	if opts.has("poll"):
		if not Tiers.can(actor, "poll_create"): return _err("Creator tier or higher can make polls.")
		var po: Variant = opts["poll"]
		var o: Array = _clean_list(po.get("options", []) if po is Dictionary else [], POLL_MAX + 1, 80)
		var uniq: Array = []
		for x in o:
			if not x in uniq: uniq.append(x)
		if uniq.size() < POLL_MIN or uniq.size() > POLL_MAX: return _err("Polls need %d to %d different options." % [POLL_MIN, POLL_MAX])
		var h := int(po.get("hours", 24))
		if h < 1 or h > POLL_MAX_H: return _err("Polls run 1 to %d hours." % POLL_MAX_H)
		p["poll"] = {"options": uniq, "hours": h, "votes": {}, "closes": 0}
	if kind == "clip":
		var dur := float(opts.get("duration_s", media[0].get("duration_s", 0.0)))
		if dur <= 0.0 or dur > MAX_CLIP_S: return _err("Clips run up to %d seconds." % MAX_CLIP_S)
		p["duration_s"] = dur
		p["allow_remix"] = bool(opts.get("allow_remix", true))
		var snd: Variant = opts.get("sound", {})
		if snd is Dictionary and str(snd.get("id", "")) != "":
			if not db()["sounds"].has(str(snd["id"])): return _err("No such sound.")
			p["sound_id"] = str(snd["id"])
		else: p["sound_title"] = clean(str(snd.get("title", "")) if snd is Dictionary else "", 80)
		if opts.get("remix_of") is Dictionary:
			var rx: Dictionary = opts["remix_of"]
			var src := _find(str(rx.get("pid", "")))
			var mode := str(rx.get("mode", "remix"))
			if src.is_empty() or src["kind"] != "clip" or not _visible(src, me) or str(src["visibility"]) != "public": return _err("Can't remix that.")
			if not bool(src.get("allow_remix", true)): return _err("The creator turned off remixes.")
			if not mode in ["duet", "stitch", "remix"]: return _err("Pick duet, stitch or remix.")
			var a := float(rx.get("start_s", 0.0)); var b := float(rx.get("end_s", 0.0))
			if mode == "stitch" and (a < 0.0 or b <= a or b - a > MAX_STITCH_S or b > float(src.get("duration_s", 0.0))): return _err("Stitch up to %d seconds of the original." % MAX_STITCH_S)
			p["remix_of"] = {"pid": src["id"], "mode": mode, "start_s": a, "end_s": b}
			if not p.has("sound_id") and src.has("sound_id") and str(p.get("sound_title", "")) == "": p["sound_id"] = src["sound_id"]
	elif opts.has("sound") or opts.has("remix_of"): return _err("Sounds and remixes are for clips.")
	var pub := int(opts.get("publish_at", 0))
	if pub > now + 60:
		if pub > now + SCHEDULE_MAX_DAYS * 86400: return _err("Schedule up to %d days ahead." % SCHEDULE_MAX_DAYS)
		p["publish_at"] = pub
	if kind == "story" and str(opts.get("highlight", "")) != "": p["highlight"] = clean(str(opts["highlight"]), 40)
	var snap := _snap()
	p["id"] = _next("p")
	_insert(p)
	return _commit(snap, _ok({"id": p["id"], "state": p["state"]}))

## Companion approval / scheduling / publish hooks for every new feed item.
static func _insert(p: Dictionary) -> void:
	var bot := str(p.get("by", p["author"]))
	if Tiers.is_bot(bot):
		p["state"] = "pending_approval"
		var what := str(p["kind"]) + (" reply" if p.has("reply_to") else "")
		p["proposal_id"] = EveCore.for_companion(bot).propose_update(PROPOSAL_TAG + p["id"] + " (" + what + "): " + (str(p["text"]) if str(p["text"]) != "" else str(p.get("media_ref", ""))).left(280))["id"]
	elif int(p.get("publish_at", 0)) > _now(): p["state"] = "scheduled"
	else: _on_publish(p)
	db()["feed"].append(p)
	if db()["feed"].size() > MAX_FEED: db()["feed"].pop_front()

static func _on_publish(p: Dictionary) -> void:
	p["state"] = "published"
	if int(p.get("publish_at", 0)) > int(p["t"]): p["t"] = int(p["publish_at"])
	p["t"] = maxi(int(p["t"]), _now()) if p.has("proposal_id") or p.has("publish_at") else int(p["t"])
	if p["kind"] == "story" or bool(p.get("ghost", false)): p["expires_at"] = int(p["t"]) + STORY_TTL
	if p.has("poll"): p["poll"]["closes"] = int(p["t"]) + int(p["poll"]["hours"]) * 3600
	var a := str(p["author"]); var by := str(p.get("by", a))
	var nm := _name(a)
	for m in p.get("mentions", []):
		if _mention_ok(str(m), by) and not (p.has("limited_to") and not m in p["limited_to"]): _note(str(m), "mention", "%s mentioned you." % nm, by)
	if p.has("reply_to") and not p.has("limited_to"):   # restricted / filtered replies notify nobody
		var par := _find(str(p["reply_to"]))
		if not par.is_empty(): _note(str(par["author"]), "reply", "%s replied to you." % nm, by)
	if p.has("quote_of"):
		var q := _find(str(p["quote_of"]))
		if not q.is_empty(): _note(str(q["author"]), "quote", "%s quoted your post." % nm, by)
	if p["kind"] == "repost":
		var o := _find(str(p.get("repost_of", "")))
		if not o.is_empty():
			if not a in o["reposts"]: o["reposts"].append(a)
			_note(str(o["author"]), "repost", "%s reposted your post." % nm, by)
	if p["kind"] == "clip":
		if not p.has("sound_id"):
			var sid := _next("s")
			var t := str(p.get("sound_title", ""))
			db()["sounds"][sid] = {"id": sid, "title": t if t != "" else "Original sound · " + nm, "by": a, "from": p["id"], "t": p["t"]}
			p["sound_id"] = sid
	if p.has("remix_of"):
		var src := _find(str(p["remix_of"]["pid"]))
		if not src.is_empty():
			var rl: Array = src.get("remixes", [])
			rl.append(p["id"]); src["remixes"] = rl
			_note(str(src["author"]), "remix", "%s made a %s with your clip." % [nm, p["remix_of"]["mode"]], by)
	if p["kind"] == "story" and p.has("highlight"): _highlight_put(a, str(p["highlight"]), p)

static func _mention_ok(target: String, from: String) -> bool:
	if not (db()["profiles"].has(target) or db()["pages"].has(target)) or is_blocked(target, from): return false
	match str(privacy_of(target)["mentions"]):
		"following": return is_following(target, from)
		"nobody": return false
	return true

static func _reply_allowed(root: Dictionary, me: String) -> bool:
	var ra := str(root["author"])
	if ra == me or str(root.get("by", "")) == me: return true
	match str(root.get("reply_policy", "everyone")):
		"following": return is_following(ra, me) or me in friends_of(ra)
		"mentioned": return me in root.get("mentions", [])
		"nobody": return false
	return true

## Publish / reject companion posts + events after the owner's decision in MENU > Proposals, and
## publish scheduled posts that are due.
static func sync_approvals() -> int:
	var states := {}
	for pr in EveCore.proposals(): states[pr["id"]] = pr["state"]
	var n := 0
	for p in db()["feed"]:
		if p["state"] == "pending_approval" and states.has(p.get("proposal_id", "")):
			match states[p["proposal_id"]]:
				"Approved":
					n += 1
					if int(p.get("publish_at", 0)) > _now(): p["state"] = "scheduled"
					else: _on_publish(p)
				"Rejected": p["state"] = "rejected"; n += 1
	for e in db()["events"].values():
		if e["state"] == "pending_approval" and states.has(e.get("proposal_id", "")):
			match states[e["proposal_id"]]:
				"Approved": e["state"] = "published"; n += 1
				"Rejected": e["state"] = "rejected"; n += 1
	for p in db()["feed"]:
		if p["state"] == "scheduled" and int(p.get("publish_at", 0)) <= _now(): _on_publish(p); n += 1
	if n > 0: _save()
	return n

static func _visible(p: Dictionary, viewer: String) -> bool:
	if p["state"] != "published": return false
	var a := str(p["author"])
	if a == viewer or str(p.get("by", "")) == viewer: return true   # authors always see their own (archive)
	if is_blocked(viewer, a) or (p.has("by") and is_blocked(viewer, str(p["by"]))): return false
	if _expired(p): return false
	if p.get("limited_to") is Array and not viewer in p["limited_to"]: return false
	if bool(p.get("mature", false)) and not age_ok(viewer): return false
	if not _account_ok(a, viewer): return false
	var v := str(p["visibility"])
	if v == "public": return true
	if v == "friends": return viewer in friends_of(a)
	if v == "close_friends": return viewer in db()["close_friends"].get(a, [])
	if v.begins_with("group:"): return is_member(v.substr(6), viewer)
	return false

static func can_see(viewer: Variant, pid: String) -> bool:
	var p := _find(pid)
	return not p.is_empty() and _visible(p, _id(viewer))

# ---------- feeds ----------
## Two call styles:
##  Social.feed(viewer, limit: int = 20, author = "") -> Array   (legacy: newest first)
##  Social.feed(viewer, cursor: String) -> {ok, items, next_cursor, mode}   (Foxy's paged feed)
## cursor "" = first page of the ranked "for_you" feed. A mode name gives the first page of that feed:
##  for_you (ranked, everyone) | following (newest, people/pages you follow + friends + your groups) |
##  latest (newest, everything you may see) | explore (ranked, people you don't follow) |
##  clips (ranked vertical-video feed) | list:<id> | tag:<tag> | author:<id> | group:<gid> | sound:<id>
## Pass next_cursor back for the next page; "" means no more. Pages are a snapshot: posts made after
## the first page don't shift later pages. Stories and replies are never feed items.
static func feed(viewer: Variant, cursor: Variant = 20, author := "") -> Variant:
	if cursor is String: return feed_page(viewer, "author:" + author if author != "" and str(cursor) == "" else str(cursor))
	if not Tiers.can(viewer, "browse"): return []
	sync_approvals()
	var me := _id(viewer)
	var c := _candidates(me, "author:" + author if author != "" else "latest", _now())
	c.sort_custom(_newer)
	return c.slice(0, int(cursor)).map(func(p): return decorate(me, p))

static func feed_page(viewer: Variant, cursor := "", limit := 20) -> Dictionary:
	var empty := {"ok": false, "error": "", "items": [], "next_cursor": "", "mode": ""}
	if not Tiers.can(viewer, "browse"): empty["error"] = "Not allowed."; return empty
	var parts := cursor.split("|")
	var mode := parts[0] if parts[0] != "" else "for_you"
	if mode == "live": return CompanionLive.page(viewer)   # v0.13.1 LIVE-1: companions' creative spaces
	if not (mode in FEED_MODES or FEED_PREFIX_MODES.any(func(x): return mode.begins_with(x))): empty["error"] = "Unknown feed."; return empty
	var me := _id(viewer)
	if mode == "following" and Tiers.tier_of(viewer) == "guest": mode = "latest"
	var at := int(parts[1]) if parts.size() >= 3 else _now()
	var off := maxi(0, int(parts[2])) if parts.size() >= 3 else 0
	limit = clampi(limit, 1, 50)
	sync_approvals()
	# Snapshot = time + the highest post sequence seen on page one (posts made in the same second
	# as the snapshot don't slip in between pages).
	var top := int(parts[3]) if parts.size() >= 4 else _max_seq()
	var c := _candidates(me, mode, at).filter(func(p): return _seq(p) <= top)
	if mode in RANKED_MODES:
		var ctx := _rank_ctx(me)
		var scored: Array = c.map(func(p): return [_score(me, p, at, ctx), _seq(p), p])
		scored.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] > y[1]))
		c = _diversify(scored.map(func(x): return x[2]))
	else: c.sort_custom(_newer)
	var items: Array = c.slice(off, off + limit).map(func(p): return decorate(me, p))
	var nxt := "%s|%d|%d|%d" % [mode, at, off + limit, top] if off + limit < c.size() else ""
	return {"ok": true, "error": "", "items": items, "next_cursor": nxt, "mode": mode}

static func _max_seq() -> int:
	var m := 0
	for p in db()["feed"]: m = maxi(m, _seq(p))
	return m

static func _newer(a: Dictionary, b: Dictionary) -> bool:
	return int(a["t"]) > int(b["t"]) or (int(a["t"]) == int(b["t"]) and _seq(a) > _seq(b))

static func _following_set(me: String) -> Dictionary:
	var fol := {}
	for x in db()["follows"].get(me, []): fol[x] = true
	for f in friends_of(me): fol[f] = true
	return fol

static func _candidates(me: String, mode: String, at: int) -> Array:
	var fol := _following_set(me)
	var members: Array = []
	if mode.begins_with("list:"):
		var L: Dictionary = db()["lists"].get(mode.substr(5), {})
		if L.is_empty() or (bool(L["private"]) and L["owner"] != me): return []
		members = L["members"]
	var tag := _norm_tag(mode.substr(4)) if mode.begins_with("tag:") else ""
	var out: Array = []
	for p in db()["feed"]:
		if int(p["t"]) > at or p["kind"] == "story" or p.has("reply_to"): continue
		if not _visible(p, me): continue
		var a := str(p["author"])
		if a != me and (is_muted(me, a) or hidden_word_hit(me, str(p["text"]))): continue
		if p["kind"] == "repost":
			var o := _find(str(p.get("repost_of", "")))
			if o.is_empty() or not _visible(o, me) or is_muted(me, str(o["author"])): continue
		var ok := true
		if mode == "following": ok = a == me or fol.has(a) or str(p["visibility"]).begins_with("group:")
		elif mode == "explore": ok = a != me and not fol.has(a) and p["visibility"] == "public" and p["kind"] != "repost"
		elif mode == "clips": ok = p["kind"] == "clip"
		elif mode.begins_with("tag:"): ok = tag in p.get("tags", [])
		elif mode.begins_with("author:"): ok = a == mode.substr(7)
		elif mode.begins_with("group:"): ok = p["visibility"] == mode
		elif mode.begins_with("sound:"): ok = str(p.get("sound_id", "")) == mode.substr(6)
		elif mode.begins_with("list:"): ok = a in members
		if ok: out.append(p)
	return out

static func _reaction_total(p: Dictionary) -> int:
	var n := 0
	for k in p.get("reactions", {}): n += (p["reactions"][k] as Array).size()
	return n

static func _rank_ctx(me: String) -> Dictionary:
	var replies := {}; var quotes := {}; var inter := {}; var bm := {}; var close := {}
	for p in db()["feed"]:
		if p["state"] != "published": continue
		if p.has("reply_to"): replies[p["reply_to"]] = int(replies.get(p["reply_to"], 0)) + 1
		if p.has("quote_of"): quotes[p["quote_of"]] = int(quotes.get(p["quote_of"], 0)) + 1
		for k in p.get("reactions", {}):
			if me in p["reactions"][k]: inter[p["author"]] = int(inter.get(p["author"], 0)) + 1
	for who in db()["bookmarks"]:
		for b in db()["bookmarks"][who]: bm[b["pid"]] = int(bm.get(b["pid"], 0)) + 1
	for who in db()["close_friends"]:
		if me in db()["close_friends"][who]: close[who] = true
	var prefs := {}
	var raw: Dictionary = db()["feed_prefs"].get(me, {})
	for t in raw:
		if int(raw[t]["until"]) == 0 or int(raw[t]["until"]) > _now(): prefs[t] = int(raw[t]["w"])
	var friends := {}
	for f in friends_of(me): friends[f] = true
	var follows := {}
	for x in db()["follows"].get(me, []): follows[x] = true
	return {"replies": replies, "quotes": quotes, "inter": inter, "bm": bm, "close": close, "prefs": prefs, "friends": friends, "follows": follows}

## Ranking: engagement (log-scaled), relationship affinity, your topic controls, already-seen
## penalty, and freshness (half-life HALF_LIFE_H hours). Deterministic for a given snapshot time.
static func _score(me: String, p: Dictionary, at: int, ctx: Dictionary) -> float:
	var a := str(p["author"]); var id := str(p["id"])
	var eng := float(_reaction_total(p)) + 2.0 * int(ctx["replies"].get(id, 0)) + 3.0 * (p.get("reposts", []) as Array).size() \
		+ 2.0 * int(ctx["quotes"].get(id, 0)) + 2.0 * int(ctx["bm"].get(id, 0)) + 0.05 * int(p.get("views_total", 0))
	var s := 1.0 + log(1.0 + eng)
	if ctx["friends"].has(a): s += 3.0
	elif ctx["follows"].has(a): s += 2.0
	if ctx["close"].has(a): s += 1.0
	if str(p["visibility"]).begins_with("group:"): s += 1.0
	s += minf(3.0, int(ctx["inter"].get(a, 0)) * 0.5)
	for t in p.get("tags", []):
		if ctx["prefs"].has(t): s += 2.0 if int(ctx["prefs"][t]) > 0 else -3.0
	if p.get("viewers", {}).has(me): s -= 1.5
	s = maxf(0.05, s)
	var age_h := maxf(0.0, float(at - int(p["t"])) / 3600.0)
	return s * pow(0.5, age_h / HALF_LIFE_H)

## No more than two items in a row from the same author.
static func _diversify(arr: Array) -> Array:
	var out: Array = []; var rest := arr.duplicate()
	while not rest.is_empty():
		var pick := 0
		if out.size() >= 2 and out[-1]["author"] == out[-2]["author"]:
			for i in rest.size():
				if rest[i]["author"] != out[-1]["author"]: pick = i; break
		out.append(rest[pick]); rest.remove_at(pick)
	return out

static func _reply_count(pid: String) -> int:
	var n := 0
	for p in db()["feed"]:
		if p["state"] == "published" and str(p.get("reply_to", "")) == pid and not p.has("limited_to"): n += 1
	return n

## A display-ready copy for Foxy's screens: counts, my reaction, bookmarked, poll results, original
## (for reposts/quotes), context notes. Internal fields (viewer lists, poll voters) are removed.
static func decorate(viewer: Variant, p: Dictionary) -> Dictionary:
	var me := _id(viewer)
	var d := p.duplicate(true)
	for k in ["viewers", "proposal_id", "limited_to", "edits"]: d.erase(k)
	d["edited"] = (p.get("edits", []) as Array).size() > 0
	d["author_name"] = _name(str(p["author"])); d["badges"] = badges_of(str(p["author"]))
	var rx := {}; var mine := ""
	for k in p.get("reactions", {}):
		rx[k] = (p["reactions"][k] as Array).size()
		if me in p["reactions"][k]: mine = k
	d["reactions"] = rx; d["likes"] = _reaction_total(p); d["my_reaction"] = mine
	d["reposts"] = (p.get("reposts", []) as Array).size(); d["reposted"] = me in p.get("reposts", [])
	d["replies"] = _reply_count(str(p["id"])); d["views"] = int(p.get("views_total", 0))
	d["bookmarked"] = db()["bookmarks"].get(me, []).any(func(b): return b["pid"] == p["id"])
	if p.has("poll"): d["poll"] = _poll_view(me, p)
	var oid := str(p.get("repost_of", p.get("quote_of", "")))
	if oid != "":
		var o := _find(oid)
		d["original"] = {"id": o["id"], "author": o["author"], "author_name": _name(str(o["author"])), "text": o["text"], "kind": o["kind"],
			"media": o.get("media", []), "t": o["t"], "mature": o.get("mature", false)} if not o.is_empty() and _visible(o, me) else {"unavailable": true}
	d["notes"] = context_notes(me, str(p["id"]))
	_media_hints(d)
	return d

## Lazy full-media fetch: the ref for one media item once the viewer opens it (visibility checked
## again). variant: "auto" (full on "full", else low) | "full" | "low" | "thumb".
static func media_url(viewer: Variant, pid: String, index := 0, variant := "auto") -> String:
	var p := _find(pid)
	if p.is_empty() or not _visible(p, _id(viewer)) or index < 0 or index >= (p.get("media", []) as Array).size(): return ""
	var d := {"media": p["media"].duplicate(true), "kind": p["kind"]}
	_media_hints(d)
	var m: Dictionary = d["media"][index]
	match variant:
		"full": return str(m["full_url"])
		"low": return str(m["low_url"])
		"thumb": return str(m["thumb_url"])
	return str(m["full_url"]) if data_mode() == "full" else str(m["low_url"])

## Data mode from Net (scripts/system/net.gd, PR #39; AutoConfig sets it from the PowerData policy):
## "full" | "normal" | "saver". data_mode_override is for tests only.
static func data_mode() -> String:
	if data_mode_override != "": return data_mode_override if data_mode_override in Net.MODES else "normal"
	return Net.mode

## Thumbnails first: every media item carries thumb_url + hash; full media is lazy (fetch only when
## opened / on screen). Budgets come straight from Net for the current mode:
##  full   -> full variant, autoplay, prefetch next items
##  normal -> low variant, autoplay, no prefetch
##  saver  -> thumbnails only in the feed, no autoplay; opening an item streams the low variant
## Each item also carries max_px / thumb_px (Net.image_px) and, for clips/stories, kbps
## (Net.media_kbps("video")) so the client never asks for more than the budget.
static func _media_hints(d: Dictionary) -> void:
	var mode := data_mode()
	var prev := Net.mode
	Net.mode = mode    # read Net's tables for this mode (restored below; override only differs in tests)
	var video := str(d.get("kind", "")) in ["clip", "story"]
	for m in d.get("media", []):
		var ref := str(m["ref"])
		var media_ref := ref.begins_with("media:")
		m["hash"] = ref.substr(6).left(16) if media_ref else ref.sha256_text().left(16)
		m["thumb_url"] = str(m.get("thumb_ref", "")) if str(m.get("thumb_ref", "")) != "" else (ref + "_t" if media_ref else "")
		m["low_url"] = str(m.get("low_ref", "")) if str(m.get("low_ref", "")) != "" else (ref + "_low" if media_ref else ref)
		m["full_url"] = ref
		m["lazy"] = true
		m["max_px"] = Net.image_px("image")
		m["thumb_px"] = Net.image_px("thumb")
		if video or str(m.get("type", "")) == "video": m["kbps"] = Net.media_kbps("video")
		if Net.thumbnails_only(): m["use_url"] = m["thumb_url"] if m["thumb_url"] != "" else m["low_url"]
		elif mode == "normal": m["use_url"] = m["low_url"]
		else: m["use_url"] = ref
	d["data_mode"] = mode
	d["thumb_url"] = str(d["media"][0]["thumb_url"]) if not (d.get("media", []) as Array).is_empty() else ""
	d["autoplay"] = video and Net.autoplay_ok()
	d["prefetch"] = Net.prefetch_ok()
	d["variant"] = "thumb" if Net.thumbnails_only() else ("full" if mode == "full" else "low")
	Net.mode = prev

# ---------- engagement: reactions, reposts, bookmarks, views ----------
static func react(actor: Variant, pid: String, kind := "like") -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	if not kind in REACTIONS: return _err("Unknown reaction.")
	var p := _find(pid)
	if p.is_empty() or not _visible(p, me): return _err("No such post.")
	var snap := _snap()
	var rx: Dictionary = p.get("reactions", {})
	var had := false
	for k in rx:
		if me in rx[k]: had = true; (rx[k] as Array).erase(me)
	var l: Array = rx.get(kind, []); l.append(me); rx[kind] = l
	p["reactions"] = rx
	if not had: _note(str(p["author"]), "like", "%s reacted to your post." % _name(me), me)
	return _commit(snap, _ok())

static func unreact(actor: Variant, pid: String) -> Dictionary:
	var me := _id(actor)
	var p := _find(pid)
	if p.is_empty(): return _err("No such post.")
	var snap := _snap()
	for k in p.get("reactions", {}): (p["reactions"][k] as Array).erase(me)
	return _commit(snap, _ok())

## Repost to your followers (public posts only). Companions: owner approval first.
static func repost(actor: Variant, pid: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "post"): return _err("Residents and up can post.")
	var o := _find(pid)
	if o.is_empty() or not _visible(o, me) or str(o["visibility"]) != "public" or o["kind"] in ["story", "repost"] or bool(o.get("ghost", false)): return _err("Can't repost that.")
	if me in o.get("reposts", []) or db()["feed"].any(func(x): return x["kind"] == "repost" and x["author"] == me and x.get("repost_of") == pid and x["state"] in ["published", "pending_approval"]): return _err("Already reposted.")
	var snap := _snap()
	var p := {"id": _next("p"), "author": me, "text": "", "t": _now(), "visibility": "public", "kind": "repost", "repost_of": pid,
		"media_ref": "", "media": [], "layers": [], "state": "published", "tags": [], "mentions": [], "reactions": {}, "reposts": [], "views_total": 0}
	_insert(p)
	return _commit(snap, _ok({"id": p["id"], "state": p["state"]}))

static func unrepost(actor: Variant, pid: String) -> Dictionary:
	var me := _id(actor)
	var snap := _snap()
	var n := 0
	for x in db()["feed"]:
		if x["kind"] == "repost" and x["author"] == me and x.get("repost_of") == pid and x["state"] != "deleted": x["state"] = "deleted"; n += 1
	var o := _find(pid)
	if not o.is_empty(): (o["reposts"] as Array).erase(me)
	if n == 0: return _err("Not reposted.")
	return _commit(snap, _ok())

static func bookmark(actor: Variant, pid: String, folder := "") -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	if not can_see(actor, pid): return _err("No such post.")
	var snap := _snap()
	var l: Array = db()["bookmarks"].get(me, []).filter(func(b): return b["pid"] != pid)
	l.append({"pid": pid, "folder": clean(folder, 40), "t": _now()})
	if l.size() > 1000: l.pop_front()
	db()["bookmarks"][me] = l
	return _commit(snap, _ok())

static func unbookmark(actor: Variant, pid: String) -> Dictionary:
	var me := _id(actor); var snap := _snap()
	db()["bookmarks"][me] = db()["bookmarks"].get(me, []).filter(func(b): return b["pid"] != pid)
	return _commit(snap, _ok())

## Private to you. folder null = all; "" = unfiled. Newest first; posts you can no longer see are skipped.
static func bookmarks(actor: Variant, folder: Variant = null) -> Array:
	var me := _id(actor)
	var out: Array = []
	var l: Array = db()["bookmarks"].get(me, [])
	for i in range(l.size() - 1, -1, -1):
		var b: Dictionary = l[i]
		if folder != null and b["folder"] != str(folder): continue
		var p := _find(str(b["pid"]))
		if not p.is_empty() and _visible(p, me):
			var d := decorate(me, p); d["folder"] = b["folder"]; out.append(d)
	return out

static func bookmark_folders(actor: Variant) -> Array:
	var out: Array = []
	for b in db()["bookmarks"].get(_id(actor), []):
		if b["folder"] != "" and not b["folder"] in out: out.append(b["folder"])
	return out

## Views (and clip watch time) feed ranking + creator analytics. Authors' own views don't count.
static func record_view(viewer: Variant, pid: String, watch_ms := 0) -> Dictionary:
	var me := _id(viewer)
	if not Tiers.can(viewer, "browse"): return _err("Not allowed.")
	var p := _find(pid)
	if p.is_empty() or not _visible(p, me): return _err("No such post.")
	if me == p["author"] or me == str(p.get("by", "")): return _ok()
	var snap := _snap()
	var vw: Dictionary = p.get("viewers", {})
	if not vw.has(me): CreatorEconomy.on_unique_view(str(p["author"]), pid, me, _now())   # v0.13 ECON-1
	if vw.has(me) or vw.size() < 1000:
		var e: Dictionary = vw.get(me, {"n": 0, "ms": 0, "t": 0})
		e["n"] = int(e["n"]) + 1; e["ms"] = maxi(int(e["ms"]), maxi(0, watch_ms)); e["t"] = _now()
		vw[me] = e
	p["viewers"] = vw
	p["views_total"] = int(p.get("views_total", 0)) + 1
	return _commit(snap, _ok())

# ---------- threads, edits, pins, deletes ----------
## {ok, root, replies: [decorated + depth]} in conversation order. Restricted / filtered replies only
## show to the people they're limited to.
static func thread(viewer: Variant, pid: String) -> Dictionary:
	var me := _id(viewer)
	if not Tiers.can(viewer, "browse"): return _err("Not allowed.")
	var p := _find(pid)
	if p.is_empty() or not _visible(p, me): return _err("No such post.")
	var root := _find(str(p.get("root", p["id"])))
	if root.is_empty() or not _visible(root, me): root = p
	var kids := {}
	for x in db()["feed"]:
		if str(x.get("root", "")) == root["id"] and _visible(x, me) and not (is_muted(me, str(x["author"])) and x["author"] != me):
			var par := str(x["reply_to"])
			var l: Array = kids.get(par, []); l.append(x); kids[par] = l
	var out: Array = []
	_walk_thread(me, str(root["id"]), kids, 1, out)
	return _ok({"root": decorate(me, root), "replies": out})

static func _walk_thread(me: String, pid: String, kids: Dictionary, depth: int, out: Array) -> void:
	var l: Array = kids.get(pid, [])
	l.sort_custom(func(a, b): return _seq(a) < _seq(b))
	for x in l:
		var d := decorate(me, x); d["depth"] = depth; out.append(d)
		if depth < 32: _walk_thread(me, str(x["id"]), kids, depth + 1, out)

## Replies to your posts held back by your hidden words (you decide to leave them or delete them).
static func hidden_replies(actor: Variant, pid: String) -> Array:
	var me := _id(actor)
	var root := _find(pid)
	if root.is_empty() or (root["author"] != me and str(root.get("by", "")) != me): return []
	return db()["feed"].filter(func(x): return str(x.get("root", "")) == pid and bool(x.get("filtered", false)) and x["state"] == "published").map(func(x): return decorate(me, x))

## Edit within EDIT_WINDOW (1 h), up to MAX_EDITS times; the history stays visible (edit_history).
## Companion posts can't be edited (the owner approved that exact text): post again instead.
static func edit_post(actor: Variant, pid: String, text: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "post"): return _err("Not allowed.")
	var p := _find(pid)
	if p.is_empty() or (p["author"] != me and str(p.get("by", "")) != me) or p["state"] in ["deleted", "hidden", "held", "rejected"]: return _err("No such post.")
	if Tiers.is_bot(me): return _err("Companion posts can't be edited. Post again for owner approval.")
	if p["state"] == "published" and _now() - int(p["t"]) > EDIT_WINDOW: return _err("Posts can be edited for 1 hour.")
	if (p.get("edits", []) as Array).size() >= MAX_EDITS: return _err("Edited too many times.")
	var body := clean(text)
	if body == "" and (p.get("media", []) as Array).is_empty(): return _err("Write something.")
	var snap := _snap()
	var e: Array = p.get("edits", []); e.append({"t": _now(), "text": p["text"]}); p["edits"] = e
	p["text"] = body; p["tags"] = parse_tags(body); p["mentions"] = parse_mentions(body).filter(func(x): return x != me)
	return _commit(snap, _ok())

static func edit_history(viewer: Variant, pid: String) -> Array:
	var p := _find(pid)
	if p.is_empty() or not _visible(p, _id(viewer)): return []
	return (p.get("edits", []) as Array).duplicate(true)

static func pin_post(actor: Variant, pid: String) -> Dictionary:
	var me := _id(actor)
	var p := _find(pid)
	if p.is_empty() or p["author"] != me or p["state"] != "published" or p["kind"] == "story": return _err("Pin one of your own posts.")
	if not db()["profiles"].has(me): return _err("No profile.")
	var snap := _snap(); db()["profiles"][me]["pinned"] = pid
	return _commit(snap, _ok())

static func unpin_post(actor: Variant) -> Dictionary:
	var me := _id(actor)
	if not db()["profiles"].has(me): return _err("No profile.")
	var snap := _snap(); db()["profiles"][me].erase("pinned")
	return _commit(snap, _ok())

static func pending_posts() -> Array:
	return db()["feed"].filter(func(p): return p["state"] == "pending_approval").duplicate(true)

static func delete_post(actor: Variant, pid: String) -> Dictionary:
	var p := _find(pid)
	if p.is_empty(): return _err("No such post.")
	var me := _id(actor)
	if p["author"] != me and str(p.get("by", "")) != me and not Tiers.can(actor, "moderate"): return _err("Not allowed.")
	var snap := _snap(); p["state"] = "deleted"
	if p["kind"] == "repost":
		var o := _find(str(p.get("repost_of", "")))
		if not o.is_empty(): (o["reposts"] as Array).erase(p["author"])
	return _commit(snap, _ok())

# ---------- polls ----------
static func poll_create(actor: Variant, question: String, options: Array, hours := 24, opts := {}) -> Dictionary:
	var o := opts.duplicate(); o["poll"] = {"options": options, "hours": hours}
	return post(actor, question, o)

## One vote per member; no changing it; closed polls refuse votes.
static func poll_vote(actor: Variant, pid: String, option: int) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "poll_vote"): return _err("Not allowed.")
	var p := _find(pid)
	if p.is_empty() or not p.has("poll") or not _visible(p, me): return _err("No such poll.")
	var po: Dictionary = p["poll"]
	if _now() >= int(po["closes"]): return _err("This poll has closed.")
	if po["votes"].has(me): return _err("You already voted.")
	if option < 0 or option >= (po["options"] as Array).size(): return _err("Pick an option.")
	var snap := _snap(); po["votes"][me] = option
	return _commit(snap, _ok())

static func _poll_view(me: String, p: Dictionary) -> Dictionary:
	var po: Dictionary = p["poll"]
	var counts: Array = []
	for i in (po["options"] as Array).size(): counts.append(0)
	for v in po["votes"]: counts[int(po["votes"][v])] += 1
	return {"options": po["options"].duplicate(), "counts": counts, "total": po["votes"].size(), "closes": po["closes"],
		"closed": int(po["closes"]) > 0 and _now() >= int(po["closes"]), "mine": int(po["votes"].get(me, -1))}

## Counts only (voters stay private).
static func poll_results(viewer: Variant, pid: String) -> Dictionary:
	var p := _find(pid)
	if p.is_empty() or not p.has("poll") or not _visible(p, _id(viewer)): return _err("No such poll.")
	return _ok({"poll": _poll_view(_id(viewer), p)})

# ---------- drafts + scheduled ----------
static func save_draft(actor: Variant, text: String, opts := {}, did := "") -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "post"): return _err("Not allowed.")
	var l: Array = db()["drafts"].get(me, [])
	if did == "" and l.size() >= MAX_DRAFTS: return _err("Up to %d drafts." % MAX_DRAFTS)
	var snap := _snap()
	var o: Variant = JSON.parse_string(JSON.stringify(opts))   # plain data only
	var d := {"id": did if did != "" else _next("d"), "text": clean(text), "opts": o if o is Dictionary else {}, "t": _now()}
	var found := false
	for i in l.size():
		if l[i]["id"] == did: l[i] = d; found = true
	if did != "" and not found: return _err("No such draft.")
	if not found: l.append(d)
	db()["drafts"][me] = l
	return _commit(snap, _ok({"id": d["id"]}))

static func drafts(actor: Variant) -> Array: return db()["drafts"].get(_id(actor), []).duplicate(true)

static func delete_draft(actor: Variant, did: String) -> Dictionary:
	var me := _id(actor); var snap := _snap()
	var before: int = db()["drafts"].get(me, []).size()
	db()["drafts"][me] = db()["drafts"].get(me, []).filter(func(d): return d["id"] != did)
	if db()["drafts"][me].size() == before: return _err("No such draft.")
	return _commit(snap, _ok())

static func publish_draft(actor: Variant, did: String) -> Dictionary:
	for d in db()["drafts"].get(_id(actor), []):
		if d["id"] == did:
			var r := post(actor, str(d["text"]), d["opts"])
			if r["ok"]: delete_draft(actor, did)
			return r
	return _err("No such draft.")

static func scheduled_posts(actor: Variant) -> Array:
	var me := _id(actor)
	return db()["feed"].filter(func(p): return p["state"] == "scheduled" and (p["author"] == me or str(p.get("by", "")) == me)).duplicate(true)

# ---------- lists ----------
static func list_create(actor: Variant, name: String, private := true) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	var n := clean(name, 48)
	if n == "": return _err("Name the list.")
	var snap := _snap()
	var lid := _next("l")
	db()["lists"][lid] = {"id": lid, "owner": me, "name": n, "private": private, "members": [], "created": _now()}
	return _commit(snap, _ok({"id": lid}))

static func list_add(actor: Variant, lid: String, who: String) -> Dictionary:
	var L: Dictionary = db()["lists"].get(lid, {})
	if L.is_empty() or L["owner"] != _id(actor): return _err("Not your list.")
	if who == "" or is_blocked(_id(actor), who): return _err("Not available.")
	if (L["members"] as Array).size() >= 500: return _err("Lists hold up to 500.")
	var snap := _snap()
	if not who in L["members"]: L["members"].append(who)
	return _commit(snap, _ok())

static func list_remove(actor: Variant, lid: String, who: String) -> Dictionary:
	var L: Dictionary = db()["lists"].get(lid, {})
	if L.is_empty() or L["owner"] != _id(actor): return _err("Not your list.")
	var snap := _snap(); (L["members"] as Array).erase(who)
	return _commit(snap, _ok())

static func list_delete(actor: Variant, lid: String) -> Dictionary:
	var L: Dictionary = db()["lists"].get(lid, {})
	if L.is_empty() or L["owner"] != _id(actor): return _err("Not your list.")
	var snap := _snap(); db()["lists"].erase(lid)
	return _commit(snap, _ok())

## Your lists, plus public lists of others when owner_id is given.
static func lists_of(viewer: Variant, owner_id := "") -> Array:
	var me := _id(viewer); var who := me if owner_id == "" else owner_id
	return db()["lists"].values().filter(func(L): return L["owner"] == who and (who == me or not bool(L["private"]))).duplicate(true)

# ---------- stories, highlights, archive ----------
## Live stories you may see, grouped by author: [{author, name, badges, items, unseen, close}].
## Order: unseen first, then close friends / friends, then newest. Muted authors are left out.
static func stories_tray(viewer: Variant) -> Array:
	var me := _id(viewer)
	if not Tiers.can(viewer, "browse"): return []
	sync_approvals()
	var by := {}
	for p in db()["feed"]:
		if p["kind"] != "story" or _expired(p) or not _visible(p, me): continue
		var a := str(p["author"])
		if a != me and is_muted(me, a): continue
		var l: Array = by.get(a, []); l.append(p); by[a] = l
	var friends := friends_of(me)
	var out: Array = []
	for a in by:
		var items: Array = by[a]
		items.sort_custom(func(x, y): return int(x["t"]) < int(y["t"]))
		var unseen := items.any(func(x): return a != me and not x.get("viewers", {}).has(me))
		out.append({"author": a, "name": _name(a), "badges": badges_of(a), "unseen": unseen, "close": me in db()["close_friends"].get(a, []),
			"friend": a in friends, "latest": int(items[-1]["t"]), "items": items.map(func(x): return decorate(me, x))})
	out.sort_custom(func(x, y):
		if x["author"] == me or y["author"] == me: return x["author"] == me
		if x["unseen"] != y["unseen"]: return x["unseen"]
		var px := int(x["close"]) * 2 + int(x["friend"]); var py := int(y["close"]) * 2 + int(y["friend"])
		if px != py: return px > py
		return x["latest"] > y["latest"])
	return out

static func story_view(viewer: Variant, sid: String) -> Dictionary:
	var p := _find(sid)
	if p.is_empty() or p["kind"] != "story": return _err("No such story.")
	return record_view(viewer, sid)

## Author only: who watched (blocked people left out).
static func story_viewers(actor: Variant, sid: String) -> Array:
	var me := _id(actor)
	var p := _find(sid)
	if p.is_empty() or p["kind"] != "story" or p["author"] != me: return []
	return p.get("viewers", {}).keys().filter(func(v): return not is_blocked(me, v))

## Every story you posted, newest first (live and expired).
static func story_archive(actor: Variant) -> Array:
	var me := _id(actor)
	var out: Array = db()["feed"].filter(func(p): return p["kind"] == "story" and p["author"] == me and p["state"] == "published")
	out.sort_custom(_newer)
	return out.map(func(p): return decorate(me, p))

static func _highlight_put(owner_id: String, name: String, p: Dictionary) -> void:
	var hs: Dictionary = db()["highlights"].get(owner_id, {})
	if not hs.has(name) and hs.size() >= 50: return
	var l: Array = hs.get(name, [])
	if l.any(func(x): return x["id"] == p["id"]) or l.size() >= 100: return
	l.append({"id": p["id"], "text": p["text"], "media": p.get("media", []).duplicate(true), "media_ref": p.get("media_ref", ""),
		"layers": p.get("layers", []).duplicate(true), "t": p["t"], "mature": p.get("mature", false), "visibility": p["visibility"]})
	hs[name] = l
	db()["highlights"][owner_id] = hs

## Keep one of your stories on your profile after it expires.
static func highlight_add(actor: Variant, name: String, sid: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "post"): return _err("Not allowed.")
	var p := _find(sid)
	if p.is_empty() or p["kind"] != "story" or p["author"] != me or p["state"] != "published": return _err("Pick one of your stories.")
	var n := clean(name, 40)
	if n == "": return _err("Name the highlight.")
	var snap := _snap(); _highlight_put(me, n, p)
	return _commit(snap, _ok())

static func highlight_remove(actor: Variant, name: String, sid := "") -> Dictionary:
	var me := _id(actor)
	var hs: Dictionary = db()["highlights"].get(me, {})
	if not hs.has(name): return _err("No such highlight.")
	var snap := _snap()
	if sid == "": hs.erase(name)
	else: hs[name] = (hs[name] as Array).filter(func(x): return x["id"] != sid)
	return _commit(snap, _ok())

## {name: [items]} as the viewer may see them (audience, blocks, account privacy, age gate still apply).
static func highlights(owner_id: String, viewer: Variant = null) -> Dictionary:
	var me := _id(viewer) if viewer != null else owner_id
	if me != owner_id and (is_blocked(me, owner_id) or not _account_ok(owner_id, me)): return {}
	var out := {}
	var hs: Dictionary = db()["highlights"].get(owner_id, {})
	for n in hs:
		var l: Array = (hs[n] as Array).filter(func(x):
			if me == owner_id: return true
			if bool(x.get("mature", false)) and not age_ok(me): return false
			match str(x["visibility"]):
				"friends": return me in friends_of(owner_id)
				"close_friends": return me in db()["close_friends"].get(owner_id, [])
			return true)
		if not l.is_empty(): out[n] = l.duplicate(true)
	return out

# ---------- pages (public pages for projects, venues, brands) ----------
static func page_create(actor: Variant, name: String, opts := {}) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "page_create"): return _err("Creator tier or higher can create pages.")
	var n := clean(name, 60)
	if n == "": return _err("Name the page.")
	for pid in db()["pages"]:
		if str(db()["pages"][pid]["name"]).to_lower() == n.to_lower(): return _err("That name is taken.")
	var snap := _snap()
	var pid := "page:" + _next("")
	db()["pages"][pid] = {"id": pid, "name": n, "category": clean(str(opts.get("category", "")), 40), "about": clean(str(opts.get("about", "")), 1000),
		"owner": me, "admins": [me], "badges": [], "created": _now(), "hidden": false}
	return _commit(snap, _ok({"id": pid}))

static func page_add_admin(actor: Variant, pid: String, who: String, on := true) -> Dictionary:
	var pg: Dictionary = db()["pages"].get(pid, {})
	if pg.is_empty() or pg["owner"] != _id(actor): return _err("Page owner only.")
	if who == pg["owner"]: return _err("The owner stays an admin.")
	var snap := _snap()
	if on and not who in pg["admins"]: pg["admins"].append(who)
	if not on: (pg["admins"] as Array).erase(who)
	return _commit(snap, _ok())

static func page(pid: String, viewer: Variant = null) -> Dictionary:
	var pg: Dictionary = db()["pages"].get(pid, {})
	if pg.is_empty(): return {}
	if bool(pg.get("hidden", false)) and not (viewer != null and Tiers.can(viewer, "moderate")): return {}
	if viewer != null and is_blocked(_id(viewer), pid): return {}
	var out := pg.duplicate(true)
	out["followers"] = followers_of(pid).size()
	return out

static func pages_all() -> Array:
	return db()["pages"].values().filter(func(p): return not bool(p.get("hidden", false))).duplicate(true)

# ---------- events (extends the Social events; merges with the events board later) ----------
## opts: description, end_unix, capacity (0 = no limit), group (gid: you must be an officer),
## page (page id: you must be an admin), visibility public | friends | group, mature.
## Companion-hosted events wait for the owner (MENU > Proposals) like posts.
static func event_create(actor: Variant, title: String, when_unix: int, where: String, opts := {}) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "event_create"): return _err("Creator tier or higher can create events.")
	var t := clean(title, 120)
	if t == "": return _err("Name the event.")
	var now := _now()
	if when_unix < now - 60 or when_unix > now + 730 * 86400: return _err("Pick a time in the next two years.")
	var end := int(opts.get("end_unix", when_unix + 7200))
	if end <= when_unix: return _err("The end must be after the start.")
	var vis := str(opts.get("visibility", "public"))
	var gid := str(opts.get("group", ""))
	if gid != "":
		if not _group_officer(actor, gid): return _err("Group officers only.")
		vis = "group:" + gid
	elif not vis in ["public", "friends"]: return _err("Pick who can see it.")
	var host := me
	if str(opts.get("page", "")) != "":
		var pg: Dictionary = db()["pages"].get(str(opts["page"]), {})
		if pg.is_empty() or not me in pg["admins"]: return _err("Page admins only.")
		host = pg["id"]
	var mature := bool(opts.get("mature", false))
	if mature and not age_ok(me): return _err("Mature events need an age-verified host.")
	var snap := _snap()
	var eid := _next("e")
	var e := {"id": eid, "host": host, "by": me, "title": t, "description": clean(str(opts.get("description", "")), 2000), "start": when_unix, "end": end,
		"where": clean(where, 120), "capacity": clampi(int(opts.get("capacity", 0)), 0, 100000), "visibility": vis, "mature": mature,
		"state": "published", "rsvps": {}, "created": now, "tags": parse_tags(t + " " + str(opts.get("description", "")))}
	if Tiers.is_bot(me):
		e["state"] = "pending_approval"
		e["proposal_id"] = EveCore.for_companion(me).propose_update(EVENT_TAG + eid + ": " + t + " @ " + e["where"])["id"]
	db()["events"][eid] = e
	return _commit(snap, _ok({"id": eid, "state": e["state"]}))

static func _event_visible(e: Dictionary, me: String) -> bool:
	if e["state"] != "published" and not (e["state"] == "cancelled" and e["rsvps"].has(me)): return e["host"] == me or e["by"] == me
	if is_blocked(me, str(e["host"])) or is_blocked(me, str(e["by"])): return false
	if bool(e.get("mature", false)) and not age_ok(me): return false
	var v := str(e["visibility"])
	if v == "friends": return me == e["by"] or me in friends_of(str(e["by"]))
	if v.begins_with("group:"): return is_member(v.substr(6), me)
	return true

## status: going | interested | declined. Capacity applies to "going".
static func event_rsvp(actor: Variant, eid: String, status := "going") -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "event_rsvp"): return _err("Not allowed.")
	if not status in EVENT_RSVP: return _err("Pick going, interested or declined.")
	var e: Dictionary = db()["events"].get(eid, {})
	if e.is_empty() or e["state"] != "published" or not _event_visible(e, me): return _err("No such event.")
	if _now() > int(e["end"]): return _err("This event has ended.")
	if status == "going" and int(e["capacity"]) > 0 and e["rsvps"].get(me, "") != "going" and e["rsvps"].values().count("going") >= int(e["capacity"]): return _err("The event is full.")
	var snap := _snap()
	e["rsvps"][me] = status
	if status == "going": _note(str(e["host"]), "event", "%s is going to %s." % [_name(me), e["title"]], me)
	return _commit(snap, _ok())

static func event_cancel(actor: Variant, eid: String) -> Dictionary:
	var me := _id(actor)
	var e: Dictionary = db()["events"].get(eid, {})
	if e.is_empty(): return _err("No such event.")
	var gid := str(e["visibility"]).substr(6) if str(e["visibility"]).begins_with("group:") else ""
	if e["by"] != me and not Tiers.can(actor, "moderate") and not (gid != "" and _group_officer(actor, gid)): return _err("Host only.")
	var snap := _snap()
	e["state"] = "cancelled"
	for who in e["rsvps"]:
		if e["rsvps"][who] != "declined": _note(who, "event", "%s was cancelled." % e["title"], me)
	return _commit(snap, _ok())

static func _event_view(me: String, e: Dictionary) -> Dictionary:
	var d := e.duplicate(true); d.erase("proposal_id"); d.erase("rsvps")
	d["going"] = e["rsvps"].values().count("going"); d["interested"] = e["rsvps"].values().count("interested")
	d["my_rsvp"] = str(e["rsvps"].get(me, "")); d["host_name"] = _name(str(e["host"]))
	return d

static func event(viewer: Variant, eid: String) -> Dictionary:
	var me := _id(viewer)
	var e: Dictionary = db()["events"].get(eid, {})
	if e.is_empty() or not _event_visible(e, me): return {}
	return _event_view(me, e)

## Upcoming (or all) events you may see, soonest first.
static func events(viewer: Variant, upcoming := true) -> Array:
	var me := _id(viewer)
	if not Tiers.can(viewer, "browse"): return []
	sync_approvals()
	var out: Array = db()["events"].values().filter(func(e): return e["state"] == "published" and _event_visible(e, me) and (not upcoming or int(e["end"]) >= _now()))
	out.sort_custom(func(a, b): return int(a["start"]) < int(b["start"]))
	return out.map(func(e): return _event_view(me, e))

# ---------- search, explore, trending ----------
## kind: all | posts | people | tags | groups | pages | events. "#tag" searches a hashtag exactly.
static func search(viewer: Variant, query: String, kind := "all", limit := 20) -> Dictionary:
	if not Tiers.can(viewer, "browse"): return _err("Not allowed.")
	var me := _id(viewer)
	var q := query.strip_edges().to_lower().left(100)
	if q == "": return _err("Type something to search.")
	var tagq := _norm_tag(q) if q.begins_with("#") else ""
	var out := _ok({"posts": [], "people": [], "tags": [], "groups": [], "pages": [], "events": []})
	var want := func(k: String) -> bool: return kind == "all" or kind == k
	if want.call("posts"):
		var hits: Array = db()["feed"].filter(func(p): return p["kind"] != "story" and p["kind"] != "repost" and not p.has("limited_to") and _visible(p, me) \
			and not (p["author"] != me and is_muted(me, str(p["author"]))) \
			and ((tagq != "" and tagq in p.get("tags", [])) or (tagq == "" and str(p["text"]).to_lower().contains(q))))
		hits.sort_custom(_newer)
		out["posts"] = hits.slice(0, limit).map(func(p): return decorate(me, p))
	if want.call("people"):
		for id in db()["profiles"]:
			var pr: Dictionary = db()["profiles"][id]
			if is_blocked(me, id): continue
			if str(id).to_lower().contains(q) or str(pr["display_name"]).to_lower().contains(q):
				out["people"].append({"id": id, "display_name": pr["display_name"], "badges": badges_of(id), "kind": pr.get("kind", "player")})
			if out["people"].size() >= limit: break
	if want.call("tags"):
		var counts := {}
		var tq := q.trim_prefix("#")
		for p in db()["feed"]:
			if p["kind"] == "story" or not _visible(p, me): continue
			for t in p.get("tags", []):
				if str(t).begins_with(tq): counts[t] = int(counts.get(t, 0)) + 1
		var tl: Array = counts.keys().map(func(t): return {"tag": t, "posts": counts[t]})
		tl.sort_custom(func(a, b): return a["posts"] > b["posts"])
		out["tags"] = tl.slice(0, limit)
	if want.call("groups"):
		for g in db()["groups"].values():
			if str(g["name"]).to_lower().contains(q) and not is_blocked(me, str(g["founder"])) and (not bool(g.get("mature", false)) or age_ok(me)):
				out["groups"].append({"id": g["id"], "name": g["name"], "members": g["members"].size(), "open": g["open"]})
	if want.call("pages"):
		for pg in pages_all():
			if str(pg["name"]).to_lower().contains(q) and not is_blocked(me, str(pg["id"])): out["pages"].append(page(pg["id"]))
	if want.call("events"):
		out["events"] = events(viewer, true).filter(func(e): return str(e["title"]).to_lower().contains(q) or tagq in e.get("tags", [])).slice(0, limit)
	return out

## Hashtags rising in the last `hours`, scored by distinct authors (so one account can't spam a
## tag to the top). Public, unexpired, non-held posts only; age gate applies.
static func trending(viewer: Variant, hours := 24, limit := 10) -> Array:
	if not Tiers.can(viewer, "browse"): return []
	var me := _id(viewer)
	var since := _now() - hours * 3600
	var authors := {}; var posts := {}
	for p in db()["feed"]:
		if int(p["t"]) < since or str(p["visibility"]) != "public" or not _visible(p, me) or p.has("limited_to"): continue
		for t in p.get("tags", []):
			var s: Dictionary = authors.get(t, {}); s[p["author"]] = true; authors[t] = s
			posts[t] = int(posts.get(t, 0)) + 1
	var out: Array = authors.keys().map(func(t): return {"tag": t, "authors": authors[t].size(), "posts": posts[t], "score": authors[t].size() * 10 + mini(posts[t], authors[t].size() * 3)})
	out.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and str(a["tag"]) < str(b["tag"])))
	return out.slice(0, limit)

## Explore = the ranked feed of public posts from people you don't follow yet.
static func explore(viewer: Variant, cursor := "") -> Dictionary: return feed_page(viewer, cursor if cursor != "" else "explore")

# ---------- context notes (community-rated context on posts) ----------
## Anyone Resident+ can add one note per post (not on their own). A note shows once it has
## >= 3 "helpful" ratings, >= 2/3 helpful overall, and two helpful raters who don't follow each
## other (a light "bridging" check so one circle of friends can't push a note alone).
static func note_add(actor: Variant, pid: String, text: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "post"): return _err("Not allowed.")
	var p := _find(pid)
	if p.is_empty() or not _visible(p, me) or p["author"] == me: return _err("Can't add a note there.")
	var body := clean(text, 500)
	if body == "": return _err("Write the note.")
	var l: Array = db()["context_notes"].get(pid, [])
	if l.any(func(n): return n["by"] == me): return _err("One note per post.")
	var snap := _snap()
	var nid := _next("n")
	l.append({"id": nid, "pid": pid, "by": me, "text": body, "t": _now(), "ratings": {}})
	db()["context_notes"][pid] = l
	return _commit(snap, _ok({"id": nid}))

static func note_rate(actor: Variant, nid: String, helpful: bool) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "follow"): return _err("Not allowed.")
	for pid in db()["context_notes"]:
		for n in db()["context_notes"][pid]:
			if n["id"] == nid:
				var p := _find(pid)
				if n["by"] == me or (not p.is_empty() and p["author"] == me): return _err("You can't rate this note.")
				var snap := _snap(); n["ratings"][me] = helpful
				return _commit(snap, _ok())
	return _err("No such note.")

static func _note_shown(n: Dictionary) -> bool:
	var yes: Array = []
	for r in n["ratings"]:
		if bool(n["ratings"][r]): yes.append(r)
	var total: int = n["ratings"].size()
	if yes.size() < 3 or yes.size() * 3 < total * 2: return false
	for i in yes.size():
		for j in range(i + 1, yes.size()):
			if not is_following(yes[i], yes[j]) and not is_following(yes[j], yes[i]) and not yes[j] in friends_of(yes[i]): return true
	return false

static func context_notes(viewer: Variant, pid: String, include_pending := false) -> Array:
	var out: Array = []
	for n in db()["context_notes"].get(pid, []):
		if include_pending or _note_shown(n): out.append({"id": n["id"], "text": n["text"], "t": n["t"], "shown": _note_shown(n)})
	return out

# ---------- creator analytics ----------
## Your own numbers (the unlocked owner can read anyone's; page admins read their page's).
static func analytics(actor: Variant, id := "") -> Dictionary:
	var me := _id(actor)
	var who := me if id == "" else id
	var page_admin: bool = who.begins_with("page:") and me in db()["pages"].get(who, {}).get("admins", [])
	if who != me and not page_admin and Tiers.tier_of(actor) != "owner": return _err("Not allowed.")
	var mine: Array = db()["feed"].filter(func(p): return p["author"] == who and p["state"] == "published" and p["kind"] != "repost")
	var ctx := _rank_ctx("")
	var uniq := {}; var views := 0; var reacts := 0; var reposts := 0; var replies := 0; var quotes := 0; var bms := 0
	var watch_pct: Array = []; var story_views := 0
	var top: Array = []
	for p in mine:
		var id2 := str(p["id"])
		views += int(p.get("views_total", 0))
		for v in p.get("viewers", {}): uniq[v] = true
		var r := _reaction_total(p); reacts += r
		reposts += (p.get("reposts", []) as Array).size()
		replies += int(ctx["replies"].get(id2, 0)); quotes += int(ctx["quotes"].get(id2, 0)); bms += int(ctx["bm"].get(id2, 0))
		if p["kind"] == "story": story_views += p.get("viewers", {}).size()
		if p["kind"] == "clip" and float(p.get("duration_s", 0)) > 0.0:
			for v in p.get("viewers", {}): watch_pct.append(minf(1.0, float(p["viewers"][v]["ms"]) / (float(p["duration_s"]) * 1000.0)))
		top.append({"id": id2, "text": str(p["text"]).left(80), "kind": p["kind"], "engagement": r + 2 * int(ctx["replies"].get(id2, 0)) + 3 * (p.get("reposts", []) as Array).size()})
	top.sort_custom(func(a, b): return a["engagement"] > b["engagement"])
	var week := _now() - 7 * 86400
	var gained := 0
	for k in db()["follow_t"]:
		if str(k).ends_with(">" + who) and int(db()["follow_t"][k]) >= week: gained += 1
	var avg := 0.0
	for w in watch_pct: avg += w
	return _ok({"id": who, "posts": mine.size(), "views": views, "reach": uniq.size(), "reactions": reacts, "replies": replies,
		"reposts": reposts, "quotes": quotes, "bookmarks": bms, "story_views": story_views, "followers": followers_of(who).size(),
		"followers_7d": gained, "clip_avg_watch": avg / watch_pct.size() if not watch_pct.is_empty() else 0.0, "top": top.slice(0, 5)})

static func post_insights(actor: Variant, pid: String) -> Dictionary:
	var me := _id(actor)
	var p := _find(pid)
	if p.is_empty() or (p["author"] != me and str(p.get("by", "")) != me and Tiers.tier_of(actor) != "owner"): return _err("Not allowed.")
	var ctx := _rank_ctx("")
	var w: Array = []
	if p["kind"] == "clip" and float(p.get("duration_s", 0)) > 0.0:
		for v in p.get("viewers", {}): w.append(minf(1.0, float(p["viewers"][v]["ms"]) / (float(p["duration_s"]) * 1000.0)))
	var avg := 0.0
	for x in w: avg += x
	return _ok({"views": int(p.get("views_total", 0)), "reach": p.get("viewers", {}).size(), "reactions": _reaction_total(p),
		"replies": int(ctx["replies"].get(pid, 0)), "reposts": (p.get("reposts", []) as Array).size(), "quotes": int(ctx["quotes"].get(pid, 0)),
		"bookmarks": int(ctx["bm"].get(pid, 0)), "remixes": (p.get("remixes", []) as Array).size(), "avg_watch": avg / w.size() if not w.is_empty() else 0.0})

# ---------- sounds (clip audio as data) ----------
static func sound(sid: String) -> Dictionary: return db()["sounds"].get(sid, {}).duplicate(true)

## Most-used sounds among clips you can see.
static func sounds_top(viewer: Variant, limit := 10) -> Array:
	var me := _id(viewer)
	var n := {}
	for p in db()["feed"]:
		if p["kind"] == "clip" and p.has("sound_id") and _visible(p, me): n[p["sound_id"]] = int(n.get(p["sound_id"], 0)) + 1
	var out: Array = []
	for sid in n:
		var d := sound(sid); d["clips"] = n[sid]; out.append(d)
	out.sort_custom(func(a, b): return a["clips"] > b["clips"])
	return out.slice(0, limit)

static func remixes_of(viewer: Variant, pid: String) -> Array:
	var me := _id(viewer)
	var p := _find(pid)
	if p.is_empty() or not _visible(p, me): return []
	var out: Array = []
	for rid in p.get("remixes", []):
		var r := _find(str(rid))
		if not r.is_empty() and _visible(r, me): out.append(decorate(me, r))
	return out

# ---------- reports + moderation queue ----------
const _POSTISH := ["post", "story", "clip", "reply"]

## kind: see REPORT_KINDS. Anyone (even guests) can report, once per target while it's open.
## evidence: optional {text, from, t} snapshot (SocialDM.report_message fills it for DMs, so
## moderators see only the reported message, never the rest of the chat).
## REPORT_HOLD distinct open reports on a post/story/clip/reply auto-hold it ("held": hidden from
## everyone but its author) until a moderator decides.
static func report(actor: Variant, kind: String, target_id: String, reason: String, evidence := {}) -> Dictionary:
	if not Tiers.can(actor, "report"): return _err("Not allowed.")
	if not kind in REPORT_KINDS or target_id == "": return _err("Pick what to report.")
	var me := _id(actor)
	for r in db()["reports"]:
		if r["reporter"] == me and r["target"] == target_id and r["kind"] == kind and r["state"] == "open": return _err("You already reported this.")
	var snap := _snap()
	var r := {"id": _next("r"), "reporter": me, "kind": kind, "target": target_id, "reason": clean(reason, 500), "state": "open", "t": _now()}
	if not evidence.is_empty():
		r["evidence"] = {"text": clean(str(evidence.get("text", "")), 1000), "from": clean(str(evidence.get("from", "")), 80), "t": int(evidence.get("t", 0))}
	db()["reports"].append(r)
	var held := false
	if kind in _POSTISH:
		var p := _find(target_id)
		if not p.is_empty() and p["state"] == "published":
			var who := {}
			for x in db()["reports"]:
				if x["target"] == target_id and x["state"] == "open" and x["kind"] in _POSTISH: who[x["reporter"]] = true
			if who.size() >= REPORT_HOLD: p["state"] = "held"; p["held_at"] = _now(); held = true
	var res := _commit(snap, _ok({"id": r["id"], "held": held}))
	if res["ok"]:
		for h in report_hooks:
			if h is Callable and (h as Callable).is_valid(): (h as Callable).call(r.duplicate(true))
	return res

## Moderators only (staff, estate managers, unlocked owner).
static func reports(actor: Variant, state := "open") -> Array:
	if not Tiers.can(actor, "moderate"): return []
	return db()["reports"].filter(func(r): return state == "" or r["state"] == state).duplicate(true)

## Open reports grouped by target, held items first, then most-reported:
## [{kind, target, count, report_id, reasons, held, snippet, mature, author}]
static func moderation_queue(actor: Variant) -> Array:
	if not Tiers.can(actor, "moderate"): return []
	var by := {}
	for r in db()["reports"]:
		if r["state"] != "open": continue
		var k := str(r["kind"]) + "|" + str(r["target"])
		if not by.has(k):
			var item := {"kind": r["kind"], "target": r["target"], "count": 0, "report_id": r["id"], "reasons": [], "held": false, "snippet": "", "mature": false, "author": ""}
			if r["kind"] in _POSTISH:
				var p := _find(str(r["target"]))
				if not p.is_empty():
					item["held"] = p["state"] == "held"; item["snippet"] = str(p["text"]).left(140); item["mature"] = bool(p.get("mature", false)); item["author"] = p["author"]
			elif r["kind"] == "event" and db()["events"].has(r["target"]): item["snippet"] = str(db()["events"][r["target"]]["title"])
			elif r.has("evidence"): item["snippet"] = str(r["evidence"]["text"]).left(140); item["author"] = r["evidence"]["from"]
			by[k] = item
		by[k]["count"] += 1
		if str(r["reason"]) != "" and by[k]["reasons"].size() < 5: by[k]["reasons"].append(r["reason"])
	var out: Array = by.values()
	out.sort_custom(func(a, b): return a["held"] and not b["held"] or (a["held"] == b["held"] and a["count"] > b["count"]))
	return out

## decision: hide (hide the post/story/clip/reply/event/page; profile: clear "about"),
## mature (label it mature: age-gated from then on, and released if it was held),
## restore (un-hide / release a held item), dismiss (no action; releases a held item).
## Every open report on the same target closes with the decision. Logged in modlog().
static func moderate(actor: Variant, report_id: String, decision: String) -> Dictionary:
	if not Tiers.can(actor, "moderate"): return _err("Moderators only.")
	if not decision in ["hide", "dismiss", "mature", "restore"]: return _err("Unknown decision.")
	for r in db()["reports"]:
		if r["id"] == report_id and r["state"] == "open":
			var snap := _snap()
			var tgt := str(r["target"]); var kind := str(r["kind"])
			var p := _find(tgt) if kind in _POSTISH else {}
			var e: Dictionary = db()["events"].get(tgt, {}) if kind == "event" else {}
			match decision:
				"hide":
					if not p.is_empty(): p["state"] = "hidden"; _note(str(p["author"]), "moderation", "A moderator hid one of your posts.")
					elif not e.is_empty(): e["state"] = "hidden"
					elif kind == "page" and db()["pages"].has(tgt): db()["pages"][tgt]["hidden"] = true
					elif kind == "profile" and db()["profiles"].has(tgt):
						if tgt == Tiers.OWNER_ID and Tiers.tier_of(actor) != "owner": return _err("Only the owner can change the owner profile.")
						db()["profiles"][tgt]["about"] = ""
				"mature":
					if not p.is_empty():
						p["mature"] = true
						if p["state"] == "held": p["state"] = "published"
						_note(str(p["author"]), "moderation", "A moderator labelled one of your posts mature.")
					elif not e.is_empty(): e["mature"] = true
					elif kind == "group" and db()["groups"].has(tgt): db()["groups"][tgt]["mature"] = true
					else: return _err("Only posts, events and groups take a mature label.")
				"restore", "dismiss":
					if not p.is_empty() and (p["state"] == "held" or (decision == "restore" and p["state"] == "hidden")): p["state"] = "published"
					elif decision == "restore" and not e.is_empty() and e["state"] == "hidden": e["state"] = "published"
					elif decision == "restore" and kind == "page" and db()["pages"].has(tgt): db()["pages"][tgt]["hidden"] = false
			var closed := "dismissed" if decision == "dismiss" else "actioned"
			for x in db()["reports"]:
				if x["state"] == "open" and x["target"] == tgt and (x["kind"] == kind or (kind in _POSTISH and x["kind"] in _POSTISH)):
					x["state"] = closed; x["by"] = _id(actor); x["decided"] = _now(); x["decision"] = decision
			_log(actor, "moderate_" + decision, kind + ":" + tgt)
			return _commit(snap, _ok())
	return _err("No open report with that id.")

static func _log(actor: Variant, action: String, target: String) -> void:
	db()["modlog"].append({"t": _now(), "by": _id(actor), "action": action, "target": clean(target, 120)})
	if db()["modlog"].size() > 500: db()["modlog"].pop_front()

## Staff + unlocked owner.
static func modlog(actor: Variant) -> Array:
	if not Tiers.can(actor, "moderate"): return []
	return db()["modlog"].duplicate(true)

# ---------- membership hooks ----------
static func membership_of(id: String) -> Dictionary:
	var t := Tiers.assigned_tier(id)
	var m := Tiers.membership(t).duplicate()
	m["tier"] = t; m["label"] = Tiers.label(t)
	return m

static func stats() -> Dictionary:
	var pub := 0; var held := 0; var stories := 0; var clips := 0; var sched := 0
	for p in db()["feed"]:
		match str(p["state"]):
			"published":
				pub += 1
				if p["kind"] == "story" and not _expired(p): stories += 1
				if p["kind"] == "clip": clips += 1
			"held": held += 1
			"scheduled": sched += 1
	return {"members": db()["profiles"].size(), "groups": db()["groups"].size(), "posts": pub,
		"pending_posts": pending_posts().size(), "open_reports": db()["reports"].filter(func(r): return r["state"] == "open").size(),
		"queued_messages": db()["outbox"].size(), "held_posts": held, "live_stories": stories, "clips": clips, "scheduled": sched,
		"pages": db()["pages"].size(), "events": db()["events"].values().filter(func(e): return e["state"] == "published").size()}

static func _name(id: String) -> String:
	if id.begins_with("page:"): return str(db()["pages"].get(id, {}).get("name", id))
	return str(db()["profiles"].get(id, {}).get("display_name", id))

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
## (Events and polls went live on 2026-10-17, SMP-*; their stubs are gone.)
static func _inactive(actor: Variant, action: String, what: String) -> Dictionary:
	if not Tiers.can(actor, action): return _err("Not allowed.")
	return {"ok": false, "error": "INACTIVE", "roadmap": what}

static func forum_post(actor: Variant, _forum: String, _title: String, _text: String) -> Dictionary: return _inactive(actor, "forum_post", "Forums: topics + replies, moderation queue (Phase 2).")
static func blog_post(actor: Variant, _title: String, _text: String) -> Dictionary: return _inactive(actor, "blog_post", "Blogs on profiles (Phase 2).")
static func album_add(actor: Variant, _album: String, _media_ref: String) -> Dictionary: return _inactive(actor, "album", "Photo/video albums incl. in-world snapshots (Phase 2; needs media storage + upload review). Single photos/carousels already post via Social.post(kind photo) + MediaTools.")
static func classified_post(actor: Variant, _title: String, _text: String, _slot: String) -> Dictionary: return _inactive(actor, "classified", "Classifieds tied to ad slots; Aethel Coin pricing needs LEGAL REVIEW (Phase 3).")
## INACTIVE: outbound cross-posting to outside networks. Off by default; see SOCIAL_MEDIA_PARITY.md
## "Export / cross-post adapters". Would need the owner's approval per post, every time.
static func cross_post(actor: Variant, _pid: String, _network: String) -> Dictionary: return _inactive(actor, "admin", "Cross-post adapters (export only, owner-approved per post, off by default). Not built.")

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _db = null
