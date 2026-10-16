class_name CannedReplies
extends RefCounted
## v0.5 offline companion replies built from persona.json. Add a "canned_replies"
## object to a persona ({"keyword": ["reply", ...]}) to customize (YOUR INPUT HERE).
## Live AI: Settings > AI mode "live" + API key routes chat to AgentBrain's LLM call.

const GENERIC := {
	"hello|hi|hey|yo": ["Hey, %s! Good to see you.", "Hi! I'm right here."],
	"who|name": ["I'm %n. %r"],
	"where|go|explore|landmark": ["Open MENU › Travel to jump to a landmark. Each one has a sign waiting for your ideas."],
	"build|make|create": ["Building arrives in v0.6. Tell me what you want built first and I'll remember it."],
	"outfit|wear|wardrobe|clothes|look": ["Tap BAG to dress me or yourself. Mature outfits stay locked unless you turn them on in Settings."],
	"love|thanks|thank": ["Always, %s. Rise from the flame.", "Anytime."],
	"help|what can|can": ["Ask me about landmarks, outfits, or the realms. Live AI chat can be switched on in Settings later."],
}

static func reply(persona: Dictionary, text: String, recap := "") -> String:
	var t := text.to_lower()
	if recap != "" and (t.find("what did you") >= 0 or t.find("been up") >= 0 or t.find("doing") >= 0):
		return recap
	var name := str(persona.get("name", "Companion"))
	var role := str(persona.get("role", ""))
	var custom: Variant = persona.get("canned_replies", {})
	var words := {}
	for w in t.replace("?", " ").replace("!", " ").replace(",", " ").replace(".", " ").split(" ", false): words[w] = true
	var tables: Array = [custom if custom is Dictionary else {}, GENERIC]
	for table in tables:
		for key in table:
			for w in str(key).split("|"):
				if w != "" and (words.has(w) or (w.contains(" ") and t.find(w) >= 0)):
					var opts: Array = table[key]
					return _fmt(str(opts[randi() % opts.size()]), name, role)
	var lines: Array = persona.get("game_lines", [])
	if lines.size() > 0: return str(lines[randi() % lines.size()])
	return "I'm still learning to talk here. (Offline reply)"

static func _fmt(s: String, name: String, role: String) -> String:
	return s.replace("%s", "Phoenix").replace("%n", name).replace("%r", role)
