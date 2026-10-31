class_name RegionRental
extends RefCounted
## SBX-6: region / parcel rental per time unit (minute, hour, day, week) and a visitor-minute meter
## (the "world owner pays per visitor-minute" idea from cloud-hosted grids). Our own code.
## The estate manager sets terms; a resident rents; a lease adds the renter to the parcel/region
## allowed list and allow_build while it runs, and tick() takes it back when it ends.
##
## LEGAL REVIEW (general information, pending counsel review): Aethel Coin rent ("aethel_rental") and
## visitor metering ("aethel_metering") are LATER features, OFF until counsel signs off. Until then free
## terms (rate 0) work, priced terms only produce a quote, and the owner can grant a lease by hand
## ("grant_lease"). Nobody is charged. When the flag turns on, charge through AethelLedger only.

const UNITS := {"minute": 60, "hour": 3600, "day": 86400, "week": 604800}

static var _r = null

static func _all() -> Dictionary:
	if _r == null:
		var d: Variant = SandboxGate.load_json("rental", {})
		_r = d if d is Dictionary else {}
		for k in ["terms", "leases", "meter"]:
			if not _r.has(k): _r[k] = {}
	return _r
static func _save() -> bool: return SandboxGate.save_json("rental", _all())

static func _key(region: String, parcel: String) -> String: return region + ("/" + parcel if parcel != "" else "")

static func set_terms(actor: Variant, region: String, parcel: String, rate_aethel: int, unit: String, min_units := 1, max_units := 52) -> String:
	if not SandboxGate.can(actor, "manage_region", region): return "Estate manager or owner only."
	if not UNITS.has(unit): return "Unit must be minute, hour, day or week."
	if rate_aethel < 0 or min_units < 1 or max_units < min_units: return "Check the rate and unit limits."
	_all()["terms"][_key(region, parcel)] = {"region": region, "parcel": parcel, "rate_aethel": rate_aethel, "unit": unit,
		"min_units": min_units, "max_units": max_units, "lessor": SandboxGate.id_of(actor)}
	return "" if _save() else "Saves are sealed. Unlock first."

static func terms(region: String, parcel := "") -> Dictionary: return _all()["terms"].get(_key(region, parcel), {})

static func quote(region: String, parcel: String, units: int) -> Dictionary:
	var t := terms(region, parcel)
	if t.is_empty(): return {"error": "Not for rent."}
	if units < int(t["min_units"]) or units > int(t["max_units"]): return {"error": "Rent %d to %d %ss." % [t["min_units"], t["max_units"], t["unit"]]}
	return {"cost_aethel": int(t["rate_aethel"]) * units, "seconds": UNITS[t["unit"]] * units, "legal_review": int(t["rate_aethel"]) > 0}

static func lease(region: String, parcel := "") -> Dictionary: return _all()["leases"].get(_key(region, parcel), {})

## Rent for `units`. Free terms only while Aethel is off. renter "" = the actor.
static func rent(actor: Variant, region: String, parcel: String, units: int, now: int) -> Dictionary:
	if not SandboxGate.can(actor, "trade"): return {"error": "Renting needs Resident tier or higher."}
	if not Tiers.can(actor, "enter", {"region": region, "parcel": parcel}): return {"error": "You can't enter that land."}
	var q := quote(region, parcel, units)
	if q.has("error"): return q
	if int(q["cost_aethel"]) > 0:
		# LEGAL REVIEW: "aethel_rental" is LATER/off. Payment wiring (AethelLedger) lands with counsel sign-off.
		return {"error": "Paid rentals are off until the legal review is done.", "quote": q}
	return _start(SandboxGate.id_of(actor), region, parcel, int(q["seconds"]), now, "rented")

## Owner hands out a lease by hand (no payment involved).
static func grant_lease(actor: Variant, renter: String, region: String, parcel: String, seconds: int, now: int) -> Dictionary:
	if not SandboxGate.can(actor, "grant_lease"): return {"error": "Owner unlock needed."}
	if renter == "" or seconds <= 0: return {"error": "Pick a renter and a length."}
	return _start(renter, region, parcel, seconds, now, "granted")

static func _start(renter: String, region: String, parcel: String, seconds: int, now: int, how: String) -> Dictionary:
	var k := _key(region, parcel)
	var cur := lease(region, parcel)
	if not cur.is_empty() and int(cur["ends"]) > now and str(cur["renter"]) != renter: return {"error": "Already rented."}
	var start := now if cur.is_empty() or int(cur["ends"]) <= now else int(cur["starts"])
	var ends := (int(cur["ends"]) if not cur.is_empty() and int(cur["ends"]) > now else now) + seconds   # renewals extend
	var l := {"renter": renter, "region": region, "parcel": parcel, "starts": start, "ends": ends, "how": how,
		"had_access": renter in _allowed(region, parcel) if cur.is_empty() else bool(cur.get("had_access", false))}
	_all()["leases"][k] = l
	var al := _allowed(region, parcel).duplicate()
	if not renter in al: al.append(renter)
	_put_estate(region, parcel, "allowed", al)
	_put_estate(region, parcel, "allow_build", true)
	return l if _save() else {"error": "Saves are sealed. Unlock first."}

static func _allowed(region: String, parcel: String) -> Array:
	return Estate.parcel_get(region, parcel, "allowed") if parcel != "" else Estate.region_get(region, "allowed")
static func _put_estate(region: String, parcel: String, key: String, v: Variant) -> void:
	if parcel != "": Estate.parcel_set(region, parcel, key, v)
	else: Estate.region_set(region, key, v)

## End expired leases: take the renter off the allowed list (unless they had access before).
static func tick(now: int) -> Array:
	var ended: Array = []
	for k in _all()["leases"].keys():
		var l: Dictionary = _all()["leases"][k]
		if int(l["ends"]) > now: continue
		if not bool(l.get("had_access", false)):
			var al := _allowed(l["region"], l["parcel"]).duplicate()
			al.erase(l["renter"])
			_put_estate(l["region"], l["parcel"], "allowed", al)
		_all()["leases"].erase(k)
		ended.append(k)
	if not ended.is_empty(): _save()
	return ended

## Visitor-minute meter: record usage per region (report only; never charged while Aethel is off).
static func meter(region: String, visitor: String, minutes: int) -> void:
	if minutes <= 0: return
	var m: Dictionary = _all()["meter"].get(region, {"minutes": 0, "visitors": {}})
	m["minutes"] = int(m["minutes"]) + minutes
	m["visitors"][visitor] = int(m["visitors"].get(visitor, 0)) + minutes
	_all()["meter"][region] = m
	_save()

static func usage(region: String) -> Dictionary: return _all()["meter"].get(region, {"minutes": 0, "visitors": {}})

static func reset_for_tests() -> void: _r = null
