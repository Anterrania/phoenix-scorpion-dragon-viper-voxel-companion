extends RefCounted
## v0.13.1 tests: TextAssist auto-correct + repair chips, Companions Live feed, group auto-approve on
## join, GlamFx (glitter / sparkle / shine / bloom / magic motes). Restores every static it touches.

const SMT := "res://tests/social_media_tests.gd"
const ROOT := "user://v0131_test"

static func run(t: Node) -> void:
	var saved_settings := {}
	for k in [["input", "autocorrect"], ["input", "capitalize"], ["input", "ai_suggest"], ["look", "glam"]]:
		saved_settings[k] = Settings.get_value(k[0], k[1], null)
	Settings.set_value("input", "autocorrect", true)
	Settings.set_value("input", "capitalize", true)
	_text(t)
	await _text_live(t)
	var smt: GDScript = load(SMT)
	var saved: Dictionary = smt._saved()
	smt._setup(ROOT)
	InteractionLedger.reset_for_tests(ROOT.path_join("ledger"))
	SceneSnapshots.reset_for_tests()
	_live(t)
	_groups(t)
	smt._restore(ROOT, saved)
	InteractionLedger.reset_for_tests("user://brain_core")
	SceneSnapshots.reset_for_tests()
	_glam(t)
	_docs(t)
	for k in saved_settings:
		var d: Variant = {"glam": "subtle"}.get(k[1], true)
		Settings.set_value(k[0], k[1], d if saved_settings[k] == null else saved_settings[k])

static func _text(t: Node) -> void:
	t.check(TextAssist.fix_word("teh") == "the" and TextAssist.fix_word("Teh") == "The", "v0131 typo fix keeps case")
	var r := TextAssist.autocorrect("i dont think teh  the build is ready")
	t.check(r["text"] == "I don't think the build is ready", "v0131 autocorrect: typos, doubled word, spaces, capital (%s)" % r["text"])
	t.check(r["fixes"].size() >= 3, "v0131 autocorrect counts fixes")
	var keep := TextAssist.autocorrect("see https://teh.example/recieve and teh@example.com @teh_bot v2 x_teh")
	t.check(keep["text"].contains("https://teh.example/recieve") and keep["text"].contains("teh@example.com") and keep["text"].contains("@teh_bot") and keep["text"].contains("x_teh"), "v0131 autocorrect leaves URLs, emails, handles, code alone")
	t.check(TextAssist.fix_word("id") == "", "v0131 ambiguous words never auto-fixed")
	var s := TextAssist.suggestions("ill go recieve it now")
	t.check(s.size() >= 2 and s.any(func(x): return str(x["text"]).contains("receive")) and s.any(func(x): return str(x["text"]).contains("I'll")), "v0131 repair chips: local fix + ambiguous offer")
	t.check(TextAssist.suggestions("  ").is_empty(), "v0131 no chips for empty input")
	var old_hook := TextAssist.ai_hook
	TextAssist.ai_hook = Callable()
	t.check(TextAssist.ai_suggest("helo") == "", "v0131 AI repair off without a model")
	TextAssist.ai_hook = func(x): return "Hello there."
	t.check(TextAssist.ai_suggest("helo ther") == "Hello there.", "v0131 AI repair offered as a suggestion")
	Settings.set_value("input", "ai_suggest", false)
	t.check(TextAssist.ai_suggest("helo ther") == "", "v0131 AI repair respects the setting")
	Settings.set_value("input", "ai_suggest", true)
	TextAssist.ai_hook = old_hook

static func _text_live(t: Node) -> void:
	var le := LineEdit.new()
	var pin := LineEdit.new(); pin.secret = true
	var raw := LineEdit.new(); raw.set_meta("no_autocorrect", true)
	t.add_child(le); t.add_child(pin); t.add_child(raw)
	TextAssist.watch(t.get_tree())
	var late := LineEdit.new(); t.add_child(late)
	t.check(le.has_meta("text_assist") and late.has_meta("text_assist"), "v0131 watch hooks existing and new text fields")
	t.check(not pin.has_meta("text_assist") and not TextAssist.eligible(pin), "v0131 secret / PIN fields never auto-corrected")
	t.check(not TextAssist.eligible(raw), "v0131 fields can opt out")
	le.text = "teh "; le.caret_column = 4
	TextAssist.on_changed(le, le.text)
	t.check(le.text == "the ", "v0131 live fix after a space")
	t.check(TextAssist.undo_last(le) and le.text == "teh ", "v0131 undo puts the word back")
	pin.text = "teh "; pin.caret_column = 4
	TextAssist.on_changed(pin, pin.text)
	t.check(pin.text == "teh ", "v0131 PIN text untouched")
	Settings.set_value("input", "autocorrect", false)
	le.text = "teh "; le.caret_column = 4
	TextAssist.on_changed(le, le.text)
	t.check(le.text == "teh ", "v0131 auto-correct can be turned off")
	Settings.set_value("input", "autocorrect", true)
	for n in [le, pin, raw, late]: n.queue_free()
	await t.get_tree().process_frame

static func _live(t: Node) -> void:
	InteractionLedger.record_interaction("foxy_ani", "secret plans for tonight", "sure")
	SceneSnapshots.capture("heaven_edit", {"cells": 3}, "foxy_ani")
	CompanionLive.now_override = int(Time.get_unix_time_from_system())
	var pg := CompanionLive.page("local")
	t.check(pg["ok"] and pg["items"].size() >= 1, "v0131 live page lists companions with activity")
	var c: Dictionary = pg["items"][0]
	t.check(c["kind"] == "live" and c["live"] and c["text"].contains("shaping Heaven"), "v0131 live card shows the creative space (%s)" % c["text"])
	t.check(not JSON.stringify(c).contains("secret plans") and int(c["chats"]) >= 1, "v0131 live card never shows chat text, only a count")
	# v0.14 LIVE-2 made Companions Live public to members, so this v0.13.1 rule no longer holds:
	# t.check(not CompanionLive.page("sa")["ok"], "v0131 other members can't open companion live feeds")
	var sa_pg := CompanionLive.page("sa")
	t.check(not sa_pg["ok"] or sa_pg["items"].all(func(it): return not it.has("chats")), "v0131 (v0.14 rule) other members never see the private chat count")
	var fp := Social.feed_page("local", "live")
	t.check(fp["ok"] and fp["mode"] == "live" and fp["items"].size() >= 1, "v0131 feed mode 'live' routes to CompanionLive")
	CompanionLive.now_override = int(Time.get_unix_time_from_system()) + 100000
	t.check(not CompanionLive.card("foxy_ani")["live"], "v0131 live badge drops after the window")
	CompanionLive.now_override = -1
	t.check(not CompanionLive.share("sa")["ok"], "v0131 only companions can share a live card")
	var sh := CompanionLive.share("foxy_ani")
	t.check(sh.get("state", "") == "pending_approval", "v0131 shared live card waits for owner approval (%s)" % str(sh))

static func _groups(t: Node) -> void:
	var g := Social.group_create("sd", "Glitter Guild", {"open": false, "auto_approve": true})
	t.check(g["ok"], "v0131 group created with auto-approve")
	var gid := str(g["id"])
	t.check(not Social.group_join("sa", gid)["ok"], "v0131 auto-approve group is still not open-join")
	var r := Social.group_request_join("sa", gid)
	t.check(r["ok"] and r["state"] == "joined" and Social.is_member(gid, "sa"), "v0131 join request auto-approved")
	var m := Social.group_create("sd", "Late Night", {"open": false, "auto_approve": true, "mature": true})
	if m["ok"]:
		t.check(not Social.group_request_join("sb", str(m["id"]))["ok"], "v0131 auto-approve keeps the age gate")
	var p := Social.group_create("sd", "Builders Only", {"open": false})
	var pid := str(p["id"])
	t.check(Social.group_request_join("sb", pid)["state"] == "requested", "v0131 default is officer approval")
	t.check(not Social.group_set_join_policy("sb", pid, true)["ok"], "v0131 only officers change the join policy")
	var sp := Social.group_set_join_policy("sd", pid, true, "staff")
	t.check(sp["ok"] and sp["min_tier"] == "staff" and not Social.is_member(pid, "sb"), "v0131 min tier keeps waiting residents out")
	t.check(not Social.group_request_join("sc", pid)["ok"], "v0131 min tier refuses lower tiers")
	t.check(Social.group_request_join("se", pid)["state"] == "joined", "v0131 qualifying tier auto-joins")
	var sp2 := Social.group_set_join_policy("sd", pid, true, "")
	t.check(sp2["ok"] and "sb" in sp2["admitted"] and Social.is_member(pid, "sb"), "v0131 turning on auto-approve admits waiting requests")
	t.check(Social.group_set_join_policy("sd", pid, true, "wizard")["min_tier"] == "", "v0131 unknown tiers ignored")

static func _glam(t: Node) -> void:
	t.check(GlamFx.set_level("full") and GlamFx.level() == "full", "v0131 glam level full")
	t.check(not GlamFx.set_level("max"), "v0131 unknown glam level refused")
	var env := Environment.new()
	env.glow_enabled = false
	t.check(GlamFx.bloom(env, "full") and env.glow_enabled, "v0131 bloom on")
	GlamFx.bloom(env, "off")
	t.check(not env.glow_enabled, "v0131 bloom off restores the world's own glow")
	var on := GlamFx.sparkle_layer("ui", "full")
	var sp: CPUParticles2D = on.get_node("Sparkles")
	t.check(sp.amount > 0 and sp.emitting and on.mouse_filter == Control.MOUSE_FILTER_IGNORE, "v0131 sparkle layer emits and ignores taps")
	t.check((sp.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "v0131 sparkles glow (additive)")
	var off := GlamFx.sparkle_layer("ui", "off")
	t.check(off.get_node_or_null("Sparkles") == null, "v0131 sparkles off when glam off")
	on.free(); off.free()
	t.check(GlamFx.magic_motes("off") == null, "v0131 no motes when off")
	var mo := GlamFx.magic_motes("subtle")
	t.check(mo != null and mo.amount > 0, "v0131 magic motes")
	mo.free()
	var b := Button.new()
	t.check(GlamFx.shine(b, "full") and b.material is ShaderMaterial, "v0131 shine sheen on buttons")
	t.check(not GlamFx.shine(b, "off") and b.material == null, "v0131 shine removed when off")
	b.free()
	var ps := t.get_tree().root.get_node_or_null("PowerSaver")
	if ps and "saver" in ps:
		var was: Variant = ps.get("saver")
		ps.set("saver", true)
		GlamFx.set_level("full")
		t.check(GlamFx.level() == "subtle", "v0131 power saver tones glam down")
		ps.set("saver", was)
	var ramp := GlamFx.palette_ramp()
	t.check(ramp.get_point_count() >= 3, "v0131 magenta / gold / platinum ramp")
	GlamFx.set_level("subtle")

static func _docs(t: Node) -> void:
	t.check(FileAccess.file_exists("res://docs/trac/20261031-dev-bot-v0131.md"), "v0131 trac log")
	t.check(FileAccess.file_exists("res://docs/modules/V0131_FOLLOWUPS.md"), "v0131 module doc")
