extends "res://scripts/generators/smooth_terrain_generator.gd"
## HEAVEN-1: the ground world (unchanged, from smooth_terrain_generator) PLUS the Heaven floating
## islands high above it, in the same VoxelLodTerrain, so islands get smooth Transvoxel surfaces,
## LOD and voxel collisions like the ground. Island shapes come from HeavenLayout (shared with
## tests, impostors and the district builder).
## Cost: a block above the ground band that touches no island bounds is filled with air in one call
## (the common case). Island blocks use the same band fill as RND-3: only voxels within `band` of the
## top or underside surface get per-voxel writes; the core is one fill_area_f per column.

var heaven_on := true

func _generate_block(out: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if not heaven_on or origin.y <= int(MAX_H + 4.0):
		super._generate_block(out, origin, lod)
		return
	var size := out.get_size()
	var s := 1 << lod
	var lo3 := Vector3(origin)
	var hi3 := lo3 + Vector3(size) * float(s)
	var pad := Vector3.ONE * maxf(4.0, 2.0 * float(s))   # band reaches past the island bounds
	var hits := HeavenLayout.islands_in(lo3 - pad, hi3 + pad)
	out.fill_f(1.0, CH_SDF)
	if hits.is_empty(): return
	_islands_into(out, origin, s, hits)

func _islands_into(out: VoxelBuffer, origin: Vector3i, s: int, hits: Array) -> void:
	var size := out.get_size()
	var fs := float(s)
	var band := maxf(4.0, 2.0 * fs)
	for lz in size.z:
		for lx in size.x:
			var wx := float(origin.x + lx * s)
			var wz := float(origin.z + lz * s)
			for isl in hits:
				var t := HeavenLayout.top_at(isl, wx, wz)
				if is_nan(t): continue
				var b := HeavenLayout.bottom_at(isl, wx, wz)
				if b >= t + band: continue   # no solid and no crossing near this column
				var ylo := clampi(int(floor((b - band - origin.y) / fs)), 0, size.y)
				var yhi := clampi(int(ceil((t + band - origin.y) / fs)) + 1, 0, size.y)
				# core (fully solid) range, written in one call
				var clo := clampi(int(ceil((b + band - origin.y) / fs)), ylo, yhi)
				var chi := clampi(int(floor((t - band - origin.y) / fs)) + 1, clo, yhi)
				if chi > clo:
					out.fill_area_f(-1.0, Vector3i(lx, clo, lz), Vector3i(lx + 1, chi, lz + 1), CH_SDF)
				for ly in range(ylo, yhi):
					if ly >= clo and ly < chi: continue
					var wy := float(origin.y + ly * s)
					var v := clampf(maxf(wy - t, b - wy) / band, -1.0, 1.0)
					if v < out.get_voxel_f(lx, ly, lz, CH_SDF):
						out.set_voxel_f(v, lx, ly, lz, CH_SDF)

## Reference value for tests: the same field as the band fill, sampled at one point.
func heaven_sdf_at(p: Vector3, lod := 0) -> float:
	var band := maxf(4.0, 2.0 * float(1 << lod))
	var v := 1.0
	for isl in HeavenLayout.islands_in(p - Vector3.ONE * band, p + Vector3.ONE * band):
		var t := HeavenLayout.top_at(isl, p.x, p.z)
		if is_nan(t): continue
		v = minf(v, clampf(maxf(p.y - t, HeavenLayout.bottom_at(isl, p.x, p.z) - p.y) / band, -1.0, 1.0))
	return v
