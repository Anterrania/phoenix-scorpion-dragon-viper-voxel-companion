class_name InteractionLedger
extends RefCounted
## v0.13 BRAIN-LEDGER: an append-only, hash-chained interaction log on this device.
## It is "Bitcoin-style" only in the sense that every block carries the SHA-256 of the block before it,
## so editing, removing or reordering any old block breaks verify(). There are NO coins, tokens, wallets,
## mining, network peers or real cryptocurrency here (LegalReview "nft_blockchain" stays HARD).
##
## Each interaction becomes one "Anterranian record" with two views of the same block:
##   - wiki:   the exact chat transcript plus in-world metadata (companion, realm, mood words).
##   - replay: ids of the in-world scene snapshots around it (SceneSnapshots), so the app can re-stage
##             the moment from world state. It never holds camera, microphone or screen recordings.
##
## Block on disk (one JSON object per line):
##   {"i": int, "prev": hex64, "hash": hex64, "body": "<canonical JSON string>"}
## hash = sha256(prev + body). The body is kept as a string so the hash never depends on how JSON
## numbers round-trip (Godot parses every number as float).
## Segments of SEGMENT_SIZE blocks (ledger_0000.jsonl, ledger_0001.jsonl, ...) keep each write small;
## the chain runs straight across segments. Nothing here deletes or rewrites an old block.

const GENESIS := "0000000000000000000000000000000000000000000000000000000000000000"
const SEGMENT_SIZE := 1000
const MAX_TEXT := 600
const KINDS := ["interaction", "scene", "memory", "system"]

static var root := "user://brain_core"
static var _seg := -1          # current segment index (-1 = not loaded)
static var _rows: Array = []   # blocks of the current segment
static var _count := 0         # total blocks across all segments
static var _head := GENESIS

static func _seg_path(n: int) -> String: return root.path_join("ledger_%04d.jsonl" % n)

static func _read_seg(n: int) -> Array:
	var out: Array = []
	for line in SecureFile.read_text(_seg_path(n)).split("\n", false):
		var d: Variant = JSON.parse_string(line)
		if d is Dictionary: out.append(d)
	return out

static func _load() -> void:
	if _seg >= 0: return
	DirAccess.make_dir_recursive_absolute(root)
	var n := 0
	_count = 0
	while SecureFile.exists(_seg_path(n + 1)):
		_count += SEGMENT_SIZE
		n += 1
	_seg = n
	_rows = _read_seg(n)
	_count += _rows.size()
	if not _rows.is_empty(): _head = str(_rows.back().get("hash", GENESIS))
	elif n > 0:
		var prev := _read_seg(n - 1)
		_head = str(prev.back().get("hash", GENESIS)) if not prev.is_empty() else GENESIS
	else: _head = GENESIS

static func length() -> int:
	_load()
	return _count

static func head_hash() -> String:
	_load()
	return _head

static func block_hash(prev: String, body: String) -> String: return (prev + body).sha256_text()

## Keep only plain values; long strings are cut; anything else becomes its string form.
static func clean(v: Variant, depth := 0) -> Variant:
	if depth > 4: return str(v).left(MAX_TEXT)
	if v is String or v is StringName: return str(v).left(MAX_TEXT)
	if v is bool or v is int: return v
	if v is float: return snappedf(v, 0.001)
	if v is Vector3 or v is Vector2: return str(v.round())
	if v is Dictionary:
		var d := {}
		for k in v: d[str(k)] = clean(v[k], depth + 1)
		return d
	if v is Array:
		var a: Array = []
		for x in (v as Array).slice(0, 64): a.append(clean(x, depth + 1))
		return a
	return str(v).left(MAX_TEXT)

## Append one block. Returns the stored block (with "body" parsed back in as "data"), or {"error"}.
static func append(kind: String, companion: String, data: Dictionary) -> Dictionary:
	if not kind in KINDS: return {"error": "unknown kind"}
	_load()
	var body := JSON.stringify({"kind": kind, "companion": companion.left(64), "t": Time.get_datetime_string_from_system(true),
		"data": clean(data)}, "", true)
	var block := {"i": _count, "prev": _head, "hash": block_hash(_head, body), "body": body}
	if _rows.size() >= SEGMENT_SIZE:
		_seg += 1
		_rows = []
	_rows.append(block)
	var lines := PackedStringArray()
	for r in _rows: lines.append(JSON.stringify(r))
	if not SecureFile.write_text(_seg_path(_seg), "\n".join(lines) + "\n"):
		_rows.pop_back()
		return {"error": "Saves are sealed. Unlock first."}
	_count += 1
	_head = block["hash"]
	var out := block.duplicate()
	out["data"] = JSON.parse_string(body)
	return out

## One chat turn -> one Anterranian record (wiki transcript + replay scene refs).
static func record_interaction(companion: String, user_text: String, reply: String, extra := {}) -> Dictionary:
	var wiki := {"transcript": [{"role": "user", "text": user_text}, {"role": "companion", "text": reply}]}
	for k in extra: wiki[k] = extra[k]
	return append("interaction", companion, {"wiki": wiki, "replay": {"scenes": SceneSnapshots.recent_ids(3)}})

## Walk every segment and re-hash. {ok, length, broken_at (-1 when ok), reason}
static func verify() -> Dictionary:
	_load()
	var prev := GENESIS
	var i := 0
	for n in range(0, _seg + 1):
		for b in _read_seg(n):
			if int(b.get("i", -1)) != i: return {"ok": false, "length": i, "broken_at": i, "reason": "index gap"}
			if str(b.get("prev", "")) != prev: return {"ok": false, "length": i, "broken_at": i, "reason": "chain link"}
			if block_hash(prev, str(b.get("body", ""))) != str(b.get("hash", "")): return {"ok": false, "length": i, "broken_at": i, "reason": "hash"}
			prev = str(b["hash"])
			i += 1
	return {"ok": true, "length": i, "broken_at": -1, "reason": ""}

## Parsed records, newest last. companion "" = all. Reads at most the last `segments` segments.
static func records(companion := "", kind := "", last_n := 200, segments := 2) -> Array:
	_load()
	var out: Array = []
	for n in range(maxi(0, _seg - segments + 1), _seg + 1):
		var rows := _rows if n == _seg else _read_seg(n)
		for b in rows:
			var d: Variant = JSON.parse_string(str(b.get("body", "")))
			if not (d is Dictionary): continue
			if companion != "" and str(d.get("companion", "")) != companion: continue
			if kind != "" and str(d.get("kind", "")) != kind: continue
			d["i"] = b.get("i", 0); d["hash"] = b.get("hash", "")
			out.append(d)
	return out.slice(-last_n)

static func reset_for_tests(r := "user://brain_core_test") -> void:
	root = r
	_seg = -1; _rows = []; _count = 0; _head = GENESIS
	if DirAccess.dir_exists_absolute(r):
		for f in DirAccess.get_files_at(r): DirAccess.remove_absolute(r.path_join(f))
