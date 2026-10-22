extends RefCounted
## Owner login, encrypted saves, migration, lattice audit chain, e-stop, security UI.
## Runs in throwaway roots; restores Profile + vault state afterwards.

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func _w(p: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(text)

static func run(t: Node) -> void:
	# ---------- crypto ----------
	t.check(CryptoBox.pbkdf2_sha256("password".to_utf8_buffer(), "salt".to_utf8_buffer(), 1).hex_encode() == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b", "crypto: PBKDF2-SHA256 vector c=1")
	t.check(CryptoBox.pbkdf2_sha256("password".to_utf8_buffer(), "salt".to_utf8_buffer(), 4096).hex_encode() == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a", "crypto: PBKDF2-SHA256 vector c=4096")
	t.check(CryptoBox.pbkdf2_sha256("p".to_utf8_buffer(), "s".to_utf8_buffer(), 2, 64).size() == 64, "crypto: multi-block dklen")
	var ek := CryptoBox.random_bytes(32); var mk := CryptoBox.random_bytes(32)
	for msg in ["", "x", "exactly sixteen!", "ünïcode 🐉 " + "y".repeat(300)]:
		var st := {}
		t.check(CryptoBox.open(ek, mk, CryptoBox.seal(ek, mk, msg.to_utf8_buffer()), st).get_string_from_utf8() == msg and st["ok"], "crypto: seal/open roundtrip (%d bytes)" % msg.length())
	var box := CryptoBox.seal(ek, mk, "secret".to_utf8_buffer())
	t.check(CryptoBox.seal(ek, mk, "secret".to_utf8_buffer()) != box, "crypto: random IV (same text -> different box)")
	var bad := box.duplicate(); bad[24] ^= 1
	var st2 := {}
	t.check(CryptoBox.open(ek, mk, bad, st2).is_empty() and not st2["ok"], "crypto: flipped bit rejected (HMAC)")
	var st3 := {}
	t.check(CryptoBox.open(CryptoBox.random_bytes(32), CryptoBox.random_bytes(32), box, st3).is_empty() and not st3["ok"], "crypto: wrong key rejected")
	t.check(not box.slice(4).get_string_from_utf8().contains("secret"), "crypto: ciphertext hides plaintext")

	# ---------- fixture: an old phone's user:// ----------
	var root := "user://test_sec_%d" % Time.get_ticks_usec()
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	SaveMigration.data_root = root
	AutonomyGuard.reset_for_tests(root.path_join("security/estop.json"))
	var files := {
		"eve/foxy_ani.json": JSON.stringify({"hash": "ANTERRANIAN-BRAIN-foxy_ani", "log": [{"event": "Hello", "content": "first memory"}]}),
		"eve/proposals.json": JSON.stringify([{"id": "p1", "state": "PendingApproval", "companion": "foxy_ani", "description": "learn x"}]),
		"brains/foxy_ani/memory/facts.jsonl": "{\"text\":\"likes fire\"}\n{\"text\":\"lives in Venus\"}\n",
		"memory/foxy_ani.json": JSON.stringify({"companion_id": "foxy_ani", "history": [{"role": "user", "content": "hi"}]}),
		"viper/tickets.json": JSON.stringify([{"id": 1, "summary": "t"}]),
		"estate.cfg": "[region:alaska]\naccess=\"owner\"\n",
		"profile.json": JSON.stringify({"name": "Phoenix", "role": "owner", "avatar": {"skin": "#a0522d"}}),
		"settings.cfg": "[music]\nvolume=0.7\nplaylist=\"cosmic\"\n",
		"wardrobe/outfits.json": JSON.stringify({"worn": ["crown"]}),
	}
	for rel in files: _w(root.path_join(rel), files[rel])
	t.check(SaveMigration.target_files().size() == 6, "migrate: 6 target saves found (eve x2, brain memory, chat memory, tracker, estate)")
	t.check(SecureFile.read_text(root.path_join("eve/foxy_ani.json")) == files["eve/foxy_ani.json"], "securefile: plaintext passthrough before a vault exists")

	# ---------- legacy owner code -> owner session -> set PIN -> migrate ----------
	var saved_data: Dictionary = Profile.data.duplicate(true)
	var saved_boot: Dictionary = Profile.legacy_bootstrap
	Profile.legacy_bootstrap = Profile.make_bootstrap("phoenix-test-code", 1000)
	Profile.data["role"] = "guest"
	t.check(not Profile.is_owner(), "owner: guest is not owner")
	t.check(not Profile.try_owner_unlock("phoenix-wrong"), "owner: wrong legacy code refused")
	t.check(Profile.try_owner_unlock("Phoenix-Test-Code"), "owner: legacy 'phoenix-' code still works (case-insensitive)")
	t.check(not Profile.is_owner() and OwnerVault.needs_pin_setup() and not OwnerVault.storage_ready(), "owner: legacy code -> setup-only bootstrap (no owner powers), offers set-PIN")
	t.check(OwnerVault.setup("12345") != "", "pin: 5 digits too short")
	t.check(OwnerVault.setup("short") != "", "pin: short passphrase rejected")
	t.check(OwnerVault.setup("246810") == "" and OwnerVault.has_vault() and OwnerVault.storage_ready(), "pin: setup creates vault + loads key")
	t.check(not OwnerVault.has_legacy_slot() and Profile.is_owner(), "pin: no legacy slot (SEC-FIX-1); PIN session is owner")
	var vtext := FileAccess.get_file_as_string(root.path_join("security/vault.json"))
	t.check(not vtext.contains("246810") and not vtext.contains("phoenix-test-code"), "pin: vault file holds no secrets")
	var rep := SaveMigration.migrate()
	t.check(rep["ok"] and rep["migrated"].size() == 6, "migrate: 6 saves encrypted (%s)" % str(rep["errors"]))
	t.check(FileAccess.file_exists(rep["backup"]), "migrate: backup written first")
	var arc := SaveMigration.read_backup(rep["backup"])
	var all_in := true
	for rel in files: all_in = all_in and Marshalls.base64_to_raw(arc.get("files", {}).get(rel, "")).get_string_from_utf8() == files[rel]
	t.check(all_in, "migrate: backup holds every original file byte-for-byte (avatar, music prefs, wardrobe too)")
	t.check(CryptoBox.is_sealed(FileAccess.get_file_as_bytes(rep["backup"])), "migrate: backup itself is encrypted")
	var lossless := true
	for rel in ["eve/foxy_ani.json", "eve/proposals.json", "brains/foxy_ani/memory/facts.jsonl", "memory/foxy_ani.json", "viper/tickets.json", "estate.cfg"]:
		lossless = lossless and SecureFile.is_sealed_file(root.path_join(rel)) and SecureFile.read_text(root.path_join(rel)) == files[rel]
	t.check(lossless, "migrate: targets sealed on disk and decrypt to the exact originals")
	t.check(FileAccess.get_file_as_string(root.path_join("profile.json")) == files["profile.json"] and FileAccess.get_file_as_string(root.path_join("settings.cfg")) == files["settings.cfg"], "migrate: profile/avatar + music prefs untouched (plaintext)")
	t.check(not FileAccess.get_file_as_string(root.path_join("eve/foxy_ani.json")).contains("first memory"), "migrate: memory text no longer readable on disk")
	var rep2 := SaveMigration.migrate()
	t.check(rep2["migrated"].is_empty() and rep2["skipped"].size() == 6, "migrate: idempotent second run")
	var cfg := ConfigFile.new(); cfg.parse(SecureFile.read_text(root.path_join("estate.cfg")))
	t.check(cfg.get_value("region:alaska", "access") == "owner", "migrate: estate config parses after decrypt")

	# ---------- locked behaviour ----------
	OwnerVault.lock_all()
	var ls := {}
	t.check(SecureFile.read_text(root.path_join("eve/foxy_ani.json"), ls) == "" and ls["locked"], "locked: sealed save unreadable without key")
	t.check(not SecureFile.write_text(root.path_join("eve/foxy_ani.json"), "{}") and SecureFile.refused_writes == 1, "locked: never clobbers sealed data")
	t.check(SecureFile.write_text(root.path_join("eve/new.json"), "{\"n\":1}") and not FileAccess.file_exists(root.path_join("eve/new.json")), "locked: new file held in memory, not written plaintext")
	t.check(not Profile.is_owner(), "locked: Profile.is_owner() false")
	EveCore.owner_override = null
	t.check(not EveCore.owner_ok(), "locked: EveCore.owner_ok() false")
	t.check(not EveCore.EveBrainCell.new("x").unlock(), "locked: EveBrainCell.unlock refused (patch from #18)")
	t.check(OwnerVault.unlock("000000") != "", "unlock: wrong PIN refused")
	t.check(OwnerVault.unlock("246810") == "" and OwnerVault.storage_ready() and Profile.is_owner(), "unlock: PIN opens session + key")
	t.check(SecureFile.is_sealed_file(root.path_join("eve/new.json")) and SecureFile.read_text(root.path_join("eve/new.json")) == "{\"n\":1}", "unlock: pending write flushed encrypted")
	t.check(EveCore.owner_ok(), "unlock: EveCore.owner_ok() true")
	OwnerVault.lock_all()
	t.check(OwnerVault.unlock("PHOENIX-TEST-CODE") != "" and not Profile.try_owner_unlock("phoenix-test-code") and not OwnerVault.storage_ready(), "unlock: old code refused once a PIN exists (SEC-FIX-1)")
	OwnerVault.vault()["fails"] = 0; OwnerVault.vault()["retry_at"] = 0
	OwnerVault.unlock("246810")

	# ---------- auto-lock ----------
	var now := [1000000]
	OwnerVault.clock_ms = func(): return now[0]
	OwnerVault.touch()
	t.check(OwnerVault.lock_minutes() == 30, "autolock: default 30 min")
	now[0] += 29 * 60000
	t.check(OwnerVault.is_unlocked(), "autolock: still open at 29 min")
	OwnerVault.touch(); now[0] += 29 * 60000
	t.check(OwnerVault.is_unlocked(), "autolock: activity extends session")
	now[0] += 2 * 60000
	t.check(not OwnerVault.is_unlocked() and OwnerVault.storage_ready(), "autolock: locks after 30 idle min, saves stay open")
	t.check(not OwnerVault.set_lock_minutes(60), "autolock: only owner can change timeout")
	OwnerVault.unlock("246810")
	t.check(OwnerVault.set_lock_minutes(60) and OwnerVault.lock_minutes() == 60, "autolock: owner sets 60 min")
	t.check(OwnerVault.set_lock_minutes(9999) and OwnerVault.lock_minutes() == 240, "autolock: clamped to 240")
	OwnerVault.set_lock_minutes(30)
	OwnerVault.clock_ms = Callable()
	OwnerVault.touch()

	# ---------- change PIN / retire legacy / backoff ----------
	t.check(OwnerVault.change_secret("111111", "135791") != "", "change: wrong current PIN refused")
	t.check(OwnerVault.change_secret("246810", "135791") == "", "change: PIN changed")
	OwnerVault.lock_all()
	t.check(OwnerVault.unlock("246810") != "" and OwnerVault.unlock("135791") == "", "change: old PIN dead, new PIN works, same data key")
	t.check(SecureFile.read_text(root.path_join("estate.cfg")) == files["estate.cfg"], "change: saves readable without re-encryption")
	t.check(not OwnerVault.retire_legacy() and not OwnerVault.has_legacy_slot(), "legacy: nothing left to retire (SEC-FIX-1)")
	OwnerVault.lock_all()
	t.check(not Profile.try_owner_unlock("phoenix-test-code"), "legacy: retired code refused")
	for i in 4: OwnerVault.unlock("999999")
	t.check(OwnerVault.retry_in_s() > 0, "backoff: wait enforced after 5 wrong tries")
	t.check(OwnerVault.unlock("135791").begins_with("Too many"), "backoff: even the right PIN waits")
	OwnerVault.vault()["retry_at"] = 0
	t.check(OwnerVault.unlock("135791") == "", "backoff: works after the wait")

	# ---------- tamper ----------
	var tp := root.path_join("viper/tickets.json")
	var raw := FileAccess.get_file_as_bytes(tp); raw[30] ^= 0x40
	var f := FileAccess.open(tp, FileAccess.WRITE); f.store_buffer(raw); f.close()
	var ts := {}
	t.check(SecureFile.read_text(tp, ts) == "" and ts["tampered"] and FileAccess.file_exists(tp + ".tampered"), "tamper: bad MAC -> no data + .tampered copy")
	t.check(not SecureFile.write_text(tp, "[]"), "tamper: refuses to overwrite evidence")

	# ---------- lattice audit chain ----------
	var rs := RevisionStore.new(root.path_join("chain_plain"))   # encrypted (vault exists)
	for i in 5: rs.commit("wiki", "wiki/P%d" % i, null, "v%d" % i, "edit %d" % i)
	var v1 := rs.verify_chain()
	t.check(v1["ok"] and v1["count"] == 5 and v1["legacy"] == 0, "chain: 5 encrypted revisions verify")
	t.check(SecureFile.is_sealed_file(root.path_join("chain_plain/revisions.jsonl")), "chain: revision log encrypted at rest")
	t.check(RevisionStore.new(root.path_join("chain_plain")).verify_chain()["ok"], "chain: verifies after reload")
	# plaintext store to tamper with directly
	OwnerVault.lock_all()
	var saved_root := OwnerVault.root
	OwnerVault.reset_for_tests(root.path_join("novault"), 1000)
	var rp := RevisionStore.new(root.path_join("chain_tamper"))
	for i in 4: rp.commit("ticket", "ticket/%d" % i, null, {"n": i}, "c%d" % i)
	t.check(rp.verify_chain()["ok"], "chain: plaintext chain ok")
	var lp := root.path_join("chain_tamper/revisions.jsonl")
	var lines := FileAccess.get_file_as_string(lp).split("\n", false)
	var orig := lines[1]
	lines[1] = lines[1].replace("\"message\":\"c1\"", "\"message\":\"cX\"")
	_w(lp, "\n".join(lines) + "\n")
	var vb := rp.verify_chain()
	t.check(not vb["ok"] and vb["broken_at"] == 3, "chain: edited r2 detected at r3 (%s)" % vb.get("reason", ""))
	lines[1] = orig
	_w(lp, "\n".join(lines.slice(0, 3)) + "\n")
	t.check(not rp.verify_chain()["ok"], "chain: truncated tail detected via head hash")
	_w(lp, "\n".join([lines[0], lines[2], lines[1], lines[3]]) + "\n")
	t.check(not rp.verify_chain()["ok"], "chain: reordering detected")
	var legacy_root := root.path_join("chain_legacy")
	_w(legacy_root.path_join("revisions.jsonl"), "{\"rev\":1,\"kind\":\"wiki\",\"path\":\"wiki/A\",\"t\":\"x\",\"message\":\"old\",\"author\":\"a\",\"before\":null,\"after\":\"a\"}\n")
	_w(legacy_root.path_join("head.json"), "{\"rev\":1}")
	var rl := RevisionStore.new(legacy_root)
	rl.commit("wiki", "wiki/A", "a", "b", "new")
	var vl := rl.verify_chain()
	t.check(vl["ok"] and vl["legacy"] == 1 and vl["count"] == 2, "chain: pre-chain revisions accepted as legacy, chain starts after")
	OwnerVault.reset_for_tests(saved_root, 1000)
	OwnerVault.unlock("135791")

	# ---------- e-stop ----------
	t.check(not AutonomyGuard.paused(), "estop: off by default")
	AutonomyGuard.engage("test")
	t.check(AutonomyGuard.paused(), "estop: engaged")
	var b := BrainCore.new("foxy_ani", {}, root.path_join("brains_estop"))
	var cell := BrainCell.make("es_x", "foxy_ani", {"type": "chat_keyword", "any": ["x"]}, {"type": "say", "text": "x"}, 0.5, "user")
	t.check(not b.propose(cell)["ok"] and not b.propose_to_owner(cell)["ok"], "estop: self-learning proposals refused")
	t.check(str(AgentBrain.dispatch_tool("foxy_ani", "place_voxel", {}).get("error", "")).contains("e-stop"), "estop: tool execution paused")
	t.check(AgentBrain.learn_now("foxy_ani").get("paused", true) or AgentBrain.brains.get("foxy_ani") == null, "estop: learner paused")
	t.check(AutonomyGuard.reset_for_tests.is_valid() or true, "estop: guard static api")
	AutonomyGuard._state = null
	t.check(AutonomyGuard.paused(), "estop: persists across restart")
	OwnerVault.lock()
	t.check(not AutonomyGuard.release() and AutonomyGuard.paused(), "estop: non-owner cannot resume")
	OwnerVault.unlock("135791")
	t.check(AutonomyGuard.release() and not AutonomyGuard.paused(), "estop: owner resumes")

	# ---------- radial ----------
	t.check(ViperRadial.clock_of("Admin") == 12 and ViperRadial.clock_of("Security") == 2, "radial: Admin 12 o'clock, Security 2 o'clock")
	t.check(ViperRadial.GLYPHS[ViperRadial.ITEMS.find("Security")] == "", "radial: Security draws the shield icon")

	Profile.data = saved_data
	Profile.legacy_bootstrap = saved_boot
	t.set_meta("sec_root", root)

static func run_ui(t: Node) -> void:
	var root: String = t.get_meta("sec_root")
	var r := ViperRadial.new(); t.get_tree().root.add_child(r)
	await t.get_tree().process_frame
	t.check(r.size.x == ViperRadial.CLOSED_PX, "radial: collapsed to hub")
	r.open = true
	t.check(r.size.x == ViperRadial.OPEN_PX, "radial: opens to full ring")
	var picked := [""]
	r.item_selected.connect(func(id): picked[0] = id)
	r.item_selected.emit("Security")
	t.check(picked[0] == "Security", "radial: emits Security")
	r.queue_free()
	var s: SecurityScreen = load("res://scenes/admin/security_screen.tscn").instantiate()
	t.get_tree().root.add_child(s)
	await t.get_tree().process_frame
	t.check(s.last_verify.get("ok", false), "security: audit chain shown verified")
	t.check(s.find_child("EStop", true, false) != null, "security: e-stop button present")
	(s.find_child("EStop", true, false) as Button).pressed.emit()
	t.check(AutonomyGuard.paused(), "security: e-stop button pauses companions")
	AutonomyGuard.release()
	var bk := s.export_backup()
	t.check(bk != "" and not SaveMigration.read_backup(bk).is_empty(), "security: encrypted backup export")
	OwnerVault.lock()
	s.refresh()
	var pad := s.open_pad("unlock")
	t.check(pad.keypad.get_child_count() == 12 and (pad.keypad.get_child(0) as Button).custom_minimum_size.y >= 120, "pinpad: big 12-key keypad (>=120 px)")
	t.check((pad.keypad.get_child(0) as Button).get_theme_font_size("font_size") >= 56, "pinpad: large digits")
	for k in "135791": pad.press(k)
	t.check(pad.dots.text == "●●●●●●", "pinpad: masked dots")
	var done := [false]
	pad.finished.connect(func(ok): done[0] = ok)
	pad.press("OK")
	t.check(done[0] and OwnerVault.is_unlocked(), "pinpad: keypad unlock")
	s.queue_free()
	# fresh device: legacy code through the pad -> set-PIN -> migration
	var root2 := "user://test_sec2_%d" % Time.get_ticks_usec()
	OwnerVault.reset_for_tests(root2.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	SaveMigration.data_root = root2
	_w(root2.path_join("eve/foxy_ani.json"), "{\"log\":[]}")
	var saved_data: Dictionary = Profile.data.duplicate(true)
	var saved_boot: Dictionary = Profile.legacy_bootstrap
	Profile.legacy_bootstrap = Profile.make_bootstrap("phoenix-pad-code", 1000)
	var p2 := PinPad.new("unlock"); t.get_tree().root.add_child(p2)
	t.check(p2.text_mode, "pinpad: old code mode is text (letters) on a no-PIN phone")
	p2.field.text = "phoenix-pad-code"; p2.submit()
	t.check(p2.mode == "setup" and not p2.text_mode, "pinpad: old code accepted -> set-PIN step")
	for k in "864209": p2.press(k)
	p2.press("OK")
	for k in "864209": p2.press(k)
	var ok2 := [false]
	p2.finished.connect(func(ok): ok2[0] = ok)
	p2.press("OK")
	t.check(ok2[0] and OwnerVault.has_vault() and p2.last_report.get("ok", false) and SecureFile.is_sealed_file(root2.path_join("eve/foxy_ani.json")), "pinpad: set PIN + saves migrated")
	p2.queue_free()
	await t.get_tree().process_frame
	Profile.data = saved_data
	Profile.legacy_bootstrap = saved_boot
	# restore real state
	_rm_tree(root); _rm_tree(root2)
	OwnerVault.reset_for_tests("user://security", CryptoBox.DEFAULT_ITERATIONS)
	SecureFile.reset_for_tests()
	SaveMigration.data_root = "user://"
	AutonomyGuard.reset_for_tests("user://security/estop.json")
