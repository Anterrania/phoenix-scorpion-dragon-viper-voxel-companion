extends Node
## v0.5 local player profile (per device): display name, role (owner | guest) and the
## avatar the player built in the first-launch creator. Saved to user://profile.json.
## Phoenix's look is the owner-only "Sovereign" preset, never the default for others.
## Roles are local only for now; multiplayer will verify them server-side later.

signal changed
const PATH := "user://profile.json"
const OPTIONS_PATH := "res://data/avatar_options.json"
## SHA-256 of the owner unlock code. Placeholder: public repo, so this is NOT security.
## Real owner auth comes with the server (account sign-in). Owner: pick your own code.
const OWNER_CODE_SHA256 := "8ae5a77088495aa98e24931de8e55e51b027353c4d1f2026651c964df6d996eb"
var data := {}
var options := {}
var owner_code_hash := OWNER_CODE_SHA256   # tests swap in a known hash

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

static func code_hash(code: String) -> String:
	return code.strip_edges().to_lower().sha256_text()

## Unlock the owner session.
## - Vault exists: PIN, passphrase or the legacy owner code (kept as its own key slot) via OwnerVault.
## - No vault yet (phones from before v0.12): the legacy owner code (hash match) opens an owner
##   session; the UI then offers the set-PIN step (OwnerVault.needs_pin_setup()).
func try_owner_unlock(code: String) -> bool:
	var ok := false
	if OwnerVault.has_vault():
		ok = OwnerVault.unlock(code) == ""
	elif code_hash(code) == owner_code_hash:
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
