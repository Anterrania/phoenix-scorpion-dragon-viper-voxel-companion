class_name ContractsBoard
extends RefCounted
## Contracts + missions board. Concepts: item exchange, courier (with collateral), auction (bids with
## a short extension near the end), service requests (paid help beacons) and missions (posted by staff
## or the system, with reputation toward an issuing faction). Availability public, private (one member)
## or org (a Social group). States: outstanding -> in_progress -> completed | failed; or cancelled /
## expired. Rewards, prices and collateral are Aethel Coin numbers only:
## LEGAL REVIEW REQUIRED: escrow is recorded, nothing moves between wallets (OrderBook.SETTLEMENT_ACTIVE).

const STORE := "contracts"
const KINDS := ["item_exchange", "courier", "auction", "service", "mission"]
const STATES := ["outstanding", "in_progress", "completed", "failed", "cancelled", "expired"]
const MAX_DAYS := 28
const AUCTION_EXTEND_S := 300
const REP_RANKS := [[0, "Unknown"], [10, "Known"], [30, "Trusted"], [60, "Respected"], [100, "Honoured"]]
const MAX_OPEN := 30

static func _db() -> Dictionary: return FrontierStore.db(STORE, {"contracts": {}, "rep": {}})
static func _snap() -> Dictionary: _db(); return FrontierStore.snap(STORE)

## spec: kind, title, text, reward (AEC int), collateral (courier), items (Array of {item, qty}),
## from/to (courier locations), days (1..28), availability ("public" | "private:<id>" | "org:<gid>"),
## faction (missions), rep (missions: reputation on success, 1..20), buyout (auction).
static func post(actor: Variant, spec: Dictionary) -> Dictionary:
	var me := Tiers.actor_id(actor)
	var kind := str(spec.get("kind", ""))
	if not kind in KINDS: return FrontierStore.err("Pick a contract type.")
	if kind == "mission":
		if not (Tiers.can(actor, "mission_create") or me == "system"): return FrontierStore.err("Staff post missions.")
	elif not Tiers.can(actor, "contract"): return FrontierStore.err("Residents and up post contracts.")
	var title := FrontierStore.clean(spec.get("title", ""), 80)
	if title == "": return FrontierStore.err("Give it a title.")
	var avail := str(spec.get("availability", "public"))
	if not (avail == "public" or avail.begins_with("private:") or (avail.begins_with("org:") and Social.is_member(avail.substr(4), me))): return FrontierStore.err("Pick who can take it.")
	var reward := maxi(0, int(spec.get("reward", 0)))
	var collateral := maxi(0, int(spec.get("collateral", 0)))
	if kind == "courier" and (str(spec.get("from", "")) == "" or str(spec.get("to", "")) == ""): return FrontierStore.err("Couriers need a from and a to.")
	if mine(me).filter(func(c): return c["state"] in ["outstanding", "in_progress"]).size() >= MAX_OPEN: return FrontierStore.err("Up to %d open contracts." % MAX_OPEN)
	var snap := _snap()
	var t := FrontierStore.now()
	var items: Array = []
	for x in spec.get("items", []):
		if x is Dictionary and str(x.get("item", "")) != "": items.append({"item": FrontierStore.clean(x["item"], 64), "qty": clampi(int(x.get("qty", 1)), 1, 1000000)})
	var c := {"id": FrontierStore.next_id(STORE, "c"), "kind": kind, "issuer": me, "title": title, "text": FrontierStore.clean(spec.get("text", ""), 1000),
		"reward": reward, "collateral": collateral, "items": items, "from": FrontierStore.clean(spec.get("from", ""), 64), "to": FrontierStore.clean(spec.get("to", ""), 64),
		"availability": avail, "faction": FrontierStore.clean(spec.get("faction", ""), 48), "rep": clampi(int(spec.get("rep", 0)), 0, 20),
		"buyout": maxi(0, int(spec.get("buyout", 0))), "bids": [], "state": "outstanding", "taker": "", "t": t,
		"expires": t + clampi(int(spec.get("days", 7)), 1, MAX_DAYS) * 86400, "currency": OrderBook.CURRENCY, "escrow": "recorded_only"}
	_db()["contracts"][c["id"]] = c
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"id": c["id"], "legal": OrderBook.LEGAL}))

static func _can_see(c: Dictionary, id: String) -> bool:
	var a := str(c["availability"])
	if c["issuer"] == id or c["taker"] == id or a == "public": return not Social.is_blocked(id, c["issuer"]) or c["issuer"] == id
	if a.begins_with("private:"): return a.substr(8) == id
	if a.begins_with("org:"): return Social.is_member(a.substr(4), id)
	return false

## Open contracts this viewer may take (kind "" = all). Guests may browse.
static func board(viewer: Variant, kind := "", limit := 50) -> Array:
	if not Tiers.can(viewer, "browse"): return []
	sweep()
	var id := Tiers.actor_id(viewer)
	var out: Array = []
	for cid in _db()["contracts"]:
		var c: Dictionary = _db()["contracts"][cid]
		if c["state"] == "outstanding" and (kind == "" or c["kind"] == kind) and _can_see(c, id): out.append(c.duplicate(true))
		if out.size() >= limit: break
	return out

static func get_contract(cid: String) -> Dictionary: return _db()["contracts"].get(cid, {}).duplicate(true)

static func mine(id: String) -> Array:
	var out: Array = []
	for cid in _db()["contracts"]:
		var c: Dictionary = _db()["contracts"][cid]
		if c["issuer"] == id or c["taker"] == id: out.append(c.duplicate(true))
	return out

## Accept: item exchange completes at once; courier/service/mission go in progress.
static func accept(actor: Variant, cid: String) -> Dictionary:
	var me := Tiers.actor_id(actor)
	var c: Dictionary = _db()["contracts"].get(cid, {})
	if c.is_empty() or c["state"] != "outstanding": return FrontierStore.err("Not available.")
	if not Tiers.can(actor, "contract"): return FrontierStore.err("Residents and up take contracts.")
	if c["issuer"] == me: return FrontierStore.err("That's your own contract.")
	if not _can_see(c, me) or Social.is_blocked(me, c["issuer"]): return FrontierStore.err("Not available.")
	if c["kind"] == "auction": return FrontierStore.err("Place a bid instead.")
	if c["expires"] <= FrontierStore.now(): return FrontierStore.err("Expired.")
	var snap := _snap()
	c["taker"] = me; c["accepted"] = FrontierStore.now()
	c["state"] = "completed" if c["kind"] == "item_exchange" else "in_progress"
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"state": c["state"]}))

static func bid(actor: Variant, cid: String, amount: int) -> Dictionary:
	var me := Tiers.actor_id(actor)
	var c: Dictionary = _db()["contracts"].get(cid, {})
	if c.is_empty() or c["kind"] != "auction" or c["state"] != "outstanding": return FrontierStore.err("No open auction.")
	if not Tiers.can(actor, "contract") or c["issuer"] == me or not _can_see(c, me): return FrontierStore.err("Not allowed.")
	var top := int(c["bids"].back()["amount"]) if not c["bids"].is_empty() else int(c["reward"])
	if amount <= top and not (c["bids"].is_empty() and amount >= top): return FrontierStore.err("Bid more than %d." % top)
	var snap := _snap()
	c["bids"].append({"by": me, "amount": amount, "t": FrontierStore.now()})
	if c["expires"] - FrontierStore.now() < AUCTION_EXTEND_S: c["expires"] = FrontierStore.now() + AUCTION_EXTEND_S
	if c["buyout"] > 0 and amount >= c["buyout"]: c["state"] = "completed"; c["taker"] = me
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"state": c["state"]}))

## Taker reports delivery / done; issuer (or staff) confirms with confirm=true, or fails it.
static func complete(actor: Variant, cid: String, success := true) -> Dictionary:
	var me := Tiers.actor_id(actor)
	var c: Dictionary = _db()["contracts"].get(cid, {})
	if c.is_empty() or c["state"] != "in_progress": return FrontierStore.err("Not in progress.")
	var issuer_ok: bool = c["issuer"] == me or Tiers.can(actor, "moderate") or (c["kind"] == "mission" and Tiers.can(actor, "mission_create"))
	if not issuer_ok and not (c["kind"] == "mission" and c["taker"] == me and success): return FrontierStore.err("The issuer confirms.")
	var snap := _snap()
	c["state"] = "completed" if success else "failed"
	c["closed"] = FrontierStore.now()
	if c["kind"] == "mission" and c["faction"] != "":
		var r: Dictionary = _db()["rep"].get(c["taker"], {})
		r[c["faction"]] = clampi(int(r.get(c["faction"], 0)) + (int(c["rep"]) if success else -int(c["rep"]) / 2), -100, 100)
		_db()["rep"][c["taker"]] = r
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"state": c["state"]}))

static func cancel(actor: Variant, cid: String) -> Dictionary:
	var c: Dictionary = _db()["contracts"].get(cid, {})
	if c.is_empty() or c["state"] != "outstanding": return FrontierStore.err("Only outstanding contracts can be cancelled.")
	if c["issuer"] != Tiers.actor_id(actor) and not Tiers.can(actor, "moderate"): return FrontierStore.err("Not yours.")
	var snap := _snap(); c["state"] = "cancelled"
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

## Expire outstanding contracts past their time; close finished auctions to the top bidder.
static func sweep() -> int:
	var n := 0
	var t := FrontierStore.now()
	for cid in _db()["contracts"]:
		var c: Dictionary = _db()["contracts"][cid]
		if c["state"] == "outstanding" and c["expires"] <= t:
			if c["kind"] == "auction" and not c["bids"].is_empty():
				c["state"] = "completed"; c["taker"] = c["bids"].back()["by"]
			else: c["state"] = "expired"
			n += 1
	if n > 0: SecureFile.write_json(FrontierStore.path(STORE), _db())
	return n

static func reputation(id: String, faction: String) -> Dictionary:
	var v := int(_db()["rep"].get(id, {}).get(faction, 0))
	var rank := "Disliked" if v < 0 else "Unknown"
	for r in REP_RANKS:
		if v >= r[0]: rank = r[1]
	return {"value": v, "rank": rank}

static func stats() -> Dictionary:
	var by := {}
	for cid in _db()["contracts"]:
		var s: String = _db()["contracts"][cid]["state"]
		by[s] = int(by.get(s, 0)) + 1
	return {"total": _db()["contracts"].size(), "outstanding": int(by.get("outstanding", 0)), "in_progress": int(by.get("in_progress", 0)), "completed": int(by.get("completed", 0))}
