class_name ModerationLists
extends RefCounted
## Viewer parity (VIEWER-3): your own safety lists, like the Firestorm Block List and Asset Blacklist.
## Clean-room (concepts only). Per viewer (Tiers.actor_id), so a shared phone keeps separate lists.
##   mute     - hide one person, object or group from you, per channel: chat, im, voice, sounds,
##              particles. Nobody is told.
##   block    - mute everything + Social.block (unfriends, unfollows, stops messages). Unblock undoes both.
##   derender - stop drawing an avatar / object / sound / particle source for you only.
##              permanent: saved (Asset Blacklist). temporary: memory only, cleared on teleport when
##              rerender_after_tp is on (default, like the viewer preference) or by Clear temporary.
## Never needs a tier: safety lists work for guests and a locked owner too (same rule as Social.block).
## Saved through SecureFile at <root>/moderation.json (encrypted once an OwnerVault exists).

const KINDS := ["avatar", "object", "group", "sound", "particle"]
const CHANNELS := ["chat", "im", "voice", "sounds", "particles"]
const MAX_ENTRIES := 1000

static var root := "user://social"
static var _db = null
static var _temp := {}    # viewer -> {target: {"kind", "label", "at"}}

static func _path() -> String: return root.path_join("moderation.json")
static func _now() -> int: return int(Time.get_unix_time_from_system())
static func _ok() -> Dictionary: return {"ok": true, "error": ""}
static func _err(e: String) -> Dictionary: return {"ok": false, "error": e}

static func db() -> Dictionary:
	if _db == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_db = d if d is Dictionary else {}
		for k in ["mutes", "derender", "prefs"]:
			if not _db.has(k): _db[k] = {}
	return _db

static func reload_data() -> void: _db = null

static func _commit(snap: Dictionary) -> Dictionary:
	if SecureFile.write_json(_path(), db()): return _ok()
	_db = snap
	return _err("Saves are sealed. Unlock first.")

static func _me(actor: Variant) -> String: return Tiers.actor_id(actor)

# ---------- mute ----------
## channels: subset of CHANNELS, [] = all.
static func mute(actor: Variant, target: String, kind := "avatar", channels: Array = [], label := "") -> Dictionary:
	var me := _me(actor)
	target = target.strip_edges()
	if me == "" or target == "" or target == me: return _err("Can't mute that.")
	if not kind in KINDS: return _err("Unknown kind.")
	var ch: Array = CHANNELS.duplicate() if channels.is_empty() else channels.filter(func(c): return c in CHANNELS)
	if ch.is_empty(): return _err("Pick what to mute.")
	var snap: Dictionary = db().duplicate(true)
	var l: Dictionary = db()["mutes"].get(me, {})
	if not l.has(target) and l.size() >= MAX_ENTRIES: return _err("Your mute list is full.")
	l[target] = {"kind": kind, "channels": ch, "label": Social.clean(label if label != "" else target, 63), "at": _now()}
	db()["mutes"][me] = l
	return _commit(snap)

static func unmute(actor: Variant, target: String) -> Dictionary:
	var me := _me(actor)
	var snap: Dictionary = db().duplicate(true)
	(db()["mutes"].get(me, {}) as Dictionary).erase(target)
	return _commit(snap)

## channel "" = muted on any channel.
static func is_muted(viewer: Variant, target: String, channel := "") -> bool:
	var e: Variant = db()["mutes"].get(_me(viewer), {}).get(target)
	if e == null: return Social.is_blocked(_me(viewer), target) if channel in ["", "chat", "im"] else false
	return channel == "" or channel in e["channels"]

static func mutes(viewer: Variant) -> Array:
	var out: Array = []
	var l: Dictionary = db()["mutes"].get(_me(viewer), {})
	for t in l:
		var r: Dictionary = l[t].duplicate(); r["target"] = t; out.append(r)
	out.sort_custom(func(a, b): return int(a["at"]) > int(b["at"]))
	return out

## Filter helper for chat / IM lists: drops lines from muted senders. lines: [{"from": id, ...}]
static func filter_lines(viewer: Variant, lines: Array, channel := "chat") -> Array:
	return lines.filter(func(l): return not is_muted(viewer, str(l.get("from", "")), channel))

# ---------- block (= mute all + Social.block) ----------
static func block(actor: Variant, target: String) -> Dictionary:
	if target == Tiers.OWNER_ID and _me(actor) != Tiers.OWNER_ID and Tiers.is_bot(_me(actor)): return _err("Companions can't block you.")
	var r := Social.block(actor, target)
	if not r["ok"]: return r
	return mute(actor, target, "avatar", [])

static func unblock(actor: Variant, target: String) -> Dictionary:
	var r := Social.unblock(actor, target)
	if not r["ok"]: return r
	return unmute(actor, target)

# ---------- derender / blacklist ----------
static func derender(actor: Variant, target: String, kind := "object", permanent := false, label := "") -> Dictionary:
	var me := _me(actor)
	target = target.strip_edges()
	if me == "" or target == "": return _err("Can't derender that.")
	if not kind in KINDS: return _err("Unknown kind.")
	var e := {"kind": kind, "label": Social.clean(label if label != "" else target, 63), "at": _now()}
	if not permanent:
		if not _temp.has(me): _temp[me] = {}
		_temp[me][target] = e
		return _ok()
	var snap: Dictionary = db().duplicate(true)
	var l: Dictionary = db()["derender"].get(me, {})
	if not l.has(target) and l.size() >= MAX_ENTRIES: return _err("Your blacklist is full.")
	l[target] = e
	db()["derender"][me] = l
	return _commit(snap)

static func rerender(actor: Variant, target: String) -> Dictionary:
	var me := _me(actor)
	if _temp.has(me): (_temp[me] as Dictionary).erase(target)
	if not db()["derender"].get(me, {}).has(target): return _ok()
	var snap: Dictionary = db().duplicate(true)
	(db()["derender"][me] as Dictionary).erase(target)
	return _commit(snap)

static func is_derendered(viewer: Variant, target: String) -> bool:
	var me := _me(viewer)
	return _temp.get(me, {}).has(target) or db()["derender"].get(me, {}).has(target)

static func clear_temporary(viewer: Variant) -> int:
	var me := _me(viewer)
	var n: int = _temp.get(me, {}).size()
	_temp.erase(me)
	return n

## Call after a teleport. Temporary derenders come back when the preference is on (default).
static func on_teleport(viewer: Variant) -> void:
	if rerender_after_tp(viewer): clear_temporary(viewer)

static func rerender_after_tp(viewer: Variant) -> bool:
	return bool(db()["prefs"].get(_me(viewer), {}).get("rerender_after_tp", true))

static func set_rerender_after_tp(actor: Variant, on: bool) -> Dictionary:
	var me := _me(actor)
	var snap: Dictionary = db().duplicate(true)
	var p: Dictionary = db()["prefs"].get(me, {})
	p["rerender_after_tp"] = on
	db()["prefs"][me] = p
	return _commit(snap)

## Blacklist rows (permanent + temporary), newest first: {"target", "kind", "label", "at", "permanent"}
static func derendered(viewer: Variant) -> Array:
	var me := _me(viewer)
	var out: Array = []
	for pair in [[db()["derender"].get(me, {}), true], [_temp.get(me, {}), false]]:
		for t in pair[0]:
			var r: Dictionary = pair[0][t].duplicate(); r["target"] = t; r["permanent"] = pair[1]; out.append(r)
	out.sort_custom(func(a, b): return int(a["at"]) > int(b["at"]))
	return out

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _db = null; _temp = {}
