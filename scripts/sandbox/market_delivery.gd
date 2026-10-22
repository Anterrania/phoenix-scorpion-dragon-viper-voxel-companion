class_name MarketDelivery
extends RefCounted
## SBX-5: marketplace delivery + magic-box vendors (web-store-to-in-world delivery as on OpenSim
## grids), rebuilt in our own code on top of the local Marketplace model (scripts/economy/marketplace.gd).
##
## Listing ("product"): {id, merchant, title, items: [{name, kind, perms: {copy, modify, transfer}}],
##   export: bool (merchant sets it), price_aethel, status: "draft"|"active"|"paused"}.
##   Product permissions are derived from the items (no one can sell more rights than they hold):
##   modify = any item modifiable, copy = every item copyable, transfer = every item transferable.
## Order: {id, listing, buyer, recipient, status: "delivered"|"pending_accept"|"refused", folder, boxed}.
##   Same-grid deliveries land in the recipient's "Received/<product>" folder at once.
##   Other-grid recipients ("grid:Name/Avatar") get a boxed order and must accept (needs export=true).
##   Gifts to another avatar need transfer. Redelivery is free and never duplicates.
## Magic box: an in-world vendor object on a parcel that shows the merchant's active listings and
##   delivers through the same order flow. Placing one needs "sell" AND build rights on that parcel.
## Money: LEGAL REVIEW (general information, pending counsel review). Priced listings are FIXED-PRICE
##   Aethel Coin purchases through AethelLedger.purchase_fixed (LegalReview: 13+, launch country,
##   price shown, spend limits). Anything won by chance (FreePlay cosmetics) can never be listed or
##   gifted (LegalReview "p2p_chance_item_trade" is HARD-disabled).

const STATUSES := ["draft", "active", "paused"]

static var _m = null

static func _all() -> Dictionary:
	if _m == null:
		var d: Variant = SandboxGate.load_json("market", {})
		_m = d if d is Dictionary else {}
		for k in ["listings", "orders", "boxes", "received"]:
			if not _m.has(k): _m[k] = {}
	return _m
static func _save() -> bool: return SandboxGate.save_json("market", _all())

static func derived_perms(items: Array) -> Dictionary:
	var out := {"copy": not items.is_empty(), "modify": false, "transfer": not items.is_empty()}
	for it in items:
		var p: Dictionary = it.get("perms", {})
		out["modify"] = out["modify"] or bool(p.get("modify", false))
		out["copy"] = out["copy"] and bool(p.get("copy", false))
		out["transfer"] = out["transfer"] and bool(p.get("transfer", false))
	return out

static func create_listing(actor: Variant, id: String, title: String, items: Array, price_aethel := 0, export := false) -> String:
	if not SandboxGate.can(actor, "sell"): return "Selling needs Creator tier or higher."
	if id == "" or not id.is_valid_identifier(): return "Listing id must be letters, digits and _."
	if _all()["listings"].has(id): return "That listing id is taken."
	if items.is_empty() or items.size() > 500: return "A listing holds 1 to 500 items."
	for it in items:   # HARD-disabled: chance-won items are bound to the account (LegalReview p2p_chance_item_trade)
		if bool(it.get("chance_won", false)) or FreePlay.is_chance_won(SandboxGate.id_of(actor), str(it.get("id", ""))):
			return "Prizes are bound to your account and can't be sold."
	var p := derived_perms(items)
	if not (p["copy"] or p["transfer"]): return "Items need copy or transfer to be sold."
	if price_aethel < 0: return "Price can't be negative."
	_all()["listings"][id] = {"id": id, "merchant": SandboxGate.id_of(actor), "title": title.left(120), "items": items.duplicate(true),
		"perms": p, "export": export, "price_aethel": price_aethel, "status": "draft"}
	return "" if _save() else "Saves are sealed. Unlock first."

static func listing(id: String) -> Dictionary: return _all()["listings"].get(id, {})

static func set_status(actor: Variant, id: String, status: String) -> String:
	var l := listing(id)
	if l.is_empty(): return "No such listing."
	if not status in STATUSES: return "Unknown status."
	var mine := str(l["merchant"]) == SandboxGate.id_of(actor) and SandboxGate.can(actor, "sell")
	if not (mine or SandboxGate.can(actor, "approve_listing")): return "Only the merchant or the owner."
	l["status"] = status
	return "" if _save() else "Saves are sealed. Unlock first."


## Buy (or gift) a listing. recipient "" = yourself; "grid:Grid/Avatar" = another grid.
## ctx = LegalReview context for priced items: {age, country, price_shown: true once the UI showed it}.
static func deliver(actor: Variant, listing_id: String, recipient := "", now := 0, ctx: Dictionary = {}) -> Dictionary:
	if not SandboxGate.can(actor, "trade"): return {"error": "Shopping needs Resident tier or higher."}
	var l := listing(listing_id)
	if l.is_empty() or str(l["status"]) != "active": return {"error": "That item isn't for sale right now."}
	var buyer := SandboxGate.id_of(actor)
	var to := recipient if recipient != "" else buyer
	if to != buyer and not bool(l["perms"]["transfer"]): return {"error": "No-transfer items can't be gifts."}
	var foreign := to.begins_with("grid:")
	if foreign and not bool(l.get("export", false)): return {"error": "This item can't leave Viper (no export permission)."}
	var oid := "ord_%s" % ("%s|%s|%s" % [listing_id, buyer, to]).sha256_text().left(14)
	var orders: Dictionary = _all()["orders"]
	if orders.has(oid) and bool(l["perms"]["copy"]): return orders[oid]   # copyable: already owned, no second charge (use redeliver)
	var price := int(l.get("price_aethel", 0))
	var paid := {}
	if price > 0:
		# Deny by default: paid items go to the buyer only (no buying coin value for someone else).
		if to != buyer: return {"error": "Paid items can only be bought for yourself."}
		var c := ctx.duplicate(); c["price_shown"] = bool(ctx.get("price_shown", false)) and int(ctx.get("shown_price", -1)) == price
		paid = AethelLedger.purchase_fixed(buyer, listing_id, price, c, now)
		if paid.has("error"): return paid
	if orders.has(oid): oid += "_%d" % orders.size()
	var o := {"id": oid, "listing": listing_id, "buyer": buyer, "recipient": to, "at": now, "txn": paid.get("id", ""),
		"folder": "Received/" + str(l["title"]), "boxed": foreign, "status": "pending_accept" if foreign else "delivered"}
	orders[oid] = o
	if not foreign: _put(to, o, l)
	return o if _save() else {"error": "Saves are sealed. Unlock first."}

static func _put(to: String, o: Dictionary, l: Dictionary) -> void:
	var inbox: Dictionary = _all()["received"].get(to, {})
	inbox[o["id"]] = {"folder": o["folder"], "listing": l["id"], "items": l["items"].duplicate(true),
		"perms": l["perms"].duplicate(), "creator": l["merchant"]}
	_all()["received"][to] = inbox

## Other-grid recipient confirms the boxed order (the "click the message to receive" step).
static func accept_delivery(order_id: String) -> String:
	var o: Dictionary = _all()["orders"].get(order_id, {})
	if str(o.get("status", "")) != "pending_accept": return "Nothing to accept."
	o["status"] = "delivered"
	_put(str(o["recipient"]), o, listing(str(o["listing"])))
	return "" if _save() else "Saves are sealed. Unlock first."

## Redeliver a past order (lost item). Buyer or owner only. Never duplicates the folder.
static func redeliver(actor: Variant, order_id: String) -> String:
	var o: Dictionary = _all()["orders"].get(order_id, {})
	if o.is_empty(): return "No such order."
	if str(o["buyer"]) != SandboxGate.id_of(actor) and not SandboxGate.can(actor, "grant"): return "Only the buyer can ask for redelivery."
	if str(o["status"]) != "delivered": return "That order isn't delivered yet."
	_put(str(o["recipient"]), o, listing(str(o["listing"])))
	return "" if _save() else "Saves are sealed. Unlock first."

static func received(member: String) -> Dictionary: return _all()["received"].get(member, {})

# ---------- magic box vendor ----------
static func place_box(actor: Variant, box_id: String, region: String, parcel: String) -> String:
	if not SandboxGate.can(actor, "sell"): return "Vendor boxes need Creator tier or higher."
	if not SandboxGate.can(actor, "place", {"region": region, "parcel": parcel}): return "You can't build on that parcel."
	if box_id == "" or _all()["boxes"].has(box_id): return "Pick a new box id."
	_all()["boxes"][box_id] = {"id": box_id, "merchant": SandboxGate.id_of(actor), "region": region, "parcel": parcel}
	return "" if _save() else "Saves are sealed. Unlock first."

## What the box shows: the merchant's active listings (synced live, nothing stored in the box).
static func box_stock(box_id: String) -> Array:
	var b: Dictionary = _all()["boxes"].get(box_id, {})
	if b.is_empty(): return []
	var out: Array = []
	for id in _all()["listings"]:
		var l: Dictionary = _all()["listings"][id]
		if str(l["merchant"]) == str(b["merchant"]) and str(l["status"]) == "active": out.append(l)
	return out

static func vend(actor: Variant, box_id: String, listing_id: String, now := 0, ctx: Dictionary = {}) -> Dictionary:
	var b: Dictionary = _all()["boxes"].get(box_id, {})
	if b.is_empty(): return {"error": "No such vendor."}
	if not Tiers.can(actor, "enter", {"region": b["region"], "parcel": b["parcel"]}): return {"error": "You can't reach that vendor."}
	if not box_stock(box_id).any(func(l): return l["id"] == listing_id): return {"error": "This vendor doesn't sell that."}
	return deliver(actor, listing_id, "", now, ctx)

static func reset_for_tests() -> void: _m = null
