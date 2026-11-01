class_name PatternRecall
extends RefCounted
## v0.13 BRAIN-RECALL: pattern recall across a companion's memories and past interactions.
## - similar(): word-overlap (Jaccard) plus an in-order word-pair bonus, so "red dragon over the lake"
##   recalls "a red dragon flew over the lake" more strongly than a bag of the same words.
## - deja_vu: a match at or above DEJA_VU means "this feels like something that happened before".
## - recurring(): word pairs that keep coming back across interactions (sequences / habits).
## Pure functions over text; no model, no network. Used for the prompt hint and the admin screen.

const DEJA_VU := 0.6
const MIN_SCORE := 0.15

static func words(t: String) -> PackedStringArray:
	var out := PackedStringArray()
	for w in t.to_lower().split(" ", false):
		var c := ""
		for ch in w:
			if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"): c += ch
		if c.length() > 1 and not c in MemoryVault.STOP: out.append(c)
	return out

static func pairs(ws: PackedStringArray) -> Dictionary:
	var d := {}
	for i in range(ws.size() - 1): d[ws[i] + " " + ws[i + 1]] = true
	return d

static func score(a: String, b: String) -> float:
	var wa := words(a); var wb := words(b)
	if wa.is_empty() or wb.is_empty(): return 0.0
	var sa := {}; var sb := {}
	for w in wa: sa[w] = true
	for w in wb: sb[w] = true
	var inter := 0
	for w in sa:
		if sb.has(w): inter += 1
	var jac := float(inter) / float(sa.size() + sb.size() - inter)
	var pa := pairs(wa); var pb := pairs(wb)
	var pc := 0
	for p in pa:
		if pb.has(p): pc += 1
	var seq := float(pc) / float(maxi(1, mini(pa.size(), pb.size())))
	return clampf(jac * 0.7 + seq * 0.3, 0.0, 1.0)

## items: Array of {text, ...}. Returns the top k with "score" and "deja_vu" added, best first.
static func similar(query: String, items: Array, k := 5) -> Array:
	var out: Array = []
	for it in items:
		var t := str(it.get("text", "")) if it is Dictionary else str(it)
		var s := score(query, t)
		if s < MIN_SCORE: continue
		var r: Dictionary = it.duplicate() if it is Dictionary else {"text": t}
		r["score"] = snappedf(s, 0.001); r["deja_vu"] = s >= DEJA_VU
		out.append(r)
	out.sort_custom(func(a, b): return a["score"] > b["score"])
	return out.slice(0, k)

## Everything a companion can recall from: current vault memories + past interaction transcripts.
static func corpus(cid: String) -> Array:
	var items: Array = []
	for v in MemoryVault.all_current(cid): items.append({"text": str(v.get("text", "")), "source": "memory", "key": v.get("key", "")})
	for r in InteractionLedger.records(cid, "interaction", 200):
		for line in r.get("data", {}).get("wiki", {}).get("transcript", []):
			if line is Dictionary: items.append({"text": str(line.get("text", "")), "source": "interaction", "role": line.get("role", "")})
	return items

static func recall(cid: String, query: String, k := 5) -> Array: return similar(query, corpus(cid), k)

## Word pairs seen in at least `min_count` different texts, most frequent first.
static func recurring(texts: Array, min_count := 3, k := 8) -> Array:
	var counts := {}
	for t in texts:
		for p in pairs(words(str(t))): counts[p] = int(counts.get(p, 0)) + 1
	var out: Array = []
	for p in counts:
		if int(counts[p]) >= min_count: out.append({"pair": p, "count": counts[p]})
	out.sort_custom(func(a, b): return a["count"] > b["count"])
	return out.slice(0, k)
