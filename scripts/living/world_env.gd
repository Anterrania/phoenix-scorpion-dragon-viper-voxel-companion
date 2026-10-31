class_name WorldEnv
extends RefCounted
## LIFE-1: environmental rules per realm (world seeds) and the effective environment an organism or
## person actually experiences after shelter and suit. Data: data/living/realms.json (units there).
## Pure functions, no ticking: callers sample at the low sim rate.

const VENUS_DEEP_Y := -30   # below this the Venus realm switches to true-surface conditions

static func realm(name: String) -> Dictionary:
	return LivingGate.realms_data().get("realms", {}).get(name, LivingGate.realms_data()["realms"]["social"])

static func planet(name: String) -> Dictionary:
	return LivingGate.realms_data().get("planets", {}).get(name, {})

static func realms() -> Array: return LivingGate.realms_data().get("realms", {}).keys()

static func shelter(id: String) -> Dictionary: return LivingGate.realms_data().get("shelters", {}).get(id, {})
static func suit(id: String) -> Dictionary: return LivingGate.realms_data().get("suits", {}).get(id, LivingGate.realms_data()["suits"]["none"])

## Outdoor environment at a height. Seasonal/day temperature: t01 in 0..1 picks between temp_min
## and temp_max (0.5 = mid). Returns partial pressures in kPa.
static func outdoor(realm_name: String, y := 0.0, t01 := 0.5) -> Dictionary:
	var rn := realm_name
	if rn == "venus_fire" and y < VENUS_DEEP_Y: rn = "venus_deep"
	var r := realm(rn)
	var p := float(r.get("pressure_kpa", 101.3))
	return {"realm": rn, "gravity": float(r.get("gravity", 9.81)), "pressure_kpa": p,
		"o2_kpa": p * float(r.get("o2", 0.0)), "co2_kpa": p * float(r.get("co2", 0.0)),
		"temp_c": lerpf(float(r.get("temp_min", 15)), float(r.get("temp_max", 25)), clampf(t01, 0.0, 1.0)),
		"radiation_msv_day": float(r.get("radiation_msv_day", 0.0)), "water": float(r.get("water", 0.5)),
		"ph": (float(r.get("soil_ph", [7, 7])[0]) + float(r.get("soil_ph", [7, 7])[1])) / 2.0,
		"acid": bool(r.get("acid", false)), "vacuum": bool(r.get("vacuum", false)),
		"pollution": float(r.get("pollution", 0.0)), "hazards": r.get("hazards", []).duplicate(),
		"day_length_h": float(r.get("day_length_h", 24))}

## What a person breathes and feels. opts: shelter (id), powered (bool), suit (id), suit_o2 (bool:
## tank not empty). Sealed + powered shelter replaces the atmosphere; a sealed suit with gas does too.
static func personal(env: Dictionary, opts := {}) -> Dictionary:
	var e := env.duplicate(true)
	e["sealed"] = false
	var sh := shelter(str(opts.get("shelter", "")))
	if not sh.is_empty():
		if bool(sh.get("sealed", false)) and bool(opts.get("powered", true)):
			e["pressure_kpa"] = float(sh["pressure_kpa"]); e["o2_kpa"] = float(sh["pressure_kpa"]) * float(sh["o2"])
			e["co2_kpa"] = float(sh["pressure_kpa"]) * float(sh["co2"]); e["temp_c"] = float(sh["temp"])
			e["acid"] = false; e["vacuum"] = false; e["pollution"] = 0.0; e["sealed"] = true
		else:
			e["temp_c"] = _toward(float(e["temp_c"]), 21.0, float(sh.get("insulation_c", 0)))
		e["radiation_msv_day"] = float(e["radiation_msv_day"]) * (1.0 - float(sh.get("radiation_shield", 0.0)))
	var su := suit(str(opts.get("suit", "none")))
	if not bool(e["sealed"]):
		var has_gas := bool(opts.get("suit_o2", true)) and float(su.get("o2_tank_h", 0)) > 0
		if bool(su.get("sealed", false)) and has_gas and float(e["pressure_kpa"]) <= float(su.get("max_pressure_kpa", 0)):
			e["pressure_kpa"] = 101.3 if float(e["pressure_kpa"]) < 30 else float(e["pressure_kpa"])
			e["o2_kpa"] = 21.0; e["co2_kpa"] = 0.04; e["acid"] = false; e["vacuum"] = false; e["pollution"] = 0.0; e["sealed"] = true
		elif bool(su.get("mask", false)) and has_gas:
			e["o2_kpa"] = maxf(float(e["o2_kpa"]), 21.0); e["co2_kpa"] = minf(float(e["co2_kpa"]), 0.04); e["pollution"] = 0.0
		if bool(su.get("acid_proof", false)): e["acid"] = false
		e["temp_c"] = _toward(float(e["temp_c"]), 21.0, absf(float(su.get("insulation_c", 0))))
		e["radiation_msv_day"] = float(e["radiation_msv_day"]) * (1.0 - float(su.get("radiation_shield", 0.0)))
	return e

## Move a temperature toward a comfort point by up to `amount` degrees (insulation / cooling).
static func _toward(t: float, target: float, amount: float) -> float:
	return move_toward(t, target, maxf(amount, 0.0))
