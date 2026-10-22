class_name Geology
extends RefCounted
## LIFE-6: ore and mineral deposits by realm and depth (data/living/materials.json "ores").
## Deterministic: a deposit is a pure function of (realm, voxel position, surface height, seed), so
## the server and every client agree without sending deposit maps. Deposits come in veins: the hash
## is taken on a 4 m cell, so neighbouring voxels share an ore (minable seams, not random specks).
## Wired into the voxel generator through BiomeVoxelGenerator.ore_at(); the render materials are not
## changed (scanner/extraction visuals are Foxy's client work).

const DATA := "res://data/living/materials.json"
const VEIN_CELL := 4
static var _db = null

static func db() -> Dictionary:
	if _db == null:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_db = d if d is Dictionary else {"ores": {}, "processed": {}}
	return _db

static func ores() -> Dictionary: return db()["ores"]
static func ore(id: String) -> Dictionary: return ores().get(id, {})

static func ores_for(realm_name: String) -> Array:
	var out: Array = []
	for id in ores():
		if realm_name in ores()[id]["realms"]: out.append(id)
	out.sort()
	return out

## 0..1 hash for a vein cell and ore index (integer mixing, no noise objects -> cheap and stateless).
static func _h01(x: int, y: int, z: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 1000003) / 1000003.0

## Ore id at a voxel or "". surface_h = ground height of that column.
static func deposit_at(realm_name: String, x: int, y: int, z: int, surface_h: int, seed_value := 1337) -> String:
	var depth := surface_h - y
	if depth < 0: return ""
	var cx := floori(float(x) / VEIN_CELL); var cy := floori(float(y) / VEIN_CELL); var cz := floori(float(z) / VEIN_CELL)
	var list := ores_for(realm_name)
	for i in list.size():
		var o: Dictionary = ores()[list[i]]
		var band: Array = o["depth"]
		if depth < int(band[0]) or depth > int(band[1]): continue
		if _h01(cx, cy, cz, seed_value + i * 7919) < float(o["chance"]): return list[i]
	return ""

## Survey: counts of each ore in a box (for tests and the scanner spec). Samples one voxel per cell.
static func survey(realm_name: String, origin: Vector3i, size: Vector3i, surface_h: int, seed_value := 1337) -> Dictionary:
	var out := {}
	for x in range(origin.x, origin.x + size.x, VEIN_CELL):
		for y in range(origin.y, origin.y + size.y, VEIN_CELL):
			for z in range(origin.z, origin.z + size.z, VEIN_CELL):
				var o := deposit_at(realm_name, x, y, z, surface_h, seed_value)
				if o != "": out[o] = int(out.get(o, 0)) + 1
	return out

static func reset_cache() -> void: _db = null
