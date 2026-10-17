class_name RepoTimeline
extends RefCounted
## Read-only "Repository" timeline: git commits exported at build time by tools/export_admin_seed.py
## into res://data/admin/repo_log.json, merged with in-app revisions for the admin Timeline view.

const PATH := "res://data/admin/repo_log.json"

static func commits() -> Array:
	if not FileAccess.file_exists(PATH): return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if d is Array else []

static func find(sha: String) -> Dictionary:
	for c in commits():
		if str(c.get("sha", "")).begins_with(sha) or sha.begins_with(str(c.get("sha", "_"))): return c
	return {}

## Unified, newest-first event list: {when, kind: "commit"|"revision", title, ref}
static func merged(revs: RevisionStore, limit := 60) -> Array:
	var ev: Array = []
	for c in commits():
		ev.append({"when": str(c.get("date", "")), "kind": "commit", "title": str(c.get("subject", "")), "ref": str(c.get("sha", "")), "author": str(c.get("author", ""))})
	if revs:
		for r in revs.history("", "", limit):
			ev.append({"when": str(r["t"]), "kind": "revision", "title": "r%d %s" % [r["rev"], r["message"]], "ref": "r%d" % r["rev"], "author": str(r["author"])})
	ev.sort_custom(func(a, b): return a["when"] > b["when"])
	return ev.slice(0, limit)
