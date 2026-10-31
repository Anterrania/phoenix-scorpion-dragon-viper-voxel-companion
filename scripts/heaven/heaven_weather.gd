class_name HeavenWeather
extends RefCounted
## HEAVEN-3: Heaven weather with temperatures in KELVIN (Phoenix spec). Deterministic: the same
## day + hour gives the same sky on every device, so friends see the same rain. Pure functions.
## T(K) = base + district offset + diurnal swing (warmest ~15:00) + weather state delta.
## States change every SLOT_HOURS of in-world time, picked by a hash of (day, slot).
## Other realms: kelvin_of_celsius() converts their WorldEnv °C so the HUD always reads K.

const ZERO_C := 273.15
const BASE_K := 293.15        # 20 °C: a mild spring day
const DIURNAL_K := 4.0
const SLOT_HOURS := 3
const STATES := {
	"clear": {"label": "Clear", "weight": 45, "dk": 0.0, "fx": "", "wind": 2.0, "humidity": 45},
	"breeze": {"label": "Breezy", "weight": 20, "dk": -0.8, "fx": "petals", "wind": 6.5, "humidity": 50},
	"mist": {"label": "Cloud mist", "weight": 15, "dk": -1.5, "fx": "", "wind": 1.0, "humidity": 88},
	"light_rain": {"label": "Light rain", "weight": 10, "dk": -2.5, "fx": "rain", "wind": 4.0, "humidity": 92},
	"golden_hour": {"label": "Golden hour", "weight": 10, "dk": 0.6, "fx": "star_dust", "wind": 1.5, "humidity": 40},
}
const DISTRICT_K := {
	"beach": 2.5, "poolrooms": 1.0, "warehouses": 1.5, "downtown": 1.2, "gardens": -0.6,
	"spirit_realm": -12.0, "the_beyond": -21.0, "transport_hub": 0.0, "main_mall": 0.4,
}

static func kelvin_of_celsius(c: float) -> float: return c + ZERO_C
static func celsius_of_kelvin(k: float) -> float: return k - ZERO_C
static func fmt_k(k: float) -> String: return "%.1f K" % k

## Weather state id for an in-world day and hour.
static func state_at(day: int, hour: float) -> String:
	var slot := int(floor(fposmod(hour, 24.0) / SLOT_HOURS))
	var h := hash("heaven:%d:%d" % [day, slot])
	var total := 0
	for k in STATES: total += int(STATES[k]["weight"])
	var roll := absi(h) % total
	var acc := 0
	var pick := "clear"
	for k in STATES:
		acc += int(STATES[k]["weight"])
		if roll < acc: pick = k; break
	# golden hour only around sunrise / sunset, otherwise it is just clear
	var hr := fposmod(hour, 24.0)
	if pick == "golden_hour" and not ((hr >= 5.5 and hr < 8.0) or (hr >= 17.0 and hr < 20.0)): pick = "clear"
	return pick

static func kelvin(district: String, day: int, hour: float) -> float:
	var st: Dictionary = STATES[state_at(day, hour)]
	var diurnal := DIURNAL_K * cos(TAU * (fposmod(hour, 24.0) - 15.0) / 24.0)
	return BASE_K + float(DISTRICT_K.get(district, 0.0)) + diurnal + float(st["dk"])

## Full report for the HUD / Heaven screen.
static func report(district: String, day: int, hour: float) -> Dictionary:
	var id := state_at(day, hour)
	var st: Dictionary = STATES[id]
	var k := kelvin(district, day, hour)
	return {"state": id, "label": st["label"], "kelvin": k, "text": fmt_k(k), "fx": st["fx"],
		"wind_ms": float(st["wind"]), "humidity": int(st["humidity"])}

## Day counter from the unix clock (one in-world day per real day; hour comes from world.hour).
static func today() -> int: return int(Time.get_unix_time_from_system() / 86400.0)
