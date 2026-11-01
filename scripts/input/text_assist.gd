class_name TextAssist
extends RefCounted
## v0.13.1 TYPE-1: auto-correct + suggestion repairs for text inputs.
## - autocorrect(text): fixes common typos / missing apostrophes, a lone "i", doubled words and spaces,
##   and (optionally) capitalizes sentence starts. Returns {text, fixes:[{from, to}]}.
## - attach(LineEdit): corrects the word you just finished (on space or punctuation); undo_last() puts it back.
##   Never touches secret fields (PIN, passphrase, keys), and skips anything that looks like a URL,
##   handle, email, number or code.
## - suggestions(text): repair chips the user can tap (never applied or sent on their own). The local
##   repair is always first; if ai_hook is set (the live/on-device model is configured) its suggestion is
##   added via ai_suggest().
## Settings: input/autocorrect (true), input/capitalize (true), input/ai_suggest (true).

const TYPOS := {
	"teh": "the", "hte": "the", "adn": "and", "nad": "and", "taht": "that", "waht": "what", "wiht": "with",
	"recieve": "receive", "beleive": "believe", "definately": "definitely", "seperate": "separate",
	"occured": "occurred", "untill": "until", "wich": "which", "becuase": "because", "becasue": "because",
	"thier": "their", "freind": "friend", "freinds": "friends", "tommorow": "tomorrow", "tomorow": "tomorrow",
	"accross": "across", "alot": "a lot", "acheive": "achieve", "wierd": "weird", "goverment": "government",
	"enviroment": "environment", "realy": "really", "pls": "please", "plz": "please", "thx": "thanks",
	"dont": "don't", "cant": "can't", "wont": "won't", "doesnt": "doesn't", "isnt": "isn't", "didnt": "didn't",
	"wasnt": "wasn't", "arent": "aren't", "couldnt": "couldn't", "shouldnt": "shouldn't", "wouldnt": "wouldn't",
	"im": "I'm", "ive": "I've", "id": "", "ill": "", "thats": "that's", "whats": "what's", "lets": "",
	"companoin": "companion", "compainon": "companion", "voxle": "voxel", "phenix": "phoenix", "pheonix": "phoenix",
}
## "" entries above are real words too (id, ill, lets): never auto-fixed, only offered as chips.
const AMBIGUOUS := {"id": "I'd", "ill": "I'll", "lets": "let's"}
const BOUNDARY := [" ", ".", ",", "!", "?", ";", ":", "\n"]

static var ai_hook: Callable          # func(text: String) -> String  (set by AgentBrain when a model is configured)
static var _last := {}                # LineEdit instance id -> {from, to, at}

static func enabled() -> bool: return bool(Settings.get_value("input", "autocorrect", true))
static func capitalize_on() -> bool: return bool(Settings.get_value("input", "capitalize", true))

static func _skip_word(w: String) -> bool:
	return w.contains("@") or w.contains("://") or w.contains("/") or w.begins_with("#") or w.is_valid_float() \
		or w.contains("_") or (w.length() > 1 and w == w.to_upper())

static func _match_case(src: String, fix: String) -> String:
	if src.length() > 0 and src[0] == src[0].to_upper() and src[0] != src[0].to_lower():
		return fix[0].to_upper() + fix.substr(1)
	return fix

## Fix one word (no punctuation). "" when nothing to do.
static func fix_word(w: String) -> String:
	if w == "" or _skip_word(w): return ""
	if w == "i": return "I"
	var k := w.to_lower()
	var f := str(TYPOS.get(k, ""))
	if f == "": return ""
	return _match_case(w, f) if f != "I'm" and f != "I've" else f

static func autocorrect(text: String, capitalize := true) -> Dictionary:
	var fixes: Array = []
	var rx := RegEx.create_from_string("[A-Za-z][A-Za-z']*")
	var out := ""
	var pos := 0
	var prev_word := ""
	for m in rx.search_all(text):
		var w := m.get_string()
		var gap := text.substr(pos, m.get_start() - pos)
		var before := text.substr(maxi(0, m.get_start() - 12), mini(12, m.get_start()))
		var in_token := before != "" and not before[before.length() - 1] in [" ", "\n", "\t", "(", "\"", "'"] and m.get_start() > 0
		var fixed := w
		if not in_token:
			var end := m.get_end()
			var tail := text.substr(end, 1)
			if not (tail in ["@", "/", "_", "."] and text.substr(end + 1, 1).strip_edges() != ""):
				var f := fix_word(w)
				if f != "": fixed = f
		# doubled word ("the the")
		if fixed.to_lower() == prev_word.to_lower() and gap == " " and fixed.length() > 1 and not fixed.to_lower() in ["that", "had", "very"]:
			fixes.append({"from": w, "to": "(removed repeat)"})
			out = out.rstrip(" ")
			pos = m.get_end()
			continue
		if fixed != w: fixes.append({"from": w, "to": fixed})
		out += gap + fixed
		prev_word = fixed
		pos = m.get_end()
	out += text.substr(pos)
	var squeezed := RegEx.create_from_string(" {2,}").sub(out, " ", true)
	if squeezed != out: fixes.append({"from": "  ", "to": " "}); out = squeezed
	if capitalize:
		var cap := _capitalize(out)
		if cap != out: fixes.append({"from": "sentence start", "to": "capital"}); out = cap
	return {"text": out, "fixes": fixes}

static func _capitalize(s: String) -> String:
	var out := ""
	var start := true
	for i in s.length():
		var ch := s[i]
		if start and ch.strip_edges() != "":
			out += ch.to_upper() if ch.to_lower() != ch.to_upper() else ch
			start = false
		else: out += ch
		if ch in [".", "!", "?"] and (i + 1 >= s.length() or s[i + 1] == " "): start = true
	return out

## Repair chips: [{label, text, source}]. Local first; AI added by ai_suggest().
static func suggestions(text: String) -> Array:
	var out: Array = []
	if text.strip_edges() == "": return out
	var r := autocorrect(text, capitalize_on())
	if r["text"] != text: out.append({"label": "✓ " + str(r["text"]).left(60), "text": r["text"], "source": "local"})
	for w in AMBIGUOUS:
		var rx := RegEx.create_from_string("(?i)\\b%s\\b" % w)
		if rx.search(text):
			var t2 := rx.sub(str(r["text"]), AMBIGUOUS[w], true)
			if t2 != r["text"]: out.append({"label": "? " + t2.left(60), "text": t2, "source": "local"})
	if not text.strip_edges().right(1) in [".", "!", "?"] and text.split(" ", false).size() >= 4:
		out.append({"label": "✓ add period", "text": str(r["text"]).strip_edges() + ".", "source": "local"})
	return out

## AI repair (only when the user has a model configured and input/ai_suggest is on). Keeps meaning;
## result is offered as a chip, never applied or sent automatically. "" when unavailable.
static func ai_suggest(text: String) -> String:
	if not bool(Settings.get_value("input", "ai_suggest", true)) or not ai_hook.is_valid(): return ""
	var s := str(ai_hook.call(text)).strip_edges()
	return s if s != "" and s != text and s.length() <= text.length() * 2 + 20 else ""

# ---------- live LineEdit support ----------
static func eligible(le: Object) -> bool:
	if le == null or not (le is LineEdit or le is TextEdit): return false
	if le is LineEdit and (le as LineEdit).secret: return false
	if le.has_meta("no_autocorrect"): return false
	return true

static func attach(le: LineEdit) -> void:
	if not eligible(le) or le.has_meta("text_assist"): return
	le.set_meta("text_assist", true)
	le.text_changed.connect(func(t): on_changed(le, t))

## Called on each edit: when the user just typed a boundary, fix the word before it.
static func on_changed(le: LineEdit, t: String) -> void:
	if not enabled() or not eligible(le) or t == "": return
	var caret := le.caret_column
	if caret <= 1 or caret > t.length(): return
	var ch := t[caret - 1]
	if not ch in BOUNDARY: return
	var i := caret - 2
	while i >= 0 and not t[i] in BOUNDARY: i -= 1
	var w := t.substr(i + 1, caret - 2 - i)
	var f := fix_word(w)
	if f == "": return
	var nt := t.substr(0, i + 1) + f + t.substr(caret - 1)
	_last[le.get_instance_id()] = {"from": w, "to": f, "at": i + 1}
	le.text = nt
	le.caret_column = caret + f.length() - w.length()

## Put back the last auto-correction in this field. True when something was undone.
static func undo_last(le: LineEdit) -> bool:
	var l: Dictionary = _last.get(le.get_instance_id(), {})
	if l.is_empty(): return false
	var at := int(l["at"])
	if le.text.substr(at, str(l["to"]).length()) != str(l["to"]): return false
	le.text = le.text.substr(0, at) + str(l["from"]) + le.text.substr(at + str(l["to"]).length())
	_last.erase(le.get_instance_id())
	return true

## Hook every LineEdit added under `root` (secret fields skip themselves).
static func watch(tree: SceneTree) -> void:
	if tree.has_meta("text_assist_watch"): return
	tree.set_meta("text_assist_watch", true)
	tree.node_added.connect(func(n):
		if n is LineEdit: TextAssist.attach(n))
