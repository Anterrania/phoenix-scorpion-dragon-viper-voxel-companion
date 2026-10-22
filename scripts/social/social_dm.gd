class_name SocialDM
extends RefCounted
## Viper OS direct messages (docs/modules/SOCIAL.md "DMs", SMP-DM). Clean-room, our own GDScript.
## One-to-one and group chats, message requests, reactions, replies, edit/unsend, read receipts,
## disappearing messages, shared posts, story / ghost-post replies, and DM reports.
##
## Privacy + storage:
## - Saved to user://social/dm.json through SecureFile, so it is AES-256 sealed with the OwnerVault
##   data key (CryptoBox: encrypt-then-MAC). Locked + sealed: nothing reads, writes are refused.
## - STRICTER than the rest of Social: with no OwnerVault on this phone, DMs are kept in memory only
##   and never written in plaintext. They persist (encrypted) as soon as a vault is set up.
## - Notifications never include message text ("New message from X").
## - Disappearing messages are deleted from the store (not just hidden) once they expire.
## - Moderators never browse chats. A member can report one message; only that message is copied
##   into the report as evidence (Social.report).
## Every call checks Tiers.can(actor, "message") (or "browse" for reading). Blocks always apply.
## The e-stop stops companions sending. Companion DMs are private, so no owner approval is needed;
## anything public a companion does still goes through Social.post -> owner approval.

const MAX_TEXT := 2000
const MAX_MSGS := 500            # per conversation (oldest drop off)
const MAX_GROUP := 32
const REQUEST_MAX := 3           # messages you can send before a request is accepted
const EDIT_WINDOW := 900         # 15 min
const DISAPPEAR_CHOICES := [0, 300, 3600, 86400, 604800]   # off, 5 min, 1 h, 24 h, 7 days

static var root := "user://social"
static var _db = null
static var _mem_only := false
static var _hooked := false

static func _path() -> String: return root.path_join("dm.json")

static func db() -> Dictionary:
	if not _hooked:
		_hooked = true
		OwnerVault.on_storage_ready.append(_on_storage_ready)
	if _db == null:
		_mem_only = not OwnerVault.has_vault()
		var d: Variant = {} if _mem_only else SecureFile.read_json(_path(), {})
		_db = d if d is Dictionary else {}
		if not _db.has("convos"): _db["convos"] = {}
		if not _db.has("seq"): _db["seq"] = 0
	return _db

## A vault was just set up or unlocked: memory-only chats get written (sealed); otherwise reload.
static func _on_storage_ready() -> void:
	if _db != null and _mem_only:
		var mem: Dictionary = _db
		_db = null
		var disk := db()
		if disk["convos"].is_empty(): _db = mem; _save()
	else: _db = null

static func encrypted_at_rest() -> bool: return OwnerVault.has_vault()

static func _save() -> bool:
	if not OwnerVault.has_vault(): _mem_only = true; return true   # memory only, never plaintext on disk
	return SecureFile.write_json(_path(), db())

static func _snap() -> Dictionary: return db().duplicate(true)
static func _commit(rollback: Dictionary, result: Dictionary) -> Dictionary:
	if _save(): return result
	_db = rollback
	return _err("Messages are sealed. Unlock first.")
static func _ok(extra := {}) -> Dictionary:
	var r := {"ok": true, "error": ""}; r.merge(extra); return r
static func _err(e: String) -> Dictionary: return {"ok": false, "error": e}
static func _now() -> int: return Social._now()
static func _id(a: Variant) -> String: return Tiers.actor_id(a)
static func _next(prefix: String) -> String:
	db()["seq"] = int(db()["seq"]) + 1
	return "%s%d" % [prefix, db()["seq"]]

static func _convo(cid: String) -> Dictionary: return db()["convos"].get(cid, {})
static func _member(c: Dictionary, me: String) -> bool: return not c.is_empty() and me in c["members"] and c["state_for"].get(me, "") != "left"

## Where a new chat from `from` lands for `to`: inbox | request | hidden_request | "" (refused).
static func _landing(from: String, to: String, first_text := "") -> String:
	if Social.is_blocked(from, to): return ""
	var pv := Social.privacy_of(to)
	var friends := from in Social.friends_of(to)
	var follows := Social.is_following(to, from)
	if Social.is_restricted(to, from): return "request"
	var rule := str(pv["dm"])
	if rule == "nobody": return "inbox" if friends else ""
	if (rule == "friends" and not friends) or (rule == "following" and not (friends or follows)):
		return "hidden_request" if Social.hidden_word_hit(to, first_text) else "request"
	return "inbox"

## Open (or find) the one-to-one chat with `to`. {ok, id}
static func open_direct(actor: Variant, to: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "message"): return _err("Not allowed.")
	if to == "" or to == me: return _err("Pick someone else.")
	if not Social.db()["profiles"].has(to): return _err("No such member.")
	if Social.is_blocked(me, to): return _err("Not available.")
	for cid in db()["convos"]:
		var c: Dictionary = db()["convos"][cid]
		if c["kind"] == "direct" and me in c["members"] and to in c["members"]:
			if c["state_for"].get(me, "") == "left": c["state_for"][me] = "inbox"
			return _ok({"id": cid})
	var land := _landing(me, to)
	if land == "": return _err("They aren't taking messages.")
	var snap := _snap()
	var cid := _next("c")
	db()["convos"][cid] = {"id": cid, "kind": "direct", "members": [me, to], "admins": [], "name": "", "by": me, "created": _now(),
		"disappear_s": 0, "state_for": {me: "inbox", to: land}, "msgs": [], "read": {}, "muted": [], "pending_from": me if land != "inbox" else ""}
	return _commit(snap, _ok({"id": cid}))

## Group chat (<= MAX_GROUP). Members who don't follow / friend you get it as a request.
static func group_create(actor: Variant, name: String, members: Array) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "message"): return _err("Not allowed.")
	var ms: Array = [me]
	for m in members:
		var s := str(m)
		if s != "" and s != me and not s in ms and Social.db()["profiles"].has(s) and _landing(me, s) != "": ms.append(s)
	if ms.size() < 2: return _err("Add at least one person who takes messages.")
	if ms.size() > MAX_GROUP: return _err("Groups hold up to %d." % MAX_GROUP)
	var snap := _snap()
	var cid := _next("c")
	var st := {me: "inbox"}
	for m in ms:
		if m != me: st[m] = "inbox" if _landing(me, m) == "inbox" else "request"
	db()["convos"][cid] = {"id": cid, "kind": "group", "members": ms, "admins": [me], "name": Social.clean(name, 60), "by": me, "created": _now(),
		"disappear_s": 0, "state_for": st, "msgs": [], "read": {}, "muted": [], "pending_from": ""}
	_system(db()["convos"][cid], "%s started the chat." % Social._name(me))
	return _commit(snap, _ok({"id": cid}))

static func _system(c: Dictionary, text: String) -> void:
	c["msgs"].append({"id": _next("m"), "from": "system", "kind": "system", "text": Social.clean(text, 200), "t": _now(), "reactions": {}, "expires": 0})

## opts: reply_to (message id), media_ref, kind (text | post_share | story_reply | ghost_reply), ref.
static func send(actor: Variant, cid: String, text: String, opts := {}) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "message"): return _err("Not allowed.")
	purge_expired()
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	var body := Social.clean(text, MAX_TEXT)
	var media := Social.clean(str(opts.get("media_ref", "")), 200)
	if body == "" and media == "" and str(opts.get("ref", "")) == "": return _err("Write a message.")
	var others: Array = c["members"].filter(func(m): return m != me and c["state_for"].get(m, "") != "left")
	if c["kind"] == "direct":
		if others.is_empty() or Social.is_blocked(me, others[0]): return _err("Not available.")
		var st: String = c["state_for"][others[0]]
		if st in ["request", "hidden_request"]:
			var sent: int = c["msgs"].filter(func(m): return m["from"] == me).size()
			if sent >= REQUEST_MAX: return _err("Wait for them to accept your request.")
			if c["msgs"].is_empty() and Social.hidden_word_hit(others[0], body): c["state_for"][others[0]] = "hidden_request"
	var snap := _snap()
	var m := {"id": _next("m"), "from": me, "kind": str(opts.get("kind", "text")), "text": body, "media_ref": media,
		"ref": Social.clean(str(opts.get("ref", "")), 80), "reply_to": str(opts.get("reply_to", "")), "t": _now(), "reactions": {},
		"expires": _now() + int(c["disappear_s"]) if int(c["disappear_s"]) > 0 else 0, "edited": false, "unsent": false}
	c["msgs"].append(m)
	if c["msgs"].size() > MAX_MSGS: c["msgs"].pop_front()
	c["read"][me] = m["id"]
	for o in others:
		if c["state_for"].get(o) == "inbox" and not o in c["muted"]: Social._note(o, "message", "New message from %s." % Social._name(me), me)
	var res := _commit(snap, _ok({"id": m["id"]}))
	if res["ok"]: Social._save()
	return res

## Messages oldest first (expired ones are purged first). Unsent ones come back as placeholders.
static func messages(actor: Variant, cid: String, limit := 50) -> Array:
	var me := _id(actor)
	if not Tiers.can(actor, "browse"): return []
	purge_expired()
	var c := _convo(cid)
	if not _member(c, me): return []
	var out: Array = []
	for m in c["msgs"]:
		if m["from"] != "system" and m["from"] != me and Social.is_blocked(me, str(m["from"])): continue
		var d: Dictionary = m.duplicate(true)
		if bool(m.get("unsent", false)): d["text"] = ""; d["media_ref"] = ""
		out.append(d)
	return out.slice(maxi(0, out.size() - limit))

## folder: inbox | requests | hidden. [{id, kind, name, members, last, unread, disappear_s}]
static func conversations(actor: Variant, folder := "inbox") -> Array:
	var me := _id(actor)
	purge_expired()
	var want: Array = {"inbox": ["inbox"], "requests": ["request"], "hidden": ["hidden_request"]}.get(folder, ["inbox"])
	var out: Array = []
	for cid in db()["convos"]:
		var c: Dictionary = db()["convos"][cid]
		if not me in c["members"] or not str(c["state_for"].get(me, "")) in want: continue
		var msgs: Array = c["msgs"].filter(func(m): return not bool(m.get("unsent", false)))
		var last: Dictionary = msgs[-1] if not msgs.is_empty() else {}
		out.append({"id": cid, "kind": c["kind"], "name": c["name"] if c["kind"] == "group" else Social._name(str(c["members"].filter(func(x): return x != me)[0])),
			"members": c["members"].duplicate(), "last": str(last.get("text", "")).left(80), "last_t": int(last.get("t", c["created"])),
			"unread": unread(me, c), "disappear_s": c["disappear_s"], "muted": me in c["muted"]})
	out.sort_custom(func(a, b): return a["last_t"] > b["last_t"])
	return out

static func _seq_of(mid: String) -> int: return int(mid.substr(1)) if mid.length() > 1 else 0

static func unread(me: String, c: Dictionary) -> int:
	var last := _seq_of(str(c["read"].get(me, "")))
	return c["msgs"].filter(func(m): return m["from"] != me and m["from"] != "system" and _seq_of(str(m["id"])) > last).size()

static func accept_request(actor: Variant, cid: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if c.is_empty() or not str(c["state_for"].get(me, "")) in ["request", "hidden_request"]: return _err("No such request.")
	var snap := _snap(); c["state_for"][me] = "inbox"; c["pending_from"] = ""
	return _commit(snap, _ok())

static func decline_request(actor: Variant, cid: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if c.is_empty() or not str(c["state_for"].get(me, "")) in ["request", "hidden_request"]: return _err("No such request.")
	var snap := _snap(); c["state_for"][me] = "left"
	return _commit(snap, _ok())

## Read receipts: marks everything up to now as read for you.
static func mark_read(actor: Variant, cid: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	if c["msgs"].is_empty(): return _ok()
	var snap := _snap(); c["read"][me] = c["msgs"][-1]["id"]
	return _commit(snap, _ok())

## Who has read message `mid`. Members with read receipts off are never listed, and if YOU turned
## read receipts off you don't see anyone's (fair both ways). Restricted members see none of yours.
static func receipts(actor: Variant, cid: String, mid: String) -> Array:
	var me := _id(actor)
	var c := _convo(cid)
	if not _member(c, me) or not bool(Social.privacy_of(me)["read_receipts"]): return []
	var n := _seq_of(mid)
	var out: Array = []
	for m in c["members"]:
		if m == me or not bool(Social.privacy_of(m)["read_receipts"]) or Social.is_restricted(m, me): continue
		if _seq_of(str(c["read"].get(m, ""))) >= n: out.append(m)
	return out

## One reaction per member per message; "" removes yours.
static func react(actor: Variant, cid: String, mid: String, emoji: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "message"): return _err("Not allowed.")
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	for m in c["msgs"]:
		if m["id"] == mid and not bool(m.get("unsent", false)):
			var snap := _snap()
			var e := Social.clean(emoji, 8)
			if e == "": m["reactions"].erase(me)
			else: m["reactions"][me] = e
			return _commit(snap, _ok())
	return _err("No such message.")

## Unsend: removes the text + media for everyone (a placeholder stays so replies still make sense).
static func unsend(actor: Variant, cid: String, mid: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	for m in c["msgs"]:
		if m["id"] == mid and m["from"] == me:
			var snap := _snap(); m["text"] = ""; m["media_ref"] = ""; m["unsent"] = true; m["reactions"] = {}
			return _commit(snap, _ok())
	return _err("You can only unsend your own messages.")

static func edit(actor: Variant, cid: String, mid: String, text: String) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "message"): return _err("Not allowed.")
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	var body := Social.clean(text, MAX_TEXT)
	if body == "": return _err("Write a message.")
	for m in c["msgs"]:
		if m["id"] == mid and m["from"] == me and not bool(m.get("unsent", false)):
			if _now() - int(m["t"]) > EDIT_WINDOW: return _err("Messages can be edited for 15 minutes.")
			var snap := _snap(); m["text"] = body; m["edited"] = true
			return _commit(snap, _ok())
	return _err("You can only edit your own messages.")

## seconds: one of DISAPPEAR_CHOICES (0 = off). Applies to new messages. Group chats: admins only.
static func set_disappearing(actor: Variant, cid: String, seconds: int) -> Dictionary:
	var me := _id(actor)
	if not Tiers.can(actor, "message"): return _err("Not allowed.")
	if not seconds in DISAPPEAR_CHOICES: return _err("Pick off, 5 min, 1 h, 24 h or 7 days.")
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	if c["kind"] == "group" and not me in c["admins"]: return _err("Group admins only.")
	var snap := _snap()
	c["disappear_s"] = seconds
	_system(c, "%s turned disappearing messages %s." % [Social._name(me), "off" if seconds == 0 else "on"])
	return _commit(snap, _ok())

## Deletes expired disappearing messages for good. Returns how many.
static func purge_expired() -> int:
	var now := _now(); var n := 0
	for cid in db()["convos"]:
		var c: Dictionary = db()["convos"][cid]
		var keep: Array = c["msgs"].filter(func(m): return int(m.get("expires", 0)) == 0 or int(m["expires"]) > now)
		n += c["msgs"].size() - keep.size()
		c["msgs"] = keep
	if n > 0: _save()
	return n

static func group_add(actor: Variant, cid: String, who: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if c.is_empty() or c["kind"] != "group" or not me in c["admins"] or not _member(c, me): return _err("Group admins only.")
	if c["members"].size() >= MAX_GROUP: return _err("Groups hold up to %d." % MAX_GROUP)
	if not Social.db()["profiles"].has(who) or _landing(me, who) == "": return _err("They aren't taking messages.")
	var snap := _snap()
	if not who in c["members"]: c["members"].append(who)
	c["state_for"][who] = "inbox" if _landing(me, who) == "inbox" else "request"
	_system(c, "%s added %s." % [Social._name(me), Social._name(who)])
	return _commit(snap, _ok())

static func group_remove(actor: Variant, cid: String, who: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if c.is_empty() or c["kind"] != "group" or not me in c["admins"]: return _err("Group admins only.")
	if not who in c["members"] or who == me: return _err("Not in this chat.")
	var snap := _snap()
	c["state_for"][who] = "left"; c["admins"].erase(who)
	_system(c, "%s removed %s." % [Social._name(me), Social._name(who)])
	return _commit(snap, _ok())

static func group_admin(actor: Variant, cid: String, who: String, on := true) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if c.is_empty() or c["kind"] != "group" or not me in c["admins"] or not _member(c, who): return _err("Group admins only.")
	var snap := _snap()
	if on and not who in c["admins"]: c["admins"].append(who)
	if not on and who != me: c["admins"].erase(who)
	return _commit(snap, _ok())

static func group_rename(actor: Variant, cid: String, name: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if c.is_empty() or c["kind"] != "group" or not _member(c, me): return _err("No such chat.")
	var snap := _snap(); c["name"] = Social.clean(name, 60)
	return _commit(snap, _ok())

static func leave(actor: Variant, cid: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	var snap := _snap()
	c["state_for"][me] = "left"; c["admins"].erase(me)
	if c["kind"] == "group":
		_system(c, "%s left." % Social._name(me))
		var rest: Array = c["members"].filter(func(m): return c["state_for"].get(m) != "left")
		if c["admins"].is_empty() and not rest.is_empty(): c["admins"].append(rest[0])
	return _commit(snap, _ok())

static func mute(actor: Variant, cid: String, on := true) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	var snap := _snap()
	if on and not me in c["muted"]: c["muted"].append(me)
	if not on: c["muted"].erase(me)
	return _commit(snap, _ok())

## Share a post into a chat (only if you can see it; recipients still need to be able to see it).
static func share_post(actor: Variant, cid: String, pid: String, text := "") -> Dictionary:
	if not Social.can_see(actor, pid): return _err("No such post.")
	return send(actor, cid, text, {"kind": "post_share", "ref": pid})

## Reply to a story or a ghost post: it goes to the author's DMs (story_replies privacy applies).
static func post_reply_dm(actor: Variant, pid: String, text: String) -> Dictionary:
	var me := _id(actor)
	var p := Social._find(pid)
	if p.is_empty() or not Social.can_see(actor, pid) or not (p["kind"] == "story" or bool(p.get("ghost", false))): return _err("Can't reply to that.")
	var author := str(p["author"])
	if author == me: return _err("That's yours.")
	var sr := str(Social.privacy_of(author)["story_replies"])
	if sr == "off" or (sr == "following" and not Social.is_following(author, me) and not me in Social.friends_of(author)): return _err("Replies are off.")
	var o := open_direct(actor, author)
	if not o["ok"]: return o
	return send(actor, o["id"], text, {"kind": "story_reply" if p["kind"] == "story" else "ghost_reply", "ref": pid})

## Report one message. Only that message (text, sender, time) goes to the moderators.
static func report_message(actor: Variant, cid: String, mid: String, reason: String) -> Dictionary:
	var me := _id(actor)
	var c := _convo(cid)
	if not _member(c, me): return _err("No such chat.")
	for m in c["msgs"]:
		if m["id"] == mid and m["from"] != me and m["from"] != "system":
			return Social.report(actor, "dm", cid + "/" + mid, reason, {"text": m["text"], "from": m["from"], "t": m["t"]})
	return _err("Pick someone else's message.")

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _db = null; _mem_only = false
