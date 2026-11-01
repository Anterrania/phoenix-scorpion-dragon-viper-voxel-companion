class_name CreatorEconomy
extends RefCounted
## v0.13 ECON-1: creators profit from their content, social-media style, in Sparks.
## Sparks are an IN-GAME credit only: never bought with money, never cashed out, never exchanged for or
## converted into Aethel Coin or play tokens (LegalReview sparks_purchase / sparks_cashout / sparks_convert
## are HARD). Spend them in-world: shops, cosmetics, boosts, land fees, tipping other creators.
## Earn them three ways:
##   1. Views:  the creator fund pays VIEW_RATE per UNIQUE viewer per post (own views never count),
##              up to DAILY_VIEW_CAP per creator per day. Hooked from Social.record_view().
##   2. Tips:   a member tips a creator from their own Sparks (MIN_TIP..MAX_TIP, no self-tips, 13+).
##   3. Sales:  when a marketplace item sells (fixed price, Aethel Coin, already LegalReview-gated), the
##              creator fund pays the creator CREATOR_SHARE of the price in Sparks. The Aethel Coin itself
##              is not moved between members (p2p_coin_transfer stays HARD).
## Casino stays free-play (PlayTokens). Aethel Coin real-money exchange stays LEGAL REVIEW (HARD).
## File: <LegalReview.root>/creator_sparks.json via SecureFile.

const FUND := "sys:creator_fund"
const VIEW_RATE := 1
const DAILY_VIEW_CAP := 1000
const CREATOR_SHARE := 0.70
const MIN_TIP := 1
const MAX_TIP := 500
const TIP_MIN_AGE := 13
const MAX_TXNS := 5000

static var _d = null

static func _path() -> String: return LegalReview.root.path_join("creator_sparks.json")
static func _all() -> Dictionary:
	if _d == null:
		var x: Variant = SecureFile.read_json(_path(), {})
		_d = x if x is Dictionary else {}
		for k in ["balances", "txns", "views", "daily"]:
			if not _d.has(k): _d[k] = {} if k != "txns" else []
	return _d
static func _save() -> bool:
	var t: Array = _all()["txns"]
	if t.size() > MAX_TXNS: _all()["txns"] = t.slice(-MAX_TXNS)
	return SecureFile.write_json(_path(), _all())

static func balance(member: String) -> int: return int(_all()["balances"].get(member, 0))

static func _credit(member: String, amount: int, kind: String, ref: String, now: int, from := FUND) -> void:
	_all()["balances"][member] = balance(member) + amount
	_all()["txns"].append({"member": member, "kind": kind, "amount": amount, "ref": ref.left(64), "from": from, "at": now})

static func _day(now: int) -> String: return Time.get_date_string_from_unix_time(now)

## Social.record_view hook. Returns Sparks credited (0 when it doesn't count).
static func on_unique_view(creator: String, post_id: String, viewer: String, now := 0) -> int:
	if creator == "" or viewer == "" or creator == viewer: return 0
	var t := now if now > 0 else int(Time.get_unix_time_from_system())
	var vk := post_id + ">" + viewer
	if _all()["views"].has(vk): return 0
	var dk := creator + "@" + _day(t)
	var today := int(_all()["daily"].get(dk, 0))
	if today >= DAILY_VIEW_CAP: return 0
	_all()["views"][vk] = t
	_all()["daily"][dk] = today + VIEW_RATE
	_credit(creator, VIEW_RATE, "view", post_id, t)
	return VIEW_RATE if _save() else 0

## Member -> creator tip, Sparks only. ctx: {age}. Returns "" or an error.
static func tip(from: String, to: String, amount: int, ctx: Dictionary = {}, ref := "", now := 0) -> String:
	if from == "" or to == "" or from == to: return "You can't tip yourself."
	if amount < MIN_TIP or amount > MAX_TIP: return "Tips are %d to %d Sparks." % [MIN_TIP, MAX_TIP]
	var lr := LegalReview.check("sparks_tip", ctx)
	if not lr["ok"]: return str(lr["reason"])
	if balance(from) < amount: return "Not enough Sparks."
	var t := now if now > 0 else int(Time.get_unix_time_from_system())
	_all()["balances"][from] = balance(from) - amount
	_all()["txns"].append({"member": from, "kind": "tip_sent", "amount": -amount, "ref": ref.left(64), "to": to, "at": t})
	_credit(to, amount, "tip", ref, t, from)
	return "" if _save() else "Saves are sealed. Unlock first."

## Marketplace sale hook: creator gets CREATOR_SHARE of the price, in Sparks, from the creator fund.
static func on_sale(creator: String, item_id: String, price: int, now := 0) -> int:
	if creator == "" or price <= 0: return 0
	var share := int(floor(float(price) * CREATOR_SHARE))
	if share <= 0: return 0
	_credit(creator, share, "sale", item_id, now if now > 0 else int(Time.get_unix_time_from_system()))
	return share if _save() else 0

## Spend in-world (shops, boosts, cosmetics). Returns "" or an error.
static func spend(member: String, amount: int, what: String, now := 0) -> String:
	if amount <= 0: return "Bad amount."
	if balance(member) < amount: return "Not enough Sparks."
	_all()["balances"][member] = balance(member) - amount
	_all()["txns"].append({"member": member, "kind": "spend", "amount": -amount, "ref": what.left(64), "at": now if now > 0 else int(Time.get_unix_time_from_system())})
	return "" if _save() else "Saves are sealed. Unlock first."

## Creator statement: balance + earnings split by source.
static func statement(member: String) -> Dictionary:
	var s := {"balance": balance(member), "views": 0, "tips": 0, "sales": 0, "spent": 0}
	for x in _all()["txns"]:
		if x["member"] != member: continue
		match str(x["kind"]):
			"view": s["views"] += int(x["amount"])
			"tip": s["tips"] += int(x["amount"])
			"sale": s["sales"] += int(x["amount"])
			"spend", "tip_sent": s["spent"] -= int(x["amount"])
	return s

static func reset_for_tests() -> void: _d = null
