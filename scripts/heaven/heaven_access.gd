class_name HeavenAccess
extends RefCounted
## HEAVEN-2: who may FLY and who may use STUDIO (build / terraform) tools inside Heaven.
## Rule (Phoenix, 2026-10-30): flying in Heaven is for the owner and the members the owner grants,
## nobody else. Everyone else walks, takes Hub transit or (phase 2) a vehicle. Studio tools in Heaven
## follow the same rule with their own grant list. Estate managers are NOT granted automatically.
## Grants live in user://heaven/access.json through SecureFile (sealed while the vault is locked),
## and only an UNLOCKED owner session can change them (Tiers.tier_of(actor) == "owner").
## File: {"fly": {member: {"by", "at"}}, "studio": {...}, "build": {...}, "log": [{at, by, kind, member, op}]}

const KINDS := ["fly", "studio", "build"]   # build = standing grant: a companion's Heaven edits apply without per-edit approval
const LOG_MAX := 200
static var root := "user://heaven"
static var _a = null

static func _path() -> String: return root.path_join("access.json")

static func _all() -> Dictionary:
	if _a == null:
		var d: Variant = SecureFile.read_json(_path(), {})
		_a = d if d is Dictionary else {}
		for k in KINDS + ["log"]:
			if not _a.has(k): _a[k] = [] if k == "log" else {}
	return _a

static func is_owner(actor: Variant) -> bool: return Tiers.tier_of(actor) == "owner"

static func granted(kind: String, member: String) -> bool:
	return kind in KINDS and _all()[kind].has(member)

static func can_fly(actor: Variant) -> bool:
	return is_owner(actor) or granted("fly", Tiers.actor_id(actor))

static func can_studio(actor: Variant) -> bool:
	return is_owner(actor) or granted("studio", Tiers.actor_id(actor))

## Standing build grant (HEAVEN-6): edits proposed by this member apply at once (still logged).
static func can_autobuild(actor: Variant) -> bool:
	return is_owner(actor) or granted("build", Tiers.actor_id(actor))

static func members(kind: String) -> Array:
	if not kind in KINDS: return []
	var out: Array = _all()[kind].keys()
	out.sort()
	return out

## Owner grants `member` the right `kind`. "" on success, else a short reason.
static func grant(actor: Variant, kind: String, member: String, now := 0) -> String:
	return _change(actor, kind, member, true, now)

static func revoke(actor: Variant, kind: String, member: String, now := 0) -> String:
	return _change(actor, kind, member, false, now)

## One tap: grant the same right to several members (e.g. "my companions").
static func grant_many(actor: Variant, kind: String, list: Array, now := 0) -> String:
	for m in list:
		var err := grant(actor, kind, str(m), now)
		if err != "" and err != "Already granted.": return err
	return ""

static func _change(actor: Variant, kind: String, member: String, on: bool, now: int) -> String:
	if not is_owner(actor): return "Only the owner (unlocked) can change Heaven access."
	if not kind in KINDS: return "Unknown right."
	member = member.strip_edges()
	if member == "" or member.length() > 64: return "Member id needed."
	if member == Tiers.OWNER_ID or member == Tiers.SELF: return "The owner always has this right."
	var d: Dictionary = _all()[kind]
	if on and d.has(member): return "Already granted."
	if not on and not d.has(member): return "Not granted."
	if on: d[member] = {"by": Tiers.actor_id(actor), "at": now}
	else: d.erase(member)
	var hist: Array = _all()["log"]
	hist.append({"at": now, "by": Tiers.actor_id(actor), "kind": kind, "member": member, "op": "grant" if on else "revoke"})
	while hist.size() > LOG_MAX: hist.pop_front()
	if not SecureFile.write_json(_path(), _all()):
		_a = null   # reload the sealed copy: the change did not stick
		return "Saves are sealed. Unlock first."
	return ""

static func log_entries() -> Array: return _all()["log"]

static func reset_for_tests(dir := "") -> void:
	if dir != "": root = dir
	_a = null
