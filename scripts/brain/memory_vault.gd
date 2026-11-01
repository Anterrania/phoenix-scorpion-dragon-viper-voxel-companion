class_name MemoryVault
extends RefCounted
## v0.13 BRAIN-VAULT: the Brain Cell memory core. Versioned and append-only.
##
## - A memory has a topic key. Writing to a key never replaces it: a NEW version is appended and the
##   older versions stay on disk as the archive (history() returns all of them, oldest first).
## - There is no delete, edit or overwrite function in this class, by design.
## - Who may write:
##     "system": the app's own recorder (chat turns, remember-tool mirror, scene notes). Append only.
##     "owner":  needs the unlocked owner session (Tiers.owner_session()).
##     "ai":     refused while the vault is locked, which is the default. Only the unlocked owner can open
##               a time-limited AI write window (owner_unlock_ai). Even then the AI can only append.
## - The AI can read its own memories (current / history / recall) but can't change how the vault works:
##   this file is code, and companions have no tool that edits code or this store.
## - Simple redaction keeps card numbers, emails and passwords out (same rule as BrainMemory).
## Storage: <root>/<companion>/vault.jsonl through SecureFile (encrypted once an OwnerVault exists).

const ACTORS := ["system", "owner", "ai"]
const MAX_TEXT := 400
const MAX_VERSIONS_READ := 5000
const STOP := ["the", "a", "an", "is", "are", "was", "to", "of", "and", "in", "on", "for", "my", "your", "i", "you", "it", "that", "this", "with", "be", "at", "me"]
const REDACT_PATTERNS := ["\\b\\d{12,19}\\b", "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "(?i)\\b(password|passcode|ssn|iban|routing number)\\b"]

static var root := "user://brain_core/vault"
static var _ai_until := 0        # unix seconds; 0 = locked
static var _cache := {}          # companion -> Array of versions
static var _redact: Array = []

static func _safe(id: String) -> bool: return RegEx.create_from_string("^[a-z0-9_\\-]{1,64}$").search(id) != null
static func _path(cid: String) -> String: return root.path_join(cid).path_join("vault.jsonl")

static func is_sensitive(text: String) -> bool:
	if _redact.is_empty():
		for p in REDACT_PATTERNS: _redact.append(RegEx.create_from_string(p))
	for r in _redact:
		if (r as RegEx).search(text) != null: return true
	return false

# ---------- lock ----------
static func ai_locked(now := 0) -> bool:
	var t := now if now > 0 else int(Time.get_unix_time_from_system())
	return t >= _ai_until

## Owner only: let companions append memories for `seconds` (max one day). Returns "" or an error.
static func owner_unlock_ai(seconds := 600, now := 0) -> String:
	if not Tiers.owner_session(): return "Owner unlock needed."
	var t := now if now > 0 else int(Time.get_unix_time_from_system())
	_ai_until = t + clampi(seconds, 1, 86400)
	return ""

## Anyone (including a companion) may LOCK; only the owner can unlock.
static func lock() -> void: _ai_until = 0

static func can_write(actor: String, now := 0) -> String:
	if not actor in ACTORS: return "Unknown writer."
	if actor == "owner" and not Tiers.owner_session(): return "Owner unlock needed."
	if actor == "ai" and ai_locked(now): return "The Brain Cell is locked. Only the owner can open it."
	return ""

# ---------- topics ----------
## "Phoenix likes gold dragons" -> "phoenix_likes". Same subject + verb = same memory, new version.
static func topic_of(text: String) -> String:
	var words := PackedStringArray()
	for w in text.to_lower().split(" ", false):
		var c := ""
		for ch in w:
			if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"): c += ch
		if c != "" and not c in STOP: words.append(c)
		if words.size() == 2: break
	return "_".join(words) if not words.is_empty() else "note"

# ---------- read ----------
static func _all(cid: String) -> Array:
	if _cache.has(cid): return _cache[cid]
	var out: Array = []
	for line in SecureFile.read_text(_path(cid)).split("\n", false):
		var d: Variant = JSON.parse_string(line)
		if d is Dictionary: out.append(d)
	_cache[cid] = out.slice(-MAX_VERSIONS_READ)
	return _cache[cid]

static func history(cid: String, key: String) -> Array:
	return _all(cid).filter(func(v): return str(v.get("key", "")) == key)

static func current(cid: String, key: String) -> Dictionary:
	var h := history(cid, key)
	return h.back() if not h.is_empty() else {}

static func archived(cid: String, key: String) -> Array:
	var h := history(cid, key)
	return h.slice(0, maxi(0, h.size() - 1))

static func keys(cid: String) -> Array:
	var seen := {}
	for v in _all(cid): seen[str(v.get("key", ""))] = true
	return seen.keys()

## Latest version of every key, newest first.
static func all_current(cid: String) -> Array:
	var latest := {}
	for v in _all(cid): latest[str(v.get("key", ""))] = v
	var out: Array = latest.values()
	out.sort_custom(func(a, b): return int(a.get("n", 0)) > int(b.get("n", 0)))
	return out

static func count(cid: String) -> int: return _all(cid).size()

# ---------- write (append only) ----------
## Append a new version of `key` (key "" = topic_of(text)). Returns {ok, key, version} or {error}.
static func remember(cid: String, text: String, actor := "system", key := "", source := "", now := 0) -> Dictionary:
	if not _safe(cid): return {"error": "Bad companion id."}
	var why := can_write(actor, now)
	if why != "": return {"error": why}
	text = text.strip_edges().left(MAX_TEXT)
	if text == "": return {"error": "Empty memory."}
	if is_sensitive(text): return {"error": "Private or financial details are not stored."}
	var k := key if key != "" else topic_of(text)
	var prior := current(cid, k)
	if not prior.is_empty() and str(prior.get("text", "")) == text: return {"ok": true, "key": k, "version": int(prior["v"]), "unchanged": true}
	var rows := _all(cid)
	var rec := {"n": rows.size(), "key": k, "v": int(prior.get("v", 0)) + 1, "text": text, "actor": actor,
		"source": source.left(40), "t": Time.get_datetime_string_from_system(true),
		"supersedes": int(prior.get("v", 0))}
	rows.append(rec)
	var lines := PackedStringArray()
	for r in rows: lines.append(JSON.stringify(r))
	DirAccess.make_dir_recursive_absolute(_path(cid).get_base_dir())
	if not SecureFile.write_text(_path(cid), "\n".join(lines) + "\n"):
		rows.pop_back()
		return {"error": "Saves are sealed. Unlock first."}
	InteractionLedger.append("memory", cid, {"key": k, "v": rec["v"], "actor": actor})
	return {"ok": true, "key": k, "version": rec["v"]}

static func reset_for_tests(r := "user://brain_core_test/vault") -> void:
	root = r; _ai_until = 0; _cache = {}
	if DirAccess.dir_exists_absolute(r):
		for d in DirAccess.get_directories_at(r):
			for f in DirAccess.get_files_at(r.path_join(d)): DirAccess.remove_absolute(r.path_join(d).path_join(f))
