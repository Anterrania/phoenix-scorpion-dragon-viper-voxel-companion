extends SceneTree
## RND bench (headless): per-LOD generation + Transvoxel meshing time and triangle counts for
## our SDF generator. Usage:
##   ~/tools/godot47 --headless --path . -s tools/render/mesh_bench.gd [-- --opt=0|1 --blocks=N]
## Prints one JSON line per LOD (prefix "BENCH ") so results can be pasted into RENDERING.md.

const BLOCK := 16
const PAD_MIN := 1
const PAD_MAX := 2

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var opt := str(args.get("opt", "1")) == "1"
	var nblocks := int(args.get("blocks", "24"))
	var gen = load("res://scripts/generators/smooth_terrain_generator.gd").new(1337)
	var mesher = ClassDB.instantiate("VoxelMesherTransvoxel")
	mesher.mesh_optimization_enabled = opt
	var size := BLOCK + PAD_MIN + PAD_MAX
	for lod in 6:
		var s := 1 << lod
		var gen_us := 0
		var mesh_us := 0
		var tris := 0
		var trans_tris := 0
		var meshed := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + lod
		for i in nblocks:
			# sample blocks that straddle the surface near spawn (the ones that actually mesh)
			var bx := rng.randi_range(-8, 8) * BLOCK * s
			var bz := rng.randi_range(-8, 8) * BLOCK * s
			var h: float = gen.height_f(float(bx + BLOCK * s / 2), float(bz + BLOCK * s / 2))
			var by := int(floor(h / float(BLOCK * s))) * BLOCK * s
			var origin := Vector3i(bx, by, bz) - Vector3i.ONE * PAD_MIN * s
			var vb = ClassDB.instantiate("VoxelBuffer")
			vb.create(size, size, size)
			var t0 := Time.get_ticks_usec()
			gen._generate_block(vb, origin, lod)
			var t1 := Time.get_ticks_usec()
			var m: Mesh = mesher.build_mesh(vb, [], {})
			var t2 := Time.get_ticks_usec()
			gen_us += t1 - t0
			mesh_us += t2 - t1
			if m == null or m.get_surface_count() == 0: continue
			meshed += 1
			var arr: Array = m.surface_get_arrays(0)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3
			# CUSTOM0.a (bits 16..23) marks vertices that belong to transition meshes
			var c0 = arr[Mesh.ARRAY_CUSTOM0]
			if c0 is PackedFloat32Array and c0.size() > 0:
				var bytes: PackedByteArray = (c0 as PackedFloat32Array).to_byte_array()
				for t in range(0, idx.size(), 3):
					var vi: int = idx[t]
					var bits := bytes.decode_s32((vi * 4 + 3) * 4)
					if ((bits >> 16) & 0xff) != 0: trans_tris += 1
		print("BENCH ", JSON.stringify({"lod": lod, "opt": opt, "blocks": nblocks, "meshed": meshed,
			"gen_ms_per_block": snappedf(gen_us / 1000.0 / nblocks, 0.01),
			"mesh_ms_per_block": snappedf(mesh_us / 1000.0 / nblocks, 0.01),
			"tris_per_meshed_block": (tris / maxi(meshed, 1)),
			"transition_tri_pct": snappedf(100.0 * trans_tris / maxi(tris, 1), 0.1)}))
	quit()
