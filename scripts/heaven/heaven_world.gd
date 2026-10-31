class_name HeavenWorld
extends Node3D
## HEAVEN-1..6 runtime: builds Heaven Welcome Island inside the running world and keeps it live.
## - Islands are built one per frame, nearest first (the spawn island synchronously, so arrival
##   is always on solid paving even before voxel collisions stream in).
## - Links: ring bridges, floating roads to the Mall, glowing aqueduct waterways, portals.
## - Far impostors: one low-poly batch for all islands, shown only beyond the voxel view distance.
## - Rides animate from absolute time (no tick replay) and only while a viewer is near (sleep
##   beyond WAKE_R * Dormancy.SLEEP_FACTOR): same rule as Dormancy, zero cost when far.
## - Rules: fly gate (HeavenAccess), void catch (fall off an island -> back on the nearest plaza),
##   Kelvin weather (HeavenWeather -> WeatherFX + HUD line), shop / transit / casino / portal prompts.
## - Live edits: polls HeavenEdits every EDIT_POLL_S; a changed island is rebuilt in place.

const B := preload("res://scripts/heaven/heaven_mesh_kit.gd")
const WAKE_R := 260.0
const EDIT_POLL_S := 1.5
const TICK_S := 0.5

var world: Node3D
var player: Node3D
var islands_built: Dictionary = {}    # id -> {node, shops, kiosks, rides, rev}
var rides: Array = []                 # {node, kind, center, phase, speed, awake, parts}
var _queue: Array = []
var _tick := 0.0
var _edit_t := 0.0
var _links: Node3D
var _impostors: MeshInstance3D
var _ui: CanvasLayer
var _info: Label
var _prompt: Button
var _prompt_info: Dictionary = {}
var _last_safe := Vector3.ZERO
var _in_heaven_t := -1000.0
var _clock := 0.0
var weather := {}
var district := {}
var point_cb: Callable                # "Direct a change": set while the owner is pointing
var _cross: Control

func setup(w: Node3D, p: Node3D) -> void:
	world = w; player = p
	name = "HeavenWorld"
	_links = Node3D.new(); _links.name = "Links"; add_child(_links)
	var spawn_id := str(HeavenLayout.data().get("spawn", {}).get("island", "transport_hub"))
	build_island(spawn_id)
	_queue = HeavenLayout.ids().filter(func(i): return i != spawn_id)
	var at: Vector3 = player.global_position if player else HeavenLayout.spawn_point()
	_queue.sort_custom(func(a, b): return HeavenLayout.center3(HeavenLayout.island(a)).distance_to(at) < HeavenLayout.center3(HeavenLayout.island(b)).distance_to(at))
	_queue.append("_links")
	_build_impostors()
	_build_ui()
	if w and w.get("pipeline") and w.pipeline.has_signal("applied"): w.pipeline.applied.connect(func(_t): _apply_ranges())
	_apply_ranges()

func build_all_now() -> void:
	while not _queue.is_empty(): _build_next()

func _build_next() -> void:
	var id: String = _queue.pop_front()
	if id == "_links": _build_links()
	else: build_island(id)

## (Re)build one island from its current pieces (base + applied edits).
func build_island(id: String) -> Dictionary:
	var isl := HeavenLayout.island(id)
	if isl.is_empty(): return {}
	if islands_built.has(id):
		var old: Dictionary = islands_built[id]
		(old["node"] as Node).queue_free()
		rides = rides.filter(func(r): return r["island"] != id)
	var bf := HeavenEdits.base_file(id)
	var pave := Color(str(bf.get("paving", {}).get("color", "#ede8de")))
	var res := HeavenBuilder.build_island(isl, HeavenEdits.pieces(id), pave)
	add_child(res["node"])
	for a in (res["node"] as Node).find_children("Trigger_*", "Area3D", false, false):
		a.body_entered.connect(_on_enter.bind(a))
		a.body_exited.connect(_on_exit.bind(a))
	for r in res["rides"]: _make_ride(r, id, res["node"])
	res["rev"] = HeavenEdits.revision(id)
	islands_built[id] = res
	return res

func _apply_ranges() -> void:
	var vd := 384.0
	var t = world.get("terrain") if world else null
	if t and "view_distance" in t: vd = float(t.view_distance)
	if _impostors:
		_impostors.visibility_range_begin = vd * 0.85
		_impostors.visibility_range_begin_margin = 24.0
	for id in islands_built:
		var d: Node = (islands_built[id]["node"] as Node).get_node_or_null("Detail")
		if d: d.visibility_range_end = maxf(RenderPipeline.props_range * 1.6, 110.0)

# ---------- links ----------
func _build_links() -> void:
	for c in _links.get_children(): c.queue_free()
	var b := B.Batch.new()
	for pair in HeavenLayout.bridges():
		_link(b, HeavenLayout.island(pair[0]), HeavenLayout.island(pair[1]), 8.0, 4.0, Color("#ede8de"), Color("#8fd0ff"))
	for pair in HeavenLayout.roads():
		_link(b, HeavenLayout.island(pair[0]), HeavenLayout.island(pair[1]), 12.0, 9.0, Color("#3a3f4c"), Color("#f0c35a"), true)
	for pair in HeavenLayout.waterways(): _waterway(b, HeavenLayout.island(pair[0]), HeavenLayout.island(pair[1]))
	for pt in HeavenLayout.portals(): _portal(b, pt)
	b.commit(_links, "LinksMesh", 0.0)

func _edge_point(from: Dictionary, to: Dictionary, inset := 0.78) -> Vector3:
	var a := HeavenLayout.center2(from); var c := HeavenLayout.center2(to)
	var e := a + (c - a).normalized() * float(from["radius"]) * inset
	return Vector3(e.x, HeavenLayout.walk_y(from) - 0.02, e.y)

func _link(b: B.Batch, a: Dictionary, c: Dictionary, width: float, arch: float, deck: Color, rail: Color, lanes := false) -> void:
	if a.is_empty() or c.is_empty(): return
	var p0 := _edge_point(a, c); var p1 := _edge_point(c, a)
	var pts := B.arch_path(p0, p1, arch, maxi(8, int(p0.distance_to(p1) / 10.0)))
	b.ribbon(pts, width, 1.2, deck, B.SOLID, true, rail)
	# underside keel + lamps on posts every ~30 m
	var keel: Array = pts.map(func(q): return q + Vector3(0, -1.2, 0))
	b.ribbon(keel, width * 0.45, 2.0, Color("#c9c3b8"), B.SOLID, false)
	if lanes:
		var mid: Array = pts.map(func(q): return q + Vector3(0, 0.02, 0))
		b.ribbon(mid, 0.25, 0.01, rail, B.GLOW, false)
	var n := int(p0.distance_to(p1) / 30.0)
	for k in range(1, n):
		var q: Vector3 = pts[int(float(k) / n * (pts.size() - 1))]
		var side := (p1 - p0).normalized().cross(Vector3.UP) * (width * 0.5 + 0.3)
		for sg in [-1.0, 1.0]:
			b.cyl(Transform3D(Basis(), q + side * sg), 0.12, 0.08, 3.2, Color("#cfd3da"), B.METAL, 6, false)
			b.sphere(Transform3D(Basis(), q + side * sg + Vector3(0, 3.35, 0)), 0.3, Color("#ffd9a0"), B.GLOW, 6, 4)

func _waterway(b: B.Batch, a: Dictionary, c: Dictionary) -> void:
	if a.is_empty() or c.is_empty(): return
	# an aqueduct beside the road (offset 14 m), 4 m above deck height, with a waterfall at each end
	var p0 := _edge_point(a, c, 0.62); var p1 := _edge_point(c, a, 0.7)
	var off := (p1 - p0).normalized().cross(Vector3.UP) * 14.0
	p0 += off + Vector3(0, 4.0, 0); p1 += off + Vector3(0, 4.0, 0)
	var pts := B.arch_path(p0, p1, 6.0, maxi(10, int(p0.distance_to(p1) / 9.0)))
	b.ribbon(pts, 4.0, 1.4, Color("#ede8de"), B.SOLID, false, Color("#8fd0ff"), 0.5)
	var water: Array = pts.map(func(q): return q + Vector3(0, 0.08, 0))
	b.ribbon(water, 3.4, 0.05, Color.WHITE, B.WATER, false)
	for k in range(2, pts.size() - 2, 4):
		var q: Vector3 = pts[k]
		b.cyl(Transform3D(Basis(), q + Vector3(0, -14.0, 0)), 0.9, 0.7, 12.6, Color("#ede8de"), B.SOLID, 8, false)
	for q in [pts[0], pts[pts.size() - 1]]:
		b.box(Transform3D(Basis(), q + Vector3(0, -2.0, 0)), Vector3(3.2, 4.0, 0.3), Color.WHITE, B.WATER, false)
		b.disc(Transform3D(Basis(), q + Vector3(0, -3.95, 0)), 3.5, Color.WHITE, B.WATER, 0.0, 16, 0.0, false)

func _portal(b: B.Batch, pt: Dictionary) -> void:
	var isl := HeavenLayout.island(str(pt["from"]))
	if isl.is_empty(): return
	var F := HeavenLayout.frame(isl)
	var at: Array = pt["at"]
	var pos := F * Vector3(float(at[0]), 0, float(at[1]))
	var xf := Transform3D(F.basis, pos)
	b.disc(xf * Transform3D(Basis(), Vector3(0, 0.04, 0)), 6.0, Color("#f4f1ff"), B.SOLID, 0.0, 32, 0.0, false)
	b.torus(xf * Transform3D(Basis(), Vector3(0, 5.5, 0)), 4.6, 0.35, Color("#e7dcff"), B.GLOW, 48, 6)
	b.torus(xf * Transform3D(Basis(), Vector3(0, 5.5, 0)), 4.0, 0.12, Color("#f0c35a"), B.GLOW, 40, 4)
	b.disc(xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 5.5, 0)), 4.0, Color(0.9, 0.85, 1.0), B.WATER, 0.0, 32, 0.0, false)
	var a := HeavenBuilder._area(_links, pos + Vector3(0, 2.0, 0), Vector3(6.0, 4.0, 2.5), {"kind": "portal", "to": pt["to"], "to_at": pt["to_at"], "name": str(pt["name"])}, F.basis)
	a.body_entered.connect(_on_enter.bind(a))
	a.body_exited.connect(_on_exit.bind(a))
	HeavenBuilder._label(_links, Transform3D(F.basis * Basis(Vector3.UP, PI), pos + Vector3(0, 11.0, 0)), str(pt["name"]), 72, 200.0)

# ---------- impostors ----------
func _build_impostors() -> void:
	var b := B.Batch.new()
	for i in HeavenLayout.islands():
		var c := HeavenLayout.center2(i)
		var top := float(i["top"])
		var R := float(i["radius"])
		var xf := Transform3D(Basis(), Vector3(c.x, top, c.y))
		b.disc(xf, R, Color("#e6efd8"), B.SOLID, 0.0, 20, 0.0, false)
		b.cyl(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(c.x, top, c.y)), R, R * 0.12, float(i["depth"]), Color("#cfc6d8"), B.SOLID, 20, false, false)
		if i["kind"] == "mall": b.dome(xf, 75.0, 48.0, Color(0.85, 0.93, 1.0, 0.5), B.GLASS, 16, 4)
	var host := Node3D.new(); host.name = "Impostors"; add_child(host)
	_impostors = b.commit(host, "ImpostorMesh", 0.0)
	_impostors.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------- rides ----------
func _make_ride(r: Dictionary, island_id: String, host: Node3D) -> void:
	var p: Dictionary = r["piece"]
	var G: Transform3D = r["xf"]
	var node := Node3D.new(); node.name = "Ride_" + str(p["type"])
	host.add_child(node)
	var ride := {"node": node, "kind": str(p["type"]), "center": G.origin, "island": island_id, "awake": false, "parts": []}
	var stat := B.Batch.new()
	match ride["kind"]:
		"wheel":
			var R := float(p.get("r", 28.0))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var foot := G * Vector3(sx * R * 0.45, 0, sz * 3.0)
					var hub := G * Vector3(0, R + 3.0, sz * 2.0)
					stat.box(Transform3D(Basis.looking_at((hub - foot).normalized(), Vector3.FORWARD if absf((hub - foot).normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT), (foot + hub) * 0.5), Vector3(0.6, 0.6, foot.distance_to(hub)), Color("#cfd3da"), B.METAL, true)
			stat.commit(node, "Support", 0.0)
			var rot := Node3D.new(); rot.name = "Wheel"; node.add_child(rot)
			rot.transform = Transform3D(G.basis, G * Vector3(0, R + 3.0, 0))
			var wb := B.Batch.new()
			for sz in [-1.6, 1.6]:
				wb.torus(Transform3D(Basis(), Vector3(0, 0, sz)), R, 0.35, Color("#f7f5fb"), B.METAL, 48, 6)
				wb.torus(Transform3D(Basis(), Vector3(0, 0, sz)), R + 0.5, 0.12, Color("#ff7ac0"), B.GLOW, 48, 4)
			for k in 16:
				var a := TAU * k / 16.0
				wb.box(Transform3D(Basis(Vector3.FORWARD, -a), Vector3(cos(a), sin(a), 0) * R * 0.5), Vector3(R, 0.25, 0.25), Color("#cfd3da"), B.METAL, false)
			wb.commit(rot, "Rim", 0.0)
			var gm := _gondola_mesh()
			for k in 16:
				var g := MeshInstance3D.new(); g.mesh = gm; rot.add_child(g)
				var a := TAU * k / 16.0
				g.position = Vector3(cos(a), sin(a), 0) * R
				ride["parts"].append(g)
			ride["rot"] = rot; ride["speed"] = TAU / 240.0; ride["base"] = G.basis
		"carousel":
			var R := float(p.get("r", 10.0))
			stat.cyl(G, R + 0.6, R + 0.6, 0.45, Color("#f7f5fb"), B.SOLID, 32)
			stat.cyl(G * Transform3D(Basis(), Vector3(0, 6.0, 0)), R + 1.0, 0.6, 3.0, Color("#ff7ac0"), B.SOLID, 24)
			stat.torus(G * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 6.0, 0)), R + 1.0, 0.15, Color("#f0c35a"), B.GLOW, 48, 4)
			stat.commit(node, "Base", 0.0)
			var rot := Node3D.new(); rot.name = "Carousel"; node.add_child(rot)
			rot.transform = Transform3D(G.basis, G * Vector3(0, 0.45, 0))
			var cb := B.Batch.new()
			cb.cyl(Transform3D(), 1.0, 1.0, 5.6, Color("#f0c35a"), B.METAL, 16)
			for k in 12:
				var a := TAU * k / 12.0
				var q := Vector3(cos(a) * R * 0.75, 0, sin(a) * R * 0.75)
				cb.cyl(Transform3D(Basis(), q), 0.06, 0.06, 5.55, Color("#f0c35a"), B.METAL, 6, false)
				cb.box(Transform3D(Basis(Vector3.UP, -a), q + Vector3(0, 1.3, 0)), Vector3(0.5, 0.6, 1.5), [Color("#f7f5fb"), Color("#ffd1e6"), Color("#bfe6ff")][k % 3], B.SOLID, false)
				cb.sphere(Transform3D(Basis(), q + Vector3(0, 1.9, 0) + Vector3(-sin(a), 0, cos(a)) * 0.6), 0.25, Color("#f7f5fb"))
			cb.commit(rot, "Deck", 0.0)
			ride["rot"] = rot; ride["speed"] = TAU / 22.0
		"coaster":
			var R := float(p.get("r", 70.0)); var H := float(p.get("h", 14.0))
			var path: Array = []
			for k in 97:
				var a := TAU * k / 96.0
				path.append(G * Vector3(cos(a) * R * (1.0 + 0.08 * sin(a * 2.0)), H + 6.0 * sin(a * 3.0), sin(a) * R * 0.86))
			stat.ribbon(path, 2.2, 0.4, Color("#ff7ac0"), B.METAL, false, Color("#8fd0ff"), 0.4)
			for k in range(0, 96, 4):
				var q: Vector3 = path[k]
				stat.cyl(Transform3D(Basis(), Vector3(q.x, G.origin.y, q.z)), 0.3, 0.25, q.y - G.origin.y - 0.4, Color("#cfd3da"), B.METAL, 6, false)
			stat.commit(node, "Track", 0.0)
			var cm := _coaster_car_mesh()
			for k in 5:
				var car := MeshInstance3D.new(); car.mesh = cm; node.add_child(car)
				ride["parts"].append(car)
			ride["path"] = path; ride["speed"] = 0.018
	rides.append(ride)

func _gondola_mesh() -> ArrayMesh:
	var b := B.Batch.new()
	b.box(Transform3D(Basis(), Vector3(0, -1.6, 0)), Vector3(2.2, 2.0, 2.2), Color("#f7f5fb"), B.SOLID, false)
	b.box(Transform3D(Basis(), Vector3(0, -1.4, 0)), Vector3(2.3, 0.9, 2.3), Color(0.82, 0.92, 1.0, 0.35), B.GLASS, false)
	b.box(Transform3D(Basis(), Vector3(0, -0.4, 0)), Vector3(0.12, 0.8, 0.12), Color("#cfd3da"), B.METAL, false)
	var tmp := Node3D.new()
	var mi := b.commit(tmp, "G", 0.0)
	var m := mi.mesh as ArrayMesh
	tmp.free()
	return m

func _coaster_car_mesh() -> ArrayMesh:
	var b := B.Batch.new()
	b.box(Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.8, 0.8, 2.6), Color("#f7f5fb"), B.METAL, false)
	b.box(Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.6, 0.1, 2.4), Color("#8fd0ff"), B.GLOW, false)
	var tmp := Node3D.new()
	var mi := b.commit(tmp, "C", 0.0)
	var m := mi.mesh as ArrayMesh
	tmp.free()
	return m

## Pose every awake ride from the absolute clock (no catch-up replay needed after sleep).
func pose_rides(t: float) -> void:
	for r in rides:
		if not r["awake"]: continue
		match r["kind"]:
			"wheel":
				var rot: Node3D = r["rot"]
				var a := fposmod(t * float(r["speed"]), TAU)
				rot.transform.basis = (r["base"] as Basis) * Basis(Vector3.BACK, a)
				for g in r["parts"]: (g as Node3D).rotation.z = -a   # gondolas stay level
			"carousel":
				var rot2: Node3D = r["rot"]
				rot2.rotation.y = fposmod(t * float(r["speed"]), TAU)
			"coaster":
				var path: Array = r["path"]
				var n := path.size() - 1
				for k in r["parts"].size():
					var u := fposmod(t * float(r["speed"]) - k * 0.006, 1.0) * n
					var i0 := int(u); var i1 := (i0 + 1) % n
					var q: Vector3 = (path[i0] as Vector3).lerp(path[i1], u - i0)
					var dir: Vector3 = (path[i1] as Vector3) - (path[i0] as Vector3)
					var car: Node3D = r["parts"][k]
					car.global_position = q + Vector3(0, 0.25, 0)
					if dir.length() > 0.01 and absf(dir.normalized().dot(Vector3.UP)) < 0.95: car.look_at(q + dir, Vector3.UP)

func _wake_rides() -> void:
	var at: Vector3 = player.global_position if player else Vector3.ZERO
	for r in rides:
		var d := at.distance_to(r["center"])
		if not r["awake"] and d < WAKE_R: r["awake"] = true
		elif r["awake"] and d > WAKE_R * Dormancy.SLEEP_FACTOR: r["awake"] = false
		(r["node"] as Node3D).set_process(r["awake"])

func awake_rides() -> int: return rides.filter(func(r): return r["awake"]).size()

# ---------- runtime ----------
func _process(delta: float) -> void:
	_clock += delta
	if not _queue.is_empty(): _build_next()   # one island per frame
	pose_rides(Time.get_ticks_msec() / 1000.0)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK_S
		_rules_tick()
	_edit_t -= delta
	if _edit_t <= 0.0:
		_edit_t = EDIT_POLL_S
		poll_edits()

## Rebuilds islands whose edit revision moved (companion edits stream in without restart).
func poll_edits() -> Array:
	HeavenEdits.sync()
	var rebuilt: Array = []
	for id in islands_built.keys():
		if int(islands_built[id]["rev"]) != HeavenEdits.revision(id):
			build_island(id); rebuilt.append(id)
	return rebuilt

func in_heaven() -> bool:
	return player != null and HeavenLayout.contains(player.global_position)

func _rules_tick() -> void:
	if player == null: return
	_wake_rides()
	var pos := player.global_position
	var here := HeavenLayout.contains(pos)
	var horiz := Vector2(pos.x, pos.z).length() < float(HeavenLayout.data().get("extent", 720))
	if here:
		_in_heaven_t = _clock
		district = HeavenLayout.district_at(pos)
		var hr: float = float(world.get("hour")) if world and world.get("hour") != null else 12.0
		weather = HeavenWeather.report(str(district.get("id", "")), HeavenWeather.today(), hr)
		var wfx = world.get("weather") if world else null
		if wfx and "heaven_fx" in wfx: wfx.heaven_fx = str(weather["fx"])
		# fly gate: no right to fly here -> land (refusal message once)
		if "flying" in player and player.flying and not LandGate.can_fly(Tiers.SELF, pos):
			player.set_flying(false)
			_toast("Flying in Heaven is by the owner's grant. Walk, or use a transit kiosk.", "warn")
		var isl := HeavenLayout.island_at(pos)
		if not isl.is_empty() and absf(pos.y - HeavenLayout.walk_y(isl)) < 3.0: _last_safe = pos
	elif horiz and _clock - _in_heaven_t < 30.0 and not ("flying" in player and player.flying):
		# void catch: fell off an island -> back on the last safe plaza spot (or the Hub)
		var g = world.get("generator") if world else null
		var ground: float = g.height_f(pos.x, pos.z) if g else 0.0
		if pos.y < HeavenLayout.floor_y() and pos.y > ground + 15.0:
			catch_fall()
	if _info:
		_info.visible = here
		if here: _info.text = hud_text()

func catch_fall() -> void:
	var to := _last_safe if _last_safe != Vector3.ZERO else HeavenLayout.spawn_point()
	place_player(to + Vector3(0, 1.0, 0))
	_toast("Caught by the clouds. Back on the plaza.", "ok")

func hud_text() -> String:
	return "☁ Heaven · %s · %s · %s" % [district.get("name", "?"), weather.get("text", "—"), weather.get("label", "")]

func place_player(p: Vector3, yaw := NAN) -> void:
	if player == null: return
	player.global_position = p
	if "velocity" in player: player.velocity = Vector3.ZERO
	if not is_nan(yaw): player.rotation.y = yaw
	for c in get_tree().get_nodes_in_group("companions"):
		(c as Node3D).global_position = p + Vector3(randf_range(-3, 3), 0.5, randf_range(2, 4))

## Transit: walk-free travel between districts (anyone, no fly right needed).
func travel_to(island_id: String) -> void:
	var isl := HeavenLayout.island(island_id)
	if isl.is_empty(): return
	if not islands_built.has(island_id): build_island(island_id)
	place_player(HeavenLayout.arrival(island_id))
	_toast("Arrived: " + str(isl["name"]), "ok")

func go_spawn() -> void:
	var s := HeavenLayout.spawn()
	place_player(s["pos"], s["yaw"])

# ---------- prompts ----------
func _on_enter(body: Node, area: Area3D) -> void:
	if body != player: return
	var info: Dictionary = area.get_meta("heaven", {})
	if info.get("kind", "") == "portal":
		var to := HeavenLayout.island(str(info["to"]))
		if to.is_empty(): return
		if not islands_built.has(str(info["to"])): build_island(str(info["to"]))
		var ta: Array = info["to_at"]
		place_player(HeavenLayout.frame(to) * Vector3(float(ta[0]), 1.2, float(ta[1])))
		_toast("Through the portal: " + str(to["name"]), "ok")
		return
	_prompt_info = info
	if _prompt:
		_prompt.text = {"shop": "🛍 Enter ", "transit": "🚝 ", "casino": "🎡 "}.get(info["kind"], "") + str(info.get("name", ""))
		_prompt.visible = true

func _on_exit(body: Node, area: Area3D) -> void:
	if body != player: return
	if _prompt_info == area.get_meta("heaven", {}):
		_prompt_info = {}
		if _prompt: _prompt.visible = false

func _open_prompt() -> void:
	var ui := _ui_root()
	if ui == null or _prompt_info.is_empty(): return
	match str(_prompt_info["kind"]):
		"shop": HeavenScreen.open(ui, self, "shop", _prompt_info)
		"transit": HeavenScreen.open(ui, self, "transit", _prompt_info)
		"casino": HeavenScreen.open(ui, self, "casino", _prompt_info)

func _ui_root() -> Node:
	return world.get_node_or_null("UI") if world else null

func _toast(text: String, variant := "ok") -> void:
	var ui := _ui_root()
	if ui: Toast.show_toast(ui, text, variant)

func _build_ui() -> void:
	_ui = CanvasLayer.new(); _ui.name = "HeavenUI"; _ui.layer = 4
	add_child(_ui)
	_info = Label.new(); _info.name = "HeavenInfo"
	_info.position = Vector2(14, 104)
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", Color("#fff6e0"))
	_info.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_info.add_theme_constant_override("outline_size", 6)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_ui.add_child(_info)
	_prompt = Button.new(); _prompt.name = "HeavenPrompt"
	_prompt.anchor_left = 0.5; _prompt.anchor_right = 0.5; _prompt.anchor_top = 1.0; _prompt.anchor_bottom = 1.0
	_prompt.offset_left = -220; _prompt.offset_right = 220; _prompt.offset_top = -330; _prompt.offset_bottom = -330 + PhoenixTokens.TAP_MIN
	_prompt.theme = ViperKit.theme()
	_prompt.visible = false
	_prompt.pressed.connect(_open_prompt)
	_ui.add_child(_prompt)

# ---------- "Direct a change": pointing ----------
## Starts pointing mode: a crosshair + "Use this spot". cb(spot: Vector3) gets the hit point.
func begin_point(cb: Callable) -> void:
	point_cb = cb
	if _cross: _cross.queue_free()
	var box := VBoxContainer.new(); box.name = "PointMode"
	box.anchor_left = 0.5; box.anchor_right = 0.5; box.anchor_top = 0.5; box.anchor_bottom = 0.5
	box.offset_left = -200; box.offset_right = 200; box.offset_top = -30; box.offset_bottom = 260
	box.theme = ViperKit.theme()
	var mark := Label.new(); mark.text = "＋"; mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 48)
	box.add_child(mark)
	var hint := Label.new(); hint.text = "Aim the centre at the spot"; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var use := Button.new(); use.text = "Use this spot"; use.custom_minimum_size.y = PhoenixTokens.TAP_MIN
	use.pressed.connect(func(): _finish_point(true))
	box.add_child(use)
	var cancel := Button.new(); cancel.text = "Cancel"; cancel.custom_minimum_size.y = PhoenixTokens.TAP_MIN
	cancel.pressed.connect(func(): _finish_point(false))
	box.add_child(cancel)
	_cross = box
	_ui.add_child(box)

func _finish_point(ok: bool) -> void:
	if _cross: _cross.queue_free(); _cross = null
	var cb := point_cb
	point_cb = Callable()
	if ok and cb.is_valid(): cb.call(aim_point())

## World point under the screen centre (physics ray: paving, buildings, voxel terrain).
func aim_point() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null: return player.global_position if player else Vector3.ZERO
	var vp := get_viewport().get_visible_rect().size * 0.5
	var from := cam.project_ray_origin(vp)
	var to := from + cam.project_ray_normal(vp) * 400.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if player is CollisionObject3D: q.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if hit.has("position") else (player.global_position if player else Vector3.ZERO)
