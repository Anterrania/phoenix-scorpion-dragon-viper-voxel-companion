# Headless smoke test: godot --headless --path . -s tests/smoke_test.gd
# Loads each main scene, runs ~600 frames, reports voxel classes, nodes and companion state.
extends SceneTree

const SCENES := ["res://scenes/main_world.tscn", "res://scenes/main.tscn"]
var _i := 0
var _frames := 0
var _scene: Node

func _initialize() -> void:
	print("VoxelTerrain class: ", ClassDB.class_exists("VoxelTerrain"), "  VoxelTool: ", ClassDB.class_exists("VoxelTool"), "  VoxelGeneratorScript: ", ClassDB.class_exists("VoxelGeneratorScript"))
	_load_next()

func _load_next() -> void:
	if _i >= SCENES.size():
		print("SMOKE DONE"); quit(0); return
	var ps: PackedScene = load(SCENES[_i])
	if ps == null:
		print("FAIL load ", SCENES[_i]); _i += 1; _load_next(); return
	_scene = ps.instantiate()
	root.add_child(_scene)
	_frames = 0
	print("Loaded ", SCENES[_i])

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 600 and _scene:
		var t := _scene.get_node_or_null("VoxelTerrain")
		print("  terrain=", t.get_class() if t else "none", " generator=", t.generator if t else null, " mesher=", t.mesher if t else null)
		for n in _scene.find_children("*", "CharacterBody3D", true, false):
			var vt = null
			if n.has_method("_vt"): vt = n._vt()
			var cmd = n.command("build") if n.has_method("command") else null
			var pvt = n.get("_vt") if not n.has_method("_vt") else null
			print("  body ", n.name, " build_cmd=", cmd, " player_vt=", pvt != null, " pos=", n.global_position.snapped(Vector3.ONE * 0.1), " voxel_tool=", vt != null, " on_floor=", n.is_on_floor(), " id=", n.get("companion_id"))
		if t and t.has_method("get_voxel_tool"):
			var tool = t.get_voxel_tool()
			tool.channel = 0
			print("  voxel at (0,0,0)=", tool.get_voxel(Vector3i(0, 0, 0)), " (0,60,0)=", tool.get_voxel(Vector3i(0, 60, 0)))
		_scene.queue_free(); _scene = null
		_i += 1
		_load_next()
	return false
