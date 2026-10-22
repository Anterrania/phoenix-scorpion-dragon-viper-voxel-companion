class_name AethelLedger
extends RefCounted
## SBX-LEGAL-4: the Aethel Coin ledger, kept apart from play tokens (PlayTokens). File:
## user://legal/aethel_ledger.json. LEGAL REVIEW: general information, pending counsel review.
## What Aethel Coin may do now: buy FIXED-PRICE items with the price shown (LegalReview
## "aethel_fixed_price_purchase": 13+, launch country, spend limits). That's it.
## Coins enter a balance only through owner_adjust() (logged, owner only) or refund() (reverses a
## purchase). Nothing random can credit coins: there is no payout function, and the test suite
## scans for one (tests/sandbox_dev_tests.gd "no random Aethel"). HARD-disabled by design, no endpoint
## exists for: wagers, cash-out, exchange, member-to-member transfer, buying play tokens.

const REFUND_WINDOW_S := 14 * 86400
static var _d = null

static func _path() -> String: return LegalReview.root.path_join("aethel_ledger.json")
static func _all() -> Dictionary:
	if _d == null:
		var x: Variant = SecureFile.read_json(_path(), {})
		_d = x if x is Dictionary else {}
		if not _d.has("balances"): _d["balances"] = {}
		if not _d.has("txns"): _d["txns"] = []
	return _d
static func _save() -> bool: return SecureFile.write_json(_path(), _all())

static func balance(member: String) -> int: return int(_all()["balances"].get(member, 0))
static func txns(member: String) -> Array: return _all()["txns"].filter(func(x): return x["member"] == member)

## Owner-only manual adjustment (local test wallet / support fixes). Never called from game logic.
static func owner_adjust(member: String, delta: int, memo: String, now: int) -> String:
	if not Tiers.owner_session(): return "Owner unlock needed."
	if balance(member) + delta < 0: return "Balance can't go below zero."
	_all()["balances"][member] = balance(member) + delta
	_all()["txns"].append({"id": "adj_%d" % _all()["txns"].size(), "member": member, "kind": "owner_adjust", "amount": delta, "memo": memo.left(80), "at": now})
	return "" if _save() else "Saves are sealed. Unlock first."

## Buy a fixed-price item. ctx carries age/country and must say the price was shown.
static func purchase_fixed(member: String, item_id: String, price: int, ctx: Dictionary, now: int) -> Dictionary:
	var c := ctx.duplicate(); c["fixed_price"] = true
	var lr := LegalReview.check("aethel_fixed_price_purchase", c)
	if not lr["ok"]: return {"error": lr["reason"]}
	if price <= 0: return {"error": "Fixed price must be above zero."}
	var lim := SpendLimits.check(member, price, int(ctx.get("age", -1)), now)
	if lim != "": return {"error": lim}
	if balance(member) < price: return {"error": "Not enough Aethel Coin."}
	_all()["balances"][member] = balance(member) - price
	var tx := {"id": "buy_%d" % _all()["txns"].size(), "member": member, "kind": "purchase", "item": item_id,
		"amount": -price, "at": now, "refund": ""}
	_all()["txns"].append(tx)
	if not _save(): return {"error": "Saves are sealed. Unlock first."}
	SpendLimits.record(member, price, now)
	return tx

## Refund flow (stub): the buyer requests inside the window, the owner approves. Approval credits
## the exact price back and marks the item to be revoked by the caller.
static func request_refund(member: String, txn_id: String, reason: String, now: int) -> String:
	for tx in _all()["txns"]:
		if tx["id"] == txn_id and tx["member"] == member and tx["kind"] == "purchase":
			if str(tx["refund"]) != "": return "Already requested."
			if now - int(tx["at"]) > REFUND_WINDOW_S: return "Refund window has closed."
			tx["refund"] = "requested"; tx["refund_reason"] = reason.left(200)
			return "" if _save() else "Saves are sealed. Unlock first."
	return "No such purchase."

static func approve_refund(txn_id: String, now: int) -> Dictionary:
	if not Tiers.owner_session(): return {"error": "Owner unlock needed."}
	for tx in _all()["txns"]:
		if tx["id"] == txn_id and str(tx.get("refund", "")) == "requested":
			tx["refund"] = "approved"; tx["refunded_at"] = now
			_all()["balances"][tx["member"]] = balance(tx["member"]) - int(tx["amount"])
			return {"revoke_item": tx["item"], "member": tx["member"]} if _save() else {"error": "Saves are sealed. Unlock first."}
	return {"error": "No pending refund."}

static func reset_for_tests() -> void: _d = null
