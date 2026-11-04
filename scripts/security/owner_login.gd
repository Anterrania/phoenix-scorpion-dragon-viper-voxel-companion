class_name OwnerLogin
extends RefCounted
## v0.14 AUTH-1: owner sign-in shared with the Scorpion Viper social app.
## Username "SkorpionViper" (case-insensitive, trimmed), display name "Phoenix Scorpion Dragon Viper".
## Record format matches the social app (src/lib/owner-auth.ts in Anterrania/SkorpionViper):
##   pbkdf2-sha256$<iterations>$<salt base64>$<derived key hex>
## PBKDF2-HMAC-SHA256, salt >= 16 bytes, 32-byte key, >= 200,000 iterations. Password is trimmed, case kept.
## (The social app also NFC-normalises; Godot has no NFC, so a password typed in decomposed Unicode would not
## match. ASCII passwords are unaffected.) Malformed record -> sign-in is off (fail closed).
## The record is NOT in the repo: CI writes the gitignored res://config/owner_login.local.cfg from the GitHub
## secret OWNER_PASS_HASH right before export. No secret -> no password sign-in; the PIN still works.
## Owner gates stay: a correct sign-in opens the same OwnerVault session as the PIN (auto-lock, backoff,
## Brain Cell lock unchanged). With no vault yet, it is the owner's first-run setup (the password becomes the
## vault passphrase and an account slot). With a vault, it unlocks only if the password was linked (account slot) while unlocked.

const USERNAME := "SkorpionViper"
const DISPLAY_NAME := "Phoenix Scorpion Dragon Viper"
const RECORD_PATH := "res://config/owner_login.local.cfg"
const PREFIX := "pbkdf2-sha256"
const MIN_ITER := 200000
const MAX_ITER := 5000000
const FREE_TRIES := 5
const ERR := "Wrong username or password."

static var record_override = null   # tests: a record string (or "" for none)
static var min_iter := MIN_ITER      # tests lower this
static var root := "user://security"
static var clock_s := Callable()     # tests: fake clock

static func _now() -> int: return int(clock_s.call()) if clock_s.is_valid() else int(Time.get_unix_time_from_system())

static func record() -> String:
	if record_override != null: return str(record_override)
	if not FileAccess.file_exists(RECORD_PATH): return ""
	var c := ConfigFile.new()
	if c.load(RECORD_PATH) != OK: return ""
	return str(c.get_value("owner", "record", "")).strip_edges()

## {iter, salt, key} or {} when malformed.
static func parse(rec: String) -> Dictionary:
	var p := rec.strip_edges().split("$")
	if p.size() != 4 or p[0] != PREFIX: return {}
	if not p[1].is_valid_int(): return {}
	var it := int(p[1])
	if it < min_iter or it > MAX_ITER: return {}
	var salt := Marshalls.base64_to_raw(p[2])
	if salt.size() < 16: return {}
	var hx := p[3].to_lower()
	if hx.length() != 64: return {}
	for ch in hx:
		if not ch in "0123456789abcdef": return {}
	return {"iter": it, "salt": salt, "key": hx.hex_decode()}

static func available() -> bool: return not parse(record()).is_empty()

static func username_ok(u: String) -> bool: return u.strip_edges().to_lower() == USERNAME.to_lower()
static func norm_password(p: String) -> String: return p.strip_edges()

## Make a record (tests and owner tooling; the release record comes from scripts/owner-hash.mjs in the social repo).
static func make_record(password: String, iter := 310000) -> String:
	var salt := CryptoBox.random_bytes(16)
	return "%s$%d$%s$%s" % [PREFIX, iter, Marshalls.raw_to_base64(salt), CryptoBox.pbkdf2_sha256(norm_password(password).to_utf8_buffer(), salt, iter).hex_encode()]

static func verify(username: String, password: String) -> bool:
	var r := parse(record())
	if r.is_empty() or norm_password(password) == "": return false
	var got := CryptoBox.pbkdf2_sha256(norm_password(password).to_utf8_buffer(), r["salt"], int(r["iter"]))   # always derive (timing)
	return CryptoBox.equal(got, r["key"]) and username_ok(username)

# ---------- backoff while there is no vault (the vault has its own) ----------
static func _fails_path() -> String: return root.path_join("login_fails.json")
static func _fails() -> Dictionary:
	var d: Variant = SecureFile.read_json(_fails_path(), {})
	return d if d is Dictionary else {}
static func retry_in_s() -> int: return maxi(0, int(_fails().get("retry_at", 0)) - _now())
static func _fail() -> void:
	var f := _fails()
	f["fails"] = int(f.get("fails", 0)) + 1
	if f["fails"] >= FREE_TRIES: f["retry_at"] = _now() + mini(3600, 30 * int(pow(2, f["fails"] - FREE_TRIES)))
	DirAccess.make_dir_recursive_absolute(root)
	SecureFile.write_json(_fails_path(), f)
static func _clear_fails() -> void:
	if FileAccess.file_exists(_fails_path()): DirAccess.remove_absolute(_fails_path())

## Sign in. "" on success (owner session open), else an error. Never logs the password.
static func sign_in(username: String, password: String) -> String:
	if OwnerVault.has_vault():
		if not username_ok(username):
			OwnerVault.unlock(CryptoBox.random_bytes(24).hex_encode())   # counts toward the vault's backoff like a wrong PIN
			return ERR
		var e := OwnerVault.unlock(norm_password(password))
		if e != "": return e if e.begins_with("Too many") else ERR
		_after(false)
		return ""
	if not available(): return "Owner sign-in isn't set up in this build. Use your PIN."
	if retry_in_s() > 0: return "Too many tries. Wait %d s." % retry_in_s()
	if not verify(username, password):
		_fail()
		return ERR
	if OwnerVault.vault_file_present(): return "A vault already exists on this device (unreadable)."
	OwnerVault.start_login_bootstrap()
	var se := OwnerVault.setup(norm_password(password))
	if se != "": return se
	OwnerVault.add_account_slot(norm_password(password))   # also as "account" slot: survives Change PIN
	_clear_fails()
	_after(true)
	return ""

## Owner is unlocked (PIN): link the shared password so it also opens this vault.
static func link(username: String, password: String) -> String:
	if not OwnerVault.is_unlocked(): return "Unlock with your PIN first."
	if available() and not verify(username, password): return ERR
	if not available() and not username_ok(username): return ERR
	return OwnerVault.add_account_slot(norm_password(password))

static func _after(first: bool) -> void:
	var ml := Engine.get_main_loop()
	var p: Node = ml.root.get_node_or_null("Profile") if ml is SceneTree else null
	if p == null: return
	p.data["role"] = "owner"
	p.data["username"] = USERNAME
	p.data["name"] = DISPLAY_NAME
	p.save()
	ViperAdminData.revisions().commit("role", "security/owner_login", null, "owner signed in as " + USERNAME,
		("Owner sign-in created the vault (first run)" if first else "Owner signed in with the shared account"), "owner")

static func reset_for_tests(p_root: String) -> void:
	root = p_root; record_override = null; min_iter = MIN_ITER; clock_s = Callable()
