class_name HeavenDirector
extends RefCounted
## HEAVEN-6 "Direct a change": the owner points at a spot in Heaven and tells a companion what to do
## in plain words ("put a fountain here", "make this taller", "paint it gold", "remove this").
## This turns the words + the pointed spot into a HeavenEdits tool call. Offline and deterministic
## (keyword rules), so it works with no model; a companion's language model can call
## HeavenEdits.tool_call directly with richer arguments when chat tools are wired (Foxy spec).

const TYPE_WORDS := {
	"fountain": "fountain", "tree": "tree", "trees": "tree", "cypress": "cypress", "palm": "palm",
	"lamp": "lamp", "light": "lamp", "bench": "bench", "table": "table", "sign": "sign", "arch": "arch",
	"gate": "arch", "columns": "column_ring", "colonnade": "column_ring", "house": "house", "home": "house",
	"apartment": "apartment", "tower": "tower", "skyscraper": "tower", "stall": "stall", "cabana": "cabana",
	"gazebo": "gazebo", "hedge": "hedge", "flowers": "flowerbed", "flowerbed": "flowerbed", "garden": "park",
	"park": "park", "pool": "pool", "crates": "crates", "car": "car", "flag": "flag", "screen": "plaza_screen",
	"statue": "statue", "kiosk": "kiosk", "shop": "shop", "store": "shop", "glow tree": "glow_tree",
}
const COLOR_WORDS := {
	"gold": "#f0c35a", "white": "#f7f5fb", "pearl": "#f7f5fb", "marble": "#ede8de", "black": "#141018",
	"pink": "#ff7ac0", "rose": "#ff7ac0", "blue": "#6fb7ff", "sky": "#8fd0ff", "purple": "#9a7fd8",
	"violet": "#9a7fd8", "red": "#d8453a", "green": "#4f8f3f", "orange": "#ff9a5a", "silver": "#cfd3da",
}

## Returns tool args for HeavenEdits.tool_call, or {"error": "..."}.
## `spot` = world point the owner pointed at; `piece` = the piece nearest that spot ({} if none).
static func parse(text: String, spot: Vector3, piece: Dictionary = {}) -> Dictionary:
	var t := " " + text.to_lower().strip_edges() + " "
	if t.strip_edges() == "": return {"error": "Say what to change."}
	var args := {"x": spot.x, "y": spot.y, "z": spot.z, "note": text.left(120)}
	var col := ""
	for w in COLOR_WORDS:
		if t.contains(" " + w + " ") or t.contains(" " + w + ","): col = COLOR_WORDS[w]; break
	var kind := ""
	for w in ["glow tree"] + TYPE_WORDS.keys():
		if t.contains(" " + w + " ") or t.contains(" " + w + "s ") or t.contains(" " + w + ","): kind = TYPE_WORDS[w]; break
	var has_target := not piece.is_empty()
	if _any(t, ["remove", "delete", "take away", "get rid"]):
		if not has_target: return {"error": "Point at the thing to remove."}
		args["op"] = "remove"; args["target"] = piece["id"]
		return args
	var bigger := _any(t, ["taller", "bigger", "larger", "higher", "grow"])
	var smaller := _any(t, ["shorter", "smaller", "lower", "shrink"])
	var move := _any(t, ["move", "put it here", "bring it here"])
	var paint := col != "" and _any(t, ["paint", "colour", "color", "make it", "turn it"])
	var turn := _any(t, ["turn around", "rotate", "face"])
	if has_target and (bigger or smaller or move or paint or turn or _any(t, ["rename", "call it", "say "])) and not _any(t, ["add", "build", "place", "put a", "plant", "new "]):
		args["op"] = "set"; args["target"] = piece["id"]
		var f := 1.25 if bigger else 0.8
		if bigger or smaller:
			for k in ["h", "w", "d", "r"]:
				if piece.has(k): args[k] = float(piece[k]) * f
			if not (piece.has("h") or piece.has("r")): args["h"] = 8.0 * f
		if paint: args["color"] = col
		if turn: args["yaw"] = float(piece.get("yaw", 0.0)) + (180.0 if t.contains("around") else 90.0)
		if move: args["move"] = true
		var nm := _after(text, ["call it ", "rename it ", "rename to ", "say "])
		if nm != "": args["text" if str(piece.get("type", "")) == "sign" else "name"] = nm
		return args
	if kind == "":
		return {"error": "I can add: fountain, tree, lamp, bench, sign, arch, house, tower, shop, gazebo, pool, statue and more."}
	args["op"] = "add"; args["type"] = kind
	if col != "": args["color"] = col
	if kind == "sign":
		var s := _after(text, ["saying ", "that says ", "reading ", "called "])
		args["text"] = s if s != "" else "Welcome"
	if kind == "shop":
		var sid := _shop_word(t)
		if sid == "": return {"error": "Which shop? (clothes, shoes, hair, looks)"}
		args["shop"] = sid
	if _any(t, ["big ", "large ", "tall "]):
		args["h"] = {"tower": 90.0, "tree": 12.0, "fountain": 8.0}.get(kind, 10.0)
		if kind == "fountain": args["r"] = 12.0
	return args

static func _any(t: String, words: Array) -> bool:
	for w in words:
		if t.contains(w): return true
	return false

static func _after(text: String, keys: Array) -> String:
	var low := text.to_lower()
	for k in keys:
		var i := low.find(k)
		if i >= 0: return text.substr(i + k.length()).strip_edges().trim_suffix(".").replace("\"", "").left(40)
	return ""

static func _shop_word(t: String) -> String:
	for pair in [["shoe", "cloudstep_shoes"], ["hair", "halo_hair"], ["look", "radiance_looks"], ["access", "gilded_wings"], ["cloth", "seraph_threads"], ["outfit", "seraph_threads"]]:
		if t.contains(pair[0]): return pair[1]
	return ""
