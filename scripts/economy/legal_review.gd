class_name LegalReview
extends RefCounted
## SBX-LEGAL-1: enforced money / chance / age policy. DENY BY DEFAULT, keyed by feature, region and age.
## General information, pending counsel review. Not legal advice. The rules are written up in
## docs/modules/LEGAL_REVIEW_GATES.md (rules only; no memo or case law in the repo).
##
## Every money or chance code path asks:  LegalReview.check(feature, ctx) -> {"ok": bool, "reason": String}
##   ctx: {"age": int (-1 / missing = unknown -> treated as a child), "country": "US",
##         "subdivision": "US-WA" (optional), "price_shown": bool, "fixed_price": bool,
##         "parental_consent": bool}
## Three states:
##   ALLOWED  - on now, still subject to the age / country / price rules below.
##   LATER    - OFF. Turning one on needs the unlocked owner AND a counsel sign-off reference
##              (set_later_flag). Even then the feature's own rules still apply.
##   HARD     - cannot be enabled by any config, flag or owner action. Changing one needs a code
##              change here AFTER counsel signs off. Unknown features are denied too.

const ALLOWED := "allowed"
const LATER := "later"
const HARD := "hard_disabled"

## Countries Viper has launched in. New-country launches are HARD-disabled: adding a code here is a
## code change that needs counsel first. (Owner to confirm the list with counsel.)
const LAUNCH_COUNTRIES := ["US"]
## Minors in these places never see paid loot boxes (BE, BR, and WA read both ways: US-WA and AU-WA).
const LOOTBOX_MINOR_BLOCKS := ["BE", "BR", "US-WA", "AU-WA"]
const ADULT := 18
const MIN_PURCHASE_AGE := 13
const MIN_CHANCE_AGE := 13

const POLICY := {
	# --- ALLOWED NOW ---
	"play_token_earn": {"state": ALLOWED, "min_age": 0, "geo": false},          # earned-only tokens
	"free_play_chance": {"state": ALLOWED, "min_age": MIN_CHANCE_AGE, "geo": true},  # spins paid with earned play tokens only
	"casino_content": {"state": ALLOWED, "min_age": ADULT, "geo": true},          # any casino-themed game: 18+
	"cosmetic_reward": {"state": ALLOWED, "min_age": 0, "geo": false},           # account-bound, never tradable
	"aethel_fixed_price_purchase": {"state": ALLOWED, "min_age": MIN_PURCHASE_AGE, "geo": true, "needs": ["price_shown", "fixed_price"]},
	"aethel_refund": {"state": ALLOWED, "min_age": 0, "geo": false},
	# --- LATER (flag OFF, counsel required) ---
	"paid_loot_box": {"state": LATER, "min_age": MIN_PURCHASE_AGE, "geo": true, "needs": ["price_shown", "odds_shown"],
		"consent_under": 16, "minor_blocks": LOOTBOX_MINOR_BLOCKS, "pity_cap": true, "spend_cap": true},
	"loyalty_reward": {"state": LATER, "min_age": MIN_PURCHASE_AGE, "geo": true},   # fixed-ratio only, never random
	"no_purchase_giveaway": {"state": LATER, "min_age": ADULT, "geo": true},
	"aethel_rental": {"state": LATER, "min_age": ADULT, "geo": true, "needs": ["price_shown", "fixed_price"]},
	"aethel_metering": {"state": LATER, "min_age": ADULT, "geo": true},
	"aethel_quest_reward": {"state": LATER, "min_age": MIN_PURCHASE_AGE, "geo": true},   # fixed, never random
	# --- HARD-DISABLED: counsel needed + a code change here. Config can't turn these on. ---
	"coin_wager": {"state": HARD},            # Aethel Coin wagers on chance
	"aethel_cashout": {"state": HARD},        # any Aethel Coin cash-out
	"aethel_exchange": {"state": HARD},       # coin <-> anything exchange / order book
	"p2p_coin_transfer": {"state": HARD},     # member-to-member coin transfer
	"p2p_chance_item_trade": {"state": HARD}, # trading / gifting anything won by chance
	"play_token_purchase": {"state": HARD},   # selling play tokens, paid spins or paid refills
	"play_token_transfer": {"state": HARD},
	"play_token_convert": {"state": HARD},    # play tokens never become Aethel Coin
	"sweepstakes": {"state": HARD},           # incl. two-currency / dual-coin models
	"real_money_gaming": {"state": HARD},
	"nft_blockchain": {"state": HARD},
	"new_country_launch": {"state": HARD},
}

static var root := "user://legal"
static var _flags = null

static func _flags_path() -> String: return root.path_join("flags.json")
static func flags() -> Dictionary:
	if _flags == null:
		var d: Variant = SecureFile.read_json(_flags_path(), {})
		_flags = d if d is Dictionary else {}
	return _flags

static func state(feature: String) -> String:
	return str(POLICY.get(feature, {}).get("state", HARD))   # unknown = denied like HARD

static func is_hard(feature: String) -> bool: return state(feature) == HARD

## LATER features only. Needs the unlocked owner and a counsel sign-off reference (kept off-repo).
static func set_later_flag(feature: String, on: bool, counsel_signoff_ref := "") -> String:
	if state(feature) != LATER: return "Only LATER features have a flag. HARD ones need a code change and counsel."
	if not Tiers.owner_session(): return "Owner unlock needed."
	if on and counsel_signoff_ref.strip_edges() == "": return "Counsel sign-off reference required."
	flags()[feature] = {"on": on, "signoff": counsel_signoff_ref.left(80)}
	return "" if SecureFile.write_json(_flags_path(), flags()) else "Saves are sealed. Unlock first."

static func _deny(feature: String, reason: String) -> Dictionary: return {"ok": false, "feature": feature, "reason": reason}

static func check(feature: String, ctx: Dictionary = {}) -> Dictionary:
	var p: Dictionary = POLICY.get(feature, {})
	if p.is_empty(): return _deny(feature, "Unknown feature (denied by default).")
	var st := str(p["state"])
	if st == HARD: return _deny(feature, "Turned off. Needs counsel review and a code change.")
	if st == LATER:
		var f: Dictionary = flags().get(feature, {})
		if not (bool(f.get("on", false)) and str(f.get("signoff", "")) != ""): return _deny(feature, "Not available yet (legal review).")
	var age := int(ctx.get("age", -1))
	var min_age := int(p.get("min_age", ADULT))
	if min_age > 0 and age < min_age: return _deny(feature, "Not available at this age." if age >= 0 else "Age not confirmed.")
	if bool(p.get("geo", true)):
		var c := str(ctx.get("country", "")).to_upper()
		if c == "" or not c in LAUNCH_COUNTRIES: return _deny(feature, "Not available in this country yet.")
	for need in p.get("needs", []):
		if not bool(ctx.get(need, false)): return _deny(feature, "Missing: %s." % need)
	if p.has("consent_under") and age < int(p["consent_under"]) and not bool(ctx.get("parental_consent", false)):
		return _deny(feature, "Needs parental consent.")
	if age < ADULT:
		for blk in p.get("minor_blocks", []):
			if str(ctx.get("country", "")).to_upper() == blk or str(ctx.get("subdivision", "")).to_upper() == blk:
				return _deny(feature, "Not available for minors here.")
	return {"ok": true, "feature": feature, "reason": ""}

static func allowed(feature: String, ctx: Dictionary = {}) -> bool: return bool(check(feature, ctx)["ok"])

# ---------- random-outcome audit log ----------
## Every server-side random outcome is appended here (one JSON line). Odds live on the server
## (FreePlay.GAMES); the client only ever gets the result.
static func _audit_path() -> String: return root.path_join("rng_audit.jsonl")

static func log_outcome(game: String, member: String, odds_version: String, roll: int, result: Dictionary, now: int) -> void:
	DirAccess.make_dir_recursive_absolute(root)
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_audit_path()) else FileAccess.WRITE
	var f := FileAccess.open(_audit_path(), mode)
	if f == null: return
	f.seek_end()
	f.store_line(JSON.stringify({"at": now, "game": game, "member": member, "odds": odds_version, "roll": roll, "result": result}))
	f.close()

static func audit_lines() -> Array:
	if not FileAccess.file_exists(_audit_path()): return []
	var out: Array = []
	for line in FileAccess.get_file_as_string(_audit_path()).split("\n", false):
		var d: Variant = JSON.parse_string(line)
		if d is Dictionary: out.append(d)
	return out

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _flags = null
