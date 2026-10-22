class_name Genome
extends RefCounted
## LIFE-2: species viability through DNA. Extends the existing DNA work (CompanionDNA = cosmetic
## avatar slots, AvatarDNA = body, Wyrmlings = Mendelian colour/horn/wing traits) with a TOLERANCE
## genome: what an organism needs and can survive. Species: data/living/species.json.
##
## - Each tolerance gene has two alleles; the expressed value is their mean (additive, like most real
##   quantitative tolerance traits). A species' listed value is used for both alleles.
## - viability(genome, env) -> {ok, score 0..1, reasons}. Spawning and long-term survival need ok.
##   Extremophile model: microbes with o2_min 0 live anaerobically (chemolithotrophs in Venus clouds);
##   vacuum kills anything without pressure_min 0 unless it is inside a sealed habitat env.
## - Creatures/species ONLY. combine() mixes two parent genomes into an offspring genome
##   (non-sexual genetics: per-gene pick one allele from each parent + small mutation). Players and
##   companions never get a tolerance genome and can never be parents (kind must be creature/plant/
##   microbe/synthetic). Old saves: persona/creature "genome" is optional; missing -> species default.

const KINDS := ["creature", "plant", "microbe", "synthetic"]
const SPECIES_PATH := "res://data/living/species.json"
const MUTATION := 0.04       # chance per gene
const MUTATION_SPAN := 0.08  # +-8% of the value
static var _db = null

static func db() -> Dictionary:
	if _db == null:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPECIES_PATH))
		_db = d if d is Dictionary else {"genes": [], "species": {}}
	return _db

static func genes() -> Array: return db().get("genes", [])
static func species(id: String) -> Dictionary: return db().get("species", {}).get(id, {})
static func species_ids() -> Array: return db().get("species", {}).keys()

## Diploid genome for a species: {species, kind, genus, alleles: {gene: [a, b]}}.
static func of_species(id: String) -> Dictionary:
	var s := species(id)
	if s.is_empty(): return {}
	var al := {}
	for g in genes(): al[g] = [float(s["genes"].get(g, 0.0)), float(s["genes"].get(g, 0.0))]
	return {"species": id, "kind": str(s.get("kind", "creature")), "genus": str(s.get("genus", id)), "metabolism": str(s.get("metabolism", "aerobic")), "alleles": al, "generation": 0}

## Tolerance genome stored on a creature save (optional field "genome"). Missing or malformed ->
## species default, so pre-LIFE saves load unchanged.
static func from_record(rec: Dictionary) -> Dictionary:
	var g: Variant = rec.get("genome")
	if g is Dictionary and g.has("alleles") and g.has("species"): return g
	return of_species(str(rec.get("species", "")))

## Persona records (players, companions) have no tolerance genome by design.
static func for_persona(_persona: Dictionary) -> Dictionary: return {}

static func expressed(genome: Dictionary, gene: String) -> float:
	var a: Array = genome.get("alleles", {}).get(gene, [0.0, 0.0])
	return (float(a[0]) + float(a[1])) / 2.0

## env from WorldEnv.outdoor()/personal(). Returns {ok, score, reasons: [String]}.
static func viability(genome: Dictionary, env: Dictionary) -> Dictionary:
	var reasons: Array = []
	if genome.is_empty(): return {"ok": false, "score": 0.0, "reasons": ["no genome"]}
	var t := float(env.get("temp_c", 15))
	var p := float(env.get("pressure_kpa", 101.3))
	var o2 := float(env.get("o2_kpa", 21.0))
	if t < expressed(genome, "temp_min"): reasons.append("too cold")
	if t > expressed(genome, "temp_max"): reasons.append("too hot")
	if p < expressed(genome, "pressure_min"): reasons.append("vacuum" if p <= 0.0 else "pressure too low")
	if p > expressed(genome, "pressure_max"): reasons.append("pressure too high")
	if o2 < expressed(genome, "o2_min"): reasons.append("not enough oxygen")
	if float(env.get("radiation_msv_day", 0)) > expressed(genome, "radiation_tol"): reasons.append("radiation")
	if float(env.get("water", 0.5)) < expressed(genome, "water_min"): reasons.append("too dry")
	var ph := float(env.get("ph", 7.0))
	if bool(env.get("acid", false)): ph = minf(ph, 1.0)
	if ph < expressed(genome, "ph_min") or ph > expressed(genome, "ph_max"): reasons.append("soil/water chemistry")
	if float(env.get("gravity", 9.81)) > expressed(genome, "gravity_max"): reasons.append("gravity too strong")
	# comfort score: distance from the centre of the temperature window
	var lo := expressed(genome, "temp_min"); var hi := expressed(genome, "temp_max")
	var score := 0.0
	if reasons.is_empty():
		var mid := (lo + hi) / 2.0; var half := maxf((hi - lo) / 2.0, 0.001)
		score = clampf(1.0 - absf(t - mid) / half * 0.5, 0.1, 1.0)
	return {"ok": reasons.is_empty(), "score": score, "reasons": reasons}

## Species that can spawn in a realm. t01 < 0 = in any season (samples coldest..warmest).
static func spawnable(realm_name: String, y := 0.0, t01 := -1.0) -> Array:
	var samples: Array = [t01] if t01 >= 0.0 else [0.0, 0.25, 0.5, 0.75, 1.0]
	var out: Array = []
	for id in species_ids():
		for s in samples:
			if bool(viability(of_species(id), WorldEnv.outdoor(realm_name, y, s))["ok"]):
				out.append(id); break
	out.sort()
	return out

## Can two genomes be combined? Same genus, both creature-kinds, and not personas.
static func compatible(a: Dictionary, b: Dictionary) -> String:
	for g in [a, b]:
		if g.is_empty() or not g.has("alleles"): return "Both parents need a creature genome."
		if not str(g.get("kind", "")) in KINDS: return "Only creatures and plants can be combined."
	if str(a.get("genus", "")) != str(b.get("genus", "")): return "Different genus: not compatible."
	return ""

## Offspring genome: for each gene take one allele from each parent (random), maybe mutate.
## Hybrids of two species in one genus get species "<a>_x_<b>" and generation +1.
static func combine(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if compatible(a, b) != "": return {}
	if rng == null:
		rng = RandomNumberGenerator.new(); rng.randomize()
	var al := {}
	for g in genes():
		var pa: Array = a["alleles"].get(g, [0.0, 0.0]); var pb: Array = b["alleles"].get(g, [0.0, 0.0])
		var x := float(pa[rng.randi() % 2]); var y := float(pb[rng.randi() % 2])
		if rng.randf() < MUTATION: x += absf(x) * rng.randf_range(-MUTATION_SPAN, MUTATION_SPAN)
		al[g] = [x, y]
	var sp := str(a["species"]) if a["species"] == b["species"] else "%s_x_%s" % [a["species"], b["species"]]
	return {"species": sp, "kind": str(a["kind"]), "genus": str(a["genus"]), "metabolism": str(a.get("metabolism", "aerobic")),
		"alleles": al, "generation": maxi(int(a.get("generation", 0)), int(b.get("generation", 0))) + 1}

static func reset_cache() -> void: _db = null
