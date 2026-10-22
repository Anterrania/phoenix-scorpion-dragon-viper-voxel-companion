class_name Restrictions
extends RefCounted
## Viewer parity (VIEWER-4): an RLV-style restriction API, minimal and safety-first.
## Decision record: docs/modules/RESTRICTIONS.md. Concepts only (RLV/RLVa are viewer features; no
## code or command syntax copied).
##
## What it is: a consenting adult lets a source they chose (a person, or an object they own) switch
## off a few of THEIR OWN abilities for a while, e.g. flying or teleporting to landmarks. Nothing else.
## Hard rules:
##   - Off by default. A subject opts in (enable) and confirms they are 18+ each time they enable.
##   - Per-source consent: only sources the subject listed can add restrictions. Revoking clears them.
##   - Prevent-only: no forced actions (no forced teleport, sit, attach/detach, outfit changes, chat).
##   - Short: every restriction expires (MAX_MINUTES). Active restrictions are session-only.
##   - Safeword: the subject can always clear everything on themselves, even while locked.
##   - Companions: only the unlocked owner can enable or consent for a companion.
##   - Owner override: the unlocked owner can clear anyone's restrictions and switch the API off.
##   - E-stop (AutonomyGuard.paused()): every restriction is suspended and no new ones can be added.
##   - NEVER list: safety and owner controls can never be restricted (see NEVER).
##   - Sources need Tiers.can(source, "message") (Resident and up, not a paused bot).
## Consumers (Foxy's HUD: fly button, landmark teleports, minimap, ...) only ever call
## is_restricted(subject, behaviour). Nothing is wired yet; see VIEWER_PARITY.md.

const BEHAVIOURS := {
	"fly": "Flying", "tplm": "Teleport to landmarks", "tploc": "Teleport from the map",
	"sendchat": "Nearby chat (typing)", "sendim": "Sending IMs", "rez": "Rezzing objects",
	"edit": "Editing objects", "showinv": "Opening inventory", "showminimap": "Minimap",
	"showworldmap": "World map", "showloc": "Seeing the location name", "shownames": "Name tags",
	"unsit": "Standing up", "fartouch": "Touching far objects",
}
## Can never be restricted, whatever is asked.
const NEVER := ["safeword", "estop", "owner_unlock", "admin", "security", "report", "block", "mute",
	"settings", "exit_app", "help", "emergency"]
const MAX_MINUTES := 240
const DEFAULT_MINUTES := 60
const MAX_ACTIVE := 32

static var root := "user://security"
static var _db = null
static var _active := {}   # subject -> [{"source", "behaviour", "until"}]

static func _path() -> String: return root.path_join("restrictions.json")
static func _now() -> int: return int(Time.get_unix_time_from_system())

static func db() -> Dictionary:
	if _db == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_db = d if d is Dictionary else {}
		if not _db.has("subjects"): _db["subjects"] = {}
		if not _db.has("global_off"): _db["global_off"] = false
	return _db

static func _save(snap: Dictionary) -> String:
	if SecureFile.write_json(_path(), db()): return ""
	_db = snap
	return "Saves are sealed. Unlock first."

static func _owner(actor: Variant) -> bool: return Tiers.tier_of(actor) == "owner"

## Who may opt a subject in or out, or manage its consent list.
static func _may_manage(actor: Variant, subject: String) -> String:
	var me := Tiers.actor_id(actor)
	if subject == "": return "Pick who."
	if Tiers.is_bot(subject): return "" if _owner(actor) else "Only you (unlocked) can decide for a companion."
	if subject == Tiers.OWNER_ID: return "" if _owner(actor) else "Owner unlock needed."
	if subject != me: return "People decide this for themselves."
	return "" if Tiers.can(actor, "message") else "Residents only."

static func global_off() -> bool: return bool(db()["global_off"])
static func suspended() -> bool: return global_off() or AutonomyGuard.paused()

static func enabled(subject: String) -> bool:
	return bool(db()["subjects"].get(subject, {}).get("enabled", false))

static func enable(actor: Variant, subject: String, adult_confirmed: bool) -> String:
	if global_off(): return "Restrictions are switched off."
	if not adult_confirmed: return "Adults only: confirm you are 18 or older."
	var e := _may_manage(actor, subject)
	if e != "": return e
	var snap: Dictionary = db().duplicate(true)
	var s: Dictionary = db()["subjects"].get(subject, {"consent": []})
	s["enabled"] = true; s["adult"] = true; s["enabled_at"] = _now()
	db()["subjects"][subject] = s
	return _save(snap)

static func disable(actor: Variant, subject: String) -> String:
	if Tiers.actor_id(actor) != subject and not _owner(actor):
		var e := _may_manage(actor, subject)
		if e != "": return e
	_active.erase(subject)
	var snap: Dictionary = db().duplicate(true)
	var s: Dictionary = db()["subjects"].get(subject, {})
	s["enabled"] = false
	db()["subjects"][subject] = s
	return _save(snap)

static func consents(subject: String) -> Array: return (db()["subjects"].get(subject, {}).get("consent", []) as Array).duplicate()

static func consent(actor: Variant, subject: String, source: String) -> String:
	var e := _may_manage(actor, subject)
	if e != "": return e
	source = source.strip_edges()
	if source == "" or source == subject: return "Pick someone else."
	var snap: Dictionary = db().duplicate(true)
	var s: Dictionary = db()["subjects"].get(subject, {"enabled": false})
	var c: Array = s.get("consent", [])
	if not source in c: c.append(source)
	s["consent"] = c
	db()["subjects"][subject] = s
	return _save(snap)

## Revoking always works for the subject themselves (no tier needed) and clears that source's restrictions.
static func revoke(actor: Variant, subject: String, source: String) -> String:
	if Tiers.actor_id(actor) != subject and not _owner(actor):
		var e := _may_manage(actor, subject)
		if e != "": return e
	_active[subject] = _active.get(subject, []).filter(func(r): return r["source"] != source)
	var snap: Dictionary = db().duplicate(true)
	var s: Dictionary = db()["subjects"].get(subject, {})
	s["consent"] = (s.get("consent", []) as Array).filter(func(x): return x != source)
	db()["subjects"][subject] = s
	return _save(snap)

## Returns "" on success or why it was refused.
static func add(source: Variant, subject: String, behaviour: String, minutes := DEFAULT_MINUTES) -> String:
	var src := Tiers.actor_id(source)
	if behaviour in NEVER or not BEHAVIOURS.has(behaviour): return "That can't be restricted."
	if AutonomyGuard.paused(): return "Emergency stop is on."
	if global_off(): return "Restrictions are switched off."
	if not enabled(subject): return "They haven't opted in."
	if not src in consents(subject): return "They haven't allowed you."
	if not Tiers.can(source, "message"): return "Your tier can't do this."
	var l: Array = _prune(subject)
	if l.size() >= MAX_ACTIVE: return "Too many restrictions."
	var until := _now() + clampi(minutes, 1, MAX_MINUTES) * 60
	l = l.filter(func(r): return not (r["source"] == src and r["behaviour"] == behaviour))
	l.append({"source": src, "behaviour": behaviour, "until": until})
	_active[subject] = l
	return ""

static func remove(source: Variant, subject: String, behaviour: String) -> void:
	var src := Tiers.actor_id(source)
	_active[subject] = _active.get(subject, []).filter(func(r): return not (r["source"] == src and r["behaviour"] == behaviour))

static func _prune(subject: String) -> Array:
	var now := _now()
	var l: Array = _active.get(subject, []).filter(func(r): return int(r["until"]) > now)
	_active[subject] = l
	return l

## The only call consumers make. False whenever anything is off, suspended or not consented.
static func is_restricted(subject: String, behaviour: String) -> bool:
	if behaviour in NEVER or suspended() or not enabled(subject): return false
	var cs := consents(subject)
	for r in _prune(subject):
		if r["behaviour"] == behaviour and r["source"] in cs: return true
	return false

static func active(subject: String) -> Array:
	if suspended(): return []
	return _prune(subject).duplicate(true)

## Safeword: always works for the subject, locked or not, no tier needed.
static func safeword(actor: Variant) -> int:
	var me := Tiers.actor_id(actor)
	var n: int = _active.get(me, []).size()
	_active.erase(me)
	return n

## Owner override: clear everyone's restrictions. Needs the owner unlock.
static func owner_clear_all(actor: Variant) -> String:
	if not _owner(actor): return "Owner unlock needed."
	_active.clear()
	return ""

## Owner switch for the whole API. Switching off also clears everything.
static func set_global_off(actor: Variant, off: bool) -> String:
	if not _owner(actor): return "Owner unlock needed."
	if off: _active.clear()
	var snap: Dictionary = db().duplicate(true)
	db()["global_off"] = off
	return _save(snap)

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _db = null; _active = {}
