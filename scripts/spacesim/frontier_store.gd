class_name FrontierStore
extends RefCounted
## Shared local store for the Frontier systems (docs/modules/SPACESIM_PARITY.md): market, contracts,
## industry, orgs, territory, ships, shards, comfort. Concepts only, inspired by space-sim games; no
## game's code, assets, names or trademarks are used in-game.
##
## LocalServices mode: one encrypted JSON file per system under user://frontier/ through SecureFile
## (sealed like every other save once an OwnerVault exists). Grid mode later swaps this for grid
## services behind the same static APIs (docs/ARCHITECTURE_AURORA_MODEL.md, docs/modules/SERVER_MESHING.md).
## Every result is {"ok": bool, "error": String, ...} like Social.

static var root := "user://frontier"
static var _dbs := {}          # name -> Dictionary (cached)
static var clock := Callable() # tests: returns unix seconds
static var _hooked := false

static func now() -> int:
	return int(clock.call()) if clock.is_valid() else int(Time.get_unix_time_from_system())

static func path(name: String) -> String: return root.path_join(name + ".json")

## Cached store for one system; `defaults` fills missing top-level keys.
static func db(name: String, defaults: Dictionary) -> Dictionary:
	if not _hooked:
		_hooked = true
		OwnerVault.on_storage_ready.append(reload_all)
	if not _dbs.has(name):
		var d: Variant = SecureFile.read_json(path(name), {})
		_dbs[name] = d if d is Dictionary else {}
	var t: Dictionary = _dbs[name]
	for k in defaults:
		if not t.has(k): t[k] = defaults[k].duplicate(true) if defaults[k] is Dictionary or defaults[k] is Array else defaults[k]
	if not t.has("seq"): t["seq"] = 0
	return t

static func next_id(name: String, prefix: String) -> String:
	var t: Dictionary = _dbs[name]
	t["seq"] = int(t["seq"]) + 1
	return "%s%d" % [prefix, t["seq"]]

static func snap(name: String) -> Dictionary: return (_dbs[name] as Dictionary).duplicate(true)

## Save, or roll back to `rollback` and report sealed saves.
static func commit(name: String, rollback: Dictionary, result: Dictionary) -> Dictionary:
	if SecureFile.write_json(path(name), _dbs[name]): return result
	_dbs[name] = rollback
	return err("Saves are sealed. Unlock first.")

static func ok(extra := {}) -> Dictionary:
	var r := {"ok": true, "error": ""}; r.merge(extra); return r
static func err(e: String) -> Dictionary: return {"ok": false, "error": e}

## Plain text only (same rule as Social.clean).
static func clean(text: Variant, cap := 200) -> String:
	return str(text).strip_edges().left(cap).replace("[", "(").replace("]", ")")

static func reload_all() -> void: _dbs = {}

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _dbs = {}
