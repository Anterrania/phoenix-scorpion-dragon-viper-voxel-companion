class_name Blueprints
extends RefCounted
## LIFE-6: blueprints for "blueprint": true recipes, with copy / modify / transfer permissions
## (the classic next-owner permission idea; original code and names).
## - original: unlimited runs, owned by its creator. copy: a limited-run print made from an original.
## - perms {"copy", "modify", "transfer"} limit what the NEXT owner may do.
## - Listings: fixed price only. Currencies: "free" and "civic_credit" (earned in game, never bought,
##   never cashed out) work. "aethel_coin" purchases and seller payouts are BLOCKED:
##   LEGAL REVIEW REQUIRED (AEC_PAYOUTS / CASH_OUT stay false). No auctions, no randomized items.
## - Listing needs Tiers.can(actor, "marketplace") (creator tier) and copy or transfer perms.
## State: user://living/blueprints.json through SecureFile.

const AEC_PAYOUTS := false   # LEGAL REVIEW REQUIRED
const CASH_OUT := false      # LEGAL REVIEW REQUIRED
const CURRENCIES := ["free", "civic_credit"]
static var root := "user://living"
static var _db = null

static func _d() -> Dictionary:
	if _db == null:
		var d: Variant = SecureFile.read_json(root.path_join("blueprints.json"), {})
		_db = d if d is Dictionary else {}
		for k in ["items", "listings", "credits"]:
			if not _db.has(k): _db[k] = {}
		if not _db.has("seq"): _db["seq"] = 0
	return _db

static func _save() -> bool: return SecureFile.write_json(root.path_join("blueprints.json"), _d())
static func _new_id(prefix: String) -> String:
	_d()["seq"] = int(_d()["seq"]) + 1
	return "%s%d" % [prefix, _d()["seq"]]

static func item(id: String) -> Dictionary: return _d()["items"].get(id, {}).duplicate(true)
static func owned_by(owner: String) -> Array:
	return _d()["items"].keys().filter(func(k): return _d()["items"][k]["owner"] == owner)
static func credits(id: String) -> int: return int(_d()["credits"].get(id, 0))

## Civic credits are earned by play only (quests, jobs). There is no purchase path.
static func earn_credits(id: String, amount: int) -> bool:
	if amount <= 0: return false
	_d()["credits"][id] = credits(id) + amount
	return _save()

## Author an original blueprint for a recipe the actor can already craft (creator tier).
static func create(actor: Variant, recipe_id: String, perms := {"copy": true, "modify": true, "transfer": true}) -> Dictionary:
	if not Tiers.can(actor, "upload"): return {"ok": false, "error": "Creator tier or higher can author blueprints."}
	if not bool(Materials.recipe(recipe_id).get("blueprint", false)): return {"ok": false, "error": "That recipe has no blueprint."}
	var id := _new_id("bp")
	var me := Tiers.actor_id(actor)
	_d()["items"][id] = {"id": id, "recipe": recipe_id, "creator": me, "owner": me, "kind": "original", "runs": -1,
		"perms": {"copy": bool(perms.get("copy", true)), "modify": bool(perms.get("modify", true)), "transfer": bool(perms.get("transfer", true))}}
	return {"ok": _save(), "error": "", "id": id}

## "" if actor may run recipe `runs` times with blueprint bp.
static func can_use(actor: Variant, bp: String, recipe_id: String, runs := 1) -> String:
	if LivingGate.exempt(actor): return ""
	var it: Dictionary = _d()["items"].get(bp, {})
	if it.is_empty(): return "You need the blueprint."
	if it["owner"] != Tiers.actor_id(actor): return "That blueprint isn't yours."
	if it["recipe"] != recipe_id: return "Wrong blueprint."
	if int(it["runs"]) >= 0 and int(it["runs"]) < runs: return "Not enough runs left on this copy."
	return ""

static func consume_runs(actor: Variant, bp: String, runs: int) -> String:
	if LivingGate.exempt(actor) and not _d()["items"].has(bp): return ""
	var it: Dictionary = _d()["items"].get(bp, {})
	if it.is_empty(): return "You need the blueprint."
	if int(it["runs"]) < 0: return ""
	it["runs"] = int(it["runs"]) - runs
	if int(it["runs"]) <= 0: _d()["items"].erase(bp)
	return "" if _save() else "Saves are sealed."

## Make a limited-run copy from an original you own (needs copy perm unless you're the creator).
static func make_copy(actor: Variant, bp: String, runs: int, to := "") -> Dictionary:
	var it: Dictionary = _d()["items"].get(bp, {})
	var me := Tiers.actor_id(actor)
	if it.is_empty() or it["owner"] != me: return {"ok": false, "error": "Not your blueprint."}
	if it["kind"] != "original": return {"ok": false, "error": "Copy from an original."}
	if not bool(it["perms"]["copy"]) and it["creator"] != me: return {"ok": false, "error": "No copy permission."}
	var id := _new_id("bp")
	var c: Dictionary = it.duplicate(true)
	c["id"] = id; c["kind"] = "copy"; c["runs"] = clampi(runs, 1, 1000); c["owner"] = to if to != "" else me
	_d()["items"][id] = c
	return {"ok": _save(), "error": "", "id": id}

static func set_perms(actor: Variant, bp: String, perms: Dictionary) -> String:
	var it: Dictionary = _d()["items"].get(bp, {})
	var me := Tiers.actor_id(actor)
	if it.is_empty() or it["owner"] != me: return "Not your blueprint."
	if not bool(it["perms"]["modify"]) and it["creator"] != me: return "No modify permission."
	for k in ["copy", "modify", "transfer"]:
		# next owners can only lose permissions, never gain them back
		if perms.has(k): it["perms"][k] = bool(perms[k]) and (bool(it["perms"][k]) or it["creator"] == me)
	return "" if _save() else "Saves are sealed."

static func give(actor: Variant, bp: String, to: String) -> String:
	var it: Dictionary = _d()["items"].get(bp, {})
	var me := Tiers.actor_id(actor)
	if it.is_empty() or it["owner"] != me: return "Not your blueprint."
	if not bool(it["perms"]["transfer"]) and it["creator"] != me: return "No transfer permission."
	it["owner"] = to
	return "" if _save() else "Saves are sealed."

## Fixed-price listing. sells "copy" (seller keeps the original) or "original" (transfer).
static func list_for_sale(actor: Variant, bp: String, price: int, currency := "civic_credit", sells := "copy", runs := 10) -> Dictionary:
	if not Tiers.can(actor, "marketplace"): return {"ok": false, "error": "Creator tier or higher can sell."}
	if currency == "aethel_coin": return {"ok": false, "error": "Aethel Coin sales are off: LEGAL REVIEW REQUIRED."}
	if not currency in CURRENCIES: return {"ok": false, "error": "Unknown currency."}
	var it: Dictionary = _d()["items"].get(bp, {})
	var me := Tiers.actor_id(actor)
	if it.is_empty() or it["owner"] != me: return {"ok": false, "error": "Not your blueprint."}
	var creator: bool = it["creator"] == me
	if sells == "copy" and not (creator or bool(it["perms"]["copy"])): return {"ok": false, "error": "No copy permission."}
	if sells == "original" and not (creator or bool(it["perms"]["transfer"])): return {"ok": false, "error": "No transfer permission."}
	if price < 0 or (currency == "free" and price != 0): return {"ok": false, "error": "Bad price."}
	var id := _new_id("ls")
	_d()["listings"][id] = {"id": id, "bp": bp, "seller": me, "price": price, "currency": currency, "sells": sells, "runs": runs}
	return {"ok": _save(), "error": "", "id": id}

static func buy(actor: Variant, listing: String, currency := "") -> Dictionary:
	var l: Dictionary = _d()["listings"].get(listing, {})
	if l.is_empty(): return {"ok": false, "error": "Listing gone."}
	if currency == "aethel_coin" or l["currency"] == "aethel_coin": return {"ok": false, "error": "Aethel Coin purchases are off: LEGAL REVIEW REQUIRED."}
	var me := Tiers.actor_id(actor)
	if me == l["seller"]: return {"ok": false, "error": "That's yours."}
	if not Tiers.can(actor, "post"): return {"ok": false, "error": "Residents and up can buy."}
	var price := int(l["price"])
	if l["currency"] == "civic_credit" and credits(me) < price: return {"ok": false, "error": "Not enough civic credits."}
	var snap := _d().duplicate(true)
	if l["currency"] == "civic_credit" and price > 0:
		_d()["credits"][me] = credits(me) - price
		_d()["credits"][l["seller"]] = credits(l["seller"]) + price   # stays in game; no payout, no cash-out
	var got := ""
	if l["sells"] == "copy":
		var it: Dictionary = _d()["items"].get(l["bp"], {})
		if it.is_empty(): _db = snap; return {"ok": false, "error": "Listing gone."}
		got = _new_id("bp")
		var c: Dictionary = it.duplicate(true)
		c["id"] = got; c["kind"] = "copy"; c["runs"] = int(l["runs"]); c["owner"] = me
		_d()["items"][got] = c
	else:
		got = str(l["bp"]); _d()["items"][got]["owner"] = me
		_d()["listings"].erase(listing)
	if not _save(): _db = snap; return {"ok": false, "error": "Saves are sealed."}
	return {"ok": true, "error": "", "id": got}

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _db = null
