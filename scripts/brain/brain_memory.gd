class_name BrainMemory
extends RefCounted
## Append-only memory layer per companion: facts.jsonl (long-term) + episodes.jsonl (episodic log).
## Lives under <root>/<id>/memory/. Keep private/financial data OUT (simple redaction below).

const MAX_FACTS := 500
const MAX_EPISODES := 2000
const MAX_TEXT := 300
## Very small safety net, not a guarantee: drops lines that look like card numbers / long digit runs / emails.
const REDACT_PATTERNS := ["\\b\\d{12,19}\\b", "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "(?i)\\b(password|passcode|ssn|iban|routing number)\\b"]

var dir: String
var _redact: Array[RegEx] = []

func _init(root: String, companion_id: String) -> void:
	dir = root.path_join(companion_id).path_join("memory")
	DirAccess.make_dir_recursive_absolute(dir)
	for p in REDACT_PATTERNS:
		_redact.append(RegEx.create_from_string(p))

func is_sensitive(text: String) -> bool:
	for r in _redact:
		if r.search(text) != null: return true
	return false

func add_fact(text: String, source := "chat", weight := 0.5) -> bool:
	text = text.strip_edges().left(MAX_TEXT)
	if text == "" or is_sensitive(text): return false
	for f in facts():
		if f.get("text", "") == text: return false
	_append("facts.jsonl", {"t": Time.get_datetime_string_from_system(true), "text": text, "source": source, "weight": weight}, MAX_FACTS)
	return true

func log_episode(kind: String, data: Dictionary) -> void:
	var e := {"t": Time.get_datetime_string_from_system(true), "kind": kind}
	for k in data:
		var v: Variant = data[k]
		if v is String:
			if is_sensitive(v): v = "[redacted]"
			v = v.left(MAX_TEXT)
		e[k] = v
	_append("episodes.jsonl", e, MAX_EPISODES)

func facts() -> Array: return _read("facts.jsonl")
func episodes(last_n := 200) -> Array: return _read("episodes.jsonl").slice(-last_n)

func fact_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for f in facts(): out.append(str(f.get("text", "")))
	return out

func _read(file: String) -> Array:
	var p := dir.path_join(file)
	var out: Array = []
	if not FileAccess.file_exists(p): return out
	for line in FileAccess.get_file_as_string(p).split("\n", false):
		var d: Variant = JSON.parse_string(line)
		if d is Dictionary: out.append(d)
	return out

func _append(file: String, rec: Dictionary, cap: int) -> void:
	var p := dir.path_join(file)
	var rows := _read(file)
	rows.append(rec)
	if rows.size() > cap: rows = rows.slice(-cap)
	var f := FileAccess.open(p, FileAccess.WRITE)
	for r in rows: f.store_line(JSON.stringify(r))
