extends RefCounted
## VWGAP: OAR/IAR import (TarGz, OpenSimArchive, InteropImport + Admin › Interop), SL/OpenSim estate
## flags + covenant, Landmarks (home, history, SLURL-like addresses), encryption fixes F1/F2.
## Throwaway roots; restores every static it touches.

const OAR := "res://tests/fixtures/sample.oar"   # made with Python tarfile (GNU format) + gzip
const IAR := "res://tests/fixtures/sample.iar"

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func run(t: Node) -> void:
	var root := "user://test_interop_%d" % Time.get_ticks_usec()
	var saved_vault := OwnerVault.root
	var saved_iter := OwnerVault.iterations
	var saved_estop := AutonomyGuard.path
	var saved_lm := Landmarks.path
	var saved_interop := InteropImport.root
	var saved_tiers := Tiers.root
	var had_estate := FileAccess.file_exists(Estate.PATH)
	var estate_raw := FileAccess.get_file_as_bytes(Estate.PATH) if had_estate else PackedByteArray()
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(root.path_join("security/estop.json"))
	Tiers.reset_for_tests(root.path_join("social"))
	Social.reset_for_tests(root.path_join("social"))
	Estate.reset_for_tests(); Estate._cfg = ConfigFile.new()
	Landmarks.reset_for_tests(root.path_join("world/landmarks.json"))
	InteropImport.reset_for_tests(root.path_join("interop"))
	Tiers.owner_override = false
	Tiers.roles()["assign"]["maker"] = "creator"
	Tiers.roles()["assign"]["em"] = "estate_manager"

	_tar(t); _archives(t); _import(t); _estate(t); _landmarks(t); _crypto(t, root)

	Tiers.owner_override = null
	OwnerVault.reset_for_tests(saved_vault, saved_iter); SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(saved_estop)
	Tiers.reset_for_tests(saved_tiers); Social.reset_for_tests(saved_tiers)
	Landmarks.reset_for_tests(saved_lm); InteropImport.reset_for_tests(saved_interop)
	if had_estate:
		var f := FileAccess.open(Estate.PATH, FileAccess.WRITE); f.store_buffer(estate_raw); f.close()
	elif FileAccess.file_exists(Estate.PATH): DirAccess.remove_absolute(Estate.PATH)
	Estate.reset_for_tests()
	_rm_tree(root)

static func _tar(t: Node) -> void:
	var files := {"a.txt": "hello", "dir/b.bin": PackedByteArray([0, 1, 2, 255]), "big.txt": "x".repeat(1300)}
	var r := TarGz.read(TarGz.write(files))
	t.check(r["ok"] and r["entries"].size() == 3, "tar: gzip round trip keeps 3 files")
	t.check((r["entries"]["a.txt"] as PackedByteArray).get_string_from_utf8() == "hello" and r["entries"]["dir/b.bin"] == PackedByteArray([0, 1, 2, 255]), "tar: contents byte-exact")
	t.check((r["entries"]["big.txt"] as PackedByteArray).size() == 1300, "tar: multi-block file size right")
	var evil := TarGz.read(TarGz.write({"../escape.txt": "x", "/abs.txt": "y", "ok.txt": "z"}))
	t.check(evil["ok"] and evil["entries"].keys() == ["ok.txt"] and evil["skipped"] == 2, "tar: '..' and absolute names dropped")
	t.check(not TarGz.read(PackedByteArray([0x1f, 0x8b, 1, 2, 3]))["ok"], "tar: corrupt gzip refused, no crash")
	t.check(not TarGz.read(TarGz.write({"a": "b"}).slice(0, 30))["ok"], "tar: truncated archive refused")

static func _archives(t: Node) -> void:
	var oar := FileAccess.get_file_as_bytes(OAR)
	t.check(oar.size() > 0 and TarGz.is_gzip(oar), "oar: fixture present and gzip")
	var s := OpenSimArchive.inspect_oar(oar)
	t.check(s["ok"] and s["kind"] == "oar" and s["version"] == "1.0" and s["region_size"] == "256,256", "oar: archive.xml read (v1.0, 256 m)")
	t.check(s["terrains"].size() == 1 and s["terrains"][0]["size"] == 256 and is_equal_approx(s["terrains"][0]["min"], 18.0) and is_equal_approx(s["terrains"][0]["max"], 50.0), "oar: RAW32 terrain 256², 18..50 m")
	t.check(s["objects"] == 1 and s["assets"].get("texture", 0) == 1, "oar: object + asset counts")
	t.check(s["parcels"].size() == 1 and s["parcels"][0]["name"] == "Fixture Plaza" and s["parcels"][0]["area"] == 65536, "oar: landdata parcel name/area")
	var vf: Dictionary = s["parcels"][0]["viper_flags"]
	t.check(vf["allow_fly"] and vf["allow_landmark"] and vf["allow_build"] and not vf["allow_push"] and not vf["allow_damage"], "oar: SL parcel flag bits -> our estate flags")
	t.check(s["settings"].get("RestrictPushing") == "True" and s["settings"].get("AgentLimit") == "40", "oar: region settings summary")
	var tr := OpenSimArchive.oar_terrain(oar)
	var hm := OpenSimArchive.to_viper_heightmap(tr["terrain"], 64)
	t.check(hm["size"] == 64 and hm["heights"].size() == 4096 and hm["src_size"] == 256, "oar: heightmap downsampled to 64²")
	t.check(is_equal_approx(hm["heights"][0], -5.0) and is_equal_approx(hm["heights"][63 * 64 + 63], 7.0), "oar: water 20 m -> -3 m (18 m -> -5, 30 m -> 7)")
	var peak := 0.0
	for v in hm["heights"]: peak = maxf(peak, v)
	t.check(is_equal_approx(peak, 27.0), "oar: 8 m peak survives box filter (50 m -> 27)")
	# LLRAW: 2x2, h = b0 * b1/128, rows bottom-up
	var raw := PackedByteArray(); raw.resize(52); raw.fill(0)
	raw[0] = 10; raw[1] = 128   # file row 0 = top -> heights row 1
	raw[39] = 40; raw[40] = 64  # file row 1, x=1 -> heights row 0, x=1 = 20
	var ll := OpenSimArchive.parse_llraw(raw)
	t.check(ll["ok"] and ll["size"] == 2 and is_equal_approx(ll["heights"][2], 10.0) and is_equal_approx(ll["heights"][1], 20.0), "terrain: LLRAW 13-channel decode + flip")
	t.check(not OpenSimArchive.parse_r32(PackedByteArray([1, 2, 3]))["ok"], "terrain: odd RAW32 refused")
	var nan := PackedFloat32Array([0.0, NAN, 1.0, 2.0]).to_byte_array()
	t.check(not OpenSimArchive.parse_r32(nan)["ok"], "terrain: NaN heights refused")
	# IAR
	var i := OpenSimArchive.inspect_iar(FileAccess.get_file_as_bytes(IAR))
	t.check(i["ok"] and i["items"].size() == 3, "iar: 3 inventory items")
	t.check(i["notecards"].get("Plaza Rules", "") == "Welcome to Fixture Plaza.\nRules: be kind. ✨", "iar: notecard text extracted (Linden text v2, UTF-8 byte length)")
	var tex: Array = i["textures"]
	t.check(tex.size() == 1 and tex[0]["format"] == "jp2" and not tex[0]["convertible"], "iar: JPEG 2000 texture flagged for conversion")
	var door: Array = i["items"].filter(func(x): return x["name"] == "Door")
	t.check(door.size() == 1 and door[0]["type"] == "script" and not door[0]["next_copy"], "iar: script listed, next-owner no-copy read")
	var rules: Array = i["items"].filter(func(x): return x["name"] == "Plaza Rules")
	t.check(rules[0]["next_copy"] and rules[0]["next_modify"] and rules[0]["next_transfer"] and rules[0]["folder"] == "Notecards", "iar: full-perm notecard + folder")
	t.check(not OpenSimArchive.inspect_oar(FileAccess.get_file_as_bytes(IAR))["ok"], "oar: IAR is not mistaken for an OAR")
	t.check(not OpenSimArchive.inspect_iar(oar)["ok"], "iar: OAR is not mistaken for an IAR")
	t.check(OpenSimArchive.notecard_text("plain".to_utf8_buffer()) == "plain", "iar: plain-text notecard passthrough")

static func _import(t: Node) -> void:
	t.check(InteropImport.inspect(OAR, "visitor")["ok"], "interop: anyone can preview")
	var g := InteropImport.import_file(OAR, "visitor")
	t.check(not g["ok"] and InteropImport.log_entries().is_empty(), "interop: guest import refused, nothing logged")
	t.check(not InteropImport.import_file(OAR, Tiers.OWNER_ID)["ok"], "interop: LOCKED owner can't import")
	var r := InteropImport.import_file(OAR, "maker")
	t.check(r["ok"] and r["terrain"]["src_size"] == 256 and r["terrain"]["size"] == 64, "interop: creator imports OAR terrain")
	var hm := InteropImport.load_terrain(r)
	t.check(hm.get("size") == 64 and hm.get("heights", []).size() == 4096, "interop: stored heightmap readable")
	var ri := InteropImport.import_file(IAR, "maker")
	t.check(ri["ok"] and ri["notecards"]["count"] == 1 and InteropImport.load_notecards(ri).has("Plaza Rules"), "interop: creator imports IAR notecards")
	var bad := InteropImport.import_file("res://tests/fixtures/missing.oar", "maker")
	t.check(not bad["ok"] and InteropImport.status()["failed"] == 1, "interop: failed import logged as failed")
	t.check(not InteropImport.import_file("res://README.md", "maker")["ok"], "interop: non-archive extension refused")
	var st := InteropImport.status()
	t.check(st["oar"] == 1 and st["iar"] == 1 and st["imports"] == 4, "interop: status counts (%s)" % str(st))
	InteropImport.reload_data()
	t.check(InteropImport.log_entries().size() == 4, "interop: log persists")
	t.check(not InteropImport.clear_log("maker") and not InteropImport.clear_log(Tiers.OWNER_ID), "interop: only the unlocked owner clears the log")
	Tiers.owner_override = true
	t.check(InteropImport.clear_log(Tiers.OWNER_ID) and InteropImport.log_entries().is_empty(), "interop: unlocked owner clears log")
	Tiers.owner_override = false

static func _estate(t: Node) -> void:
	var old := ConfigFile.new(); old.parse("[region:Old]\nallow_fly=false\n")
	Estate._cfg = old
	t.check(not Estate.region_get("Old", "allow_fly") and Estate.region_get("Old", "allow_push") == true and Estate.region_get("Old", "maturity") == "general", "estate: old cfg keeps values, new flags default (back-compat)")
	t.check(Estate.covenant("Old") == "", "estate: no covenant by default")
	var bits := Estate.sl_parcel_flags("Old")
	t.check(bits & 0x1 == 0 and bits & 0x40 != 0 and bits & 0x200000 == 0, "estate: SL bits (no fly, build ok, push allowed)")
	Estate.region_set("Old", "allow_push", false)
	t.check(Estate.sl_parcel_flags("Old") & 0x200000 != 0, "estate: allow_push=false -> RESTRICT_PUSHOBJECT bit")
	var back := Estate.flags_from_sl(Estate.sl_parcel_flags("Old"))
	var same := true
	for k in Estate.SL_PARCEL_BITS: same = same and back[k] == bool(Estate.region_get("Old", k))
	t.check(same, "estate: SL bit field round trip")
	t.check(Estate.set_covenant("Old", "No griefing.", "visitor") != "" and Estate.covenant("Old") == "", "estate: guest can't edit covenant")
	t.check(Estate.set_covenant("Old", "  No griefing.  ", "em") == "" and Estate.covenant("Old") == "No griefing." and int(Estate.region_get("Old", "covenant_changed")) > 0, "estate: estate manager sets covenant + timestamp")
	t.check(Estate.set_covenant("Old", "x".repeat(5000), "em") == "" and Estate.covenant("Old").length() == Estate.COVENANT_MAX, "estate: covenant capped")

static func _landmarks(t: Node) -> void:
	Estate._cfg = ConfigFile.new()
	var a := Landmarks.address("Region M50", Vector3(12.4, 30, -7.6))
	t.check(a == "viper://Region%20M50/12/30/-8", "landmarks: SLURL-like address (%s)" % a)
	var p := Landmarks.parse_address(a)
	t.check(p["ok"] and p["region"] == "Region M50" and p["pos"] == Vector3(12, 30, -8), "landmarks: address parses back")
	t.check(Landmarks.parse_address("Spawn")["ok"] and not Landmarks.parse_address("viper://R/abc")["ok"] and not Landmarks.parse_address("")["ok"], "landmarks: bare region ok, junk refused")
	var r := Landmarks.save_here("Cabin", "Spawn", Vector3(10, 5, 10), "visitor")
	t.check(r["ok"] and Landmarks.list().size() == 1 and Landmarks.list()[0]["name"] == "Cabin", "landmarks: save + list")
	t.check(Landmarks.save_here("", "Spawn", Vector3(70, 0, 3), "visitor")["ok"] and Landmarks.list()[1]["name"] == "Spawn (70, 3)", "landmarks: default name")
	t.check(Landmarks.rename(r["id"], "Log Cabin") and Landmarks.list()[0]["name"] == "Log Cabin", "landmarks: rename")
	Estate.region_set("NoLM", "allow_landmark", false); Estate.region_set("NoLM", "allow_set_home", false)
	t.check(not Landmarks.save_here("x", "NoLM", Vector3.ZERO, "visitor")["ok"], "landmarks: allow_landmark=false blocks residents")
	t.check(Landmarks.save_here("x", "NoLM", Vector3.ZERO, "em")["ok"], "landmarks: estate manager may still save (SL rule)")
	t.check(Landmarks.set_home("NoLM", Vector3.ZERO, "visitor") != "" and not Landmarks.has_home(), "landmarks: allow_set_home=false blocks Set Home")
	t.check(Landmarks.set_home("Spawn", Vector3(1, 2, 3), "visitor") == "" and Landmarks.to_vec(Landmarks.home()) == Vector3(1, 2, 3), "landmarks: Set Home")
	Landmarks.record_teleport("Spawn", Vector3(0, 0, 0))
	Landmarks.record_teleport("Spawn", Vector3(1, 0, 0))   # within 2 m: merged
	Landmarks.record_teleport("Venus", Vector3(500, 0, 0))
	t.check(Landmarks.history().size() == 2 and Landmarks.history()[0]["region"] == "Venus", "landmarks: history newest first, near-duplicates merged")
	for k in 60: Landmarks.record_teleport("R%d" % k, Vector3(k * 10, 0, 0))
	t.check(Landmarks.history().size() == Landmarks.MAX_HISTORY, "landmarks: history capped at 50")
	Landmarks.reload_data()
	t.check(Landmarks.list().size() == 3 and Landmarks.has_home() and Landmarks.history().size() == 50, "landmarks: persisted")
	t.check(Landmarks.remove(r["id"]) and Landmarks.list().size() == 2 and not Landmarks.remove("nope"), "landmarks: remove")
	t.check(Landmarks.clear_history() and Landmarks.history().is_empty(), "landmarks: clear history")

static func _crypto(t: Node, root: String) -> void:
	# F2: atomic replace keeps exactly one file, never zero
	var a := root.path_join("swap/a.txt"); var b := root.path_join("swap/a.txt.tmp")
	DirAccess.make_dir_recursive_absolute(a.get_base_dir())
	for pr in [[a, "old"], [b, "new"]]:
		var f := FileAccess.open(pr[0], FileAccess.WRITE); f.store_string(pr[1]); f.close()
	t.check(SecureFile.replace_file(b, a) and FileAccess.get_file_as_string(a) == "new" and not FileAccess.file_exists(b), "crypto F2: replace_file swaps atomically")
	# F7: social/world/interop stores are migration targets
	var saved_dr := SaveMigration.data_root
	SaveMigration.data_root = root.path_join("mig")
	for rel in ["social/social.json", "world/landmarks.json", "interop/imports.json", "profile.json"]:
		DirAccess.make_dir_recursive_absolute(SaveMigration.data_root.path_join(rel).get_base_dir())
		var f := FileAccess.open(SaveMigration.data_root.path_join(rel), FileAccess.WRITE); f.store_string("{}"); f.close()
	var tf: Array = SaveMigration.target_files().map(func(x): return SaveMigration._rel(x))
	t.check(tf.size() == 3 and "social/social.json" in tf and "world/landmarks.json" in tf and "interop/imports.json" in tf, "crypto F7: social/world/interop saves are migration targets (%s)" % str(tf))
	SaveMigration.data_root = saved_dr
	# F1: unlock_with_dek must not accept arbitrary bytes
	t.check(not OwnerVault.unlock_with_dek(CryptoBox.random_bytes(64)), "crypto F1: no vault -> unlock_with_dek refused")
	t.check(OwnerVault.setup("13572468", true) == "", "crypto F1: vault set up")
	var k := OwnerVault.dek()
	var real: PackedByteArray = k["enc"] + k["mac"]
	t.check(str(OwnerVault.vault().get("dek_check", "")) != "" and not FileAccess.get_file_as_string(OwnerVault.root.path_join("vault.json")).contains(Marshalls.raw_to_base64(real)), "crypto F1: key check value stored, DEK not")
	OwnerVault.lock_all()
	t.check(not OwnerVault.unlock_with_dek(CryptoBox.random_bytes(64)) and not OwnerVault.is_unlocked() and not OwnerVault.storage_ready(), "crypto F1: random 64 bytes refused (was: owner session)")
	t.check(not OwnerVault.unlock_with_dek(PackedByteArray()), "crypto F1: wrong length refused")
	t.check(OwnerVault.unlock_with_dek(real) and OwnerVault.is_unlocked() and OwnerVault.storage_ready(), "crypto F1: the real DEK still works (biometric path)")
	OwnerVault.lock()
	var fake := real.duplicate(); fake[0] ^= 1
	t.check(not OwnerVault.unlock_with_dek(fake), "crypto F1: one flipped bit refused")
	# older vaults (no dek_check) get one on the next PIN unlock
	OwnerVault.lock_all()
	OwnerVault.vault().erase("dek_check"); OwnerVault._save_vault()
	t.check(not OwnerVault.unlock_with_dek(real), "crypto F1: old vault without check refuses DEK unlock")
	t.check(OwnerVault.unlock("13572468") == "" and str(OwnerVault.vault().get("dek_check", "")) != "", "crypto F1: PIN unlock adds the check to an old vault")
	OwnerVault.lock_all()
	t.check(OwnerVault.unlock_with_dek(real), "crypto F1: upgraded old vault accepts the real DEK")
	OwnerVault.lock_all()

static func run_ui(t: Node) -> void:
	var root := "user://test_interop_ui_%d" % Time.get_ticks_usec()
	var saved := InteropImport.root
	InteropImport.reset_for_tests(root)
	Tiers.owner_override = false
	var s := InteropScreen.open(t)
	await t.get_tree().process_frame
	t.check(s != null and s.is_inside_tree() and InteropScreen.open(t) == s, "interop ui: opens once")
	t.check(s.import_btn != null and s.import_btn.disabled == not Tiers.can(Tiers.SELF, "upload"), "interop ui: Import button follows the upload gate")
	t.check(s.clear_btn != null and s.clear_btn.disabled, "interop ui: Clear log disabled without owner unlock")
	var pv: Dictionary = s.preview(OAR)
	t.check(pv["ok"] and s.preview_label.text.begins_with("OAR v1.0"), "interop ui: preview shows OAR summary")
	var small := true
	for l in s.find_children("*", "Label", true, false):
		var fs: int = (l as Label).get_theme_font_size("font_size")
		if fs > 0 and fs < 16: small = false
	t.check(small, "interop ui: no text under 16 px")
	s.queue_free()
	await t.get_tree().process_frame
	Tiers.owner_override = null
	InteropImport.reset_for_tests(saved)
	_rm_tree(root)

## Docs + seeds: new pages reach the in-app wiki, tracker rows reach tickets.
static func run_docs(t: Node) -> void:
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	t.check(wiki is Dictionary, "vwgap docs: wiki seed parses")
	if not (wiki is Dictionary): return
	for p in ["VirtualWorldFeatureGap", "Interop", "Encryption", "InteropGuide", "LandmarksTeleport", "EncryptionGuide"]:
		t.check(wiki.has(p), "vwgap docs: wiki seed has " + p)
	var gap := str(wiki.get("VirtualWorldFeatureGap", {}).get("text", ""))
	t.check(gap.contains("Avination") and gap.contains("OpenLife Grid") and gap.contains("| feature | source | ours | owner | status |"), "vwgap docs: Avination/OLG rows in viewer-parity format")
	t.check(not wiki.get("VirtualWorldFeatureGap", {}).get("truncated", true), "vwgap docs: gap page not truncated")
	t.check(str(wiki.get("Interop", {}).get("text", "")).contains("BSD-3"), "vwgap docs: interop licensing note")
	t.check(str(wiki.get("InteropGuide", {}).get("text", "")).contains("status: partial"), "vwgap docs: interop wiki page honest status")
	var enc := str(wiki.get("Encryption", {}).get("text", ""))
	t.check(enc.contains("PBKDF2") and enc.contains("F1") and not enc.contains(Profile.OWNER_CODE_SHA256), "vwgap docs: encryption doc has findings, no code hash")
	var tk: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/tickets_seed.json"))
	var found := {}
	for x in tk:
		if str(x.get("milestone", "")).begins_with("VWGAP-"): found[x["milestone"]] = x["status"]
	t.check(found.size() == 7 and found.get("VWGAP-1") == "closed" and found.get("VWGAP-5") == "new", "vwgap docs: tracker rows seeded (%d)" % found.size())
