class_name ParcelTools
extends RefCounted
## Viewer parity (docs/modules/VIEWER_PARITY.md, VIEWER-2): the admin side of the SL / Firestorm
## "About Land" and "Region / Estate" floaters, built on top of Estate (user://estate.cfg).
## Clean-room: concepts only, no viewer code (Firestorm/SL viewer are LGPL).
##
## Kept in its own file on purpose: the virtual-world gap worker (docs/virtual-world-gap) is adding
## parcel flags (push, scripts, landmarks, voice, search, maturity, agent limit) and the covenant to
## estate.gd. None of those keys are repeated here. This file adds:
##   General  - parcel name, description, category, sale listing (price INACTIVE: needs Aethel Coin
##              + LEGAL REVIEW), parcel owner id.
##   Access   - allow/ban lists with timed bans (hours), group access, adult-only flag, passes (INACTIVE).
##   Options  - landing point + teleport routing, avatars visible from outside, avatar sounds.
##   Objects  - an object registry the build engine reports into, owner/group/other counts,
##              return by owner/class, auto-return after N minutes, a per-owner Lost and Found.
##   Media    - parcel media + music URL (http/https only), loop, auto-scale, description.
##   Estate   - per-region estate managers (owner-only list, max 15), estate messages (local log).
##   Debug    - restart / kick / top scripts are server features: stubbed, INACTIVE until a grid exists.
##
## Who may change things (every setter returns "" on success or a short error):
##   estate-level (managers, estate message, region scope): Tiers.can(actor, "land", region)
##   parcel-level: the above, OR a listed estate manager of that region, OR the parcel's owner_id.
##   Writes go through SecureFile (encrypted once an OwnerVault exists) and roll back if refused.

const DEFAULTS := {
	"name": "", "description": "", "category": "none", "owner_id": "",
	"for_sale": false, "sale_to": "", "sale_price": 0,
	"group_access": false, "adult_only": false, "pass_hours": 0.0, "pass_price": 0,
	"ban_expiry": {},
	"landing_point": [], "tp_routing": "anywhere", "see_avatars": true, "avatar_sounds": "everyone",
	"auto_return_min": 0,
	"media_loop": false, "media_autoscale": true, "media_desc": "",
	"managers": [],
}
const CATEGORIES := ["none", "linden_location", "arts_culture", "business", "educational", "gaming",
	"hangout", "newcomer", "parks_nature", "residential", "shopping", "rental", "other"]
const TP_ROUTING := ["anywhere", "landing_point", "blocked"]
const AVATAR_SOUNDS := ["everyone", "group", "nobody"]
const LIST_MAX := 300          # SL caps allow/ban lists at a few hundred names
const MANAGERS_MAX := 15
const URL_MAX := 1024
const TEXT_MAX := 255
const DESC_MAX := 1024
const OBJECTS_PATH_NAME := "parcel_objects.json"

static var root := "user://world"
static var _objs = null    # {"objects": {oid: {...}}, "lost_and_found": {owner: [oid...]}, "seq": n}
static var events: Array = []  # estate messages + returns, newest last (session only)

static func _now() -> int: return int(Time.get_unix_time_from_system())
static func _sec(region: String, parcel: String) -> String:
	return "region:" + region if parcel == "" else "parcel:%s/%s" % [region, parcel]

## Parcel value, falling back to the region value, then DEFAULTS.
static func get_value(region: String, parcel: String, key: String) -> Variant:
	var c := Estate.cfg()
	if parcel != "" and c.has_section_key(_sec(region, parcel), key): return c.get_value(_sec(region, parcel), key)
	if c.has_section_key(_sec(region, ""), key): return c.get_value(_sec(region, ""), key)
	var d: Variant = Estate.REGION_DEFAULTS[key] if Estate.REGION_DEFAULTS.has(key) else DEFAULTS.get(key)
	return d.duplicate() if d is Array or d is Dictionary else d

## Several keys at once, written atomically (rolled back if SecureFile refuses).
static func _put(region: String, parcel: String, changes: Dictionary) -> String:
	var c := Estate.cfg()
	var sec := _sec(region, parcel)
	var prev := {}
	for k in changes: prev[k] = c.get_value(sec, k) if c.has_section_key(sec, k) else null
	for k in changes: c.set_value(sec, k, changes[k])
	if SecureFile.write_text(Estate.PATH, c.encode_to_text()): return ""
	for k in prev: c.set_value(sec, k, prev[k])   # null erases the key again
	return "Saves are sealed. Unlock first."

# ---------- permissions ----------
static func managers(region: String) -> Array: return get_value(region, "", "managers")

static func is_manager(region: String, id: String) -> bool: return id != "" and id in managers(region)

static func can_manage_estate(actor: Variant, region: String) -> bool:
	return region != "" and Tiers.can(actor, "land", region)

static func can_manage_parcel(actor: Variant, region: String, parcel: String) -> bool:
	if region == "": return false
	if can_manage_estate(actor, region): return true
	var id := Tiers.actor_id(actor)
	if Tiers.is_bot(id) and AutonomyGuard.paused(): return false   # e-stop: bots only browse
	if Tiers.tier_of(actor) == "guest": return false              # locked owner / guests: browse only
	if is_manager(region, id): return true
	return parcel != "" and id != "" and str(get_value(region, parcel, "owner_id")) == id

static func _deny(actor: Variant, region: String, parcel: String) -> String:
	return "" if can_manage_parcel(actor, region, parcel) else "Only the parcel owner, estate managers or you (unlocked) can change this."

# ---------- General ----------
static func general(region: String, parcel: String) -> Dictionary:
	var out := {}
	for k in ["name", "description", "category", "owner_id", "for_sale", "sale_to", "sale_price"]: out[k] = get_value(region, parcel, k)
	out["group"] = Tiers.land_group({"region": region, "parcel": parcel})
	out["area_m2"] = 64 * 64 if parcel != "" else 0
	out["sale_price_active"] = false   # INACTIVE until Aethel Coin + legal review
	return out

static func set_general(actor: Variant, region: String, parcel: String, fields: Dictionary) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	var ch := {}
	if fields.has("name"): ch["name"] = Social.clean(str(fields["name"]), 63)
	if fields.has("description"): ch["description"] = Social.clean(str(fields["description"]), DESC_MAX)
	if fields.has("category"):
		if not str(fields["category"]) in CATEGORIES: return "Unknown category."
		ch["category"] = str(fields["category"])
	if fields.has("for_sale"): ch["for_sale"] = bool(fields["for_sale"])
	if fields.has("sale_to"): ch["sale_to"] = str(fields["sale_to"]).strip_edges().left(64)
	# INACTIVE (2026-10-17): sale_price is stored but never charged. Re-enable when the Aethel Coin
	# wallet transfer exists and the currency has passed LEGAL REVIEW (docs/wiki/aethel-coin-exchange.md).
	if fields.has("sale_price"): ch["sale_price"] = maxi(0, int(fields["sale_price"]))
	if fields.has("owner_id"):
		if not can_manage_estate(actor, region): return "Only estate managers or you can hand a parcel to someone."
		ch["owner_id"] = str(fields["owner_id"]).strip_edges().left(64)
	return _put(region, parcel, ch) if not ch.is_empty() else ""

# ---------- Access: allow / ban lists ----------
static func allowed(region: String, parcel: String) -> Array: return (get_value(region, parcel, "allowed") as Array).duplicate()
static func banned(region: String, parcel: String) -> Array: return (get_value(region, parcel, "banned") as Array).duplicate()

static func allow(actor: Variant, region: String, parcel: String, who: String) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	who = who.strip_edges()
	if who == "": return "Enter a name."
	var l := allowed(region, parcel)
	if who in l: return ""
	if l.size() >= LIST_MAX: return "The allowed list is full."
	l.append(who)
	return _put(region, parcel, {"allowed": l})

static func disallow(actor: Variant, region: String, parcel: String, who: String) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	return _put(region, parcel, {"allowed": allowed(region, parcel).filter(func(x): return x != who)})

## hours <= 0 = permanent. Banning also removes the person from the allowed list.
static func ban(actor: Variant, region: String, parcel: String, who: String, hours := 0.0) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	who = who.strip_edges()
	if who == "": return "Enter a name."
	if who == Tiers.OWNER_ID: return "The owner can't be banned."
	if who == Tiers.actor_id(actor): return "You can't ban yourself."
	var l := banned(region, parcel)
	if not who in l:
		if l.size() >= LIST_MAX: return "The ban list is full."
		l.append(who)
	var ex: Dictionary = (get_value(region, parcel, "ban_expiry") as Dictionary).duplicate()
	if hours > 0.0: ex[who] = _now() + int(hours * 3600.0)
	else: ex.erase(who)
	return _put(region, parcel, {"banned": l, "ban_expiry": ex, "allowed": allowed(region, parcel).filter(func(x): return x != who)})

static func unban(actor: Variant, region: String, parcel: String, who: String) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	var ex: Dictionary = (get_value(region, parcel, "ban_expiry") as Dictionary).duplicate()
	ex.erase(who)
	return _put(region, parcel, {"banned": banned(region, parcel).filter(func(x): return x != who), "ban_expiry": ex})

## Lifts timed bans whose time is up. Returns how many were lifted. No permission needed (expiry
## was decided by a manager); call it on region entry / screen open.
static func sweep_bans(region: String, parcel: String, now := -1) -> int:
	if now < 0: now = _now()
	var ex: Dictionary = (get_value(region, parcel, "ban_expiry") as Dictionary).duplicate()
	var gone: Array = []
	for who in ex:
		if int(ex[who]) <= now: gone.append(who)
	if gone.is_empty(): return 0
	for g in gone: ex.erase(g)
	var err := _put(region, parcel, {"banned": banned(region, parcel).filter(func(x): return not x in gone), "ban_expiry": ex})
	return gone.size() if err == "" else 0

static func set_access(actor: Variant, region: String, parcel: String, fields: Dictionary) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	var ch := {}
	if fields.has("access"):
		if not str(fields["access"]) in Estate.ACCESS: return "Unknown access mode."
		ch["access"] = str(fields["access"])
	if fields.has("group_access"): ch["group_access"] = bool(fields["group_access"])
	if fields.has("adult_only"): ch["adult_only"] = bool(fields["adult_only"])
	# INACTIVE (2026-10-17): passes are stored only. Selling time-limited passes needs Aethel Coin +
	# LEGAL REVIEW. Re-enable together with sale_price.
	if fields.has("pass_hours"): ch["pass_hours"] = clampf(float(fields["pass_hours"]), 0.0, 168.0)
	if fields.has("pass_price"): ch["pass_price"] = maxi(0, int(fields["pass_price"]))
	return _put(region, parcel, ch) if not ch.is_empty() else ""

## Adult-only parcels refuse entry to anyone without an adult flag. adult: the caller's verified flag
## (the app has no age verification yet, so this defaults to false = refuse).
static func entry_ok(actor: Variant, region: String, parcel: String, adult := false) -> bool:
	if not Tiers.can(actor, "enter", {"region": region, "parcel": parcel}): return false
	if bool(get_value(region, parcel, "adult_only")) and not adult and Tiers.tier_of(actor) != "owner": return false
	return true

# ---------- Options ----------
static func set_options(actor: Variant, region: String, parcel: String, fields: Dictionary) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	var ch := {}
	if fields.has("tp_routing"):
		if not str(fields["tp_routing"]) in TP_ROUTING: return "Unknown teleport routing."
		ch["tp_routing"] = str(fields["tp_routing"])
	if fields.has("landing_point"):
		var p: Variant = fields["landing_point"]
		ch["landing_point"] = [p.x, p.y, p.z] if p is Vector3 else []
	if fields.has("see_avatars"): ch["see_avatars"] = bool(fields["see_avatars"])
	if fields.has("avatar_sounds"):
		if not str(fields["avatar_sounds"]) in AVATAR_SOUNDS: return "Unknown sound option."
		ch["avatar_sounds"] = str(fields["avatar_sounds"])
	return _put(region, parcel, ch) if not ch.is_empty() else ""

## Where a teleport into this parcel lands: the requested spot, the landing point, or null (blocked).
## Owner + managers always land where they asked (like SL).
static func teleport_target(actor: Variant, region: String, parcel: String, requested: Vector3) -> Variant:
	if can_manage_parcel(actor, region, parcel): return requested
	match str(get_value(region, parcel, "tp_routing")):
		"blocked": return null
		"landing_point":
			var lp: Array = get_value(region, parcel, "landing_point")
			return Vector3(lp[0], lp[1], lp[2]) if lp.size() == 3 else requested
	return requested

# ---------- Media ----------
static func valid_url(u: String) -> bool:
	u = u.strip_edges()
	return u == "" or (u.length() <= URL_MAX and (u.begins_with("https://") or u.begins_with("http://")) and not " " in u)

static func set_media(actor: Variant, region: String, parcel: String, fields: Dictionary) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	var ch := {}
	for k in ["media_url", "music_url"]:
		if fields.has(k):
			var u := str(fields[k]).strip_edges()
			if not valid_url(u): return "Use a web address starting with https://"
			ch[k] = u
	if fields.has("media_loop"): ch["media_loop"] = bool(fields["media_loop"])
	if fields.has("media_autoscale"): ch["media_autoscale"] = bool(fields["media_autoscale"])
	if fields.has("media_desc"): ch["media_desc"] = Social.clean(str(fields["media_desc"]), TEXT_MAX)
	return _put(region, parcel, ch) if not ch.is_empty() else ""

# ---------- Objects: registry, counts, returns, auto-return ----------
static func _opath() -> String: return root.path_join(OBJECTS_PATH_NAME)

static func objs() -> Dictionary:
	if _objs == null:
		var d: Variant = SecureFile.read_json(_opath(), {})
		_objs = d if d is Dictionary else {}
		for k in ["objects", "lost_and_found"]:
			if not _objs.has(k): _objs[k] = {}
		if not _objs.has("seq"): _objs["seq"] = 0
	return _objs

static func _osave() -> bool: return SecureFile.write_json(_opath(), objs())

## The build engine (Foxy's build tools) reports every rezzed object here. Returns the object id or "".
static func register_object(owner: String, region: String, parcel: String, opts := {}) -> String:
	if owner == "" or region == "": return ""
	var snap: Dictionary = objs().duplicate(true)
	objs()["seq"] = int(objs()["seq"]) + 1
	var oid := "obj%d" % objs()["seq"]
	objs()["objects"][oid] = {"owner": owner, "region": region, "parcel": parcel, "group": str(opts.get("group", "")),
		"name": Social.clean(str(opts.get("name", "Object")), 63), "impact": maxi(1, int(opts.get("impact", 1))),
		"rezzed": int(opts.get("rezzed", _now()))}
	if _osave(): return oid
	_objs = snap
	return ""

static func objects_on(region: String, parcel: String) -> Array:
	var out: Array = []
	var o: Dictionary = objs()["objects"]
	for oid in o:
		if o[oid]["region"] == region and (parcel == "" or o[oid]["parcel"] == parcel):
			var r: Dictionary = o[oid].duplicate(); r["id"] = oid; out.append(r)
	return out

## "owner" = parcel owner's objects, "group" = set to the land group, "other" = everyone else.
static func classify(obj: Dictionary, region: String, parcel: String) -> String:
	var pown := str(get_value(region, parcel, "owner_id"))
	if pown == "": pown = Tiers.OWNER_ID
	if obj["owner"] == pown: return "owner"
	var g := Tiers.land_group({"region": region, "parcel": parcel})
	if g != "" and obj.get("group", "") == g: return "group"
	return "other"

## Land impact by class + per-owner list (About Land > Objects).
static func object_counts(region: String, parcel: String) -> Dictionary:
	var c := {"owner": 0, "group": 0, "other": 0, "total": 0, "by_owner": {}}
	for o in objects_on(region, parcel):
		var k := classify(o, region, parcel)
		c[k] += int(o["impact"]); c["total"] += int(o["impact"])
		c["by_owner"][o["owner"]] = int(c["by_owner"].get(o["owner"], 0)) + int(o["impact"])
	return c

## filter: {"owner": id} or {"class": "owner"|"group"|"other"}. Returned objects move to their
## owner's Lost and Found (never deleted). Returns {"ok", "error", "returned": n}.
static func return_objects(actor: Variant, region: String, parcel: String, filter: Dictionary) -> Dictionary:
	var e := _deny(actor, region, parcel)
	if e != "": return {"ok": false, "error": e, "returned": 0}
	var picked: Array = []
	for o in objects_on(region, parcel):
		if filter.has("owner") and o["owner"] != str(filter["owner"]): continue
		if filter.has("class") and classify(o, region, parcel) != str(filter["class"]): continue
		picked.append(o["id"])
	return _return_ids(picked, "returned by %s" % Tiers.actor_id(actor))

static func _return_ids(ids: Array, why: String) -> Dictionary:
	if ids.is_empty(): return {"ok": true, "error": "", "returned": 0}
	var snap: Dictionary = objs().duplicate(true)
	for oid in ids:
		var o: Dictionary = objs()["objects"][oid]
		var lf: Array = objs()["lost_and_found"].get(o["owner"], [])
		lf.append({"id": oid, "name": o["name"], "from": "%s/%s" % [o["region"], o["parcel"]], "why": why, "at": _now()})
		objs()["lost_and_found"][o["owner"]] = lf
		objs()["objects"].erase(oid)
	if not _osave():
		_objs = snap
		return {"ok": false, "error": "Saves are sealed. Unlock first.", "returned": 0}
	events.append({"kind": "return", "count": ids.size(), "why": why, "at": _now()})
	return {"ok": true, "error": "", "returned": ids.size()}

static func lost_and_found(owner: String) -> Array: return (objs()["lost_and_found"].get(owner, []) as Array).duplicate(true)

static func set_auto_return(actor: Variant, region: String, parcel: String, minutes: int) -> String:
	var e := _deny(actor, region, parcel)
	if e != "": return e
	return _put(region, parcel, {"auto_return_min": clampi(minutes, 0, 10080)})

## Returns "other" objects older than the parcel's auto-return time (0 = off). Owner + group objects stay.
static func auto_return_sweep(region: String, parcel: String, now := -1) -> int:
	var mins := int(get_value(region, parcel, "auto_return_min"))
	if mins <= 0: return 0
	if now < 0: now = _now()
	var ids: Array = []
	for o in objects_on(region, parcel):
		if classify(o, region, parcel) == "other" and now - int(o["rezzed"]) >= mins * 60: ids.append(o["id"])
	return int(_return_ids(ids, "auto-return after %d min" % mins)["returned"])

# ---------- Estate ----------
static func add_manager(actor: Variant, region: String, who: String) -> String:
	if Tiers.tier_of(actor) != "owner": return "Only you (unlocked) can add estate managers."
	who = who.strip_edges()
	if who == "" or who == Tiers.OWNER_ID: return "Pick someone else."
	if Tiers.is_bot(who): return "Companions can't be estate managers."
	var l := managers(region)
	if who in l: return ""
	if l.size() >= MANAGERS_MAX: return "An estate can have %d managers." % MANAGERS_MAX
	l.append(who)
	return _put(region, "", {"managers": l})

static func remove_manager(actor: Variant, region: String, who: String) -> String:
	if Tiers.tier_of(actor) != "owner": return "Only you (unlocked) can remove estate managers."
	return _put(region, "", {"managers": managers(region).filter(func(x): return x != who)})

## Estate message to everyone in the region. Local for now: logged and sent as a notification to
## the actor's own inbox as proof; a grid would broadcast it.
static func estate_message(actor: Variant, region: String, text: String) -> String:
	if not (can_manage_estate(actor, region) or is_manager(region, Tiers.actor_id(actor)) and Tiers.tier_of(actor) != "guest"):
		return "Only estate managers or you can message the estate."
	var t := Social.clean(text, TEXT_MAX)
	if t == "": return "Write a message."
	events.append({"kind": "estate_message", "region": region, "text": t, "at": _now()})
	return ""

## Server-only region tools. INACTIVE (2026-10-17): there is no region server yet (offline phone build).
## What: restart region (with delay), kick a user, top scripts / top colliders, disable scripts /
## physics / collisions. Why: needs the Aurora-model grid services (docs/ARCHITECTURE_AURORA_MODEL.md).
## Re-enable: implement against the region service and drop the "inactive" result.
static func region_debug(actor: Variant, region: String, what: String) -> Dictionary:
	if not can_manage_estate(actor, region): return {"ok": false, "error": "Only estate managers or you."}
	return {"ok": false, "error": "%s needs the region server (planned)." % what, "inactive": true}

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _objs = null; events = []
