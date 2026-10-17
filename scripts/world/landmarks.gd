class_name Landmarks
extends RefCounted
## Personal landmarks, home location and teleport history (Second Life / OpenSim "Landmarks",
## "Set Home to Here" and "Teleport History"). Local standalone store; a grid InventoryService
## would hold landmarks as inventory items later (docs/VIRTUAL_WORLD_FEATURE_GAP.md).
## - File: user://world/landmarks.json via SecureFile (encrypted once an OwnerVault exists).
## - Estate flags: allow_landmark / allow_set_home on the region/parcel are respected (SL behaviour;
##   the owner and estate managers may always save, like SL estate managers).
## - Addresses: "viper://<Region>/<x>/<y>/<z>" (SLURL-like, region-local metres, rounded).
## - Caps: 200 landmarks, 50 history entries (newest first), names 64 chars.

const MAX_LANDMARKS := 200
const MAX_HISTORY := 50
const MAX_NAME := 64
const SCHEME := "viper://"
static var path := "user://world/landmarks.json"
static var _db = null

static func db() -> Dictionary:
	if _db == null:
		var d: Variant = SecureFile.read_json(path, {})
		_db = d if d is Dictionary else {}
		for k in ["landmarks", "history"]:
			if not (_db.get(k) is Array): _db[k] = []
		if not (_db.get("home") is Dictionary): _db["home"] = {}
	return _db

static func _save() -> bool: return SecureFile.write_json(path, db())
static func reload_data() -> void: _db = null

static func _pos(p: Variant) -> Array:
	if p is Vector3: return [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]
	if p is Array and p.size() >= 3: return [float(p[0]), float(p[1]), float(p[2])]
	return [0.0, 0.0, 0.0]

static func to_vec(entry: Dictionary) -> Vector3:
	var a := _pos(entry.get("pos", []))
	return Vector3(a[0], a[1], a[2])

## SLURL-like address. Region names are percent-encoded (spaces etc.).
static func address(region: String, p: Vector3) -> String:
	return "%s%s/%d/%d/%d" % [SCHEME, region.uri_encode(), roundi(p.x), roundi(p.y), roundi(p.z)]

## {ok, region, pos: Vector3}; also accepts "Region/x/y/z" without the scheme.
static func parse_address(addr: String) -> Dictionary:
	var a := addr.strip_edges().trim_prefix(SCHEME)
	var parts := a.split("/", false)
	if parts.is_empty() or parts[0] == "": return {"ok": false}
	var v := [0.0, 0.0, 0.0]
	for i in 3:
		if parts.size() > i + 1:
			if not parts[i + 1].is_valid_float(): return {"ok": false}
			v[i] = float(parts[i + 1])
	return {"ok": true, "region": parts[0].uri_decode(), "pos": Vector3(v[0], v[1], v[2])}

static func _flag_ok(region: String, parcel: String, key: String, actor: Variant) -> bool:
	if Tiers.can(actor, "land", region): return true   # owner / estate managers (SL: EMs may always)
	return bool(Estate.parcel_get(region, parcel, key) if parcel != "" else Estate.region_get(region, key))

static func list() -> Array: return db()["landmarks"].duplicate(true)

## Save a landmark. Returns {ok, error?, id?}.
static func save_here(name: String, region: String, p: Vector3, actor: Variant = "self") -> Dictionary:
	var n := name.strip_edges().left(MAX_NAME)
	if n == "": n = "%s (%d, %d)" % [region, roundi(p.x), roundi(p.z)]
	if region == "": return {"ok": false, "error": "No region."}
	if not _flag_ok(region, Estate.parcel_id(p), "allow_landmark", actor):
		return {"ok": false, "error": "This land doesn't allow landmarks."}
	var lms: Array = db()["landmarks"]
	if lms.size() >= MAX_LANDMARKS: return {"ok": false, "error": "Landmark list is full (%d)." % MAX_LANDMARKS}
	var id := "lm%d_%d" % [int(Time.get_unix_time_from_system()), lms.size() + 1]
	lms.append({"id": id, "name": n, "region": region, "pos": _pos(p), "t": int(Time.get_unix_time_from_system())})
	if not _save():
		lms.pop_back()
		return {"ok": false, "error": "Saves are sealed. Unlock first."}
	return {"ok": true, "id": id}

static func remove(id: String) -> bool:
	var lms: Array = db()["landmarks"]
	for i in lms.size():
		if lms[i]["id"] == id:
			var gone: Dictionary = lms[i]
			lms.remove_at(i)
			if _save(): return true
			lms.insert(i, gone)
			return false
	return false

static func rename(id: String, name: String) -> bool:
	var n := name.strip_edges().left(MAX_NAME)
	if n == "": return false
	for l in db()["landmarks"]:
		if l["id"] == id:
			var old: String = l["name"]
			l["name"] = n
			if _save(): return true
			l["name"] = old
	return false

# ---------- home ----------
static func home() -> Dictionary: return db()["home"].duplicate(true)
static func has_home() -> bool: return not db()["home"].is_empty()

static func set_home(region: String, p: Vector3, actor: Variant = "self") -> String:
	if region == "": return "No region."
	if not _flag_ok(region, Estate.parcel_id(p), "allow_set_home", actor): return "This land doesn't allow Set Home."
	var prev: Dictionary = db()["home"]
	db()["home"] = {"region": region, "pos": _pos(p), "t": int(Time.get_unix_time_from_system())}
	if _save(): return ""
	db()["home"] = prev
	return "Saves are sealed. Unlock first."

# ---------- teleport history ----------
## Newest first. Consecutive duplicates (same region, within 2 m) are merged.
static func record_teleport(region: String, p: Vector3, label := "") -> void:
	var h: Array = db()["history"]
	if not h.is_empty() and h[0]["region"] == region and to_vec(h[0]).distance_to(p) < 2.0: return
	h.push_front({"region": region, "pos": _pos(p), "label": label.left(MAX_NAME), "t": int(Time.get_unix_time_from_system())})
	while h.size() > MAX_HISTORY: h.pop_back()
	_save()   # sealed + locked: kept in memory only (SecureFile refuses, nothing is clobbered)

static func history(limit := MAX_HISTORY) -> Array: return db()["history"].slice(0, limit)

static func clear_history() -> bool:
	var prev: Array = db()["history"]
	db()["history"] = []
	if _save(): return true
	db()["history"] = prev
	return false

static func reset_for_tests(p: String) -> void:
	path = p; _db = null
