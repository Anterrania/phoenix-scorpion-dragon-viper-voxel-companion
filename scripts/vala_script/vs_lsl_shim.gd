class_name VsLslShim
extends RefCounted
## Optional import shim: reads a simple LSL-style script and writes the matching Vala Script.
## Clean-room: a table of call shapes we support, written from scratch. It never runs LSL.
## Anything outside the common subset is reported with its line number and left out or kept as-is
## (so the result won't compile until someone rewrites that part).
##
## translate(src) -> {ok, source, unsupported: [{line, what}], error, line}

## LSL-style call -> Vala Script template ($0, $1... are the original arguments).
const CALLS := {
	"llSay": "say($0, $1)", "llWhisper": "whisper($0, $1)", "llShout": "shout($0, $1)",
	"llRegionSay": "region_say($0, $1)", "llOwnerSay": "owner_say($0)",
	"llListen": "listen($0, $1, $2, $3)", "llListenRemove": "listen_remove($0)",
	"llSetText": "set_text($0, $1, $2)", "llSetColor": "set_color($0)", "llSetAlpha": "set_alpha($0)",
	"llGetPos": "get_pos()", "llSetPos": "set_pos($0)", "llGetRot": "get_rot()", "llSetRot": "set_rot($0)",
	"llGetOwner": "get_owner()", "llGetKey": "get_key()", "llGetObjectName": "get_name()",
	"llSetTimerEvent": "timer($0)", "llSensor": "sensor($0, $3)", "llSensorRemove": "sensor_remove()",
	"llDetectedKey": "detected_key($0)", "llDetectedName": "detected_name($0)", "llDetectedPos": "detected_pos($0)",
	"llGiveInventory": "give_item($0, $1)", "llRezObject": "rez($0, $1)", "llDie": "die()",
	"llTeleportAgent": "teleport($0, $2)", "llHTTPRequest": "http_request($0, \"POST\", $2)",
	"llResetScript": "reset_script()", "llGetTime": "time()", "llGetUnixTime": "now()",
	"llGetFreeMemory": "free_memory()", "llStringLength": "length($0)", "llGetListLength": "length($0)",
	"llGetSubString": "substr($0, $1, ($2) - ($1) + 1)", "llSubStringIndex": "index_of($0, $1)",
	"llToUpper": "to_upper($0)", "llToLower": "to_lower($0)", "llStringTrim": "trim($0)",
	"llList2String": "(string)(($0)[$1])", "llList2Key": "(string)(($0)[$1])",
	"llList2Integer": "(integer)(($0)[$1])", "llList2Float": "(float)(($0)[$1])",
	"llList2Vector": "($0)[$1]", "llList2Rot": "($0)[$1]",
	"llList2List": "list_slice($0, $1, ($2) + 1)", "llListFindList": "list_find($0, ($1)[0])",
	"llParseString2List": "split($0, ($1)[0])", "llDumpList2String": "join($0, $1)",
	"llListSort": "list_sort($0)",
	"llAbs": "abs($0)", "llFabs": "abs($0)", "llFloor": "floor($0)", "llCeil": "ceil($0)", "llRound": "round($0)",
	"llSqrt": "sqrt($0)", "llPow": "pow($0, $1)", "llSin": "sin($0)", "llCos": "cos($0)", "llTan": "tan($0)",
	"llAtan2": "atan2($0, $1)", "llFrand": "rand($0)", "llVecMag": "vec_mag($0)", "llVecNorm": "vec_norm($0)",
	"llVecDist": "vec_dist($0, $1)", "llEuler2Rot": "euler_to_rot($0)", "llRot2Euler": "rot_to_euler($0)",
}
## Events we don't run yet. Their whole handler is dropped and reported.
const UNSUPPORTED_EVENTS := ["link_message", "run_time_permissions", "money", "dataserver", "attach", "control",
	"at_target", "not_at_target", "at_rot_target", "not_at_rot_target", "email", "land_collision_start",
	"land_collision", "land_collision_end", "moving_start", "moving_end", "object_rez", "remote_data",
	"transaction_result", "experience_permissions", "experience_permissions_denied", "path_update",
	"http_request", "game_control", "linkset_data"]

var unsupported: Array = []

func _report(line: int, what: String) -> void:
	unsupported.append({"line": line, "what": what})

static func _tok_text(t: Dictionary) -> String:
	match t["t"]:
		"str": return "\"" + str(t["v"]).replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
		"float":
			var s := str(t["v"])
			return s if s.contains(".") or s.contains("e") else s + ".0"
	return str(t["v"])

func translate(src: String) -> Dictionary:
	unsupported = []
	var lx := VsLexer.new()
	var toks := lx.tokenize(src)
	if lx.error != "": return {"ok": false, "source": "", "unsupported": [], "error": lx.error, "line": lx.error_line}
	var out := _emit(toks, 0, toks.size() - 1)
	var c := VsParser.new().compile(out)
	unsupported.sort_custom(func(a, b): return a["line"] < b["line"])
	return {"ok": unsupported.is_empty() and c["ok"], "source": out, "unsupported": unsupported,
		"error": c.get("error", ""), "line": c.get("line", 0)}

## Rebuild tokens [a, b) as Vala Script text, keeping line breaks so line numbers still match.
func _emit(toks: Array, a: int, b: int, line0 := -1) -> String:
	var s := ""
	var line := line0 if line0 >= 0 else 1
	var i := a
	var depth := 0
	while i < b:
		var t: Dictionary = toks[i]
		while int(t["line"]) > line:
			s += "\n"; line += 1
		if t["t"] == "op" and t["v"] == "{": depth += 1
		if t["t"] == "op" and t["v"] == "}": depth -= 1
		if t["t"] == "op" and t["v"] == "@":
			_report(t["line"], "labels and jump"); i += 1; continue
		if t["t"] == "kw" and t["v"] == "jump":
			_report(t["line"], "labels and jump"); i += 1; continue
		if t["t"] == "id" and depth == 1 and str(t["v"]) in UNSUPPORTED_EVENTS and _is_op(toks, i + 1, "("):
			_report(t["line"], "event %s" % t["v"])
			i = _skip_handler(toks, i)
			continue
		if t["t"] == "id" and _is_op(toks, i + 1, "(") and (str(t["v"]).begins_with("ll") or str(t["v"]).begins_with("os")):
			var nm := str(t["v"])
			var end := _match_paren(toks, i + 1)
			if not CALLS.has(nm):
				_report(t["line"], "function %s" % nm)
				s += nm + " "
				i += 1; continue
			var args: Array = []
			var start := i + 2
			var d := 0
			var vd := 0   # inside a <x, y, z> vector literal
			for j in range(i + 2, end + 1):
				var tj: Dictionary = toks[j]
				if tj["t"] == "op" and tj["v"] == "<" and toks[j - 1]["t"] == "op" and toks[j - 1]["v"] in ["(", ",", "[", "="]: vd += 1
				elif tj["t"] == "op" and tj["v"] == ">" and vd > 0: vd -= 1
				if tj["t"] == "op" and tj["v"] in ["(", "[", "{"]: d += 1
				if tj["t"] == "op" and tj["v"] in [")", "]", "}"]:
					if d == 0:
						if j > start: args.append(_emit(toks, start, j, int(toks[start]["line"])).replace("\n", " ").strip_edges())
						break
					d -= 1
				if tj["t"] == "op" and tj["v"] == "," and d == 0 and vd == 0:
					args.append(_emit(toks, start, j, int(toks[start]["line"])).replace("\n", " ").strip_edges())
					start = j + 1
			var tpl: String = CALLS[nm]
			for k in range(9, -1, -1):
				var token := "$%d" % k
				if tpl.contains(token):
					if k >= args.size(): _report(t["line"], "%s with too few arguments" % nm)
					tpl = tpl.replace(token, args[k] if k < args.size() else "0")
			s += tpl + " "
			line = int(toks[end]["line"]) if end < toks.size() else line
			i = end + 1
			continue
		s += _tok_text(t) + " "
		i += 1
	return s

static func _is_op(toks: Array, i: int, v: String) -> bool:
	return i < toks.size() and toks[i]["t"] == "op" and toks[i]["v"] == v

static func _match_paren(toks: Array, i: int) -> int:
	var d := 0
	for j in range(i, toks.size()):
		if toks[j]["t"] == "op" and toks[j]["v"] == "(": d += 1
		elif toks[j]["t"] == "op" and toks[j]["v"] == ")":
			d -= 1
			if d == 0: return j
	return toks.size() - 1

## Skip `name(params) { ... }` and return the index after its closing brace.
static func _skip_handler(toks: Array, i: int) -> int:
	var j := _match_paren(toks, i + 1) + 1
	if not _is_op(toks, j, "{"): return j
	var d := 0
	while j < toks.size():
		if toks[j]["t"] == "op" and toks[j]["v"] == "{": d += 1
		elif toks[j]["t"] == "op" and toks[j]["v"] == "}":
			d -= 1
			if d == 0: return j + 1
		j += 1
	return j
