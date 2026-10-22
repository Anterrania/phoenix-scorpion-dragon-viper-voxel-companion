class_name ShardModel
extends RefCounted
## Persistent planets + shards/servers model (docs/modules/SERVER_MESHING.md, tied to
## docs/ARCHITECTURE_AURORA_MODEL.md). A planning + simulation model used by the admin and tests; the
## real region servers come with the grid phase. Concepts:
## - Universe -> systems -> planets (data/frontier/planets.json). Planets are persistent: their voxel
##   edits and claims live in grid storage, not in a shard.
## - Shard = one live copy of the universe with a pool of servers. Each server has authority over
##   territories: a whole planet, or a quadtree cell of it ("planet/0/3").
## - Meshing: a territory whose load passes SPLIT_AT of a server's capacity splits into 4 child cells
##   on fresh servers; four sibling cells whose load drops under MERGE_AT merge back. Instances
##   (events, arenas) run on servers taken from the reserve pool and released when empty.
## - Entities: "unstowed" items exist in one shard; "stowed" ones live in the global inventory and can
##   unstow in any shard (ShipRegistry hangars use the same rule).
## - Standalone (today): one shard "local", one server, every planet on it.
## Changes to the shard config are owner-only (Tiers "admin").

const STORE := "shards"
const PLANETS := "res://data/frontier/planets.json"
const SPLIT_AT := 0.8
const MERGE_AT := 0.3
const MAX_DEPTH := 4
const DEFAULT_CAP := 100   # load units per server (players + weighted entities)

static func _db() -> Dictionary: return FrontierStore.db(STORE, {"shards": {}, "reserve": 4})
static func _snap() -> Dictionary: _db(); return FrontierStore.snap(STORE)

static func catalog() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLANETS))
	return d if d is Dictionary else {"systems": [], "planets": []}

static func planets(built_only := false) -> Array:
	return catalog().get("planets", []).filter(func(p): return not built_only or p.get("status") == "built")

## Standalone shard: one server owning every built planet.
static func standalone() -> Dictionary:
	var terr: Array = planets(true).map(func(p): return p["id"])
	return {"id": "local", "cap": DEFAULT_CAP, "servers": {"srv1": {"territories": terr, "kind": "territory"}}, "load": {}, "instances": {}, "seq": 1}

static func shards() -> Dictionary:
	if _db()["shards"].is_empty(): _db()["shards"]["local"] = standalone()
	return _db()["shards"]

static func shard(id: String) -> Dictionary: return shards().get(id, {})

static func add_shard(actor: Variant, id: String, cap := DEFAULT_CAP) -> Dictionary:
	if not Tiers.can(actor, "admin"): return FrontierStore.err("Owner only.")
	var sid := FrontierStore.clean(id, 24)
	if sid == "" or shards().has(sid): return FrontierStore.err("Pick a new shard name.")
	var snap := _snap()
	var s := standalone(); s["id"] = sid; s["cap"] = clampi(cap, 10, 100000)
	shards()[sid] = s
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"shard": sid}))

static func server_of(shard_id: String, territory: String) -> String:
	var s := shard(shard_id)
	var best := ""; var best_len := -1
	for srv in s.get("servers", {}):
		for t in s["servers"][srv]["territories"]:
			# longest matching prefix wins: "aurora_tundra/0/3" beats "aurora_tundra"
			if (territory == t or territory.begins_with(t + "/")) and t.length() > best_len: best = srv; best_len = t.length()
	return best

static func _new_server(s: Dictionary, kind := "territory") -> String:
	s["seq"] = int(s.get("seq", 1)) + 1
	var id := "srv%d" % s["seq"]
	s["servers"][id] = {"territories": [], "kind": kind}
	return id

## Report load for a territory and rebalance. Pure in-memory simulation (owner preview + tests);
## persist() saves the result when the owner wants it.
static func report_load(shard_id: String, territory: String, load: int) -> Dictionary:
	var s := shard(shard_id)
	if s.is_empty(): return FrontierStore.err("No such shard.")
	s["load"][territory] = maxi(0, load)
	return FrontierStore.ok({"events": rebalance(shard_id)})

static func rebalance(shard_id: String) -> Array:
	var s := shard(shard_id)
	var events: Array = []
	var cap := int(s["cap"])
	# split hot territories
	for srv in s["servers"].keys():
		for t in (s["servers"][srv]["territories"] as Array).duplicate():
			var l := int(s["load"].get(t, 0))
			if l > cap * SPLIT_AT and t.count("/") < MAX_DEPTH:
				s["servers"][srv]["territories"].erase(t)
				for q in 4:
					var child := "%s/%d" % [t, q]
					var target: String = srv if q == 0 else _new_server(s)
					s["servers"][target]["territories"].append(child)
					s["load"][child] = l / 4
				s["load"].erase(t)
				events.append({"split": t})
	# merge cold siblings
	var parents := {}
	for t in s["load"]:
		if str(t).count("/") > 0: parents[str(t).get_base_dir()] = true
	for p in parents:
		var kids: Array = []
		for q in 4: kids.append("%s/%d" % [p, q])
		if not kids.all(func(k): return s["load"].has(k) and server_of(shard_id, k) != ""): continue
		var total := 0
		for k in kids: total += int(s["load"][k])
		if total < cap * MERGE_AT:
			var keep := server_of(shard_id, kids[0])
			for k in kids:
				var srv := server_of(shard_id, k)
				s["servers"][srv]["territories"].erase(k)
				s["load"].erase(k)
				if srv != keep and s["servers"][srv]["territories"].is_empty(): s["servers"].erase(srv)
			s["servers"][keep]["territories"].append(p)
			s["load"][p] = total
			events.append({"merge": p})
	return events

## Instances (events, concerts, arenas) take reserve servers and give them back.
static func open_instance(shard_id: String, name: String) -> Dictionary:
	var s := shard(shard_id)
	if s.is_empty(): return FrontierStore.err("No such shard.")
	var in_use: int = s["instances"].size()
	if in_use >= int(_db()["reserve"]): return FrontierStore.err("No reserve servers free.")
	var srv := _new_server(s, "instance")
	var iid := "inst:" + FrontierStore.clean(name, 32)
	s["servers"][srv]["territories"].append(iid)
	s["instances"][iid] = srv
	return FrontierStore.ok({"instance": iid, "server": srv})

static func close_instance(shard_id: String, iid: String) -> Dictionary:
	var s := shard(shard_id)
	if not s.get("instances", {}).has(iid): return FrontierStore.err("No such instance.")
	s["servers"].erase(s["instances"][iid]); s["instances"].erase(iid)
	return FrontierStore.ok()

static func server_count(shard_id: String) -> int: return shard(shard_id).get("servers", {}).size()

## Owner saves the simulated layout (e.g. a planned split) to user://frontier/shards.json.
static func persist(actor: Variant) -> Dictionary:
	if not Tiers.can(actor, "admin"): return FrontierStore.err("Owner only.")
	var snap := _snap()
	return FrontierStore.commit(STORE, snap, FrontierStore.ok())

static func reset_layout() -> void: _db()["shards"] = {}

static func stats() -> Dictionary:
	var srv := 0
	for s in shards().values(): srv += s["servers"].size()
	return {"systems": catalog().get("systems", []).size(), "planets": planets().size(), "built_planets": planets(true).size(), "shards": shards().size(), "servers": srv}
