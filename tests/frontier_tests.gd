extends RefCounted
## Frontier space-sim systems (SPACE-1..9): Tiers actions, OrgRights on Social groups, OrderBook,
## ContractsBoard, Industry, Territory x Estate, ShipRegistry + insurance gating, ShardModel meshing,
## ComfortPrefs, FrontierScreen, docs/wiki/tracker. Throwaway roots; restores every static it touches.

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static var _t := 1_800_000_000

static func run(t: Node) -> void:
	var root := "user://test_frontier_%d" % Time.get_ticks_usec()
	var saved_vault := OwnerVault.root
	var saved_estop := AutonomyGuard.path
	var had_estate := FileAccess.file_exists(Estate.PATH)
	var estate_raw := FileAccess.get_file_as_bytes(Estate.PATH) if had_estate else PackedByteArray()
	BrainCore.adapter_root = root.path_join("brains")
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(root.path_join("security/estop.json"))
	var saved_eve := EveCore.save_dir
	EveCore.save_dir = root.path_join("eve"); EveCore.reset_cache()
	Tiers.reset_for_tests(root.path_join("social"))
	Social.reset_for_tests(root.path_join("social"))
	FrontierStore.reset_for_tests(root.path_join("frontier"))
	FrontierStore.clock = func(): return _t
	Estate.reset_for_tests(); Estate._cfg = ConfigFile.new()
	Tiers.owner_override = true
	for pair in [["f_res", "resident"], ["f_res2", "resident"], ["f_cre", "creator"], ["f_cre2", "creator"], ["f_staff", "staff"], ["f_mgr", "estate_manager"]]:
		Tiers.set_tier(pair[0], pair[1])
	Tiers.owner_override = false

	# ---------- tiers ----------
	t.check(Tiers.can("f_res", "trade") and Tiers.can("f_res", "contract") and Tiers.can("f_res", "industry") and Tiers.can("f_res", "ship_own"), "frontier tiers: residents trade, contract, industry, own ships")
	t.check(not Tiers.can("stranger", "trade") and not Tiers.can("stranger", "ship_own"), "frontier tiers: guests browse only")
	t.check(not Tiers.can("f_res", "territory") and Tiers.can("f_cre", "territory"), "frontier tiers: land claims need creator")
	t.check(not Tiers.can("f_cre", "mission_create") and Tiers.can("f_staff", "mission_create"), "frontier tiers: missions need staff")
	t.check(Tiers.SPACE_ACTIONS.all(func(a): return a in Tiers.ACTIONS), "frontier tiers: actions registered in Tiers.ACTIONS")

	# ---------- orgs (extend Social groups) ----------
	var g: String = Social.group_create("f_cre", "Ember Corp", {"tag": "EMB"})["id"]
	Social.group_join("f_res", g); Social.group_join("f_res2", g)
	t.check(OrgRights.rights_of(g, "f_cre").size() == OrgRights.RIGHTS.size(), "orgs: group owner holds every right")
	t.check(OrgRights.rights_of(g, "f_res").is_empty() and not OrgRights.has("f_res", g, "trade"), "orgs: plain member has no extra rights")
	t.check(not OrgRights.set_title("f_res", g, "Hauler", ["trade"])["ok"], "orgs: members can't define titles")
	t.check(OrgRights.set_title("f_cre", g, "Hauler", ["trade", "pilot", "bogus"])["ok"] and OrgRights.titles(g)["Hauler"] == ["trade", "pilot"], "orgs: owner defines a title; unknown rights dropped")
	t.check(OrgRights.assign_title("f_cre", g, "f_res", "Hauler")["ok"] and OrgRights.has("f_res", g, "trade") and not OrgRights.has("f_res", g, "factory"), "orgs: title grants its rights only")
	Social.group_set_role("f_cre", g, "f_res2", "officer")
	OrgRights.set_title("f_cre", g, "Director", ["manage_titles", "kick"])
	t.check(not OrgRights.assign_title("f_res2", g, "f_res", "Director")["ok"], "orgs: officers can't grant manage-titles titles")
	t.check(OrgRights.has("f_res2", g, "factory") and not OrgRights.has("f_res2", g, "wallet_take"), "orgs: officer defaults")
	t.check(not OrgRights.add_policy("f_res2", g, "all", ["mine"], ["north"])["ok"], "orgs: policies need manage_titles")
	t.check(OrgRights.add_policy("f_cre", g, "member:f_res2", ["mine"], ["north"])["ok"], "orgs: owner adds a tag policy")
	t.check(OrgRights.allowed("f_res2", g, ["north"], "mine") and not OrgRights.allowed("f_res2", g, ["south"], "mine") and not OrgRights.allowed("stranger", g, ["north"], "mine"), "orgs: policy applies by actor + tag only")
	t.check(not OrgRights.add_policy("f_cre", g, "all", ["wallet_take"], ["north"])["ok"], "orgs: wallet/kick rights can't go in policies")
	var g2: String = Social.group_create("f_cre2", "Frost Guild")["id"]
	var al := OrgRights.alliance_create("f_cre", g, "Phoenix Accord")
	t.check(al["ok"] and OrgRights.alliance_of(g) == al["id"], "orgs: alliance created by org owner")
	t.check(not OrgRights.alliance_join("f_cre2", al["id"], g2)["ok"], "orgs: alliance join needs an invite")
	t.check(OrgRights.alliance_invite("f_cre", al["id"], g2)["ok"] and OrgRights.alliance_join("f_cre2", al["id"], g2)["ok"] and OrgRights.alliances()[al["id"]]["members"].size() == 2, "orgs: invite + join")
	t.check(OrgRights.alliance_leave("f_cre", g)["ok"] and OrgRights.alliances()[al["id"]]["executor"] == g2, "orgs: executor passes on when it leaves")

	# ---------- market ----------
	t.check(not OrderBook.place("stranger", "sell", "ferrite_plate", 10, 5)["ok"], "market: guests can't trade")
	var s1 := OrderBook.place("f_res", "sell", "ferrite_plate", 10, 5)
	t.check(s1["ok"] and s1["fills"].is_empty() and s1["order"]["broker_fee"] >= 1 and s1["legal"].contains("LEGAL REVIEW REQUIRED"), "market: resting sell order pays broker fee; legal note")
	OrderBook.place("f_res2", "sell", "ferrite_plate", 5, 4)
	var b1 := OrderBook.place("f_cre", "buy", "ferrite_plate", 8, 6, {"days": 0})
	t.check(b1["ok"] and b1["fills"].size() == 2 and b1["fills"][0]["price"] == 4 and b1["fills"][0]["qty"] == 5 and b1["fills"][1]["price"] == 5 and b1["fills"][1]["qty"] == 3, "market: best price first, partial fills at resting price")
	t.check(b1["fills"][0]["settlement"] == "pending_legal_review" and not OrderBook.SETTLEMENT_ACTIVE, "market: settlement off (legal review)")
	t.check(b1["order"]["state"] == "filled" and b1["order"]["broker_fee"] == 0, "market: immediate order, no broker fee")
	var bk := OrderBook.book("ferrite_plate")
	t.check(bk["asks"].size() == 1 and bk["asks"][0]["qty"] == 7 and bk["bids"].is_empty(), "market: book shows the rest")
	t.check(OrderBook.place("f_res", "buy", "ferrite_plate", 3, 9)["fills"].is_empty(), "market: no self-matching")
	t.check(not OrderBook.cancel("f_res2", s1["order"]["id"])["ok"] and OrderBook.cancel("f_res", s1["order"]["id"])["ok"], "market: only the owner cancels")
	Social.group_join("f_cre2", g)
	t.check(not OrderBook.place("f_cre2", "buy", "x", 1, 1, {"org": g})["ok"], "market: org orders need the org trade right")
	t.check(OrderBook.place("f_res", "buy", "x", 1, 1, {"org": g})["ok"], "market: titled member places org order")
	t.check(not OrderBook.place("f_res", "sell", "x", 0, 1)["ok"] and not OrderBook.place("f_res", "hold", "x", 1, 1)["ok"], "market: validates qty and side")
	_t += 15 * 86400
	t.check(OrderBook.expire() >= 1 and OrderBook.book("ferrite_plate")["bids"].is_empty(), "market: orders expire")

	# ---------- contracts ----------
	t.check(not ContractsBoard.post("f_res", {"kind": "mission", "title": "Patrol"})["ok"], "contracts: residents can't post missions")
	var cour := ContractsBoard.post("f_res", {"kind": "courier", "title": "Move plates", "from": "welcome", "to": "venus", "reward": 50, "collateral": 200})
	t.check(cour["ok"] and cour["legal"].contains("LEGAL REVIEW REQUIRED"), "contracts: courier posted with legal note")
	t.check(not ContractsBoard.post("f_res", {"kind": "courier", "title": "x"})["ok"], "contracts: courier needs from/to")
	t.check(not ContractsBoard.accept("f_res", cour["id"])["ok"] and not ContractsBoard.accept("stranger", cour["id"])["ok"], "contracts: can't take own; guests can't take")
	t.check(ContractsBoard.accept("f_res2", cour["id"])["state"] == "in_progress", "contracts: courier accepted")
	t.check(not ContractsBoard.complete("f_res2", cour["id"])["ok"] and ContractsBoard.complete("f_res", cour["id"])["state"] == "completed", "contracts: issuer confirms delivery")
	var priv := ContractsBoard.post("f_res", {"kind": "item_exchange", "title": "Lens swap", "availability": "private:f_cre"})
	t.check(ContractsBoard.board("f_res2").all(func(c): return c["id"] != priv["id"]) and ContractsBoard.board("f_cre").any(func(c): return c["id"] == priv["id"]), "contracts: private contracts only for their target")
	t.check(ContractsBoard.accept("f_cre", priv["id"])["state"] == "completed", "contracts: item exchange completes on accept")
	var auc := ContractsBoard.post("f_cre", {"kind": "auction", "title": "Rare core", "reward": 100, "days": 1})
	t.check(not ContractsBoard.bid("f_res", auc["id"], 50)["ok"] and ContractsBoard.bid("f_res", auc["id"], 100)["ok"] and not ContractsBoard.bid("f_res2", auc["id"], 100)["ok"] and ContractsBoard.bid("f_res2", auc["id"], 120)["ok"], "contracts: auction bids must rise")
	_t += 2 * 86400
	ContractsBoard.sweep()
	t.check(ContractsBoard.get_contract(auc["id"])["state"] == "completed" and ContractsBoard.get_contract(auc["id"])["taker"] == "f_res2", "contracts: auction closes to top bidder")
	var mis := ContractsBoard.post("f_staff", {"kind": "mission", "title": "Survey the tundra", "faction": "Aurora Wardens", "rep": 12})
	ContractsBoard.accept("f_res", mis["id"])
	t.check(ContractsBoard.complete("f_res", mis["id"], true)["ok"] and ContractsBoard.reputation("f_res", "Aurora Wardens")["value"] == 12 and ContractsBoard.reputation("f_res", "Aurora Wardens")["rank"] == "Known", "contracts: mission completion grants reputation")
	Social.block("f_res2", "f_staff")
	var mis2 := ContractsBoard.post("f_staff", {"kind": "mission", "title": "Escort"})
	t.check(not ContractsBoard.accept("f_res2", mis2["id"])["ok"], "contracts: blocks apply")

	# ---------- industry ----------
	t.check(Industry.recipes().has("ferrite_plate") and Industry.recipes().has("jump_coil"), "industry: recipes load")
	t.check(not Industry.add_materials("f_res", "f_res", "ferrite_ore", 100)["ok"] and Industry.add_materials("f_staff", "f_res", "ferrite_ore", 9)["ok"], "industry: only system/staff add materials")
	t.check(not Industry.start("f_res", "manufacture", "ferrite_plate", {"runs": 3})["ok"], "industry: missing materials refused")
	var j1 := Industry.start("f_res", "manufacture", "ferrite_plate", {"runs": 2})
	t.check(j1["ok"] and Industry.stock("f_res").get("ferrite_ore", 0) == 1 and j1["seconds"] == 120, "industry: job consumes inputs, timed")
	t.check(not Industry.start("f_res", "manufacture", "hull_frame")["ok"], "industry: blueprint recipes need a blueprint")
	t.check(Industry.collect("f_res")["delivered"].is_empty(), "industry: not ready yet")
	_t += 121
	t.check(Industry.collect("f_res")["delivered"].size() == 1 and Industry.stock("f_res")["ferrite_plate"] == 2, "industry: collect delivers outputs")
	var bp: String = Industry.grant_blueprint("system", "f_res", "hull_frame")["id"]
	t.check(Industry.start("f_res", "research_me", "hull_frame", {"blueprint": bp})["ok"], "industry: research ME started")
	t.check(not Industry.start("f_res", "copy", "hull_frame", {"blueprint": bp})["ok"], "industry: busy blueprint can't double-book")
	t.check(not Industry.start("f_res", "manufacture", "ferrite_plate")["ok"], "industry: slots by tier (resident 2)")
	_t += 10000
	Industry.collect("f_res")
	t.check(Industry.blueprints("f_res")[0]["me"] == 1 and Industry.inputs_for("hull_frame", 10, 10)["ferrite_plate"] == 90, "industry: ME level reduces inputs")
	Industry.start("f_res", "copy", "hull_frame", {"blueprint": bp, "runs": 2})
	_t += 10000; Industry.collect("f_res")
	var copy: Dictionary = Industry.blueprints("f_res").filter(func(b): return b["kind"] == "copy")[0]
	t.check(copy["runs"] == 2 and copy["me"] == 1, "industry: copy keeps research, limited runs")
	t.check(not Industry.start("f_res", "research_te", "hull_frame", {"blueprint": copy["id"]})["ok"], "industry: copies can't be researched")
	t.check(not Industry.start("f_res2", "manufacture", "ferrite_plate", {"org": g})["ok"], "industry: org jobs need factory right")

	# ---------- territory x estate ----------
	Estate.region_set("fr_reg", "allow_build", true)
	t.check(not Territory.claim("f_cre", "fr_reg", "1_1")["ok"], "land: closed region refuses claims")
	t.check(not Territory.set_claims_open("f_cre", "fr_reg", true)["ok"] and Territory.set_claims_open("f_mgr", "fr_reg", true)["ok"], "land: estate manager opens a region")
	t.check(not Territory.claim("f_res", "fr_reg", "1_1")["ok"], "land: residents can't claim")
	var cl := Territory.claim("f_cre", "fr_reg", "1_1")
	t.check(cl["ok"] and Territory.claim_of("fr_reg", "1_1")["state"] == "active", "land: creator claims a parcel")
	t.check(not Territory.claim("f_cre2", "fr_reg", "1_1")["ok"], "land: no double claims")
	t.check(Tiers.can("f_cre", "build", "fr_reg/1_1") and not Tiers.can("f_cre2", "build", "fr_reg/1_1"), "land: claim holder builds via Tiers + Estate")
	t.check(Territory.claim("f_cre", "fr_reg", "2_2", "org:" + g, ["north"])["ok"] and Tiers.land_group({"region": "fr_reg", "parcel": "2_2"}) == g, "land: org claim sets the Estate group")
	t.check(Territory.can("f_res2", "mine", "fr_reg", "2_2") and not Territory.can("f_cre2", "mine", "fr_reg", "2_2"), "land: org policies grant mining on tagged claims")
	t.check(Territory.sovereign("fr_reg") != "", "land: sovereignty by claim share")
	t.check(not Territory.contest("f_staff", "fr_reg", "1_1")["ok"], "land: safe land can't be contested")
	Estate.region_set("fr_reg", "allow_damage", true)
	t.check(Territory.contest("f_staff", "fr_reg", "1_1")["ok"] and Territory.claim_of("fr_reg", "1_1")["state"] == "contested", "land: damage land contest window")
	t.check(Territory.resolve("f_staff", "fr_reg", "1_1", "defended")["state"] == "active", "land: staff resolve")
	_t += (Territory.UPKEEP_DAYS + 1) * 86400
	t.check(Territory.claim_of("fr_reg", "1_1")["state"] == "grace", "land: lapsed upkeep -> grace")
	t.check(Territory.renew("f_cre", "fr_reg", "1_1")["ok"] and Territory.claim_of("fr_reg", "1_1")["state"] == "active", "land: renew restores")
	t.check(Territory.release("f_cre", "fr_reg", "2_2")["ok"] and Tiers.land_group({"region": "fr_reg", "parcel": "2_2"}) == "", "land: release clears the Estate group")

	# ---------- ships + insurance ----------
	t.check(not ShipRegistry.register("stranger", "royal_suv", "Car")["ok"], "ships: guests can't own ships")
	t.check(not ShipRegistry.register("f_res", "not_a_model", "X")["ok"], "ships: unknown models refused")
	var sh := ShipRegistry.register("f_res", "royal_flagship_starfighter", "Ember Wing", "medium")
	t.check(sh["ok"] and sh["ship"]["state"] == "stored", "ships: resident registers a ship")
	t.check(not ShipRegistry.register("f_cre", "royal_suv", "Big", "capital")["ok"], "ships: capitals are staff+")
	var sid: String = sh["ship"]["id"]
	t.check(not ShipRegistry.insure("f_res", sid, "plus")["ok"] and ShipRegistry.insure("f_res", sid, "basic")["ok"], "ships: insurance plans gated by tier")
	t.check(not ShipRegistry.deploy("f_res2", sid, "local", "fr_reg")["ok"] and ShipRegistry.deploy("f_res", sid, "local", "fr_reg")["ok"], "ships: only the owner deploys")
	t.check(not ShipRegistry.report_loss("f_res", sid)["ok"] and ShipRegistry.report_loss("system", sid, "crash")["loss"]["insured"], "ships: losses recorded by system/staff")
	var c := ShipRegistry.claim("f_res", sid)
	t.check(c["ok"] and c["seconds"] == 300, "ships: claim timer by size and plan")
	_t += 301
	t.check(ShipRegistry.process_claims() == 1 and ShipRegistry.ship(sid)["state"] == "stored", "ships: claim restores the hull to the hangar")
	t.check(ShipRegistry.register("f_res2", "royal_suv", "Org car", "small", "org:" + g)["ok"] == false, "ships: org ships need hangar_take")
	AutonomyGuard.engage("test")
	t.check(not ShipRegistry.register("bot:test", "royal_suv", "Bot car")["ok"], "ships: e-stop stops bots")
	AutonomyGuard.release()

	# ---------- shards / meshing ----------
	ShardModel.reset_layout()
	t.check(ShardModel.server_count("local") == 1 and ShardModel.server_of("local", "aurora_tundra/whatever") == "srv1", "shards: standalone = one server for all planets")
	t.check(ShardModel.planets(true).size() == 3 and ShardModel.planets().size() == 5, "shards: 3 built planets, 2 planned")
	var ev: Array = ShardModel.report_load("local", "aurora_tundra", 95)["events"]
	t.check(ev.size() == 1 and ShardModel.server_count("local") == 4 and ShardModel.server_of("local", "aurora_tundra/2") != ShardModel.server_of("local", "aurora_tundra/1"), "shards: hot planet splits into 4 cells on new servers")
	for q in 4: ShardModel.report_load("local", "aurora_tundra/%d" % q, 5)
	t.check(ShardModel.server_count("local") == 1 and ShardModel.server_of("local", "aurora_tundra") == "srv1", "shards: cold cells merge back")
	var inst := ShardModel.open_instance("local", "concert")
	t.check(inst["ok"] and ShardModel.server_count("local") == 2 and ShardModel.close_instance("local", inst["instance"])["ok"] and ShardModel.server_count("local") == 1, "shards: instances use reserve servers")
	t.check(not ShardModel.add_shard("f_mgr", "eu1")["ok"], "shards: config is owner-only")
	Tiers.owner_override = true
	t.check(ShardModel.add_shard(Tiers.OWNER_ID, "eu1")["ok"] and ShardModel.stats()["shards"] == 2, "shards: owner adds a shard")
	Tiers.owner_override = false

	# ---------- comfort ----------
	t.check(ComfortPrefs.get_pref("fov") == 75 and not ComfortPrefs.get_pref("motion_blur"), "comfort: defaults calm")
	t.check(ComfortPrefs.set_pref("fov", 200)["value"] == ComfortPrefs.FOV_MAX and not ComfortPrefs.set_pref("bogus", 1)["ok"], "comfort: FOV clamped, unknown keys refused")
	t.check(ComfortPrefs.calm_preset()["ok"] and ComfortPrefs.get_pref("snap_turn") and ComfortPrefs.get_pref("travel_fx") == 0.0, "comfort: calm preset")
	t.check(not ComfortPrefs.save_profile("touch_default", "touch_default", {})["ok"], "comfort: built-ins protected")
	t.check(not ComfortPrefs.save_profile("mine", "touch_default", {"jump": "tap_to_move", "move": "tap_to_move"})["ok"], "comfort: duplicate bindings refused")
	t.check(ComfortPrefs.save_profile("mine", "touch_default", {"jump": "swipe_up"})["ok"] and ComfortPrefs.set_pref("profile", "mine")["ok"] and ComfortPrefs.bindings()["jump"] == "swipe_up", "comfort: custom profile saved + active")
	t.check(not ComfortPrefs.set_pref("profile", "nope")["ok"], "comfort: unknown profile refused")
	var cam := Camera3D.new(); ComfortPrefs.apply_camera(cam, true); t.check(is_equal_approx(cam.fov, 85.0), "comfort: camera hook applies vehicle FOV"); cam.free()

	# ---------- persistence ----------
	FrontierStore.reload_all()
	t.check(ContractsBoard.reputation("f_res", "Aurora Wardens")["value"] == 12 and ComfortPrefs.bindings()["jump"] == "swipe_up" and OrgRights.titles(g).has("Hauler"), "frontier: state persists across reload")
	t.check(not FileAccess.get_file_as_string(FrontierStore.path("contracts")).is_empty(), "frontier: saved through SecureFile")

	Tiers.owner_override = null
	FrontierStore.clock = Callable()
	EveCore.save_dir = saved_eve; EveCore.reset_cache()
	BrainCore.adapter_root = BrainCore.DEFAULT_ROOT
	OwnerVault.reset_for_tests(saved_vault, 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(saved_estop)
	Tiers.reset_for_tests("user://social"); Social.reset_for_tests("user://social")
	FrontierStore.reset_for_tests("user://frontier")
	if had_estate:
		var f := FileAccess.open(Estate.PATH, FileAccess.WRITE); f.store_buffer(estate_raw); f.close()
	else: DirAccess.remove_absolute(Estate.PATH)
	Estate.reset_for_tests()
	t.check(FileAccess.file_exists(Estate.PATH) == had_estate, "frontier: real estate.cfg restored")
	_rm_tree(root)

static func run_docs(t: Node) -> void:
	var doc := FileAccess.get_file_as_string("res://docs/modules/SPACESIM_PARITY.md")
	t.check(doc.contains("| feature | source | ours | owner | status |") and doc.contains("Concepts only"), "frontier docs: parity table in viewer-parity format + concepts-only note")
	t.check(doc.count("\n| ") >= 60, "frontier docs: parity rows (%d)" % doc.count("\n| "))
	t.check(FileAccess.file_exists("res://docs/modules/SERVER_MESHING.md") and FileAccess.get_file_as_string("res://docs/modules/SERVER_MESHING.md").contains("ARCHITECTURE_AURORA_MODEL.md"), "frontier docs: server meshing doc tied to Aurora model")
	t.check(FileAccess.file_exists("res://patches/foxy/FRONTIER_CLIENT_SPECS.md"), "frontier docs: client specs for Foxy")
	var idx := FileAccess.get_file_as_string("res://docs/wiki/INDEX.md")
	t.check(idx.contains("frontier.md") and FileAccess.file_exists("res://docs/wiki/frontier.md"), "frontier docs: wiki page + index link")
	t.check(FileAccess.get_file_as_string("res://docs/wiki/frontier.md").contains("LEGAL REVIEW REQUIRED"), "frontier docs: wiki legal note")
	var csv := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	t.check(csv.contains("SPACE-1,") and not csv.contains("\r"), "frontier docs: tracker rows, LF endings")

static func run_ui(t: Node) -> void:
	var root := "user://test_frontier_ui_%d" % Time.get_ticks_usec()
	Tiers.reset_for_tests(root); Social.reset_for_tests(root); FrontierStore.reset_for_tests(root.path_join("frontier"))
	Tiers.owner_override = false
	var s := FrontierScreen.open(t.get_tree().root)
	await t.get_tree().process_frame
	t.check(s.pages.count() == 5 and s.sec.size() == 8, "frontier ui: 5 swipe tabs (kit max) holding 8 sections")
	t.check(s.min_font_ok(PhoenixTokens.TYPE["micro"]), "frontier ui: text >= compact micro size")
	t.check(s.min_tap_ok(PhoenixTokens.TAP_MIN), "frontier ui: taps >= TAP_MIN")
	t.check(FrontierScreen.open(t.get_tree().root) == s, "frontier ui: open() reuses the screen")
	var fov := int(ComfortPrefs.get_pref("fov"))
	for n in s.sec["Comfort"].get_children():
		if n is HBoxContainer: (n.get_child(2) as Button).pressed.emit(); break
	t.check(int(ComfortPrefs.get_pref("fov")) == fov + 5, "frontier ui: comfort FOV + works")
	s.queue_free()
	await t.get_tree().process_frame
	Tiers.owner_override = null
	Tiers.reset_for_tests("user://social"); Social.reset_for_tests("user://social"); FrontierStore.reset_for_tests("user://frontier")
	_rm_tree(root)
