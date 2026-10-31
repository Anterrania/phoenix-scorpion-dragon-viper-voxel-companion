class_name Territory
extends RefCounted
## Territory claims tied to Estate parcels. Concepts: a claim beacon on a land tile (our tile = an
## Estate parcel, 64 m), upkeep with a grace period, org claims whose rights flow through OrgRights
## policies (build / dig / mine / deploy), regional sovereignty (an org holding most active claims in
## a region), and contested claims that only exist where the region allows damage (PvP land).
##
## Rules
## - The owner opens a region for claims: Estate region key "allow_claims" (set with Tiers "land").
## - Claiming needs Tiers "territory" (creator+), Tiers "enter" on the parcel, and a free parcel.
## - Org claims need the org "territory" right; the parcel's Estate "group" becomes the org, terraform
##   "group", so Tiers.can(actor, "build", parcel) already lets that org's members build.
## - Upkeep: INACTIVE coin charge (LEGAL REVIEW REQUIRED). Upkeep is a renew() timestamp for now;
##   lapsed claims go to "grace" for GRACE_DAYS, then release.
## - Planetary war: contest() opens a VULNERABLE_H window on damage-enabled land; staff resolve it.

const STORE := "territory"
const UPKEEP_DAYS := 30
const GRACE_DAYS := 7
const VULNERABLE_H := 24
const MAX_CLAIMS := {"creator": 4, "staff": 16, "estate_manager": 64, "owner": 1000}
const UPKEEP_AEC := 0   # INACTIVE (2026-10-17): coin upkeep. Why: LEGAL REVIEW REQUIRED. Re-enable: legal sign-off + settlement.

static func _db() -> Dictionary: return FrontierStore.db(STORE, {"claims": {}})
static func _snap() -> Dictionary: _db(); return FrontierStore.snap(STORE)

static func key(region: String, parcel: String) -> String: return region + "/" + parcel

static func claims_open(region: String) -> bool: return bool(Estate.region_get(region, "allow_claims") == true)

## Owner / estate manager opens or closes a region for claims.
static func set_claims_open(actor: Variant, region: String, on: bool) -> Dictionary:
	if not Tiers.can(actor, "land", region): return FrontierStore.err("Owner or estate manager only.")
	Estate.region_set(region, "allow_claims", on)
	return FrontierStore.ok()

static func claim_of(region: String, parcel: String) -> Dictionary:
	var c: Dictionary = _db()["claims"].get(key(region, parcel), {})
	return _status(c).duplicate(true) if not c.is_empty() else {}

static func _status(c: Dictionary) -> Dictionary:
	var t := FrontierStore.now()
	if c["state"] in ["active", "grace"]:
		if t > int(c["paid_until"]) + GRACE_DAYS * 86400: c["state"] = "released"
		elif t > int(c["paid_until"]): c["state"] = "grace"
		else: c["state"] = "active"
	if c["state"] == "contested" and t > int(c.get("vulnerable_until", 0)): c["state"] = "active"
	return c

static func claims_by(holder: String) -> Array:
	return _db()["claims"].values().map(func(c): return _status(c)).filter(func(c): return c["holder"] == holder and c["state"] != "released").duplicate(true)

## holder: "" = yourself, or "org:<gid>".
static func claim(actor: Variant, region: String, parcel: String, holder := "", tags: Array = []) -> Dictionary:
	var me := Tiers.actor_id(actor)
	if not Tiers.can(actor, "territory"): return FrontierStore.err("Creator tier or higher can claim land.")
	if region == "" or parcel == "": return FrontierStore.err("Pick a parcel.")
	if not claims_open(region): return FrontierStore.err("This region isn't open for claims.")
	if not Tiers.can(actor, "enter", {"region": region, "parcel": parcel}): return FrontierStore.err("You can't enter that parcel.")
	if Tiers.land_group({"region": region, "parcel": parcel}) != "": return FrontierStore.err("That parcel already belongs to a group.")
	var ex: Dictionary = _db()["claims"].get(key(region, parcel), {})
	if not ex.is_empty() and _status(ex)["state"] != "released": return FrontierStore.err("Already claimed.")
	var h := me if holder == "" else holder
	var gid := ""
	if h.begins_with("org:"):
		gid = h.substr(4)
		if not OrgRights.has(actor, gid, "territory"): return FrontierStore.err("Needs the org territory right.")
	elif h != me: return FrontierStore.err("Claim for yourself or an org.")
	var cap := int(MAX_CLAIMS.get(Tiers.tier_of(actor), 0))
	if claims_by(h).size() >= cap: return FrontierStore.err("Up to %d claims at your tier." % cap)
	var snap := _snap()
	var t := FrontierStore.now()
	var c := {"region": region, "parcel": parcel, "holder": h, "by": me, "t": t, "paid_until": t + UPKEEP_DAYS * 86400, "state": "active",
		"tags": tags.map(func(x): return FrontierStore.clean(x, 32)).filter(func(x): return x != "") + [key(region, parcel)], "upkeep_aec": UPKEEP_AEC}
	_db()["claims"][key(region, parcel)] = c
	var res := FrontierStore.commit(STORE, snap, FrontierStore.ok({"claim": c.duplicate(true)}))
	if res["ok"]:
		if gid != "": Estate.parcel_set(region, parcel, "group", gid)
		else: Estate.parcel_set(region, parcel, "allowed", (Estate.parcel_get(region, parcel, "allowed") as Array) + [me])
		Estate.parcel_set(region, parcel, "terraform", "group")
	return res

static func _holder_ok(actor: Variant, c: Dictionary, right: String) -> bool:
	if Tiers.can(actor, "land", {"region": c["region"], "parcel": c["parcel"]}): return true
	var h: String = c["holder"]
	if h.begins_with("org:"): return OrgRights.has(actor, h.substr(4), right)
	return h == Tiers.actor_id(actor)

static func renew(actor: Variant, region: String, parcel: String) -> Dictionary:
	var c: Dictionary = _db()["claims"].get(key(region, parcel), {})
	if c.is_empty() or _status(c)["state"] == "released": return FrontierStore.err("No claim here.")
	if not _holder_ok(actor, c, "territory"): return FrontierStore.err("Holder only.")
	var snap := _snap()
	c["paid_until"] = maxi(int(c["paid_until"]), FrontierStore.now()) + UPKEEP_DAYS * 86400
	_status(c)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"paid_until": c["paid_until"]}))

static func release(actor: Variant, region: String, parcel: String) -> Dictionary:
	var c: Dictionary = _db()["claims"].get(key(region, parcel), {})
	if c.is_empty(): return FrontierStore.err("No claim here.")
	if not _holder_ok(actor, c, "territory"): return FrontierStore.err("Holder only.")
	var snap := _snap(); c["state"] = "released"
	var res := FrontierStore.commit(STORE, snap, FrontierStore.ok())
	if res["ok"]:
		if str(c["holder"]).begins_with("org:"): Estate.parcel_set(region, parcel, "group", "")
		else: Estate.parcel_set(region, parcel, "allowed", (Estate.parcel_get(region, parcel, "allowed") as Array).filter(func(x): return x != c["holder"]))
	return res

## Rights on a claimed parcel: build/dig/mine/deploy. Tiers first (estate + owner), then the holder
## and the org's tag policies.
static func can(actor: Variant, right: String, region: String, parcel: String) -> bool:
	if not right in ["build", "dig", "mine", "deploy"]: return false
	var c: Dictionary = _db()["claims"].get(key(region, parcel), {})
	if right == "build" and Tiers.can(actor, "build", {"region": region, "parcel": parcel}): return true
	if c.is_empty() or _status(c)["state"] == "released": return Tiers.can(actor, "land", {"region": region, "parcel": parcel})
	if not Tiers.can(actor, "enter", {"region": region, "parcel": parcel}): return false
	var h: String = c["holder"]
	if h == Tiers.actor_id(actor): return true
	if h.begins_with("org:"): return OrgRights.allowed(actor, h.substr(4), c["tags"], right)
	return Tiers.can(actor, "land", {"region": region, "parcel": parcel})

## Org (or member) holding at least half of a region's active claims, or "".
static func sovereign(region: String) -> String:
	var count := {}; var total := 0
	for c in _db()["claims"].values():
		if c["region"] == region and _status(c)["state"] in ["active", "contested"]:
			count[c["holder"]] = int(count.get(c["holder"], 0)) + 1; total += 1
	for h in count:
		if count[h] * 2 >= total and total > 0: return h
	return ""

## Open a vulnerability window on a claim (damage-enabled land only). Staff, or an org with "fleet".
static func contest(actor: Variant, region: String, parcel: String, attacker_gid := "") -> Dictionary:
	var c: Dictionary = _db()["claims"].get(key(region, parcel), {})
	if c.is_empty() or _status(c)["state"] != "active": return FrontierStore.err("No active claim here.")
	if not bool(Estate.parcel_get(region, parcel, "allow_damage")): return FrontierStore.err("Safe land: claims here can't be contested.")
	if not (Tiers.can(actor, "moderate") or (attacker_gid != "" and OrgRights.has(actor, attacker_gid, "fleet"))): return FrontierStore.err("Needs staff or the org fleet right.")
	var snap := _snap()
	c["state"] = "contested"; c["vulnerable_until"] = FrontierStore.now() + VULNERABLE_H * 3600; c["attacker"] = attacker_gid
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"vulnerable_until": c["vulnerable_until"]}))

## Staff resolve a contest: "defended" keeps the holder, "lost" releases the claim.
static func resolve(actor: Variant, region: String, parcel: String, outcome: String) -> Dictionary:
	if not Tiers.can(actor, "moderate"): return FrontierStore.err("Staff only.")
	var c: Dictionary = _db()["claims"].get(key(region, parcel), {})
	if c.is_empty() or c["state"] != "contested": return FrontierStore.err("Not contested.")
	if not outcome in ["defended", "lost"]: return FrontierStore.err("defended or lost?")
	var snap := _snap()
	c["state"] = "active" if outcome == "defended" else "released"
	var res := FrontierStore.commit(STORE, snap, FrontierStore.ok({"state": c["state"]}))
	if res["ok"] and outcome == "lost" and str(c["holder"]).begins_with("org:"): Estate.parcel_set(region, parcel, "group", "")
	return res

static func stats() -> Dictionary:
	var by := {}
	for c in _db()["claims"].values():
		var s: String = _status(c)["state"]
		by[s] = int(by.get(s, 0)) + 1
	return {"active": int(by.get("active", 0)), "grace": int(by.get("grace", 0)), "contested": int(by.get("contested", 0)), "released": int(by.get("released", 0))}
