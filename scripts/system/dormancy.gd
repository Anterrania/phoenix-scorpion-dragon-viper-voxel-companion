class_name Dormancy
extends RefCounted
## Dormancy: shared sleep/wake helper for regions, sims, companions and scripts.
## Anything with no viewer nearby goes dormant (costs nothing). On wake it catches up with ONE call
## carrying the elapsed seconds: fast-forward math, never a tick-by-tick replay.
## API (docs/modules/POWER_AND_DATA.md §5):
##   Dormancy.register(id, pos, catch_up: Callable(elapsed_s: float), wake_radius := 96.0, kind := "")
##   Dormancy.unregister(id) · Dormancy.move(id, pos)
##   Dormancy.update(viewers: Array[Vector3], now_s) -> {woke: [ids], slept: [ids]}  (call ~1 Hz, not per frame)
##   Dormancy.is_dormant(id) · Dormancy.set_background(on, now_s)  (backgrounded app: everything sleeps)
##   Math: ff_linear, ff_decay, ff_toward, ff_ticks (pure, testable)
## Hysteresis: wake inside wake_radius, sleep only beyond wake_radius * SLEEP_FACTOR, after SLEEP_DELAY_S.

const SLEEP_FACTOR := 1.25
const SLEEP_DELAY_S := 10.0
const MAX_CATCH_UP_S := 7.0 * 86400.0   # cap: a week away is treated as a week

static var _items: Dictionary = {}   # id -> {pos, radius, cb, kind, dormant, since, far_since}
static var background := false

static func reset_for_tests() -> void:
	_items.clear(); background = false

static func register(id: String, pos: Vector3, catch_up: Callable, wake_radius := 96.0, kind := "") -> void:
	_items[id] = {"pos": pos, "radius": wake_radius, "cb": catch_up, "kind": kind, "dormant": false, "since": -1.0, "far_since": -1.0}

static func unregister(id: String) -> void: _items.erase(id)
static func move(id: String, pos: Vector3) -> void:
	if _items.has(id): _items[id]["pos"] = pos
static func is_dormant(id: String) -> bool: return bool(_items.get(id, {}).get("dormant", false))
static func count(dormant := true) -> int:
	return _items.values().filter(func(e): return bool(e["dormant"]) == dormant).size()

static func _sleep(e: Dictionary, now_s: float) -> void:
	e["dormant"] = true; e["since"] = now_s; e["far_since"] = -1.0

static func _wake(id: String, e: Dictionary, now_s: float) -> void:
	var elapsed := clampf(now_s - float(e["since"]), 0.0, MAX_CATCH_UP_S)
	e["dormant"] = false; e["since"] = -1.0; e["far_since"] = -1.0
	var cb: Callable = e["cb"]
	if cb.is_valid() and elapsed > 0.0: cb.call(elapsed)

static func update(viewers: Array, now_s: float) -> Dictionary:
	var woke: Array = []; var slept: Array = []
	if background: return {"woke": woke, "slept": slept}
	for id in _items:
		var e: Dictionary = _items[id]
		var d := INF
		for v in viewers: d = minf(d, (v as Vector3).distance_to(e["pos"]))
		var r: float = e["radius"]
		if e["dormant"]:
			if d <= r: _wake(id, e, now_s); woke.append(id)
		elif d > r * SLEEP_FACTOR:
			if float(e["far_since"]) < 0.0: e["far_since"] = now_s
			elif now_s - float(e["far_since"]) >= SLEEP_DELAY_S: _sleep(e, now_s); slept.append(id)
		else: e["far_since"] = -1.0
	return {"woke": woke, "slept": slept}

## App backgrounded: everything sleeps now. Foreground: nothing wakes until update() sees a viewer.
static func set_background(on: bool, now_s: float) -> void:
	background = on
	if on:
		for id in _items:
			if not _items[id]["dormant"]: _sleep(_items[id], now_s)

# ---------- fast-forward math (pure) ----------
## value + rate * elapsed, clamped. (hunger, growth, crafting progress)
static func ff_linear(value: float, rate_per_s: float, elapsed_s: float, lo := -INF, hi := INF) -> float:
	return clampf(value + rate_per_s * elapsed_s, lo, hi)

## Exponential decay with a half-life. (mood, heat, disease load)
static func ff_decay(value: float, half_life_s: float, elapsed_s: float) -> float:
	if half_life_s <= 0.0: return 0.0
	return value * pow(0.5, elapsed_s / half_life_s)

## Ease toward a target with a half-life. (temperature, energy recovering to rest)
static func ff_toward(value: float, target: float, half_life_s: float, elapsed_s: float) -> float:
	return target + ff_decay(value - target, half_life_s, elapsed_s)

## How many discrete events a fixed-rate tick would have produced, capped (spawns, script timers).
static func ff_ticks(elapsed_s: float, hz: float, max_ticks := 1000) -> int:
	return mini(int(floor(maxf(elapsed_s, 0.0) * maxf(hz, 0.0))), max_ticks)
