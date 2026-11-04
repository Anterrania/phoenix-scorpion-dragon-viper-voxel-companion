class_name Tiers
extends RefCounted
## Viper OS membership tiers + permission matrix (docs/wiki/tiers.md, docs/modules/SOCIAL.md).
## One question for every feature:  Tiers.can(actor, action, target := null) -> bool
##
## Tiers (low -> high): guest, resident, creator (Premium/Creator), staff (Builder/Staff: bots and
## employees), estate_manager, owner.
## - actor: "self" (this device's player), a member id String, or {"id": ..., "tier": ...}.
## - Owner powers ALSO need Profile.is_owner() (owner device + unlocked owner session). A locked
##   owner is treated as a guest: whoever holds a locked phone can only browse.
## - target: for build/land/enter pass a parcel: {"region": r, "parcel": p} or "region/parcel" or
##   "region". It is combined with Estate access lists, ban list, allow_build and terraform rights.
##   For edit_profile pass the profile id.
## - E-stop (AutonomyGuard.paused()): bots/companions can do nothing but browse.
## - Role assignments + matrix overrides: user://social/roles.json through SecureFile (encrypted
##   once an OwnerVault exists). Only the owner can save them. Nobody can be assigned "owner", and
##   "admin"/"roles" can never be granted to anyone but the owner.

const ORDER := ["guest", "resident", "creator", "staff", "estate_manager", "owner"]
const LABELS := {"guest": "Guest", "resident": "Resident", "creator": "Premium / Creator",
	"staff": "Builder / Staff", "estate_manager": "Estate Manager", "owner": "Owner"}
const OWNER_ID := "phoenix"
const SELF := "self"
const ACTIONS := ["browse", "report", "post", "message", "friend", "follow", "group_join", "forum_post",
	"blog_post", "event_rsvp", "poll_vote", "album", "classified", "upload", "marketplace",
	"group_create", "event_create", "poll_create", "broadcast", "page_create", "build", "land", "enter", "moderate",
	"edit_profile", "admin", "roles", "companion_create"] + SPACE_ACTIONS   # v0.14 CREATE-1: companion_create
## Frontier (space-sim systems, docs/modules/SPACESIM_PARITY.md): market orders, contracts, industry,
## ship ownership + insurance (resident), territory claims (creator), mission posting (staff).
const SPACE_ACTIONS := ["trade", "contract", "industry", "ship_own", "insure", "territory", "mission_create"]
const OWNER_ONLY := ["admin", "roles"]
const _G := ["browse", "report", "enter"]
const _R := ["post", "message", "friend", "follow", "group_join", "forum_post", "blog_post", "event_rsvp", "poll_vote", "edit_profile", "build"] + ["trade", "contract", "industry", "ship_own", "insure"]
const _C := ["album", "classified", "upload", "marketplace", "group_create", "event_create", "poll_create", "broadcast", "page_create"] + ["territory"] + ["companion_create"]
const _S := ["moderate"] + ["mission_create"]
const _E := ["land"]
## Membership hooks (Aethel Coin prices are INACTIVE until the economy + legal review land).
const MEMBERSHIP := {
	"guest": {"perks": "Browse worlds, profiles, groups and the feed.", "aethel_monthly": 0, "active": true},
	"resident": {"perks": "Post, message, friends, join groups, build where land allows.", "aethel_monthly": 0, "active": true},
	"creator": {"perks": "Albums, classifieds (ad slots), uploads, marketplace, create groups/events/polls/pages.", "aethel_monthly": 0, "active": false},
	"staff": {"perks": "Build tools on staff land, moderation queue. Bots and employees.", "aethel_monthly": 0, "active": true},
	"estate_manager": {"perks": "Region/estate settings and land, plus staff powers.", "aethel_monthly": 0, "active": true},
	"owner": {"perks": "Everything. Needs the owner unlock.", "aethel_monthly": 0, "active": true},
}

static var root := "user://social"
static var _roles = null   # {"assign": {id: tier}, "matrix": {tier: [actions]}}

static func default_matrix() -> Dictionary:
	var m := {}
	var acc: Array = []
	for pair in [["guest", _G], ["resident", _R], ["creator", _C], ["staff", _S], ["estate_manager", _E]]:
		acc = acc + pair[1]
		m[pair[0]] = acc.duplicate()
	m["owner"] = ACTIONS.duplicate()
	return m

static func _path() -> String: return root.path_join("roles.json")

static func roles() -> Dictionary:
	if _roles == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_roles = d if d is Dictionary else {}
		if not _roles.has("assign"): _roles["assign"] = {}
		if not _roles.has("matrix"): _roles["matrix"] = {}
	return _roles

static func reload_roles() -> void: _roles = null

static func matrix() -> Dictionary:
	var m := default_matrix()
	var o: Dictionary = roles()["matrix"]
	for t in o:
		if t in ORDER and t != "owner" and o[t] is Array:
			m[t] = (o[t] as Array).filter(func(a): return a in ACTIONS and not a in OWNER_ONLY)
	return m

static func rank(tier: String) -> int: return ORDER.find(tier)
static func label(tier: String) -> String: return LABELS.get(tier, "Guest")
static func membership(tier: String) -> Dictionary: return MEMBERSHIP.get(tier, MEMBERSHIP["guest"])

static func _profile() -> Node:
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("Profile") if ml is SceneTree else null

static var owner_override = null   # tests only: true/false forces Profile.is_owner()
static func owner_session() -> bool:
	if owner_override != null: return bool(owner_override)
	var p := _profile()
	return p != null and p.is_owner()

static func actor_id(actor: Variant) -> String:
	if actor is Dictionary: return str(actor.get("id", ""))
	var s := str(actor)
	if s == SELF:
		var p := _profile()
		if (p != null and p.is_owner_device()) or owner_override != null and bool(owner_override): return OWNER_ID
		return "local"
	return s

static func is_bot(id: String) -> bool:
	return id.begins_with("bot:") or (id != "" and FileAccess.file_exists("res://companions/%s/persona.json" % id))

## Raw tier (before the owner-session check).
static func assigned_tier(id: String) -> String:
	if id == OWNER_ID: return "owner"
	var a: Dictionary = roles()["assign"]
	if a.has(id): return str(a[id])
	if id == "local":
		var p := _profile()
		return "resident" if p != null and p.has_profile() else "guest"
	if is_bot(id): return "resident"   # companions: posts still go through owner approval (Social)
	return "guest"

## Effective tier: owner only with an unlocked owner session.
static func tier_of(actor: Variant) -> String:
	var id := actor_id(actor)
	var t := assigned_tier(id)
	# a Dictionary actor may LOWER its tier (e.g. "act as guest"), never raise it
	if actor is Dictionary and str(actor.get("tier", "")) in ORDER and rank(str(actor["tier"])) < rank(t):
		t = str(actor["tier"])
	if t == "owner" and not owner_session(): return "guest"
	return t

static func can(actor: Variant, action: String, target: Variant = null) -> bool:
	if not action in ACTIONS: return false
	var id := actor_id(actor)
	if id == "": return false
	var t := tier_of(actor)
	if action in OWNER_ONLY: return t == "owner"
	if is_bot(id) and action != "browse" and AutonomyGuard.paused(): return false
	if t != "owner" and not action in matrix().get(t, []): return false
	if action == "edit_profile" and target != null:
		var pid := str(target)
		if pid == OWNER_ID: return t == "owner"
		if pid != id and t != "owner": return false   # only your own profile (companions': owner only)
	if action in ["build", "land", "enter", "broadcast"] and target != null:
		return _land_ok(id, t, action, _parcel(target))
	return true

static func _parcel(target: Variant) -> Dictionary:
	if target is Dictionary: return {"region": str(target.get("region", "")), "parcel": str(target.get("parcel", ""))}
	var parts := str(target).split("/", true, 1)
	return {"region": parts[0], "parcel": parts[1] if parts.size() > 1 else ""}

static func _pget(p: Dictionary, key: String) -> Variant:
	return Estate.parcel_get(p["region"], p["parcel"], key) if p["parcel"] != "" else Estate.region_get(p["region"], key)

## Estate group that owns/manages a parcel (set by Social.group_claim_land), "" if none.
static func land_group(p: Dictionary) -> String:
	var c := Estate.cfg()   # "group" is not in REGION_DEFAULTS, so look it up without a null default
	var sec := "parcel:%s/%s" % [p["region"], p["parcel"]]
	if p["parcel"] != "" and c.has_section_key(sec, "group"): return str(c.get_value(sec, "group"))
	if c.has_section_key("region:" + p["region"], "group"): return str(c.get_value("region:" + p["region"], "group"))
	return ""

static func _in_land_group(id: String, p: Dictionary) -> bool:
	var g := land_group(p)
	return g != "" and Social.is_member(g, id)

static func _land_ok(id: String, t: String, action: String, p: Dictionary) -> bool:
	if p["region"] == "": return false
	if t == "owner": return true
	if id in _pget(p, "banned"): return false   # bans always win
	var access := str(_pget(p, "access"))
	var allowed: Array = _pget(p, "allowed")
	var can_enter := access == "public" or (access in ["allowed_list", "group_only"] and (id in allowed or _in_land_group(id, p)))
	if t == "estate_manager": can_enter = can_enter or access != "owner_only"
	if not can_enter: return false
	match action:
		"enter": return true
		"land": return t == "estate_manager"
		"build":
			if not bool(_pget(p, "allow_build")): return false
			match str(_pget(p, "terraform")):
				"everyone": return true
				"group": return rank(t) >= rank("staff") or _in_land_group(id, p) or id in allowed
				_: return rank(t) >= rank("staff")   # owner_only land: owner's staff/managers build for the owner
		"broadcast":   # parcel media/stream (SL "change media"): staff+, the land group, or the allow list
			return rank(t) >= rank("staff") or _in_land_group(id, p) or id in allowed
	return false

# ---------- owner-only editing ----------
static func _save() -> bool: return SecureFile.write_json(_path(), roles(), "\t")

static func set_tier(member: String, tier: String) -> String:
	if not owner_session(): return "Owner unlock needed."
	if not tier in ORDER or tier == "owner": return "Pick a tier below Owner."
	if member == "" or member == OWNER_ID or member == SELF: return "That member can't be changed."
	var prev: Variant = roles()["assign"].get(member)
	roles()["assign"][member] = tier
	if not _save():
		if prev == null: roles()["assign"].erase(member)
		else: roles()["assign"][member] = prev
		return "Saves are sealed. Unlock first."
	return ""

## Role aliases accepted by set_role (UI labels -> tier keys).
const ROLE_ALIASES := {"builder": "staff", "premium": "creator", "manager": "estate_manager", "estate": "estate_manager"}

## Owner-gated role setter with an audit entry (2026-10-17). Same rules as set_tier (needs
## Profile.is_owner(): owner device + unlocked session; nobody can be made owner; the owner can't be
## changed), plus one tamper-evident revision "role/<member>" in the Viper Admin timeline
## (before tier -> after tier, author = owner). Accepts tier keys or the aliases above.
## Use companion ids exactly as in res://companions/ (e.g. "foxy_ani", "aaliyah", "circuit_nova").
## Returns "" on success or the error text.
static func set_role(member: String, role: String) -> String:
	var tier: String = ROLE_ALIASES.get(role.to_lower(), role.to_lower())
	var before := assigned_tier(member) if member != "" else ""
	var e := set_tier(member, tier)
	if e != "": return e
	if before != tier:
		ViperAdminData.revisions().commit("role", "role/" + member, before, tier,
			"Role %s: %s -> %s" % [member, label(before), label(tier)], OWNER_ID)
	return ""

static func clear_tier(member: String) -> String:
	if not owner_session(): return "Owner unlock needed."
	roles()["assign"].erase(member)
	return "" if _save() else "Saves are sealed. Unlock first."

static func set_matrix(tier: String, actions: Array) -> String:
	if not owner_session(): return "Owner unlock needed."
	if not tier in ORDER or tier == "owner": return "Owner always has every power."
	roles()["matrix"][tier] = actions.filter(func(a): return a in ACTIONS and not a in OWNER_ONLY)
	return "" if _save() else "Saves are sealed. Unlock first."

static func reset_matrix() -> String:
	if not owner_session(): return "Owner unlock needed."
	roles()["matrix"] = {}
	return "" if _save() else "Saves are sealed. Unlock first."

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _roles = null
