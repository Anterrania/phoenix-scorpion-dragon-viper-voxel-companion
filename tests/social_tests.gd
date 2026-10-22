extends RefCounted
## Tiers (permission matrix, estate combine, owner session, e-stop) + Social (profiles, picks, friends,
## followers, blocks, messages + offline queue, groups + land, feed + companion approval, reports +
## moderation, roadmap stubs, encrypted persistence) + the admin Community screen.
## Throwaway roots; restores every static it touches.

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func run(t: Node) -> void:
	var root := "user://test_social_%d" % Time.get_ticks_usec()
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
	Social.reset_for_tests(root.path_join("social"))
	Estate.reset_for_tests(); Estate._cfg = ConfigFile.new()   # in-memory estate for the test
	Tiers.owner_override = false

	# ---------- tiers ----------
	t.check(Tiers.ORDER.size() == 6 and Tiers.ORDER[0] == "guest" and Tiers.ORDER[5] == "owner", "tiers: six tiers in order")
	t.check(Tiers.can("stranger", "browse") and not Tiers.can("stranger", "post"), "tiers: guests browse, can't post")
	t.check(Tiers.can("stranger", "report"), "tiers: guests can report")
	t.check(not Tiers.can("stranger", "bogus_action"), "tiers: unknown action denied")
	t.check(not Tiers.can("", "browse"), "tiers: empty actor denied")
	t.check(Tiers.tier_of(Tiers.OWNER_ID) == "guest", "tiers: locked owner acts as guest")
	t.check(not Tiers.can(Tiers.OWNER_ID, "admin") and not Tiers.can(Tiers.OWNER_ID, "moderate"), "tiers: locked owner has no owner powers")
	t.check(Tiers.set_tier("ex_res", "resident") != "", "tiers: role editor refuses without owner unlock")
	Tiers.owner_override = true
	t.check(Tiers.can(Tiers.OWNER_ID, "admin") and Tiers.can(Tiers.OWNER_ID, "roles"), "tiers: unlocked owner has admin")
	t.check(Tiers.set_tier("ex_res", "resident") == "" and Tiers.set_tier("ex_cre", "creator") == "" and Tiers.set_tier("ex_staff", "staff") == "" and Tiers.set_tier("ex_mgr", "estate_manager") == "", "tiers: owner assigns tiers")
	t.check(Tiers.set_tier("ex_res", "owner") != "" and Tiers.set_tier(Tiers.OWNER_ID, "guest") != "", "tiers: nobody can be made owner; owner can't be demoted")
	t.check(Tiers.can("ex_res", "post") and not Tiers.can("ex_res", "album") and not Tiers.can("ex_res", "classified"), "tiers: residents post, no albums/classifieds")
	t.check(Tiers.can("ex_cre", "album") and Tiers.can("ex_cre", "classified") and not Tiers.can("ex_cre", "moderate"), "tiers: creators get albums + classifieds, don't moderate")
	t.check(Tiers.can("ex_staff", "moderate") and not Tiers.can("ex_staff", "land") and not Tiers.can("ex_staff", "admin"), "tiers: staff moderate, no land/admin")
	t.check(Tiers.can("ex_mgr", "land") and Tiers.can("ex_mgr", "moderate") and not Tiers.can("ex_mgr", "roles"), "tiers: estate manager land + moderate, not roles")
	t.check(Tiers.tier_of({"id": "ex_res", "tier": "staff"}) == "resident" and Tiers.tier_of({"id": "ex_staff", "tier": "guest"}) == "guest", "tiers: dict actor can lower but never raise its tier")
	t.check(Tiers.set_matrix("resident", ["browse", "report", "admin", "roles", "post"]) == "" and not Tiers.can("ex_res", "message") and not Tiers.can("ex_res", "admin"), "tiers: owner matrix override applies; admin/roles never grantable")
	t.check(Tiers.reset_matrix() == "" and Tiers.can("ex_res", "message"), "tiers: reset matrix to defaults")
	Tiers.reload_roles()
	t.check(Tiers.tier_of("ex_cre") == "creator", "tiers: assignments persist across reload")
	t.check(Tiers.is_bot("foxy_ani") and Tiers.tier_of("foxy_ani") == "resident", "tiers: companions are residents by default")
	t.check(Tiers.membership("creator").has("perks") and Tiers.membership("nope") == Tiers.MEMBERSHIP["guest"], "tiers: membership hooks")
	t.check(Tiers.can("ex_res", "edit_profile", "ex_res") and not Tiers.can("ex_res", "edit_profile", "ex_cre"), "tiers: edit own profile only")
	t.check(not Tiers.can("ex_mgr", "edit_profile", Tiers.OWNER_ID) and Tiers.can(Tiers.OWNER_ID, "edit_profile", Tiers.OWNER_ID), "tiers: owner profile is owner-only")

	# ---------- tiers x estate ----------
	Estate.region_set("t_reg", "allow_build", true)
	t.check(Tiers.can(Tiers.OWNER_ID, "build", "t_reg/0_0"), "land: owner builds anywhere")
	t.check(not Tiers.can("ex_res", "build", "t_reg/0_0") and Tiers.can("ex_staff", "build", "t_reg/0_0"), "land: owner_only terraform -> staff build, residents don't")
	Estate.parcel_set("t_reg", "1_1", "terraform", "everyone")
	t.check(Tiers.can("ex_res", "build", {"region": "t_reg", "parcel": "1_1"}), "land: terraform=everyone lets residents build")
	t.check(not Tiers.can("stranger", "build", "t_reg/1_1"), "land: guests never build")
	Estate.parcel_set("t_reg", "1_1", "banned", ["ex_res"])
	t.check(not Tiers.can("ex_res", "build", "t_reg/1_1") and not Tiers.can("ex_res", "enter", "t_reg/1_1"), "land: ban list always wins")
	Estate.parcel_set("t_reg", "1_1", "allow_build", false)
	t.check(not Tiers.can("ex_staff", "build", "t_reg/1_1") and Tiers.can(Tiers.OWNER_ID, "build", "t_reg/1_1"), "land: allow_build=false -> owner only")
	Estate.parcel_set("t_reg", "2_2", "access", "owner_only")
	t.check(not Tiers.can("ex_mgr", "enter", "t_reg/2_2") and not Tiers.can("ex_staff", "build", "t_reg/2_2"), "land: owner_only access keeps everyone out")
	t.check(Tiers.can("ex_mgr", "land", "t_reg/0_0") and not Tiers.can("ex_staff", "land", "t_reg/0_0"), "land: land settings = estate manager")
	t.check(not Tiers.can("ex_res", "build", ""), "land: empty region denied")

	# ---------- profiles ----------
	t.check(Social.profile("ex_res").is_empty(), "social: no profiles until created (no seed data)")
	t.check(Social.set_profile("ex_res", "ex_res", {"display_name": "Example Resident", "about": "[b]hi[/b]", "interests": ["voxels", "music"]})["ok"], "social: create own profile")
	t.check(Social.profile("ex_res")["about"] == "(b)hi(/b)", "social: BBCode neutralised")
	t.check(not Social.set_profile("ex_res", "ex_cre", {"about": "x"})["ok"], "social: can't edit someone else's profile")
	t.check(not Social.set_profile("ex_res", "ex_res", {"display_name": "  "})["ok"], "social: empty name rejected")
	Tiers.owner_override = false
	t.check(not Social.set_profile(Tiers.OWNER_ID, Tiers.OWNER_ID, {"about": "x"})["ok"], "social: owner profile locked without owner unlock")
	Tiers.owner_override = true
	t.check(Social.set_profile(Tiers.OWNER_ID, Tiers.OWNER_ID, {"display_name": "Owner"})["ok"], "social: unlocked owner edits owner profile")
	t.check(Social.add_pick("ex_res", "ex_res", {"title": "Welcome Island", "region": "welcome", "note": "start here"})["ok"], "social: add pick")
	t.check(not Social.add_pick("ex_res", "ex_res", {"title": ""})["ok"], "social: pick needs a title")
	for i in 12: Social.add_pick("ex_res", "ex_res", {"title": "p%d" % i})
	t.check(Social.profile("ex_res")["picks"].size() == Social.MAX_PICKS, "social: picks capped at 10")
	t.check(Social.remove_pick("ex_res", "ex_res", 0)["ok"] and Social.profile("ex_res")["picks"].size() == 9, "social: remove pick")
	t.check(Social.profile("ex_res")["tier_label"] == "Resident", "social: profile shows tier")
	Social.set_profile("ex_cre", "ex_cre", {"display_name": "Example Creator"})
	Social.set_profile("ex_staff", "ex_staff", {"display_name": "Example Staff"})

	# ---------- friends / followers / blocks ----------
	t.check(not Social.friend_request("stranger", "ex_res")["ok"], "friends: guests can't friend")
	t.check(Social.friend_request("ex_res", "ex_cre")["ok"] and Social.friend_requests("ex_cre") == ["ex_res"], "friends: request pending")
	t.check(Social.notifications("ex_cre").size() == 1, "notify: friend request notifies")
	t.check(not Social.friend_accept("ex_res", "ex_cre")["ok"], "friends: requester can't self-accept")
	t.check(Social.friend_accept("ex_cre", "ex_res")["ok"] and Social.friends_of("ex_res") == ["ex_cre"], "friends: accepted")
	t.check(Social.follow("ex_staff", "ex_cre")["ok"] and Social.followers_of("ex_cre") == ["ex_staff"], "follow: follower")
	t.check(Social.block("ex_cre", "ex_staff")["ok"] and Social.followers_of("ex_cre").is_empty(), "block: removes follow")
	t.check(not Social.friend_request("ex_staff", "ex_cre")["ok"] and not Social.send_message("ex_staff", "ex_cre", "hi")["ok"], "block: no requests or messages either way")
	t.check(Social.profile("ex_cre", "ex_staff").is_empty(), "block: blocked viewer can't see profile")
	t.check(Social.friend_remove("ex_res", "ex_cre")["ok"] and Social.friends_of("ex_res").is_empty(), "friends: remove")
	Social.friend_request("ex_res", "ex_cre"); Social.friend_accept("ex_cre", "ex_res")

	# ---------- messages ----------
	var m := Social.send_message("ex_res", "ex_cre", "hello there")
	t.check(m["ok"] and m["state"] == "delivered" and Social.inbox("ex_cre", true).size() == 1, "im: delivered to local inbox")
	t.check(Social.mark_read("ex_cre", m["id"])["ok"] and Social.inbox("ex_cre", true).is_empty(), "im: mark read")
	var q := Social.send_message("ex_res", "far_away", "see you")
	t.check(q["ok"] and q["state"] == "queued" and Social.outbox("ex_res").size() == 1, "im: unknown recipient -> offline queue")
	t.check(Social.flush_outbox() == 0, "im: still queued while offline")
	Social.set_profile(Tiers.OWNER_ID, "far_away", {"display_name": "Far Away", "kind": "example"})
	t.check(Social.flush_outbox() == 1 and Social.inbox("far_away").size() == 1 and Social.outbox("ex_res").is_empty(), "im: queue flushes once recipient is known")
	t.check(not Social.send_message("ex_res", "ex_cre", "x".repeat(5000))["ok"] or Social.inbox("ex_cre")[-1]["text"].length() <= Social.MAX_MSG, "im: length capped")
	t.check(not Social.send_message("ex_res", "ex_res", "me")["ok"], "im: can't message yourself")

	# ---------- groups ----------
	t.check(not Social.group_create("ex_res", "Builders")["ok"], "groups: residents can't create")
	var g := Social.group_create("ex_cre", "Example Builders", {"tag": "BUILDERSXYZ", "open": false})
	t.check(g["ok"] and Social.group(g["id"])["tag"].length() <= 8, "groups: creator creates, tag capped")
	var gid: String = g["id"]
	t.check(not Social.group_create("ex_cre", "example builders")["ok"], "groups: names unique")
	t.check(not Social.group_join("ex_res", gid)["ok"], "groups: invite-only refuses")
	t.check(Social.group_invite("ex_cre", gid, "ex_res")["ok"] and Social.group_join("ex_res", gid)["ok"], "groups: invite then join")
	t.check(Social.groups_of("ex_res")[0]["role"] == "member", "groups: groups_of with role")
	t.check(not Social.group_set_role("ex_res", gid, "ex_res", "officer")["ok"], "groups: members can't promote")
	t.check(Social.group_set_role("ex_cre", gid, "ex_res", "officer")["ok"] and Social.groups_of("ex_res")[0]["role"] == "officer", "groups: owner promotes")
	t.check(Social.group_notice("ex_res", gid, "Build night Friday")["ok"] and Social.group(gid)["notice"]["text"] == "Build night Friday", "groups: officer posts notice")
	t.check(not Social.group_leave("ex_cre", gid)["ok"], "groups: last owner can't leave a group with members")
	t.check(not Social.group_claim_land("ex_cre", gid, "t_reg", "3_3")["ok"], "groups: only owner/estate manager assigns land")
	t.check(Social.group_claim_land("ex_mgr", gid, "t_reg", "3_3")["ok"], "groups: estate manager gives group land")
	t.check(Estate.parcel_get("t_reg", "3_3", "access") == "group_only" and Tiers.land_group({"region": "t_reg", "parcel": "3_3"}) == gid, "groups: parcel becomes group_only, linked to group")
	t.check(Tiers.can("ex_res", "build", "t_reg/3_3") and Tiers.can("ex_res", "enter", "t_reg/3_3"), "groups: members enter + build on group land")
	t.check(not Tiers.can("far_away", "enter", "t_reg/3_3"), "groups: non-members kept out of group land")

	# ---------- feed + companion approval ----------
	t.check(not Social.post("stranger", "hi")["ok"], "feed: guests can't post")
	var p1 := Social.post("ex_res", "first post")
	t.check(p1["ok"] and p1["state"] == "published", "feed: resident posts")
	Social.post("ex_res", "friends only", {"visibility": "friends"})
	Social.post("ex_res", "group only", {"visibility": "group:" + gid})
	t.check(not Social.post("ex_staff", "x", {"visibility": "group:" + gid})["ok"], "feed: can't post to a group you're not in")
	t.check(Social.feed("stranger").size() == 1, "feed: guest sees public only")
	t.check(Social.feed("ex_cre").size() == 3, "feed: friend + group member sees all")
	t.check(Social.feed("ex_staff").size() == 1, "feed: non-friend sees public")
	var cp := Social.post("foxy_ani", "Look at my new build!")
	t.check(cp["ok"] and cp["state"] == "pending_approval", "feed: companion post waits for owner approval")
	t.check(Social.feed("ex_cre", 50, "foxy_ani").is_empty(), "feed: unapproved companion post not visible")
	var props := EveCore.proposals(true).filter(func(x): return str(x["description"]).begins_with(Social.PROPOSAL_TAG))
	t.check(props.size() == 1 and props[0]["companion"] == "foxy_ani", "feed: companion post queued in EveCore proposals")
	EveCore.owner_override = false
	t.check(not EveCore.decide(props[0]["id"], true), "feed: non-owner can't approve")
	EveCore.owner_override = true
	t.check(EveCore.decide(props[0]["id"], true), "feed: owner approves")
	EveCore.owner_override = null
	t.check(Social.feed("ex_cre", 50, "foxy_ani").size() == 1, "feed: approved companion post published")
	var cp2 := Social.post("foxy_ani", "second")
	EveCore.owner_override = true; EveCore.decide(Social.db()["feed"].filter(func(x): return x["id"] == cp2["id"])[0]["proposal_id"], false); EveCore.owner_override = null
	Social.sync_approvals()
	t.check(Social.db()["feed"].filter(func(x): return x["id"] == cp2["id"])[0]["state"] == "rejected", "feed: rejected companion post never published")
	AutonomyGuard.engage("test")
	t.check(not Social.post("foxy_ani", "during e-stop")["ok"] and Social.feed("ex_cre").size() > 0, "estop: companions can't post; people unaffected")
	AutonomyGuard.reset_for_tests(root.path_join("security/estop2.json"))

	# ---------- reports + moderation ----------
	var r := Social.report("stranger", "post", p1["id"], "spam")
	t.check(r["ok"], "report: anyone can report")
	t.check(not Social.report("ex_res", "planet", "x", "?")["ok"], "report: unknown kind refused")
	t.check(Social.reports("ex_res").is_empty() and Social.reports("ex_staff").size() == 1, "moderation: queue visible to staff only")
	t.check(not Social.moderate("ex_cre", r["id"], "hide")["ok"], "moderation: creators can't moderate")
	t.check(Social.moderate("ex_staff", r["id"], "hide")["ok"] and not Social.feed("stranger").any(func(x): return x["id"] == p1["id"]), "moderation: staff hides reported post")
	t.check(not Social.moderate("ex_staff", r["id"], "hide")["ok"], "moderation: decided reports are closed")
	var r2 := Social.report("ex_res", "profile", Tiers.OWNER_ID, "test")
	t.check(not Social.moderate("ex_staff", r2["id"], "hide")["ok"], "moderation: staff can't change the owner profile")
	t.check(Social.moderate("ex_staff", r2["id"], "dismiss")["ok"], "moderation: dismiss")
	Tiers.owner_override = false
	t.check(Social.reports(Tiers.OWNER_ID).is_empty(), "moderation: locked owner can't see the queue")
	Tiers.owner_override = true
	t.check(not Social.notify("ex_res", "ex_cre", "x", "y")["ok"] and Social.notify("system", "ex_cre", "event", "Build night")["ok"], "notify: system/staff only")

	# ---------- roadmap stubs ----------
	var stubs := [Social.forum_post("ex_res", "f", "t", "x"), Social.blog_post("ex_res", "t", "x"), Social.album_add("ex_cre", "a", "m"),
		Social.event_create("ex_cre", "e", 0, "welcome"), Social.poll_create("ex_cre", "q", ["a", "b"]), Social.classified_post("ex_cre", "t", "x", "slot1")]
	t.check(stubs.all(func(s): return s["error"] == "INACTIVE" and str(s["roadmap"]) != ""), "roadmap: stubs report INACTIVE with a roadmap note")
	t.check(Social.album_add("ex_res", "a", "m")["error"] == "Not allowed." and Social.classified_post("ex_res", "t", "x", "s")["error"] == "Not allowed.", "roadmap: stubs still enforce tiers (creators only)")
	t.check(Social.classified_post("ex_cre", "t", "x", "s")["roadmap"].contains("LEGAL REVIEW"), "roadmap: classifieds carry legal-review note")

	# ---------- example data ----------
	Tiers.owner_override = false
	t.check(not Social.seed_examples(Tiers.OWNER_ID)["ok"], "examples: owner-only")
	Tiers.owner_override = true
	t.check(Social.seed_examples(Tiers.OWNER_ID)["ok"] and Social.profile("example_resident")["display_name"].begins_with(Social.EXAMPLE_TAG), "examples: labelled [EXAMPLE]")
	t.check(Social.clear_examples(Tiers.OWNER_ID)["ok"] and Social.profile("example_resident").is_empty() and Social.profile("far_away").is_empty(), "examples: cleared")
	var st := Social.stats()
	t.check(st["groups"] == 1 and st["open_reports"] == 0, "social: stats")

	# ---------- persistence + encryption ----------
	Social.reload_data()
	t.check(Social.profile("ex_res")["display_name"] == "Example Resident" and Social.friends_of("ex_res") == ["ex_cre"], "persist: reload keeps profiles + friends")
	var sp := root.path_join("social/social.json")
	t.check(not SecureFile.is_sealed_file(sp), "persist: plaintext before a vault exists (same as other saves)")
	t.check(OwnerVault.setup("864213", true) == "", "persist: vault set up for test")
	Social.post("ex_res", "after vault")
	t.check(SecureFile.is_sealed_file(sp) and not FileAccess.get_file_as_string(sp).contains("Example Resident"), "persist: social save encrypted once a vault exists")
	Tiers.set_tier("ex_res", "resident")
	t.check(SecureFile.is_sealed_file(root.path_join("social/roles.json")), "persist: roles encrypted")
	OwnerVault.lock_all()
	Social.reload_data()
	t.check(Social.profile("ex_res").is_empty(), "persist: sealed + locked -> nothing readable")
	t.check(not Social.post("ex_res", "locked write")["ok"] and SecureFile.is_sealed_file(sp), "persist: locked write refused, sealed file not clobbered")
	t.check(OwnerVault.unlock("864213") == "", "persist: unlock")
	Social.reload_data()
	t.check(Social.profile("ex_res")["display_name"] == "Example Resident" and Social.feed("ex_cre", 50).any(func(x): return x["text"] == "after vault"), "persist: decrypts after unlock")

	# ---------- restore ----------
	Tiers.owner_override = null
	EveCore.owner_override = null
	EveCore.save_dir = saved_eve; EveCore.reset_cache()
	OwnerVault.reset_for_tests(saved_vault, 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(saved_estop)
	Tiers.reset_for_tests("user://social"); Social.reset_for_tests("user://social")
	BrainCore.adapter_root = BrainCore.DEFAULT_ROOT
	if had_estate:
		var f := FileAccess.open(Estate.PATH, FileAccess.WRITE); f.store_buffer(estate_raw); f.close()
	else: DirAccess.remove_absolute(Estate.PATH)
	Estate.reset_for_tests()
	t.check(FileAccess.file_exists(Estate.PATH) == had_estate, "estate: real estate.cfg restored byte-for-byte")
	_rm_tree(root)

## Wiki + tracker seeds for the social pages.
static func run_docs(t: Node) -> void:
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	for p in ["Social", "Community", "Tiers"]: t.check(wiki is Dictionary and wiki.has(p), "social docs: wiki seed has " + p)
	t.check(str(wiki.get("Social", {}).get("text", "")).contains("Clean-room"), "social docs: clean-room licence note")
	t.check(str(wiki.get("Community", {}).get("text", "")).contains("status: partial"), "social docs: community page honest status")
	var tk: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/tickets_seed.json"))
	var n := 0
	for x in tk:
		if str(x.get("milestone", "")).begins_with("SOCIAL-"): n += 1
	t.check(n == 8, "social docs: SOCIAL-1..8 tickets seeded")

## Admin Community screen loads and gates owner-only controls.
static func run_ui(t: Node) -> void:
	var root := "user://test_social_ui_%d" % Time.get_ticks_usec()
	Tiers.reset_for_tests(root); Social.reset_for_tests(root)
	Tiers.owner_override = false
	var s: CommunityScreen = load("res://scenes/admin/community_screen.tscn").instantiate()
	t.get_tree().root.add_child(s)
	await t.get_tree().process_frame
	t.check(s.pages.count() == 5, "community ui: 5 swipe tabs")
	t.check(s.save_roles_btn != null and s.save_roles_btn.disabled, "community ui: role editor save disabled while locked")
	t.check(s.min_font_ok(16), "community ui: labels >= 16 px")
	t.check(s.min_tap_ok(PhoenixTokens.tap()), "community ui: buttons >= token tap size (%d px)" % PhoenixTokens.tap())
	Tiers.owner_override = true
	s.refresh()
	t.check(not s.save_roles_btn.disabled, "community ui: save enabled for unlocked owner")
	s.pending_tiers["ex_ui"] = "staff"
	t.check(s.save_roles() == "" and Tiers.tier_of("ex_ui") == "staff", "community ui: owner saves a role")
	Tiers.owner_override = false
	s.pending_tiers["ex_ui"] = "creator"
	t.check(s.save_roles() != "" and Tiers.tier_of("ex_ui") == "staff", "community ui: locked save refused")
	s.queue_free()
	Tiers.owner_override = null
	Tiers.reset_for_tests("user://social"); Social.reset_for_tests("user://social")
	_rm_tree(root)
