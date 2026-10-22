class_name Industry
extends RefCounted
## Industry: recipes, blueprints and a timed job queue. Concepts: blueprint originals (unlimited runs)
## and copies (limited runs), material-efficiency (ME 0..10, -1% inputs per level) and time-efficiency
## (TE 0..20 in steps of 2, -1% time per point) research, copying, a per-actor stockpile, job slots by
## tier, org jobs gated by org rights. Recipes: data/frontier/recipes.json (original names).
## Jobs are timestamps, so they "run" while the app is closed; collect() delivers finished ones.

const STORE := "industry"
const RECIPES := "res://data/frontier/recipes.json"
const JOB_KINDS := ["manufacture", "research_me", "research_te", "copy"]
const MAX_ME := 10
const MAX_TE := 20
const MAX_RUNS := 100
const SLOTS := {"guest": 0, "resident": 2, "creator": 4, "staff": 6, "estate_manager": 6, "owner": 10}
const RESEARCH_S := 120   # per level
const COPY_S := 60        # per run copied

static var _recipes = null

static func _db() -> Dictionary: return FrontierStore.db(STORE, {"blueprints": {}, "jobs": [], "stock": {}})
static func _snap() -> Dictionary: _db(); return FrontierStore.snap(STORE)

static func recipes() -> Dictionary:
	if _recipes == null:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECIPES))
		_recipes = d.get("recipes", {}) if d is Dictionary else {}
	return _recipes

static func stock(owner: String) -> Dictionary: return _db()["stock"].get(owner, {}).duplicate()

static func _add(owner: String, mat: String, qty: int) -> void:
	var s: Dictionary = _db()["stock"].get(owner, {})
	s[mat] = int(s.get(mat, 0)) + qty
	if int(s[mat]) <= 0: s.erase(mat)
	_db()["stock"][owner] = s

## Materials come from gathering/mining (system) or staff tools. Not a player cheat.
static func add_materials(actor: Variant, owner: String, mat: String, qty: int) -> Dictionary:
	if not (Tiers.actor_id(actor) == "system" or Tiers.can(actor, "moderate")): return FrontierStore.err("System or staff only.")
	if qty == 0 or FrontierStore.clean(mat, 48) == "": return FrontierStore.err("Pick a material and amount.")
	var snap := _snap(); _add(owner, FrontierStore.clean(mat, 48), qty)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"stock": stock(owner)}))

static func grant_blueprint(actor: Variant, owner: String, recipe: String) -> Dictionary:
	if not (Tiers.actor_id(actor) == "system" or Tiers.can(actor, "moderate")): return FrontierStore.err("System or staff only.")
	if not recipes().has(recipe): return FrontierStore.err("No such recipe.")
	var snap := _snap()
	var id := FrontierStore.next_id(STORE, "bp")
	_db()["blueprints"][id] = {"id": id, "recipe": recipe, "owner": owner, "kind": "original", "runs": -1, "me": 0, "te": 0}
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"id": id}))

static func blueprints(owner: String) -> Array:
	return _db()["blueprints"].values().filter(func(b): return b["owner"] == owner).duplicate(true)

static func slots_for(actor: Variant) -> int: return int(SLOTS.get(Tiers.tier_of(actor), 0))

static func jobs(owner: String, active_only := false) -> Array:
	return _db()["jobs"].filter(func(j): return j["owner"] == owner and (not active_only or j["state"] == "running")).duplicate(true)

## Material needs for `runs` with ME applied (never below 1 per input per run).
static func inputs_for(recipe: String, runs: int, me := 0) -> Dictionary:
	var out := {}
	var r: Dictionary = recipes().get(recipe, {})
	for m in r.get("inputs", {}):
		out[m] = maxi(runs, int(ceil(float(r["inputs"][m]) * runs * (1.0 - me / 100.0))))
	return out

## Stable API for the living-world/mining stream (Blueprint, Recipe, Industry.start_job).
## Recipe: a dictionary from recipes(); Blueprint: a dictionary from blueprints(owner).
static func recipe(id: String) -> Dictionary: return recipes().get(id, {}).duplicate(true)
static func blueprint(id: String) -> Dictionary: return _db()["blueprints"].get(id, {}).duplicate(true)
static func start_job(actor: Variant, recipe_id: String, runs := 1, opts := {}) -> Dictionary:
	var o := opts.duplicate(); o["runs"] = runs
	return start(actor, str(o.get("kind", "manufacture")), recipe_id, o)

## opts: blueprint (id; required for blueprint recipes and for research/copy), runs, org (Social group id).
static func start(actor: Variant, kind: String, recipe: String, opts := {}) -> Dictionary:
	var me := Tiers.actor_id(actor)
	if not Tiers.can(actor, "industry"): return FrontierStore.err("Residents and up can run industry.")
	if not kind in JOB_KINDS: return FrontierStore.err("Unknown job.")
	var r: Dictionary = recipes().get(recipe, {})
	if r.is_empty(): return FrontierStore.err("No such recipe.")
	var org := str(opts.get("org", ""))
	var owner := me
	if org != "":
		if not OrgRights.has(actor, org, "factory" if kind == "manufacture" else "research"): return FrontierStore.err("Needs the org factory/research right.")
		owner = "org:" + org
	if jobs(me, true).size() >= slots_for(actor): return FrontierStore.err("All %d job slots are busy." % slots_for(actor))
	var runs := clampi(int(opts.get("runs", 1)), 1, MAX_RUNS)
	var bp: Dictionary = _db()["blueprints"].get(str(opts.get("blueprint", "")), {})
	if not bp.is_empty() and (bp["owner"] != owner or bp["recipe"] != recipe): return FrontierStore.err("Not your blueprint for that recipe.")
	if (kind != "manufacture" or bool(r.get("needs_blueprint", false))) and bp.is_empty(): return FrontierStore.err("Needs a blueprint.")
	if kind in ["research_me", "research_te", "copy"] and bp["kind"] != "original": return FrontierStore.err("Only originals can be researched or copied.")
	if kind == "manufacture" and not bp.is_empty() and bp["kind"] == "copy" and int(bp["runs"]) < runs: return FrontierStore.err("This copy has %d runs left." % bp["runs"])
	if kind == "research_me" and int(bp["me"]) >= MAX_ME: return FrontierStore.err("Material research is maxed.")
	if kind == "research_te" and int(bp["te"]) >= MAX_TE: return FrontierStore.err("Time research is maxed.")
	if _db()["jobs"].any(func(j): return j["state"] == "running" and j["blueprint"] != "" and j["blueprint"] == bp.get("id", "") and kind != "manufacture"): return FrontierStore.err("That blueprint is busy.")
	var snap := _snap()
	var dur := 0
	if kind == "manufacture":
		var need := inputs_for(recipe, runs, int(bp.get("me", 0)))
		var have: Dictionary = _db()["stock"].get(owner, {})
		for m in need:
			if int(have.get(m, 0)) < int(need[m]): return FrontierStore.err("Missing %d %s." % [int(need[m]) - int(have.get(m, 0)), m])
		for m in need: _add(owner, m, -int(need[m]))
		dur = int(ceil(float(r["seconds"]) * runs * (1.0 - int(bp.get("te", 0)) / 100.0)))
		if not bp.is_empty() and bp["kind"] == "copy":
			bp["runs"] = int(bp["runs"]) - runs
	elif kind == "copy": dur = COPY_S * runs * int(r.get("tier", 1))
	else: dur = RESEARCH_S * int(r.get("tier", 1)) * (1 + (int(bp["me"]) if kind == "research_me" else int(bp["te"]) / 2))
	var t := FrontierStore.now()
	var j := {"id": FrontierStore.next_id(STORE, "j"), "owner": me, "deliver_to": owner, "kind": kind, "recipe": recipe, "blueprint": str(bp.get("id", "")),
		"runs": runs, "start": t, "end": t + dur, "state": "running"}
	_db()["jobs"].append(j)
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"job": j.duplicate(), "seconds": dur}))

## Deliver every finished job for this actor. Returns {"ok", "delivered": [job ids]}.
static func collect(actor: Variant) -> Dictionary:
	var me := Tiers.actor_id(actor)
	var t := FrontierStore.now()
	var done: Array = []
	var snap := _snap()
	for j in _db()["jobs"]:
		if j["owner"] != me or j["state"] != "running" or j["end"] > t: continue
		var r: Dictionary = recipes().get(j["recipe"], {})
		var bp: Dictionary = _db()["blueprints"].get(j["blueprint"], {})
		match j["kind"]:
			"manufacture":
				for m in r.get("outputs", {}): _add(j["deliver_to"], m, int(r["outputs"][m]) * int(j["runs"]))
			"research_me": if not bp.is_empty(): bp["me"] = mini(MAX_ME, int(bp["me"]) + 1)
			"research_te": if not bp.is_empty(): bp["te"] = mini(MAX_TE, int(bp["te"]) + 2)
			"copy":
				var id := FrontierStore.next_id(STORE, "bp")
				_db()["blueprints"][id] = {"id": id, "recipe": j["recipe"], "owner": j["deliver_to"], "kind": "copy", "runs": int(j["runs"]), "me": int(bp.get("me", 0)), "te": int(bp.get("te", 0))}
		j["state"] = "delivered"; done.append(j["id"])
	_db()["jobs"] = _db()["jobs"].filter(func(x): return x["state"] == "running" or FrontierStore.now() - int(x["end"]) < 7 * 86400)
	if done.is_empty(): return FrontierStore.ok({"delivered": []})
	return FrontierStore.commit(STORE, snap, FrontierStore.ok({"delivered": done}))

static func cancel(actor: Variant, job_id: String) -> Dictionary:
	for j in _db()["jobs"]:
		if j["id"] == job_id and j["state"] == "running":
			if j["owner"] != Tiers.actor_id(actor) and not Tiers.can(actor, "moderate"): return FrontierStore.err("Not your job.")
			var snap := _snap()
			for x in _db()["jobs"]:
				if x["id"] == job_id: x["state"] = "cancelled"   # inputs are not refunded
			return FrontierStore.commit(STORE, snap, FrontierStore.ok())
	return FrontierStore.err("No running job with that id.")

static func stats() -> Dictionary:
	return {"recipes": recipes().size(), "blueprints": _db()["blueprints"].size(), "running": _db()["jobs"].filter(func(j): return j["state"] == "running").size()}

static func reset_cache() -> void: _recipes = null
