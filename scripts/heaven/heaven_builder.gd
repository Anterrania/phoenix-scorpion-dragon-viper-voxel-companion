class_name HeavenBuilder
extends RefCounted
## HEAVEN-1: turns district piece data (data/heaven/districts/*.json + runtime edits) into geometry.
## One island = one Node3D holding:
##   "Main" batch  (buildings, paving, roads' ends) -> <= 5 draw calls + 1 trimesh body,
##   "Detail" batch (lamps, benches, tables, crates) with a short visibility range (props.range),
##   ride nodes (sky wheel, carousel, coaster train) animated only while awake (Dormancy),
##   Area3D triggers (shops, transit kiosks, casino, portals) and Label3D signs.
## Pieces are placed in the island frame (HeavenLayout.frame): -z faces the Main Mall.
## Rebuilding one island (after a companion edit) frees only that island's node.

const B := preload("res://scripts/heaven/heaven_mesh_kit.gd")
const WALL := 0.35
const DOOR := Vector2(3.2, 3.6)
const C_MARBLE := Color("#ede8de")
const C_PEARL := Color("#f7f5fb")
const C_GOLD := Color("#f0c35a")
const C_SKY := Color("#8fd0ff")
const C_WARM := Color("#ffd9a0")
const C_LEAF := Color("#4f8f3f")
const C_DARKLEAF := Color("#2f6a34")
const C_WOOD := Color("#8a6142")
const C_STONE := Color("#c9c3b8")
const C_GLASS := Color(0.82, 0.92, 1.0, 0.28)
const C_PLAT := Color("#cfd3da")
const DETAIL_TYPES := ["lamp", "bench", "table", "crates", "forklift", "car", "flowerbed"]
## Types a companion may add at runtime (HeavenEdits validates against this).
const EDITABLE := ["lamp", "tree", "cypress", "palm", "bench", "table", "fountain", "column_ring", "sign", "arch",
	"shop", "house", "apartment", "tower", "stall", "cabana", "gazebo", "hedge", "flowerbed", "park", "pool",
	"crates", "car", "flag", "plaza_screen", "glow_tree", "kiosk", "statue"]

## Build one island. Returns {node, shops: [...], kiosks: [...], rides: [...], areas: n, tris: n}.
static func build_island(isl: Dictionary, pieces: Array, paving_col := C_MARBLE) -> Dictionary:
	var root := Node3D.new()
	root.name = "Island_" + str(isl["id"])
	var F := HeavenLayout.frame(isl)
	var main := B.Batch.new()
	var detail := B.Batch.new()
	var out := {"node": root, "shops": [], "kiosks": [], "rides": [], "areas": 0, "tris": 0, "signs": 0}
	# plaza paving (walking surface even before voxel collisions stream in) + gold edge
	var R := float(isl["radius"]) * 0.82
	main.disc(F * Transform3D(Basis(), Vector3(0, 0, 0)), R, paving_col, B.SOLID, 0.0, 64, 0.9)
	main.disc(F * Transform3D(Basis(), Vector3(0, 0.02, 0)), R, C_GOLD, B.METAL, R - 0.6, 64, 0.0, false)
	for p in pieces:
		var t := str(p.get("type", ""))
		var bt: B.Batch = detail if t in DETAIL_TYPES else main
		var G := F * piece_xf(p)
		_piece(bt, G, p, out, root, isl)
	main.commit(root, "Main", 0.0)
	detail.commit(root, "Detail", maxf(RenderPipeline.props_range * 1.6, 110.0))
	out["tris"] = main.tris + detail.tris
	return out

static func piece_xf(p: Dictionary) -> Transform3D:
	var at: Array = p.get("at", [0, 0])
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(p.get("yaw", 0.0)))), Vector3(float(at[0]), float(p.get("y", 0.0)), float(at[1])))

static func _col(p: Dictionary, key: String, def: Color) -> Color:
	var s := str(p.get(key, ""))
	return Color(s) if s != "" and Color.html_is_valid(s) else def

static func _f(p: Dictionary, key: String, def: float) -> float: return float(p.get(key, def))

static func _piece(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D, isl: Dictionary) -> void:
	var w := _f(p, "w", 12.0); var d := _f(p, "d", 10.0); var h := _f(p, "h", 6.0); var r := _f(p, "r", 6.0)
	var col := _col(p, "color", C_PEARL); var trim := _col(p, "trim", C_GOLD)
	match str(p["type"]):
		"lamp":
			b.cyl(G, 0.16, 0.1, 4.6, C_PLAT, B.METAL, 8)
			b.sphere(G * Transform3D(Basis(), Vector3(0, 4.85, 0)), 0.38, C_WARM, B.GLOW, 8, 5)
		"tree":
			b.cyl(G, 0.38, 0.26, h * 0.5, C_WOOD, B.SOLID, 8)
			b.sphere(G * Transform3D(Basis(), Vector3(0, h * 0.62, 0)), h * 0.3, C_LEAF, B.SOLID, 10, 6)
			b.sphere(G * Transform3D(Basis(), Vector3(h * 0.12, h * 0.8, 0.1)), h * 0.2, C_LEAF.lightened(0.12), B.SOLID, 8, 5)
		"cypress":
			b.cyl(G, 0.25, 0.2, 1.2, C_WOOD, B.SOLID, 6)
			b.cyl(G * Transform3D(Basis(), Vector3(0, 1.0, 0)), 1.25, 0.0, h, C_DARKLEAF, B.SOLID, 10)
		"palm":
			b.cyl(G, 0.32, 0.2, h, C_WOOD.lightened(0.15), B.SOLID, 8)
			for k in 7:
				var a := TAU * k / 7.0
				b.box(G * Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.35), Vector3(0, h, 0)) * Transform3D(Basis(), Vector3(0, 0, -2.0)), Vector3(0.9, 0.08, 4.0), C_LEAF, B.SOLID, false)
		"glow_tree":
			b.cyl(G, 0.9, 0.5, h * 0.6, C_PEARL, B.METAL, 12)
			for k in 5:
				b.sphere(G * Transform3D(Basis(), Vector3(cos(k * 1.3) * h * 0.22, h * (0.6 + 0.07 * k), sin(k * 1.3) * h * 0.22)), h * 0.16, Color("#ffe9ff").lerp(C_SKY, k / 5.0), B.GLOW, 10, 6)
		"bench":
			b.block(G, Vector3(0, 0.42, 0), Vector3(2.0, 0.08, 0.55), C_WOOD)
			b.block(G, Vector3(0, 0.5, 0.25), Vector3(2.0, 0.5, 0.06), C_WOOD)
			for sx in [-0.85, 0.85]: b.block(G, Vector3(sx, 0, 0), Vector3(0.08, 0.42, 0.5), C_PLAT, B.METAL)
		"table":
			b.cyl(G, 0.08, 0.08, 0.74, C_PLAT, B.METAL, 6, false)
			b.cyl(G * Transform3D(Basis(), Vector3(0, 0.72, 0)), 0.8, 0.8, 0.04, C_PEARL, B.SOLID, 12)
			b.cyl(G, 0.04, 0.04, 2.3, C_PLAT, B.METAL, 5, false)
			b.cyl(G * Transform3D(Basis(), Vector3(0, 2.0, 0)), 1.7, 0.0, 0.55, Color("#f4d9a6"), B.SOLID, 10, false)
		"fountain":
			b.cyl(G, r, r, 0.8, C_MARBLE, B.SOLID, 24, true, false)
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.8, 0)), r, C_GOLD, B.METAL, r - 0.45, 24)
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.6, 0)), r - 0.45, Color.WHITE, B.WATER, 0.0, 24, 0.0, false)
			b.cyl(G, 0.9, 0.7, h * 0.6, C_MARBLE, B.SOLID, 12)
			b.cyl(G * Transform3D(Basis(), Vector3(0, h * 0.6, 0)), 0.8, 2.4, 0.6, C_MARBLE, B.SOLID, 16, false)
			b.disc(G * Transform3D(Basis(), Vector3(0, h * 0.6 + 0.5, 0)), 2.2, Color.WHITE, B.WATER, 0.0, 16, 0.0, false)
			b.cyl(G * Transform3D(Basis(), Vector3(0, h * 0.6 + 0.5, 0)), 0.12, 0.05, h * 0.4, Color("#bff4ff"), B.GLOW, 6, false)
		"column_ring":
			var n := int(p.get("n", 12))
			for k in n:
				var a := TAU * k / n
				var cx := Transform3D(Basis(), Vector3(cos(a) * r, 0, sin(a) * r))
				b.block(G * cx, Vector3.ZERO, Vector3(1.6, 0.5, 1.6), C_MARBLE)
				b.cyl(G * cx, 0.6, 0.52, h, C_PEARL, B.SOLID, 12)
				b.block(G * cx, Vector3(0, h, 0), Vector3(1.5, 0.45, 1.5), C_GOLD, B.METAL, false)
			b.torus(G * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, h + 0.7, 0)), r, 0.35, C_GOLD, B.METAL, 48, 6)
		"statue":
			b.block(G, Vector3.ZERO, Vector3(2.4, 1.2, 2.4), C_MARBLE)
			b.cyl(G * Transform3D(Basis(), Vector3(0, 1.2, 0)), 0.5, 0.35, 2.2, C_PEARL, B.METAL, 10)
			b.sphere(G * Transform3D(Basis(), Vector3(0, 3.7, 0)), 0.45, C_PEARL, B.METAL)
			b.torus(G * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 4.3, 0)), 0.5, 0.06, C_GOLD, B.GLOW, 16, 4)
		"sign":
			b.block(G, Vector3.ZERO, Vector3(0.5, h - 1.0, 0.5), C_PLAT, B.METAL)
			b.block(G, Vector3(0, h - 1.4, 0), Vector3(7.5, 1.6, 0.25), Color("#1b1630"), B.SOLID, false)
			b.block(G, Vector3(0, h - 1.5, -0.14), Vector3(7.7, 0.08, 0.04), C_SKY, B.GLOW, false)
			_label(root, G * Transform3D(Basis(Vector3.UP, PI), Vector3(0, h - 0.6, -0.2)), str(p.get("text", "")), 64, 260.0)
			_label(root, G * Transform3D(Basis(), Vector3(0, h - 0.6, 0.2)), str(p.get("text", "")), 64, 260.0)
			out["signs"] += 2
		"arch":
			for sx in [-1.0, 1.0]:
				b.block(G, Vector3(sx * w * 0.5, 0, 0), Vector3(1.6, h, 1.6), C_MARBLE)
				b.block(G, Vector3(sx * w * 0.5, h - 0.5, 0), Vector3(1.9, 0.5, 1.9), C_GOLD, B.METAL, false)
			b.block(G, Vector3(0, h, 0), Vector3(w + 2.4, 1.2, 1.8), C_PEARL)
			b.block(G, Vector3(0, h + 0.3, -0.93), Vector3(w + 2.0, 0.12, 0.06), C_SKY, B.GLOW, false)
		"spawn_pad":
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.03, 0)), r, C_PEARL, B.SOLID, 0.0, 32, 0.0, false)
			b.torus(G * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.08, 0)), r, 0.12, C_SKY, B.GLOW, 40, 4)
			b.torus(G * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.08, 0)), r * 0.6, 0.08, C_GOLD, B.GLOW, 32, 4)
		"kiosk":
			b.block(G, Vector3.ZERO, Vector3(1.2, 2.3, 0.7), C_PEARL)
			b.block(G, Vector3(0, 1.0, -0.37), Vector3(0.95, 1.1, 0.04), C_SKY, B.GLOW, false)
			b.block(G, Vector3(0, 2.3, 0), Vector3(1.3, 0.12, 0.8), C_GOLD, B.METAL)
			var kp := G * Vector3(0, 1.2, -1.2)
			out["kiosks"].append(kp)
			_area(root, kp, Vector3(3.0, 2.6, 3.0), {"kind": "transit", "island": isl["id"], "name": "Transit kiosk"})
			out["areas"] += 1
		"car":
			b.block(G, Vector3(0, 0.35, 0), Vector3(1.9, 0.75, 4.4), col if p.has("color") else Color("#e9edf2"), B.METAL)
			b.block(G, Vector3(0, 1.1, 0.25), Vector3(1.7, 0.6, 2.4), C_GLASS, B.GLASS, false)
			b.block(G, Vector3(0, 0.5, -2.21), Vector3(1.6, 0.12, 0.04), C_SKY, B.GLOW, false)
			b.block(G, Vector3(0, 0.12, 0), Vector3(1.6, 0.05, 3.6), C_SKY, B.GLOW, false)
		"canopy":
			for sx in [-0.45, 0.45]:
				for sz in [-0.4, 0.4]: b.cyl(G * Transform3D(Basis(), Vector3(sx * w, 0, sz * d)), 0.3, 0.3, h, C_PLAT, B.METAL, 8)
			b.block(G, Vector3(0, h, 0), Vector3(w, 0.3, d), C_GLASS, B.GLASS)
			b.block(G, Vector3(0, h - 0.1, 0), Vector3(w + 0.4, 0.12, 0.3), C_GOLD, B.METAL, false)
		"tram_platform":
			b.block(G, Vector3(0, 0.03, 0), Vector3(w, 0.02, d), C_STONE, B.SOLID, false)
			for sx in [-0.5, 0.5]: b.block(G, Vector3(sx * w, 0.05, 0), Vector3(0.12, 0.03, d), C_SKY, B.GLOW, false)
			for k in 5: b.cyl(G * Transform3D(Basis(), Vector3(0, 0, -d * 0.4 + k * d * 0.2)), 0.22, 0.22, 4.2, C_PLAT, B.METAL, 8)
			b.block(G, Vector3(0, 4.2, 0), Vector3(w * 0.9, 0.25, d), C_GLASS, B.GLASS, false)
		"park":
			b.block(G, Vector3(0, 0.01, 0), Vector3(w, 0.03, d), Color("#7fb86a"), B.SOLID, false)
			for k in 4: _piece(b, G * Transform3D(Basis(), Vector3((k % 2 - 0.5) * w * 0.6, 0, (floorf(k / 2.0) - 0.5) * d * 0.6)), {"type": "tree", "h": 7.0}, out, root, isl)
			_piece(b, G, {"type": "bench"}, out, root, isl)
		"hedge":
			b.block(G, Vector3.ZERO, Vector3(w, h, d), C_DARKLEAF)
		"flowerbed":
			b.block(G, Vector3.ZERO, Vector3(w, 0.4, d), Color("#6e5236"))
			var rng := RandomNumberGenerator.new(); rng.seed = hash(str(p["id"]))
			for k in 14: b.block(G, Vector3(rng.randf_range(-w, w) * 0.42, 0.4, rng.randf_range(-d, d) * 0.4), Vector3(0.5, 0.35, 0.5), col.lerp(Color.WHITE, rng.randf() * 0.3), B.SOLID, false)
		"gazebo":
			for k in 6:
				var a := TAU * k / 6.0
				b.cyl(G * Transform3D(Basis(), Vector3(cos(a) * r, 0, sin(a) * r)), 0.25, 0.25, h - 1.0, C_PEARL, B.SOLID, 8)
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.03, 0)), r + 0.5, C_MARBLE, B.SOLID, 0.0, 6, 0.0, false)
			b.cyl(G * Transform3D(Basis(), Vector3(0, h - 1.0, 0)), r + 1.0, 0.0, 2.6, C_GOLD, B.METAL, 6)
		"field":
			b.block(G, Vector3(0, 0.01, 0), Vector3(w, 0.03, d), Color("#5fa14d"), B.SOLID, false)
			for sx in [-0.5, 0.0, 0.5]: b.block(G, Vector3(sx * w, 0.045, 0), Vector3(0.15, 0.01, d), Color.WHITE, B.SOLID, false)
			for sx in [-0.5, 0.5]:
				b.block(G, Vector3(sx * (w - 1.0), 0, 0), Vector3(0.12, 2.4, 6.0), C_PLAT, B.METAL)
		"flag":
			b.cyl(G, 0.12, 0.08, h, C_PLAT, B.METAL, 8)
			b.block(G, Vector3(1.6, h - 2.2, 0), Vector3(3.0, 1.9, 0.05), C_SKY, B.GLOW, false)
		"plaza_screen":
			for sx in [-0.5, 0.5]: b.block(G, Vector3(sx * w, 0, 0), Vector3(0.6, h, 0.6), C_PLAT, B.METAL)
			b.block(G, Vector3(0, h * 0.4, 0), Vector3(w, h * 0.6, 0.4), Color("#0c0a14"))
			b.block(G, Vector3(0, h * 0.4 + 0.2, -0.22), Vector3(w - 0.6, h * 0.6 - 0.4, 0.04), Color("#7a5cff"), B.GLOW, false)
		"crates":
			var n := int(h)
			for k in n: b.block(G, Vector3(0, k * 1.2, 0), Vector3(1.2, 1.2, 1.2), Color("#a87b4f").darkened(0.06 * k))
		"forklift":
			b.block(G, Vector3(0, 0.3, 0), Vector3(1.2, 1.2, 2.2), Color("#f0a040"), B.METAL)
			b.block(G, Vector3(0, 0.3, -1.25), Vector3(0.9, 2.8, 0.12), C_PLAT, B.METAL)
			b.block(G, Vector3(0, 0.1, -1.8), Vector3(0.9, 0.06, 1.0), C_PLAT, B.METAL)
		"canal_ring":
			var wd := _f(p, "width", 6.0)
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.04, 0)), r + wd * 0.5, Color.WHITE, B.WATER, r - wd * 0.5, 96, 0.0, false)
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.05, 0)), r + wd * 0.5 + 0.5, C_GOLD, B.METAL, r + wd * 0.5, 96, 0.0, false)
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.05, 0)), r - wd * 0.5, C_GOLD, B.METAL, r - wd * 0.5 - 0.5, 96, 0.0, false)
		"lagoon":
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.05, 0)), r, Color(0.7, 1.0, 1.0), B.WATER, 0.0, 48, 0.0, false)
		"sand":
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.02, 0)), r, Color("#eed9a6"), B.SOLID, 0.0, 48, 0.0, false)
		"boardwalk":
			b.block(G, Vector3(0, 0.02, 0), Vector3(w, 0.03, d), C_WOOD.lightened(0.2), B.SOLID, false)
			for k in int(w / 6.0): b.block(G, Vector3(-w * 0.5 + 3.0 + k * 6.0, 0.05, -d * 0.5), Vector3(0.1, 0.01, 0.1), C_WARM, B.GLOW, false)
		"pool":
			b.block(G, Vector3(0, 0.01, 0), Vector3(w + 1.2, 0.03, d + 1.2), Color("#e8f6f8"), B.SOLID, false)
			b.block(G, Vector3(0, 0.05, 0), Vector3(w, 0.01, d), Color(0.8, 1.0, 1.0), B.WATER, false)
		"cabana":
			for sx in [-1.2, 1.2]:
				for sz in [-1.2, 1.2]: b.cyl(G * Transform3D(Basis(), Vector3(sx, 0, sz)), 0.1, 0.1, 2.6, C_WOOD, B.SOLID, 6)
			b.gable(G * Transform3D(Basis(), Vector3(0, 2.6, 0)), 2.8, 2.8, 1.0, Color("#f7efe0"))
			b.block(G, Vector3(0, 0.3, 0), Vector3(1.8, 0.3, 1.8), Color("#ffffff"), B.SOLID, false)
		"lifeguard":
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]: b.block(G, Vector3(sx, 0, sz), Vector3(0.2, 3.0, 0.2), C_WOOD)
			b.block(G, Vector3(0, 3.0, 0), Vector3(2.6, 2.0, 2.6), Color("#ff5a4a"))
			b.gable(G * Transform3D(Basis(), Vector3(0, 5.0, 0)), 2.6, 2.6, 1.0, C_PEARL)
		"halo":
			b.disc(G * Transform3D(Basis(), Vector3(0, 0.03, 0)), r * 0.5, Color("#f0ecff"), B.SOLID, 0.0, 48, 0.0, false)
			b.torus(G * Transform3D(Basis(), Vector3(0, r * 0.6 + 2.0, 0)), r * 0.6, 0.6, Color("#e7dcff"), B.GLOW, 64, 8)
			b.torus(G * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, r * 0.6 + 2.0, 0)), r * 0.5, 0.3, C_GOLD, B.GLOW, 64, 6)
		"dome": _dome(b, G, p, out, root, isl)
		"shop": _shop(b, G, p, out, root, isl)
		"house": _house(b, G, p, out, root)
		"apartment": _apartment(b, G, p, out, root)
		"tower": _tower(b, G, p, out, root)
		"terminal": _terminal(b, G, p, out, root, isl)
		"pavilion": _pavilion(b, G, p)
		"stall": _stall(b, G, p, out, root)
		"casino_hall": _casino(b, G, p, out, root, isl)
		"pool_hall": _pool_hall(b, G, p)
		"warehouse": _warehouse(b, G, p)
		"classroom_wing": _classrooms(b, G, p)
		"wheel", "carousel", "coaster": out["rides"].append({"piece": p, "xf": G})
		_: pass

# ---------- enterable shells ----------
## Walls + roof with a door gap in the front (-z) wall. Returns nothing; interior is open.
static func shell(b: B.Batch, G: Transform3D, w: float, d: float, h: float, col: Color, trim: Color, door := DOOR, glass_front := false, ceiling := 4.6) -> void:
	var t := WALL
	b.block(G, Vector3(0, 0.01, 0), Vector3(w - 2 * t, 0.02, d - 2 * t), col.darkened(0.08), B.SOLID, false)   # interior floor finish
	b.block(G, Vector3(0, 0, d * 0.5 - t * 0.5), Vector3(w, h, t), col)                     # back
	b.block(G, Vector3(-w * 0.5 + t * 0.5, 0, 0), Vector3(t, h, d - 2 * t), col)              # left
	b.block(G, Vector3(w * 0.5 - t * 0.5, 0, 0), Vector3(t, h, d - 2 * t), col)               # right
	var seg := (w - door.x) * 0.5
	var fz := -d * 0.5 + t * 0.5
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (door.x * 0.5 + seg * 0.5)
		if glass_front:
			b.block(G, Vector3(cx, 0, fz), Vector3(seg, 0.6, t), col)
			b.block(G, Vector3(cx, 0.6, fz), Vector3(seg, minf(h, ceiling) - 0.6, 0.08), C_GLASS, B.GLASS)
			if h > ceiling: b.block(G, Vector3(cx, ceiling, fz), Vector3(seg, h - ceiling, t), col)
		else:
			b.block(G, Vector3(cx, 0, fz), Vector3(seg, h, t), col)
	b.block(G, Vector3(0, door.y, fz), Vector3(door.x, h - door.y, t), col)                  # lintel
	# door frame
	for sx in [-1.0, 1.0]: b.block(G, Vector3(sx * (door.x * 0.5 + 0.08), 0, fz - t * 0.5 - 0.02), Vector3(0.16, door.y, 0.06), trim, B.METAL, false)
	b.block(G, Vector3(0, door.y, fz - t * 0.5 - 0.02), Vector3(door.x + 0.32, 0.16, 0.06), trim, B.METAL, false)
	# roof + cornice
	b.block(G, Vector3(0, h, 0), Vector3(w + 0.5, 0.4, d + 0.5), col.darkened(0.05))
	b.block(G, Vector3(0, h + 0.1, 0), Vector3(w + 0.9, 0.24, d + 0.9), trim, B.METAL, false)
	# ground floor ceiling (keeps interiors human-scale) + light panel
	if h > ceiling + 1.0: b.block(G, Vector3(0, ceiling, 0), Vector3(w - 2 * t, 0.3, d - 2 * t), col.darkened(0.12))
	var ch := minf(h, ceiling) - 0.06
	b.block(G, Vector3(0, ch, 0), Vector3((w - 2 * t) * 0.6, 0.05, (d - 2 * t) * 0.6), C_WARM, B.GLOW, false)
	# window bands on the three solid sides (emissive, no real lights)
	var floors := maxi(1, int(h / 4.0))
	for f in floors:
		var y := 1.4 + f * 4.0
		if y + 1.4 > h - 0.4: break
		var wc := C_WARM.darkened(0.25 + 0.08 * (f % 3))
		b.block(G, Vector3(0, y, d * 0.5 + 0.02), Vector3(w * 0.8, 1.3, 0.04), wc, B.GLOW, false)
		b.block(G, Vector3(-w * 0.5 - 0.02, y, 0), Vector3(0.04, 1.3, d * 0.7), wc, B.GLOW, false)
		b.block(G, Vector3(w * 0.5 + 0.02, y, 0), Vector3(0.04, 1.3, d * 0.7), wc, B.GLOW, false)
		if f > 0: b.block(G, Vector3(0, y, -d * 0.5 - 0.02), Vector3(w * 0.8, 1.3, 0.04), wc, B.GLOW, false)

static func _shop(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D, isl: Dictionary) -> void:
	var w := _f(p, "w", 16.0); var d := _f(p, "d", 14.0); var h := _f(p, "h", 8.0)
	var col := _col(p, "color", C_PEARL); var trim := _col(p, "trim", C_GOLD)
	shell(b, G, w, d, h, col, trim, Vector2(4.0, 3.6), true)
	var s := HeavenShops.shop(str(p.get("shop", "")))
	var cat := str(s.get("category", "clothes"))
	_interior(b, G, w, d, cat, str(p.get("shop", "")))
	_label(root, G * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 4.6, -d * 0.5 - 0.3)), str(s.get("name", p.get("name", "Shop"))), 56, 120.0)
	b.block(G, Vector3(0, 4.1, -d * 0.5 - 0.1), Vector3(minf(w - 1.0, 9.0), 1.0, 0.12), Color("#1b1630"), B.SOLID, false)
	b.block(G, Vector3(0, 4.05, -d * 0.5 - 0.18), Vector3(minf(w - 1.0, 9.0), 0.06, 0.04), trim, B.GLOW, false)
	out["signs"] += 1
	var ap := G * Vector3(0, 1.6, 0)
	_area(root, ap, Vector3(w - 1.4, 3.0, d - 1.4), {"kind": "shop", "shop": str(p.get("shop", "")), "island": isl["id"], "name": str(s.get("name", "Shop"))}, G.basis)
	out["shops"].append({"shop": str(p.get("shop", "")), "pos": G * Vector3(0, 0, -d * 0.5 - 2.0)})
	out["areas"] += 1

## Shop fittings by category: racks of colour, shoe walls, salon chairs + mirrors, glow pedestals.
static func _interior(b: B.Batch, G: Transform3D, w: float, d: float, cat: String, seed_id: String) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(seed_id)
	var palette := [Color("#f4efe6"), Color("#9fc4ec"), Color("#141018"), Color("#ffe7b8"), Color("#ff7ac0"), Color("#5ad8ff"), Color("#c99a2e")]
	b.block(G, Vector3(0, 0, d * 0.5 - 1.6), Vector3(4.0, 1.05, 1.0), Color("#2a2238"))   # counter
	b.block(G, Vector3(0, 1.05, d * 0.5 - 1.6), Vector3(4.1, 0.06, 1.1), C_GOLD, B.METAL, false)
	var depth := d - 4.5
	match cat:
		"shoes":
			for sx in [-1.0, 1.0]:
				for k in 4:
					var y := 0.5 + k * 0.55
					b.block(G, Vector3(sx * (w * 0.5 - 0.7), y, -0.5), Vector3(0.7, 0.05, depth), C_PEARL, B.SOLID, false)
					for j in int(depth / 0.9):
						b.block(G, Vector3(sx * (w * 0.5 - 0.7), y + 0.05, -0.5 - depth * 0.5 + 0.45 + j * 0.9), Vector3(0.32, 0.16, 0.5), palette[rng.randi() % palette.size()], B.SOLID, false)
			b.cyl(G * Transform3D(Basis(), Vector3(0, 0, -1.0)), 1.0, 1.0, 0.45, C_PEARL, B.SOLID, 16)   # try-on seat
		"hair":
			for k in 3:
				var z := -depth * 0.35 + k * depth * 0.35
				for sx in [-1.0, 1.0]:
					b.block(G, Vector3(sx * (w * 0.5 - 0.4), 0.9, z), Vector3(0.06, 1.6, 1.0), C_GLASS.lightened(0.4), B.GLASS, false)   # mirror
					b.block(G, Vector3(sx * (w * 0.5 - 1.5), 0, z), Vector3(0.7, 0.55, 0.7), Color("#2a2238"))   # chair
					b.block(G, Vector3(sx * (w * 0.5 - 1.8), 0.55, z), Vector3(0.12, 0.6, 0.7), Color("#2a2238"), B.SOLID, false)
		"looks", "info":
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				var pp := Vector3(cos(a) * w * 0.22, 0, sin(a) * depth * 0.25 - 0.5)
				b.cyl(G * Transform3D(Basis(), pp), 0.55, 0.45, 1.0, C_PEARL, B.SOLID, 12)
				b.sphere(G * Transform3D(Basis(), pp + Vector3(0, 1.35, 0)), 0.3, palette[k + 2], B.GLOW, 8, 5)
		_:   # clothes, accessories, all: hanging racks + mannequins
			for sx in [-1.0, 1.0]:
				b.block(G, Vector3(sx * (w * 0.5 - 0.9), 1.75, -0.5), Vector3(0.06, 0.06, depth), C_PLAT, B.METAL, false)
				for j in int(depth / 0.45):
					b.block(G, Vector3(sx * (w * 0.5 - 0.9), 0.7, -0.5 - depth * 0.5 + 0.25 + j * 0.45), Vector3(0.55, 1.0, 0.08), palette[rng.randi() % palette.size()], B.SOLID, false)
			for k in 3:
				var mp := Vector3(-w * 0.2 + k * w * 0.2, 0, -d * 0.5 + 2.2)
				b.cyl(G * Transform3D(Basis(), mp), 0.35, 0.35, 0.12, C_GOLD, B.METAL, 10)
				b.cyl(G * Transform3D(Basis(), mp + Vector3(0, 0.12, 0)), 0.2, 0.28, 1.45, palette[rng.randi() % palette.size()], B.SOLID, 10, false)
				b.sphere(G * Transform3D(Basis(), mp + Vector3(0, 1.75, 0)), 0.15, C_PEARL)

static func _house(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D) -> void:
	var w := _f(p, "w", 12.0); var d := _f(p, "d", 10.0); var h := _f(p, "h", 6.0)
	var col := _col(p, "color", C_PEARL); var roof := _col(p, "trim", Color("#7a4a3a"))
	shell(b, G, w, d, h, col, C_PLAT, DOOR, false, h)
	b.gable(G * Transform3D(Basis(), Vector3(0, h + 0.2, 0)), w, d, 3.2, roof)
	b.block(G, Vector3(0, 0, -d * 0.5 - 3.0), Vector3(2.0, 0.02, 5.4), C_STONE, B.SOLID, false)   # path
	for sx in [-1.0, 1.0]: b.block(G, Vector3(sx * (w * 0.5 + 0.8), 0, 0), Vector3(0.6, 1.0, d + 4.0), C_DARKLEAF)   # yard hedges

static func _apartment(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D) -> void:
	var w := _f(p, "w", 22.0); var d := _f(p, "d", 26.0); var h := _f(p, "h", 28.0)
	shell(b, G, w, d, h, _col(p, "color", C_MARBLE), _col(p, "trim", C_GOLD), Vector2(4.0, 3.8), true)
	for f in range(1, int(h / 4.0)):   # balconies
		b.block(G, Vector3(0, f * 4.0, -d * 0.5 - 0.7), Vector3(w * 0.7, 0.18, 1.4), C_PEARL, B.SOLID, false)
		b.block(G, Vector3(0, f * 4.0 + 0.18, -d * 0.5 - 1.38), Vector3(w * 0.7, 1.0, 0.04), C_GLASS, B.GLASS, false)

static func _tower(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D) -> void:
	var w := _f(p, "w", 24.0); var d := _f(p, "d", 24.0); var h := _f(p, "h", 60.0)
	var col := _col(p, "color", Color("#9fb7cc")); var trim := _col(p, "trim", C_SKY)
	shell(b, G, w, d, 6.0, C_MARBLE, trim, Vector2(5.0, 4.0), true, 5.6)   # enterable lobby
	b.block(G, Vector3(0, 6.2, 0), Vector3(w - 1.0, h - 6.2, d - 1.0), col.darkened(0.35))   # core
	b.block(G, Vector3(0, 6.2, 0), Vector3(w, h - 6.2, d), Color(col.r, col.g, col.b, 0.42), B.GLASS, false)   # curtain wall
	var floors := int((h - 6.2) / 4.0)
	for f in floors:
		if f % 2 == 1: continue
		var y := 6.2 + f * 4.0 + 1.0
		var wc := C_WARM.darkened(0.35 + 0.1 * (floori(f / 2.0) % 3))
		b.block(G, Vector3(0, y, -d * 0.5 + 0.48), Vector3(w * 0.85, 1.2, 0.04), wc, B.GLOW, false)
		b.block(G, Vector3(0, y, d * 0.5 - 0.48), Vector3(w * 0.85, 1.2, 0.04), wc, B.GLOW, false)
	b.block(G, Vector3(0, h, 0), Vector3(w + 0.4, 0.6, d + 0.4), C_PLAT, B.METAL)
	b.block(G, Vector3(0, h + 0.6, 0), Vector3(w * 0.4, 3.0, d * 0.4), col)
	b.cyl(G * Transform3D(Basis(), Vector3(0, h + 3.6, 0)), 0.2, 0.05, 8.0, C_PLAT, B.METAL, 6, false)
	b.sphere(G * Transform3D(Basis(), Vector3(0, h + 11.8, 0)), 0.4, Color("#ff5a5a"), B.GLOW, 6, 4)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]: b.block(G, Vector3(sx * w * 0.5, 6.2, sz * d * 0.5), Vector3(0.2, h - 6.2, 0.2), trim, B.GLOW, false)

static func _terminal(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D, isl: Dictionary) -> void:
	var w := _f(p, "w", 64.0); var d := _f(p, "d", 30.0); var h := _f(p, "h", 16.0)
	shell(b, G, w, d, h, C_PEARL, C_GOLD, Vector2(10.0, 6.0), true, h)
	# sweeping glass vault over the hall
	for k in 9:
		var x := -w * 0.4 + k * w * 0.1
		b.block(G, Vector3(x, h + 0.3, 0), Vector3(0.4, 2.6, d + 1.0), C_GOLD, B.METAL, false)
	b.block(G, Vector3(0, h + 0.3, 0), Vector3(w * 0.85, 2.4, d - 2.0), C_GLASS, B.GLASS, false)
	# departure boards + kiosks inside
	b.block(G, Vector3(0, 4.0, d * 0.5 - 0.5), Vector3(18.0, 3.0, 0.2), Color("#0c0a14"))
	b.block(G, Vector3(0, 4.2, d * 0.5 - 0.62), Vector3(17.0, 2.5, 0.04), C_SKY, B.GLOW, false)
	for x in [-18.0, -6.0, 6.0, 18.0]:
		_piece(b, G * Transform3D(Basis(Vector3.UP, PI), Vector3(x, 0, d * 0.5 - 5.0)), {"type": "kiosk"}, out, root, isl)
	for k in 6: _piece(b, G * Transform3D(Basis(), Vector3(-15.0 + k * 6.0, 0, 0)), {"type": "bench"}, out, root, isl)
	_label(root, G * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 7.4, -d * 0.5 - 0.3)), str(p.get("name", "Transportation Hub")), 96, 260.0)
	out["signs"] += 1

static func _pavilion(b: B.Batch, G: Transform3D, p: Dictionary) -> void:
	var w := _f(p, "w", 48.0); var d := _f(p, "d", 30.0); var h := _f(p, "h", 9.0)
	for i in 7:
		for j in 2:
			b.cyl(G * Transform3D(Basis(), Vector3(-w * 0.5 + i * w / 6.0, 0, (j - 0.5) * d)), 0.45, 0.4, h, C_PEARL, B.SOLID, 12)
	b.block(G, Vector3(0, h, 0), Vector3(w + 2.0, 0.6, d + 2.0), _col(p, "color", C_PEARL))
	b.block(G, Vector3(0, h + 0.6, 0), Vector3(w * 0.6, 1.6, d * 0.6), C_GLASS, B.GLASS, false)
	b.block(G, Vector3(0, h - 0.1, 0), Vector3(w + 2.2, 0.2, d + 2.2), _col(p, "trim", C_GOLD), B.METAL, false)
	b.block(G, Vector3(0, h - 0.4, 0), Vector3(w * 0.8, 0.05, d * 0.7), C_WARM, B.GLOW, false)

static func _stall(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D) -> void:
	var col := _col(p, "color", Color("#ff9a5a"))
	b.block(G, Vector3.ZERO, Vector3(5.0, 1.1, 2.0), C_PEARL)
	b.block(G, Vector3(0, 1.1, 0), Vector3(5.2, 0.08, 2.2), C_WOOD)
	b.block(G, Vector3(0, 0, 1.6), Vector3(5.0, 3.0, 0.3), C_PEARL)
	for sx in [-2.4, 2.4]: b.block(G, Vector3(sx, 0, 0.3), Vector3(0.15, 3.0, 0.15), C_PLAT, B.METAL)
	b.box(G * Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(0, 3.1, 0.0)), Vector3(5.6, 0.1, 2.8), col, B.SOLID, false)   # awning
	b.block(G, Vector3(0, 2.4, -1.15), Vector3(4.0, 0.5, 0.06), col.lightened(0.3), B.GLOW, false)
	_label(root, G * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 2.65, -1.25)), str(p.get("name", "")), 40, 70.0)
	out["signs"] += 1

static func _casino(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D, isl: Dictionary) -> void:
	var w := _f(p, "w", 60.0); var d := _f(p, "d", 40.0); var h := _f(p, "h", 18.0)
	var trim := _col(p, "trim", C_GOLD)
	shell(b, G, w, d, h, _col(p, "color", Color("#1c1426")), trim, Vector2(8.0, 5.0), true, 7.0)
	for k in 6: b.block(G, Vector3(-w * 0.5 + 0.1, 2.0 + k * 2.4, 0), Vector3(0.1, 0.25, d * 0.9), [C_GOLD, Color("#ff2fd0"), C_SKY][k % 3], B.GLOW, false)
	for k in 6: b.block(G, Vector3(w * 0.5 - 0.1, 2.0 + k * 2.4, 0), Vector3(0.1, 0.25, d * 0.9), [C_GOLD, Color("#ff2fd0"), C_SKY][k % 3], B.GLOW, false)
	# free-play cabinets (rows) + wheel stage
	for row in 3:
		for k in 8:
			var cp := Vector3(-w * 0.35 + k * w * 0.1, 0, -d * 0.2 + row * 5.0)
			b.block(G, cp, Vector3(1.1, 1.9, 0.9), Color("#2a2238"))
			b.block(G, cp + Vector3(0, 1.1, -0.47), Vector3(0.8, 0.6, 0.04), [Color("#ff2fd0"), C_SKY, C_GOLD][(k + row) % 3], B.GLOW, false)
	b.cyl(G * Transform3D(Basis(), Vector3(0, 0, d * 0.5 - 6.0)), 4.0, 4.0, 0.5, C_GOLD, B.METAL, 24)
	b.torus(G * Transform3D(Basis(), Vector3(0, 4.5, d * 0.5 - 6.0)), 3.2, 0.25, C_GOLD, B.GLOW, 32, 6)
	_area(root, G * Vector3(0, 1.6, 0), Vector3(w - 2.0, 3.0, d - 2.0), {"kind": "casino", "island": isl["id"], "name": "Celestial Casino (free play)"}, G.basis)
	out["areas"] += 1

static func _pool_hall(b: B.Batch, G: Transform3D, p: Dictionary) -> void:
	var w := _f(p, "w", 64.0); var d := _f(p, "d", 48.0); var h := _f(p, "h", 10.0)
	var tile := _col(p, "color", Color("#f1f7f8"))
	# open arcades on all sides: columns + arches, three pool rooms inside
	for i in 9:
		for side in [-1.0, 1.0]:
			b.block(G, Vector3(-w * 0.5 + i * w / 8.0, 0, side * d * 0.5), Vector3(1.2, h, 1.2), tile)
	for j in 7:
		for side in [-1.0, 1.0]:
			b.block(G, Vector3(side * w * 0.5, 0, -d * 0.5 + j * d / 6.0), Vector3(1.2, h, 1.2), tile)
	b.block(G, Vector3(0, h, 0), Vector3(w + 1.2, 0.8, d + 1.2), tile)
	b.block(G, Vector3(0, h - 0.1, 0), Vector3(w * 0.9, 0.05, d * 0.9), Color("#dffaff"), B.GLOW, false)
	for k in 3:
		var px := -w * 0.3 + k * w * 0.3
		b.block(G, Vector3(px, 0.01, 0), Vector3(w * 0.26, 0.03, d * 0.7), Color("#e8f6f8"), B.SOLID, false)
		b.block(G, Vector3(px, 0.05, 0), Vector3(w * 0.22, 0.01, d * 0.62), Color(0.8, 1.0, 1.0), B.WATER, false)
		b.block(G, Vector3(px, 0, d * 0.4), Vector3(1.0, h, 1.0), tile)
	b.block(G, Vector3(0, h * 0.6, 0), Vector3(w * 0.8, 0.2, 0.6), _col(p, "trim", C_SKY), B.GLOW, false)

static func _warehouse(b: B.Batch, G: Transform3D, p: Dictionary) -> void:
	var w := _f(p, "w", 30.0); var d := _f(p, "d", 22.0); var h := _f(p, "h", 12.0)
	shell(b, G, w, d, h, _col(p, "color", Color("#b9b2a6")), _col(p, "trim", Color("#f0a040")), Vector2(7.0, 6.0), false, h)
	b.block(G, Vector3(0, 6.0, -d * 0.5 - 0.05), Vector3(7.0, 0.3, 0.08), Color("#f0a040"), B.GLOW, false)
	for k in 4:   # pallet racks inside
		var z := -d * 0.3 + k * d * 0.2
		for sx in [-1.0, 1.0]:
			b.block(G, Vector3(sx * (w * 0.5 - 2.0), 0, z), Vector3(2.4, 4.0, 1.2), Color("#6a7684"), B.METAL)
			b.block(G, Vector3(sx * (w * 0.5 - 2.0), 1.2, z), Vector3(2.0, 1.0, 1.0), Color("#a87b4f"), B.SOLID, false)

static func _classrooms(b: B.Batch, G: Transform3D, p: Dictionary) -> void:
	var w := _f(p, "w", 46.0); var d := _f(p, "d", 16.0); var h := _f(p, "h", 9.0)
	var rooms := int(p.get("rooms", 4))
	shell(b, G, w, d, h, _col(p, "color", Color("#f2ebe0")), _col(p, "trim", Color("#3e6fb0")), Vector2(4.0, 3.6), true, 4.4)
	# corridor along the front, classrooms behind partition walls with doors
	var rw := (w - 2.0 * WALL) / rooms
	for k in range(1, rooms):
		var x := -w * 0.5 + WALL + k * rw
		b.block(G, Vector3(x, 0, 1.5), Vector3(0.2, 4.4, d - 3.0 - 2 * WALL), Color("#e6dfd2"))
	for k in rooms:
		var cx := -w * 0.5 + WALL + (k + 0.5) * rw
		# corridor wall with a door per room
		b.block(G, Vector3(cx - rw * 0.3, 0, -d * 0.5 + 3.0), Vector3(rw * 0.4 - 0.2, 4.4, 0.2), Color("#e6dfd2"))
		b.block(G, Vector3(cx + rw * 0.3, 0, -d * 0.5 + 3.0), Vector3(rw * 0.4 - 0.2, 4.4, 0.2), Color("#e6dfd2"))
		b.block(G, Vector3(cx, 2.6, -d * 0.5 + 3.0), Vector3(rw * 0.2 + 0.2, 1.8, 0.2), Color("#e6dfd2"))
		b.block(G, Vector3(cx, 1.2, d * 0.5 - WALL - 0.06), Vector3(rw * 0.6, 1.4, 0.04), Color("#244a3a"), B.SOLID, false)   # chalkboard
		for i in 3:
			for j in 3:
				b.block(G, Vector3(cx - rw * 0.25 + i * rw * 0.25, 0, -d * 0.5 + 5.0 + j * 2.0), Vector3(1.0, 0.75, 0.6), C_WOOD.lightened(0.2))

static func _dome(b: B.Batch, G: Transform3D, p: Dictionary, out: Dictionary, root: Node3D, isl: Dictionary) -> void:
	var r := _f(p, "r", 75.0); var h := _f(p, "h", 48.0)
	var doors := int(p.get("doors", 4))
	var openings: Array = []
	for k in doors: openings.append({"angle": TAU * k / doors, "width": 16.0 / r, "height": 10.0})
	b.dome(G, r, h, Color(0.85, 0.93, 1.0, 0.2), B.GLASS, 40, 12, openings)
	# gold ribs (meridians) and two latitude rings
	for k in 20:
		var a := TAU * k / 20.0
		var skip := false
		for o in openings:
			if absf(angle_difference(a, float(o["angle"]))) < float(o["width"]) * 0.5: skip = true
		for j in 12:
			var p0 := PI * 0.5 * j / 12.0; var p1 := PI * 0.5 * (j + 1) / 12.0
			if skip and h * sin(p1) < 10.5: continue
			var q0 := Vector3(cos(a) * cos(p0) * r, sin(p0) * h, sin(a) * cos(p0) * r)
			var q1 := Vector3(cos(a) * cos(p1) * r, sin(p1) * h, sin(a) * cos(p1) * r)
			b.box(G * Transform3D(Basis.looking_at((q1 - q0).normalized(), Vector3(cos(a), 0, sin(a))), (q0 + q1) * 0.5), Vector3(0.35, 0.35, (q1 - q0).length() + 0.1), C_GOLD, B.METAL, false)
	for ph in [0.35, 0.8]:
		b.torus(G * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, sin(ph) * h, 0)), cos(ph) * r, 0.3, C_GOLD, B.METAL, 64, 4)
	b.sphere(G * Transform3D(Basis(), Vector3(0, h + 0.6, 0)), 2.2, C_GOLD, B.METAL, 12, 6)
	b.torus(G * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.25, 0)), r, 0.5, C_MARBLE, B.SOLID, 64, 4)
	# entrance portals: glowing arch frames
	for o in openings:
		var a: float = o["angle"]
		var e := G * Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(cos(a) * r, 0, sin(a) * r))
		for sx in [-1.0, 1.0]: b.block(e, Vector3(sx * 8.0, 0, 0), Vector3(1.2, 10.5, 1.2), C_PEARL)
		b.block(e, Vector3(0, 10.0, 0), Vector3(17.6, 1.2, 1.4), C_PEARL)
		b.block(e, Vector3(0, 9.9, -0.72), Vector3(15.0, 0.12, 0.05), C_SKY, B.GLOW, false)
	b.block(G, Vector3(0, h * 0.95, 0), Vector3(r * 0.3, 0.05, r * 0.3), Color("#fff4dc"), B.GLOW, false)

# ---------- helpers ----------
static func _label(root: Node3D, xf: Transform3D, text: String, size := 64, range_end := 200.0) -> Label3D:
	var l := Label3D.new()
	l.name = "HeavenSign"
	l.text = text
	l.font_size = size
	l.pixel_size = 0.012
	l.outline_size = 10
	l.modulate = Color("#fff6e0")
	l.outline_modulate = Color(0.08, 0.05, 0.12, 0.9)
	l.visibility_range_end = range_end
	l.double_sided = false
	l.visible = FloatingText.enabled()
	root.add_child(l)
	l.transform = xf   # island roots sit at the world origin, so local == world
	return l

## Trigger volume (meta "heaven" = info dict). Monitoring only (no physics cost on idle bodies).
static func _area(root: Node3D, pos: Vector3, size: Vector3, info: Dictionary, basis := Basis()) -> Area3D:
	var a := Area3D.new()
	a.name = "Trigger_" + str(info.get("kind", "x"))
	a.monitorable = false
	a.set_meta("heaven", info)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs
	a.add_child(cs)
	a.transform = Transform3D(basis.orthonormalized(), pos)
	root.add_child(a)
	return a
