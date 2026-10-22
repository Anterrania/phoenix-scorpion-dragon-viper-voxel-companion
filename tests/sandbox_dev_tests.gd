extends RefCounted
## SBX-2..7 + SBX-LEGAL-1..5: quests, on-demand worlds + bundles, inventory migration, market delivery,
## magic box, region rental, free play, LegalReview policy, ledgers, spend limits, refunds.
## Throwaway roots; restores every static it touches (and the real estate.cfg).

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

const ADULT := {"age": 30, "country": "US"}
const TEEN := {"age": 15, "country": "US"}
const KID := {"age": 11, "country": "US"}

static func run(t: Node) -> void:
	var root := "user://test_sbxdev_%d" % Time.get_ticks_usec()
	var saved_vault := OwnerVault.root
	var saved_estop := AutonomyGuard.path
	var had_estate := FileAccess.file_exists(Estate.PATH)
	var estate_raw := FileAccess.get_file_as_bytes(Estate.PATH) if had_estate else PackedByteArray()
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(root.path_join("security/estop.json"))
	Tiers.reset_for_tests(root.path_join("social"))
	SandboxGate.reset_for_tests(root.path_join("sandbox"))
	LegalReview.reset_for_tests(root.path_join("legal"))
	for c in [QuestEngine, WorldHost, InventoryMigration, MarketDelivery, RegionRental, FreePlay, PlayTokens, AethelLedger, SpendLimits]: c.reset_for_tests()
	Estate.reset_for_tests(); Estate._cfg = ConfigFile.new()
	Tiers.owner_override = true
	Tiers.set_tier("sx_res", "resident"); Tiers.set_tier("sx_cre", "creator"); Tiers.set_tier("sx_mgr", "estate_manager")
	Tiers.owner_override = false

	_gate(t); _quests(t); _worlds(t); _migration(t); _legal(t); _ledgers(t); _market(t); _rental(t); _free_play(t); _no_random_aethel(t)

	Tiers.owner_override = null
	OwnerVault.reset_for_tests(saved_vault, 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(saved_estop)
	Tiers.reset_for_tests("user://social")
	SandboxGate.reset_for_tests("user://sandbox")
	LegalReview.reset_for_tests("user://legal")
	for c in [QuestEngine, WorldHost, InventoryMigration, MarketDelivery, RegionRental, FreePlay, PlayTokens, AethelLedger, SpendLimits]: c.reset_for_tests()
	if had_estate:
		var f := FileAccess.open(Estate.PATH, FileAccess.WRITE); f.store_buffer(estate_raw); f.close()
	else: DirAccess.remove_absolute(Estate.PATH)
	Estate.reset_for_tests()
	t.check(FileAccess.file_exists(Estate.PATH) == had_estate, "sbxdev: real estate.cfg restored")
	_rm_tree(root)

static func _gate(t: Node) -> void:
	t.check(SandboxGate.action_for("sell") == "marketplace" and SandboxGate.action_for("play", "r") == "enter", "sbx gate: verbs map onto Tiers actions")
	t.check(not SandboxGate.can("sx_res", "sell") and SandboxGate.can("sx_cre", "sell"), "sbx gate: selling is creator+")
	t.check(not SandboxGate.can("stranger", "trade") and SandboxGate.can("sx_res", "trade"), "sbx gate: guests can't trade")
	t.check(not SandboxGate.can("self", "grant"), "sbx gate: owner verb refused while locked")
	Tiers.owner_override = true
	t.check(SandboxGate.can("self", "grant") and not SandboxGate.can("sx_mgr", "grant"), "sbx gate: owner verb needs the owner, not just an unlocked session")
	Tiers.owner_override = false
	t.check(not SandboxGate.can("nope", "frobnicate"), "sbx gate: unknown verb denied")

static func _quests(t: Node) -> void:
	t.check(QuestEngine.definitions().size() >= 4 and QuestEngine.definition("first_light").size() > 0, "quests: shipped definitions load")
	for d in QuestEngine.definitions(): t.check(QuestEngine.validate(d) == "", "quests: shipped %s valid" % d["id"])
	t.check(QuestEngine.accept("sx_res", "aurora_walk", 0) != "", "quests: prerequisite blocks")
	t.check(QuestEngine.accept("sx_res", "first_light", 0) == "" and QuestEngine.accept("sx_res", "first_light", 0) != "", "quests: accept once")
	QuestEngine.report("sx_res", "build", "beacon", 1, 5)
	t.check(QuestEngine.journal("sx_res")[0]["objectives"][1]["count"] == 0, "quests: sequence order holds later objective")
	var up := QuestEngine.report("sx_res", "collect", "voxel_ice", 9, 6)
	t.check(QuestEngine.journal("sx_res")[0]["objectives"][0]["count"] == 5 and up.size() == 1, "quests: progress capped at count")
	t.check(QuestEngine.track("sx_res", "first_light") == "" and QuestEngine.journal("sx_res")[0]["tracked"], "quests: track active quest")
	QuestEngine.report("sx_res", "build", "beacon", 1, 7)
	t.check(QuestEngine.status_of("sx_res", "first_light") == "complete", "quests: optional objective not needed to complete")
	var c := QuestEngine.claim("sx_res", "first_light", 8)
	t.check(c.get("rewards", {}).get("tokens", 0) == 10 and "aurora_walk" in c.get("next", []), "quests: claim returns rewards + branches")
	t.check(PlayTokens.balance("sx_res") == 10, "quests: token reward lands in the play-token ledger")
	t.check(AethelLedger.balance("sx_res") == 0, "quests: no Aethel Coin from quests")
	t.check(QuestEngine.claim("sx_res", "first_light")["error"] != "", "quests: claim once")
	t.check(QuestEngine.accept("sx_res", "first_light", 9) == "Already done.", "quests: non-repeatable")
	# timed mission + region fail
	t.check(QuestEngine.accept("sx_res", "ember_run", 100) == "", "quests: mission unlocked by prerequisite")
	t.check(QuestEngine.tick("sx_res", 200).is_empty() and QuestEngine.tick("sx_res", 401) == ["ember_run"], "quests: timed mission fails on timeout")
	t.check(QuestEngine.accept("sx_res", "aurora_walk", 500) == "", "quests: branch quest accepted")
	t.check(QuestEngine.abandon("sx_res", "aurora_walk") == "" and QuestEngine.status_of("sx_res", "aurora_walk") == "abandoned", "quests: abandon")
	# repeatable cooldown
	QuestEngine.accept("sx_res", "daily_garden", 1000); QuestEngine.report("sx_res", "use", "plant", 3, 1001); QuestEngine.claim("sx_res", "daily_garden", 1001)
	t.check(QuestEngine.accept("sx_res", "daily_garden", 2000) != "" and QuestEngine.accept("sx_res", "daily_garden", 1001 + 86400) == "", "quests: repeatable cooldown")
	# region access
	Estate.region_set("sx_closed", "access", "owner_only")
	var dq := {"id": "locked_q", "title": "Locked", "region": "sx_closed", "objectives": [{"id": "a", "type": "visit", "target": "x", "count": 1}]}
	# authoring
	t.check(QuestEngine.author("sx_res", dq) != "", "quests: residents can't author")
	t.check(QuestEngine.author("sx_cre", {"id": "bad", "title": "B", "objectives": [{"id": "a", "type": "teleport"}]}) != "", "quests: unknown objective rejected")
	t.check(QuestEngine.author("sx_cre", {"id": "rich", "title": "R", "objectives": dq["objectives"], "rewards": {"aethel": 5}}).contains("legal"), "quests: Aethel reward refused (legal review)")
	t.check(QuestEngine.author("sx_cre", dq) == "" and QuestEngine.definition("locked_q").is_empty(), "quests: authored quest is a draft")
	t.check(QuestEngine.publish("sx_cre", "locked_q") != "", "quests: publish is owner-only")
	Tiers.owner_override = true; t.check(QuestEngine.publish("self", "locked_q") == "", "quests: owner publishes"); Tiers.owner_override = false
	t.check(QuestEngine.accept("sx_res", "locked_q", 0) != "", "quests: region access via Tiers enter")
	QuestEngine.reset_for_tests()
	t.check(QuestEngine.status_of("sx_res", "first_light") == "claimed" and QuestEngine.definition("locked_q").size() > 0, "quests: state + authored reload from disk")

static func _worlds(t: Node) -> void:
	var r := "sx_world"
	t.check(WorldHost.state(r) == "stored", "worlds: regions start stored")
	var e := WorldHost.request_entry("sx_res", r, 1000)
	t.check(e["state"] == "starting" and e["eta_s"] == WorldHost.SPINUP_S, "worlds: visit wakes a stored region")
	WorldHost.tick(1000 + WorldHost.SPINUP_S)
	t.check(WorldHost.state(r) == "running", "worlds: spin-up finishes")
	WorldHost.leave("sx_res", r, 1100)
	WorldHost.tick(1100 + 30)
	t.check(WorldHost.state(r) == "running", "worlds: stays up during idle timeout")
	WorldHost.tick(1100 + WorldHost.DEFAULT_IDLE_S)
	t.check(WorldHost.state(r) == "stopping", "worlds: idle region spins down")
	WorldHost.tick(1100 + WorldHost.DEFAULT_IDLE_S + WorldHost.SPINDOWN_S)
	t.check(WorldHost.state(r) == "stored", "worlds: stored again")
	t.check(WorldHost.set_schedule("sx_res", r, [{"start_h": 0, "end_h": 24}]) != "", "worlds: schedule needs estate manager")
	t.check(WorldHost.set_schedule("sx_mgr", r, [{"start_h": 5, "end_h": 3}]) != "", "worlds: bad window rejected")
	t.check(WorldHost.set_schedule("sx_mgr", r, [{"start_h": 0, "end_h": 24}]) == "", "worlds: manager sets keep-awake window")
	WorldHost.tick(5000)
	t.check(WorldHost.state(r) == "starting", "worlds: schedule wakes a region")
	WorldHost.tick(5000 + WorldHost.SPINUP_S); WorldHost.tick(99999)
	t.check(WorldHost.state(r) == "running", "worlds: schedule keeps it awake")
	Estate.region_set("sx_shut", "access", "owner_only")
	t.check(WorldHost.request_entry("sx_res", "sx_shut", 0).has("error"), "worlds: entry obeys estate access")
	# phone budget
	for i in WorldHost.MAX_RUNNING + 1: WorldHost.request_entry("sx_res", "sx_b%d" % i, 10 + i)
	for i in WorldHost.MAX_RUNNING + 1: WorldHost.leave("sx_res", "sx_b%d" % i, 20 + i)
	WorldHost.request_entry("sx_res", "sx_bnew", 50)
	t.check(WorldHost.running().size() <= WorldHost.MAX_RUNNING + 2, "worlds: cap keeps running count bounded")
	t.check(WorldHost.state(r) == "stopping" or WorldHost.state("sx_b0") == "stopping", "worlds: least-recently-visited empty region sleeps first")
	# bundles
	var b := "sx_bundle"
	Estate.region_set(b, "water_height", 4.5); Estate.region_set(b, "banned", ["someone"]); Estate.parcel_set(b, "0_0", "allow_build", false)
	WorldHost.place_object("sx_mgr", b, {"id": "o1", "name": "Mine", "creator": "sx_mgr", "perms": {}})
	WorldHost.place_object("sx_mgr", b, {"id": "o2", "name": "Full", "creator": "x", "perms": {"copy": true, "transfer": true}})
	WorldHost.place_object("sx_mgr", b, {"id": "o3", "name": "NoTrans", "creator": "x", "perms": {"copy": true}})
	WorldHost.place_object("sx_mgr", b, {"id": "o4", "name": "MarketNoExp", "creator": "x", "market": true, "export": false, "perms": {"copy": true, "transfer": true}})
	WorldHost.place_object("sx_mgr", b, {"id": "o5", "name": "MarketExp", "creator": "x", "market": true, "export": true, "perms": {}})
	t.check(WorldHost.place_object("sx_res", b, {"id": "zz"}) != "", "bundle: residents can't place region objects")
	t.check(WorldHost.export_bundle("sx_res", b).has("error"), "bundle: export needs estate manager")
	var bun := WorldHost.export_bundle("sx_mgr", b)
	var ids: Array = bun["objects"].map(func(o): return o["id"])
	t.check(ids == ["o1", "o2", "o5"] and bun["report"]["skipped"].size() == 2, "bundle: export rules (own, copy+transfer, market export flag)")
	t.check(not bun["estate"].has("banned") and not bun["estate"].has("allowed") and bun["estate"]["water_height"] == 4.5, "bundle: estate kept, people lists left out")
	t.check(bun["parcels"].has("0_0") and bun["parcels"]["0_0"]["allow_build"] == false, "bundle: parcel overrides exported")
	var round: Variant = JSON.parse_string(JSON.stringify(bun))
	t.check(WorldHost.import_bundle("sx_mgr", round, "sx_copy") != "", "bundle: import is owner-only")
	Tiers.owner_override = true
	t.check(WorldHost.import_bundle("self", {"format": "x"}, "sx_copy") != "", "bundle: wrong format refused")
	t.check(WorldHost.import_bundle("self", round, "../evil") != "", "bundle: unsafe region name refused")
	t.check(WorldHost.import_bundle("self", round, "sx_copy") == "" and float(Estate.region_get("sx_copy", "water_height")) == 4.5 and WorldHost.objects("sx_copy").size() == 3, "bundle: owner imports")
	t.check(Estate.parcel_get("sx_copy", "0_0", "allow_build") == false, "bundle: parcels restored")
	t.check(WorldHost.import_bundle("self", round, "sx_copy") != "" and WorldHost.import_bundle("self", round, "sx_copy", true) == "", "bundle: overwrite must be explicit")
	Tiers.owner_override = false

static func _migration(t: Node) -> void:
	var T := InventoryMigration.PERM_TRANSFER; var M := InventoryMigration.PERM_MODIFY; var C := InventoryMigration.PERM_COPY
	var p := InventoryMigration.perms_from({"owner": C | M | T, "next_owner": C | T})
	t.check(p["owner"]["modify"] and not p["next_owner"]["modify"] and p["next_owner"]["copy"], "migration: mask bits read (OpenSim values)")
	t.check(not InventoryMigration.perms_from({"owner": C, "next_owner": C | M | T})["next_owner"]["transfer"], "migration: next-owner never wider than owner")
	t.check(InventoryMigration.perms_from("CT")["owner"]["transfer"] and not InventoryMigration.perms_from("CT")["owner"]["modify"], "migration: CMT text perms")
	var man := {"grid": "OldGrid", "avatar": "Old Me", "items": [
		{"name": "My House", "type": "object", "folder": "Builds", "creator": "Old Me", "asset_id": "a1", "perms": {"owner": C | M | T, "next_owner": C}},
		{"name": "Bought Hat", "type": "clothing", "creator": "Shop Person", "asset_id": "a2", "perms": {"owner": C | M, "next_owner": C | M}},
		{"name": "Full Tree", "type": "object", "creator": "Freebie Maker", "asset_id": "a3", "perms": "CMT"},
		{"name": "Market Lamp", "type": "object", "creator": "Shop Person", "asset_id": "a4", "perms": "C", "export": true},
		{"name": "Door script", "type": "lsltext", "creator": "Old Me", "asset_id": "a5", "perms": "CMT"},
		{"name": "A friend", "type": "callingcard", "creator": "x", "asset_id": "a6"},
		{"name": "Weird", "type": "hologram", "creator": "x", "asset_id": "a7"}]}
	t.check(InventoryMigration.migrate("sx_res", man).has("error"), "migration: residents can't import")
	var dry := InventoryMigration.migrate("sx_cre", man, "", {}, true)
	t.check(dry["imported"].size() == 4 and dry["skipped"].size() == 3 and InventoryMigration.items_of("sx_cre").is_empty(), "migration: dry run maps + skips, saves nothing")
	var res := InventoryMigration.migrate("sx_cre", man)
	var byname := {}
	for r in res["imported"]: byname[r["name"]] = r
	t.check(not byname.has("Bought Hat") and byname.has("Full Tree") and byname.has("Market Lamp"), "migration: no-transfer goods stay behind, full-perm and export-flagged come over")
	t.check(byname["My House"]["creator_id"] == "sx_cre" and byname["My House"]["folder"] == "Imported/OldGrid/Builds", "migration: your creations credited to you, folders kept")
	t.check(byname["Full Tree"]["creator_id"].begins_with("grid:") and not JSON.stringify(res).contains("Freebie Maker"), "migration: other creators kept as ids, names dropped")
	t.check(byname["Door script"]["kind"] == "script" and byname["Door script"]["needs_port"], "migration: scripts flagged needs_port")
	t.check(byname["My House"]["next_owner"]["copy"] and not byname["My House"]["next_owner"]["modify"], "migration: next-owner perms carried")
	InventoryMigration.migrate("sx_cre", man)
	t.check(InventoryMigration.items_of("sx_cre").size() == 4, "migration: re-run doesn't duplicate")
	t.check(InventoryMigration.migrate("sx_cre", man, "sx_res").has("error"), "migration: migrating for others is owner-only")
	Tiers.owner_override = true
	t.check(not InventoryMigration.migrate("self", man, "sx_res").has("error"), "migration: owner migrates for a member")
	Tiers.owner_override = false

static func _legal(t: Node) -> void:
	t.check(not LegalReview.allowed("totally_new_thing", ADULT), "legal: unknown feature denied by default")
	t.check(LegalReview.allowed("free_play_chance", ADULT) and LegalReview.allowed("free_play_chance", TEEN), "legal: free play 13+")
	t.check(not LegalReview.allowed("free_play_chance", KID), "legal: under-13 no chance features")
	t.check(not LegalReview.allowed("free_play_chance", {"country": "US"}), "legal: unknown age treated as a child")
	t.check(LegalReview.allowed("casino_content", {"age": 18, "country": "US"}) and not LegalReview.allowed("casino_content", {"age": 17, "country": "US"}), "legal: casino content 18+")
	t.check(not LegalReview.allowed("free_play_chance", {"age": 30, "country": "FR"}), "legal: no new-country launch")
	var buy := {"age": 30, "country": "US", "price_shown": true, "fixed_price": true}
	t.check(LegalReview.allowed("aethel_fixed_price_purchase", buy), "legal: fixed-price purchase allowed with price shown")
	t.check(not LegalReview.allowed("aethel_fixed_price_purchase", {"age": 30, "country": "US", "fixed_price": true}), "legal: price must be shown")
	t.check(not LegalReview.allowed("aethel_fixed_price_purchase", {"age": 12, "country": "US", "price_shown": true, "fixed_price": true}), "legal: under-13 no purchases")
	for f in ["paid_loot_box", "loyalty_reward", "no_purchase_giveaway", "aethel_rental", "aethel_metering", "aethel_quest_reward"]:
		t.check(LegalReview.state(f) == LegalReview.LATER and not LegalReview.allowed(f, buy), "legal: LATER %s is off" % f)
	for f in ["coin_wager", "aethel_cashout", "aethel_exchange", "p2p_coin_transfer", "p2p_chance_item_trade", "play_token_purchase", "play_token_transfer", "play_token_convert", "sweepstakes", "real_money_gaming", "nft_blockchain", "new_country_launch"]:
		t.check(LegalReview.is_hard(f) and not LegalReview.allowed(f, buy), "legal: HARD %s denied" % f)
	# flags: LATER needs owner + sign-off ref; HARD can't be flagged at all
	t.check(LegalReview.set_later_flag("paid_loot_box", true, "ref") != "", "legal: LATER flag needs the owner")
	Tiers.owner_override = true
	t.check(LegalReview.set_later_flag("coin_wager", true, "ref") != "" and not LegalReview.allowed("coin_wager", buy), "legal: HARD can't be enabled by config")
	t.check(LegalReview.set_later_flag("paid_loot_box", true, "") != "", "legal: LATER flag needs a counsel sign-off ref")
	t.check(LegalReview.set_later_flag("paid_loot_box", true, "counsel-test-ref") == "", "legal: owner flips LATER flag with sign-off")
	Tiers.owner_override = false
	var lb := {"age": 30, "country": "US", "price_shown": true, "odds_shown": true}
	t.check(LegalReview.allowed("paid_loot_box", lb), "legal: flagged loot box allowed for adults with odds + price")
	t.check(not LegalReview.allowed("paid_loot_box", {"age": 30, "country": "US", "price_shown": true}), "legal: loot box needs odds shown")
	t.check(not LegalReview.allowed("paid_loot_box", {"age": 15, "country": "US", "price_shown": true, "odds_shown": true}), "legal: under-16 loot box needs parental consent")
	t.check(not LegalReview.allowed("paid_loot_box", {"age": 17, "country": "US", "subdivision": "US-WA", "price_shown": true, "odds_shown": true}), "legal: minors blocked in WA")
	# the policy file holds no flag for HARD features, and a hand-edited flag file can't turn one on
	LegalReview.flags()["coin_wager"] = {"on": true, "signoff": "forged"}
	t.check(not LegalReview.allowed("coin_wager", buy), "legal: forged flag file can't enable HARD")
	Tiers.owner_override = true; LegalReview.set_later_flag("paid_loot_box", false); Tiers.owner_override = false
	LegalReview.flags().erase("coin_wager")
	t.check(not LegalReview.allowed("paid_loot_box", lb), "legal: LATER back off")
	t.check(FileAccess.get_file_as_string("res://docs/modules/LEGAL_REVIEW_GATES.md").contains("general information, pending counsel review"), "legal: rules doc marked pending counsel")

static func _ledgers(t: Node) -> void:
	t.check(PlayTokens.earn("sx_led", 50, "purchase") != "" and PlayTokens.balance("sx_led") == 0, "ledger: play tokens can't be bought")
	t.check(PlayTokens.earn("sx_led", 50, "quest") == "" and PlayTokens.balance("sx_led") == 50, "ledger: play tokens earned by playing")
	t.check(PlayTokens.earn("sx_led", 99999, "quest") != "", "ledger: per-event earn cap")
	var forbidden := ["transfer", "gift", "trade", "send", "buy", "purchase", "cash", "convert", "withdraw", "payout", "award", "wager", "bet", "exchange"]
	for cls in [PlayTokens, AethelLedger]:
		var bad: Array = []
		for m in (cls as Script).get_script_method_list():
			for w in forbidden:
				if str(m["name"]).to_lower().contains(w) and str(m["name"]) != "purchase_fixed": bad.append(m["name"])
		t.check(bad.is_empty(), "ledger: no P2P/cash-out/payout endpoint on %s %s" % [(cls as Script).resource_path.get_file(), bad])
	t.check(PlayTokens._path() != AethelLedger._path() and not FileAccess.get_file_as_string("res://scripts/economy/play_tokens.gd").contains("AethelLedger."), "ledger: play tokens and Aethel Coin are separate ledgers")
	# Aethel fixed-price + spend limits + refund
	t.check(AethelLedger.owner_adjust("sx_led", 5000, "test", 0) != "", "ledger: adjust is owner-only")
	Tiers.owner_override = true; AethelLedger.owner_adjust("sx_led", 5000, "test wallet", 0); AethelLedger.owner_adjust("sx_teen", 5000, "test wallet", 0); Tiers.owner_override = false
	var now := 1_800_000_000
	var ok := {"age": 30, "country": "US", "price_shown": true}
	t.check(AethelLedger.purchase_fixed("sx_led", "hat", 100, {"age": 30, "country": "US"}, now).has("error"), "ledger: purchase refused without price shown")
	t.check(AethelLedger.purchase_fixed("sx_led", "hat", 100, {"age": 12, "country": "US", "price_shown": true}, now).has("error"), "ledger: under-13 purchase refused")
	var tx := AethelLedger.purchase_fixed("sx_led", "hat", 100, ok, now)
	t.check(not tx.has("error") and AethelLedger.balance("sx_led") == 4900, "ledger: fixed-price purchase debits")
	var teen := {"age": 15, "country": "US", "price_shown": true}
	t.check(not AethelLedger.purchase_fixed("sx_teen", "a", 1500, teen, now).has("error") and AethelLedger.purchase_fixed("sx_teen", "b", 600, teen, now)["error"].contains("limit"), "spend limits: teen monthly cap")
	t.check(SpendLimits.set_cap("sx_led", 50) != "", "spend limits: personal cap is owner-only")
	Tiers.owner_override = true; SpendLimits.set_cap("sx_led", 150); Tiers.owner_override = false
	t.check(AethelLedger.purchase_fixed("sx_led", "x", 100, ok, now).has("error"), "spend limits: personal cap applies")
	t.check(AethelLedger.request_refund("sx_other", tx["id"], "", now) != "", "refund: only the buyer requests")
	t.check(AethelLedger.request_refund("sx_led", tx["id"], "changed my mind", now + 15 * 86400) != "", "refund: window closes")
	t.check(AethelLedger.request_refund("sx_led", tx["id"], "changed my mind", now + 60) == "", "refund: requested")
	t.check(AethelLedger.approve_refund(tx["id"], now).has("error"), "refund: approval is owner-only")
	Tiers.owner_override = true
	var rf := AethelLedger.approve_refund(tx["id"], now + 120)
	Tiers.owner_override = false
	t.check(rf.get("revoke_item", "") == "hat" and AethelLedger.balance("sx_led") == 5000, "refund: approved, coins back, item to revoke")
	t.check(Marketplace.buy({"moderation": "approved", "creator_id": "c", "price_aethel": 10, "id": "m1"}, "sx_led") != "", "ledger: legacy Marketplace.buy refuses priced items without age/country/price shown")
	var ex := CurrencyExchange.new()
	t.check(not ex.place_order("sx_led", "buy", 1, 1), "ledger: coin exchange HARD-disabled")
	var lg := Ledger.new()
	t.check(lg.transfer("mint", "sx_a", 10) and not lg.transfer("sx_a", "sx_b", 5), "ledger: member-to-member transfer HARD-disabled")

static func _market(t: Node) -> void:
	var lamp := [{"name": "Lamp", "kind": "object", "perms": {"copy": true, "modify": true, "transfer": true}}]
	var statue := [{"name": "Statue", "kind": "object", "perms": {"copy": false, "modify": true, "transfer": true}}]
	var mixed := lamp + [{"name": "Base", "kind": "object", "perms": {"copy": true, "modify": false, "transfer": false}}]
	var dp := MarketDelivery.derived_perms(mixed)
	t.check(dp["modify"] and dp["copy"] and not dp["transfer"], "market: product perms derived (any modify, all copy, all transfer)")
	t.check(MarketDelivery.create_listing("sx_res", "lamp", "Lamp", lamp) != "", "market: residents can't list")
	t.check(MarketDelivery.create_listing("sx_cre", "lamp", "Lamp", lamp, 0, true) == "", "market: creator lists")
	MarketDelivery.create_listing("sx_cre", "statue", "Statue", statue)
	MarketDelivery.create_listing("sx_cre", "mixed", "Set", mixed)
	MarketDelivery.create_listing("sx_cre", "pricey", "Gold Lamp", lamp, 40)
	t.check(MarketDelivery.create_listing("sx_cre", "prize", "Prize", [{"name": "P", "kind": "cosmetic", "chance_won": true, "perms": {"copy": true, "transfer": true}}]) != "", "market: chance-won prizes can't be listed")
	t.check(MarketDelivery.deliver("sx_res", "lamp").has("error"), "market: drafts aren't for sale")
	t.check(MarketDelivery.set_status("sx_res", "lamp", "active") != "", "market: only merchant/owner sets status")
	for id in ["lamp", "statue", "mixed", "pricey"]: MarketDelivery.set_status("sx_cre", id, "active")
	t.check(MarketDelivery.deliver("stranger", "lamp").has("error"), "market: guests can't receive")
	var o := MarketDelivery.deliver("sx_res", "lamp", "", 10)
	t.check(o.get("status", "") == "delivered" and MarketDelivery.received("sx_res").has(o["id"]), "market: delivered to Received folder")
	t.check(MarketDelivery.deliver("sx_res", "lamp", "", 11)["id"] == o["id"], "market: copyable item not bought twice")
	t.check(MarketDelivery.deliver("sx_res", "mixed", "sx_cre").has("error"), "market: no-transfer can't be a gift")
	t.check(MarketDelivery.deliver("sx_res", "statue", "grid:Other/Av").has("error"), "market: no-export can't leave Viper")
	var f := MarketDelivery.deliver("sx_res", "lamp", "grid:Other/Av", 12)
	t.check(f.get("status", "") == "pending_accept" and f["boxed"], "market: off-grid delivery boxed, waits for accept")
	t.check(MarketDelivery.accept_delivery(f["id"]) == "" and MarketDelivery.received("grid:Other/Av").has(f["id"]), "market: accept completes off-grid delivery")
	t.check(MarketDelivery.redeliver("sx_cre", o["id"]) != "" and MarketDelivery.redeliver("sx_res", o["id"]) == "", "market: buyer-only redelivery")
	# priced: fixed-price Aethel via AethelLedger + LegalReview
	Tiers.owner_override = true; AethelLedger.owner_adjust("sx_res", 100, "test wallet", 0); Tiers.owner_override = false
	t.check(MarketDelivery.deliver("sx_res", "pricey", "", 20, {"age": 30, "country": "US"}).has("error"), "market: priced item needs price shown")
	t.check(MarketDelivery.deliver("sx_res", "pricey", "", 20, {"age": 30, "country": "US", "price_shown": true, "shown_price": 39}).has("error"), "market: shown price must match")
	t.check(MarketDelivery.deliver("sx_res", "pricey", "sx_cre", 20, {"age": 30, "country": "US", "price_shown": true, "shown_price": 40}).has("error"), "market: paid items only for yourself")
	var po := MarketDelivery.deliver("sx_res", "pricey", "", 20, {"age": 30, "country": "US", "price_shown": true, "shown_price": 40})
	t.check(not po.has("error") and po["txn"] != "" and AethelLedger.balance("sx_res") == 60, "market: fixed-price Aethel purchase delivers")
	t.check(MarketDelivery.deliver("sx_res", "pricey", "", 21, {"age": 30, "country": "US", "price_shown": true, "shown_price": 40})["id"] == po["id"] and AethelLedger.balance("sx_res") == 60, "market: no double charge for owned copyable item")
	# magic box
	Estate.region_set("sx_shop", "allow_build", true); Estate.region_set("sx_shop", "terraform", "everyone")
	Estate.region_set("sx_nobuild", "allow_build", false)
	t.check(MarketDelivery.place_box("sx_res", "b1", "sx_shop", "0_0") != "", "magic box: residents can't place")
	t.check(MarketDelivery.place_box("sx_cre", "b0", "sx_nobuild", "0_0") != "", "magic box: needs build rights on the parcel")
	t.check(MarketDelivery.place_box("sx_cre", "b1", "sx_shop", "0_0") == "", "magic box: creator places on buildable land")
	t.check(MarketDelivery.box_stock("b1").size() == 4, "magic box: shows the merchant's active listings")
	MarketDelivery.set_status("sx_cre", "statue", "paused")
	t.check(MarketDelivery.box_stock("b1").size() == 3 and MarketDelivery.vend("sx_res", "b1", "statue").has("error"), "magic box: stock syncs with listing status")
	t.check(MarketDelivery.vend("sx_res", "b1", "mixed", 30).get("status", "") == "delivered", "magic box: vends through delivery")
	Estate.region_set("sx_shop", "banned", ["sx_res"])
	t.check(MarketDelivery.vend("sx_res", "b1", "lamp").has("error"), "magic box: banned buyer can't use it")
	MarketDelivery.reset_for_tests()
	t.check(MarketDelivery.listing("lamp").size() > 0 and MarketDelivery.box_stock("b1").size() == 3, "market: reload from disk")

static func _rental(t: Node) -> void:
	var r := "sx_rent"
	t.check(RegionRental.set_terms("sx_res", r, "1_1", 0, "day") != "", "rental: terms need estate manager")
	t.check(RegionRental.set_terms("sx_mgr", r, "1_1", 0, "fortnight") != "", "rental: unit validated")
	t.check(RegionRental.set_terms("sx_mgr", r, "1_1", 0, "day", 1, 30) == "", "rental: manager sets free terms")
	t.check(RegionRental.rent("stranger", r, "1_1", 2, 0).has("error"), "rental: guests can't rent")
	t.check(RegionRental.rent("sx_res", r, "1_1", 40, 0).has("error"), "rental: unit limits")
	var l := RegionRental.rent("sx_res", r, "1_1", 2, 1000)
	t.check(not l.has("error") and l["ends"] == 1000 + 2 * 86400, "rental: lease per time unit")
	t.check("sx_res" in Estate.parcel_get(r, "1_1", "allowed") and Estate.parcel_get(r, "1_1", "allow_build") == true, "rental: lease grants access + build")
	t.check(RegionRental.rent("sx_cre", r, "1_1", 1, 2000).has("error"), "rental: no double letting")
	t.check(RegionRental.rent("sx_res", r, "1_1", 1, 2000)["ends"] == 1000 + 3 * 86400, "rental: renewal extends")
	t.check(RegionRental.tick(1000 + 3 * 86400) == [r + "/1_1"] and not "sx_res" in Estate.parcel_get(r, "1_1", "allowed"), "rental: expiry takes access back")
	RegionRental.set_terms("sx_mgr", r, "2_2", 25, "week")
	var paid := RegionRental.rent("sx_res", r, "2_2", 1, 0)
	t.check(paid.has("error") and paid["quote"]["cost_aethel"] == 25 and paid["quote"]["legal_review"], "rental: priced rent only quotes (LEGAL REVIEW, aethel_rental LATER)")
	t.check(RegionRental.grant_lease("sx_mgr", "sx_res", r, "2_2", 3600, 0).has("error"), "rental: hand grant is owner-only")
	Tiers.owner_override = true
	t.check(not RegionRental.grant_lease("self", "sx_res", r, "2_2", 3600, 0).has("error"), "rental: owner grants a lease")
	Tiers.owner_override = false
	RegionRental.meter(r, "sx_res", 30); RegionRental.meter(r, "sx_cre", 15)
	t.check(RegionRental.usage(r)["minutes"] == 45 and AethelLedger.balance("sx_mgr") == 0, "rental: visitor-minute meter reports, never charges")

static func _free_play(t: Node) -> void:
	FreePlay.seed_for_tests(12345)
	for g in FreePlay.GAMES:
		var total := 0.0
		for o in FreePlay.odds(g): total += o["percent"]
		t.check(absf(total - 100.0) < 0.01, "free play: %s odds disclosed, sum 100%%" % g)
	t.check(FreePlay.spin("sx_res", "star_wheel", KID, 0).has("error"), "free play: under-13 can't play")
	t.check(FreePlay.spin("sx_res", "lantern_reels", TEEN, 0).has("error"), "free play: casino-style game 18+")
	t.check(FreePlay.spin("sx_res", "star_wheel", {"age": 30, "country": "DE"}, 0).has("error"), "free play: launch countries only")
	var before := PlayTokens.balance("sx_cre")
	t.check(FreePlay.spin("sx_cre", "star_wheel", ADULT, 0).has("error"), "free play: no tokens, no spin (no refills)")
	PlayTokens.earn("sx_cre", 400, "event")
	var coins := AethelLedger.balance("sx_cre")
	var n_log := LegalReview.audit_lines().size()
	var plays := 0
	var won_cos := ""
	for i in 60:
		var r := FreePlay.spin("sx_cre", "star_wheel" if i % 2 == 0 else "lantern_reels", ADULT, 100 + i)
		if r.has("error"): break
		plays += 1
		if r["prize"].has("cosmetic"): won_cos = r["prize"]["cosmetic"]
	t.check(plays >= 30, "free play: adults play with earned tokens (%d plays)" % plays)
	t.check(AethelLedger.balance("sx_cre") == coins, "free play: no Aethel Coin from any spin")
	t.check(LegalReview.audit_lines().size() == n_log + plays and LegalReview.audit_lines()[-1].has("odds"), "free play: every outcome logged for audit")
	for c in FreePlay.cosmetics("sx_cre"): t.check(c["bound"] and not c["tradable"], "free play: prize %s bound to the account" % c["id"])
	if won_cos != "":
		t.check(MarketDelivery.create_listing("sx_cre", "resell", "Resell", [{"id": won_cos, "name": "x", "perms": {"copy": true, "transfer": true}}]) != "", "free play: won cosmetic can't be listed")

## "No code path awards Aethel Coin from a random outcome": prize tables have no coin key, nothing that
## uses randomness touches the Aethel ledger, and the Aethel ledger has no randomness and no payout.
static func _no_random_aethel(t: Node) -> void:
	for g in FreePlay.GAMES:
		for p in FreePlay.GAMES[g]["prizes"]:
			for k in p: t.check(k in FreePlay.PRIZE_KEYS, "no random Aethel: %s prize key %s allowed" % [g, k])
	var files: Array = []
	_walk("res://scripts", files)
	var rand_re := RegEx.new(); rand_re.compile("\\brand[fi]?(_range)?\\(|RandomNumberGenerator|\\.randi|\\.randf|randomize\\(")
	var aethel_re := RegEx.new(); aethel_re.compile("AethelLedger\\.|aethel_ledger\\.json|ugc/wallet\\.json|Marketplace\\.(buy|_save)\\(")
	var offenders: Array = []
	for f in files:
		var src := FileAccess.get_file_as_string(f)
		var code := ""
		for line in src.split("\n"):
			if not line.strip_edges().begins_with("#"): code += line + "\n"
		if rand_re.search(code) != null and aethel_re.search(code) != null:
			# marketplace.gd: randi() only names an upload file; its Aethel use is a fixed-price DEBIT via purchase_fixed
			if f.ends_with("economy/marketplace.gd") and not code.contains("owner_adjust") and not code.contains("approve_refund"): continue
			offenders.append(f)
	t.check(offenders.is_empty(), "no random Aethel: no script mixes randomness with the Aethel ledger %s" % [offenders])
	var al := FileAccess.get_file_as_string("res://scripts/economy/aethel_ledger.gd")
	t.check(rand_re.search(al) == null, "no random Aethel: Aethel ledger has no randomness")
	var credit_re := RegEx.new(); credit_re.compile("AethelLedger\\.(owner_adjust|approve_refund)\\(")
	var creditors: Array = []
	for f in files:
		if credit_re.search(FileAccess.get_file_as_string(f)) != null: creditors.append(f)
	t.check(creditors.is_empty(), "no random Aethel: no game script credits coins (only owner tools/tests) %s" % [creditors])

static func _walk(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"): out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir): _walk(dir.path_join(d), out)

## Docs: parity inventory, legal gates doc, Foxy specs, tracker rows, wiki pages.
static func run_docs(t: Node) -> void:
	var par := FileAccess.get_file_as_string("res://docs/modules/SANDBOX_PARITY.md")
	t.check(par.length() > 8000, "sbx docs: SANDBOX_PARITY.md present")
	for src in ["The Sims", "Grand Theft Auto", "League of Angels", "Skyrim", "Game of Thrones Slots Casino", "InWorldz", "Kitely", "Minecraft", "Roblox", "No Man's Sky", "Rust", "Valheim", "Garry's Mod", "Fallout", "Red Dead Online", "Animal Crossing", "IMVU", "Sansar", "VRChat", "Decentraland", "The Sandbox", "Entropia Universe", "Active Worlds"]:
		t.check(par.contains(src), "sbx docs: parity covers " + src)
	t.check(par.contains("| Source | Feature | Viper status | Owner | Tracker |"), "sbx docs: parity table columns")
	t.check(par.contains("LEGAL REVIEW") and par.contains("free-play"), "sbx docs: legal review + free-play notes")
	var lg := FileAccess.get_file_as_string("res://docs/modules/LEGAL_REVIEW_GATES.md")
	for w in ["ALLOWED", "LATER", "HARD-DISABLED", "play_tokens", "aethel_coin"]: t.check(lg.contains(w), "sbx docs: legal gates doc mentions " + w)
	var specs: Array = Array(DirAccess.get_files_at("res://docs/specs/foxy")).filter(func(f): return f.begins_with("sbx_") and f.ends_with(".md"))
	t.check(specs.size() >= 8, "sbx docs: Foxy specs (%d)" % specs.size())
	var csv := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	t.check(not csv.contains("\r"), "sbx docs: tracker LF endings")
	for id in ["SBX-1,", "SBX-2,", "SBX-3,", "SBX-4,", "SBX-5,", "SBX-6,", "SBX-7,", "SBX-LEGAL-1,", "SBX-LEGAL-2,", "SBX-LEGAL-3,", "SBX-LEGAL-4,", "SBX-LEGAL-5,"]:
		t.check(csv.contains("\n" + id), "sbx docs: tracker row " + id.trim_suffix(","))
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	for p in ["SandboxParity", "LegalReviewGates", "QuestsMissions", "OnDemandWorlds", "MarketDelivery", "FreePlayGames"]:
		t.check(wiki is Dictionary and wiki.has(p), "sbx docs: wiki seed has " + p)
