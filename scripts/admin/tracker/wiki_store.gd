class_name WikiStore
extends RefCounted
## Trac-Wiki-style pages with SVN-style revisions. Pages are markdown-ish text.
## Links: CamelCase WikiNames, [wiki:PageName label], ticket links #12, revision links r42, commit links [changeset:abc1234].
## Seeded once from res://data/admin/wiki_seed.json (generated from docs/ by tools/export_admin_seed.py).

const SEED_PATH := "res://data/admin/wiki_seed.json"
const MAX_TEXT := 24000
const NAME_RE := "^[A-Z][A-Za-z0-9]{1,63}$"

var revs: RevisionStore
var path: String
var pages := {}   # name -> {text, rev, source}

func _init(p_revs: RevisionStore, seed_if_empty := true) -> void:
	revs = p_revs
	path = revs.root.path_join("wiki.json")
	if FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary: pages = d
	revs.register_applier("wiki", _apply)
	if pages.is_empty() and seed_if_empty: seed_from_res()

static func valid_name(n: String) -> bool:
	return RegEx.create_from_string(NAME_RE).search(n) != null

func seed_from_res() -> int:
	if not FileAccess.file_exists(SEED_PATH): return 0
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEED_PATH))
	if not (d is Dictionary): return 0
	for n in d:
		if valid_name(n): pages[n] = {"text": str(d[n].get("text", "")), "rev": 0, "source": str(d[n].get("source", ""))}
	var rv := revs.commit("wiki", "wiki/", null, {"seeded": pages.size()}, "Seed %d wiki pages from docs/" % pages.size(), "system")
	for n in pages: pages[n]["rev"] = rv
	_save()
	return pages.size()

func _save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(pages))

func names() -> Array:
	var k := pages.keys(); k.sort(); return k

func get_text(n: String) -> String: return str(pages.get(n, {}).get("text", ""))

## Save a page edit. Returns the new revision, or 0 if invalid / unchanged.
func save_page(n: String, text: String, author := "local", message := "") -> int:
	if not valid_name(n) or text.length() > MAX_TEXT: return 0
	var before: Variant = pages[n]["text"] if pages.has(n) else null
	if before == text: return 0
	var rv := revs.commit("wiki", "wiki/" + n, before, text, message if message != "" else ("Edit " + n), author)
	if rv == 0: return 0
	pages[n] = {"text": text, "rev": rv, "source": pages.get(n, {}).get("source", "in-app")}
	_save()
	return rv

func page_history(n: String) -> Array: return revs.history("wiki/" + n, "wiki")

func _apply(p: String, content: Variant) -> bool:
	var n := p.trim_prefix("wiki/")
	if not valid_name(n): return false
	if content == null: pages.erase(n)
	elif content is String: pages[n] = {"text": content, "rev": revs.head() + 1, "source": pages.get(n, {}).get("source", "in-app")}
	else: return false
	_save()
	return true

## Render to RichTextLabel BBCode with [url=...] links: wiki:Name, ticket:12, rev:42, changeset:sha.
## Code blocks (``` fenced) are kept literal.
func render(text: String) -> String:
	var out := PackedStringArray()
	var in_code := false
	for raw in text.split("\n"):
		var line: String = raw
		if line.strip_edges().begins_with("```"):
			in_code = not in_code
			out.append("[code]" if in_code else "[/code]")
			continue
		line = line.replace("[", "[lb]")   # escape BBCode first
		if in_code: out.append(line); continue
		var h := RegEx.create_from_string("^(#{1,4})\\s+(.*)$").search(line)
		if h: line = "[b][font_size=%d]%s[/font_size][/b]" % [34 - 4 * h.get_string(1).length(), h.get_string(2)]
		var th := RegEx.create_from_string("^(=+)\\s*(.*?)\\s*=+\\s*$").search(line)
		if th: line = "[b][font_size=%d]%s[/font_size][/b]" % [34 - 4 * th.get_string(1).length(), th.get_string(2)]
		if line.begins_with("- ") or line.begins_with("* "): line = "  • " + line.substr(2)
		out.append(_links(line))
	return "\n".join(out)

func _links(s: String) -> String:
	s = RegEx.create_from_string("\\*\\*([^*]+)\\*\\*").sub(s, "[b]$1[/b]", true)
	s = RegEx.create_from_string("`([^`]+)`").sub(s, "[color=#f5c451]$1[/color]", true)
	# explicit [wiki:Name label] (already escaped as [lb]wiki:...])
	s = RegEx.create_from_string("\\[lb\\]wiki:([A-Za-z0-9]+)(?: ([^\\]]+))?\\]").sub(s, "[url=wiki:$1]$1[/url]", true)
	s = RegEx.create_from_string("\\[lb\\]changeset:([0-9a-f]{6,40})\\]").sub(s, "[url=changeset:$1]$1[/url]", true)
	s = RegEx.create_from_string("(^|[\\s(])#(\\d{1,6})\\b").sub(s, "$1[url=ticket:$2]#$2[/url]", true)
	s = RegEx.create_from_string("(^|[\\s(])r(\\d{1,7})\\b").sub(s, "$1[url=rev:$2]r$2[/url]", true)
	# CamelCase WikiNames that exist (avoid linking every capitalised word)
	var re := RegEx.create_from_string("(?<![\\w=:/\\]])([A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+)\\b")
	var res := ""
	var last := 0
	for m in re.search_all(s):
		res += s.substr(last, m.get_start() - last)
		var w := m.get_string(1)
		res += ("[url=wiki:%s]%s[/url]" % [w, w]) if pages.has(w) else w
		last = m.get_end()
	return res + s.substr(last)

## Parse a [url] meta from render(): returns {"type": "wiki"|"ticket"|"rev"|"changeset", "id": String}
static func parse_link(meta: String) -> Dictionary:
	var i := meta.find(":")
	if i <= 0: return {}
	return {"type": meta.left(i), "id": meta.substr(i + 1)}
