class_name Materials
extends RefCounted
## LIFE-6: mining, refining, processing and crafting with real materials. Every craft and build
## consumes its inputs (data/living/recipes.json graph: refine -> process -> alloy -> component -> build).
## - mine(): needs Tiers.can(actor, "build", parcel) (mining changes land) and the nation's "mining" law
##   (Governance.law_allows). Exempt owner skips the law, never the estate (owner always has build).
##   Costs fatigue through Survival when rules apply.
## - craft(): station + inputs + (for blueprint recipes) a Blueprints item the actor owns or a copy
##   with runs left. Nothing is consumed unless the craft succeeds.
## - Industry bridge: the Frontier industry (feature/spacesim-parity: Industry, recipes in
##   data/frontier/recipes.json, ME/TE research, job queue) is the long-job factory. When that class is
##   present, export_to_industry() moves refined stock into its stockpile with the "system" actor, so
##   mined materials feed its jobs instead of a second stockpile. When it is absent the bridge is a no-op.
## inventory: a plain Dictionary {material: count} owned by the caller (Inventory, satchel or server).

const DATA := "res://data/living/recipes.json"
static var _db = null

static func db() -> Dictionary:
	if _db == null:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_db = d if d is Dictionary else {"recipes": {}, "stations": []}
	return _db

static func recipes() -> Dictionary: return db()["recipes"]
static func recipe(id: String) -> Dictionary: return recipes().get(id, {})

static func name_of(id: String) -> String:
	var o := Geology.ore(id)
	if not o.is_empty(): return str(o["name"])
	return str(Geology.db()["processed"].get(id, id.capitalize()))

static func _parcel(region: String, pos: Vector3) -> Dictionary:
	return {"region": region, "parcel": Estate.parcel_id(pos)}

## Mine one voxel. Returns {"ok", "error", "ore"} and adds the ore to inv.
static func mine(actor: Variant, region: String, pos: Vector3, surface_h: int, inv: Dictionary, seed_value := 1337) -> Dictionary:
	var p := _parcel(region, pos)
	if not Tiers.can(actor, "build", p): return {"ok": false, "error": "You can't dig on this land.", "ore": ""}
	if not Governance.law_allows(actor, region, "mining", p["parcel"]): return {"ok": false, "error": "Mining is against the law here.", "ore": ""}
	var o := Geology.deposit_at(LivingGate.realm_of(region), int(pos.x), int(pos.y), int(pos.z), surface_h, seed_value)
	if o == "": return {"ok": true, "error": "", "ore": ""}   # plain rock: dug, nothing collected
	inv[o] = int(inv.get(o, 0)) + 1
	return {"ok": true, "error": "", "ore": o}

## Can this recipe run? Returns "" or the reason.
static func check(actor: Variant, recipe_id: String, inv: Dictionary, station: String, runs := 1, blueprint_id := "") -> String:
	var r := recipe(recipe_id)
	if r.is_empty(): return "Unknown recipe."
	if not Tiers.can(actor, "build"): return "You can't craft right now."
	if str(r["station"]) != "hands" and station != str(r["station"]): return "Needs a %s." % r["station"]
	if bool(r.get("blueprint", false)):
		var e := Blueprints.can_use(actor, blueprint_id, recipe_id, runs)
		if e != "": return e
	for m in r["inputs"]:
		if int(inv.get(m, 0)) < int(r["inputs"][m]) * runs: return "Missing %d %s." % [int(r["inputs"][m]) * runs - int(inv.get(m, 0)), name_of(m)]
	return ""

## Craft/refine/build. Consumes inputs, adds outputs. Returns {"ok", "error", "outputs"}.
static func craft(actor: Variant, recipe_id: String, inv: Dictionary, station: String, runs := 1, blueprint_id := "") -> Dictionary:
	runs = clampi(runs, 1, 1000)
	var e := check(actor, recipe_id, inv, station, runs, blueprint_id)
	if e != "": return {"ok": false, "error": e, "outputs": {}}
	var r := recipe(recipe_id)
	if bool(r.get("blueprint", false)):
		e = Blueprints.consume_runs(actor, blueprint_id, runs)
		if e != "": return {"ok": false, "error": e, "outputs": {}}
	for m in r["inputs"]:
		inv[m] = int(inv[m]) - int(r["inputs"][m]) * runs
		if int(inv[m]) <= 0: inv.erase(m)
	var out := {}
	for m in r["outputs"]:
		out[m] = int(r["outputs"][m]) * runs
		inv[m] = int(inv.get(m, 0)) + out[m]
	return {"ok": true, "error": "", "outputs": out}

## Total raw materials (ores) a build needs, expanding the recipe graph (first producer wins).
static func raw_cost(item: String, qty := 1, _depth := 0) -> Dictionary:
	if _depth > 12 or Geology.ores().has(item): return {item: qty}
	var rid := producer(item)
	if rid == "": return {item: qty}
	var r := recipe(rid)
	var runs := int(ceil(float(qty) / float(r["outputs"][item])))
	var out := {}
	for m in r["inputs"]:
		var sub := raw_cost(m, int(r["inputs"][m]) * runs, _depth + 1)
		for k in sub: out[k] = int(out.get(k, 0)) + int(sub[k])
	return out

static func producer(item: String) -> String:
	var ids := recipes().keys(); ids.sort()
	for id in ids:
		if recipes()[id]["outputs"].has(item): return id
	return ""

## Graph check: every input is an ore or produced by some recipe; no unknown stations.
static func validate_graph() -> Array:
	var bad: Array = []
	for id in recipes():
		var r: Dictionary = recipes()[id]
		if not str(r["station"]) in db()["stations"]: bad.append("%s: unknown station" % id)
		for m in r["inputs"]:
			if not Geology.ores().has(m) and producer(m) == "": bad.append("%s: nothing makes %s" % [id, m])
	return bad

# ---------- Industry bridge (feature/spacesim-parity) ----------
static func industry_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == "Industry": return load(str(c["path"]))
	return null

## Move materials into the Frontier Industry stockpile. Returns how many stacks moved (0 if absent).
static func export_to_industry(owner: String, inv: Dictionary) -> int:
	var ind := industry_script()
	if ind == null: return 0
	var n := 0
	for m in inv.keys():
		var r: Variant = ind.call("add_materials", "system", owner, m, int(inv[m]))
		if r is Dictionary and bool(r.get("ok", false)):
			inv.erase(m); n += 1
	return n

static func reset_cache() -> void: _db = null
