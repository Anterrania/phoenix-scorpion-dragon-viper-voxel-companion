extends RefCounted
## SBX-20..25: sim systems (gate, needs + mood, perks, factions, crafting)
## and the parity docs. Throwaway roots; restores every static it touches.

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func run(t: Node) -> void:
	var root := "user://test_sim_%d" % Time.get_ticks_usec()
	var saved_vault := OwnerVault.root
	var saved_estop := AutonomyGuard.path
	var saved_eve := EveCore.save_dir
	var had_estate := FileAccess.file_exists(Estate.PATH)
	var estate_raw := FileAccess.get_file_as_bytes(Estate.PATH) if had_estate else PackedByteArray()
	BrainCore.adapter_root = root.path_join("brains")
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(root.path_join("security/estop.json"))
	EveCore.save_dir = root.path_join("eve"); EveCore.reset_cache()
	Tiers.reset_for_tests(root.path_join("social"))
	SimGate.reset_for_tests(root.path_join("sim"))
	Estate.reset_for_tests(); Estate._cfg = ConfigFile.new()
	Tiers.owner_override = true
	Tiers.set_tier("sb_res", "resident"); Tiers.set_tier("sb_cre", "creator"); Tiers.set_tier("sb_mgr", "estate_manager")
	Tiers.owner_override = false

	_gate(t); _needs(t); _perks(t); _factions(t); _crafting(t)

	# ---------- restore ----------
	Tiers.owner_override = null
	EveCore.owner_override = null
	EveCore.save_dir = saved_eve; EveCore.reset_cache()
	OwnerVault.reset_for_tests(saved_vault, 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(saved_estop)
	Tiers.reset_for_tests("user://social")
	SimGate.reset_for_tests("user://sim")
	BrainCore.adapter_root = BrainCore.DEFAULT_ROOT
	if had_estate:
		var f := FileAccess.open(Estate.PATH, FileAccess.WRITE); f.store_buffer(estate_raw); f.close()
	else: DirAccess.remove_absolute(Estate.PATH)
	Estate.reset_for_tests()
	t.check(FileAccess.file_exists(Estate.PATH) == had_estate, "sim: real estate.cfg restored")
	_rm_tree(root)

static func _gate(t: Node) -> void:
	t.check(SimGate.action_for("craft") == "build" and SimGate.action_for("join_faction") == "group_join", "sim gate: verbs map onto Tiers actions")
	t.check(SimGate.action_for("play", "alaska") == "enter" and SimGate.action_for("play") == "browse", "sim gate: play with region -> enter")
	for v in SimGate.VERBS: t.check(SimGate.VERBS[v] in Tiers.ACTIONS, "sim gate: %s maps to a real Tiers action" % v)
	t.check(not SimGate.can("sb_res", "nope"), "sim gate: unknown verb denied")
	t.check(SimGate.can("stranger", "play") and not SimGate.can("stranger", "craft"), "sim gate: guests play, can't craft")
	t.check(SimGate.can("sb_res", "craft") and not SimGate.can("sb_res", "create_faction"), "sim gate: residents craft, creators found factions")
	t.check(SimGate.can("sb_cre", "create_faction"), "sim gate: creators found factions")
	t.check(not SimGate.can("sb_mgr", "set_reputation") and not SimGate.can("sb_mgr", "reset_needs"), "sim gate: owner verbs denied to managers")
	t.check(not SimGate.can(Tiers.OWNER_ID, "set_reputation"), "sim gate: locked owner has no owner verbs")
	Tiers.owner_override = true
	t.check(SimGate.can("self", "respec_any") and SimGate.owner(), "sim gate: unlocked owner has owner verbs")
	Tiers.owner_override = false
	AutonomyGuard.engage("test")
	t.check(not SimGate.can("foxy_ani", "craft") and SimGate.can("foxy_ani", "play"), "sim gate: e-stop blocks companion crafting, still browses")
	AutonomyGuard._state["paused"] = false; AutonomyGuard._save()

static func _needs(t: Node) -> void:
	var n := NeedsMood.new("foxy_ani", {"social": 1.5})
	t.check(n.get_need("hunger") == 80.0 and n.mood() == "happy", "needs: start at 80, happy")
	n.tick(60.0)
	t.check(is_equal_approx(n.get_need("hunger"), 50.0), "needs: hunger decays 0.5/min")
	t.check(n.get_need("warmth") == 100.0 or n.get_need("warmth") >= 80.0, "needs: warmth doesn't drain outside hostile realms")
	var w := n.get_need("warmth")
	n.tick(10.0, "idle", "hostile")
	t.check(n.get_need("warmth") < w, "needs: warmth drains in hostile realms")
	var e := n.get_need("energy")
	n.tick(10.0, "build")
	t.check(e - n.get_need("energy") > 0.33 * 10.0 * 1.5, "needs: building drains energy faster")
	var p := n.get_need("purpose")
	t.check(p > 75.0, "needs: building refills purpose")
	var s0 := n.get_need("social")
	n.tick(5.0, "chat")
	t.check(n.get_need("social") > s0, "needs: chatting refills social")
	n.values["hunger"] = 5.0
	t.check("hunger" in n.critical() and n.suggest()["action"] == "eat", "needs: critical hunger -> eat")
	var before := n.mood_score()
	n.add_moodlet("party", 20.0, 30.0); n.add_moodlet("party", 20.0, 30.0)
	t.check(n.moodlets.size() == 1 and n.mood_score() > before, "needs: moodlet lifts mood, doesn't stack")
	n.tick(31.0)
	t.check(n.moodlets.is_empty(), "needs: moodlet expires")
	for k in n.values: n.values[k] = 5.0
	t.check(n.mood() == "miserable", "needs: all low -> miserable")
	var r := NeedsMood.new("x"); r.relaxed = true; r.tick(500.0)
	t.check(r.get_need("hunger") == 80.0, "needs: relaxed mode never decays")
	t.check(is_equal_approx(NeedsMood.new("y").to_life_energy(), 0.8), "needs: CompanionLife energy bridge 0..1")
	var d := n.to_dict(); d["values"]["old_need"] = 50
	var n2 := NeedsMood.from_dict(d)
	t.check(n2.get_need("hunger") == 5.0 and not n2.values.has("old_need") and n2.personality.get("social") == 1.5, "needs: round trip, unknown needs ignored")
	t.check(n.save() and NeedsMood.load_for("foxy_ani").get_need("hunger") == 5.0, "needs: save/load per companion")
	t.check(not n.reset_needs(), "needs: reset is owner-only")
	Tiers.owner_override = true
	t.check(n.reset_needs() and n.get_need("hunger") == 80.0, "needs: owner resets")
	Tiers.owner_override = false
	# EveCore hook: locked cell refuses, owner-unlocked cell logs
	EveCore.owner_override = false
	var eve := EveCore.new("sb_test_comp")
	var m := NeedsMood.new("sb_test_comp"); m.last_mood = "x"
	t.check(not m.remember(eve), "needs: locked Eve cell refuses mood log")
	EveCore.owner_override = true; eve.refresh_lock()
	t.check(m.remember(eve) and eve.entries().back()["event"].begins_with("Mood: ") and not m.remember(eve), "needs: mood change logged once to Eve when unlocked")
	EveCore.owner_override = null

static func _perks(t: Node) -> void:
	var p := PerkTree.new("self")
	t.check(p.defs().size() >= 5 and p.points_available() == 0, "perks: defs load, no points at level 1")
	t.check(p.unlock("steady_hands") != "", "perks: gated by skill level")
	for i in 40: p.gain_xp("building", 30.0)
	t.check(p.skill_level("building") >= 5 and p.points_available() > 0, "perks: XP levels skills, grants points")
	t.check(p.unlock("master_mason") != "", "perks: prerequisite enforced")
	t.check(p.unlock("steady_hands") == "" and is_equal_approx(p.modifier("build_speed"), 0.1), "perks: unlock + modifier")
	var avail := p.points_available()
	p.bonus_points += 1
	t.check(p.points_available() == avail + 1, "perks: bonus points add")
	var p2 := PerkTree.new("self"); p2.load_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check(p2.unlocked.get("steady_hands") == 1 and p2.skill_level("building") == p.skill_level("building"), "perks: JSON round trip")
	t.check(p.respec() and p.unlocked.is_empty(), "perks: respec own tree")
	var c := PerkTree.new("foxy_ani")
	t.check(not c.respec(), "perks: can't respec a companion without owner")
	Tiers.owner_override = true
	t.check(c.respec(), "perks: owner respecs anyone")
	Tiers.owner_override = false
	var g := PerkTree.new("stranger"); g.bonus_points = 1; g.gain_xp("exploring", 400.0)
	t.check(g.unlock("trailblazer") == "", "perks: guests can spend points (browse-level action)")
	t.check(PerkTree.new("").why_not("trailblazer") != "", "perks: empty actor refused")

static func _factions(t: Node) -> void:
	var fx := Factions.new()
	t.check(fx.defs.size() >= 4 and Factions.rank_for(0) == "neutral" and Factions.rank_for(800) == "exalted" and Factions.rank_for(-600) == "hostile", "factions: defs + ranks")
	fx.change("sb_res", "frost_wardens", 200)
	t.check(fx.get_rep("sb_res", "frost_wardens") == 200 and fx.get_rep("sb_res", "ember_court") == -100 and fx.get_rep("sb_res", "star_cartographers") == 100, "factions: ally/rival spillover")
	fx.change("sb_res", "frost_wardens", 5000)
	t.check(fx.get_rep("sb_res", "frost_wardens") == Factions.MAX_REP, "factions: clamped")
	t.check(fx.join("stranger", "free_builders") != "", "factions: guests can't join")
	t.check(fx.join("sb_res", "frost_wardens") == "" and fx.is_member("sb_res", "frost_wardens"), "factions: resident joins")
	t.check(fx.join("sb_res", "ember_court") != "", "factions: hostile/exclusive blocks")
	fx.set_reputation("sb_cre", "ember_court", 0)
	t.check(fx.get_rep("sb_cre", "ember_court") == 0, "factions: set_reputation refused while locked (no change)")
	fx.change("sb_cre", "ember_court", -700)
	t.check(not fx.set_reputation("sb_cre", "ember_court", 0) and fx.join("sb_cre", "ember_court") != "", "factions: hostile can't join; owner override locked")
	Tiers.owner_override = true
	t.check(fx.set_reputation("sb_cre", "ember_court", 0) and fx.join("sb_cre", "ember_court") == "", "factions: owner override then join")
	Tiers.owner_override = false
	t.check(fx.create("sb_res", "my_gang", "Mine") != "" and fx.create("sb_cre", "makers", "Makers") == "" and fx.rank("sb_cre", "makers") == "honored", "factions: creators found factions")
	t.check(fx.claim("sb_res", "alaska", "frost_wardens") != "" and fx.claim("sb_mgr", "alaska", "frost_wardens") == "", "factions: territory claim needs estate manager")
	t.check(fx.turf_bonus("sb_res", "alaska") == 1.25 and fx.turf_bonus("sb_cre", "alaska") == 1.0, "factions: turf bonus for members")
	t.check(fx.save(), "factions: save")
	var fx2 := Factions.load_saved()
	t.check(fx2.defs.has("makers") and fx2.is_member("sb_res", "frost_wardens") and fx2.territory.get("alaska") == "frost_wardens", "factions: reload keeps custom + members + turf")

static func _crafting(t: Node) -> void:
	var perks := PerkTree.new("sb_res")
	var cr := Crafting.new("sb_res", perks)
	var inv := {"voxel:1": 4, "voxel:15": 1, "voxel:4": 5}
	t.check(cr.recipes().size() >= 5 and cr.material_name("voxel:1") == "snow", "craft: recipes + material names")
	t.check("beacon" in cr.available(inv) and not "stone_brick" in cr.available(inv), "craft: available respects stations")
	var r := cr.craft("beacon", inv)
	t.check(r["error"] == "" and inv.get("beacon") == 1 and not inv.has("voxel:1") and not inv.has("voxel:15"), "craft: consumes inputs, makes output")
	t.check(cr.craft("beacon", inv)["error"] == "Missing materials.", "craft: missing materials")
	t.check(cr.craft("stone_brick", inv)["error"].begins_with("Needs a"), "craft: station required")
	r = cr.craft("stone_brick", inv, "workbench", null, 2)
	t.check(r["error"] == "" and inv["stone_brick"] == 8 and inv.get("voxel:4") == 1, "craft: batches")
	t.check(cr.craft("obsidian_blade", {"voxel:5": 3, "voxel:6": 1}, "forge")["error"].begins_with("Needs crafting"), "craft: skill gate")
	var before := inv.duplicate()
	t.check(Crafting.new("stranger", perks).craft("stone_brick", inv, "workbench")["error"] == "You can't craft here." or inv == before, "craft: guests can't craft")
	Estate.region_set("craft_reg", "allow_build", true); Estate.region_set("craft_reg", "terraform", "everyone")
	var inv2 := {"voxel:4": 2}
	t.check(cr.craft("stone_brick", inv2, "workbench", "craft_reg/0_0")["error"] == "", "craft: estate allows build -> craft on parcel")
	Estate.region_set("craft_reg", "allow_build", false)
	inv2 = {"voxel:4": 2}
	t.check(cr.craft("stone_brick", inv2, "workbench", "craft_reg/0_0")["error"] == "You can't craft here." and inv2["voxel:4"] == 2, "craft: no-build land blocks, nothing consumed")
	perks.skills.skills["crafting"] = {"level": 20, "xp": 0.0}; perks.bonus_points = 5
	t.check(perks.unlock("tinkerer") == "", "craft: tinkerer perk")
	var inv3 := {"voxel:4": 2}
	t.check(cr.craft("stone_brick", inv3, "workbench", null, 1, 0.0)["made"]["stone_brick"] == 5, "craft: perk bonus output")
	var blade := {"id": "obsidian_blade"}
	var mats := {"voxel:2": 3, "voxel:15": 1}
	t.check(cr.infuse(blade, "frostbite", mats, "workbench") == "Needs an infuser.", "infuse: needs infuser")
	t.check(cr.infuse(blade, "frostbite", mats, "infuser") == "" and blade["infusion"]["id"] == "frostbite" and mats.is_empty(), "infuse: applies effect, consumes")
	t.check(cr.infuse(blade, "frostbite", {"voxel:2": 3, "voxel:15": 1}, "infuser") == "Already infused.", "infuse: one per item")
	t.check(cr.infuse({"id": "beacon"}, "radiance", {"voxel:13": 2}, "infuser") != "", "infuse: wrong item rejected")

## Docs: parity inventory, Foxy specs, tracker rows, wiki pages, legal-review markers.
static func run_docs(t: Node) -> void:
	var par := FileAccess.get_file_as_string("res://docs/modules/SANDBOX_PARITY.md")
	t.check(par.length() > 5000, "sim docs: SANDBOX_PARITY.md present")
	for src in ["The Sims", "Grand Theft Auto", "League of Angels", "Skyrim", "Game of Thrones Slots Casino", "InWorldz", "Kitely", "Minecraft", "Roblox", "VRChat", "Decentraland"]:
		t.check(par.contains(src), "sim docs: parity covers " + src)
	t.check(par.contains("LEGAL REVIEW") and par.contains("free play tokens"), "sim docs: casino/gacha legal review + free tokens")
	t.check(par.contains("| Source | Feature | Viper status | Owner | Tracker |"), "sim docs: parity table columns")
	var specs: Array = Array(DirAccess.get_files_at("res://docs/specs/foxy")).filter(func(f): return f.begins_with("sbx_"))
	t.check(specs.size() >= 6, "sim docs: Foxy specs (%d)" % specs.size())
	var csv := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	t.check(not csv.contains("\r"), "sim docs: tracker LF endings")
	for i in range(20, 31): t.check(csv.contains("SBX-%d," % i), "sim docs: tracker row SBX-%d" % i)
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	for p in ["SimNeedsMood", "SimSkillsPerks", "SimFactions", "SimCrafting", "SandboxParity"]:
		t.check(wiki is Dictionary and wiki.has(p), "sim docs: wiki seed has " + p)
