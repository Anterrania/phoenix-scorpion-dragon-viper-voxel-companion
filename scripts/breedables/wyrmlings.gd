class_name Wyrmlings
extends RefCounted
## v0.6 breedables: the Ember Wyrmling (original creature). Mendelian genetics:
## each trait has two alleles; lower index in the list = more dominant. Rare
## mutations. Feed to keep them happy; breed two fed adults for an offspring.
## Saved to user://wyrmlings.json.

const PATH := "user://wyrmlings.json"
const TRAITS := {
	"color": ["ember", "magenta", "gold", "platinum", "void"],
	"horn": ["single", "twin", "none", "crown"],
	"wing": ["small", "large", "none", "seraph"],
}
const COLORS := {"ember": "#ff5a14", "magenta": "#ff2fd0", "gold": "#f2bd3a", "platinum": "#e8e4f0", "void": "#2a1050"}
const MUTATION := 0.02
const BREED_COOLDOWN := 120.0  # seconds (real time)

static func load_all() -> Array:
	if not FileAccess.file_exists(PATH): return starters()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if d is Array and not d.is_empty() else starters()

static func save_all(list: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(list, "  "))

static func starters() -> Array:
	return [make("Cinder", {"color": ["ember", "gold"], "horn": ["single", "none"], "wing": ["small", "seraph"]}, 0),
		make("Rosa", {"color": ["magenta", "platinum"], "horn": ["twin", "crown"], "wing": ["large", "none"]}, 0)]

static func make(name: String, genes: Dictionary, gen: int) -> Dictionary:
	return {"id": "wyrm_%d_%d" % [Time.get_ticks_usec(), randi() % 10000], "name": name, "genes": genes,
		"generation": gen, "hunger": 0.0, "last_bred": 0.0, "owner": Profile.display_name()}

## Expressed trait = the more dominant allele.
static func expressed(w: Dictionary, trait_name: String) -> String:
	var al: Array = w["genes"][trait_name]
	var order: Array = TRAITS[trait_name]
	return al[0] if order.find(al[0]) <= order.find(al[1]) else al[1]

## Rarity from how many recessive/rare alleles are expressed.
static func rarity(w: Dictionary) -> String:
	var score := 0
	for t in TRAITS:
		score += TRAITS[t].find(expressed(w, t))
	return ["Common", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Legendary"][mini(score, 6)]

static func feed(w: Dictionary) -> void:
	w["hunger"] = maxf(0.0, float(w["hunger"]) - 0.5)

static func can_breed(a: Dictionary, b: Dictionary, now: float) -> String:
	if a["id"] == b["id"]: return "pick two different wyrmlings"
	for w in [a, b]:
		if float(w["hunger"]) > 0.5: return "%s is too hungry - feed first" % w["name"]
		if now - float(w["last_bred"]) < BREED_COOLDOWN: return "%s needs rest before breeding" % w["name"]
	return ""

static func breed(a: Dictionary, b: Dictionary, now: float, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new(); rng.randomize()
	var genes := {}
	for t in TRAITS:
		var pa: String = a["genes"][t][rng.randi() % 2]
		var pb: String = b["genes"][t][rng.randi() % 2]
		if rng.randf() < MUTATION: pa = TRAITS[t][rng.randi() % TRAITS[t].size()]
		genes[t] = [pa, pb]
	a["last_bred"] = now; b["last_bred"] = now
	a["hunger"] = float(a["hunger"]) + 0.4; b["hunger"] = float(b["hunger"]) + 0.4
	var names := ["Ash", "Blaze", "Nyx", "Sol", "Vex", "Lumi", "Pyra", "Zeph", "Kira", "Onyx"]
	return make(names[rng.randi() % names.size()], genes, maxi(int(a["generation"]), int(b["generation"])) + 1)

static func tick_hunger(list: Array, seconds: float) -> void:
	for w in list: w["hunger"] = minf(1.0, float(w["hunger"]) + seconds / 600.0)

## Smooth 3D model from expressed genes.
static func build_model(w: Dictionary) -> Node3D:
	var K = PropKit
	var n := Node3D.new()
	n.name = str(w["name"])
	var col: String = COLORS[expressed(w, "color")]
	var m = K.mat(col, 0.8, 0.4, 0.3)
	K.part(n, K.sphere(0.35, 12), m, Vector3(0, 0.4, 0), Vector3(1, 0.8, 1.4))
	K.part(n, K.sphere(0.2, 10), m, Vector3(0, 0.62, -0.45))
	K.part(n, K.cone(0.0, 0.1, 0.6, 6), m, Vector3(0, 0.35, 0.6), Vector3.ONE, Vector3(1.3, 0, 0))
	for s in [-1.0, 1.0]: K.part(n, K.sphere(0.04, 6), K.mat("#ffffff", 4.0), Vector3(s * 0.08, 0.68, -0.62))
	match expressed(w, "horn"):
		"single": K.part(n, K.cone(0.0, 0.04, 0.2, 6), K.mat("#f2bd3a", 0.5, 1.0, 0.2), Vector3(0, 0.82, -0.48))
		"twin":
			for s in [-1.0, 1.0]: K.part(n, K.cone(0.0, 0.035, 0.18, 6), K.mat("#f2bd3a", 0.5, 1.0, 0.2), Vector3(s * 0.08, 0.8, -0.42), Vector3.ONE, Vector3(0, 0, -s * 0.3))
		"crown":
			for i in 5: K.part(n, K.cone(0.0, 0.03, 0.14, 4), K.mat("#e8e4f0", 1.0, 1.0, 0.2), Vector3(cos(i * 1.256) * 0.1, 0.8, -0.45 + sin(i * 1.256) * 0.1))
	var wing: String = expressed(w, "wing")
	if wing != "none":
		var ws: float = {"small": 0.35, "large": 0.6, "seraph": 0.75}[wing]
		var wm = K.mat("#ffffff", 2.0) if wing == "seraph" else K.mat(col, 0.4, 0.3, 0.4)
		for s in [-1.0, 1.0]: K.part(n, K.cone(0.0, ws * 0.5, ws * 1.4, 3), wm, Vector3(s * ws * 0.6, 0.6, 0), Vector3(1, 1, 0.1), Vector3(0, 0, -s * 1.1))
	n.scale = Vector3.ONE * (2.2 if int(w["generation"]) == 0 else 1.8)
	return n
