extends RefCounted
## Wiki expansion (VIPER-11 / WIKI-1..6): seed contents, ticket seed, and relative link check for docs/wiki.

const PAGES := ["WorldsRegions", "WorldAlaskanAuroraTundra", "WorldVenusFireWastes", "WorldCosmicGlitterExpanse",
	"PopularPlaces", "Interactions", "HowTo", "OwnerLock", "AethelCoinExchange", "EconomyMetrics", "EconomyGuide"]

static func run(t: Node) -> void:
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	t.check(wiki is Dictionary, "wiki: seed parses")
	if not (wiki is Dictionary): return
	for p in PAGES: t.check(wiki.has(p), "wiki: seed has page " + p)
	t.check(str(wiki.get("AethelCoinExchange", {}).get("text", "")).contains("LEGAL REVIEW REQUIRED"), "wiki: exchange page has legal-review note")
	t.check(str(wiki.get("OwnerLock", {}).get("text", "")).contains("status: built"), "wiki: owner lock page is built")
	var tk: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/tickets_seed.json"))
	var found := {}
	for x in tk:
		if str(x.get("milestone", "")).begins_with("WIKI-"): found[x["milestone"]] = x["status"]
	for i in range(1, 7):
		t.check(found.get("WIKI-%d" % i, "") == "closed", "wiki: ticket WIKI-%d seeded and closed" % i)
	# link check: every relative .md link in docs/wiki and docs/FAQ.md resolves to a file
	var re := RegEx.new(); re.compile("\\]\\(([^)#:]+\\.md)(#[^)]*)?\\)")
	var files: Array = ["res://docs/FAQ.md"]
	for f in DirAccess.get_files_at("res://docs/wiki"):
		if f.ends_with(".md"): files.append("res://docs/wiki/" + f)
	var bad := 0
	for f in files:
		var base: String = f.get_base_dir()
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			var target := base.path_join(m.get_string(1)).simplify_path()
			if not FileAccess.file_exists(target):
				bad += 1; t.check(false, "wiki: broken link %s -> %s" % [f, m.get_string(1)])
	t.check(bad == 0, "wiki: all relative links resolve (%d files)" % files.size())
