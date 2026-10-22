extends SceneTree
## RND bench: greedy vs naive face count on a 32^3 house-like blocky build. Usage: godot --headless --path . -s tools/render/greedy_bench.gd
func _initialize():
	var d := Vector3i(32,32,32)
	var v := PackedByteArray(); v.resize(d.x*d.y*d.z)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	# house-like build: floor slab, 4 walls, 3 materials + 10% random blocks
	for z in d.z: for y in d.y: for x in d.x:
		var m := 0
		if y < 2: m = 1
		elif y < 20 and (x == 2 or x == 29 or z == 2 or z == 29) and x>=2 and x<=29 and z>=2 and z<=29: m = 2
		elif y < 20 and rng.randf() < 0.02: m = 3
		v[GreedyMesher.idx(d,x,y,z)] = m
	var t0 := Time.get_ticks_usec()
	var q := GreedyMesher.mesh_quads(v, d)
	var t1 := Time.get_ticks_usec()
	print("GB naive_faces=", GreedyMesher.naive_face_count(v,d), " greedy_quads=", q.size(), " ms=", (t1-t0)/1000.0)
	quit()
