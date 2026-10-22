class_name FreePlay
extends RefCounted
## SBX-7: free-play chance games (prize wheel, reels). ENTERTAINMENT ONLY. Our own games, names and odds.
## Rules (LegalReview, general information pending counsel review):
## - Paid only with EARNED play tokens (PlayTokens). No paid spins, no refills, no Aethel Coin in or out.
## - Prizes are play tokens or cosmetics bound to the account (tradable = false, never listable).
## - Casino-themed games (casino: true) are 18+; every chance game is 13+ and launch-country only.
## - Odds live here on the server side; the client gets only the result. Every roll is logged
##   (LegalReview.log_outcome) and the odds table is published by odds() for disclosure.
## PRIZE TABLES MUST NEVER CONTAIN AETHEL COIN. The test suite fails if one does.

const GAMES := {
	"star_wheel": {"title": "Star Wheel", "cost": 5, "casino": false, "odds_version": "sw-1",
		"prizes": [
			{"weight": 50, "tokens": 2},
			{"weight": 30, "tokens": 5},
			{"weight": 15, "tokens": 10},
			{"weight": 5, "cosmetic": "trail_starlight"}]},
	"lantern_reels": {"title": "Lantern Reels", "cost": 10, "casino": true, "odds_version": "lr-1",
		"prizes": [
			{"weight": 60, "tokens": 0},
			{"weight": 25, "tokens": 10},
			{"weight": 12, "tokens": 25},
			{"weight": 3, "cosmetic": "lantern_halo"}]},
}
const PRIZE_KEYS := ["weight", "tokens", "cosmetic"]   # anything else in a prize is a bug

static var _rng := RandomNumberGenerator.new()
static var _bound = null

static func _all() -> Dictionary:
	if _bound == null:
		var d: Variant = SandboxGate.load_json("bound_cosmetics", {})
		_bound = d if d is Dictionary else {}
	return _bound

static func cosmetics(member: String) -> Array: return _all().get(member, [])

static func is_chance_won(member: String, item_id: String) -> bool:
	return cosmetics(member).any(func(c): return c["id"] == item_id)

## Odds disclosure: [{prize, percent}] (public; the roll itself never leaves the server).
static func odds(game: String) -> Array:
	var g: Dictionary = GAMES.get(game, {})
	var total := 0
	for p in g.get("prizes", []): total += int(p["weight"])
	var out: Array = []
	for p in g.get("prizes", []):
		out.append({"prize": ("cosmetic " + str(p["cosmetic"])) if p.has("cosmetic") else "%d play tokens" % int(p.get("tokens", 0)),
			"percent": 100.0 * int(p["weight"]) / maxf(total, 1)})
	return out

static func check_game(actor: Variant, game: String, ctx: Dictionary) -> String:
	var g: Dictionary = GAMES.get(game, {})
	if g.is_empty(): return "No such game."
	if not SandboxGate.can(actor, "play"): return "You can't play here."
	var lr := LegalReview.check("free_play_chance", ctx)
	if not lr["ok"]: return lr["reason"]
	if bool(g["casino"]):
		lr = LegalReview.check("casino_content", ctx)
		if not lr["ok"]: return lr["reason"]
	return ""

## One play. Returns {"prize": {...}, "balance": n} or {"error": "..."}.
static func spin(actor: Variant, game: String, ctx: Dictionary, now: int) -> Dictionary:
	var err := check_game(actor, game, ctx)
	if err != "": return {"error": err}
	var g: Dictionary = GAMES[game]
	var member := SandboxGate.id_of(actor)
	err = PlayTokens.spend(member, int(g["cost"]))
	if err != "": return {"error": err}
	var total := 0
	for p in g["prizes"]: total += int(p["weight"])
	var roll := _rng.randi_range(0, total - 1)
	var acc := 0
	var prize: Dictionary = g["prizes"][0]
	for p in g["prizes"]:
		acc += int(p["weight"])
		if roll < acc: prize = p; break
	var result := {}
	if int(prize.get("tokens", 0)) > 0:
		PlayTokens.earn(member, int(prize["tokens"]), "free_play_win", {"age": int(ctx.get("age", -1))})
		result["tokens"] = int(prize["tokens"])
	if prize.has("cosmetic"):
		var mine: Array = _all().get(member, [])
		if not mine.any(func(c): return c["id"] == prize["cosmetic"]):
			mine.append({"id": prize["cosmetic"], "bound": true, "tradable": false, "won_at": now, "game": game})
		_all()[member] = mine
		SandboxGate.save_json("bound_cosmetics", _all())
		result["cosmetic"] = prize["cosmetic"]
	LegalReview.log_outcome(game, member, str(g["odds_version"]), roll, result, now)
	return {"prize": result, "balance": PlayTokens.balance(member)}

static func seed_for_tests(s: int) -> void: _rng.seed = s
static func reset_for_tests() -> void: _bound = null
