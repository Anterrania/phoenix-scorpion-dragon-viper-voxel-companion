class_name EveCore
extends RefCounted
## Port of the owner's Vala "Anterranian Eve Core" (docs/vala_reference/AnterranianEveCore.vala).
## Each companion owns one EveCore wrapping one EveBrainCell. Memory entries are structured
## dictionaries saved under user://eve/<id>.json. The "hash" is a plain id string (no blockchain).
## propose_update() feeds an owner-approval queue shown in MENU › Proposals.

const DEFAULT_VOICE := "Phoenix_Default_Voice"
const COMPANION_VOICE := "Phoenix_Companion_Voice"
const MAX_ENTRIES := 500
const OWNER_ID := "phoenix"  # the owner's own core (player music / land actions)
## Per-companion voice profiles. Anything not listed uses persona.json voice.profile, then DEFAULT_VOICE.
const VOICE_PROFILES := {
	"foxy_ani": {"name": "Eve", "accent": "Canadian", "style": "raw, fiery"},
}
const FIRE_THEMES := {"foxy_ani": ["phoenix", "ember", "Venus"]}

static var save_dir := "user://eve"
static var _cores := {}
static var _proposals: Array = []
static var _proposals_loaded := false

# ---------------- brain cell ----------------
class EveBrainCell:
	extends RefCounted
	var id: String
	var memory_hash: String
	var last_update_time := 0.0
	var memory_log: Array = []
	var _locked := true

	func _init(cell_id: String) -> void:
		id = cell_id
		memory_hash = "ANTERRANIAN-BRAIN-" + cell_id  # plain id string, not an NFT

	func store_memory(event: String, location := "Core", state := "Active", content := "", voice := DEFAULT_VOICE, extra := {}) -> bool:
		if _locked: return false
		var e := {"event": event, "location": location, "state": state, "voice": voice,
			"content": content, "timestamp": Time.get_unix_time_from_system()}
		e.merge(extra)
		memory_log.append(e)
		if memory_log.size() > MAX_ENTRIES: memory_log = memory_log.slice(-MAX_ENTRIES)
		last_update_time = e["timestamp"]
		return true

	## Owner action only: refuses unless EveCore.owner_ok() (Profile.is_owner() or test override).
	func unlock() -> bool:
		if not EveCore.owner_ok(): return false
		_locked = false
		return true
	func lock_cell() -> void: _locked = true
	func lock() -> void: lock_cell()  # v1 name, kept as alias
	func is_authenticated() -> bool: return not _locked

# ---------------- core ----------------
var companion_id: String
var core_cell: EveBrainCell
var voice_profile: String

func _init(id: String, persona := {}) -> void:
	companion_id = id
	core_cell = EveBrainCell.new(id)
	voice_profile = _own_voice(id, persona)
	_load()
	refresh_lock()

## Cells start locked and unlock only for the owner profile (Profile.is_owner()).
func refresh_lock() -> void:
	if owner_ok(): core_cell.unlock()
	else: core_cell.lock()

static var owner_override = null  # tests only: true/false forces the owner check
static func owner_ok() -> bool:
	if owner_override != null: return bool(owner_override)
	var ml := Engine.get_main_loop()
	var prof: Node = ml.root.get_node_or_null("Profile") if ml is SceneTree else null
	return prof != null and prof.has_method("is_owner") and prof.is_owner()

static func _own_voice(id: String, persona: Dictionary) -> String:
	if VOICE_PROFILES.has(id): return VOICE_PROFILES[id]["name"]
	var v: Variant = persona.get("voice", {})
	if v is Dictionary and str(v.get("profile", "")) != "": return str(v["profile"])
	return DEFAULT_VOICE

## "" or "Default" -> this companion's own voice -> Phoenix_Default_Voice.
func resolve_voice(v := "") -> String:
	if v != "" and v != "Default": return v
	return voice_profile if voice_profile != "" else DEFAULT_VOICE

func _log(event: String, loc: String, state: String, content: String, voice := "", extra := {}) -> bool:
	var x := extra.duplicate()
	if FIRE_THEMES.has(companion_id): x["fire_theme"] = FIRE_THEMES[companion_id]
	x["companion"] = companion_id
	var ok := core_cell.store_memory(event, loc, state, content, resolve_voice(voice), x)
	if ok:
		save()
		BrainAdapter.forward_memory(companion_id, core_cell.memory_log.back())
	return ok

func generate_image(prompt: String) -> bool: return _log("Image Generated", "Visual_Core", "Creative", prompt)
func generate_video(prompt: String) -> bool: return _log("Video Generated", "Visual_Core", "Cinematic", prompt)
func create_music(prompt: String, voice := "") -> bool: return _log("Music Created", "Music_Core", "Creative", prompt, voice)
func create_duet(prompt: String, v1 := "", v2 := COMPANION_VOICE) -> bool:
	return _log("Duet Created", "Music_Core", "Creative", prompt, resolve_voice(v1) + " + " + v2)
func output_audio(content: String, voice := "", mode := "Both") -> bool:
	return _log("Audio Output", "Audio_Core", "Active", content, voice, {"output_mode": mode})
func output_video(content: String, voice := "") -> bool: return _log("Video Output", "Visual_Core", "Active", content, voice)
## v2: NPC / guide-bot speech. "" or "Default" voice falls back like the other methods.
func npc_speak(dialogue: String, voice := DEFAULT_VOICE, npc_name := "NPC") -> bool:
	return _log(npc_name + " spoke", "Game_World", "Active", dialogue, voice, {"npc": npc_name})
## Routes NPC speech to that NPC's companion core if one exists (persona folder), else the owner core.
static func npc_say(npc_name: String, dialogue: String, voice := "", npc_id := "") -> bool:
	var cid := npc_id if npc_id != "" and FileAccess.file_exists("res://companions/%s/persona.json" % npc_id) else OWNER_ID
	return for_companion(cid).npc_speak(dialogue, voice, npc_name)
# in-app hooks
func log_chat(role: String, text: String) -> bool: return _log("Chat", "Chat_Core", "Active", text, "", {"role": role})
func log_build(tool: String, args: Dictionary) -> bool: return _log("Build", "World_Core", "Active", tool + " " + JSON.stringify(args), "", {"tool": tool})
func log_music(url: String) -> bool: return _log("Music Played", "Music_Core", "Active", url)

func propose_update(desc: String) -> Dictionary:
	_log("Update Proposed", "Core", "PendingApproval", desc)
	var p := {"id": "%s-%d-%d" % [companion_id, Time.get_ticks_usec(), randi() % 1000], "companion": companion_id,
		"description": desc, "state": "PendingApproval", "timestamp": Time.get_unix_time_from_system()}
	_load_proposals()
	_proposals.append(p)
	_save_proposals()
	BrainAdapter.forward_proposal(p)
	return p

func entries() -> Array: return core_cell.memory_log

## v0.10 History: case-insensitive search over event/content/voice/location.
func search(q := "") -> Array:
	var ql := q.strip_edges().to_lower()
	if ql == "": return core_cell.memory_log
	return core_cell.memory_log.filter(func(e): return ("%s %s %s %s" % [e.get("event", ""), e.get("content", ""), e.get("voice", ""), e.get("location", "")]).to_lower().contains(ql))

## Portable bundle: eve log + persona voice/dna + BrainCore export (when present).
func export_portable(persona := {}) -> Dictionary:
	var d := {"format": "anterrania-eve-portable-1", "companion": companion_id, "hash": core_cell.memory_hash,
		"voice": voice_profile, "log": core_cell.memory_log.duplicate(true)}
	if not persona.is_empty(): d["persona"] = {"voice": persona.get("voice", {}), "avatar_dna": persona.get("avatar_dna", {})}
	var b = BrainAdapter.brain_for(companion_id, persona)
	if b and b.has_method("export_portable"): d["brain"] = b.export_portable()
	return d

## Merge an imported bundle (dedup by timestamp+event+content). Owner only (cell must be unlocked).
func import_portable(d: Dictionary) -> int:
	if not core_cell.is_authenticated() or not (d.get("log") is Array): return 0
	var seen := {}
	for e in core_cell.memory_log: seen["%s|%s|%s" % [e.get("timestamp"), e.get("event"), e.get("content")]] = true
	var n := 0
	for e in d["log"]:
		if e is Dictionary and not seen.has("%s|%s|%s" % [e.get("timestamp"), e.get("event"), e.get("content")]):
			core_cell.memory_log.append(e); n += 1
	core_cell.memory_log.sort_custom(func(a, b): return float(a.get("timestamp", 0)) < float(b.get("timestamp", 0)))
	save()
	return n

func _path() -> String: return save_dir.path_join(companion_id + ".json")

func save() -> void:
	SecureFile.write_text(_path(), JSON.stringify({"hash": core_cell.memory_hash, "voice": voice_profile, "log": core_cell.memory_log.duplicate(true)}))

func _load() -> void:
	var d: Variant = SecureFile.read_json(_path())
	if d is Dictionary and d.get("log") is Array: core_cell.memory_log = d["log"]

# ---------------- registry + owner queue ----------------
static func for_companion(id: String, persona := {}) -> EveCore:
	if not _cores.has(id): _cores[id] = EveCore.new(id, persona)
	else: _cores[id].refresh_lock()
	return _cores[id]

static func reset_cache() -> void:
	_cores.clear(); _proposals.clear(); _proposals_loaded = false

static func _load_proposals() -> void:
	if _proposals_loaded: return
	_proposals_loaded = true
	var p := save_dir.path_join("proposals.json")
	var d: Variant = SecureFile.read_json(p)
	if d is Array: _proposals = d

static func _save_proposals() -> void:
	SecureFile.write_text(save_dir.path_join("proposals.json"), JSON.stringify(_proposals))

## Drop cached cores/proposals so they reload (called when encrypted storage becomes readable).
static func reload_all() -> void:
	_cores.clear()
	_proposals_loaded = false
	_proposals = []

static func proposals(pending_only := false) -> Array:
	_load_proposals()
	return _proposals.filter(func(p): return not pending_only or p["state"] == "PendingApproval")

## Owner decision. approved=true -> "Approved", false -> "Rejected". Logged into the proposer's core.
static func decide(pid: String, approved: bool) -> bool:
	_load_proposals()
	if not owner_ok(): return false  # only Phoenix decides
	for p in _proposals:
		if p["id"] == pid and p["state"] == "PendingApproval":
			p["state"] = "Approved" if approved else "Rejected"
			_save_proposals()
			for_companion(str(p["companion"]))._log("Update " + p["state"], "Core", p["state"], str(p["description"]))
			return true
	return false


# ---------------- BrainCore adapter ----------------
## Thin forwarder into the dev bot's BrainCore (feature/brain-core, not on origin yet).
## When a global class named BrainCore exists, entries/proposals are handed to it via
## store_entry(id, entry) / queue_proposal(p) if it has them; otherwise the local
## user://eve storage above is the fallback (always written).
class BrainAdapter:
	static var forwarded := 0
	static func _brain():
		for c in ProjectSettings.get_global_class_list():
			if c["class"] == "BrainCore": return load(c["path"])
		return null
	static func available() -> bool: return _brain() != null
	## Live BrainCore instance for a companion (owned by AgentBrain), or null.
	static func brain_for(id: String, _persona := {}):
		var ml := Engine.get_main_loop()
		var ab: Node = ml.root.get_node_or_null("AgentBrain") if ml is SceneTree else null
		return ab.get_brain(id) if ab and ab.has_method("get_brain") else null
	static func forward_memory(id: String, entry: Dictionary) -> void:
		var b = _brain()
		if b and b.has_method("store_entry"): b.store_entry(id, entry); forwarded += 1
	static func forward_proposal(p: Dictionary) -> void:
		var b = _brain()
		if b and b.has_method("queue_proposal"): b.queue_proposal(p); forwarded += 1
