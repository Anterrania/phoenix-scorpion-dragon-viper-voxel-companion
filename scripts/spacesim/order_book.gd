class_name OrderBook
extends RefCounted
## Regional market order book (buy + sell orders per item and location), generalising the
## CurrencyExchange scaffold (scripts/economy/currency_exchange.gd, which stays as the single-pair
## coin exchange model). Concepts: price-time priority, partial fills, order duration + expiry,
## broker fee on resting orders, sales tax on the seller, both burned as sinks, org orders.
##
## LEGAL REVIEW REQUIRED: prices are in Aethel Coin (AEC). Settlement is OFF: orders match and fills
## are recorded with settlement "pending_legal_review"; no coin moves between wallets until the
## economy + legal review land (docs/modules/ECONOMY.md, docs/wiki/aethel-coin-exchange.md).

const STORE := "market"
const LEGAL := "LEGAL REVIEW REQUIRED: Aethel Coin settlement is off. Orders match; nothing moves between wallets."
const CURRENCY := "AEC"
const BROKER_BPS := 100      # 1% of order value when an order rests on the book
const SALES_TAX_BPS := 200   # 2% of each fill, paid by the seller
const MAX_OPEN := 50         # per actor
const MAX_QTY := 1000000
const MAX_PRICE := 1000000000
const MAX_DAYS := 90
const MAX_HISTORY := 200
const SETTLEMENT_ACTIVE := false   # INACTIVE (2026-10-17): coin settlement. Why: LEGAL REVIEW REQUIRED. Re-enable: legal sign-off + Ledger persistence.

static func _db() -> Dictionary: return FrontierStore.db(STORE, {"orders": [], "fills": [], "sinks": 0})
static func _snap() -> Dictionary: _db(); return FrontierStore.snap(STORE)

static func market_key(item: String, location := "global") -> String: return location + "|" + item

## opts: location ("global" or a region id), days (1..90; 0 = immediate: fill what you can, rest is
## dropped, no broker fee), org (a Social group id; needs the org "trade" right).
static func place(actor: Variant, side: String, item: String, qty: int, price: int, opts := {}) -> Dictionary:
	var me := Tiers.actor_id(actor)
	if not Tiers.can(actor, "trade"): return FrontierStore.err("Residents and up can trade.")
	if not side in ["buy", "sell"]: return FrontierStore.err("Buy or sell?")
	var it := FrontierStore.clean(item, 64)
	if it == "" or qty < 1 or qty > MAX_QTY or price < 1 or price > MAX_PRICE: return FrontierStore.err("Check the item, quantity and price.")
	var org := str(opts.get("org", ""))
	if org != "" and not OrgRights.has(actor, org, "trade"): return FrontierStore.err("Needs the org trade right.")
	var days := clampi(int(opts.get("days", 14)), 0, MAX_DAYS)
	var loc := FrontierStore.clean(opts.get("location", "global"), 64)
	if open_orders(me).size() >= MAX_OPEN: return FrontierStore.err("Up to %d open orders." % MAX_OPEN)
	var snap := _snap()
	var t := FrontierStore.now()
	var o := {"id": FrontierStore.next_id(STORE, "o"), "owner": me, "org": org, "side": side, "item": it, "location": loc,
		"qty": qty, "qty0": qty, "price": price, "t": t, "expires": t + days * 86400, "state": "open", "broker_fee": 0}
	var fills := _match(o)
	if o["qty"] > 0 and days > 0:
		o["broker_fee"] = maxi(1, o["qty"] * price * BROKER_BPS / 10000)
		_db()["sinks"] = int(_db()["sinks"]) + o["broker_fee"]
		_db()["orders"].append(o)
	else:
		o["state"] = "filled" if o["qty"] == 0 else "dropped"
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"order": o.duplicate(), "fills": fills, "legal": LEGAL}))

static func _match(o: Dictionary) -> Array:
	var fills: Array = []
	var other := "sell" if o["side"] == "buy" else "buy"
	var book: Array = _db()["orders"].filter(func(x): return x["state"] == "open" and x["side"] == other and x["item"] == o["item"] and x["location"] == o["location"] and x["owner"] != o["owner"] and x["expires"] > FrontierStore.now())
	# best price first, then oldest
	book.sort_custom(func(a, b): return (a["price"] < b["price"] if other == "sell" else a["price"] > b["price"]) if a["price"] != b["price"] else a["t"] < b["t"])
	for r in book:
		if o["qty"] == 0: break
		if (o["side"] == "buy" and r["price"] > o["price"]) or (o["side"] == "sell" and r["price"] < o["price"]): break
		var q: int = mini(o["qty"], r["qty"])
		var p: int = r["price"]   # resting order sets the price
		var tax := q * p * SALES_TAX_BPS / 10000
		var f := {"id": FrontierStore.next_id(STORE, "f"), "item": o["item"], "location": o["location"], "qty": q, "price": p,
			"buyer": o["owner"] if o["side"] == "buy" else r["owner"], "seller": r["owner"] if o["side"] == "buy" else o["owner"],
			"sales_tax": tax, "currency": CURRENCY, "t": FrontierStore.now(),
			"settlement": "settled" if SETTLEMENT_ACTIVE else "pending_legal_review"}
		o["qty"] -= q; r["qty"] -= q
		if r["qty"] == 0: r["state"] = "filled"
		_db()["sinks"] = int(_db()["sinks"]) + tax
		_db()["fills"].append(f); fills.append(f.duplicate())
	while _db()["fills"].size() > MAX_HISTORY: _db()["fills"].pop_front()
	return fills

static func cancel(actor: Variant, oid: String) -> Dictionary:
	for o in _db()["orders"]:
		if o["id"] == oid and o["state"] == "open":
			if o["owner"] != Tiers.actor_id(actor) and not Tiers.can(actor, "moderate"): return FrontierStore.err("Not your order.")
			var snap := _snap()
			for x in _db()["orders"]:
				if x["id"] == oid: x["state"] = "cancelled"   # broker fee is not refunded
			return FrontierStore.commit(STORE, snap, FrontierStore.ok())
	return FrontierStore.err("No open order with that id.")

## Expire old orders and drop closed ones from the live list. Returns how many expired.
static func expire() -> int:
	var n := 0
	var t := FrontierStore.now()
	for o in _db()["orders"]:
		if o["state"] == "open" and o["expires"] <= t: o["state"] = "expired"; n += 1
	_db()["orders"] = _db()["orders"].filter(func(o): return o["state"] == "open")
	SecureFile.write_json(FrontierStore.path(STORE), _db())
	return n

static func book(item: String, location := "global", depth := 10) -> Dictionary:
	var live: Array = _db()["orders"].filter(func(o): return o["state"] == "open" and o["item"] == item and o["location"] == location and o["expires"] > FrontierStore.now())
	var bids := live.filter(func(o): return o["side"] == "buy")
	var asks := live.filter(func(o): return o["side"] == "sell")
	bids.sort_custom(func(a, b): return a["price"] > b["price"])
	asks.sort_custom(func(a, b): return a["price"] < b["price"])
	var strip := func(o): return {"id": o["id"], "qty": o["qty"], "price": o["price"]}
	return {"item": item, "location": location, "bids": bids.slice(0, depth).map(strip), "asks": asks.slice(0, depth).map(strip),
		"spread": (asks[0]["price"] - bids[0]["price"]) if not bids.is_empty() and not asks.is_empty() else -1, "legal": LEGAL}

static func open_orders(id: String) -> Array:
	return _db()["orders"].filter(func(o): return o["owner"] == id and o["state"] == "open").duplicate(true)

static func history(item := "", limit := 20) -> Array:
	var out: Array = []
	for i in range(_db()["fills"].size() - 1, -1, -1):
		var f: Dictionary = _db()["fills"][i]
		if item == "" or f["item"] == item: out.append(f.duplicate())
		if out.size() >= limit: break
	return out

static func stats() -> Dictionary:
	var open: Array = _db()["orders"].filter(func(o): return o["state"] == "open")
	var items := {}
	for o in open: items[o["item"]] = true
	return {"open_orders": open.size(), "items": items.size(), "fills": _db()["fills"].size(), "sinks": int(_db()["sinks"]), "settlement": "on" if SETTLEMENT_ACTIVE else "off (legal review)"}
