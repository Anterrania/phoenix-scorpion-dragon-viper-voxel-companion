class_name Ecology
extends RefCounted
## LIFE-3b: per-region creature populations (no individuals simulated while nobody watches).
## Each species grows logistically toward a carrying capacity K set by how well its genome fits the
## region's environment (Genome.viability score). Closed-form solution, so one step of any length
## is exact: that is what Dormancy catch-up uses. Non-viable species decline (half-life 24 game h).
## In-memory only; the server persists via its own snapshot if needed.

const R_PER_H := 0.05        # intrinsic growth per game hour
const K_MAX := 200.0
const DECLINE_HALF_H := 24.0
static var pops := {}        # region -> {species: count}

static func seed_region(region: String, counts: Dictionary) -> void:
	pops[region] = counts.duplicate()

static func capacity(region: String, species: String) -> float:
	var env := WorldEnv.outdoor(LivingGate.realm_of(region))
	var v := Genome.viability(Genome.of_species(species), env)
	return K_MAX * float(v.get("score", 0.0)) if bool(v.get("ok", false)) else 0.0

## Logistic N(t) = K / (1 + ((K - N0) / N0) e^(-r t)).
static func logistic(n0: float, k: float, r: float, t: float) -> float:
	if n0 <= 0.0: return 0.0
	if k <= 0.0: return n0 * pow(0.5, t / DECLINE_HALF_H)
	return k / (1.0 + ((k - n0) / n0) * exp(-r * t))

static func step(region: String, dt_h: float) -> void:
	if not pops.has(region) or dt_h <= 0.0: return
	var p: Dictionary = pops[region]
	for s in p.keys():
		p[s] = logistic(float(p[s]), capacity(region, s), R_PER_H, dt_h)
		if float(p[s]) < 0.5: p.erase(s)

static func population(region: String) -> Dictionary: return pops.get(region, {}).duplicate()
static func reset_for_tests() -> void: pops = {}
