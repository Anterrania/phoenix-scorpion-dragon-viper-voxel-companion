class_name FoliageScatter
extends Node3D
## RND-5 GPU-instanced ground cover: grass/heather tufts (Alaska), ash pebbles (Venus),
## crystal shards (Cosmic). One MultiMeshInstance3D per biome per 48 m cell, streamed around
## the player, with a visibility range (distance cull) from the tier knob "foliage.range".
## Density from "foliage.density". No collision, no shadows, no textures.
## Placement is a pure function (scatter) so tests check it without a scene.

const CELL := 48.0
const BASE_PER_CELL := 260        # instances per cell at density 1.0
const MAX_SLOPE := 0.55           # skip cliffs (|grad h|)
const KINDS := ["tuft", "pebble", "shard"]
const COLORS := [Color("#5d6e4a"), Color("#3a2a24"), Color("#b48cff")]

var generator
var player: Node3D
var density := 0.6
var view_range := 60.0
var _cells := {}           # Vector2i -> Node3D
var _scan := 0.0
var _meshes := {}          # kind -> Mesh
var _mat: ShaderMaterial

func setup(gen, p: Node3D) -> void:
	generator = gen
	player = p
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/foliage_sway.gdshader")
	for k in KINDS: _meshes[k] = make_mesh(k)

func set_density(d: float) -> void:
	if is_equal_approx(d, density): return
	density = maxf(d, 0.0)
	_rebuild()

func set_view_range(r: float) -> void:
	view_range = maxf(r, 0.0)
	for k in _cells:
		for mmi in _cells[k].get_children():
			(mmi as GeometryInstance3D).visibility_range_end = view_range
	_scan = 0.0

func _rebuild() -> void:
	for k in _cells: if is_instance_valid(_cells[k]): _cells[k].queue_free()
	_cells.clear()
	_scan = 0.0

static func cells_radius(range_m: float) -> int:
	return maxi(1, int(ceil(range_m / CELL)))

## Pure: deterministic candidate points for a cell -> Array of {pos: Vector3, yaw, scale, biome}.
## height_fn(x, z) -> float, biome_fn(x, z) -> int; points under `water` or on steep slopes are dropped.
static func scatter(cell: Vector2i, count: int, height_fn: Callable, biome_fn: Callable, water: float) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, 7177))
	for i in count:
		var x := (cell.x + rng.randf()) * CELL
		var z := (cell.y + rng.randf()) * CELL
		var yaw := rng.randf() * TAU
		var sc := rng.randf_range(0.6, 1.4)
		var h: float = height_fn.call(x, z)
		if h < water + 0.25: continue
		var gx: float = height_fn.call(x + 1.0, z) - h
		var gz: float = height_fn.call(x, z + 1.0) - h
		if Vector2(gx, gz).length() > MAX_SLOPE: continue
		out.append({"pos": Vector3(x, h - 0.05, z), "yaw": yaw, "scale": sc, "biome": int(biome_fn.call(x, z))})
	return out

## Tiny procedural meshes (vertex colours; alpha = sway weight).
static func make_mesh(kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"tuft":   # 3 crossed blades, 6 triangles
			for b in 3:
				var a := b * PI / 3.0
				var d := Vector3(cos(a), 0, sin(a)) * 0.09
				var tip := Vector3(cos(a) * 0.05, 0.42, sin(a) * 0.05)
				st.set_color(Color(0.28, 0.33, 0.2, 0.0)); st.add_vertex(-d)
				st.set_color(Color(0.28, 0.33, 0.2, 0.0)); st.add_vertex(d)
				st.set_color(Color(0.62, 0.66, 0.42, 1.0)); st.add_vertex(tip)
		"pebble":   # flat tetra chip
			var p := [Vector3(-0.12, 0, -0.08), Vector3(0.13, 0, -0.05), Vector3(0.0, 0, 0.13), Vector3(0.01, 0.08, 0.0)]
			for f in [[0, 1, 3], [1, 2, 3], [2, 0, 3]]:
				for i in f:
					st.set_color(Color(0.2, 0.16, 0.15, 0.0)); st.add_vertex(p[i])
		_:   # "shard": thin double pyramid
			var r := 0.05
			var ring := [Vector3(r, 0.12, 0), Vector3(0, 0.12, r), Vector3(-r, 0.12, 0), Vector3(0, 0.12, -r)]
			for i in 4:
				var a2: Vector3 = ring[i]
				var b2: Vector3 = ring[(i + 1) % 4]
				st.set_color(Color(0.55, 0.4, 0.95, 0.0)); st.add_vertex(Vector3.ZERO)
				st.set_color(Color(0.7, 0.55, 1.0, 0.3)); st.add_vertex(a2)
				st.set_color(Color(0.7, 0.55, 1.0, 0.3)); st.add_vertex(b2)
				st.set_color(Color(0.95, 0.85, 1.0, 1.0)); st.add_vertex(Vector3(0, 0.5, 0))
				st.set_color(Color(0.7, 0.55, 1.0, 0.3)); st.add_vertex(b2)
				st.set_color(Color(0.7, 0.55, 1.0, 0.3)); st.add_vertex(a2)
	st.generate_normals()
	return st.commit()

func _fill(cell: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "Foliage_%d_%d" % [cell.x, cell.y]
	add_child(root)
	var g = generator
	var pts := scatter(cell, int(BASE_PER_CELL * density), func(x, z): return g.height_f(x, z),
		func(x, z): return g.biome_at(x, z), float(g.LAVA_LEVEL))
	var by_biome := [[], [], []]
	for p in pts: by_biome[clampi(p.biome, 0, 2)].append(p)
	for b in 3:
		if by_biome[b].is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[KINDS[b]]
		mm.instance_count = by_biome[b].size()
		for i in by_biome[b].size():
			var p: Dictionary = by_biome[b][i]
			var t := Transform3D(Basis(Vector3.UP, p.yaw).scaled(Vector3.ONE * p.scale), p.pos)
			mm.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = view_range
		mmi.visibility_range_end_margin = 4.0
		mmi.set_meta("biome", b)
		root.add_child(mmi)
	return root

func instance_count() -> int:
	var n := 0
	for k in _cells:
		if not is_instance_valid(_cells[k]): continue
		for mmi in _cells[k].get_children(): n += (mmi as MultiMeshInstance3D).multimesh.instance_count
	return n

func draw_count() -> int:
	var n := 0
	for k in _cells: if is_instance_valid(_cells[k]): n += _cells[k].get_child_count()
	return n

func stream(force := false) -> void:
	if player == null or generator == null: return
	if density <= 0.0 or view_range <= 0.0:
		_rebuild(); return
	var c := Vector2i(floori(player.global_position.x / CELL), floori(player.global_position.z / CELL))
	var r := cells_radius(view_range)
	var keep := {}
	var built := 0
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := c + Vector2i(dx, dz)
			keep[k] = true
			if not _cells.has(k) and (force or built < 1):   # at most 1 new cell per scan: no hitch
				_cells[k] = _fill(k); built += 1
	for k in _cells.keys():
		if not keep.has(k):
			if is_instance_valid(_cells[k]): _cells[k].queue_free()
			_cells.erase(k)

func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		stream(false)
