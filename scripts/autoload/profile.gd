extends Node
## v0.5 local player profile (per device): display name, role (owner | guest) and the
## avatar the player built in the first-launch creator. Saved to user://profile.json.
## Phoenix's look is the owner-only "Sovereign" preset, never the default for others.
## Roles are local only for now; multiplayer will verify them server-side later.

signal changed
const PATH := "user://profile.json"
const OPTIONS_PATH := "res://data/avatar_options.json"
## SEC-FIX-1: the old unsalted SHA-256 of the legacy owner code is RETIRED from the release path.
## It used to ship in every APK and could be brute-forced offline. The value was removed from the repo:
# const OWNER_CODE_SHA256 := "<removed: SEC-FIX-1, docs/SECURITY_DEVICE_TEST_PLAN.md F1>"
## Legacy bootstrap (optional, devices with no vault yet): a PBKDF2-HMAC-SHA256 record of the
## legacy code with a random salt, read from the gitignored res://config/owner_bootstrap.local.cfg
## ([owner] salt=<base64>, iter=<int>, hash=<hex>). Nothing secret is committed. The legacy code can
## ONLY bootstrap the first PIN setup; once vault.json has a pin slot it is refused.
const BOOTSTRAP_PATH := "res://config/owner_bootstrap.local.cfg"
var data := {}
var options := {}
var legacy_bootstrap := _load_bootstrap()   # {salt, iter, hash}; tests swap in make_bootstrap()

func _ready() -> void:
	var o: Variant = JSON.parse_string(FileAccess.get_file_as_string(OPTIONS_PATH))
	options = o if o is Dictionary else {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	data = d if d is Dictionary else {}
	# when encrypted saves become readable (first unlock this launch), drop stale caches
	OwnerVault.on_storage_ready.append(func():
		EveCore.reload_all()
		Estate.reload_data()   # not Estate.reload(): that is Script.reload() on a class_name
		ViperAdminData.reset()
		var ab := get_node_or_null("/root/AgentBrain")
		if ab and ab.has_method("reload_brains"): ab.reload_brains())

func has_profile() -> bool:
	return data.has("avatar") and str(data.get("name", "")) != ""

func role() -> String:
	return str(data.get("role", "guest"))

## Owner powers need BOTH the owner role on this device AND an unlocked owner session
## (OwnerVault: PIN/passphrase or the legacy owner code, auto-lock after inactivity).
func is_owner() -> bool:
	return role() == "owner" and OwnerVault.is_unlocked()

## The device belongs to the owner (role), whether or not the session is unlocked right now.
func is_owner_device() -> bool:
	return role() == "owner"

func _exit_tree() -> void:
	OwnerVault.on_storage_ready.clear()   # static Callables must not outlive this node at shutdown

func _input(e: InputEvent) -> void:
	if e is InputEventKey or e is InputEventMouseButton or e is InputEventScreenTouch: OwnerVault.touch()

func display_name() -> String:
	return str(data.get("name", "Traveler"))

static func _norm_code(code: String) -> String: return code.strip_edges().to_lower()

static func _load_bootstrap() -> Dictionary:
	if not FileAccess.file_exists(BOOTSTRAP_PATH): return {}
	var c := ConfigFile.new()
	if c.load(BOOTSTRAP_PATH) != OK: return {}
	return {"salt": str(c.get_value("owner", "salt", "")), "iter": int(c.get_value("owner", "iter", 0)), "hash": str(c.get_value("owner", "hash", ""))}

## Build a salted PBKDF2 bootstrap record (owner tooling + tests). Never store the code itself.
static func make_bootstrap(code: String, iter := CryptoBox.DEFAULT_ITERATIONS) -> Dictionary:
	var salt := CryptoBox.random_bytes(16)
	return {"salt": Marshalls.raw_to_base64(salt), "iter": iter,
		"hash": CryptoBox.pbkdf2_sha256(_norm_code(code).to_utf8_buffer(), salt, iter).hex_encode()}

func legacy_code_matches(code: String) -> bool:
	var b := legacy_bootstrap
	if str(b.get("hash", "")) == "" or str(b.get("salt", "")) == "" or int(b.get("iter", 0)) < 1000 or _norm_code(code) == "": return false
	var h := CryptoBox.pbkdf2_sha256(_norm_code(code).to_utf8_buffer(), Marshalls.base64_to_raw(str(b["salt"])), int(b["iter"]))
	return CryptoBox.equal(h.hex_encode().to_ascii_buffer(), str(b["hash"]).to_lower().to_ascii_buffer())

## Unlock the owner session.
## - Vault exists: PIN or passphrase via OwnerVault. The legacy owner code is refused (SEC-FIX-1);
##   old legacy key slots are removed once, on first load of a vault that has a pin slot.
## - No vault yet: the legacy code (PBKDF2 bootstrap match) opens a SETUP-ONLY bootstrap. It grants
##   no owner powers; the only thing it allows is OwnerVault.setup() of the first PIN.
## SEC-FIX-5: first-run owner setup is allowed only when there is NO vault file (valid or corrupted),
## no legacy bootstrap record in the build, and no existing owner data (profile role) on the device.
func first_run_allowed() -> bool:
	return not OwnerVault.vault_file_present() and str(legacy_bootstrap.get("hash", "")) == "" and role() != "owner"

## First-run: create the owner PIN/passphrase (confirmed by the caller), claim the device, log it.
func first_run_setup(secret: String) -> String:
	if not first_run_allowed(): return "First-run setup is not available on this device."
	var e := OwnerVault.setup(secret, true)
	if e != "": return e
	data["role"] = "owner"
	save()
	ViperAdminData.revisions().commit("role", "security/owner_setup", null, "first-run owner PIN created",
		"Owner PIN/passphrase created on first run (SEC-FIX-5)", "owner")
	return ""

func try_owner_unlock(code: String) -> bool:
	var ok := false
	if OwnerVault.has_vault():
		ok = OwnerVault.unlock(code) == ""
	elif legacy_code_matches(code):
		OwnerVault.start_legacy_session(code.strip_edges())
		ok = true
	if ok and role() != "owner":
		data["role"] = "owner"
		save()
	elif ok: changed.emit()
	return ok

func default_avatar() -> Dictionary:
	return preset_avatar("wanderer")

func preset_avatar(id: String) -> Dictionary:
	for p in options.get("presets", []):
		if p["id"] == id:
			if bool(p.get("owner_only", false)) and not is_owner_device(): return {}   # cosmetic: survives auto-lock
			if p.has("from"):
				var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p["from"]))
				if d is Dictionary:
					var a: Dictionary = d.duplicate()
					a["body"] = 0
					return a
			return (p["avatar"] as Dictionary).duplicate(true)
	return {}

func avatar() -> Dictionary:
	return data.get("avatar", default_avatar())

func save_profile(name: String, av: Dictionary) -> void:
	data["name"] = name.strip_edges() if name.strip_edges() != "" else "Traveler"
	data["avatar"] = av
	if not data.has("role"): data["role"] = "guest"
	if not data.has("created"): data["created"] = Time.get_datetime_string_from_system()
	save()

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data, "  "))
	changed.emit()

## Avatar dict (hex strings) -> HumanoidModel style (Colors).
static func to_style(av: Dictionary) -> Dictionary:
	var st := {"look": "phoenix" if av.has("hair_streaks") or str(av.get("look", "")) == "phoenix" else "classic"}
	for k in ["skin", "hair", "eyes", "outfit", "top", "pants", "accent", "trim", "jacket"]:
		if av.has(k): st[k] = Color(str(av[k]))
	if not st.has("jacket") and st.has("outfit"): st["jacket"] = st["outfit"]
	var fh := str(av.get("facial_hair", av.get("beard", "None")))
	if fh != "None" and fh != "": st["beard"] = Color(fh)
	var streaks: Array = []
	for c in av.get("hair_streaks", []): streaks.append(Color(str(c)))
	if not streaks.is_empty(): st["hair_streaks"] = streaks if streaks.size() >= 6 else [st.get("hair", Color.BLACK)] + streaks + streaks
	st["masculine"] = int(av.get("body", 0)) == 0
	st["curly"] = int(av.get("hair_style", 0)) == 1
	for acc in ["crown", "chains", "horns"]:
		st[acc] = bool(av.get(acc, false))
	st["glow"] = float(av.get("glow", 1.2))
	st["third_person"] = true
	return st
