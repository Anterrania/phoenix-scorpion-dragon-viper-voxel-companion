class_name RevisionStore
extends RefCounted
## SVN-style global revision counter for in-app content: r1, r2, ... (monotonic, never reused).
## Every change to a ticket, wiki page, brain cell or world-edit summary is one revision with
## before/after snapshots (JSON-able), so log / diff / revert work uniformly.
## Files: <root>/revisions.jsonl (append-only log) + <root>/head.json ({"rev": N}).
## Reverting never rewrites history: it commits a NEW revision whose content is the old "before".
## Tamper-evident "lattice" chain: every record carries prev = SHA-256 of the previous record's exact
## stored line (genesis = 64 zeros); head.json keeps the hash of the last line, so edits, deletions,
## reordering or truncation are all detected by verify_chain(). Files are encrypted via SecureFile
## once an OwnerVault exists.

const KINDS := ["ticket", "wiki", "brain_cell", "world", "profile", "role"]
const MAX_SNAPSHOT := 32000

var root: String
var _head := 0
const GENESIS := "0000000000000000000000000000000000000000000000000000000000000000"
var _head_hash := GENESIS
var _lines = null   # cached raw lines (Array[String])
var _appliers := {}   # kind -> Array[Callable(path, content) -> bool], newest last; used by revert()

func _init(p_root := "user://viper") -> void:
	root = p_root
	DirAccess.make_dir_recursive_absolute(root)
	var d: Variant = SecureFile.read_json(root.path_join("head.json"))
	if d is Dictionary:
		_head = int(d.get("rev", 0))
		_head_hash = str(d.get("hash", GENESIS))

func head() -> int: return _head

## Local wall-clock time with offset, same shape as git's %aI ("2026-10-17T11:35:00-07:00"),
## so in-app revisions and exported commits sort and display in the same zone.
static func local_iso() -> String:
	var b := int(Time.get_time_zone_from_system().get("bias", 0))
	return "%s%s%02d:%02d" % [Time.get_datetime_string_from_system(false), "-" if b < 0 else "+", absi(b) / 60, absi(b) % 60]

## Register how a kind re-applies content on revert (TicketStore/WikiStore/brain adapters do this).
func register_applier(kind: String, apply: Callable) -> void:
	var arr: Array = _appliers.get(kind, [])
	arr = arr.filter(func(c: Callable): return c.is_valid() and c != apply)
	arr.append(apply)
	_appliers[kind] = arr

func _applier(kind: String) -> Callable:
	var arr: Array = _appliers.get(kind, [])
	for i in range(arr.size() - 1, -1, -1):
		if (arr[i] as Callable).is_valid(): return arr[i]
	return Callable()

## Record a change. Returns the new revision number (0 if rejected).
func commit(kind: String, path: String, before: Variant, after: Variant, message := "", author := "local") -> int:
	if kind not in KINDS or path == "" or path.length() > 200: return 0
	if JSON.stringify(after).length() > MAX_SNAPSHOT or JSON.stringify(before).length() > MAX_SNAPSHOT: return 0
	var lines := _raw_lines()
	_head += 1
	var rec := {"rev": _head, "t": local_iso(), "kind": kind, "path": path,
		"author": author.left(64), "message": message.left(300), "before": before, "after": after,
		"prev": CryptoBox.sha256_hex(lines.back()) if not lines.is_empty() else GENESIS}
	var line := JSON.stringify(rec)
	lines.append(line)
	if not SecureFile.write_text(root.path_join("revisions.jsonl"), "\n".join(lines) + "\n"):
		lines.pop_back(); _head -= 1
		return 0
	_head_hash = CryptoBox.sha256_hex(line)
	SecureFile.write_json(root.path_join("head.json"), {"rev": _head, "hash": _head_hash})
	return _head

func _raw_lines() -> Array:
	if _lines == null:
		_lines = Array(SecureFile.read_text(root.path_join("revisions.jsonl")).split("\n", false))
	return _lines

## Walk the lattice chain. {ok, count, legacy (unchained old records), broken_at (rev or 0), reason}
func verify_chain() -> Dictionary:
	_lines = null
	var lines := _raw_lines()
	var prev_hash := GENESIS
	var legacy := 0
	var chained := false
	for i in lines.size():
		var d: Variant = JSON.parse_string(lines[i])
		if not (d is Dictionary): return {"ok": false, "count": i, "legacy": legacy, "broken_at": i + 1, "reason": "unreadable line %d" % (i + 1)}
		if not d.has("prev"):
			if chained: return {"ok": false, "count": i, "legacy": legacy, "broken_at": int(d.get("rev", i + 1)), "reason": "unchained record after chain start"}
			legacy += 1
		else:
			var expect := prev_hash if (chained or i == 0) else CryptoBox.sha256_hex(lines[i - 1])
			if str(d["prev"]) != expect:
				return {"ok": false, "count": i, "legacy": legacy, "broken_at": int(d.get("rev", i + 1)), "reason": "hash mismatch before r%d" % int(d.get("rev", i + 1))}
			chained = true
		prev_hash = CryptoBox.sha256_hex(lines[i])
	var last := prev_hash if not lines.is_empty() else GENESIS
	if last != _head_hash and not (legacy == lines.size() and _head_hash == GENESIS):
		return {"ok": false, "count": lines.size(), "legacy": legacy, "broken_at": _head, "reason": "head hash mismatch (truncated or edited tail)"}
	return {"ok": true, "count": lines.size(), "legacy": legacy, "broken_at": 0, "reason": "", "head_hash": last}

func _all() -> Array:
	var out: Array = []
	for line in _raw_lines():
		var d: Variant = JSON.parse_string(line)
		if d is Dictionary: out.append(d)
	return out

## Newest first. Filter by path prefix (e.g. "wiki/WikiStart", "ticket/") and/or kind.
func history(path_prefix := "", kind := "", limit := 100) -> Array:
	var rows := _all().filter(func(r): return (path_prefix == "" or str(r["path"]).begins_with(path_prefix)) and (kind == "" or r["kind"] == kind))
	rows.reverse()
	return rows.slice(0, limit)

func get_rev(n: int) -> Dictionary:
	for r in _all():
		if int(r["rev"]) == n: return r
	return {}

## Content of `path` as of revision n (after applying n), or null if it didn't exist yet.
func content_at(path: String, n: int) -> Variant:
	var cur: Variant = null
	for r in _all():
		if int(r["rev"]) > n: break
		if r["path"] == path: cur = r["after"]
	return cur

## Unified-style line diff of revision n (before -> after).
func diff(n: int) -> String:
	var r := get_rev(n)
	if r.is_empty(): return ""
	return "--- %s (r%d before)\n+++ %s (r%d)\n%s" % [r["path"], n, r["path"], n, line_diff(_text(r["before"]), _text(r["after"]))]

static func _text(v: Variant) -> String:
	if v == null: return ""
	if v is String: return v
	return JSON.stringify(v, "  ", true)

## Small LCS line diff ("  " same, "- " removed, "+ " added). Fine for wiki pages / JSON snapshots.
static func line_diff(a: String, b: String) -> String:
	var x := a.split("\n")
	var y := b.split("\n")
	if x.size() * y.size() > 250000:
		return "- (%d lines)\n+ (%d lines)\n" % [x.size(), y.size()]
	var n := x.size(); var m := y.size()
	var L := []
	for i in n + 1:
		var row := PackedInt32Array(); row.resize(m + 1); L.append(row)
	for i in range(n - 1, -1, -1):
		for j in range(m - 1, -1, -1):
			L[i][j] = L[i + 1][j + 1] + 1 if x[i] == y[j] else maxi(L[i + 1][j], L[i][j + 1])
	var out := PackedStringArray()
	var i := 0; var j := 0
	while i < n and j < m:
		if x[i] == y[j]: out.append("  " + x[i]); i += 1; j += 1
		elif L[i + 1][j] >= L[i][j + 1]: out.append("- " + x[i]); i += 1
		else: out.append("+ " + y[j]); j += 1
	while i < n: out.append("- " + x[i]); i += 1
	while j < m: out.append("+ " + y[j]); j += 1
	return "\n".join(out)

## Revert revision n: re-apply its "before" through the kind's applier and record a new revision.
func revert(n: int, author := "local") -> int:
	if not AdminGate.ok(): return 0   # AUDIT-2: owner session only (reads stay open)
	var r := get_rev(n)
	if r.is_empty(): return 0
	var apply := _applier(r["kind"])
	if not apply.is_valid(): return 0
	var current: Variant = content_at(r["path"], _head)
	var ok: bool = apply.call(r["path"], r["before"])
	if not ok: return 0
	return commit(r["kind"], r["path"], current, r["before"], "Revert r%d: %s" % [n, r["message"]], author)
