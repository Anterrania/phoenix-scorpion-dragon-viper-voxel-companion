# SCAFFOLD: Lindex-style in-game order book (virtual currency <-> in-game token only).
# No fiat. Real-money features are blocked pending Law Bot review.
class_name CurrencyExchange
extends RefCounted

const FEE_BPS := 50  # 0.5% fee, burned (sink)
var bids: Array[Dictionary] = []  # {acct, qty, price}
var asks: Array[Dictionary] = []

func place_order(acct: String, side: String, qty: int, price: int) -> void:
	var o := {"acct": acct, "qty": qty, "price": price}
	if side == "buy":
		bids.append(o); bids.sort_custom(func(a, b): return a.price > b.price)
	else:
		asks.append(o); asks.sort_custom(func(a, b): return a.price < b.price)

## Returns the matched fills. Settlement through Ledger is TODO.
func match_orders() -> Array[Dictionary]:
	var fills: Array[Dictionary] = []
	while not bids.is_empty() and not asks.is_empty() and bids[0].price >= asks[0].price:
		var q: int = min(bids[0].qty, asks[0].qty)
		var p: int = asks[0].price
		fills.append({"buyer": bids[0].acct, "seller": asks[0].acct, "qty": q, "price": p,
			"fee": q * p * FEE_BPS / 10000})
		bids[0].qty -= q; asks[0].qty -= q
		if bids[0].qty == 0: bids.pop_front()
		if asks[0].qty == 0: asks.pop_front()
	return fills
