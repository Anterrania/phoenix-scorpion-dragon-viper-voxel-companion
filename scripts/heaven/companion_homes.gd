class_name CompanionHomes
extends RefCounted
## v0.14 HOME-1: every court companion has its own home realm in the world picker ("home_<id>") and also
## stands in Heaven (the court). Homes are far plots in the generated world, picked deterministically from
## the companion's home_realm biome, so every device lands in the same place. A visit spawns that companion
## face to face (free roam, its own persona, jobs and memory) and puts up a small marker (pedestal + sign).
## No terrain edits. Visitors and court members are cleared before the next world-picker trip.

## The imported court (docs/modules/V014_COMPANIONS.md). Order = picker order.
const COURT := ["foxy_ani", "aaliyah", "circuit_nova", "gemini_nightscythe", "seraphyx", "sonic_gage", "viper_gamer", "phoenix_dev_bot"]
const HOME_RADIUS := 1536.0
const BIOME_INDEX := {"alaska": 0, "venus": 1, "cosmic": 2, "cyber": 2}   # generator biome_at(): 0 Alaskan, 1 Venus, 2 Cosmic
const COURT_MAX_LOW := 4
const COURT_MAX := 8
const META := "phoenix_home_visitor"

static func persona(cid: String) -> Dictionary: return CompanionsScreen.persona_of(cid)

static func display_name(cid: String) -> String:
	var p := persona(cid)
	return str(p.get("display_name", p.get("name", cid)))

static func biome_index(home_realm: String) -> int:
	for k in BIOME_INDEX:
		if home_realm.begins_with(k): return int(BIOME_INDEX[k])
	return 0

## Grid entries appended to WorldPicker.grids().
static func grids() -> Array:
	var out: Array = []
	for cid in COURT:
		var p := persona(cid)
		if p.is_empty(): continue
		out.append({"id": "home_" + cid, "name": "%s · Home" % display_name(cid),
			"about": "%s's own realm (%s). %s" % [str(p.get("name", cid)), str(p.get("home_realm", p.get("home_biome", "alaska"))).replace("_", " "), str(p.get("job", ""))],
			"kind": "companion_home", "enter": "home:" + cid, "companion": cid, "rating": "general"})
	return out

## Fixed origin per companion (spread around a ring), then the nearest column of its biome.
static func origin(cid: String) -> Vector3:
	var i := maxi(0, COURT.find(cid))
	var a := TAU * float(i) / float(COURT.size())
	return Vector3(cos(a) * HOME_RADIUS, 0, sin(a) * HOME_RADIUS)

static func target(cid: String, gen: Object = null) -> Dictionary:
	var o := origin(cid)
	var want := biome_index(str(persona(cid).get("home_realm", persona(cid).get("home_biome", "alaska"))))
	if gen and gen.has_method("biome_at"):
		for ring in range(0, 24):
			var r := ring * 96.0
			var steps := maxi(1, ring * 8)
			for k in steps:
				var a := TAU * k / steps
				var p := o + Vector3(cos(a) * r, 0, sin(a) * r)
				if int(gen.biome_at(p.x, p.z)) == want: return {"kind": "companion_home", "pos": p, "companion": cid}
	return {"kind": "companion_home", "pos": o, "companion": cid}

## Remove earlier home visitors / court members and markers (owner-summoned companions stay).
static func clear_visitors(world: Node) -> int:
	if world == null or not world.is_inside_tree(): return 0
	var n := 0
	var kept: Array = Settings.get_value("companions", CompanionsScreen.SUMMONED_KEY, [])
	for c in world.get_tree().get_nodes_in_group("companions"):
		if not c.has_meta(META): continue
		if str(c.get("companion_id")) in kept: c.remove_meta(META); continue   # the owner added it: stays
		c.queue_free(); n += 1
	for ch in world.get_children():
		if ch.has_meta(META) and not ch.is_in_group("companions"): ch.queue_free()
	return n

static func _place(ui: Node, cid: String, at: Vector3, kind: String) -> Node:
	var r := CompanionsScreen._spawn(ui, cid, 1.0, false, false)
	if r.has("error"): return null
	var n: Node3D = r["node"]
	n.set_meta(META, kind)
	n.global_position = at
	if n.has_method("set_follow"): n.call_deferred("set_follow", false)   # free roam where they live
	return n

## Arrive at a home: the companion meets you face to face, plus a marker.
static func arrive(ui: Node, cid: String) -> Node:
	var w: Node = ui.get("world") if ui else null
	var pl: Node3D = ui.get("player") if ui else null
	if w == null or not w.is_inside_tree(): return null
	var base: Vector3 = pl.global_position if pl else origin(cid)
	var c := _place(ui, cid, base + Vector3(0, 1.5, -3), "home")
	w.add_child(marker(cid, base + Vector3(2.5, 0, -2)))
	if c and c.has_method("show_bubble"):
		c.call_deferred("show_bubble", "Welcome to my realm! " + str(persona(cid).get("starter_message", "")))
	return c

static func marker(cid: String, at: Vector3) -> Node3D:
	var root := Node3D.new(); root.name = "Home_" + cid; root.set_meta(META, "marker")
	root.position = at
	var ped := MeshInstance3D.new(); var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7; cyl.bottom_radius = 0.9; cyl.height = 0.6; ped.mesh = cyl
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(PhoenixTokens.GOLD); mat.metallic = 0.8; mat.roughness = 0.25
	mat.emission_enabled = true; mat.emission = Color(PhoenixTokens.MAGENTA); mat.emission_energy_multiplier = 0.4
	ped.material_override = mat; root.add_child(ped)
	var sign := Label3D.new(); sign.name = "Sign"; sign.text = "%s's Home" % str(persona(cid).get("name", cid))
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sign.position = Vector3(0, 1.6, 0); sign.font_size = 48
	sign.modulate = Color(PhoenixTokens.GOLD); root.add_child(sign)
	return root

static func court_cap() -> int:
	return COURT_MAX_LOW if Settings.quality() <= 1 else COURT_MAX

static func court_on() -> bool: return bool(Settings.get_value("companions", "heaven_court", true))

## Heaven court: court companions stand in a ring near the Heaven spawn.
static func heaven_court(ui: Node) -> int:
	if not court_on(): return 0
	var c0 := HeavenLayout.spawn_point()
	var ids: Array = []
	for cid in COURT:
		if not persona(cid).is_empty(): ids.append(cid)
	ids = ids.slice(0, court_cap())
	var n := 0
	for i in ids.size():
		var a := TAU * float(i) / float(ids.size())
		if _place(ui, str(ids[i]), c0 + Vector3(cos(a) * 7.0, 1.5, sin(a) * 7.0), "court") != null: n += 1
	return n
