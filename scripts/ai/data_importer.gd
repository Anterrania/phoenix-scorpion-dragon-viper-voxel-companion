# Data importers: bring the user's OWN existing info into companion memory.
# These are NOT reasoning backends. Only LocalProvider + GrokProvider reason (ai_provider.gd).
# Each import needs explicit user consent, a preview, and per-item accept/reject.
# Input is a file the user exported themselves. No live API calls. NOT yet run in Godot.
class_name DataImporter
extends RefCounted

enum Source { COPILOT, GEMINI, META_AI, GENERIC_TEXT }

signal preview_ready(items: Array) # Array of {text, source, timestamp, selected}

var source: Source = Source.GENERIC_TEXT
var consent_given := false

func get_label() -> String:
	return ["Microsoft Copilot export", "Google Gemini export (Takeout)", "Meta AI export", "Text/JSON file"][source]

## Parse a user-chosen export file into candidate facts. Writes nothing.
func parse_export(path: String) -> void:
	if not consent_given or not FileAccess.file_exists(path):
		preview_ready.emit([]); return
	var items: Array = []
	# TODO: per-source parsers (export formats vary; verify before implementing).
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var t := line.strip_edges()
		if t != "":
			items.append({"text": t.left(500), "source": get_label(), "timestamp": "", "selected": true})
	preview_ready.emit(items)

## After user review: append accepted items to the companion's brain facts.jsonl.
func commit(companion_id: String, items: Array) -> int:
	var path := "user://brains/%s/memory/facts.jsonl" % companion_id
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null: return 0
	f.seek_end()
	var n := 0
	for it in items:
		if it.get("selected", false):
			f.store_line(JSON.stringify({"t": Time.get_datetime_string_from_system(), "text": it.text, "source": it.source, "weight": 0.5}))
			n += 1
	return n
