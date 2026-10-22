class_name OrgRights
extends RefCounted
## Organisation / corporation rights on top of Social groups (no second group system).
## Concepts: corporation roles + titles (role bundles), alliances of organisations, and tag-based
## access policies on assets (territory, ships, constructs, containers). Clean-room, our own names.
##
## - A Social group IS an organisation. Social roles still apply: group "owner" holds every right
##   (the founder / chief), "officer" holds OFFICER_DEFAULT, "member" holds nothing extra.
## - Titles: named bundles of RIGHTS, defined by the group owner, assigned by owner/officers.
##   Officers can't hand out a title that contains "manage_titles" (only the group owner can).
## - Policies: {actor: "org:<gid>" | "member:<id>" | "friends" | "all", rights: [...], tags: [...]}.
##   An asset carries tags; allowed(actor, owner_gid, tags, right) checks the owning org's policies.
## - The unlocked Viper OS owner (Tiers "admin") can always act; e-stop and blocks still apply via Tiers.

const STORE := "orgs"
const RIGHTS := ["invite", "kick", "notice", "manage_titles", "wallet_view", "wallet_take", "trade",
	"factory", "research", "station", "diplomat", "contracts", "fleet", "territory", "build", "dig",
	"mine", "deploy", "pilot", "hangar_view", "hangar_take"]
const OFFICER_DEFAULT := ["invite", "notice", "wallet_view", "trade", "factory", "contracts", "fleet", "build", "pilot", "hangar_view"]
const ACTOR_KINDS := ["org", "member", "friends", "all"]
const MAX_TITLES := 24
const MAX_POLICIES := 64

static func _db() -> Dictionary: return FrontierStore.db(STORE, {"orgs": {}, "alliances": {}})
static func _snap() -> Dictionary: _db(); return FrontierStore.snap(STORE)

static func _org(gid: String) -> Dictionary:
	var o: Dictionary = _db()["orgs"].get(gid, {})
	if o.is_empty():
		o = {"titles": {}, "members": {}, "policies": [], "alliance": ""}
		_db()["orgs"][gid] = o
	return o

static func _social_role(gid: String, id: String) -> String:
	return str(Social.group(gid).get("members", {}).get(id, ""))

static func _is_admin(actor: Variant) -> bool: return Tiers.can(actor, "admin")

## Every right this member holds in the organisation.
static func rights_of(gid: String, id: String) -> Array:
	var role := _social_role(gid, id)
	if role == "": return []
	if role == "owner": return RIGHTS.duplicate()
	var out: Array = OFFICER_DEFAULT.duplicate() if role == "officer" else []
	var o: Dictionary = _db()["orgs"].get(gid, {})
	for title in o.get("members", {}).get(id, []):
		for r in o.get("titles", {}).get(title, []):
			if not r in out: out.append(r)
	return out

static func has(actor: Variant, gid: String, right: String) -> bool:
	if not right in RIGHTS: return false
	if _is_admin(actor): return true
	var id := Tiers.actor_id(actor)
	if Tiers.is_bot(id) and AutonomyGuard.paused(): return false
	return right in rights_of(gid, id)

# ---------- titles ----------
static func titles(gid: String) -> Dictionary: return _db()["orgs"].get(gid, {}).get("titles", {}).duplicate(true)

static func set_title(actor: Variant, gid: String, title: String, rights: Array) -> Dictionary:
	if Social.group(gid).is_empty(): return FrontierStore.err("No such organisation.")
	if _social_role(gid, Tiers.actor_id(actor)) != "owner" and not _is_admin(actor): return FrontierStore.err("Only the organisation owner edits titles.")
	var name := FrontierStore.clean(title, 32)
	if name == "": return FrontierStore.err("Name the title.")
	var snap := _snap()
	var o := _org(gid)
	if not o["titles"].has(name) and o["titles"].size() >= MAX_TITLES: return FrontierStore.err("Up to %d titles." % MAX_TITLES)
	o["titles"][name] = rights.filter(func(r): return r in RIGHTS)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"title": name, "rights": o["titles"][name].duplicate()}))

static func remove_title(actor: Variant, gid: String, title: String) -> Dictionary:
	if _social_role(gid, Tiers.actor_id(actor)) != "owner" and not _is_admin(actor): return FrontierStore.err("Only the organisation owner edits titles.")
	var snap := _snap()
	var o := _org(gid)
	o["titles"].erase(title)
	for m in o["members"]: o["members"][m] = (o["members"][m] as Array).filter(func(x): return x != title)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

static func assign_title(actor: Variant, gid: String, member: String, title: String, on := true) -> Dictionary:
	var me := Tiers.actor_id(actor)
	var role := _social_role(gid, me)
	if not (role in ["owner", "officer"] or _is_admin(actor)): return FrontierStore.err("Officers only.")
	if not Social.is_member(gid, member): return FrontierStore.err("Not a member.")
	var o := _org(gid)
	if not o["titles"].has(title): return FrontierStore.err("No such title.")
	if role != "owner" and not _is_admin(actor) and "manage_titles" in o["titles"][title]: return FrontierStore.err("Only the organisation owner can grant that title.")
	var snap := _snap()
	var l: Array = o["members"].get(member, [])
	if on and not title in l: l.append(title)
	if not on: l = l.filter(func(x): return x != title)
	o["members"][member] = l
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"titles": l.duplicate()}))

# ---------- policies (tag-based asset access) ----------
static func policies(gid: String) -> Array: return _db()["orgs"].get(gid, {}).get("policies", []).duplicate(true)

static func add_policy(actor: Variant, gid: String, who: String, rights: Array, tags: Array) -> Dictionary:
	if not has(actor, gid, "manage_titles"): return FrontierStore.err("Needs the manage titles right.")
	var kind := who.split(":")[0]
	if not kind in ACTOR_KINDS: return FrontierStore.err("Pick org:<id>, member:<id>, friends or all.")
	var rs := rights.filter(func(r): return r in RIGHTS and not r in ["manage_titles", "wallet_take", "kick"])
	var ts := tags.map(func(x): return FrontierStore.clean(x, 32)).filter(func(x): return x != "")
	if rs.is_empty() or ts.is_empty(): return FrontierStore.err("A policy needs rights and tags.")
	var o := _org(gid)
	if o["policies"].size() >= MAX_POLICIES: return FrontierStore.err("Up to %d policies." % MAX_POLICIES)
	var snap := _snap()
	var p := {"id": FrontierStore.next_id(STORE, "pol"), "actor": FrontierStore.clean(who, 64), "rights": rs, "tags": ts}
	o["policies"].append(p)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"policy": p.duplicate(true)}))

static func remove_policy(actor: Variant, gid: String, pid: String) -> Dictionary:
	if not has(actor, gid, "manage_titles"): return FrontierStore.err("Needs the manage titles right.")
	var snap := _snap()
	var o := _org(gid)
	o["policies"] = o["policies"].filter(func(p): return p["id"] != pid)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

static func _matches(who: String, id: String, gid: String) -> bool:
	if who == "all": return true
	if who == "friends": return id in Social.friends_of(str(Social.group(gid).get("founder", "")))
	if who.begins_with("member:"): return who.substr(7) == id
	if who.begins_with("org:"): return Social.is_member(who.substr(4), id)
	return false

## Asset access: org members with the right, or a policy whose tags overlap the asset's tags.
static func allowed(actor: Variant, owner_gid: String, asset_tags: Array, right: String) -> bool:
	if has(actor, owner_gid, right): return true
	var id := Tiers.actor_id(actor)
	if id == "" or (Tiers.is_bot(id) and AutonomyGuard.paused()): return false
	if Social.is_blocked(id, str(Social.group(owner_gid).get("founder", ""))): return false
	for p in _db()["orgs"].get(owner_gid, {}).get("policies", []):
		if right in p["rights"] and _matches(str(p["actor"]), id, owner_gid) and p["tags"].any(func(tg): return tg in asset_tags): return true
	return false

# ---------- alliances (organisations of organisations) ----------
static func alliances() -> Dictionary: return _db()["alliances"].duplicate(true)

static func alliance_create(actor: Variant, gid: String, name: String) -> Dictionary:
	if _social_role(gid, Tiers.actor_id(actor)) != "owner" and not _is_admin(actor): return FrontierStore.err("Organisation owner only.")
	if not Tiers.can(actor, "group_create"): return FrontierStore.err("Creator tier or higher.")
	if str(_org(gid)["alliance"]) != "": return FrontierStore.err("Leave your alliance first.")
	var n := FrontierStore.clean(name, 48)
	if n == "": return FrontierStore.err("Name the alliance.")
	var snap := _snap()
	var aid := FrontierStore.next_id(STORE, "al")
	_db()["alliances"][aid] = {"id": aid, "name": n, "executor": gid, "members": [gid], "invites": [], "created": FrontierStore.now()}
	_org(gid)["alliance"] = aid
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"id": aid}))

static func alliance_invite(actor: Variant, aid: String, gid: String) -> Dictionary:
	var a: Dictionary = _db()["alliances"].get(aid, {})
	if a.is_empty(): return FrontierStore.err("No such alliance.")
	if not has(actor, str(a["executor"]), "diplomat"): return FrontierStore.err("Needs the diplomat right in the executor organisation.")
	var snap := _snap()
	if not gid in a["invites"]: a["invites"].append(gid)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

static func alliance_join(actor: Variant, aid: String, gid: String) -> Dictionary:
	var a: Dictionary = _db()["alliances"].get(aid, {})
	if a.is_empty() or not gid in a.get("invites", []): return FrontierStore.err("Invite needed.")
	if not has(actor, gid, "diplomat"): return FrontierStore.err("Needs the diplomat right.")
	if str(_org(gid)["alliance"]) != "": return FrontierStore.err("Leave your alliance first.")
	var snap := _snap()
	a["invites"].erase(gid); a["members"].append(gid); _org(gid)["alliance"] = aid
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

static func alliance_leave(actor: Variant, gid: String) -> Dictionary:
	var aid := str(_org(gid)["alliance"])
	if aid == "": return FrontierStore.err("Not in an alliance.")
	if not has(actor, gid, "diplomat"): return FrontierStore.err("Needs the diplomat right.")
	var snap := _snap()
	var a: Dictionary = _db()["alliances"][aid]
	a["members"].erase(gid); _org(gid)["alliance"] = ""
	if a["members"].is_empty(): _db()["alliances"].erase(aid)
	elif a["executor"] == gid: a["executor"] = a["members"][0]
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

static func alliance_of(gid: String) -> String: return str(_db()["orgs"].get(gid, {}).get("alliance", ""))

static func summary() -> Dictionary:
	var t := 0; var p := 0
	for gid in _db()["orgs"]:
		t += _db()["orgs"][gid]["titles"].size(); p += _db()["orgs"][gid]["policies"].size()
	return {"orgs": Social.all_groups().size(), "titles": t, "policies": p, "alliances": _db()["alliances"].size()}
