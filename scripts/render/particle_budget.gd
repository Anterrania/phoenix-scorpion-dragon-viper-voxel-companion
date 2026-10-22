class_name ParticleBudget
extends RefCounted
## RND-6 particle budget: one shared pool of GPU particles per device tier
## (RenderTiers "particles.budget" / "particles.emitter_cap"). Emitters ask before they spawn;
## the answer is clamped to the per-emitter cap and to what is left in the pool, so weather,
## spells and club FX together can never exceed the tier's total. Pure static state, tested.

static var budget := 1200
static var emitter_cap := 450
static var _granted := {}   # emitter id -> granted amount

static func configure(total: int, cap: int) -> void:
	budget = maxi(0, total)
	emitter_cap = maxi(1, cap)

static func used() -> int:
	var u := 0
	for k in _granted: u += int(_granted[k])
	return u

static func left() -> int:
	return maxi(0, budget - used())

## Grants up to `wanted` particles for `id` (re-requesting replaces the old grant).
## Always grants at least `min_amount` if any budget is left, so effects never vanish silently.
static func request(id: String, wanted: int, min_amount := 4) -> int:
	_granted.erase(id)
	var g := mini(mini(wanted, emitter_cap), left())
	if g < min_amount: g = mini(min_amount, left())
	g = maxi(g, 0)
	if g > 0: _granted[id] = g
	return g

static func release(id: String) -> void:
	_granted.erase(id)

static func clear() -> void:
	_granted.clear()

static func granted(id: String) -> int:
	return int(_granted.get(id, 0))
