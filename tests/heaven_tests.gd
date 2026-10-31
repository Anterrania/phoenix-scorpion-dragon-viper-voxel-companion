extends RefCounted
## HEAVEN-1..6: Heaven Welcome Island. Layout, voxel islands, builder geometry, fly / studio gates,
## Kelvin weather, shops, world picker, live companion edits + "Direct a change", runtime world.

static func _hub() -> Dictionary: return HeavenLayout.island("transport_hub")

static func run(t: Node) -> void:
	var root := "user://test_heaven_%d" % Time.get_ticks_usec()
	var old_eve := EveCore.save_dir
	EveCore.save_dir = root.path_join("eve"); EveCore.reset_cache()
	HeavenAccess.reset_for_tests(root.path_join("heaven"))
	HeavenEdits.reset_for_tests(root.path_join("heaven"))
	HeavenLayout.reset_for_tests()
	_layout(t)
	_terrain(t)
	_builder(t)
	_gates(t)
	_weather(t)
	_shops(t)
	_picker(t)
	_edits(t)
	_director(t)
	Tiers.owner_override = null; EveCore.owner_override = null
	EveCore.save_dir = old_eve; EveCore.reset_cache()

static func _layout(t: Node) -> void:
	var ids := HeavenLayout.ids()
	t.check(ids.size() == 16 and HeavenLayout.ring_ids().size() == 13, "heaven: mall + 13 districts + spirit realm + the beyond")
	t.check(HeavenLayout.island("main_mall")["kind"] == "mall" and HeavenLayout.center2(HeavenLayout.island("main_mall")) == Vector2.ZERO, "heaven: Mall dome island at the centre")
	var hub := _hub()
	t.check(HeavenLayout.center2(hub).y > 400.0 and absf(HeavenLayout.center2(hub).x) < 1.0, "heaven: Transportation Hub is the bottom island of the map (+z)")
	var sp := HeavenLayout.spawn_point()
	t.check(HeavenLayout.island_at(sp).get("id", "") == "transport_hub" and absf(sp.y - HeavenLayout.walk_y(hub) - 1.2) < 0.01, "heaven: spawn stands on the Hub plaza")
	var ring := HeavenLayout.ring_ids()
	var min_gap := 1e9
	for i in ring.size():
		var a := HeavenLayout.island(ring[i]); var b := HeavenLayout.island(ring[(i + 1) % ring.size()])
		min_gap = minf(min_gap, HeavenLayout.center2(a).distance_to(HeavenLayout.center2(b)) - float(a["radius"]) - float(b["radius"]))
	t.check(min_gap > 10.0, "heaven: ring islands float apart (min gap %.0f m, bridges span it)" % min_gap)
	var ok := true
	for i in HeavenLayout.islands():
		if float(i["top"]) - float(i["depth"]) < HeavenLayout.floor_y() or not HeavenLayout.contains(HeavenLayout.center3(i) + Vector3(0, 2, 0)): ok = false
	t.check(ok, "heaven: every island sits inside Heaven airspace, above the floor")
	t.check(not HeavenLayout.contains(Vector3(0, 40, 0)) and not HeavenLayout.contains(Vector3(5000, 600, 0)), "heaven: ground world and far sky are not Heaven")
	t.check(HeavenLayout.bridges().size() == 13 and HeavenLayout.roads().size() == 13 and HeavenLayout.waterways().size() == 5, "heaven: 13 bridges, 13 floating roads, 5 waterways")
	t.check(HeavenLayout.portals().size() == 4, "heaven: portals Mall <-> Spirit Realm <-> The Beyond")
	t.check(HeavenLayout.island("the_beyond")["top"] > HeavenLayout.island("spirit_realm")["top"], "heaven: The Beyond floats above the Spirit Realm")
	t.check(HeavenLayout.sdf(hub, HeavenLayout.center3(hub) + Vector3(0, -5, 0)) < 0.0 and HeavenLayout.sdf(hub, HeavenLayout.center3(hub) + Vector3(0, 5, 0)) > 0.0, "heaven: island SDF solid below the top, air above")
	t.check(HeavenLayout.sdf(hub, Vector3(0, 300, 0)) > 0.0, "heaven: open sky between ground and islands")
	t.check(HeavenLayout.district_at(HeavenLayout.center3(HeavenLayout.island("casino")) + Vector3(0, 2, 0)).get("id", "") == "casino", "heaven: district lookup")

static func _terrain(t: Node) -> void:
	var G = load("res://scripts/heaven/heaven_terrain_generator.gd")
	var g = G.new(1337)
	t.check(g.height_f(10.0, 4.0) == load("res://scripts/generators/smooth_terrain_generator.gd").new(1337).height_f(10.0, 4.0), "heaven terrain: ground world unchanged")
	if not ClassDB.class_exists("VoxelBuffer"): return
	var hub := _hub()
	var c := HeavenLayout.center3(hub)
	for lod in [0, 2]:
		var buf = ClassDB.instantiate("VoxelBuffer")
		buf.create(16, 16, 16)
		var s: int = 1 << int(lod)
		var org := Vector3i(int(c.x) - 8 * s, int(float(hub["top"])) - 8 * s, int(c.z) - 8 * s)
		g._generate_block(buf, org, lod)
		var worst := 0.0
		var solid := 0
		for z in 16:
			for y in 16:
				for x in 16:
					var v: float = buf.get_voxel_f(x, y, z, 1)
					var ref: float = g.heaven_sdf_at(Vector3(org) + Vector3(x, y, z) * s, lod)
					worst = maxf(worst, absf(v - ref))
					if v < 0.0: solid += 1
		t.check(worst < 0.02 and solid > 500, "heaven terrain: band fill matches reference at lod %d (err %.3f, %d solid)" % [lod, worst, solid])
	var air = ClassDB.instantiate("VoxelBuffer"); air.create(16, 16, 16)
	g._generate_block(air, Vector3i(0, 300, 0), 0)
	t.check(air.get_voxel_f(8, 8, 8, 1) > 0.0, "heaven terrain: sky between ground and islands is air")

static func _builder(t: Node) -> void:
	var tris := 0
	var shops := 0
	var rides := 0
	var ok := true
	for id in HeavenLayout.ids():
		var r := HeavenBuilder.build_island(HeavenLayout.island(id), HeavenEdits.base_pieces(id))
		tris += int(r["tris"]); shops += (r["shops"] as Array).size(); rides += (r["rides"] as Array).size()
		var n: Node3D = r["node"]
		if n.find_children("*", "MeshInstance3D", true, false).is_empty() or n.find_children("*", "StaticBody3D", true, false).is_empty(): ok = false
		n.free()
	t.check(ok, "heaven builder: every island gets meshes + collision")
	t.check(shops == HeavenShops.shops().size(), "heaven builder: one enterable shop per shops.json entry (%d)" % shops)
	t.check(rides >= 3, "heaven builder: theme park rides (wheel, carousel, coaster)")
	t.check(tris > 20000 and tris < 900000, "heaven builder: geometry budget (%d tris)" % tris)
	var mall := HeavenBuilder.build_island(HeavenLayout.island("main_mall"), HeavenEdits.base_pieces("main_mall"))
	t.check(mall["node"].find_child("Trigger_shop", true, false) != null, "heaven builder: mall shop doors are trigger volumes")
	mall["node"].free()
	for p in HeavenEdits.base_pieces("downtown"):
		if not (p["type"] in HeavenBuilder.EDITABLE or p["type"] in ["coaster", "wheel", "carousel", "canal_ring", "lagoon", "sand", "spawn_pad", "dome", "terminal", "tram_platform", "casino_hall"]):
			ok = false
	t.check(ok, "heaven builder: district pieces are known types")

static func _gates(t: Node) -> void:
	var sky := HeavenLayout.spawn_point()
	Tiers.owner_override = false
	t.check(not LandGate.can_fly(Tiers.SELF, sky), "heaven gate: nobody flies in Heaven by default (locked owner too)")
	t.check(LandGate.can_fly(Tiers.SELF, Vector3(1300, 20, 1300)) == bool(Estate.parcel_get(LandGate.target_at(Vector3(1300, 20, 1300))["region"], LandGate.target_at(Vector3(1300, 20, 1300))["parcel"], "allow_fly")), "heaven gate: ground fly rule unchanged")
	t.check(HeavenAccess.grant(Tiers.SELF, "fly", "foxy_ani") != "", "heaven gate: only the unlocked owner grants")
	Tiers.owner_override = true
	t.check(LandGate.can_fly(Tiers.SELF, sky), "heaven gate: unlocked owner flies")
	t.check(HeavenAccess.grant(Tiers.SELF, "fly", "foxy_ani", 1) == "", "heaven gate: owner grants flight")
	t.check(HeavenAccess.grant(Tiers.SELF, "fly", Tiers.OWNER_ID) != "", "heaven gate: grants never target the owner id")
	Tiers.owner_override = false
	t.check(LandGate.can_fly("foxy_ani", sky) and not LandGate.can_fly("aaliyah", sky), "heaven gate: granted member flies, others walk")
	var args := {"x": sky.x, "y": sky.y, "z": sky.z}
	t.check(LandGate.companion_tool_error("foxy_ani", "place_voxel", args).begins_with("heaven:"), "heaven studio gate: voxel tools in Heaven need the studio grant")
	Tiers.owner_override = true
	HeavenAccess.grant(Tiers.SELF, "studio", "foxy_ani", 1)
	t.check(not LandGate.companion_tool_error("foxy_ani", "place_voxel", args).begins_with("heaven:"), "heaven studio gate: granted companion passes the Heaven check")
	t.check(HeavenAccess.revoke(Tiers.SELF, "studio", "foxy_ani", 2) == "" and not HeavenAccess.can_studio("foxy_ani"), "heaven studio gate: revoke")
	t.check(HeavenAccess.log_entries().size() >= 3, "heaven access: grants are logged")
	Tiers.owner_override = false
	# player: refused flight + ceiling under the islands
	var P: PackedScene = load("res://scenes/player.tscn")
	var pl = P.instantiate()
	t.add_child(pl)
	pl.global_position = sky + Vector3(0, 2, 0)
	var refused := [""]
	pl.fly_refused.connect(func(r): refused[0] = r)
	pl.set_flying(true)
	t.check(not pl.flying and refused[0] != "", "heaven gate: player flight refused in Heaven without a grant")
	pl.global_position = Vector3(0, 60, 0)
	t.check(pl.fly_ceiling() < HeavenLayout.floor_y(), "heaven gate: sky ceiling stays below the islands without a grant")
	Tiers.owner_override = true
	t.check(pl.fly_ceiling() > HeavenLayout.ceiling_y(), "heaven gate: owner's ceiling is above Heaven")
	pl.global_position = sky + Vector3(0, 2, 0)
	pl.set_flying(true)
	t.check(pl.flying, "heaven gate: owner may take off in Heaven")
	pl.queue_free()
	Tiers.owner_override = false

static func _weather(t: Node) -> void:
	var r := HeavenWeather.report("beach", 100, 15.0)
	t.check(r["kelvin"] > 280.0 and r["kelvin"] < 305.0 and str(r["text"]).ends_with(" K"), "heaven weather: Kelvin temperature (%s)" % r["text"])
	t.check(HeavenWeather.report("the_beyond", 100, 15.0)["kelvin"] < HeavenWeather.report("spirit_realm", 100, 15.0)["kelvin"] and HeavenWeather.report("spirit_realm", 100, 15.0)["kelvin"] < r["kelvin"], "heaven weather: higher realms are colder")
	t.check(HeavenWeather.report("gardens", 100, 3.0)["kelvin"] < HeavenWeather.report("gardens", 100, 15.0)["kelvin"], "heaven weather: warmest mid-afternoon")
	t.check(absf(HeavenWeather.kelvin_of_celsius(20.0) - 293.15) < 0.001 and absf(HeavenWeather.celsius_of_kelvin(273.15)) < 0.001, "heaven weather: K <-> °C")
	var states := {}
	for d in 40:
		for h in [6.0, 12.0, 18.0]: states[HeavenWeather.report("gardens", d, h)["state"]] = true
	t.check(states.size() >= 3 and not states.has("storm"), "heaven weather: gentle varied states, no storms")
	t.check("rain" in load("res://scripts/fx/weather_fx.gd").HEAVEN_FX and "petals" in load("res://scripts/fx/weather_fx.gd").HEAVEN_FX, "heaven weather: rain + petal particle kinds")

static func _shops(t: Node) -> void:
	var ok := true
	for s in HeavenShops.shops():
		if HeavenLayout.island(str(s["island"])).is_empty(): ok = false
		for it in HeavenShops.stock(str(s["id"])):
			if int(it.get("price_aethel", 0)) != 0: ok = false
	t.check(ok, "heaven shops: every shop is on a real island; house items are free")
	var cats := {}
	for s in HeavenShops.for_island("main_mall"): cats[s["category"]] = true
	t.check(cats.has("clothes") and cats.has("shoes") and cats.has("hair") and cats.has("looks"), "heaven shops: mall has clothes, shoes, hair, looks")
	var inv := t.get_node_or_null("/root/Inventory")
	if inv:
		t.check(not inv.item("hair_rose_gold").is_empty(), "heaven shops: house items in the wardrobe catalog")
		var was: bool = inv.is_equipped("heaven_test", "hair_rose_gold")
		if not was: HeavenShops.wear(inv, "hair_rose_gold", "heaven_test")
		var st: Dictionary = inv.styled("heaven_test", {})
		t.check(st.get("hair") is Color, "heaven shops: worn hair colour reaches the avatar style")
		HeavenShops.wear(inv, "hair_rose_gold", "heaven_test")   # tap again = take off
	var r := HeavenShops.buy("no_such_listing", 1, {"shown_price": 5})
	t.check(r.has("error"), "heaven shops: buying goes through MarketDelivery checks")
	var fp := FreePlay.spin(Tiers.SELF, "lantern_reels", {}, 1)
	t.check(fp.has("error"), "heaven casino: casino spin refused without age/country (free play only, legal review)")

static func _picker(t: Node) -> void:
	WorldPicker.reset_for_tests()
	t.check(WorldPicker.grids().size() >= 5 and WorldPicker.default_id() == "heaven", "world picker: grids listed, Heaven is the default start world")
	var g = load("res://scripts/heaven/heaven_terrain_generator.gd").new(1337)
	t.check(WorldPicker.target(WorldPicker.grid("heaven"), g)["pos"] == HeavenLayout.spawn_point(), "world picker: Heaven enters at the Hub")
	var v := WorldPicker.target(WorldPicker.grid("venus"), g)
	t.check(int(g.biome_at(v["pos"].x, v["pos"].z)) == 1, "world picker: Venus found by biome search")
	var old: Variant = Settings.get_value("world", "start_realm", "")
	t.check(WorldPicker.set_start_realm("cosmic") and WorldPicker.start_realm() == "cosmic", "world picker: start world is a setting")
	t.check(not WorldPicker.set_start_realm("nowhere"), "world picker: unknown world refused")
	Settings.set_value("world", "start_realm", old)

static func _edits(t: Node) -> void:
	var hub := _hub()
	var base := HeavenEdits.pieces("transport_hub").size()
	Tiers.owner_override = false; EveCore.owner_override = false
	var add := {"island": "transport_hub", "op": "add", "piece": {"type": "fountain", "at": [10.0, 20.0], "r": 5.0}}
	t.check(HeavenEdits.validate({"island": "transport_hub", "op": "add", "piece": {"type": "fountain", "at": [500.0, 0.0]}}).has("error"), "heaven edits: off-plaza refused")
	t.check(HeavenEdits.validate({"island": "transport_hub", "op": "add", "piece": {"type": "coaster", "at": [0.0, 0.0]}}).has("error"), "heaven edits: non-editable types refused")
	t.check(HeavenEdits.validate({"island": "nowhere", "op": "add", "piece": add["piece"]}).has("error"), "heaven edits: unknown island refused")
	var big := HeavenEdits.validate({"island": "transport_hub", "op": "add", "piece": {"type": "tower", "at": [0.0, 30.0], "h": 9999.0}})
	t.check(float(big["edit"]["piece"]["h"]) <= 140.0, "heaven edits: sizes clamped")
	var r := HeavenEdits.propose("foxy_ani", add, 100, "a welcome fountain")
	t.check(r.get("state", "") == "pending" and HeavenEdits.pieces("transport_hub").size() == base, "heaven edits: companion proposal waits for the owner")
	var pend := EveCore.proposals(true).filter(func(p): return p["id"] == r["proposal"])
	t.check(pend.size() == 1 and str(pend[0]["description"]).contains("[heaven-edit"), "heaven edits: proposal goes through EveCore.propose_update")
	var rev0 := HeavenEdits.revision("transport_hub")
	t.check(not EveCore.decide(str(r["proposal"]), true), "heaven edits: locked owner can't approve")
	EveCore.owner_override = true; Tiers.owner_override = true
	EveCore.decide(str(r["proposal"]), true)
	var ch := HeavenEdits.sync()
	t.check(ch == ["transport_hub"] and HeavenEdits.pieces("transport_hub").size() == base + 1 and HeavenEdits.revision("transport_hub") > rev0, "heaven edits: approved -> applied, island revision bumps (live rebuild)")
	var pid := str(HeavenEdits.edits("applied")[-1]["piece"]["id"])
	var r2 := HeavenEdits.propose("foxy_ani", {"island": "transport_hub", "op": "set", "target": pid, "set": {"color": "#f0c35a", "r": 8.0}}, 101)
	EveCore.decide(str(r2["proposal"]), false)
	HeavenEdits.sync()
	t.check(HeavenEdits.find_piece("transport_hub", pid).get("r", 0.0) == 5.0, "heaven edits: rejected change not applied")
	t.check(HeavenEdits.edits("rejected").size() == 1, "heaven edits: rejection kept in the log")
	HeavenAccess.grant(Tiers.SELF, "build", "aaliyah", 1)
	Tiers.owner_override = false; EveCore.owner_override = false
	var r3 := HeavenEdits.propose("aaliyah", {"island": "transport_hub", "op": "set", "target": pid, "set": {"r": 7.0}}, 102)
	t.check(r3.get("state", "") == "applied" and float(HeavenEdits.find_piece("transport_hub", pid)["r"]) == 7.0, "heaven edits: standing build grant applies at once")
	t.check(HeavenEdits.revert(Tiers.SELF, str(r3["id"])) != "", "heaven edits: only the owner undoes")
	Tiers.owner_override = true; EveCore.owner_override = true
	t.check(HeavenEdits.revert(Tiers.SELF, str(r3["id"])) == "" and float(HeavenEdits.find_piece("transport_hub", pid)["r"]) == 5.0, "heaven edits: owner undo")
	# companion build tool (world coordinates) + owner direction
	var spot := HeavenLayout.frame(hub) * Vector3(-20.0, 0.0, 25.0) + Vector3(0, HeavenLayout.walk_y(hub), 0)
	var r4 := HeavenEdits.tool_call("foxy_ani", {"op": "add", "type": "lamp", "x": spot.x, "y": spot.y, "z": spot.z}, 103, true)
	t.check(r4.get("state", "") == "applied", "heaven direct: unlocked owner directing applies immediately")
	var lamp: Dictionary = r4["edit"]["piece"]
	t.check(absf(float(lamp["at"][0]) + 20.0) < 0.05 and absf(float(lamp["at"][1]) - 25.0) < 0.05, "heaven edits: tool call converts world -> island-local position")
	Tiers.owner_override = false; EveCore.owner_override = false
	var r5 := HeavenEdits.tool_call("foxy_ani", {"op": "add", "type": "bench", "x": spot.x, "y": spot.y, "z": spot.z}, 104, true)
	t.check(r5.get("state", "") == "pending", "heaven direct: without the unlocked owner it stays a proposal")
	t.check(HeavenEdits.tool_call("foxy_ani", {"op": "add", "type": "lamp", "x": 3000.0, "y": 10.0, "z": 0.0}).has("error"), "heaven edits: tool refuses spots off Heaven")
	t.check(HeavenEdits.TOOL_SPEC["name"] == "heaven_edit", "heaven edits: companion tool spec published")
	# persisted: a fresh load sees the same applied overlay
	var n_applied := HeavenEdits.edits("applied").size()
	HeavenEdits._e = null
	t.check(HeavenEdits.edits("applied").size() == n_applied, "heaven edits: overlay persists (SecureFile)")
	# runtime world: builds everything and rebuilds the edited island live
	var hw := HeavenWorld.new()
	var pl := Node3D.new(); pl.name = "HeavenTestPlayer"
	t.add_child(pl); t.add_child(hw)
	pl.global_position = HeavenLayout.spawn_point()
	hw.setup(null, pl)
	hw.build_all_now()
	t.check(hw.islands_built.size() == 16 and hw.get_node("Links").get_child_count() > 0, "heaven world: all islands + bridges/roads/waterways/portals built")
	t.check(hw.find_child("ImpostorMesh", true, false) != null, "heaven world: far impostors")
	hw._rules_tick()
	t.check(hw.hud_text().contains("Transportation Hub") and hw.hud_text().contains(" K"), "heaven world: HUD line with district + Kelvin")
	pl.global_position = HeavenLayout.center3(HeavenLayout.island("theme_park")) + Vector3(0, 2, 0)
	hw._wake_rides()
	hw.pose_rides(12.5)
	t.check(hw.awake_rides() >= 3, "heaven world: rides wake near a viewer")
	pl.global_position = Vector3(0, 40, 0)
	hw._wake_rides()
	t.check(hw.awake_rides() == 0, "heaven world: rides sleep when nobody is near")
	EveCore.owner_override = true; Tiers.owner_override = true
	EveCore.decide(str(r5["proposal"]), true)
	var rebuilt := hw.poll_edits()
	t.check(rebuilt == ["transport_hub"], "heaven world: approved edit streams in (only that island rebuilt)")
	hw.queue_free(); pl.queue_free()
	Tiers.owner_override = false; EveCore.owner_override = false

static func _director(t: Node) -> void:
	var spot := HeavenLayout.spawn_point()
	var a := HeavenDirector.parse("put a fountain here", spot)
	t.check(a.get("op") == "add" and a.get("type") == "fountain", "heaven director: 'put a fountain here' -> add fountain")
	var piece := {"id": "x_1", "type": "tower", "h": 40.0, "w": 10.0}
	var b := HeavenDirector.parse("make it taller", spot, piece)
	t.check(b.get("op") == "set" and float(b.get("h", 0)) == 50.0, "heaven director: 'make it taller' -> set h x1.25")
	t.check(HeavenDirector.parse("paint it gold", spot, piece).get("color") == "#f0c35a", "heaven director: colours")
	t.check(HeavenDirector.parse("remove this", spot, piece).get("op") == "remove", "heaven director: remove")
	t.check(HeavenDirector.parse("remove this", spot).has("error"), "heaven director: remove needs a pointed piece")
	t.check(HeavenDirector.parse("add a sign saying Hello Heaven", spot).get("text") == "Hello Heaven", "heaven director: sign text")
	t.check(HeavenDirector.parse("make magic", spot).has("error"), "heaven director: unknown request explains what it can add")

static func run_docs(t: Node) -> void:
	var plan := FileAccess.get_file_as_string("res://docs/VOXEL_WORLD_PLAN.md")
	t.check(plan.contains("Heaven Welcome Island") and plan.contains("persistent server"), "heaven docs: plan + 24/7 persistent-server note")
	t.check(FileAccess.get_file_as_string("res://docs/specs/foxy/HEAVEN_CLIENT.md").contains("heaven_edit"), "heaven docs: Foxy client spec")
	var csv := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	t.check(csv.contains("HEAVEN-1") and csv.contains("HEAVEN-6") and not csv.contains("\r"), "heaven docs: tracker rows (LF)")
	t.check(FileAccess.get_file_as_string("res://docs/modules/VIEWER_PARITY.md").contains("Heaven"), "heaven docs: viewer parity")

static func run_scene(t: Node) -> void:
	var ui := HeavenScreen.new()
	t.add_child(ui)
	await t.get_tree().process_frame
	var ok := true
	for p in HeavenScreen.PAGES:
		ui.go(p)
		if ui.body.get_child_count() == 0: ok = false
	t.check(ok, "heaven screen: every page renders")
	ui.go("direct")
	ui.set_spot(HeavenLayout.spawn_point())
	var r := ui.ask("put a lamp here")
	t.check(not r.has("error") and r.get("state", "") == "pending", "heaven screen: locked Direct a change -> proposal")
	ui.queue_free()
	var wp := WorldPicker.new()
	t.add_child(wp)
	await t.get_tree().process_frame
	t.check(wp.find_child("Enter_heaven", true, false) != null, "world picker: renders grids")
	wp.queue_free()
