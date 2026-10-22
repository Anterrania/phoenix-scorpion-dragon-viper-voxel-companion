extends RefCounted
## Social-media parity (SMP-*): post kinds, feeds (ranked + paged + data-mode hints), stories,
## clips/sounds/remix, threads, quotes, reposts, reactions, bookmarks, polls, scheduling, drafts,
## lists, pages, events, search/trending, privacy, age gating, context notes, analytics,
## notification batches, moderation queue, DMs (encrypted), MediaTools. Throwaway roots; restores statics.

const T0 := 1_800_000_000

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func _setup(root: String) -> void:
	BrainCore.adapter_root = root.path_join("brains")
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(root.path_join("security/estop.json"))
	EveCore.save_dir = root.path_join("eve"); EveCore.reset_cache()
	Tiers.reset_for_tests(root.path_join("social"))
	Social.reset_for_tests(root.path_join("social"))
	SocialDM.reset_for_tests(root.path_join("social"))
	MediaTools.root = root.path_join("social/media")
	Social.now_override = T0
	Social.data_mode_override = ""
	Tiers.owner_override = true
	for pair in [["sa", "resident"], ["sb", "resident"], ["sc", "resident"], ["sd", "creator"], ["se", "staff"], ["sf", "staff"], ["sg", "resident"]]:
		Tiers.set_tier(pair[0], pair[1])
		Social.set_profile(pair[0], pair[0], {"display_name": "Example " + pair[0].to_upper()})
	Social.set_profile(Tiers.OWNER_ID, "foxy_ani", {"display_name": "Foxy"})

static func _restore(root: String, saved: Dictionary) -> void:
	Social.now_override = -1; Social.data_mode_override = ""; Social.age_override = null
	Social.notify_listeners.clear(); Social.report_hooks.clear()
	Tiers.owner_override = null
	EveCore.owner_override = null
	EveCore.save_dir = saved["eve"]; EveCore.reset_cache()
	OwnerVault.reset_for_tests(saved["vault"], 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(saved["estop"])
	Tiers.reset_for_tests("user://social"); Social.reset_for_tests("user://social"); SocialDM.reset_for_tests("user://social")
	MediaTools.root = "user://social/media"
	BrainCore.adapter_root = BrainCore.DEFAULT_ROOT
	_rm_tree(root)

static func _approve_last(companion: String, yes := true) -> void:
	var props = EveCore.proposals(true).filter(func(x): return x["companion"] == companion)
	EveCore.owner_override = true
	EveCore.decide(props[-1]["id"], yes)
	EveCore.owner_override = null
	Social.sync_approvals()

static func _saved() -> Dictionary:
	return {"vault": OwnerVault.root, "estop": AutonomyGuard.path, "eve": EveCore.save_dir}

static func _ids(items: Array) -> Array: return items.map(func(x): return x["id"])

static func run(t: Node) -> void:
	var root = "user://test_smp_%d" % Time.get_ticks_usec()
	var saved = _saved()
	_setup(root)
	Social.friend_request("sa", "sb"); Social.friend_accept("sb", "sa")
	Social.follow("sc", "sa")

	# ---------- post kinds + media ----------
	t.check(not Social.post("sa", "x", {"kind": "hologram"})["ok"], "smp posts: unknown kind refused")
	t.check(not Social.post("sa", "pic", {"kind": "photo"})["ok"], "smp posts: photo needs media")
	var car = Social.post("sa", "carousel", {"kind": "photo", "media": [{"ref": "media:aaaa", "alt": "a voxel tower"}, {"ref": "media:bbbb", "alt": ""}]})
	t.check(car["ok"] and Social._find(car["id"])["media"].size() == 2 and Social._find(car["id"])["media"][0]["alt"] == "a voxel tower", "smp posts: carousel with alt text")
	var many: Array = []
	for i in 11: many.append({"ref": "media:%d" % i})
	t.check(not Social.post("sa", "x", {"kind": "photo", "media": many})["ok"], "smp posts: carousel capped at 10")
	t.check(not Social.post("sa", "x", {"kind": "clip", "media": [{"ref": "media:img", "type": "image"}]})["ok"], "smp clips: clip needs a video")
	var clip = Social.post("sa", "dance #VoxelDance", {"kind": "clip", "media": [{"ref": "clip:1", "type": "video", "duration_s": 30}], "sound": {"title": "Night drive"}})
	var cp = Social._find(clip["id"])
	t.check(clip["ok"] and cp.has("sound_id") and Social.sound(cp["sound_id"])["title"] == "Night drive", "smp clips: clip publishes + original sound created")
	t.check(not Social.post("sa", "x", {"kind": "clip", "media": [{"ref": "clip:x", "type": "video"}], "duration_s": 9999})["ok"], "smp clips: length capped")
	var duet = Social.post("sb", "duet!", {"kind": "clip", "media": [{"ref": "clip:2", "type": "video", "duration_s": 15}], "remix_of": {"pid": clip["id"], "mode": "duet"}})
	t.check(duet["ok"] and Social._find(duet["id"])["sound_id"] == cp["sound_id"] and Social.remixes_of("sc", clip["id"]).size() == 1, "smp clips: duet links to source + reuses its sound")
	t.check(not Social.post("sb", "s", {"kind": "clip", "media": [{"ref": "clip:3", "type": "video", "duration_s": 5}], "remix_of": {"pid": clip["id"], "mode": "stitch", "start_s": 0, "end_s": 9}})["ok"], "smp clips: stitch limited to 5 s")
	var noremix = Social.post("sa", "mine only", {"kind": "clip", "media": [{"ref": "clip:4", "type": "video", "duration_s": 5}], "allow_remix": false})
	t.check(not Social.post("sb", "r", {"kind": "clip", "media": [{"ref": "clip:5", "type": "video", "duration_s": 5}], "remix_of": {"pid": noremix["id"], "mode": "remix"}})["ok"], "smp clips: creator can turn remixes off")
	t.check(Social.sounds_top("sc")[0]["id"] == cp["sound_id"] and Social.sounds_top("sc")[0]["clips"] == 2, "smp clips: top sounds")
	t.check(Social.feed_page("sc", "sound:" + str(cp["sound_id"]))["items"].size() == 2, "smp clips: sound feed")
	t.check(not Social.post("sa", "x", {"sound": {"title": "s"}})["ok"], "smp clips: sounds only on clips")
	var layered = Social.post("sa", "layers", {"kind": "photo", "media_ref": "media:cccc", "layers": [{"type": "text", "x": 2.0, "text": "[b]hi"}, {"type": "bogus"}]})
	var ly: Array = Social._find(layered["id"])["layers"]
	t.check(ly.size() == 1 and ly[0]["x"] == 1.0 and ly[0]["text"] == "(b)hi", "smp posts: overlay layers cleaned + clamped")

	# ---------- hashtags + mentions ----------
	var hm = Social.post("sa", "Building #Voxels with @sb today #voxels", {})
	t.check(Social._find(hm["id"])["tags"] == ["voxels"] and Social._find(hm["id"])["mentions"] == ["sb"], "smp tags: hashtags lower-cased + deduped, mentions parsed")
	t.check(Social.notifications("sb").any(func(n): return n["kind"] == "mention"), "smp mentions: mentioned member notified")
	Social.set_privacy("sc", {"mentions": "nobody"})
	var before: int = Social.notifications("sc").size()
	Social.post("sb", "hey @sc", {})
	t.check(Social.notifications("sc").size() == before, "smp mentions: mentions=nobody -> no notification")

	# ---------- replies / threads / reply controls ----------
	var root_p = Social.post("sa", "Thread root", {})
	var r1 = Social.post("sb", "reply one", {"reply_to": root_p["id"]})
	var r2 = Social.post("sc", "reply two", {"reply_to": r1["id"]})
	var th = Social.thread("sg", root_p["id"])
	t.check(r1["ok"] and r2["ok"] and th["ok"] and th["replies"].size() == 2 and th["replies"][1]["depth"] == 2, "smp threads: nested replies with depth")
	t.check(not Social.feed("sg", 100).any(func(x): return x["id"] == r1["id"]), "smp threads: replies are not feed items")
	t.check(Social.feed("sg", 100).filter(func(x): return x["id"] == root_p["id"])[0]["replies"] == 1, "smp threads: reply count on the root")
	var closed = Social.post("sa", "No replies please", {"reply_policy": "nobody"})
	t.check(not Social.post("sb", "x", {"reply_to": closed["id"]})["ok"] and Social.post("sa", "self ok", {"reply_to": closed["id"]})["ok"], "smp threads: reply_policy nobody (author still can)")
	var men = Social.post("sa", "only @sg may reply", {"reply_policy": "mentioned"})
	t.check(Social.post("sg", "me", {"reply_to": men["id"]})["ok"] and not Social.post("sc", "me too", {"reply_to": men["id"]})["ok"], "smp threads: reply_policy mentioned")
	Social.restrict("sa", "sc")
	var rr = Social.post("sc", "restricted reply", {"reply_to": root_p["id"]})
	t.check(Social.can_see("sc", rr["id"]) and Social.can_see("sa", rr["id"]) and not Social.can_see("sb", rr["id"]), "smp restrict: reply visible only to them + you")
	Social.unrestrict("sa", "sc")
	Social.set_hidden_words("sa", ["Spoilerword"])
	var hw = Social.post("sb", "big SPOILERWORD here", {"reply_to": root_p["id"]})
	t.check(not Social.thread("sa", root_p["id"])["replies"].any(func(x): return x["id"] == hw["id"]) and Social.hidden_replies("sa", root_p["id"]).size() == 1, "smp hidden words: reply filtered into hidden replies")

	# ---------- quotes + reposts ----------
	var fr = Social.post("sa", "friends only", {"visibility": "friends"})
	t.check(not Social.post("sb", "q", {"quote_of": fr["id"]})["ok"], "smp quotes: only public posts can be quoted")
	var qt = Social.post("sb", "so true", {"quote_of": root_p["id"]})
	t.check(qt["ok"] and Social.decorate("sg", Social._find(qt["id"]))["original"]["id"] == root_p["id"], "smp quotes: quote carries the original")
	var rp = Social.repost("sb", hm["id"])
	t.check(rp["ok"] and not Social.repost("sb", hm["id"])["ok"], "smp reposts: once per member")
	t.check(Social.decorate("sg", Social._find(hm["id"]))["reposts"] == 1, "smp reposts: counted on the original")
	t.check(not Social.repost("sb", fr["id"])["ok"], "smp reposts: friends-only posts can't be reposted")
	t.check(Social.unrepost("sb", hm["id"])["ok"] and Social.decorate("sg", Social._find(hm["id"]))["reposts"] == 0, "smp reposts: undo")

	# ---------- reactions + bookmarks ----------
	t.check(Social.react("sb", root_p["id"], "like")["ok"] and Social.react("sb", root_p["id"], "love")["ok"], "smp reactions: react + switch")
	var dec = Social.decorate("sb", Social._find(root_p["id"]))
	t.check(dec["likes"] == 1 and dec["my_reaction"] == "love" and dec["reactions"].get("like", 0) == 0, "smp reactions: one reaction per member")
	t.check(not Social.react("sb", root_p["id"], "fire")["ok"] and not Social.react("stranger", root_p["id"])["ok"], "smp reactions: unknown kind / guests refused")
	t.check(Social.bookmark("sg", root_p["id"], "Ideas")["ok"] and Social.bookmark("sg", hm["id"])["ok"], "smp bookmarks: save (with folder)")
	t.check(Social.bookmarks("sg").size() == 2 and Social.bookmarks("sg", "Ideas").size() == 1 and Social.bookmark_folders("sg") == ["Ideas"], "smp bookmarks: folders")
	t.check(Social.unbookmark("sg", hm["id"])["ok"] and Social.bookmarks("sg").size() == 1, "smp bookmarks: remove")
	t.check(not Social.bookmark("sg", fr["id"])["ok"], "smp bookmarks: can't save what you can't see")

	# ---------- polls ----------
	t.check(not Social.poll_create("sa", "Which biome?", ["Tundra", "Fire"])["ok"], "smp polls: creator tier needed")
	t.check(not Social.poll_create("sd", "Q", ["one"])["ok"] and not Social.poll_create("sd", "Q", ["a", "b"], 500)["ok"], "smp polls: 2-4 options, <= 168 h")
	var pl = Social.poll_create("sd", "Which biome next?", ["Tundra", "Fire", "Glitter"], 24)
	t.check(pl["ok"] and Social.poll_vote("sa", pl["id"], 1)["ok"] and Social.poll_vote("sb", pl["id"], 1)["ok"], "smp polls: create + vote")
	t.check(not Social.poll_vote("sa", pl["id"], 0)["ok"] and not Social.poll_vote("sc", pl["id"], 9)["ok"], "smp polls: one vote, valid option")
	var res = Social.poll_results("sc", pl["id"])["poll"]
	t.check(res["counts"] == [0, 2, 0] and res["total"] == 2 and res["mine"] == -1 and not res.has("votes"), "smp polls: counts only, voters private")
	Social.now_override = T0 + 25 * 3600
	t.check(not Social.poll_vote("sc", pl["id"], 0)["ok"] and Social.poll_results("sc", pl["id"])["poll"]["closed"], "smp polls: closes on time")
	Social.now_override = T0

	# ---------- scheduling + drafts + edits + pins ----------
	var sch = Social.post("sa", "Later post", {"publish_at": T0 + 3600})
	t.check(sch["ok"] and sch["state"] == "scheduled" and not Social.feed("sb", 200).any(func(x): return x["id"] == sch["id"]) and Social.scheduled_posts("sa").size() == 1, "smp schedule: waits, hidden until due")
	t.check(not Social.post("sa", "too far", {"publish_at": T0 + 100 * 86400})["ok"], "smp schedule: <= 90 days ahead")
	Social.now_override = T0 + 3601
	Social.sync_approvals()
	t.check(Social._find(sch["id"])["state"] == "published" and Social.feed("sb", 200).any(func(x): return x["id"] == sch["id"]), "smp schedule: publishes when due")
	Social.now_override = T0
	var dr = Social.save_draft("sa", "draft one", {"visibility": "friends"})
	t.check(dr["ok"] and Social.save_draft("sa", "draft one, edited", {"visibility": "friends"}, dr["id"])["ok"] and Social.drafts("sa").size() == 1, "smp drafts: save + update")
	var pd = Social.publish_draft("sa", dr["id"])
	t.check(pd["ok"] and Social.drafts("sa").is_empty() and Social._find(pd["id"])["visibility"] == "friends" and Social._find(pd["id"])["text"] == "draft one, edited", "smp drafts: publish keeps options + removes draft")
	t.check(Social.edit_post("sa", root_p["id"], "Thread root (edited)")["ok"] and Social.edit_history("sb", root_p["id"]).size() == 1 and Social.decorate("sb", Social._find(root_p["id"]))["edited"], "smp edits: edit with visible history")
	Social.now_override = T0 + 7200
	t.check(not Social.edit_post("sa", root_p["id"], "late")["ok"], "smp edits: 1 hour window")
	Social.now_override = T0
	t.check(not Social.edit_post("sb", root_p["id"], "not mine")["ok"], "smp edits: only the author")
	t.check(Social.pin_post("sa", root_p["id"])["ok"] and Social.profile("sa")["pinned"] == root_p["id"] and not Social.pin_post("sa", r1["id"])["ok"], "smp pins: pin own post only")

	# ---------- companions: every kind waits for the owner ----------
	var cst = Social.post("foxy_ani", "Story from Foxy", {"kind": "story", "media_ref": "media:fox"})
	var ccl = Social.post("foxy_ani", "Foxy clip", {"kind": "clip", "media": [{"ref": "clip:fox", "type": "video", "duration_s": 10}]})
	var crp = Social.repost("foxy_ani", hm["id"])
	t.check(cst["state"] == "pending_approval" and ccl["state"] == "pending_approval" and crp["state"] == "pending_approval", "smp companions: stories, clips and reposts wait for owner approval")
	t.check(Social.stories_tray("sb").all(func(x): return x["author"] != "foxy_ani"), "smp companions: unapproved story not shown")
	_approve_last("foxy_ani")
	t.check(Social._find(crp["id"])["state"] == "published", "smp companions: approved repost published")
	t.check(not Social.edit_post("foxy_ani", crp["id"], "x")["ok"], "smp companions: can't edit an approved post")
	var csch = Social.post("foxy_ani", "Foxy later", {"publish_at": T0 + 600})
	_approve_last("foxy_ani")
	t.check(Social._find(csch["id"])["state"] == "scheduled", "smp companions: approved + scheduled waits for its time")

	# ---------- stories, close friends, highlights ----------
	var st = Social.post("sa", "my story", {"kind": "story", "media_ref": "media:st1", "visibility": "friends"})
	var cf = Social.post("sa", "close friends only", {"kind": "story", "media_ref": "media:st2", "visibility": "close_friends"})
	Social.close_friends_add("sa", "sb")
	t.check(not Social.feed("sb", 200).any(func(x): return x["id"] == st["id"]), "smp stories: never in feeds")
	var tray = Social.stories_tray("sb")
	t.check(tray.size() >= 1 and tray[0]["author"] == "sa" and tray[0]["items"].size() == 2 and tray[0]["unseen"], "smp stories: tray groups by author, unseen first")
	t.check(Social.stories_tray("sc").all(func(x): return x["author"] != "sa"), "smp stories: friends audience respected")
	t.check(Social.story_view("sb", st["id"])["ok"] and Social.story_viewers("sa", st["id"]) == ["sb"] and Social.story_viewers("sb", st["id"]).is_empty(), "smp stories: viewer list for the author only")
	t.check(not Social.stories_tray("sb")[0]["unseen"] or Social.stories_tray("sb")[0]["items"].size() == 2, "smp stories: seen state tracked")
	Social.now_override = T0 + 86401
	t.check(Social.stories_tray("sb").all(func(x): return x["author"] != "sa") and Social.story_archive("sa").size() == 2, "smp stories: expire after 24 h, stay in the author's archive")
	t.check(Social.highlight_add("sa", "Builds", st["id"])["ok"] and Social.highlights("sa", "sb").has("Builds") and not Social.highlights("sa", "sc").has("Builds"), "smp highlights: keep an expired story; audience still applies")
	Social.now_override = T0
	var dmr = SocialDM.post_reply_dm("sb", cf["id"], "love this")
	t.check(dmr["ok"] and SocialDM.conversations("sa").size() >= 1, "smp stories: story replies go to DMs")
	var ghost = Social.post("sa", "fleeting thought", {"ghost": true})
	t.check(not Social.post("sb", "r", {"reply_to": ghost["id"]})["ok"] and SocialDM.post_reply_dm("sb", ghost["id"], "psst")["ok"], "smp ghost: replies go to DMs, not the thread")
	Social.now_override = T0 + 86401
	t.check(not Social.can_see("sb", ghost["id"]) and Social.can_see("sa", ghost["id"]), "smp ghost: gone after 24 h (author keeps it)")
	Social.now_override = T0

	# ---------- privacy: private accounts, friends-only, mute ----------
	Social.set_privacy("sg", {"account": "private"})
	var gp = Social.post("sg", "private account post", {})
	var fo = Social.follow("sc", "sg")
	t.check(fo["ok"] and fo["state"] == "requested" and not Social.can_see("sc", gp["id"]), "smp privacy: private account -> follow request, posts hidden")
	t.check(Social.follow_requests("sg") == ["sc"] and Social.follow_approve("sg", "sc")["ok"] and Social.can_see("sc", gp["id"]), "smp privacy: approved follower sees posts")
	t.check(not Social.set_privacy("sg", {"account": "secret"})["ok"] and not Social.set_privacy("sg", {"bogus": 1})["ok"], "smp privacy: unknown values refused")
	Social.set_privacy("sg", {"account": "public"})
	Social.mute("sc", "sa")
	t.check(not Social.feed("sc", 200).any(func(x): return x["author"] == "sa") and Social.can_see("sc", root_p["id"]), "smp mute: muted author leaves feeds (still viewable directly)")
	Social.unmute("sc", "sa")

	# ---------- feeds: paging, snapshot, ranking, modes, data hints ----------
	for i in 25: Social.post("sf", "filler %d #filler" % i, {})
	var p1: Dictionary = Social.feed("sg", "latest")
	t.check(p1 is Dictionary and p1["ok"] and p1["items"].size() == 20 and p1["next_cursor"] != "", "smp feed: Social.feed(viewer, cursor) -> page + next_cursor")
	var late = Social.post("sf", "made after page one", {})
	Social.now_override = T0 + 5
	var seen = {}
	for x in p1["items"]: seen[x["id"]] = true
	var cur: String = p1["next_cursor"]
	var dup = false; var pages := 1; var got_late := false
	while cur != "" and pages < 20:
		var pg: Dictionary = Social.feed("sg", cur)
		for x in pg["items"]:
			if seen.has(x["id"]): dup = true
			if x["id"] == late["id"]: got_late = true
			seen[x["id"]] = true
		cur = pg["next_cursor"]; pages += 1
	t.check(not dup and not got_late and pages >= 2, "smp feed: pages don't repeat and are a snapshot")
	t.check(Social.feed("sg", "")["mode"] == "for_you" and Social.feed("sg", "bogus")["ok"] == false, "smp feed: default ranked mode; unknown mode refused")
	var fy: Array = Social.feed_page("sg", "for_you", 50)["items"]
	var three = false
	for i in range(2, fy.size()):
		if fy[i]["author"] == fy[i - 1]["author"] and fy[i]["author"] == fy[i - 2]["author"] and fy.slice(i).any(func(x): return x["author"] != fy[i]["author"]): three = true
	t.check(not three, "smp feed: ranked feed never shows 3 in a row from one author (when others exist)")
	Social.now_override = T0 + 3 * 3600
	var hot = Social.post("sc", "fresh and popular", {})
	for w in ["sa", "sb", "sd", "se"]: Social.react(w, hot["id"])
	var fy2: Array = Social.feed_page("sg", "for_you", 50)["items"]
	t.check(_ids(fy2).find(hot["id"]) < _ids(fy2).find(root_p["id"]), "smp feed: fresh + engaged post outranks an older quiet one")
	Social.follow("sg", "sd")
	t.check(Social.feed_page("sg", "following", 50)["items"].all(func(x): return x["author"] in ["sg", "sd"]), "smp feed: following = followed + friends + you")
	t.check(Social.feed_page("sg", "explore", 50)["items"].all(func(x): return x["author"] != "sd" and x["author"] != "sg"), "smp feed: explore = people you don't follow")
	t.check(Social.feed_page("sg", "clips", 50)["items"].all(func(x): return x["kind"] == "clip") and Social.feed_page("sg", "clips", 50)["items"].size() >= 2, "smp feed: clips feed is video only")
	t.check(Social.feed_page("sg", "tag:filler", 50)["items"].size() == 25, "smp feed: hashtag feed")
	t.check(Social.feed("sg", 20) is Array, "smp feed: legacy feed(viewer, limit) still returns an Array")
	t.check(Social.set_feed_pref("sg", "#filler", false, 3)["ok"] and not Social.set_feed_pref("sg", "x", true, 5)["ok"], "smp feed: topic controls (1/3/7 days)")
	var fy3: Array = Social.feed_page("sg", "for_you", 50)["items"]
	t.check(fy3.size() > 0 and fy3[0]["tags"].find("filler") == -1, "smp feed: 'less of' a topic ranks it down")
	var lst = Social.list_create("sg", "Builders")
	Social.list_add("sg", lst["id"], "sd")
	t.check(Social.feed_page("sg", "list:" + lst["id"], 50)["items"].all(func(x): return x["author"] == "sd") and Social.feed_page("sc", "list:" + lst["id"])["items"].is_empty(), "smp lists: list feed; private lists stay private")
	t.check(Social.lists_of("sc", "sg").is_empty() and Social.lists_of("sg").size() == 1, "smp lists: only you see your private lists")
	Social.now_override = T0
	# data-mode hints follow Net (PR #39)
	var net_prev := Net.mode
	Net.set_data_mode("full")
	t.check(Social.data_mode() == "full", "smp data: Social.data_mode() reads Net.mode")
	var ci: Dictionary = Social.feed_page("sc", "clips")["items"][0]
	t.check(ci["autoplay"] and ci["variant"] == "full" and ci["media"][0]["lazy"] and ci["media"][0]["hash"].length() == 16 and ci["prefetch"] and ci["media"][0]["kbps"] == Net.MEDIA_KBPS["full"]["video"], "smp data: full -> autoplay, prefetch, full variant, Net video budget")
	Net.set_data_mode("normal")
	ci = Social.feed_page("sc", "clips")["items"][0]
	t.check(ci["variant"] == "low" and ci["media"][0]["use_url"] == ci["media"][0]["low_url"], "smp data: normal -> low variant"); t.check(ci["autoplay"] and not ci["prefetch"] and ci["media"][0]["kbps"] == 1500 and ci["media"][0]["thumb_px"] == 320, "smp data: normal budgets from Net")
	var phi: Dictionary = Social.decorate("sb", Social._find(car["id"]))
	t.check(phi["thumb_url"] == "media:aaaa_t" and phi["media"][1]["thumb_url"] == "media:bbbb_t", "smp data: thumbnails first (thumb_url per item)")
	Net.set_data_mode("saver")
	ci = Social.feed_page("sc", "clips")["items"][0]
	t.check(not ci["autoplay"] and ci["variant"] == "thumb" and ci["media"][0]["kbps"] == 400 and ci["media"][0]["max_px"] == 640, "smp data: saver -> thumbnails only, no autoplay, saver budgets")
	t.check(Social.media_url("sb", car["id"], 0) == "media:aaaa_low" and Social.media_url("sb", car["id"], 0, "full") == "media:aaaa" and Social.media_url("sc", fr["id"], 0) == "", "smp data: lazy media_url (saver -> low; visibility checked)")
	Social.data_mode_override = "full"
	t.check(Social.data_mode() == "full" and Net.mode == "saver", "smp data: test override doesn't touch Net")
	Social.data_mode_override = ""; Net.set_data_mode(net_prev)

	# ---------- pages ----------
	t.check(not Social.page_create("sa", "Viper Builders")["ok"], "smp pages: creator tier needed")
	var pg1 = Social.page_create("sd", "Viper Builders", {"category": "Community"})
	t.check(pg1["ok"] and not Social.page_create("sd", "viper builders")["ok"], "smp pages: create, unique names")
	var pgp = Social.post("sd", "Page news #voxels", {"as_page": pg1["id"]})
	t.check(pgp["ok"] and Social._find(pgp["id"])["author"] == pg1["id"] and not Social.post("sa", "x", {"as_page": pg1["id"]})["ok"], "smp pages: admins post as the page")
	t.check(Social.follow("sb", pg1["id"])["ok"] and Social.feed_page("sb", "following", 50)["items"].any(func(x): return x["id"] == pgp["id"]), "smp pages: follow a page -> following feed")
	Tiers.owner_override = false
	t.check(not Social.set_badge("sd", pg1["id"], "verified")["ok"], "smp badges: locked owner / others can't grant")
	Tiers.owner_override = true
	t.check(Social.set_badge(Tiers.OWNER_ID, pg1["id"], "verified")["ok"] and "verified" in Social.badges_of(pg1["id"]) and not Social.set_badge(Tiers.OWNER_ID, "sa", "bluecheck")["ok"], "smp badges: owner grants internal badges")
	t.check("companion" in Social.badges_of("foxy_ani"), "smp badges: companions labelled")

	# ---------- events ----------
	t.check(not Social.event_create("sa", "Build night", T0 + 86400, "welcome/0_0")["ok"], "smp events: creator tier needed")
	var ev = Social.event_create("sd", "Build night #voxels", T0 + 86400, "welcome/0_0", {"capacity": 2})
	t.check(ev["ok"] and Social.event_rsvp("sa", ev["id"])["ok"] and Social.event_rsvp("sb", ev["id"])["ok"], "smp events: create + RSVP")
	t.check(not Social.event_rsvp("sc", ev["id"], "going")["ok"] and Social.event_rsvp("sc", ev["id"], "interested")["ok"], "smp events: capacity applies to going")
	var evv = Social.event("sc", ev["id"])
	t.check(evv["going"] == 2 and evv["interested"] == 1 and evv["my_rsvp"] == "interested" and not evv.has("rsvps"), "smp events: counts, my RSVP, guest list private")
	t.check(Social.events("sg").size() == 1, "smp events: upcoming list")
	t.check(Social.event_cancel("sd", ev["id"])["ok"] and Social.notifications("sa").any(func(n): return n["kind"] == "event" and str(n["text"]).contains("cancelled")), "smp events: cancel notifies attendees")
	Tiers.set_tier("foxy_ani", "creator")
	var fev = Social.event_create("foxy_ani", "Foxy's concert", T0 + 7200, "welcome/0_0")
	t.check(fev["state"] == "pending_approval" and Social.events("sg").is_empty(), "smp events: companion events wait for the owner")
	_approve_last("foxy_ani")
	t.check(Social.events("sg").size() == 1, "smp events: approved companion event listed")
	Tiers.clear_tier("foxy_ani")

	# ---------- age gating ----------
	t.check(not Social.post("sa", "adult", {"mature": true})["ok"], "smp age: unverified can't post mature")
	t.check(Social.set_age_verified(Tiers.OWNER_ID, "sa", true)["ok"] and Social.set_mature_opt_in("sa", true)["ok"] and Social.age_ok("sa"), "smp age: owner verifies + member opts in")
	Tiers.owner_override = false
	t.check(not Social.set_age_verified(Tiers.OWNER_ID, "sb", true)["ok"] and not Social.age_ok(Tiers.OWNER_ID), "smp age: locked owner can't verify and is gated")
	Tiers.owner_override = true
	var mat = Social.post("sa", "mature #nightlife", {"mature": true})
	t.check(mat["ok"] and not Social.can_see("sb", mat["id"]) and not Social.can_see("stranger", mat["id"]) and Social.can_see(Tiers.OWNER_ID, mat["id"]), "smp age: mature hidden from unverified + guests")
	t.check(not Social.search("sb", "#nightlife")["posts"].size() and not Social.trending("sb").any(func(x): return x["tag"] == "nightlife"), "smp age: mature kept out of search + trending")
	t.check(not Social.age_ok("foxy_ani") and not Social.age_ok("stranger"), "smp age: companions + guests never age_ok")
	var mg = Social.group_create("sd", "Late lounge", {"mature": true})
	t.check(not mg["ok"], "smp age: mature group needs a verified creator")

	# ---------- search + trending ----------
	var sr = Social.search("sg", "#voxels")
	t.check(sr["ok"] and sr["posts"].size() >= 2 and sr["posts"].all(func(x): return "voxels" in x["tags"]), "smp search: exact hashtag")
	t.check(Social.search("sg", "example sb", "people")["people"].size() == 1 and Social.search("sg", "viper", "pages")["pages"].size() == 1, "smp search: people + pages")
	t.check(not Social.search("sg", "  ")["ok"], "smp search: empty query refused")
	Social.now_override = T0 + 3 * 3600
	for w in ["sa", "sb", "sc"]: Social.post(w, "#rising thing", {})
	var tr = Social.trending("sg", 24)
	t.check(_ids_tag(tr).find("rising") < _ids_tag(tr).find("filler"), "smp trending: many authors beat one spamming account")
	Social.now_override = T0

	# ---------- context notes ----------
	var nt = Social.note_add("sb", hm["id"], "Context: this build is a remake.")
	t.check(nt["ok"] and not Social.note_add("sa", hm["id"], "mine")["ok"] and Social.context_notes("sg", hm["id"]).is_empty(), "smp notes: added, hidden until rated")
	for w in ["sc", "sd", "se"]: Social.note_rate(w, nt["id"], true)
	t.check(not Social.note_rate("sa", nt["id"], false)["ok"], "smp notes: post author can't rate")
	t.check(Social.context_notes("sg", hm["id"]).size() == 1 and Social.decorate("sg", Social._find(hm["id"]))["notes"].size() == 1, "smp notes: shown after helpful ratings from people who don't follow each other")

	# ---------- analytics ----------
	Social.record_view("sb", clip["id"], 15000); Social.record_view("sc", clip["id"], 30000); Social.record_view("sa", clip["id"], 30000)
	var pi = Social.post_insights("sa", clip["id"])
	t.check(pi["ok"] and pi["views"] == 2 and pi["reach"] == 2 and is_equal_approx(pi["avg_watch"], 0.75) and pi["remixes"] == 1, "smp analytics: views, reach, watch time, remixes (own views excluded)")
	var an = Social.analytics("sa")
	t.check(an["ok"] and an["followers"] >= 1 and an["posts"] > 5 and an["top"].size() > 0, "smp analytics: creator summary")
	t.check(not Social.analytics("sb", "sa")["ok"] and Social.analytics(Tiers.OWNER_ID, "sa")["ok"] and Social.analytics("sd", pg1["id"])["ok"], "smp analytics: own (owner + page admins) only")

	# ---------- notifications: batches + grouping + prefs ----------
	var batches: Array = []
	Social.notify_listeners.append(func(b): batches.append(b))
	var bp = Social.post("sg", "hi @sa and @sb", {})
	t.check(batches.size() == 1 and batches[0].has("sa") and batches[0].has("sb"), "smp notify: one batch per action (no polling)")
	Social.react("sc", bp["id"]); Social.react("sd", bp["id"])
	var grp = Social.notifications_grouped("sg")
	t.check(grp.any(func(g): return g["kind"] == "like" and g["count"] == 2 and g["from"].size() == 2), "smp notify: grouped by kind")
	Social.set_notify_prefs("sg", {"like": false})
	var nb: int = Social.notifications("sg").size()
	Social.react("se", bp["id"])
	t.check(Social.notifications("sg").size() == nb, "smp notify: per-kind off switch")
	Social.notify_listeners.clear()

	# ---------- moderation: auto-hold, queue, mature label ----------
	var hooked: Array = []
	Social.report_hooks.append(func(r): hooked.append(r["id"]))
	var bad = Social.post("sb", "questionable", {})
	Social.report("sc", "post", bad["id"], "spam")
	t.check(not Social.report("sc", "post", bad["id"], "again")["ok"], "smp moderation: one open report per person")
	Social.report("sd", "post", bad["id"], "spam"); var r3 := Social.report("stranger", "post", bad["id"], "nsfw")
	t.check(r3["held"] and not Social.can_see("sg", bad["id"]) and hooked.size() == 3, "smp moderation: 3 reports auto-hold the post; hooks fire")
	var q = Social.moderation_queue("se")
	t.check(q.size() >= 1 and q[0]["held"] and q[0]["count"] == 3 and q[0]["snippet"] == "questionable" and Social.moderation_queue("sa").is_empty(), "smp moderation: grouped queue, held first, staff only")
	t.check(Social.moderate("se", q[0]["report_id"], "mature")["ok"] and Social._find(bad["id"])["mature"] and Social._find(bad["id"])["state"] == "published", "smp moderation: mature label releases it age-gated")
	t.check(not Social.can_see("sg", bad["id"]) and Social.can_see("sa", bad["id"]) and Social.reports("se").filter(func(r): return r["target"] == bad["id"]).is_empty(), "smp moderation: all reports on the target closed")
	t.check(Social.modlog("se").any(func(l): return l["action"] == "moderate_mature") and Social.modlog("sa").is_empty(), "smp moderation: mod log (staff only)")
	Social.report_hooks.clear()

	# ---------- groups: rules, requests, removals ----------
	var gg = Social.group_create("sd", "Example Guild", {"open": false, "rules": ["Be kind", "[b]No spam"]})
	t.check(gg["ok"] and Social.group(gg["id"])["rules"] == ["Be kind", "(b)No spam"], "smp groups: rules")
	t.check(Social.group_request_join("sa", gg["id"])["ok"] and Social.group_approve("sd", gg["id"], "sa")["ok"] and Social.is_member(gg["id"], "sa"), "smp groups: request + approve")
	var gpst = Social.post("sa", "guild post", {"visibility": "group:" + gg["id"]})
	t.check(Social.group_remove_post("sd", gg["id"], gpst["id"])["ok"] and not Social.can_see("sd", gpst["id"]) and not Social.group_remove_post("sb", gg["id"], gpst["id"])["ok"], "smp groups: officers remove group posts")

	# ---------- e-stop ----------
	AutonomyGuard.engage("test")
	t.check(not Social.post("foxy_ani", "x", {"kind": "story", "media_ref": "m"})["ok"] and not Social.react("foxy_ani", root_p["id"])["ok"], "smp estop: companions can't post or react")
	AutonomyGuard.reset_for_tests(root.path_join("security/estop2.json"))

	# ---------- persistence ----------
	Social.reload_data()
	t.check(Social._find(clip["id"]).has("sound_id") and Social.drafts("sa").is_empty() and Social.bookmarks("sg").size() == 1, "smp persist: new data reloads")
	_restore(root, saved)

static func _ids_tag(a: Array) -> Array: return a.map(func(x): return x["tag"])

## DMs: requests, groups, reactions, receipts, disappearing, encryption at rest.
static func run_dm(t: Node) -> void:
	var root = "user://test_smp_dm_%d" % Time.get_ticks_usec()
	var saved = _saved()
	_setup(root)
	Social.friend_request("sa", "sb"); Social.friend_accept("sb", "sa")
	var dmp = root.path_join("social/dm.json")
	var c = SocialDM.open_direct("sa", "sb")
	t.check(c["ok"] and SocialDM.open_direct("sb", "sa")["id"] == c["id"], "dm: one chat per pair")
	t.check(SocialDM.send("sa", c["id"], "hello there")["ok"] and SocialDM.messages("sb", c["id"]).size() == 1, "dm: send + read")
	t.check(not FileAccess.file_exists(dmp) and not SocialDM.encrypted_at_rest(), "dm: no vault -> memory only, never plaintext on disk")
	t.check(Social.notifications("sb").any(func(n): return n["kind"] == "message" and not str(n["text"]).contains("hello")), "dm: notification never shows message text")
	t.check(not SocialDM.open_direct("stranger", "sa")["ok"] and not SocialDM.open_direct("sa", "sa")["ok"] and not SocialDM.messages("sc", c["id"]).size(), "dm: guests, self and non-members refused")
	# requests
	Social.set_privacy("sc", {"dm": "following"})
	var rq = SocialDM.open_direct("sd", "sc")
	t.check(rq["ok"] and SocialDM.conversations("sc", "requests").size() == 1 and SocialDM.conversations("sc").is_empty(), "dm: non-followers land in requests")
	for i in 3: SocialDM.send("sd", rq["id"], "msg %d" % i)
	t.check(not SocialDM.send("sd", rq["id"], "one more")["ok"], "dm: request message cap until accepted")
	t.check(SocialDM.accept_request("sc", rq["id"])["ok"] and SocialDM.conversations("sc").size() == 1 and SocialDM.send("sd", rq["id"], "thanks")["ok"], "dm: accept request")
	Social.set_privacy("se", {"dm": "nobody"})
	t.check(not SocialDM.open_direct("sa", "se")["ok"], "dm: dm=nobody refuses")
	Social.set_hidden_words("sg", ["buynow"])
	Social.set_privacy("sg", {"dm": "following"})
	var hr = SocialDM.open_direct("sd", "sg")
	SocialDM.send("sd", hr["id"], "BUYNOW cheap coins")
	t.check(SocialDM.conversations("sg", "hidden").size() == 1 and SocialDM.conversations("sg", "requests").is_empty(), "dm: hidden words send requests to hidden")
	Social.block("sb", "sd")
	t.check(not SocialDM.open_direct("sd", "sb")["ok"], "dm: blocks apply")
	# reactions, reply, edit, unsend, receipts
	var m1 = SocialDM.send("sb", c["id"], "reply to you", {"reply_to": SocialDM.messages("sb", c["id"])[0]["id"]})
	t.check(SocialDM.react("sa", c["id"], m1["id"], "❤")["ok"] and SocialDM.messages("sb", c["id"])[-1]["reactions"]["sa"] == "❤", "dm: reactions")
	t.check(SocialDM.edit("sb", c["id"], m1["id"], "reply (edited)")["ok"] and SocialDM.messages("sa", c["id"])[-1]["edited"], "dm: edit")
	Social.now_override = T0 + 1000
	t.check(not SocialDM.edit("sb", c["id"], m1["id"], "late")["ok"], "dm: edit window 15 min")
	t.check(not SocialDM.unsend("sa", c["id"], m1["id"])["ok"] and SocialDM.unsend("sb", c["id"], m1["id"])["ok"] and SocialDM.messages("sa", c["id"])[-1]["text"] == "", "dm: unsend own only")
	var m2 = SocialDM.send("sa", c["id"], "read me")
	t.check(SocialDM.receipts("sa", c["id"], m2["id"]).is_empty(), "dm: unread -> no receipt")
	SocialDM.mark_read("sb", c["id"])
	t.check(SocialDM.receipts("sa", c["id"], m2["id"]) == ["sb"] and SocialDM.conversations("sb")[0]["unread"] == 0, "dm: read receipts + unread count")
	Social.set_privacy("sb", {"read_receipts": false})
	t.check(SocialDM.receipts("sa", c["id"], m2["id"]).is_empty(), "dm: read receipts can be turned off")
	# disappearing
	t.check(not SocialDM.set_disappearing("sa", c["id"], 42)["ok"] and SocialDM.set_disappearing("sa", c["id"], 300)["ok"], "dm: disappearing choices")
	var dm3 = SocialDM.send("sa", c["id"], "vanishing")
	Social.now_override = T0 + 1000 + 301
	t.check(SocialDM.purge_expired() >= 1 and not SocialDM.messages("sb", c["id"]).any(func(x): return x["id"] == dm3["id"]), "dm: disappearing messages deleted after the timer")
	# groups
	var g = SocialDM.group_create("sa", "Build crew", ["sb", "sc", "nobody_here"])
	t.check(g["ok"] and SocialDM._convo(g["id"])["members"].size() == 3, "dm groups: create (unknown members skipped)")
	t.check(SocialDM.group_add("sa", g["id"], "sg")["ok"] and not SocialDM.group_add("sb", g["id"], "sd")["ok"], "dm groups: admins add")
	t.check(SocialDM.group_remove("sa", g["id"], "sg")["ok"] and SocialDM.messages("sg", g["id"]).is_empty(), "dm groups: remove")
	t.check(not SocialDM.set_disappearing("sb", g["id"], 3600)["ok"] and SocialDM.group_admin("sa", g["id"], "sb")["ok"] and SocialDM.set_disappearing("sb", g["id"], 3600)["ok"], "dm groups: admin-only settings")
	t.check(SocialDM.leave("sa", g["id"])["ok"] and not SocialDM.send("sa", g["id"], "x")["ok"] and SocialDM.send("sb", g["id"], "still here")["ok"], "dm groups: leave")
	var big: Array = []
	for i in 40: big.append("x%d" % i)
	t.check(not SocialDM.group_create("sa", "too big", ["sb"] + big)["ok"] or SocialDM.group_create("sa", "ok", ["sb"])["ok"], "dm groups: size cap")
	# share + report
	var pp = Social.post("sa", "share me", {})
	t.check(SocialDM.share_post("sa", c["id"], pp["id"])["ok"] and SocialDM.messages("sb", c["id"])[-1]["kind"] == "post_share", "dm: share a post")
	var rep = SocialDM.report_message("sb", c["id"], SocialDM.messages("sb", c["id"])[-1]["id"], "unwanted")
	var rr: Array = Social.reports("se").filter(func(r): return r["kind"] == "dm")
	t.check(rep["ok"] and rr.size() == 1 and rr[0]["evidence"]["from"] == "sa" and not rr[0].has("chat"), "dm: report one message with evidence only")
	# e-stop
	SocialDM.open_direct("foxy_ani", "sa")
	AutonomyGuard.engage("test")
	t.check(not SocialDM.open_direct("foxy_ani", "sb")["ok"], "dm: e-stop stops companions")
	AutonomyGuard.reset_for_tests(root.path_join("security/estop2.json"))
	# encryption at rest
	t.check(OwnerVault.setup_for_tests("864213") == "", "dm: vault set up")
	SocialDM.send("sa", c["id"], "secret plans")
	t.check(SocialDM.encrypted_at_rest() and SecureFile.is_sealed_file(dmp) and not FileAccess.get_file_as_string(dmp).contains("secret plans"), "dm: sealed on disk once a vault exists")
	OwnerVault.lock_all()
	SocialDM.reset_for_tests(root.path_join("social"))
	t.check(SocialDM.messages("sa", c["id"]).is_empty() and not SocialDM.send("sa", c["id"], "locked")["ok"], "dm: locked -> unreadable, writes refused")
	t.check(OwnerVault.unlock("864213") == "", "dm: unlock")
	SocialDM.reset_for_tests(root.path_join("social"))
	t.check(SocialDM.messages("sb", c["id"]).any(func(x): return x["text"] == "secret plans"), "dm: decrypts after unlock")
	_restore(root, saved)

# ---------- MediaTools ----------
static func _exif_app1(orientation: int) -> PackedByteArray:
	var tiff = PackedByteArray([0x49, 0x49, 0x2A, 0, 8, 0, 0, 0])
	tiff.append_array(PackedByteArray([2, 0]))
	tiff.append_array(PackedByteArray([0x12, 0x01, 3, 0, 1, 0, 0, 0, orientation, 0, 0, 0]))
	tiff.append_array(PackedByteArray([0x25, 0x88, 4, 0, 1, 0, 0, 0, 38, 0, 0, 0]))
	tiff.append_array(PackedByteArray([0, 0, 0, 0]))
	tiff.append_array(PackedByteArray([1, 0, 0x01, 0x00, 2, 0, 2, 0, 0, 0, 0x4E, 0, 0, 0, 0, 0, 0, 0]))
	var body = "Exif".to_ascii_buffer(); body.append_array(PackedByteArray([0, 0])); body.append_array(tiff)
	var n = body.size() + 2
	var seg = PackedByteArray([0xFF, 0xE1, (n >> 8) & 0xFF, n & 0xFF]); seg.append_array(body)
	return seg

static func _test_image(w: int, h: int) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in range(0, h, 8):
		for x in range(0, w, 8):
			img.fill_rect(Rect2i(x, y, 8, 8), Color((x % 256) / 255.0, (y % 256) / 255.0, float((x * y) % 97) / 97.0))
	return img

static func run_media(t: Node) -> void:
	var root = "user://test_smp_media_%d" % Time.get_ticks_usec()
	var saved = _saved()
	_setup(root)
	var jpg = _test_image(2000, 1000).save_jpg_to_buffer(0.95)
	var tagged = jpg.slice(0, 2); tagged.append_array(_exif_app1(6)); tagged.append_array(jpg.slice(2))
	var com = PackedByteArray([0xFF, 0xFE, 0, 9]); com.append_array("gps:1,2".to_ascii_buffer())
	tagged = tagged.slice(0, 2) + com + tagged.slice(2)
	t.check(MediaTools.sniff(tagged) == "jpg" and MediaTools.header_size(tagged) == Vector2i(2000, 1000), "media: sniff + header size before decode")
	t.check(MediaTools.has_metadata(tagged) and MediaTools.exif_orientation(tagged) == 6, "media: EXIF (GPS + orientation) detected")
	var clean = MediaTools.strip_metadata(tagged)
	var img = Image.new()
	t.check(not MediaTools.has_metadata(clean) and clean.size() < tagged.size() and img.load_jpg_from_buffer(clean) == OK and img.get_width() == 2000, "media: EXIF/GPS stripped losslessly, still decodes")
	t.check(not clean.hex_encode().contains("457869660000"), "media: no Exif marker left")
	var r = MediaTools.process_upload("sa", tagged, "A gradient")
	t.check(r["ok"] and MediaTools.sniff(r["full"]) == "webp" and not MediaTools.has_metadata(r["full"]), "media: upload re-encoded to WebP without metadata")
	t.check(r["w"] == 720 and r["h"] == 1440 and r["had_metadata"], "media: EXIF rotation applied, longest side 1440")
	var lo = Image.new(); lo.load_webp_from_buffer(r["low"])
	var th = Image.new(); th.load_webp_from_buffer(r["thumb"])
	t.check(maxi(lo.get_width(), lo.get_height()) == 640 and th.get_width() == 320 and th.get_height() == 320, "media: low (640) + square thumbnail (320)")
	t.check(MediaTools.LOW_SIDE == Net.IMAGE_PX["saver"]["image"] and MediaTools.THUMB_SIDE == Net.IMAGE_PX["normal"]["thumb"] and MediaTools.FULL_SIDE <= Net.IMAGE_PX["full"]["image"], "media: variants sized to Net budgets")
	t.check(r["bytes_out"] < r["bytes_in"] and r["thumb"].size() < r["low"].size() and r["low"].size() < r["full"].size(), "media: compression keeps it small")
	t.check(MediaTools.process_upload("sa", tagged)["missing_alt"], "media: missing alt text flagged")
	t.check(not MediaTools.process_upload("stranger", tagged)["ok"], "media: guests can't upload")
	var item = MediaTools.store_media(r)
	t.check(item["ref"].begins_with("media:") and MediaTools.path_of(item["ref"]) != "" and MediaTools.path_of(item["thumb_ref"]) != "" and MediaTools.path_of("media:../../x") == "", "media: stored as refs, path_of safe")
	var ph = Social.post("sa", "uploaded", {"kind": "photo", "media": [item]})
	t.check(ph["ok"] and Social.decorate("sb", Social._find(ph["id"]))["thumb_url"] == item["thumb_ref"], "media: stored item posts with its thumbnail")
	# PNG text chunk
	var png = _test_image(64, 48).save_png_to_buffer()
	var txt = "tEXtComment\u0000secret".to_utf8_buffer()
	var chunk = PackedByteArray([0, 0, 0, txt.size() - 4]); chunk.append_array(txt); chunk.append_array(PackedByteArray([0, 0, 0, 0]))
	var png2 = png.slice(0, 33) + chunk + png.slice(33)
	var pclean = MediaTools.strip_metadata(png2)
	var pi = Image.new()
	t.check(MediaTools.has_metadata(png2) and not MediaTools.has_metadata(pclean) and pi.load_png_from_buffer(pclean) == OK and pi.get_width() == 64, "media: PNG text chunks stripped")
	var wp = _test_image(40, 30).save_webp_to_buffer(true, 0.7)
	t.check(MediaTools.sniff(wp) == "webp" and MediaTools.header_size(wp) == Vector2i(40, 30) and MediaTools.validate(MediaTools.strip_metadata(wp))["ok"], "media: WebP header + strip round trip")
	# rejects
	t.check(not MediaTools.validate("hello world, not an image".to_utf8_buffer())["ok"], "media: non-images refused")
	var bomb = png.slice(0, 16); bomb.append_array(PackedByteArray([0, 0, 0x4E, 0x20, 0, 0, 0x4E, 0x20])); bomb.append_array(png.slice(24))
	t.check(not MediaTools.validate(bomb)["ok"], "media: oversized header refused before decoding")
	var trunc = jpg.slice(0, 200)
	t.check(not MediaTools.validate(trunc)["ok"], "media: damaged file refused")
	_restore(root, saved)

## Docs, tracker and wiki registration.
static func run_docs(t: Node) -> void:
	t.check(FileAccess.file_exists("res://docs/modules/SOCIAL_MEDIA_PARITY.md"), "smp docs: SOCIAL_MEDIA_PARITY.md exists")
	var par = FileAccess.get_file_as_string("res://docs/modules/SOCIAL_MEDIA_PARITY.md")
	for k in ["TikTok", "Instagram", "Facebook", "Threads", "cross-post", "owner approval", "Gemini Nightscythe"]: t.check(par.contains(k), "smp docs: parity doc covers " + k)
	var soc = FileAccess.get_file_as_string("res://docs/modules/SOCIAL.md")
	t.check(soc.contains("Social.feed(viewer, cursor)") and soc.contains("\"clip\"") and soc.contains("\"story\""), "smp docs: SOCIAL.md documents feed(viewer, cursor) + clip/story kinds")
	for f in ["FEED_SCREEN.md", "REELS_PLAYER.md", "STORY_VIEWER.md", "IMAGE_EDITOR.md", "COMPOSER.md", "DM_SCREEN.md"]:
		t.check(FileAccess.file_exists("res://docs/specs/foxy/" + f), "smp docs: Foxy spec " + f)
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	for p in ["SocialMediaParity", "SocialMedia", "Messages"]: t.check(wiki is Dictionary and wiki.has(p), "smp docs: wiki seed has " + p)
	var tk: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/tickets_seed.json"))
	var n = 0
	for x in tk:
		if str(x.get("milestone", "")).begins_with("SMP-"): n += 1
	t.check(n >= 15, "smp docs: SMP- tickets seeded (%d)" % n)
	t.check(not FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv").contains("\r"), "smp docs: tracker has LF line endings")

## Admin Community: Reports tab uses the grouped queue with a Mature decision.
static func run_ui(t: Node) -> void:
	var root = "user://test_smp_ui_%d" % Time.get_ticks_usec()
	var saved = _saved()
	_setup(root)
	var p = Social.post("sa", "reported thing", {})
	for w in ["sb", "sc", "sd"]: Social.report(w, "post", p["id"], "spam")
	var s: CommunityScreen = load("res://scenes/admin/community_screen.tscn").instantiate()
	t.get_tree().root.add_child(s)
	await t.get_tree().process_frame
	var labels: Array = []
	var all: Array = []; s._walk(s.boxes["Reports"], all)
	for n in all:
		if n is Button: labels.append(n.text)
	t.check("Mature" in labels and "Hide" in labels and "Keep" in labels, "community ui: Hide / Mature / Keep on held posts")
	t.check(s.min_tap_ok(PhoenixTokens.tap()), "community ui: new buttons >= token tap size")
	s.queue_free()
	_restore(root, saved)
