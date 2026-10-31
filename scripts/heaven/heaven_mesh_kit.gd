class_name HeavenMeshKit
extends RefCounted
## HEAVEN-1: our own batched mesh builder for Heaven architecture (no imported assets).
## Everything one district needs goes into ONE Batch: up to five surfaces (solid, metal, glow, glass,
## water) = at most five draw calls per district, plus ONE StaticBody3D with a trimesh shape built
## from the solid / metal / glass faces flagged `collide`. Vertex colors carry the palette, so one
## material per layer serves every building. Glow uses HDR albedo (bloom) instead of real lights:
## no per-pixel light cost on phones.
## Shapes: box, cylinder / cone / tube, dome (with arched openings), sphere, torus, gable roof,
## ribbon (roads, bridges, waterways, coaster track), disc / annulus (plazas, canals).

enum { SOLID, METAL, GLOW, GLASS, WATER }
const LAYERS := 5

static var _mats: Array = []

## Shared materials (one per layer, created once).
static func material(layer: int) -> Material:
	if _mats.is_empty():
		var solid := StandardMaterial3D.new()
		solid.vertex_color_use_as_albedo = true
		solid.roughness = 0.62
		solid.metallic_specular = 0.45
		var metal := StandardMaterial3D.new()
		metal.vertex_color_use_as_albedo = true
		metal.metallic = 0.9
		metal.roughness = 0.28
		var glow := ShaderMaterial.new()
		glow.shader = load("res://shaders/heaven_glow.gdshader")
		var glass := StandardMaterial3D.new()
		glass.vertex_color_use_as_albedo = true
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.metallic = 0.35
		glass.roughness = 0.06
		var water := ShaderMaterial.new()
		water.shader = load("res://shaders/heaven_water.gdshader")
		_mats = [solid, metal, glow, glass, water]
	return _mats[layer]

class Batch:
	var v: Array = []        # per layer PackedVector3Array
	var n: Array = []
	var c: Array = []
	var uv: Array = []
	var faces := PackedVector3Array()   # collision triangles
	var tris := 0

	func _init() -> void:
		for i in LAYERS:
			v.append(PackedVector3Array()); n.append(PackedVector3Array())
			c.append(PackedColorArray()); uv.append(PackedVector2Array())

	## One triangle, vertices in Godot's front-face order (clockwise seen from the front).
	func tri(layer: int, a: Vector3, b: Vector3, d: Vector3, col: Color, collide: bool) -> void:
		var nn := (d - a).cross(b - a).normalized()
		v[layer].append_array(PackedVector3Array([a, b, d]))
		n[layer].append_array(PackedVector3Array([nn, nn, nn]))
		c[layer].append_array(PackedColorArray([col, col, col]))
		uv[layer].append_array(PackedVector2Array([Vector2(a.x + a.y, a.z), Vector2(b.x + b.y, b.z), Vector2(d.x + d.y, d.z)]))
		if collide: faces.append_array(PackedVector3Array([a, b, d]))
		tris += 1

	## Quad a-b-c-d listed counter-clockwise when looked at from the side its normal faces.
	func quad(layer: int, a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, collide := true) -> void:
		tri(layer, a, cc, b, col, collide)
		tri(layer, a, d, cc, col, collide)

	## Axis box in the frame `xf` (size = full extents, centred on the local origin).
	func box(xf: Transform3D, size: Vector3, col: Color, layer := SOLID, collide := true) -> void:
		var h := size * 0.5
		var p := func(x: float, y: float, z: float) -> Vector3: return xf * Vector3(x * h.x, y * h.y, z * h.z)
		var P: Array = [p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1),
			p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1)]
		quad(layer, P[4], P[5], P[6], P[7], col, collide)   # +z
		quad(layer, P[1], P[0], P[3], P[2], col, collide)   # -z
		quad(layer, P[5], P[1], P[2], P[6], col, collide)   # +x
		quad(layer, P[0], P[4], P[7], P[3], col, collide)   # -x
		quad(layer, P[7], P[6], P[2], P[3], col, collide)   # +y
		quad(layer, P[0], P[1], P[5], P[4], col, collide)   # -y

	## Box from its bottom-centre (handy for buildings): base at local (x, y, z).
	func block(xf: Transform3D, at: Vector3, size: Vector3, col: Color, layer := SOLID, collide := true) -> void:
		box(xf * Transform3D(Basis(), at + Vector3(0, size.y * 0.5, 0)), size, col, layer, collide)

	## Cylinder / cone / tube along local +y from y=0 to y=h. r1 bottom, r2 top. caps optional.
	func cyl(xf: Transform3D, r1: float, r2: float, h: float, col: Color, layer := SOLID, seg := 16, collide := true, caps := true) -> void:
		for i in seg:
			var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
			var b0 := xf * Vector3(cos(a0) * r1, 0, sin(a0) * r1); var b1 := xf * Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			var t0 := xf * Vector3(cos(a0) * r2, h, sin(a0) * r2); var t1 := xf * Vector3(cos(a1) * r2, h, sin(a1) * r2)
			quad(layer, b1, b0, t0, t1, col, collide)
			if caps:
				if r2 > 0.0: tri(layer, xf * Vector3(0, h, 0), t0, t1, col, collide)
				if r1 > 0.0: tri(layer, xf * Vector3(0, 0, 0), b1, b0, col, collide)

	## Flat disc (y-up) or annulus when r_in > 0, at local y=0, plus an outer skirt of depth `skirt`.
	func disc(xf: Transform3D, r_out: float, col: Color, layer := SOLID, r_in := 0.0, seg := 48, skirt := 0.0, collide := true) -> void:
		for i in seg:
			var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
			var o0 := Vector3(cos(a0), 0, sin(a0)); var o1 := Vector3(cos(a1), 0, sin(a1))
			if r_in <= 0.0: tri(layer, xf * Vector3.ZERO, xf * (o0 * r_out), xf * (o1 * r_out), col, collide)
			else: quad(layer, xf * (o0 * r_in), xf * (o1 * r_in), xf * (o1 * r_out), xf * (o0 * r_out), col, collide)
			if skirt > 0.0:
				quad(layer, xf * (o0 * r_out), xf * (o1 * r_out), xf * (o1 * r_out + Vector3(0, -skirt, 0)), xf * (o0 * r_out + Vector3(0, -skirt, 0)), col, collide)
				if r_in > 0.0:
					quad(layer, xf * (o1 * r_in), xf * (o0 * r_in), xf * (o0 * r_in + Vector3(0, -skirt, 0)), xf * (o1 * r_in + Vector3(0, -skirt, 0)), col, collide)

	## Dome (half ellipsoid) of radius r and height hgt. `openings`: [{angle, width (rad), height (m)}]
	## arch cut-outs at ground level (entrances). Cells inside an opening are skipped.
	func dome(xf: Transform3D, r: float, hgt: float, col: Color, layer := GLASS, seg := 32, rings := 10, openings: Array = [], collide := true) -> void:
		for j in rings:
			var p0 := PI * 0.5 * j / rings; var p1 := PI * 0.5 * (j + 1) / rings
			for i in seg:
				var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
				var skip := false
				var am := (a0 + a1) * 0.5
				var ym := hgt * sin((p0 + p1) * 0.5)
				for o in openings:
					if absf(angle_difference(am, float(o["angle"]))) < float(o["width"]) * 0.5 and ym < float(o["height"]): skip = true
				if skip: continue
				var q := func(a: float, ph: float) -> Vector3: return xf * Vector3(cos(a) * cos(ph) * r, sin(ph) * hgt, sin(a) * cos(ph) * r)
				quad(layer, q.call(a1, p0), q.call(a0, p0), q.call(a0, p1), q.call(a1, p1), col, collide)

	## Sphere (crowns, lamps, ornaments). Never collides (decor).
	func sphere(xf: Transform3D, r: float, col: Color, layer := SOLID, seg := 10, rings := 6) -> void:
		for j in rings:
			var p0 := -PI * 0.5 + PI * j / rings; var p1 := -PI * 0.5 + PI * (j + 1) / rings
			for i in seg:
				var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
				var q := func(a: float, ph: float) -> Vector3: return xf * (Vector3(cos(a) * cos(ph), sin(ph), sin(a) * cos(ph)) * r)
				quad(layer, q.call(a1, p0), q.call(a0, p0), q.call(a0, p1), q.call(a1, p1), col, false)

	## Torus in the local XY plane (portals, sky wheel rims), axis = local z.
	func torus(xf: Transform3D, R: float, r: float, col: Color, layer := GLOW, seg := 32, tube := 6) -> void:
		for i in seg:
			var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
			for j in tube:
				var b0 := TAU * j / tube; var b1 := TAU * (j + 1) / tube
				var q := func(a: float, b: float) -> Vector3:
					return xf * Vector3(cos(a) * (R + r * cos(b)), sin(a) * (R + r * cos(b)), r * sin(b))
				quad(layer, q.call(a0, b0), q.call(a1, b0), q.call(a1, b1), q.call(a0, b1), col, false)

	## Gable roof: ridge along local x, base w (x) by d (z), rise h, at local y=0.
	func gable(xf: Transform3D, w: float, d: float, h: float, col: Color, layer := SOLID) -> void:
		var hw := w * 0.5 + 0.4; var hd := d * 0.5 + 0.4
		var A := xf * Vector3(-hw, 0, hd); var B := xf * Vector3(hw, 0, hd)
		var C := xf * Vector3(hw, 0, -hd); var D := xf * Vector3(-hw, 0, -hd)
		var R0 := xf * Vector3(-hw, h, 0); var R1 := xf * Vector3(hw, h, 0)
		quad(layer, A, B, R1, R0, col)
		quad(layer, C, D, R0, R1, col)
		tri(layer, B, R1, C, col, true)
		tri(layer, D, R0, A, col, true)

	## Ribbon: a deck following `pts` (world space), width w, thickness t. Top + sides + bottom.
	## Returns nothing; collision on top/sides when collide. `rails` adds glow edge strips.
	func ribbon(pts: Array, w: float, t: float, col: Color, layer := SOLID, collide := true, rail_col := Color(0, 0, 0, 0), rail_h := 1.1) -> void:
		for k in pts.size() - 1:
			var a: Vector3 = pts[k]; var b: Vector3 = pts[k + 1]
			var fwd := (b - a); fwd.y = 0.0
			if fwd.length() < 0.001: continue
			var side := fwd.normalized().cross(Vector3.UP) * w * 0.5
			var dn := Vector3(0, -t, 0)
			quad(layer, a - side, a + side, b + side, b - side, col, collide)   # top
			quad(layer, a + side + dn, a - side + dn, b - side + dn, b + side + dn, col, false)   # bottom
			quad(layer, a + side, a + side + dn, b + side + dn, b + side, col, collide)
			quad(layer, a - side + dn, a - side, b - side, b - side + dn, col, collide)
			if rail_col.a > 0.0:
				for sgn in [-1.0, 1.0]:
					var o: Vector3 = side * sgn * 0.98
					var up := Vector3(0, rail_h, 0)
					# glass parapet (collides: nobody walks off a bridge) + glowing handrail line
					quad(GLASS, a + o, b + o, b + o + up, a + o + up, Color(0.85, 0.93, 1.0, 0.22), collide)
					box(Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5 + o + up), Vector3(0.12, 0.08, (b - a).length()), rail_col, GLOW, false)

	## Commit into `parent`: one MeshInstance3D (multi-surface) + one StaticBody3D. Returns the mesh.
	func commit(parent: Node3D, mesh_name: String, vis_end := 0.0) -> MeshInstance3D:
		var am := ArrayMesh.new()
		for layer in LAYERS:
			if (v[layer] as PackedVector3Array).is_empty(): continue
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = v[layer]; arr[Mesh.ARRAY_NORMAL] = n[layer]
			arr[Mesh.ARRAY_COLOR] = c[layer]; arr[Mesh.ARRAY_TEX_UV] = uv[layer]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, HeavenMeshKit.material(layer))
		var mi := MeshInstance3D.new()
		mi.name = mesh_name
		mi.mesh = am
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
			mi.visibility_range_end_margin = 24.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(mi)
		if not faces.is_empty():
			var sb := StaticBody3D.new()
			sb.name = mesh_name + "Body"
			var cs := CollisionShape3D.new()
			var sh := ConcavePolygonShape3D.new()
			sh.backface_collision = true
			sh.set_faces(faces)
			cs.shape = sh
			sb.add_child(cs)
			parent.add_child(sb)
		return mi

## Transform helper: position + yaw (radians) in world space.
static func at(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)

## Points along an arched path from a to b (n segments), rising `arch` metres at the middle.
static func arch_path(a: Vector3, b: Vector3, arch: float, n := 16) -> Array:
	var out: Array = []
	for i in n + 1:
		var t := float(i) / n
		out.append(a.lerp(b, t) + Vector3(0, arch * sin(PI * t), 0))
	return out
