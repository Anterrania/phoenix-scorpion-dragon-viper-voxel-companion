class_name GreedyMesher
extends RefCounted
## RND-4 greedy meshing for BLOCKY voxel content: player builds, voxel props, and the inactive
## v0.1 blocky path if it is ever re-enabled. (The smooth world uses Transvoxel, where greedy
## meshing does not apply: it outputs triangles along an SDF surface, not axis-aligned faces.)
##
## Technique (public, well known): for each axis and facing, sweep slice by slice, build a 2D
## mask of exposed faces keyed by material, and merge runs into the largest rectangles. Same
## material + same facing + coplanar faces become one quad. Self-written; no third-party code.
##
## Voxels: PackedByteArray of dims.x*dims.y*dims.z, index x + y*dx + z*dx*dy, 0 = air.

static func idx(dims: Vector3i, x: int, y: int, z: int) -> int:
	return x + y * dims.x + z * dims.x * dims.y

static func solid(vox: PackedByteArray, dims: Vector3i, p: Vector3i) -> int:
	if p.x < 0 or p.y < 0 or p.z < 0 or p.x >= dims.x or p.y >= dims.y or p.z >= dims.z: return 0
	return vox[idx(dims, p.x, p.y, p.z)]

## Exposed faces without merging (what a naive face-culling mesher emits). For comparison.
static func naive_face_count(vox: PackedByteArray, dims: Vector3i) -> int:
	var n := 0
	var dirs := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
	for z in dims.z:
		for y in dims.y:
			for x in dims.x:
				if vox[idx(dims, x, y, z)] == 0: continue
				for d in dirs:
					if solid(vox, dims, Vector3i(x, y, z) + d) == 0: n += 1
	return n

## Returns quads: {axis:int 0..2, back:bool, slice:int, u:int, v:int, w:int, h:int, mat:int}
## `slice` is the plane coordinate along `axis`; (u,v) are the other two axes in order.
static func mesh_quads(vox: PackedByteArray, dims: Vector3i) -> Array:
	var quads := []
	for axis in 3:
		var ua := (axis + 1) % 3
		var va := (axis + 2) % 3
		var du := dims[ua]
		var dv := dims[va]
		for back in [false, true]:
			for sl in dims[axis]:
				var mask := PackedInt32Array()
				mask.resize(du * dv)
				for v in dv:
					for u in du:
						var p := Vector3i.ZERO
						p[axis] = sl; p[ua] = u; p[va] = v
						var m := solid(vox, dims, p)
						var q := p
						q[axis] += -1 if back else 1
						mask[u + v * du] = m if (m != 0 and solid(vox, dims, q) == 0) else 0
				# merge rectangles
				for v in dv:
					var u := 0
					while u < du:
						var m := mask[u + v * du]
						if m == 0:
							u += 1
							continue
						var w := 1
						while u + w < du and mask[u + w + v * du] == m: w += 1
						var h := 1
						var grow := true
						while v + h < dv and grow:
							for k in w:
								if mask[u + k + (v + h) * du] != m:
									grow = false; break
							if grow: h += 1
						for hh in h:
							for k in w: mask[u + k + (v + hh) * du] = 0
						quads.append({"axis": axis, "back": back, "slice": sl, "u": u, "v": v, "w": w, "h": h, "mat": m})
						u += w
	return quads

## Builds an ArrayMesh (one surface, vertex colors from `palette[mat]`). 4 verts / 2 tris per quad.
static func build_mesh(vox: PackedByteArray, dims: Vector3i, palette: Dictionary = {}, voxel_size := 1.0) -> ArrayMesh:
	var quads := mesh_quads(vox, dims)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var ids := PackedInt32Array()
	for q in quads:
		var axis: int = q.axis
		var ua := (axis + 1) % 3
		var va := (axis + 2) % 3
		var plane: int = q.slice + (0 if q.back else 1)
		var n := Vector3.ZERO
		n[axis] = -1.0 if q.back else 1.0
		var c: Color = palette.get(q.mat, Color(0.8, 0.8, 0.85))
		var base := verts.size()
		for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var p := Vector3.ZERO
			p[axis] = plane
			p[ua] = q.u + corner.x * q.w
			p[va] = q.v + corner.y * q.h
			verts.append(p * voxel_size); norms.append(n); cols.append(c)
		# winding: Godot front faces are clockwise seen from the normal side
		if q.back: ids.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		else: ids.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var am := ArrayMesh.new()
	if verts.is_empty(): return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = ids
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am
