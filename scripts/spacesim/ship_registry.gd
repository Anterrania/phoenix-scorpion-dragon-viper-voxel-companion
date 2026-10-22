class_name ShipRegistry
extends RefCounted
## Ship + construct ownership, hangars and insurance. Concepts: a registry of owned vehicles
## (data/items/vehicles.json models or voxel constructs), stored in a hangar or deployed on a
## planet/shard, persistent across shards (stow / unstow like ShardModel entities), loss reports,
## and insurance that replaces a lost hull after a claim timer. No payouts in coin: a claim restores
## the hull (LEGAL REVIEW REQUIRED before any Aethel Coin premium or payout exists).
##
## Tier gating (Tiers.can): owning a ship = "ship_own" (resident+); insurance = "insure" plus the
## plan's minimum tier (INSURANCE[plan].min_tier). Org ships need the org "pilot" right to fly and
## "hangar_take" to change. Bots obey the e-stop through Tiers.

const STORE := "ships"
const VEHICLES := "res://data/items/vehicles.json"
const SIZES := {"small": 60, "medium": 300, "large": 1800, "capital": 7200}   # claim seconds
const MAX_SHIPS := {"resident": 6, "creator": 20, "staff": 50, "estate_manager": 50, "owner": 1000}
const INSURANCE := {
	"none": {"min_tier": "resident", "claim_factor": 0.0, "days": 0, "label": "Uninsured"},
	"basic": {"min_tier": "resident", "claim_factor": 1.0, "days": 30, "label": "Basic: hull replaced, slow claim"},
	"plus": {"min_tier": "creator", "claim_factor": 0.5, "days": 90, "label": "Plus: hull replaced, faster claim"},
	"fleet": {"min_tier": "staff", "claim_factor": 0.25, "days": 365, "label": "Fleet: staff and bot fleets, fastest claim"},
}
const PREMIUM_AEC := 0   # INACTIVE (2026-10-17): coin premiums. Why: LEGAL REVIEW REQUIRED. Re-enable: legal sign-off.

static func _db() -> Dictionary: return FrontierStore.db(STORE, {"ships": {}, "losses": []})
static func _snap() -> Dictionary: _db(); return FrontierStore.snap(STORE)

static func models() -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(VEHICLES))
	return (d.get("items", []) if d is Dictionary else []).map(func(v): return {"id": v["id"], "name": v.get("display_name", v["id"]), "type": v.get("type", "")})

## owner: yourself or "org:<gid>" (needs org "hangar_take"). model: a vehicles.json id or "construct:<id>".
static func register(actor: Variant, model: String, name: String, size := "small", owner := "") -> Dictionary:
	var me := Tiers.actor_id(actor)
	if not Tiers.can(actor, "ship_own"): return FrontierStore.err("Residents and up can own ships.")
	if not size in SIZES: return FrontierStore.err("Pick a size.")
	if not (model.begins_with("construct:") or models().any(func(m): return m["id"] == model)): return FrontierStore.err("Unknown model.")
	var o := me if owner == "" else owner
	if o.begins_with("org:"):
		if not OrgRights.has(actor, o.substr(4), "hangar_take"): return FrontierStore.err("Needs the org hangar right.")
	elif o != me: return FrontierStore.err("Register for yourself or an org.")
	if size == "capital" and Tiers.rank(Tiers.tier_of(actor)) < Tiers.rank("staff"): return FrontierStore.err("Capital ships are staff and owner only for now.")
	var cap := int(MAX_SHIPS.get(Tiers.tier_of(actor), 0))
	if fleet(o).size() >= cap: return FrontierStore.err("Up to %d ships at your tier." % cap)
	var snap := _snap()
	var id := FrontierStore.next_id(STORE, "s")
	var s := {"id": id, "model": FrontierStore.clean(model, 64), "name": FrontierStore.clean(name, 40) if FrontierStore.clean(name, 40) != "" else id, "size": size,
		"owner": o, "state": "stored", "hangar": "home", "shard": "", "where": "", "insurance": "none", "insured_until": 0, "claim_ready": 0, "t": FrontierStore.now()}
	_db()["ships"][id] = s
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"ship": s.duplicate()}))

static func fleet(owner: String) -> Array:
	return _db()["ships"].values().filter(func(s): return s["owner"] == owner and s["state"] != "scrapped").duplicate(true)

static func ship(id: String) -> Dictionary: return _db()["ships"].get(id, {}).duplicate()

static func _may(actor: Variant, s: Dictionary, right := "pilot") -> bool:
	if Tiers.can(actor, "admin"): return true
	var o: String = s["owner"]
	if o.begins_with("org:"): return OrgRights.has(actor, o.substr(4), right)
	return o == Tiers.actor_id(actor) and Tiers.can(actor, "ship_own")

## Deploy (unstow) a stored ship onto a shard/region; Tiers "enter" on that region.
static func deploy(actor: Variant, id: String, shard: String, region: String) -> Dictionary:
	var s: Dictionary = _db()["ships"].get(id, {})
	if s.is_empty() or s["state"] != "stored": return FrontierStore.err("Ship isn't in a hangar.")
	if not _may(actor, s): return FrontierStore.err("Not allowed to fly this ship.")
	if not Tiers.can(actor, "enter", region): return FrontierStore.err("You can't enter that region.")
	var snap := _snap()
	s["state"] = "deployed"; s["shard"] = FrontierStore.clean(shard, 32); s["where"] = FrontierStore.clean(region, 64)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

## Stow into a hangar (landing pad / home). Ships follow you across shards while stowed.
static func stow(actor: Variant, id: String, hangar := "home") -> Dictionary:
	var s: Dictionary = _db()["ships"].get(id, {})
	if s.is_empty() or s["state"] != "deployed": return FrontierStore.err("Ship isn't deployed.")
	if not _may(actor, s): return FrontierStore.err("Not allowed.")
	var snap := _snap()
	s["state"] = "stored"; s["hangar"] = FrontierStore.clean(hangar, 32); s["shard"] = ""; s["where"] = ""
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

static func insure(actor: Variant, id: String, plan: String) -> Dictionary:
	var s: Dictionary = _db()["ships"].get(id, {})
	if s.is_empty() or s["state"] == "scrapped": return FrontierStore.err("No such ship.")
	if not INSURANCE.has(plan): return FrontierStore.err("Unknown plan.")
	if not Tiers.can(actor, "insure") or not _may(actor, s, "hangar_take"): return FrontierStore.err("Not allowed to insure this ship.")
	if Tiers.rank(Tiers.tier_of(actor)) < Tiers.rank(str(INSURANCE[plan]["min_tier"])): return FrontierStore.err("%s needs %s tier or higher." % [plan.capitalize(), Tiers.label(INSURANCE[plan]["min_tier"])])
	var snap := _snap()
	s["insurance"] = plan; s["insured_until"] = FrontierStore.now() + int(INSURANCE[plan]["days"]) * 86400
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"plan": plan, "until": s["insured_until"], "premium_aec": PREMIUM_AEC}))

## Record a loss (system/region server or staff). Writes a loss report.
static func report_loss(actor: Variant, id: String, cause := "", by := "") -> Dictionary:
	if not (Tiers.actor_id(actor) == "system" or Tiers.can(actor, "moderate")): return FrontierStore.err("System or staff only.")
	var s: Dictionary = _db()["ships"].get(id, {})
	if s.is_empty() or s["state"] != "deployed": return FrontierStore.err("Only a deployed ship can be lost.")
	var snap := _snap()
	s["state"] = "destroyed"
	var r := {"id": FrontierStore.next_id(STORE, "loss"), "ship": id, "model": s["model"], "owner": s["owner"], "where": s["where"], "shard": s["shard"],
		"cause": FrontierStore.clean(cause, 120), "by": FrontierStore.clean(by, 64), "t": FrontierStore.now(), "insured": s["insurance"] != "none" and int(s["insured_until"]) > FrontierStore.now()}
	_db()["losses"].append(r)
	while _db()["losses"].size() > 200: _db()["losses"].pop_front()
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"loss": r.duplicate()}))

## File a claim for a destroyed, insured ship; ready after the size/plan timer.
static func claim(actor: Variant, id: String, expedite := false) -> Dictionary:
	var s: Dictionary = _db()["ships"].get(id, {})
	if s.is_empty() or s["state"] != "destroyed": return FrontierStore.err("Only destroyed ships can be claimed.")
	if not _may(actor, s, "hangar_take"): return FrontierStore.err("Not allowed.")
	if s["insurance"] == "none" or int(s["insured_until"]) < FrontierStore.now(): return FrontierStore.err("Not insured.")
	var snap := _snap()
	var secs := int(SIZES[s["size"]] * float(INSURANCE[s["insurance"]]["claim_factor"]) * (0.5 if expedite else 1.0))
	s["state"] = "claim_pending"; s["claim_ready"] = FrontierStore.now() + secs
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"seconds": secs, "expedite_fee_aec": 0}))

## Deliver ready claims to the hangar. Returns how many were restored.
static func process_claims() -> int:
	var n := 0
	for s in _db()["ships"].values():
		if s["state"] == "claim_pending" and int(s["claim_ready"]) <= FrontierStore.now():
			s["state"] = "stored"; s["hangar"] = "home"; n += 1
	if n > 0: SecureFile.write_json(FrontierStore.path(STORE), _db())
	return n

static func losses(owner := "", limit := 20) -> Array:
	var out: Array = []
	for i in range(_db()["losses"].size() - 1, -1, -1):
		if owner == "" or _db()["losses"][i]["owner"] == owner: out.append(_db()["losses"][i].duplicate())
		if out.size() >= limit: break
	return out

static func stats() -> Dictionary:
	var by := {}
	for s in _db()["ships"].values(): by[s["state"]] = int(by.get(s["state"], 0)) + 1
	return {"ships": _db()["ships"].size(), "deployed": int(by.get("deployed", 0)), "stored": int(by.get("stored", 0)), "claims": int(by.get("claim_pending", 0)), "losses": _db()["losses"].size()}
