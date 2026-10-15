extends Node
# Headless smoke tests: godot --headless res://tests/test_runner.tscn
var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond: print("PASS ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)

func _walk(dir: String, ext: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == ext: out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "addons": _walk(dir.path_join(d), ext, out)

func _ready() -> void:
	check(ClassDB.class_exists("VoxelTerrain"), "Voxel Tools extension loaded")
	var scripts: Array = []
	_walk("res://scripts", "gd", scripts)
	for s in scripts:
		var sc: Script = load(s)
		check(sc != null and sc.can_instantiate(), "script loads: " + s)
	var jsons: Array = []
	_walk("res://data", "json", jsons)
	_walk("res://companions", "json", jsons)
	for j in jsons:
		check(JSON.parse_string(FileAccess.get_file_as_string(j)) != null, "json parses: " + j)
	var main = ProjectSettings.get_setting("application/run/main_scene")
	check(load(main) is PackedScene, "main scene loads: " + main)
	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
