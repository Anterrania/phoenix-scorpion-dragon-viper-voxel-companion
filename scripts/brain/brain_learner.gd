class_name BrainLearner
extends RefCounted
## Turns experience (episodes.jsonl) into SAFE brain-cell proposals. Pure data in, data out.
## - "feedback" episodes -> bounded weight reinforcement (auto, logged, rollback-able)
## - "taught" episodes ("when I say X, reply Y") -> low-risk say cell proposal (pending by default)
## - repeated "keyword -> successful tool" pattern (>= PATTERN_MIN times) -> high-risk tool proposal (always pending)
## Never generates or runs code.

const PATTERN_MIN := 3
const STOPWORDS := ["the", "a", "an", "and", "you", "me", "please", "can", "could", "now", "here", "there", "it", "to", "of", "i", "my", "for", "make", "let", "lets", "get", "put", "want", "just", "some", "this", "that", "with", "what", "your", "are", "yes", "okay"]

## via_owner = true: proposals go to the owner's EveCore queue (MENU > Proposals) instead of the local pending/ folder.
static func learn(brain: BrainCore, last_n := 200, auto_apply_low_risk := false, via_owner := false) -> Dictionary:
	var report := {"reinforced": 0, "proposed": [], "skipped": []}
	var eps := brain.memory.episodes(last_n)
	var last_chat := ""
	var pairs := {}   # "keyword|tool" -> {count, args}
	for e in eps:
		match e.get("kind", ""):
			"feedback":
				if brain.reinforce(str(e.get("cell_id", "")), float(e.get("reward", 0.0))):
					report["reinforced"] += 1
			"taught":
				var when := str(e.get("when", "")).to_lower().strip_edges()
				var reply := str(e.get("reply", "")).strip_edges()
				if when == "" or reply == "": continue
				var id := _slug("taught_" + when)
				if brain.cells.has(id): continue
				var cell := BrainCell.make(id, brain.companion_id, {"type": "chat_keyword", "any": [when]},
					{"type": "say", "text": reply}, 0.7, "self_proposed", "player taught a reply")
				var why := "player taught: when '%s'" % when
				_push(report, id, brain.propose_to_owner(cell, why) if via_owner else brain.propose(cell, why, auto_apply_low_risk))
			"chat":
				last_chat = str(e.get("text", "")).to_lower()
			"tool":
				if e.get("ok", false) and last_chat != "":
					for w in _keywords(last_chat):
						var k := "%s|%s" % [w, e.get("name", "")]
						var p: Dictionary = pairs.get(k, {"count": 0, "args": e.get("args", {})})
						p["count"] += 1
						pairs[k] = p
	for k in pairs:
		if pairs[k]["count"] < PATTERN_MIN: continue
		var parts: PackedStringArray = k.split("|")
		var id := _slug("auto_%s_%s" % [parts[0], parts[1]])
		if brain.cells.has(id): continue
		var cell := BrainCell.make(id, brain.companion_id, {"type": "chat_keyword", "any": [parts[0]]},
			{"type": "tool", "name": parts[1], "args": pairs[k]["args"] if pairs[k]["args"] is Dictionary else {}},
			0.5, "self_proposed", "seen '%s' -> %s %d times" % [parts[0], parts[1], pairs[k]["count"]])
		var reason: String = cell["provenance"]["reason"]
		_push(report, id, brain.propose_to_owner(cell, reason) if via_owner else brain.propose(cell, reason))
	return report

static func _push(report: Dictionary, id: String, r: Dictionary) -> void:
	if r.get("ok"): report["proposed"].append({"id": id, "status": r["status"]})
	else: report["skipped"].append({"id": id, "error": r.get("error", "")})

static func _keywords(text: String) -> Array:
	var out: Array = []
	for w in text.replace(",", " ").replace(".", " ").replace("!", " ").replace("?", " ").split(" ", false):
		if w.length() >= 3 and w not in STOPWORDS and w not in out: out.append(w)
	return out

static func _slug(s: String) -> String:
	var re := RegEx.create_from_string("[^a-z0-9_]+")
	return re.sub(s.to_lower().replace(" ", "_"), "", true).left(48)
