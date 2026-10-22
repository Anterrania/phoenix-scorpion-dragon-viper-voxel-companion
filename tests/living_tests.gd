extends RefCounted
## LIFE- tests: survival, disease, genome, governance, geology/materials/blueprints, land addressing.

static func _setup(root: String) -> void:
	load("res://tests/viewer_tests.gd")._setup(root)
	Governance.reset_for_tests(root.path_join("living")); Blueprints.reset_for_tests(root.path_join("living"))
	Disease.reset_for_tests(root.path_join("living"))
	LivingGate.reset_cache(); Genome.reset_cache(); Geology.reset_cache(); Materials.reset_cache()

static func _teardown(t: Node, root: String, sv: String, se: String) -> void:
	load("res://tests/viewer_tests.gd")._teardown(root, sv, se)
	Governance.reset_for_tests("user://living"); Blueprints.reset_for_tests("user://living")
	Disease.reset_for_tests("user://living")
	var s := t.get_node_or_null("/root/Survival")
	if s: s.reset_for_tests("user://living")

static func run(t: Node) -> void:
	var root := "user://test_living_%d" % Time.get_ticks_usec()
	var sv := OwnerVault.root; var se := AutonomyGuard.path
	_setup(root)
	var S: Node = t.get_node_or_null("/root/Survival")
	t.check(S != null and S.has_signal("vitals_changed"), "living: Survival autoload with vitals_changed")
	S.reset_for_tests(root.path_join("living"))
	var O := Tiers.OWNER_ID
	Tiers.owner_override = true
	t.check(Tiers.set_tier("l_res", "resident") == "" and Tiers.set_tier("l_mgr", "estate_manager") == "" and Tiers.set_tier("l_cre", "creator") == "" and Tiers.set_tier("l_res2", "resident") == "", "living: tiers set")
	Tiers.owner_override = false

	# ---------- realm defaults + estate flag ----------
	t.check(LivingGate.mode("alaskan_tundra") == "on" and LivingGate.mode("venus_fire") == "on" and LivingGate.mode("cosmic") == "on", "gate: survival realms default on")
	t.check(LivingGate.mode("cyberpunk") == "softcore", "gate: cyberpunk softcore")
	t.check(LivingGate.mode("club") == "off" and LivingGate.mode("some_home") == "off", "gate: social/club/home default off")
	t.check(LivingGate.set_mode("l_res", "alaskan_tundra", "off") != "", "gate: resident can't change survival flag")
	t.check(LivingGate.set_mode(O, "alaskan_tundra", "off") != "", "gate: LOCKED owner can't change flag")
	t.check(LivingGate.set_mode("l_mgr", "my_reg", "on") == "" and LivingGate.mode("my_reg") == "on", "gate: estate manager sets flag")
	t.check(LivingGate.set_realm("l_mgr", "my_reg", "venus_fire") == "" and LivingGate.realm_of("my_reg") == "venus_fire", "gate: realm per region")
	t.check(not LivingGate.exempt(O), "gate: locked owner NOT exempt")
	Tiers.owner_override = true
	t.check(LivingGate.exempt(O) and not LivingGate.exempt("l_res"), "gate: unlocked owner exempt, others not")
	Tiers.owner_override = false

	# ---------- environment ----------
	var vf := WorldEnv.outdoor("venus_fire", 0.0)
	var vd := WorldEnv.outdoor("venus_fire", -100.0)
	t.check(vd["pressure_kpa"] > 9000 and vd["temp_c"] > 400 and vf["pressure_kpa"] < 200, "env: Venus deep crushing/hot, cloud deck ~1 bar")
	t.check(WorldEnv.outdoor("cosmic")["vacuum"] and WorldEnv.outdoor("cosmic")["pressure_kpa"] < 1, "env: space is vacuum")
	var hab := WorldEnv.personal(WorldEnv.outdoor("cosmic"), {"shelter": "habitat", "powered": true})
	t.check(hab["pressure_kpa"] > 90 and hab["o2_kpa"] > 18, "env: powered habitat holds air")

	# ---------- survival ----------
	var cold: Dictionary = S.tick_actor("l_res", "alaskan_tundra", {"t01": 0.0}, 6.0)
	t.check(cold["calories"] < 2500 and cold["hydration"] < 100 and cold["fatigue"] > 0, "survival: food/water/fatigue drain")
	var vac: Dictionary = S.tick_actor("l_res2", "cosmic", {}, 0.5)
	t.check("pressure" in vac["alerts"] and vac["state"] in ["critical", "incapacitated"], "survival: vacuum without suit is critical")
	S.refill_suit("l_res2", 8.0); S.recover("l_res2")
	var suited: Dictionary = S.tick_actor("l_res2", "cosmic", {"suit": "pressure_suit"}, 0.5)
	t.check(not "pressure" in suited["alerts"] and suited["suit_o2_h"] < 8.0, "survival: pressure suit protects, tank drains")
	var club: Dictionary = S.tick_actor("l_res", "club", {}, 10.0)
	t.check(club["calories"] == cold["calories"] and club["mode"] == "off", "survival: off regions don't drain")
	var got := []
	S.vitals_changed.connect(func(id, _v): got.append(id))
	S.tick_actor(O, "venus_fire", {}, 0.0)
	var lockedv: Dictionary = S.tick_actor(O, "cosmic", {}, 1.0)
	t.check(not lockedv["exempt"] and "pressure" in lockedv["alerts"], "survival: locked owner gets survival rules")
	Tiers.owner_override = true
	var god: Dictionary = S.tick_actor(O, "venus_fire", {}, 24.0)
	t.check(god["exempt"] and god["health"] == 100.0 and god["alerts"].is_empty(), "survival: unlocked owner exempt")
	Tiers.owner_override = false
	t.check(got.size() > 0 and S.vitals("l_res").has("o2_sat"), "survival: vitals() + vitals_changed fire")
	var soft: Dictionary = S.tick_actor("l_res", "cyberpunk", {}, 1000.0)
	t.check(soft["health"] >= 10.0, "survival: softcore never drops below 10 health")
	AutonomyGuard.engage("test")
	t.check(AutonomyGuard.paused(), "living: e-stop engaged")
	if AutonomyGuard.paused():
		var bot := "bot:tester"
		var b0: Dictionary = S.tick_actor(bot, "alaskan_tundra", {}, 0.0)
		var b1: Dictionary = S.tick_actor(bot, "alaskan_tundra", {}, 5.0)
		t.check(b1["calories"] == b0["calories"], "survival: e-stop freezes bots")
		t.check(not Disease.expose(bot, "common_cold", "alaskan_tundra", 0.0, 24.0), "disease: e-stop freezes bot infection")
		Tiers.owner_override = true; AutonomyGuard.release(); Tiers.owner_override = false
	S.set_region_active("alaskan_tundra", true)
	t.check(S.active_regions() == ["alaskan_tundra"], "survival: only active regions tick")
	S.set_region_active("alaskan_tundra", false)

	# ---------- disease ----------
	t.check(Disease.expose("l_res", "common_cold", "alaskan_tundra", 0.0, 24.0), "disease: exposure infects")
	t.check(not Disease.expose("l_res", "common_cold", "club", 0.0, 24.0), "disease: no infection when survival off")
	t.check(Disease.cases("l_res")["common_cold"]["stage"] == "incubating", "disease: incubation first")
	Disease.advance("l_res", 48.0)
	t.check(Disease.is_contagious("l_res") and not Disease.symptoms("l_res").is_empty(), "disease: sick + contagious after incubation")
	t.check(Disease.contact("l_res", "l_res2", "alaskan_tundra", 24.0, 0.0) == ["common_cold"], "disease: spreads by contact")
	t.check(Disease.treat("l_res", "common_cold", "cold_remedy") == "", "disease: treatment works")
	Disease.advance("l_res", 24.0 * 30)
	t.check(Disease.cases("l_res").is_empty(), "disease: recovers")
	t.check(Disease.vaccinate("l_mgr", "shiver_vaccine", 0.0) == "" and Disease.is_immune("l_mgr", "shiver_fever"), "disease: vaccine gives immunity")
	t.check(not Disease.expose("l_mgr", "shiver_fever", "alaskan_tundra", 0.0, 24.0), "disease: immune can't catch it")
	Tiers.owner_override = true
	t.check(not Disease.expose(O, "common_cold", "alaskan_tundra", 0.0, 99.0), "disease: unlocked owner exempt")
	Tiers.owner_override = false
	var sir := [990.0, 10.0, 0.0]
	for i in 200: sir = Disease.sir_step(sir[0], sir[1], sir[2], 0.5, 0.2, 0.5)
	t.check(absf(sir[0] + sir[1] + sir[2] - 1000.0) < 0.01 and sir[2] > 500.0, "disease: SIR conserves N, epidemic burns through at R0 2.5")
	t.check(Disease.r0("common_cold") > 1.0, "disease: cold R0 > 1")

	# ---------- genome (creatures only, non-sexual combine) ----------
	var ew := Genome.of_species("ember_wyrm"); var fw := Genome.of_species("frost_wyrm")
	t.check(not ew.is_empty() and Genome.for_persona({"id": "foxy"}).is_empty(), "genome: species have genomes, personas never")
	t.check(Genome.compatible(ew, fw) == "", "genome: same genus compatible")
	t.check(Genome.compatible(ew, Genome.of_species("voidbear")) != "", "genome: other genus incompatible")
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var kid := Genome.combine(ew, fw, rng)
	t.check(not kid.is_empty() and int(kid.get("generation", 0)) >= 1, "genome: combine yields offspring genome")
	t.check(Genome.from_record({"species": "ember_wyrm"}).size() > 0, "genome: old saves without genome still load")
	t.check("emberstrand" in Genome.spawnable("venus_fire"), "genome: acid-cloud extremophile viable on Venus cloud deck")
	t.check(not Genome.viability(Genome.of_species("tundra_leaper"), WorldEnv.outdoor("venus_fire", -100.0))["ok"], "genome: tundra animal not viable on Venus surface")
	t.check("frostcoil_worm" in Genome.spawnable("alaskan_glacier"), "genome: ice worm spawns on glacier")

	# ---------- governance ----------
	t.check(not Governance.found("l_res", "Aurora League", "republic")["ok"], "gov: resident can't found")
	t.check(not Governance.found("l_cre", "France Reborn", "republic")["ok"], "gov: real-world names refused")
	var nf := Governance.found("l_cre", "Aurora League", "republic")
	t.check(nf["ok"], "gov: creator founds nation")
	var N: String = nf.get("id", "")
	t.check(not Governance.claim("l_cre", N, "gov_reg")["ok"], "gov: claim needs estate land rights")
	Tiers.owner_override = true
	t.check(Governance.found(O, "Phoenix Crown", "monarchy")["ok"], "gov: owner founds")
	t.check(Governance.grant_citizenship("l_cre", N, "l_res")["ok"] and Governance.grant_citizenship(O, N, "l_res2")["ok"], "gov: citizenship")
	t.check(Governance.claim(O, N, "gov_reg")["ok"] and Governance.nation_at("gov_reg") == N, "gov: owner claims for nation")
	Tiers.owner_override = false
	t.check(Governance.set_law("l_cre", N, "mining", false)["ok"] and not Governance.law_allows("l_res", "gov_reg", "mining"), "gov: law toggle per territory")
	Tiers.owner_override = true
	t.check(Governance.law_allows(O, "gov_reg", "mining"), "gov: unlocked owner exempt from laws")
	Tiers.owner_override = false
	t.check(not Governance.law_allows(O, "gov_reg", "mining"), "gov: locked owner bound by laws")
	t.check(not Governance.set_tax("l_cre", N, "sales", 5, "aethel_coin")["ok"], "gov: Aethel Coin tax LEGAL REVIEW refused")
	t.check(Governance.set_tax("l_cre", N, "sales", 10)["ok"] and Governance.tax_due("l_res", "gov_reg", "sales", 100) == 10, "gov: civic credit tax hook")
	t.check(not Governance.set_tax("l_cre", N, "sales", 90)["ok"], "gov: tax capped")
	var el := Governance.start_election("l_cre", N, "leader", ["l_cre", "l_res"])
	t.check(el["ok"], "gov: election starts")
	t.check(Governance.vote("l_res", N, el["id"], "l_res")["ok"] and Governance.vote("l_res2", N, el["id"], "l_res")["ok"], "gov: citizens vote")
	t.check(not Governance.vote("l_res", N, el["id"], "l_cre")["ok"] and not Governance.vote("l_mgr", N, el["id"], "l_cre")["ok"], "gov: one vote, citizens only")
	var res := Governance.close_election("l_cre", N, el["id"])
	t.check(res["winner"] == "l_res" and Governance.nation(N)["leader"] == "l_res", "gov: winner becomes leader")
	t.check(Governance.set_border("l_res", N, "visa")["ok"] and Governance.can_cross("l_mgr", "gov_reg") != "" and Governance.can_cross("l_res2", "gov_reg") == "", "gov: visa border")
	t.check(Governance.grant_visa("l_res", N, "l_mgr")["ok"] and Governance.can_cross("l_mgr", "gov_reg") == "", "gov: visa grants entry")
	var N2: String = Governance.found("l_mgr", "Ember Accord", "council")["id"]
	t.check(Governance.request_embassy("l_mgr", N2, N)["ok"] and Governance.accept_embassy("l_res", N, N2)["ok"] and N in Governance.nation(N2)["embassies"], "gov: embassies")

	# ---------- geology + materials + blueprints ----------
	var sv1 := Geology.survey("alaskan_tundra", Vector3i(0, -200, 0), Vector3i(256, 200, 256), 0)
	t.check(sv1.has("hematite_ore") and sv1.has("quartz") and not sv1.has("emberite"), "geo: tundra ores by realm")
	t.check(Geology.deposit_at("alaskan_tundra", 3, 5, 3, 0) == "", "geo: nothing above ground")
	t.check(Geology.deposit_at("cosmic", 10, -50, 10, 0, 9) == Geology.deposit_at("cosmic", 10, -50, 10, 0, 9), "geo: deterministic")
	var gen = load("res://scripts/generators/biome_voxel_generator.gd").new(1337)
	t.check(gen.has_method("ore_at") and gen.ore_at(5, 500, 5) == "", "geo: generator ore_at hook")
	t.check(Materials.validate_graph().is_empty(), "mat: recipe graph closed: %s" % [Materials.validate_graph()])
	var rc := Materials.raw_cost("habitat_module")
	t.check(not rc.is_empty() and rc.keys().all(func(k): return Geology.ores().has(k)), "mat: build cost expands to raw ores")
	var inv := {"steel": 2}
	t.check(not Materials.craft("l_res", "wall_panel", inv, "assembler")["ok"] and inv["steel"] == 2, "mat: blueprint needed, nothing consumed")
	var bp := Blueprints.create("l_cre", "wall_panel")
	t.check(bp["ok"] and not Blueprints.create("l_res", "wall_panel")["ok"], "bp: creators author blueprints")
	t.check(Blueprints.make_copy("l_cre", bp["id"], 1, "l_res")["ok"], "bp: copy made")
	var cid: String = Blueprints.owned_by("l_res")[0]
	t.check(not Materials.craft("l_res", "wall_panel", inv, "hands", 1, cid)["ok"], "mat: needs station")
	var cr := Materials.craft("l_res", "wall_panel", inv, "assembler", 1, cid)
	t.check(cr["ok"] and inv.get("steel", 0) == 0 and inv["wall_panel"] == 1 and Blueprints.item(cid).is_empty(), "mat: craft consumes inputs and copy runs")
	t.check(not Blueprints.list_for_sale("l_cre", bp["id"], 10, "aethel_coin")["ok"] and not Blueprints.AEC_PAYOUTS and not Blueprints.CASH_OUT, "bp: Aethel Coin sales/payouts LEGAL REVIEW off")
	var ls := Blueprints.list_for_sale("l_cre", bp["id"], 5, "civic_credit", "copy", 3)
	t.check(ls["ok"] and not Blueprints.list_for_sale("l_res", bp["id"], 5)["ok"], "bp: fixed-price listing (creator tier)")
	t.check(not Blueprints.buy("l_res2", ls["id"])["ok"], "bp: need credits")
	Blueprints.earn_credits("l_res2", 20)
	var b := Blueprints.buy("l_res2", ls["id"])
	t.check(b["ok"] and Blueprints.credits("l_res2") == 15 and Blueprints.credits("l_cre") == 5 and Blueprints.item(b["id"])["runs"] == 3, "bp: buy copy for civic credits")
	var nt := Blueprints.create("l_cre", "window_panel", {"copy": false, "modify": false, "transfer": false})
	Blueprints.give("l_cre", nt["id"], "l_res")
	t.check(Blueprints.give("l_res", nt["id"], "l_res2") != "" and Blueprints.make_copy("l_res", nt["id"], 1)["ok"] == false, "bp: no-transfer / no-copy enforced on next owner")
	Estate.region_set("mine_reg", "realm", "alaskan_tundra"); Estate.region_set("mine_reg", "terraform", "everyone")
	var minv := {}
	var dug := 0
	for x in 64:
		var m := Materials.mine("l_res", "mine_reg", Vector3(x * 4, -40, 8), 0, minv)
		if m["ok"]: dug += 1
	t.check(dug == 64 and not minv.is_empty(), "mat: resident mines where estate allows")
	t.check(not Materials.mine("stranger_x", "own_reg", Vector3(1, -10, 1), 0, {})["ok"], "mat: guests can't mine owner land")
	t.check(Materials.export_to_industry("l_res", {}) == 0 or Materials.industry_script() != null, "mat: Industry bridge safe when absent")

	# ---------- land ----------
	t.check(Land.object_cap("l_res", "mine_reg") == Land.UNLIMITED and Land.object_cap("stranger_x", "own_reg") == 0, "land: no object caps where build allowed")
	t.check(Land.render_budget("low")["view_m"] < Land.render_budget("ultra")["view_m"], "land: render budgets per viewer tier")
	var far := Land.from_world(Vector3(1.0e9, -5.0, -3.5e9))
	t.check(far["local"].x >= 0 and far["local"].x < Land.SECTOR_M and far["local"].z < Land.SECTOR_M, "land: sector+local normalized")
	var near := Land.add(far, Vector3(0.25, 0, 0))
	t.check(absf(Land.distance(far, near) - 0.25) < 0.001, "land: cm precision a billion metres out")
	t.check(Land.rebase(near, near["sector"]).length() < Land.SECTOR_M * 2, "land: rebase near origin")
	var addr := Land.address("earth", far)
	var pa := Land.parse_address(addr)
	t.check(pa["planet"] == "earth" and pa["sector"] == far["sector"], "land: planet/region/chunk address round-trips")
	var pg := SectorPager.new(1, 4)
	pg.set_viewer("a", Vector3i(0, 0, 0))
	t.check(pg.active.size() == 27 and pg.is_active(Vector3i(1, 1, 1)), "pager: radius cube active")
	pg.set_viewer("a", Vector3i(100, 0, 0))
	t.check(not pg.is_active(Vector3i(0, 0, 0)) and pg.cache.size() == 4 and pg.unloads == 23, "pager: LRU cache bounded")
	pg.remove_viewer("a")
	t.check(pg.active.is_empty(), "pager: no viewers, nothing active")

	_teardown(t, root, sv, se)

static func run_docs(t: Node) -> void:
	for p in ["res://docs/modules/LIVING_WORLD.md", "res://docs/modules/SURVIVAL.md", "res://docs/modules/GOVERNANCE.md", "res://docs/modules/MINING_AND_MATERIALS.md"]:
		t.check(FileAccess.file_exists(p), "docs: %s exists" % p)
	t.check(FileAccess.get_file_as_string("res://docs/modules/MINING_AND_MATERIALS.md").contains("LEGAL REVIEW"), "docs: blueprint sales LEGAL REVIEW noted")
	var spec := FileAccess.get_file_as_string("res://docs/specs/foxy/LIVING_WORLD_CLIENT.md")
	t.check(spec.contains("owner=Foxy"), "docs: Foxy client spec")
	t.check(FileAccess.get_file_as_string("res://docs/modules/VIEWER_PARITY.md").contains("Living world parity"), "docs: parity section")

static func run_dormancy(t: Node) -> void:
	var S: Node = t.get_node("/root/Survival")
	var root := "user://test_living_dorm_%d" % Time.get_ticks_usec()
	var sv := OwnerVault.root; var se := AutonomyGuard.path
	_setup(root); S.reset_for_tests(root.path_join("living")); Dormancy.reset_for_tests(); Ecology.reset_for_tests()
	Tiers.owner_override = true; Tiers.set_tier("d_res", "resident"); Tiers.owner_override = false
	t.check(S.tick_interval() >= S.TICK_S, "dormancy: sim tick respects PowerData budget (>= TICK_S)")
	S.register_region("alaskan_tundra", Vector3.ZERO, 50.0)
	S.track("d_res", "alaskan_tundra", {})
	Ecology.seed_region("alaskan_tundra", {"tundra_leaper": 10.0, "emberstrand": 10.0})
	Dormancy.update([Vector3(5000, 0, 0)], 0.0)
	Dormancy.update([Vector3(5000, 0, 0)], 20.0)
	t.check(Dormancy.is_dormant("living:alaskan_tundra"), "dormancy: region with no viewer sleeps")
	var before: Dictionary = S.vitals("d_res")
	Dormancy.update([Vector3(1, 0, 0)], 20.0 + 6.0 * 3600.0)   # 6 real hours away
	var after: Dictionary = S.vitals("d_res")
	t.check(not Dormancy.is_dormant("living:alaskan_tundra") and float(after["calories"]) < float(before["calories"]), "dormancy: one-step survival catch-up on wake")
	var pop := Ecology.population("alaskan_tundra")
	t.check(float(pop.get("tundra_leaper", 0)) > 10.0 and float(pop.get("emberstrand", 0)) < 10.0, "ecology: viable species grow, unfit decline in catch-up")
	t.check(absf(Ecology.logistic(10, 100, 0.05, 1e6) - 100.0) < 0.01, "ecology: logistic saturates at K")
	S.unregister_region("alaskan_tundra"); Dormancy.reset_for_tests(); Ecology.reset_for_tests()
	_teardown(t, root, sv, se)
