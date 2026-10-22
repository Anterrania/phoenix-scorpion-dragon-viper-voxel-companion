class_name PlayTokens
extends RefCounted
## SBX-LEGAL-2: the play-token ledger. Kept apart from Aethel Coin (AethelLedger) on purpose:
## separate class, separate file (user://legal/play_tokens.json), no shared code path.
## Play tokens are EARNED ONLY (quests, daily play, achievements, events) and only spent on free-play
## games. There is deliberately NO buy, transfer, gift, trade, cash-out or convert function here:
## those are HARD-disabled in LegalReview (play_token_purchase / play_token_transfer / play_token_convert).
## Do not add one without counsel review and a LegalReview code change.

const EARN_SOURCES := ["quest", "daily_play", "achievement", "event", "free_play_win", "refund"]
const MAX_EARN := 500   # per single earn event
const MAX_BALANCE := 100000

static var _d = null

static func _path() -> String: return LegalReview.root.path_join("play_tokens.json")
static func _all() -> Dictionary:
	if _d == null:
		var x: Variant = SecureFile.read_json(_path(), {})
		_d = x if x is Dictionary else {}
	return _d
static func _save() -> bool: return SecureFile.write_json(_path(), _all())

static func balance(member: String) -> int: return int(_all().get(member, {}).get("balance", 0))

## Earn from gameplay. Source must be a gameplay source (never a purchase).
static func earn(member: String, amount: int, source: String, ctx: Dictionary = {}) -> String:
	if not source in EARN_SOURCES: return "Play tokens can only be earned by playing."
	if amount <= 0 or amount > MAX_EARN: return "Bad amount."
	if not LegalReview.allowed("play_token_earn", ctx): return "Not available."
	var a: Dictionary = _all().get(member, {"balance": 0, "earned": 0})
	a["balance"] = mini(int(a["balance"]) + amount, MAX_BALANCE)
	a["earned"] = int(a["earned"]) + amount
	_all()[member] = a
	return "" if _save() else "Saves are sealed. Unlock first."

## Spend on a free-play game (called by FreePlay only).
static func spend(member: String, amount: int) -> String:
	if amount <= 0: return "Bad amount."
	if balance(member) < amount: return "Not enough play tokens. Earn more by playing."
	_all()[member]["balance"] = balance(member) - amount
	return "" if _save() else "Saves are sealed. Unlock first."

static func reset_for_tests() -> void: _d = null
