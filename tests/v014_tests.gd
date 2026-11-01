extends RefCounted
## v0.14 tests: imported companion personas (job / abilities / tasks), companion home realms + Heaven court,
## Companions Live broadcast (members, opt-in viewers, never private chats), member-made companions,
## shared owner sign-in (SkorpionViper, social app record format), Scorpion Viper bridge. Restores statics.

const SMT := "res://tests/social_media_tests.gd"
const ROOT := "user://v014_test"
const COURT := ["foxy_ani", "aaliyah", "circuit_nova", "gemini_nightscythe", "seraphyx", "sonic_gage", "viper_gamer", "phoenix_dev_bot"]
## Cross-implementation vector: Python hashlib.pbkdf2_hmac("sha256", "Test-Passw0rd!", bytes(range(16)), 1000, 32)
const VECTOR := "pbkdf2-sha256$1000$AAECAwQFBgcICQoLDA0ODw==$731a710bbefbbd25d211392912eaad7728b5589230a84305574b662474448bbd"
const TEST_PW := "Test-Passw0rd!"

class FakeGen extends RefCounted:
	func biome_at(x: float, _z: float) -> int: return 1 if x > 1000.0 else (2 if x < -1000.0 else 0)

class FakeBridge extends Object:
	var version := 2
	var installed := true
	var opened: Array = []
	var uri := ""
	var consumed := false
	func get_plugin_version() -> int: return version
	func is_app_installed(pkg: String) -> bool: return installed and pkg == "os.viper.scorpion"
	func open_app(pkg: String, u: String) -> bool:
		opened.append([pkg, u]); return installed
	func get_launch_uri() -> String: return uri
	func consume_launch_uri() -> void: consumed = true; uri = ""

static func run(t: Node) -> void:
	_personas(t)
	_homes(t)
	var smt: GDScript = load(SMT)
	var saved: Dictionary = smt._saved()
	smt._setup(ROOT)
	CompanionBroadcast.reset_for_tests(ROOT.path_join("social"))
	CompanionCreator.reset_for_tests(ROOT.path_join("custom"))
	InteractionLedger.reset_for_tests(ROOT.path_join("ledger"))
	var bc_saved: Variant = Settings.get_value("companions", "broadcast", null)
	Settings.set_value("companions", "broadcast", true)
	_broadcast(t)
	_creator(t)
	Settings.set_value("companions", "broadcast", true if bc_saved == null else bc_saved)
	_login(t)
	_bridge(t)
	CompanionBroadcast.reset_for_tests("user://social")
	CompanionCreator.reset_for_tests(CompanionCreator.ROOT)
	OwnerLogin.reset_for_tests("user://security")
	InteractionLedger.reset_for_tests("user://brain_core")
	smt._restore(ROOT, saved)
	_sources(t)

static func _p(cid: String) -> Dictionary: return CompanionsScreen.persona_of(cid)

static func _personas(t: Node) -> void:
	var reg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companions/registry.json"))["companions"]
	var dirs := {}
	for k in reg: dirs[str(reg[k].get("dir", k))] = true
	for cid in COURT:
		var p := _p(cid)
		t.check(not p.is_empty() and p.get("id", "") == cid, "v014 persona %s exists" % cid)
		t.check(str(p.get("job", "")) != "" and p.get("tasks", []).size() >= 3 and p.get("abilities", []).size() >= 3, "v014 %s has job, task list and abilities" % cid)
		var bp: Dictionary = p.get("bot_profile", {})
		t.check(str(bp.get("source", "")).begins_with("Anterrania/grokbot-configs bots/") and bp.get("tasks", []) == p["tasks"], "v014 %s bot_profile records its source" % cid)
		var js := JSON.stringify(p)
		t.check(not js.contains("agent_id") and not js.contains("@gmail") and not js.contains("server_id"), "v014 %s carries no agent ids or contact info" % cid)
		t.check(str(p.get("home_realm", "")) != "", "v014 %s has a home realm" % cid)
		t.check(dirs.has(cid), "v014 %s is in companions/registry.json" % cid)
	t.check(_p("circuit_nova").get("name", "") == "Circuit Nova" and _p("circuit_nova").get("display_name", "") == "Aura Aurora", "v014 Circuit Nova keeps her name, shows as Aura Aurora")
	t.check(_p("viper_gamer").get("casino", "") == "free_play_only" and str(_p("viper_gamer")["system_prompt"]).contains("free-play only"), "v014 viper gamer: free-play casino only")
	t.check(str(_p("seraphyx")["system_prompt"]).contains("no access to real email"), "v014 seraphyx sees in-app activity only")
	t.check(AgentBrain._job_lines(_p("foxy_ani")).contains("Your tasks:"), "v014 brain adds job + tasks for personas that lacked them")
	t.check(AgentBrain._job_lines(_p("seraphyx")) == "", "v014 brain does not repeat the job when the prompt has it")
	t.check(_p("foxy_ani").get("starter_message", "") != "" and _p("foxy_ani").has("avatar_dna"), "v014 merge kept foxy's existing fields")

static func _homes(t: Node) -> void:
	WorldPicker.reset_for_tests()
	var ids: Array = WorldPicker.grids().map(func(g): return str(g["id"]))
	t.check(ids.has("heaven") and ids.has("alaska"), "v014 world picker keeps the base realms")
	t.check(COURT.all(func(c): return ids.has("home_" + c)), "v014 every court companion has a home realm in the picker")
	var g := WorldPicker.grid("home_seraphyx")
	t.check(g.get("kind", "") == "companion_home" and g.get("companion", "") == "seraphyx", "v014 home grid entry names its companion")
	var gen := FakeGen.new()
	var a := WorldPicker.target(WorldPicker.grid("home_foxy_ani"), gen)
	var b := WorldPicker.target(WorldPicker.grid("home_foxy_ani"), gen)
	t.check(a["kind"] == "companion_home" and a["pos"] == b["pos"] and a["companion"] == "foxy_ani", "v014 home position is deterministic")
	t.check(gen.biome_at(a["pos"].x, a["pos"].z) == 1, "v014 foxy's home lands in the Venus biome")
	var c := WorldPicker.target(WorldPicker.grid("home_gemini_nightscythe"), gen)
	t.check(gen.biome_at(c["pos"].x, c["pos"].z) == 2, "v014 nightscythe's home lands in the Cosmic biome")
	t.check(CompanionHomes.origin("aaliyah") != CompanionHomes.origin("seraphyx"), "v014 homes are separate plots")
	var m := CompanionHomes.marker("seraphyx", Vector3.ZERO)
	t.check((m.get_node("Sign") as Label3D).text.contains("Seraphyx") and m.has_meta(CompanionHomes.META), "v014 home marker sign")
	m.free()
	t.check(CompanionHomes.court_cap() >= 4 and CompanionHomes.court_cap() <= COURT.size(), "v014 Heaven court size is device-limited")
	t.check(CompanionHomes.clear_visitors(null) == 0, "v014 clear visitors without a world is a no-op")
	WorldPicker.reset_for_tests()

static func _broadcast(t: Node) -> void:
	var e := CompanionBroadcast.activity("foxy_ani", "built a fire altar")
	t.check(e.get("kind", "") == "building", "v014 broadcast: build action -> building")
	t.check(CompanionBroadcast.activity("aaliyah", "rested by the lake").get("kind", "") == "idle", "v014 broadcast: other action -> idle")
	var bt := CompanionBroadcast.banter("foxy_ani", "seraphyx", 0)
	t.check(bt.size() == 2 and bt[0]["to"] == "seraphyx" and bt[1]["to"] == "foxy_ani" and bt[0]["kind"] == "talking", "v014 companions talk to each other on the broadcast")
	t.check(str(bt[0]["text"]) in _p("foxy_ani")["game_lines"], "v014 banter uses the persona's own lines")
	AgentBrain.reply_ready.emit("foxy_ani", "PRIVATE-OWNER-REPLY-123")
	t.check(not JSON.stringify(CompanionBroadcast.db()).contains("PRIVATE-OWNER-REPLY-123"), "v014 owner chat replies never reach the broadcast")
	var r := CompanionBroadcast.viewer_say("sa", "foxy_ani", "Hello Foxy!")
	t.check(not r["ok"], "v014 viewer words stay off the broadcast without opt-in")
	CompanionBroadcast.set_opt_in("sa", true)
	Tiers.owner_override = true
	Tiers.set_tier("sa", "resident")
	r = CompanionBroadcast.viewer_say("sa", "foxy_ani", "Hello Foxy!")
	t.check(r["ok"] and r["entry"]["from"] == "sa" and not r["reply"].is_empty(), "v014 opted-in member talks with a companion on the broadcast")
	t.check(not CompanionBroadcast.viewer_say("sa", "foxy_ani", "show nude pics")["ok"], "v014 broadcast refuses sexual content")
	t.check(CompanionBroadcast.status("foxy_ani") == "talking", "v014 broadcast status per companion")
	var owner_pg := CompanionLive.page(Tiers.OWNER_ID)
	t.check(owner_pg["ok"] and owner_pg["items"].any(func(it): return it["author"] == "seraphyx" and it.has("broadcast")), "v014 live page lists broadcast companions")
	t.check(owner_pg["items"].all(func(it): return it.has("chats")), "v014 owner sees the chat count")
	var mem_pg := CompanionLive.page("sa")
	t.check(mem_pg["ok"] and mem_pg["items"].all(func(it): return not it.has("chats")), "v014 members watch the broadcast, without the chat count")
	t.check(not CompanionLive.page({"id": "g_guest", "tier": "guest"})["ok"], "v014 guests can't watch the broadcast")
	Settings.set_value("companions", "broadcast", false)
	t.check(CompanionBroadcast.activity("foxy_ani", "built a hut").is_empty(), "v014 broadcast off -> nothing logged")
	Settings.set_value("companions", "broadcast", true)
	var many := 0
	for i in CompanionBroadcast.MAX + 20: CompanionBroadcast.activity("sonic_gage", "placed block %d" % i); many += 1
	t.check(CompanionBroadcast.db()["log"].size() == CompanionBroadcast.MAX, "v014 broadcast log is capped")

static func _creator(t: Node) -> void:
	Tiers.owner_override = false
	var r := CompanionCreator.create("g_guest", {"name": "Nova Kid"})
	t.check(not r["ok"] and r["error"].contains("members"), "v014 non-members can't create companions")
	Tiers.owner_override = true
	Tiers.set_tier("cm", "creator")
	Tiers.owner_override = false
	r = CompanionCreator.create("cm", {"name": "Star Runner", "role": "explorer", "personality": "Bold and kind.", "home_realm": "venus_fire", "palette": "neon"})
	t.check(r["ok"] and str(r["id"]).begins_with("custom_star_runner_"), "v014 a creator-tier member makes a companion")
	var cid: String = r.get("id", "")
	var p := CompanionsScreen.persona_of(cid)
	t.check(p.get("name", "") == "Star Runner" and p.get("creator", "") == "cm" and str(p["system_prompt"]).contains("not a real person"), "v014 custom persona loads through the shared loader")
	t.check(not CompanionCreator.create("cm", {"name": "Bad", "personality": "explicit nsfw"})["ok"], "v014 custom companions refuse sexual content")
	t.check(not CompanionCreator.create("cm", {"name": "x"})["ok"], "v014 custom companion needs a real name")
	t.check(CompanionCreator.persona("custom_../../profile").is_empty(), "v014 custom ids can't escape their folder")
	t.check(not CompanionCreator.may_interact({"id": "g_guest", "tier": "guest"}, cid), "v014 non-members can't talk to member companions")
	t.check(CompanionCreator.may_interact({"id": "g_guest", "tier": "guest"}, "foxy_ani"), "v014 non-members talk with the owner's companions")
	t.check(CompanionCreator.may_interact("cm", cid), "v014 the creator talks with their companion")
	for i in 3: CompanionCreator.create("cm", {"name": "Extra %d" % i})
	t.check(CompanionCreator.list("cm").size() == CompanionCreator.MAX_PER_MEMBER, "v014 member companion limit")
	t.check(Tiers.can("cm", "companion_create") and not Tiers.can("sa", "companion_create"), "v014 companion_create is a creator-tier action")
	Tiers.owner_override = true

static func _login(t: Node) -> void:
	var prof: Node = t.get_node("/root/Profile")
	var saved_data: Dictionary = prof.data.duplicate(true)
	var saved_boot: Dictionary = prof.legacy_bootstrap
	prof.legacy_bootstrap = {}
	var sroot := ROOT.path_join("login")
	OwnerVault.reset_for_tests(sroot.path_join("security"), 1000)
	OwnerLogin.reset_for_tests(sroot.path_join("security"))
	t.check(not OwnerLogin.available(), "v014 no record in a test build -> sign-in off (fail closed)")
	t.check(OwnerLogin.sign_in("SkorpionViper", TEST_PW).contains("isn't set up"), "v014 sign-in off says use the PIN")
	t.check(OwnerLogin.parse(VECTOR).is_empty(), "v014 production minimum: 1000 iterations refused")
	OwnerLogin.min_iter = 1000
	var pr := OwnerLogin.parse(VECTOR)
	t.check(int(pr.get("iter", 0)) == 1000 and pr["salt"].size() == 16 and pr["key"].size() == 32, "v014 parses the social app's record format")
	for bad in ["", "pbkdf2-sha1$1000$AAECAwQFBgcICQoLDA0ODw==$" + "a".repeat(64), "pbkdf2-sha256$1000$AAEC$" + "a".repeat(64),
			"pbkdf2-sha256$x$AAECAwQFBgcICQoLDA0ODw==$" + "a".repeat(64), "pbkdf2-sha256$1000$AAECAwQFBgcICQoLDA0ODw==$" + "g".repeat(64),
			"pbkdf2-sha256$1000$AAECAwQFBgcICQoLDA0ODw==$abcd"]:
		t.check(OwnerLogin.parse(bad).is_empty(), "v014 malformed record refused: " + bad.left(24))
	OwnerLogin.record_override = VECTOR
	t.check(OwnerLogin.verify("SkorpionViper", TEST_PW), "v014 matches a Python-made PBKDF2 record (cross-implementation)")
	t.check(OwnerLogin.verify("  skorpionviper ", "  " + TEST_PW + " "), "v014 username case-insensitive, both trimmed")
	t.check(not OwnerLogin.verify("SkorpionViper", TEST_PW.to_lower()), "v014 password case is kept")
	t.check(not OwnerLogin.verify("Phoenix", TEST_PW), "v014 other usernames refused")
	t.check(not prof.first_run_allowed(), "v014 a build with the owner record has no open first-run claim")
	# backoff before any vault exists
	for i in OwnerLogin.FREE_TRIES: OwnerLogin.sign_in("SkorpionViper", "wrong-pass-%d" % i)
	t.check(OwnerLogin.retry_in_s() > 0 and OwnerLogin.sign_in("SkorpionViper", TEST_PW).begins_with("Too many"), "v014 sign-in backoff after 5 wrong tries")
	OwnerLogin._clear_fails()
	var e := OwnerLogin.sign_in("SkorpionViper", TEST_PW)
	t.check(e == "" and OwnerVault.is_unlocked() and OwnerVault.has_account_slot(), "v014 first sign-in creates the vault and opens the owner session (%s)" % e)
	t.check(prof.data.get("name", "") == "Phoenix Scorpion Dragon Viper" and prof.data.get("username", "") == "SkorpionViper" and prof.role() == "owner", "v014 owner display name + username set")
	t.check(not JSON.stringify(OwnerVault.vault()).contains(TEST_PW), "v014 the password is never stored")
	OwnerVault.lock_all()
	t.check(not OwnerVault.is_unlocked(), "v014 auto-lock still applies (owner gate)")
	t.check(OwnerLogin.sign_in("SkorpionViper", "nope-nope-nope") == OwnerLogin.ERR and not OwnerVault.is_unlocked(), "v014 wrong password refused")
	t.check(OwnerLogin.sign_in("someone", TEST_PW) == OwnerLogin.ERR and not OwnerVault.is_unlocked(), "v014 wrong username refused")
	t.check(OwnerLogin.sign_in("skorpionviper", TEST_PW) == "" and OwnerVault.is_unlocked() and OwnerVault.storage_ready(), "v014 sign-in unlocks the existing vault")
	# PIN device: link the shared password, then it survives Change PIN
	OwnerVault.lock_all()
	OwnerVault.reset_for_tests(sroot.path_join("security2"), 1000)
	t.check(OwnerLogin.link("SkorpionViper", TEST_PW) != "", "v014 linking needs the PIN unlock first")
	t.check(OwnerVault.setup_for_tests("246810") == "", "v014 PIN vault for link test")
	t.check(OwnerLogin.link("SkorpionViper", "not-the-password") == OwnerLogin.ERR, "v014 link checks the shared record")
	t.check(OwnerLogin.link("SkorpionViper", TEST_PW) == "" and OwnerVault.has_account_slot(), "v014 link adds the account slot")
	t.check(OwnerVault.change_secret("246810", "13579111") == "", "v014 change PIN")
	OwnerVault.lock_all()
	t.check(OwnerLogin.sign_in("SkorpionViper", TEST_PW) == "" and OwnerVault.is_unlocked(), "v014 shared password still opens after Change PIN")
	OwnerVault.lock_all()
	prof.data = saved_data
	prof.legacy_bootstrap = saved_boot
	prof.save()
	OwnerLogin.reset_for_tests("user://security")

static func _bridge(t: Node) -> void:
	var ok := SocialBridge.parse_enter("phoenixvoxel://enter?realm=venus")
	t.check(ok["ok"] and ok["realm"] == "venus", "v014 enter link -> realm")
	var hc := SocialBridge.parse_enter("phoenixvoxel://enter?companion=seraphyx")
	t.check(hc["ok"] and hc["realm"] == "home_seraphyx" and hc["companion"] == "seraphyx", "v014 enter link with a companion -> its home realm")
	t.check(SocialBridge.parse_enter("phoenixvoxel://enter")["realm"] == "heaven", "v014 bare enter link -> Heaven")
	for bad in ["phoenixvoxel://enter?realm=nowhere", "phoenixvoxel://enter?realm=../x", "https://evil.example/enter?realm=venus",
			"phoenixvoxel://enterx?realm=venus", "phoenixvoxel://enter?companion=custom_star", "phoenixvoxel://enter?companion=ghost",
			"phoenixvoxel://enter?realm=" + "a".repeat(220)]:
		t.check(not SocialBridge.parse_enter(bad)["ok"], "v014 bad enter link refused: " + bad.left(40))
	var link := SocialBridge.enter_link("home_foxy_ani", "foxy_ani")
	t.check(SocialBridge.parse_enter(link)["ok"] and SocialBridge.parse_enter(link)["realm"] == "home_foxy_ani", "v014 enter_link round trip")
	var fb := FakeBridge.new()
	var urls: Array = []
	SocialBridge.plugin_override = fb
	SocialBridge.open_url_override = func(u): urls.append(u)
	t.check(SocialBridge.open_social() == "app" and fb.opened[0] == ["os.viper.scorpion", SocialBridge.SOCIAL_URI], "v014 Open Social opens Scorpion Viper")
	fb.installed = false
	t.check(SocialBridge.open_social() == "web" and urls[-1] == SocialBridge.FALLBACK_URL, "v014 not installed -> release page")
	fb.installed = true; fb.version = 1
	t.check(SocialBridge.open_social() == "web", "v014 old plugin -> release page")
	fb.version = 2
	fb.uri = "phoenixvoxel://enter?realm=nowhere"
	t.check(SocialBridge.check_launch(null) == "Unknown world." and fb.consumed, "v014 launch link validated and consumed once")
	t.check(SocialBridge.check_launch(null) == "", "v014 no link -> nothing")
	SocialBridge.plugin_override = null
	SocialBridge.open_url_override = Callable()
	fb.free()

static func _sources(t: Node) -> void:
	var ci := FileAccess.get_file_as_string("res://.github/workflows/ci.yml")
	t.check(ci.contains("secrets.OWNER_PASS_HASH") and ci.contains("config/owner_login.local.cfg"), "v014 CI injects the owner record from a secret")
	t.check(ci.find("Owner sign-in record") > ci.find("Run tests"), "v014 owner record is written after the tests")
	t.check(ci.contains("grep -q 'phoenixvoxel'") and ci.contains("grep -q 'os.viper.scorpion'"), "v014 CI checks the bridge manifest entries")
	t.check(FileAccess.get_file_as_string("res://.gitignore").contains("config/*.local.cfg"), "v014 owner record path is gitignored")
	var leaked := false
	var re := RegEx.create_from_string("pbkdf2-sha256\\$[0-9]{6,7}\\$[A-Za-z0-9+/]{20,}")
	for d in ["res://scripts/security", "res://config", "res://data"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".local.cfg"): continue
			if re.search(FileAccess.get_file_as_string(d.path_join(f))) != null: leaked = true
	t.check(not leaked, "v014 no owner record committed")
	var man := FileAccess.get_file_as_string("res://android/plugins/viper_device/src/main/AndroidManifest.xml")
	t.check(man.contains("android:scheme=\"phoenixvoxel\"") and man.contains("<package android:name=\"os.viper.scorpion\" />"), "v014 plugin manifest: Enter World scheme + Scorpion Viper visibility")
	var kt := FileAccess.get_file_as_string("res://android/plugins/viper_device/src/main/java/com/anterrania/viperdevice/ViperDevicePlugin.kt")
	t.check(kt.contains("fun get_plugin_version(): Int = 2") and kt.contains("fun open_app(") and kt.contains("bridgeApps = setOf(\"os.viper.scorpion\")"), "v014 plugin v2 bridge with an app allow-list")
	t.check(FileAccess.file_exists("res://docs/modules/V014_COMPANIONS.md"), "v014 module doc")
	var tr := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	for row in ["PERSONA-IMPORT", "COMPANION-HOMES", "LIVE-BROADCAST", "CREATE-COMPANION", "OWNER-LOGIN", "SOCIAL-BRIDGE"]:
		t.check(tr.contains(row), "v014 tracker row " + row)
