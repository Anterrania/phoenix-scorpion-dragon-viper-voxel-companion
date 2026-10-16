class_name ClubFloor
extends Node3D
## v0.7 Radio Club: chill spot with an animated light-up dance floor beside Phoenix Radio.
const PropKit := preload("res://scripts/world/prop_kit.gd")
const N := 6
var tiles: Array = []
var _t := 0.0
func build() -> void:
	name = "RadioClub"
	for x in N:
		for z in N:
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(1.9, 0.2, 1.9)
			m.mesh = bm
			var mt: StandardMaterial3D = PropKit.mat("#ff2fd2", 1.2).duplicate()
			m.material_override = mt
			m.position = Vector3((x - N / 2.0 + 0.5) * 2.0, 0.1, (z - N / 2.0 + 0.5) * 2.0)
			add_child(m); tiles.append(mt)
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
	sh.size = Vector3(N * 2.0, 0.2, N * 2.0); cs.shape = sh; body.add_child(cs); body.position.y = 0.1; add_child(body)
	var s := PropKit.make_sign("Radio Club", "dance floor · DJ nights on Events board")
	s.position = Vector3(N + 1.5, 0, 0); add_child(s)
func _process(delta: float) -> void:
	_t += delta
	for i in tiles.size():
		var h := fposmod(_t * 0.15 + float(i % N) * 0.11 + float(i / N) * 0.07, 1.0)
		tiles[i].albedo_color = Color.from_hsv(h, 0.8, 1.0)
		tiles[i].emission = tiles[i].albedo_color
