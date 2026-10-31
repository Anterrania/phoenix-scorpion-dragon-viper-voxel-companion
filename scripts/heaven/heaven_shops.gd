class_name HeavenShops
extends RefCounted
## HEAVEN-4: SL-style shops inside Heaven buildings (clothes, shoes, hair, looks, accessories).
## Two kinds of stock on every shop:
##  - House items (data/heaven/shop_items.json): free starter items, price 0. "Wear" equips them on
##    your avatar through the Inventory autoload (same wardrobe as the Wardrobe panel).
##  - Creator items: ACTIVE marketplace listings (MarketDelivery) whose category matches the shop
##    ("all" shows every category). Buying goes through MarketDelivery.deliver, so the LegalReview
##    gates (age, launch country, price shown, spend limits) apply unchanged. No coin is ever moved
##    by this file.

const SHOPS_PATH := "res://data/heaven/shops.json"
const ITEMS_PATH := "res://data/heaven/shop_items.json"
const CATEGORIES := ["clothes", "shoes", "hair", "looks", "accessories"]
const SLOT_OF := {"clothes": "outfit", "shoes": "shoes", "hair": "hair", "looks": "look", "accessories": "accent"}

static var _shops: Array = []

static func shops() -> Array:
	if _shops.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOPS_PATH)) if FileAccess.file_exists(SHOPS_PATH) else null
		_shops = d.get("shops", []) if d is Dictionary else []
	return _shops

static func shop(id: String) -> Dictionary:
	for s in shops():
		if s["id"] == id: return s
	return {}

static func for_island(island_id: String) -> Array:
	return shops().filter(func(s): return s["island"] == island_id)

static func house_items() -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH)) if FileAccess.file_exists(ITEMS_PATH) else null
	return d.get("items", []) if d is Dictionary else []

## House items of a shop, resolved through Inventory (so they are the same records the wardrobe uses).
static func stock(shop_id: String, inv: Node = null) -> Array:
	var s := shop(shop_id)
	var out: Array = []
	for id in s.get("items", []):
		var it: Dictionary = inv.item(str(id)) if inv else {}
		if it.is_empty():
			for h in house_items():
				if h["id"] == id: it = h
		if not it.is_empty(): out.append(it)
	return out

## Active creator listings for this shop's category.
static func creator_listings(shop_id: String) -> Array:
	var cat := str(shop(shop_id).get("category", ""))
	if not (cat in CATEGORIES or cat == "all"): return []
	var out: Array = []
	for l in MarketDelivery._all()["listings"].values():
		if str(l.get("status", "")) != "active": continue
		if cat == "all" or str(l.get("category", "")) == cat: out.append(l)
	return out

## Wear / take off a house item. Returns "" or a reason.
static func wear(inv: Node, item_id: String, target := "player") -> String:
	if inv == null: return "Wardrobe not ready."
	if inv.item(item_id).is_empty(): return "Not in this shop."
	inv.equip(target, item_id)
	return ""

## Buy a creator listing (fixed price, LegalReview through MarketDelivery). ctx["shown_price"] must be
## the price the screen showed (MarketDelivery checks it); age / country come from the caller's
## confirmed profile (missing = refused, by design).
static func buy(listing_id: String, now: int, ctx: Dictionary) -> Dictionary:
	var c := ctx.duplicate()
	c["price_shown"] = true
	c["fixed_price"] = true
	return MarketDelivery.deliver(Tiers.SELF, listing_id, "", now, c)

static func reset_for_tests() -> void: _shops = []
