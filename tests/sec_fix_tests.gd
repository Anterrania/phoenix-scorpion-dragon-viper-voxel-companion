extends RefCounted
## SEC-FIX-1..4 (docs/SECURITY_DEVICE_TEST_PLAN.md F1-F5): legacy owner code retired, API key in an
## encrypted store, sealed fail-closed e-stop, arm64-only Android export + clean test user://.

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func _w(p: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(text); f.close()

static func run(t: Node) -> void:
	var saved_root := OwnerVault.root
	var saved_estop := AutonomyGuard.path
	var saved_boot: Dictionary = Profile.legacy_bootstrap
	var saved_data: Dictionary = Profile.data.duplicate(true)
	var root := "user://test_secfix_%d" % Time.get_ticks_usec()

	# ---------- SEC-FIX-1: legacy owner code ----------
	var src := FileAccess.get_file_as_string("res://scripts/autoload/profile.gd")
	t.check(not src.contains("\nconst OWNER_CODE_SHA256") and not src.contains("sha256_text"), "sec1: unsalted owner-code hash gone from the release path")
	t.check(not src.to_lower().contains("8ae5a77088495aa9"), "sec1: old hash value not kept in the repo")
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	Profile.legacy_bootstrap = {}
	t.check(not Profile.try_owner_unlock("phoenix-anything"), "sec1: no bootstrap record -> legacy code refused")
	var boot := Profile.make_bootstrap("phoenix-boot", 1000)
	t.check(str(boot["salt"]) != "" and str(boot["hash"]).length() == 64 and not JSON.stringify(boot).contains("phoenix-boot"), "sec1: bootstrap is salted PBKDF2, no code inside")
	t.check(Profile.make_bootstrap("phoenix-boot", 1000)["hash"] != boot["hash"], "sec1: random salt per record")
	Profile.legacy_bootstrap = boot
	Profile.data["role"] = "guest"
	t.check(not Profile.try_owner_unlock("phoenix-wrong"), "sec1: wrong legacy code refused")
	t.check(Profile.try_owner_unlock("PHOENIX-BOOT") and OwnerVault.needs_pin_setup(), "sec1: legacy code allowed to bootstrap a no-vault device")
	t.check(not OwnerVault.is_unlocked() and not Profile.is_owner() and not AutonomyGuard.release(), "sec1: bootstrap grants no owner powers")
	t.check(OwnerVault.setup("135790") == "" and OwnerVault.has_vault() and not OwnerVault.has_legacy_slot(), "sec1: first setup creates a PIN, no legacy slot")
	OwnerVault.lock_all()
	t.check(not Profile.try_owner_unlock("phoenix-boot") and not OwnerVault.storage_ready(), "sec1: legacy refused once vault has a pin slot")
	t.check(Profile.try_owner_unlock("135790") and Profile.is_owner(), "sec1: PIN allowed")
	# one-time migration of an older vault that still has a legacy slot
	var d := OwnerVault.dek()
	var dk: PackedByteArray = d["enc"] + d["mac"]
	var v := OwnerVault.vault()
	v["slots"].append(OwnerVault._make_slot("legacy", "phoenix-old", dk))
	OwnerVault._save_vault()
	t.check(FileAccess.get_file_as_string(OwnerVault.root.path_join("vault.json")).contains("\"legacy\""), "sec1: fixture vault with legacy slot")
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	t.check(not OwnerVault.has_legacy_slot() and str(OwnerVault.vault().get("legacy_retired", "")) != "", "sec1: migration strips the legacy slot on load")
	t.check(not FileAccess.get_file_as_string(OwnerVault.root.path_join("vault.json")).contains("\"legacy\""), "sec1: migration persisted to vault.json")
	t.check(OwnerVault.unlock("phoenix-old") != "" and OwnerVault.unlock("135790") == "", "sec1: migrated vault: old code refused, PIN works")

	# ---------- SEC-FIX-2: API key ----------
	var cfgp := "user://settings.cfg"
	var cfg_before := FileAccess.get_file_as_string(cfgp)
	Settings.reset_secrets_for_tests()
	Settings.cfg.set_value("llm", "api_key", "xk-test-PLAINTEXT-123"); Settings.cfg.save(cfgp)
	Settings.migrate_api_key()
	t.check(Settings.api_key() == "xk-test-PLAINTEXT-123", "sec2: migrated key still works")
	t.check(not Settings.cfg.has_section_key("llm", "api_key") and not FileAccess.get_file_as_string(cfgp).contains("PLAINTEXT"), "sec2: key blanked out of settings.cfg")
	var sb := FileAccess.get_file_as_bytes(Settings.secrets_path())
	t.check(CryptoBox.is_sealed(sb) and not sb.get_string_from_utf8().contains("PLAINTEXT"), "sec2: key sealed on disk")
	Settings.migrate_api_key()
	t.check(Settings.api_key() == "xk-test-PLAINTEXT-123", "sec2: migration is one-time / idempotent")
	Settings.set_value("llm", "api_key", "xk-new-456")
	t.check(Settings.get_value("llm", "api_key") == "xk-new-456" and not FileAccess.get_file_as_string(cfgp).contains("xk-new"), "sec2: UI writes go to the sealed store")
	Settings.reset_secrets_for_tests()
	t.check(Settings.api_key() == "xk-new-456", "sec2: sealed key reloads after restart")
	OwnerVault.lock_all(); Settings.reset_secrets_for_tests()
	t.check(Settings.user_api_key() == "", "sec2: key unreadable while the vault is sealed")
	OwnerVault.unlock("135790")
	t.check(Settings.user_api_key() == "xk-new-456", "sec2: key back after unlock")
	var bad := FileAccess.get_file_as_bytes(Settings.secrets_path()); bad[bad.size() - 40] ^= 1
	var bf := FileAccess.open(Settings.secrets_path(), FileAccess.WRITE); bf.store_buffer(bad); bf.close()
	Settings.reset_secrets_for_tests()
	t.check(Settings.user_api_key() == "", "sec2: tampered store yields no key")
	Settings.reset_secrets_for_tests()
	var f0 := FileAccess.open(cfgp, FileAccess.WRITE); f0.store_string(cfg_before); f0.close()
	Settings.cfg.load(cfgp)
	if Settings.cfg.has_section_key("llm", "api_key"): Settings.cfg.erase_section_key("llm", "api_key"); Settings.cfg.save(cfgp)

	# ---------- SEC-FIX-3: e-stop sealed, fail closed ----------
	var ep := root.path_join("security/estop.json")
	AutonomyGuard.reset_for_tests(ep)
	t.check(not AutonomyGuard.paused(), "sec3: no file -> released")
	AutonomyGuard.engage("t"); t.check(AutonomyGuard.release() and not AutonomyGuard.paused(), "sec3: owner release writes sealed state")
	var rec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ep))
	t.check(str(rec.get("mac", "")) != "", "sec3: estop.json carries a MAC")
	AutonomyGuard.reset_for_tests(ep)
	t.check(not AutonomyGuard.paused(), "sec3: valid MAC -> state honoured")
	AutonomyGuard.engage("t2")
	var rec2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ep))
	rec2["state"]["paused"] = false
	_w(ep, JSON.stringify(rec2))
	AutonomyGuard.reset_for_tests(ep)
	t.check(AutonomyGuard.paused() and AutonomyGuard.state().get("fail_closed", false), "sec3: tampered (paused->false) fails closed")
	_w(ep, JSON.stringify({"state": {"paused": false, "reason": "", "since": ""}}))
	AutonomyGuard.reset_for_tests(ep)
	t.check(AutonomyGuard.paused(), "sec3: MAC stripped fails closed")
	_w(ep, JSON.stringify({"paused": false}))
	AutonomyGuard.reset_for_tests(ep)
	t.check(AutonomyGuard.paused(), "sec3: old plain JSON under a vault fails closed")
	_w(ep, "{not json")
	AutonomyGuard.reset_for_tests(ep)
	t.check(AutonomyGuard.paused(), "sec3: unreadable file fails closed")
	t.check(AutonomyGuard.release() and not AutonomyGuard.paused(), "sec3: owner can release after fail-closed")
	OwnerVault.lock_all()
	AutonomyGuard.reset_for_tests(ep)
	t.check(AutonomyGuard.paused(), "sec3: unverifiable while sealed -> engaged")
	OwnerVault.unlock("135790")
	t.check(not AutonomyGuard.paused(), "sec3: re-verified on unlock -> released")

	# ---------- SEC-FIX-4: export + test hygiene ----------
	var ex := ConfigFile.new(); ex.load("res://export_presets.cfg")
	var ai := -1
	for i in 10:
		if ex.has_section("preset.%d" % i) and str(ex.get_value("preset.%d" % i, "platform", "")) == "Android": ai = i
	var o := "preset.%d.options" % ai
	t.check(ai >= 0 and bool(ex.get_value(o, "architectures/arm64-v8a", false)) and not bool(ex.get_value(o, "architectures/x86_64", true)) and not bool(ex.get_value(o, "architectures/x86", true)) and not bool(ex.get_value(o, "architectures/armeabi-v7a", true)), "sec4: Android export is arm64-only")

	# restore
	Profile.legacy_bootstrap = saved_boot
	Profile.data = saved_data
	_rm_tree(root)
	OwnerVault.reset_for_tests(saved_root, CryptoBox.DEFAULT_ITERATIONS)
	AutonomyGuard.reset_for_tests(saved_estop)

## Remove throwaway test roots from user:// (F5) and check none are left behind.
static func cleanup(t: Node) -> void:
	var pre := ["test_viper_", "brains_test_", "test_sec", "test_secfix_"]
	for d in DirAccess.get_directories_at("user://"):
		for p in pre:
			if d.begins_with(p): _rm_tree("user://".path_join(d)); break
	var left := []
	for d in DirAccess.get_directories_at("user://"):
		for p in pre:
			if d.begins_with(p): left.append(d)
	t.check(left.is_empty(), "sec4: tests leave no test_viper_*/brains_test_* folders (%s)" % str(left))
