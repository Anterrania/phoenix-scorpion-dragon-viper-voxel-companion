# SCAFFOLD: append-only double-entry ledger for the VIRTUAL in-game currency.
# Amounts are integers (smallest unit). No real-money value. See docs/modules/ECONOMY_BANKING.md.
class_name Ledger
extends RefCounted

var _entries: Array[Dictionary] = []  # {id, ts, from, to, amount, memo}

## HARD-DISABLED (SBX-LEGAL-1): member-to-member coin transfer ("p2p_coin_transfer") needs counsel and
## a LegalReview code change. Only system accounts ("mint" or "sys:...") may be on one side.
## Aethel Coin itself lives in AethelLedger; this scaffold is not wired to it.
static func is_system(acct: String) -> bool: return acct == "mint" or acct.begins_with("sys:")

func transfer(from_acct: String, to_acct: String, amount: int, memo := "") -> bool:
	if amount <= 0 or from_acct == to_acct:
		return false
	if not is_system(from_acct) and not is_system(to_acct) and not LegalReview.allowed("p2p_coin_transfer"):
		return false
	if from_acct != "mint" and balance(from_acct) < amount:
		return false
	_entries.append({"id": _entries.size(), "ts": Time.get_unix_time_from_system(),
		"from": from_acct, "to": to_acct, "amount": amount, "memo": memo})
	return true

func balance(acct: String) -> int:
	var b := 0
	for e in _entries:
		if e.to == acct: b += e.amount
		if e.from == acct: b -= e.amount
	return b

func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)
