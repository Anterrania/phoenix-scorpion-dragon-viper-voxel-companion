class_name WyrmPen
extends Node3D
## v0.6 the Wyrmling Nest near spawn: shows every owned Ember Wyrmling wandering.
signal changed
var list: Array = []
var models := {}
var generator
var _t := 0.0
var _save_t := 0.0

func setup(g) -> void:
	generator = g
	name = "WyrmlingNest"
	var K = PropKit
	K.part(self, K.torus(5.6, 6.0), K.mat("#f2bd3a", 0.8, 1.0, 0.2), Vector3(0, 0.2, 0))
	var s := PropKit.make_sign("Wyrmling Nest", "MENU › Wyrmlings to feed & breed")
	s.position = Vector3(0, 0, 6.5)
	add_child(s)
	list = Wyrmlings.load_all()
	rebuild()

func rebuild() -> void:
	for k in models:
		if is_instance_valid(models[k]): models[k].queue_free()
	models.clear()
	for w in list:
		var m := Wyrmlings.build_model(w)
		add_child(m)
		m.position = Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		models[w["id"]] = m
	changed.emit()

func save() -> void:
	Wyrmlings.save_all(list)

func _process(delta: float) -> void:
	_t += delta
	_save_t += delta
	if _save_t > 30.0:
		_save_t = 0.0
		Wyrmlings.tick_hunger(list, 30.0)
		save()
	var i := 0
	for k in models:
		var m: Node3D = models[k]
		if not is_instance_valid(m): continue
		var a := _t * 0.3 + i * 1.7
		m.position = Vector3(cos(a) * (2.0 + i % 3), absf(sin(_t * 3.0 + i)) * 0.15, sin(a) * (2.0 + i % 3))
		m.rotation.y = -a
		i += 1
	if generator:
		position.y = generator.height_f(global_position.x, global_position.z) if is_inside_tree() else position.y
