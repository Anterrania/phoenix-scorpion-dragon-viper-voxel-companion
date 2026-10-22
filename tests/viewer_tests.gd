extends RefCounted
## Viewer parity (VIEWER-1..5): ParcelTools (About Land / Region-Estate), ModerationLists (mute, block,
## derender), Restrictions (opt-in RLV-style API), the Land & Safety admin screen, docs + wiki.
## Throwaway roots; restores every static it touches.

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func _setup(root: String) -> void:
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(root.path_join("security/estop.json"))
	Tiers.reset_for_tests(root.path_join("social")); Social.reset_for_tests(root.path_join("social"))
	ModerationLists.reset_for_tests(root.path_join("social"))
	Restrictions.reset_for_tests(root.path_join("security"))
	ParcelTools.reset_for_tests(root.path_join("world"))
	Estate.reset_for_tests(); Estate._cfg = ConfigFile.new()   # in-memory estate
	Tiers.owner_override = false

static func _teardown(root: String, saved_vault: String, saved_estop: String) -> void:
	Tiers.owner_override = null
	OwnerVault.reset_for_tests(saved_vault, CryptoBox.DEFAULT_ITERATIONS); SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(saved_estop)
	Tiers.reset_for_tests("user://social"); Social.reset_for_tests("user://social")
	ModerationLists.reset_for_tests("user://social"); Restrictions.reset_for_tests("user://security")
	ParcelTools.reset_for_tests("user://world")
	Estate.reset_for_tests()
	_rm_tree(root)

static func run(t: Node) -> void:
	var root := "user://test_viewer_%d" % Time.get_ticks_usec()
	var saved_vault := OwnerVault.root
	var saved_estop := AutonomyGuard.path
	_setup(root)
	var R := "v_reg"; var P := "1_1"

	# ---------- parcel tools: permissions ----------
	t.check(ParcelTools.set_general("stranger", R, P, {"name": "X"}) != "", "parcel: guests can't edit")
	t.check(ParcelTools.set_general(Tiers.OWNER_ID, R, P, {"name": "X"}) != "", "parcel: locked owner can't edit")
	Tiers.owner_override = true
	t.check(Tiers.set_tier("v_mgr", "estate_manager") == "" and Tiers.set_tier("v_res", "resident") == "" and Tiers.set_tier("v_res2", "resident") == "", "parcel: tiers set up")
	t.check(ParcelTools.set_general(Tiers.OWNER_ID, R, P, {"name": "  Ember [b]Cove[/b] ", "description": "Beach", "category": "hangout"}) == "", "parcel: owner edits general")
	var g := ParcelTools.general(R, P)
	t.check(g["name"] == "Ember (b)Cove(/b)" and g["category"] == "hangout" and g["area_m2"] == 4096, "parcel: name cleaned, category, area")
	t.check(ParcelTools.set_general(Tiers.OWNER_ID, R, P, {"category": "nope"}) != "", "parcel: unknown category refused")
	t.check(not g["sale_price_active"], "parcel: land sale price INACTIVE (legal review)")
	t.check(ParcelTools.set_general("v_mgr", R, P, {"description": "Mgr edit"}) == "", "parcel: estate manager tier edits")
	t.check(ParcelTools.set_general("v_res", R, P, {"name": "Mine"}) != "", "parcel: resident can't edit someone else's parcel")
	t.check(ParcelTools.set_general(Tiers.OWNER_ID, R, P, {"owner_id": "v_res"}) == "" and ParcelTools.set_general("v_res", R, P, {"name": "Mine"}) == "", "parcel: owner hands parcel over; parcel owner edits")
	t.check(ParcelTools.set_general("v_res", R, P, {"owner_id": "v_res2"}) != "", "parcel: parcel owner can't reassign ownership")
	t.check(ParcelTools.set_general("v_res", R, "2_2", {"name": "Nope"}) != "", "parcel: parcel owner can't edit other parcels")
	# estate managers list
	t.check(ParcelTools.add_manager("v_mgr", R, "v_res2") != "", "estate: only owner adds managers")
	t.check(ParcelTools.add_manager(Tiers.OWNER_ID, R, "foxy_ani") != "", "estate: companions can't be managers")
	t.check(ParcelTools.add_manager(Tiers.OWNER_ID, R, "v_res2") == "" and ParcelTools.is_manager(R, "v_res2"), "estate: owner adds a manager")
	t.check(ParcelTools.set_general("v_res2", R, "2_2", {"name": "Managed"}) == "", "estate: listed manager edits parcels in that region")
	t.check(ParcelTools.set_general("v_res2", "other_reg", "2_2", {"name": "x"}) != "", "estate: manager rights are per region")
	t.check(ParcelTools.estate_message("v_res2", R, "Restart soon") == "" and ParcelTools.events.back()["kind"] == "estate_message", "estate: manager sends an estate message")
	t.check(ParcelTools.estate_message("stranger", R, "spam") != "", "estate: strangers can't message the estate")
	t.check(ParcelTools.region_debug(Tiers.OWNER_ID, R, "Restart region").get("inactive", false), "estate: region restart stubbed INACTIVE")
	t.check(ParcelTools.remove_manager(Tiers.OWNER_ID, R, "v_res2") == "" and not ParcelTools.is_manager(R, "v_res2"), "estate: owner removes a manager")
	Tiers.owner_override = false
	t.check(ParcelTools.set_general("v_mgr", R, P, {"name": "x"}) == "", "estate: estate-manager tier doesn't need the owner unlock")
	t.check(ParcelTools.set_general(Tiers.OWNER_ID, R, P, {"name": "x"}) != "", "parcel: owner powers need unlock")
	Tiers.owner_override = true

	# ---------- access ----------
	t.check(ParcelTools.allow(Tiers.OWNER_ID, R, P, "friend1") == "" and "friend1" in ParcelTools.allowed(R, P), "access: allow list add")
	t.check(ParcelTools.ban(Tiers.OWNER_ID, R, P, "friend1", 0.0) == "" and "friend1" in ParcelTools.banned(R, P) and not "friend1" in ParcelTools.allowed(R, P), "access: ban removes from allowed")
	t.check(ParcelTools.ban(Tiers.OWNER_ID, R, P, Tiers.OWNER_ID) != "", "access: owner can't be banned")
	t.check(ParcelTools.ban("v_mgr", R, P, "v_mgr") != "", "access: can't ban yourself")
	Estate.parcel_set(R, P, "access", "public")
	t.check(not Tiers.can("friend1", "enter", {"region": R, "parcel": P}), "access: Tiers honours ParcelTools bans")
	t.check(ParcelTools.ban(Tiers.OWNER_ID, R, P, "griefer", 1.0) == "" and "griefer" in ParcelTools.banned(R, P), "access: timed ban")
	t.check(ParcelTools.sweep_bans(R, P) == 0, "access: timed ban still active")
	t.check(ParcelTools.sweep_bans(R, P, int(Time.get_unix_time_from_system()) + 7200) == 1 and not "griefer" in ParcelTools.banned(R, P) and "friend1" in ParcelTools.banned(R, P), "access: expired timed ban lifted, permanent stays")
	t.check(ParcelTools.unban(Tiers.OWNER_ID, R, P, "friend1") == "" and not "friend1" in ParcelTools.banned(R, P), "access: unban")
	t.check(ParcelTools.set_access(Tiers.OWNER_ID, R, P, {"access": "bogus"}) != "", "access: unknown access refused")
	t.check(ParcelTools.set_access(Tiers.OWNER_ID, R, P, {"adult_only": true}) == "", "access: adult-only flag")
	t.check(not ParcelTools.entry_ok("v_res2", R, P, false) and ParcelTools.entry_ok("v_res2", R, P, true), "access: adult-only needs the adult flag")
	t.check(ParcelTools.entry_ok(Tiers.OWNER_ID, R, P, false), "access: owner always enters")
	ParcelTools.set_access(Tiers.OWNER_ID, R, P, {"adult_only": false})

	# ---------- options ----------
	t.check(ParcelTools.set_options(Tiers.OWNER_ID, R, P, {"tp_routing": "landing_point", "landing_point": Vector3(10, 5, 12)}) == "", "options: landing point + routing")
	t.check(ParcelTools.teleport_target("v_res2", R, P, Vector3(1, 1, 1)) == Vector3(10, 5, 12), "options: visitors land on the landing point")
	t.check(ParcelTools.teleport_target(Tiers.OWNER_ID, R, P, Vector3(1, 1, 1)) == Vector3(1, 1, 1), "options: owner lands where asked")
	ParcelTools.set_options(Tiers.OWNER_ID, R, P, {"tp_routing": "blocked"})
	t.check(ParcelTools.teleport_target("v_res2", R, P, Vector3.ONE) == null, "options: blocked routing refuses teleports")
	t.check(ParcelTools.set_options(Tiers.OWNER_ID, R, P, {"tp_routing": "sideways"}) != "", "options: unknown routing refused")

	# ---------- media ----------
	t.check(ParcelTools.set_media(Tiers.OWNER_ID, R, P, {"music_url": "https://example.com/live.mp3", "media_loop": true}) == "", "media: https music url")
	t.check(str(Estate.parcel_get(R, P, "music_url")) == "https://example.com/live.mp3", "media: shares Estate music_url (radio reads it)")
	t.check(ParcelTools.set_media(Tiers.OWNER_ID, R, P, {"media_url": "javascript:alert(1)"}) != "" and ParcelTools.set_media(Tiers.OWNER_ID, R, P, {"media_url": "file:///etc/passwd"}) != "", "media: non-web urls refused")
	t.check(ParcelTools.set_media(Tiers.OWNER_ID, R, P, {"media_url": ""}) == "", "media: blank url clears")

	# ---------- objects ----------
	ParcelTools.set_general(Tiers.OWNER_ID, R, P, {"owner_id": "v_res"})
	var o1 := ParcelTools.register_object("v_res", R, P, {"impact": 3})
	var o2 := ParcelTools.register_object("visitor", R, P, {"rezzed": 1000})
	var o3 := ParcelTools.register_object("visitor2", R, P)
	t.check(o1 != "" and o2 != "" and o3 != "", "objects: registry accepts objects")
	var n := ParcelTools.object_counts(R, P)
	t.check(n["owner"] == 3 and n["other"] == 2 and n["total"] == 5 and n["by_owner"]["visitor"] == 1, "objects: land impact by class + owner")
	t.check(ParcelTools.auto_return_sweep(R, P) == 0, "objects: auto-return off by default")
	t.check(ParcelTools.set_auto_return("v_res", R, P, 10) == "", "objects: parcel owner sets auto-return")
	t.check(ParcelTools.auto_return_sweep(R, P) == 1 and ParcelTools.lost_and_found("visitor").size() == 1, "objects: old visitor object auto-returned to Lost and Found")
	t.check(ParcelTools.return_objects("v_res2", R, P, {"class": "other"})["ok"] == false, "objects: non-managers can't return")
	var rr := ParcelTools.return_objects("v_res", R, P, {"owner": "visitor2"})
	t.check(rr["ok"] and rr["returned"] == 1 and ParcelTools.object_counts(R, P)["other"] == 0, "objects: return by owner")
	t.check(ParcelTools.object_counts(R, P)["owner"] == 3, "objects: owner's objects untouched")
	ParcelTools.reset_for_tests(root.path_join("world"))
	t.check(ParcelTools.lost_and_found("visitor2").size() == 1 and ParcelTools.objects_on(R, P).size() == 1, "objects: registry + Lost and Found persist")

	# ---------- e-stop: bots ----------
	AutonomyGuard.engage("test")
	t.check(not ParcelTools.can_manage_parcel("foxy_ani", R, P), "parcel: e-stop leaves bots browse-only")
	AutonomyGuard.reset_for_tests(root.path_join("security/estop2.json"))   # fresh, released guard

	# ---------- moderation lists ----------
	t.check(ModerationLists.mute("v_res", "loud", "avatar", ["chat"])["ok"] and ModerationLists.is_muted("v_res", "loud", "chat") and not ModerationLists.is_muted("v_res", "loud", "voice"), "mute: per channel")
	t.check(not ModerationLists.is_muted("v_res2", "loud", "chat"), "mute: lists are per viewer")
	t.check(ModerationLists.mute("v_res", "v_res")["ok"] == false and ModerationLists.mute("v_res", "x", "bogus")["ok"] == false, "mute: self + unknown kind refused")
	var lines := [{"from": "loud", "text": "a"}, {"from": "nice", "text": "b"}]
	t.check(ModerationLists.filter_lines("v_res", lines).size() == 1, "mute: chat filter drops muted lines")
	t.check(ModerationLists.mute("stranger", "loud")["ok"], "mute: works for guests (no tier)")
	t.check(ModerationLists.block("v_res", "troll")["ok"] and Social.is_blocked("v_res", "troll") and ModerationLists.is_muted("v_res", "troll", "voice"), "block: Social.block + mute all")
	t.check(ModerationLists.unblock("v_res", "troll")["ok"] and not Social.is_blocked("v_res", "troll") and not ModerationLists.is_muted("v_res", "troll"), "block: unblock undoes both")
	Social.block("v_res", "old_block")
	t.check(ModerationLists.is_muted("v_res", "old_block", "im"), "mute: earlier Social blocks count as muted for chat/IM")
	t.check(ModerationLists.unmute("v_res", "loud")["ok"] and not ModerationLists.is_muted("v_res", "loud"), "mute: unmute")
	t.check(ModerationLists.derender("v_res", "ugly_tree", "object", true)["ok"] and ModerationLists.derender("v_res", "photo_bomb", "avatar", false)["ok"], "derender: permanent + temporary")
	t.check(ModerationLists.is_derendered("v_res", "ugly_tree") and ModerationLists.is_derendered("v_res", "photo_bomb") and ModerationLists.derendered("v_res").size() == 2, "derender: both hidden")
	ModerationLists.on_teleport("v_res")
	t.check(not ModerationLists.is_derendered("v_res", "photo_bomb") and ModerationLists.is_derendered("v_res", "ugly_tree"), "derender: temporary cleared on teleport, blacklist stays")
	t.check(ModerationLists.set_rerender_after_tp("v_res", false)["ok"], "derender: pref off")
	ModerationLists.derender("v_res", "photo_bomb", "avatar", false); ModerationLists.on_teleport("v_res")
	t.check(ModerationLists.is_derendered("v_res", "photo_bomb") and ModerationLists.clear_temporary("v_res") == 1, "derender: pref off keeps temporary until Clear temporary")
	ModerationLists.reload_data()
	t.check(ModerationLists.is_derendered("v_res", "ugly_tree"), "moderation: blacklist persists")
	t.check(ModerationLists.is_muted("stranger", "loud") and not ModerationLists.is_muted("v_res", "loud"), "moderation: mute list persists")
	t.check(not ModerationLists.rerender_after_tp("v_res"), "moderation: derender pref persists")
	t.check(ModerationLists.rerender("v_res", "ugly_tree")["ok"] and not ModerationLists.is_derendered("v_res", "ugly_tree"), "derender: rerender")
	t.check(ModerationLists.block("foxy_ani", Tiers.OWNER_ID)["ok"] == false, "block: companions can't block the owner")

	# ---------- restrictions ----------
	var S := "v_res"
	t.check(Restrictions.add("v_res2", S, "fly") != "" and not Restrictions.is_restricted(S, "fly"), "restrict: off by default")
	t.check(Restrictions.enable(S, S, false) != "", "restrict: needs 18+ confirmation")
	t.check(Restrictions.enable("v_res2", S, true) != "", "restrict: nobody opts someone else in")
	t.check(Restrictions.enable("stranger", "stranger", true) != "", "restrict: guests can't opt in")
	t.check(Restrictions.enable(S, S, true) == "" and Restrictions.enabled(S), "restrict: subject opts in")
	t.check(Restrictions.add("v_res2", S, "fly") != "", "restrict: unconsented source refused")
	t.check(Restrictions.consent(S, S, "v_res2") == "", "restrict: subject consents to a source")
	t.check(Restrictions.add("v_res2", S, "fly", 30) == "" and Restrictions.is_restricted(S, "fly"), "restrict: consented source restricts flying")
	t.check(Restrictions.add("v_res2", S, "safeword") != "" and Restrictions.add("v_res2", S, "admin") != "" and Restrictions.add("v_res2", S, "tpto_force") != "", "restrict: NEVER list + no unknown/forced behaviours")
	t.check(not Restrictions.is_restricted(S, "safeword"), "restrict: safety controls never restricted")
	AutonomyGuard.engage("test")
	t.check(not Restrictions.is_restricted(S, "fly") and Restrictions.add("v_res2", S, "tplm") != "", "restrict: e-stop suspends everything")
	AutonomyGuard.reset_for_tests(root.path_join("security/estop3.json"))
	t.check(Restrictions.is_restricted(S, "fly"), "restrict: resumes after e-stop release")
	t.check(Restrictions.safeword(S) == 1 and not Restrictions.is_restricted(S, "fly"), "restrict: safeword clears all")
	Restrictions.add("v_res2", S, "tplm")
	t.check(Restrictions.revoke(S, S, "v_res2") == "" and not Restrictions.is_restricted(S, "tplm"), "restrict: revoking consent clears that source")
	t.check(Restrictions.enable(Tiers.OWNER_ID, "foxy_ani", true) == "" and Restrictions.consent(Tiers.OWNER_ID, "foxy_ani", "v_res2") == "", "restrict: owner opts a companion in")
	Tiers.owner_override = false
	t.check(Restrictions.enable("v_res2", "foxy_ani", true) != "" and Restrictions.consent("v_res2", "foxy_ani", "v_mgr") != "", "restrict: never on companions without the owner")
	t.check(Restrictions.set_global_off(Tiers.OWNER_ID, true) != "", "restrict: switch-off needs owner unlock")
	Tiers.owner_override = true
	Restrictions.consent(S, S, "v_res2"); Restrictions.add("v_res2", S, "rez")
	t.check(Restrictions.set_global_off(Tiers.OWNER_ID, true) == "" and not Restrictions.is_restricted(S, "rez") and Restrictions.enable(S, S, true) != "", "restrict: owner switches the API off for everyone")
	t.check(Restrictions.set_global_off(Tiers.OWNER_ID, false) == "" and Restrictions.owner_clear_all(Tiers.OWNER_ID) == "", "restrict: owner switches it back on, clears all")
	Restrictions.reset_for_tests(root.path_join("security"))
	t.check(Restrictions.enabled(S) and "v_res2" in Restrictions.consents(S) and Restrictions.active(S).is_empty(), "restrict: opt-in + consent persist, active restrictions are session-only")
	t.check(Restrictions.disable(S, S) == "" and not Restrictions.enabled(S), "restrict: subject opts out")
	_teardown(root, saved_vault, saved_estop)

static func run_docs(t: Node) -> void:
	var doc := FileAccess.get_file_as_string("res://docs/modules/VIEWER_PARITY.md")
	t.check(doc.contains("| feature | Firestorm | Phoenix | DarkStorm | Avination | OLG 3DX | ours | owner | status |"), "viewer docs: parity table header")
	for s in ["## Firestorm / Phoenix / DarkStorm", "## Grid side", "## Space sims", "DarkStorm"]: t.check(doc.contains(s), "viewer docs: section " + s)
	t.check(FileAccess.get_file_as_string("res://docs/modules/RESTRICTIONS.md").contains("opt-in"), "viewer docs: restrictions decision record")
	t.check(not FileAccess.file_exists("res://docs/VIEWER_FEATURE_PARITY.md"), "viewer docs: single parity file")
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	for p in ["ViewerFeatures", "LandSafety", "MuteBlockDerender", "Restrictions", "ViewerParity"]: t.check(wiki is Dictionary and wiki.has(p), "viewer docs: wiki seed has " + p)
	var idx := FileAccess.get_file_as_string("res://docs/wiki/INDEX.md")
	for f in ["viewer-features.md", "land-safety.md", "mute-block-derender.md", "restrictions.md"]: t.check(idx.contains(f), "viewer docs: INDEX links " + f)
	var tk: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/tickets_seed.json"))
	var found := 0
	for x in tk:
		if str(x.get("milestone", "")).begins_with("VIEWER-"): found += 1
	t.check(found >= 6, "viewer docs: VIEWER tickets seeded (%d)" % found)

static func run_ui(t: Node) -> void:
	var root := "user://test_viewer_ui_%d" % Time.get_ticks_usec()
	var saved_vault := OwnerVault.root
	var saved_estop := AutonomyGuard.path
	_setup(root)
	var s: LandSafetyScreen = load("res://scenes/admin/land_safety_screen.tscn").instantiate()
	s.region = "ui_reg"; s.parcel = "0_0"
	t.get_tree().root.add_child(s)
	await t.get_tree().process_frame
	t.check(s.pages.count() == 5, "land & safety ui: 5 swipe tabs (kit max)")
	t.check(not s.can_edit(), "land & safety ui: view only while locked")
	t.check(s.min_font_ok(PhoenixTokens.TYPE["micro"]), "land & safety ui: text >= compact micro size")
	t.check(s.min_tap_ok(PhoenixTokens.TAP_MIN), "land & safety ui: taps >= TAP_MIN")
	t.check(s.find_child("Safeword", true, false) is Button, "land & safety ui: safeword button always present")
	Tiers.owner_override = true
	s.refresh()
	t.check(s.can_edit(), "land & safety ui: unlocked owner edits")
	var nm: LineEdit = s.find_child("ParcelName", true, false)
	t.check(nm != null, "land & safety ui: parcel name field")
	s.queue_free()
	await t.get_tree().process_frame
	_teardown(root, saved_vault, saved_estop)
