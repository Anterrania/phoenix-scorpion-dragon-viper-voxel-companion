class_name WelcomeIsland
extends Node3D
## v0.7 Welcome Island: floating orientation island with a guided station path, two guide bots
## (Welcome Guide, Help Desk) and FAQ lookup. Original design; data in data/welcome/.
const DATA := "res://data/welcome/welcome_island.json"
const FAQ := "res://data/welcome/help_faq.json"
const PropKit := preload("res://scripts/world/prop_kit.gd")
var stations: Array = []
var station_pos: Dictionary = {}
var bots: Array = []

static func load_json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

static func origin() -> Vector3:
	var o: Array = load_json(DATA).get("origin", [640, 90, 640])
	return Vector3(o[0], o[1], o[2])

static func spawn_point() -> Vector3:
	return origin() + Vector3(0, 2, 26)

func build() -> void:
	name = "WelcomeIsland"
	position = origin()
	var pad := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 34; cm.bottom_radius = 22; cm.height = 4
	pad.mesh = cm; pad.material_override = PropKit.mat("#3b2a4a", 0.0, 0.0, 0.9)
	pad.position.y = -2
	add_child(pad)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 34; sh.height = 4
	cs.shape = sh; body.add_child(cs); body.position.y = -2; add_child(body)
	stations = load_json(DATA).get("stations", [])
	var n := stations.size()
	for i in n:
		var a := PI * 0.5 + TAU * float(i) / n
		var p := Vector3(cos(a), 0, sin(a)) * 22.0
		station_pos[stations[i]["id"]] = origin() + p
		var glow := MeshInstance3D.new()
		var tm := CylinderMesh.new(); tm.top_radius = 2.2; tm.bottom_radius = 2.2; tm.height = 0.15
		glow.mesh = tm; glow.material_override = PropKit.mat("#ff2fd2", 1.6)
		glow.position = p + Vector3(0, 0.08, 0)
		add_child(glow)
		var s := PropKit.make_sign(str(stations[i]["title"]))
		var lab: Label3D = s.get_node("Text")
		lab.text = "%s\n%s" % [stations[i]["title"], stations[i]["text"]]
		lab.font_size = 40
		s.position = p
		add_child(s)
	for i in load_json(FAQ).get("bots", []).size():
		var b: Dictionary = load_json(FAQ)["bots"][i]
		var bot := _make_bot(b)
		bot.position = Vector3(-4 + 8 * i, 0, 18)
		add_child(bot)
		bots.append(bot)

func _make_bot(b: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = str(b["id"])
	n.add_to_group("helpers")
	n.set_meta("bot", b)
	PropKit.part(n, PropKit.cone(0.35, 0.55, 1.4, 12), PropKit.mat(str(b["color"]), 0.5, 0.6, 0.3), Vector3(0, 0.7, 0))
	PropKit.part(n, PropKit.sphere(0.4), PropKit.mat("#f4ecff", 0.8), Vector3(0, 1.75, 0))
	var l := Label3D.new()
	l.text = "%s\n(ask me: MENU › Help)" % b["name"]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 2.6; l.font_size = 48; l.pixel_size = 0.008; l.outline_size = 12
	l.modulate = Color(str(b["color"]))
	n.add_child(l)
	return n

func _process(delta: float) -> void:
	for b in bots: b.rotation.y += delta * 0.6

## Keyword FAQ lookup shared by both guide bots. Returns {answer, point}.
static func answer(question: String) -> Dictionary:
	var d := load_json(FAQ)
	var words := question.to_lower().replace("?", " ").replace(",", " ").replace(".", " ").split(" ", false)
	for f in d.get("faq", []):
		for k in f["keywords"]:
			if words.has(k): return {"answer": f["answer"], "point": f.get("point", "")}
	return {"answer": d.get("fallback", "..."), "point": ""}
