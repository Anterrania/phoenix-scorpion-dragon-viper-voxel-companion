extends Node3D
## v0.5 world content: biome-scattered smooth props (streamed in 32 m cells around
## the player) + placeholder landmark sites from data/landmarks.json with
## "YOUR INPUT HERE" signs.

const CELL := 32.0
const RANGE := 3  # cells each side
const LANDMARKS_PATH := "res://data/landmarks.json"
var generator
var player: Node3D
var landmarks: Array = []   # [{id,name,biome,position,node}]
var _cells := {}
var _scan := 0.0
var _islands: Array = []
var _t := 0.0

func setup(gen, p: Node3D) -> void:
	generator = gen
	player = p
	_place_landmarks()
	_stream(true)
	_place_radio()

static func load_landmarks() -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LANDMARKS_PATH))
	return d.get("landmarks", []) if d is Dictionary else []

func ground(x: float, z: float) -> float:
	return maxf(generator.height_f(x, z), generator.LAVA_LEVEL + 0.2)

## Nearest dry spot of a biome, searched outward in a spiral starting at `angle`.
func find_site(biome: int, angle: float) -> Vector2:
	for i in 3000:
		var r := 120.0 + i * 6.0
		var a := angle + i * 0.37
		var x := cos(a) * r
		var z := sin(a) * r
		var ok := true
		for o in [Vector2.ZERO, Vector2(25, 0), Vector2(-25, 0), Vector2(0, 25), Vector2(0, -25)]:
			if generator.biome_at(x + o.x, z + o.y) != biome or generator.height_f(x + o.x, z + o.y) < generator.LAVA_LEVEL + 1.0:
				ok = false; break
		if ok: return Vector2(x, z)
	return Vector2(400.0 * (biome + 1), 0)

func _place_landmarks() -> void:
	var rng := RandomNumberGenerator.new()
	var i := 0
	for L in load_landmarks():
		rng.seed = hash(L["id"])
		var site: Vector2
		if L.has("near_spawn"):
			site = Vector2(float(L["near_spawn"][0]), float(L["near_spawn"][1]))
		else:
			site = find_site(int(L["biome"]), i * 1.7)
		var y := ground(site.x, site.y)
		for o in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
			y = minf(y, ground(site.x + o.x, site.y + o.y))
		var n := LandmarkBuilder.build(str(L["structure"]), rng)
		n.name = str(L["id"])
		add_child(n)
		n.global_position = Vector3(site.x, y, site.y)
		n.set_meta("landmark", L)
		var s := PropKit.make_sign(str(L["name"]), "placeholder · tap MENU › Where to give input")
		add_child(s)
		var sp := site + Vector2(0, 12).rotated(i * 0.9)
		s.global_position = Vector3(sp.x, ground(sp.x, sp.y), sp.y)
		landmarks.append({"id": L["id"], "name": L["name"], "biome": int(L["biome"]), "position": n.global_position, "node": n, "input": L.get("input", [])})
		i += 1

var radio: MusicRadio
func _place_radio() -> void:
	radio = MusicRadio.new()
	add_child(radio)
	radio.global_position = Vector3(-6, ground(-6, -10), -10)
	radio.setup(player)

func landmark_by_id(id: String) -> Dictionary:
	for l in landmarks:
		if l["id"] == id: return l
	return {}

func _stream(force: bool) -> void:
	if player == null or generator == null: return
	var c := Vector2i(floori(player.global_position.x / CELL), floori(player.global_position.z / CELL))
	var keep := {}
	for dx in range(-RANGE, RANGE + 1):
		for dz in range(-RANGE, RANGE + 1):
			var k := c + Vector2i(dx, dz)
			keep[k] = true
			if not _cells.has(k): _cells[k] = _fill_cell(k)
	for k in _cells.keys():
		if not keep.has(k):
			if is_instance_valid(_cells[k]): _cells[k].queue_free()
			_cells.erase(k)

func _near_landmark(p: Vector3) -> bool:
	for l in landmarks:
		var lp: Vector3 = l["position"]
		if Vector2(lp.x - p.x, lp.z - p.z).length() < 16.0: return true
	return Vector2(p.x, p.z).length() < 8.0  # keep spawn clear

func _fill_cell(k: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "Cell_%d_%d" % [k.x, k.y]
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var count := rng.randi_range(4, 8)
	for i in count:
		var x := (k.x + rng.randf()) * CELL
		var z := (k.y + rng.randf()) * CELL
		var b: int = generator.biome_at(x, z)
		var h: float = generator.height_f(x, z)
		var p := Vector3(x, h - 0.15, z)
		if _near_landmark(p): continue
		var n: Node3D = null
		var roll := rng.randf()
		match b:
			0:
				if h < generator.LAVA_LEVEL + 0.5: continue
				n = PropKit.spruce(rng) if roll < 0.45 else (PropKit.shrub(rng, "#4a5e48") if roll < 0.7 else (PropKit.rock(rng, "#6a6878") if roll < 0.9 else PropKit.crystal_cluster(rng, "#9ad8ff")))
			1:
				if h < generator.LAVA_LEVEL + 0.3: continue
				n = PropKit.obsidian_spire(rng) if roll < 0.35 else (PropKit.lava_vent(rng) if roll < 0.6 else PropKit.rock(rng, "#2a1a18"))
			2:
				if roll < 0.3:
					n = PropKit.floating_island(rng)
					p.y = maxf(h, generator.LAVA_LEVEL) + rng.randf_range(12.0, 30.0)
					_islands.append(n)
				else:
					n = PropKit.crystal_cluster(rng, ["#ff2fd2", "#b48cff", "#e8e4f0"][rng.randi() % 3]) if roll < 0.8 else PropKit.rock(rng, "#24163e")
		if n == null: continue
		n.rotation.y = rng.randf() * TAU
		root.add_child(n)
		n.position = p
		n.set_meta("base_y", p.y)
	return root

func prop_count() -> int:
	var c := 0
	for k in _cells:
		if is_instance_valid(_cells[k]): c += _cells[k].get_child_count()
	return c

func _process(delta: float) -> void:
	_t += delta
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.75
		_stream(false)
		_islands = _islands.filter(func(n): return is_instance_valid(n))
	for n in _islands:
		if not is_instance_valid(n): continue
		n.position.y = float(n.get_meta("base_y")) + sin(_t * 0.6 + float(n.get_meta("bob"))) * 0.6
