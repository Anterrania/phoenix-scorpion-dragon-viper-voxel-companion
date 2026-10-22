class_name SpendLimits
extends RefCounted
## SBX-LEGAL-3 (stub): spend-limit service for Aethel Coin fixed-price purchases.
## Monthly caps by age band, optional lower personal / parent caps set by the owner. Server-side
## later; local file now (user://legal/spend.json). Numbers are placeholders pending counsel.

const MONTHLY_CAP := {"teen": 2000, "adult": 20000}   # Aethel Coin per calendar month
static var _d = null

static func _path() -> String: return LegalReview.root.path_join("spend.json")
static func _all() -> Dictionary:
	if _d == null:
		var x: Variant = SecureFile.read_json(_path(), {})
		_d = x if x is Dictionary else {}
		if not _d.has("spent"): _d["spent"] = {}
		if not _d.has("caps"): _d["caps"] = {}
	return _d

static func _month(now: int) -> String: return Time.get_datetime_string_from_unix_time(now).left(7)

static func cap_for(member: String, age: int) -> int:
	if age < LegalReview.MIN_PURCHASE_AGE: return 0
	var base: int = MONTHLY_CAP["adult"] if age >= LegalReview.ADULT else MONTHLY_CAP["teen"]
	var personal := int(_all()["caps"].get(member, -1))
	return mini(base, personal) if personal >= 0 else base

static func spent(member: String, now: int) -> int:
	return int(_all()["spent"].get(member, {}).get(_month(now), 0))

static func check(member: String, amount: int, age: int, now: int) -> String:
	if spent(member, now) + amount > cap_for(member, age): return "Monthly spend limit reached."
	return ""

static func record(member: String, amount: int, now: int) -> void:
	var m: Dictionary = _all()["spent"].get(member, {})
	m[_month(now)] = int(m.get(_month(now), 0)) + amount
	_all()["spent"][member] = m
	SecureFile.write_json(_path(), _all())

## Owner (or later a verified parent) can set a lower personal cap. It can never raise the age cap.
static func set_cap(member: String, cap: int) -> String:
	if not Tiers.owner_session(): return "Owner unlock needed."
	_all()["caps"][member] = maxi(cap, 0)
	return "" if SecureFile.write_json(_path(), _all()) else "Saves are sealed. Unlock first."

static func reset_for_tests() -> void: _d = null
