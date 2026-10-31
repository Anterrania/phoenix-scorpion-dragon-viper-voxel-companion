class_name HeavenLayout
extends RefCounted
## HEAVEN-1: Heaven Welcome Island layout (data/heaven/heaven_layout.json), the default starting realm.
## A floating archipelago high above the ground world: the Main Mall dome in the centre, a ring of
## districts around it (Transportation Hub = spawn, at the bottom of the map), and higher planes
## (Spirit Realm, The Beyond) reached by portals. Bridges join ring neighbours, floating roads run
## from the Mall to every district, glowing waterways run to five of them.
## Pure data + geometry: the terrain generator, the district builder, the gates and the tests all
## read the same island shape from here, so collision, visuals and rules never disagree.
## Island shape: flat plaza top (r < 0.84 R), rounded lip, tapered rocky underside.

const PATH := "res://data/heaven/heaven_layout.json"
const PAVE := 0.5          # paving thickness: plaza walking height = top + PAVE
const LIP_START := 0.84    # fraction of radius where the plaza edge starts to round off
const LIP_DROP := 3.0      # metres the lip falls by the rim

static var _d: Dictionary = {}
static var _by_id: Dictionary = {}

static func data() -> Dictionary:
	if _d.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_d = v if v is Dictionary else {"islands": [], "bridges": [], "roads": [], "waterways": [], "portals": []}
		_by_id.clear()
		for i in _d.get("islands", []): _by_id[str(i["id"])] = i
	return _d

static func islands() -> Array: return data().get("islands", [])
static func island(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})
static func ids() -> Array: return islands().map(func(i): return str(i["id"]))
static func ring_ids() -> Array: return islands().filter(func(i): return i["tier"] == "ring").map(func(i): return str(i["id"]))
static func bridges() -> Array: return data().get("bridges", [])
static func roads() -> Array: return data().get("roads", [])
static func waterways() -> Array: return data().get("waterways", [])
static func portals() -> Array: return data().get("portals", [])
static func floor_y() -> float: return float(data().get("floor_y", 470))
static func ceiling_y() -> float: return float(data().get("ceiling_y", 1100))

static func center2(i: Dictionary) -> Vector2: return Vector2(float(i["center"][0]), float(i["center"][1]))
static func center3(i: Dictionary) -> Vector3: return Vector3(float(i["center"][0]), walk_y(i), float(i["center"][1]))
static func walk_y(i: Dictionary) -> float: return float(i["top"]) + PAVE
static func plaza_radius(i: Dictionary) -> float: return float(i["radius"]) * 0.8

## Inside Heaven airspace (the rules zone): within the archipelago footprint and above the floor.
static func contains(p: Vector3) -> bool:
	var ext := float(data().get("extent", 720))
	return p.y > floor_y() and p.y < ceiling_y() + 200.0 and Vector2(p.x, p.z).length() < ext

## Island whose footprint is under p (horizontally), nearest by top height; {} if none.
static func island_at(p: Vector3) -> Dictionary:
	var best := {}
	var best_dy := INF
	for i in islands():
		if Vector2(p.x, p.z).distance_to(center2(i)) > float(i["radius"]): continue
		var dy := absf(p.y - float(i["top"]))
		if dy < best_dy: best_dy = dy; best = i
	return best

## District name for p: the island under p, or the nearest island in Heaven airspace.
static func district_at(p: Vector3) -> Dictionary:
	var i := island_at(p)
	if not i.is_empty(): return i
	var best := {}
	var bd := INF
	for j in islands():
		var d := Vector3(p.x, p.y, p.z).distance_to(Vector3(center2(j).x, float(j["top"]), center2(j).y))
		if d < bd: bd = d; best = j
	return best

## Spawn: on the Hub plaza, facing the Mall. Returns {pos, yaw}.
static func spawn() -> Dictionary:
	var s: Dictionary = data().get("spawn", {"island": "transport_hub", "offset": [0, 0]})
	var i := island(str(s["island"]))
	if i.is_empty(): return {"pos": Vector3(0, 640, 0), "yaw": 0.0}
	var w := frame(i) * Vector3(float(s["offset"][0]), 0.0, float(s["offset"][1]))
	var c := Vector2(w.x, w.z)
	var face := center2(island(str(s.get("face", "main_mall"))))
	var dir := face - c
	return {"pos": Vector3(c.x, walk_y(i) + 1.2, c.y), "yaw": atan2(-dir.x, -dir.y)}

static func spawn_point() -> Vector3: return spawn()["pos"]

## Local frame of an island: origin = centre at walking height, local -z faces the Main Mall
## (the Mall itself faces north). District pieces are placed in this frame.
static func yaw_of(i: Dictionary) -> float:
	var c := center2(i)
	if c.length() < 1.0 or str(i.get("tier", "")) == "high": return 0.0
	return atan2(c.x, c.y)   # local -z = direction to the origin

static func frame(i: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw_of(i)), center3(i))

## Arrival point for transit to an island: plaza edge facing the island centre.
static func arrival(id: String) -> Vector3:
	var i := island(id)
	if i.is_empty(): return spawn_point()
	var c := center2(i)
	var toward := (Vector2.ZERO - c)
	var off := toward.normalized() * plaza_radius(i) * 0.7 if toward.length() > 1.0 else Vector2(0, plaza_radius(i) * 0.7)
	return Vector3(c.x + off.x, walk_y(i) + 1.2, c.y + off.y)

# ---------- island shape (shared by terrain SDF, tests and impostors) ----------
## Rim wobble so islands are not perfect discs (cheap, deterministic).
static func rim_scale(i: Dictionary, ang: float) -> float:
	var s := float(hash(str(i["id"])) % 1000) * 0.006
	return 1.0 + 0.04 * sin(3.0 * ang + s) + 0.02 * sin(7.0 * ang + 2.0 * s)

## Height of the island top at world (x, z), or NAN outside the island.
static func top_at(i: Dictionary, x: float, z: float) -> float:
	var c := center2(i)
	var dx := x - c.x; var dz := z - c.y
	var R := float(i["radius"]) * rim_scale(i, atan2(dz, dx))
	var r := sqrt(dx * dx + dz * dz) / R
	if r >= 1.0: return NAN
	var lip := smoothstep(LIP_START, 1.0, r)
	return float(i["top"]) - LIP_DROP * lip + 0.6 * sin(x * 0.21) * sin(z * 0.17) * lip

## Height of the island underside at (x, z), or NAN outside.
static func bottom_at(i: Dictionary, x: float, z: float) -> float:
	var c := center2(i)
	var dx := x - c.x; var dz := z - c.y
	var R := float(i["radius"]) * rim_scale(i, atan2(dz, dx))
	var r := sqrt(dx * dx + dz * dz) / R
	if r >= 1.0: return NAN
	var taper := pow(maxf(1.0 - r * r, 0.0), 0.55)
	var rough := 0.85 + 0.15 * sin(x * 0.05 + z * 0.07) + 0.06 * sin(x * 0.23 - z * 0.19)
	return float(i["top"]) - 2.0 - float(i["depth"]) * taper * rough

## Signed distance-ish value (negative = solid) for one island at p. Vertical distance to the slab,
## good enough for Transvoxel within the band the generator samples.
static func sdf(i: Dictionary, p: Vector3) -> float:
	var t := top_at(i, p.x, p.z)
	if is_nan(t):
		# outside the footprint: horizontal distance to the rim (keeps the surface closed)
		var c := center2(i)
		return maxf(0.5, Vector2(p.x, p.z).distance_to(c) - float(i["radius"]) * 1.06)
	return maxf(p.y - t, bottom_at(i, p.x, p.z) - p.y)   # solid between underside and top

## Axis-aligned bounds of an island: [min: Vector3, max: Vector3].
static func aabb(i: Dictionary) -> AABB:
	var c := center2(i)
	var R := float(i["radius"]) * 1.08
	var top := float(i["top"]) + 1.0
	var bot := float(i["top"]) - 2.0 - float(i["depth"]) * 1.1
	return AABB(Vector3(c.x - R, bot, c.y - R), Vector3(2.0 * R, top - bot, 2.0 * R))

## Islands whose bounds touch the box [a, b].
static func islands_in(a: Vector3, b: Vector3) -> Array:
	var box := AABB(a, b - a)
	return islands().filter(func(i): return aabb(i).intersects(box))

static func reset_for_tests() -> void:
	_d = {}; _by_id = {}
