class_name Terraform
extends RefCounted
## v0.9 voxel land tools modelled on the SL/OpenSim viewer "Edit Terrain" tools:
## Raise, Lower, Flatten, Smooth, Roughen (noise), Revert - with brush size + strength.
## Works on the smooth SDF (negative = ground). Pure math in brush_value() so it is testable
## headless; apply() writes through a VoxelTool (VoxelLodTerrain) when available.
const OPS := ["raise", "lower", "flatten", "smooth", "noise", "revert"]
const ICONS := {"raise": "⬆", "lower": "⬇", "flatten": "▬", "smooth": "≈", "noise": "✶", "revert": "↺"}
const MIN_SIZE := 1.0
const MAX_SIZE := 12.0

## New SDF value for one voxel.
## d = sdf now, p = voxel world pos, c = brush centre, size = radius (m), strength 0..1,
## avg = local average SDF (smooth), orig = generator SDF (revert), flat_y = flatten target.
static func brush_value(op: String, d: float, p: Vector3, c: Vector3, size: float, strength: float, avg := 0.0, orig := 0.0, flat_y := 0.0) -> float:
	var r := p.distance_to(c)
	if r > size: return d
	var w := clampf(strength, 0.0, 1.0) * (0.5 + 0.5 * cos(PI * r / size))  # soft falloff
	match op:
		"raise": return d - w * 0.5
		"lower": return d + w * 0.5
		"flatten": return lerpf(d, (p.y - flat_y) / 4.0, w)
		"smooth": return lerpf(d, avg, w)
		"noise": return d + (hash3(p) - 0.5) * w * 0.6
		"revert": return lerpf(d, orig, w)
	return d

static func hash3(p: Vector3) -> float:
	return fposmod(sin(p.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)

## Applies the brush to a VoxelTool (SDF channel). sdf_orig: Callable(Vector3)->float for revert.
static func apply(vt: Object, op: String, c: Vector3, size: float, strength: float, sdf_orig := Callable()) -> int:
	if vt == null or op not in OPS: return 0
	size = clampf(size, MIN_SIZE, MAX_SIZE)
	vt.channel = 1
	var ri := ceili(size)
	var cc := Vector3i(c.round())
	var before := {}
	for z in range(-ri, ri + 1):
		for y in range(-ri, ri + 1):
			for x in range(-ri, ri + 1):
				var q := cc + Vector3i(x, y, z)
				before[q] = vt.get_voxel_f(q)
	var n := 0
	for q in before:
		var p := Vector3(q)
		var avg := 0.0
		if op == "smooth":
			var cnt := 0
			for o in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				avg += float(before.get(q + o, before[q])); cnt += 1
			avg /= cnt
		var orig := float(sdf_orig.call(p)) if sdf_orig.is_valid() else float(before[q])
		var nv := brush_value(op, float(before[q]), p, c, size, strength, avg, orig, c.y)
		if nv != before[q]:
			vt.set_voxel_f(q, clampf(nv, -1.0, 1.0)); n += 1
	return n
