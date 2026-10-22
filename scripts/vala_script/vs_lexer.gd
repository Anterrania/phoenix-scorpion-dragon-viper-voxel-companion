class_name VsLexer
extends RefCounted
## Vala Script lexer (our own sandboxed in-world language; NOT the GNOME Vala compiler).
## Turns source text into tokens: {t, v, line}. t is one of
## "id", "kw", "type", "int", "float", "str", "tpl" (an @"..." template), "op", "eof".
## Hard limits keep a hostile script from eating the phone: MAX_SOURCE chars, MAX_TOKENS tokens.

const MAX_SOURCE := 65536
const MAX_TOKENS := 20000
const KEYWORDS := ["default", "state", "if", "else", "while", "do", "for", "foreach", "in", "return",
	"break", "continue", "jump", "var", "slot", "using", "true", "false", "null"]
const TYPES := ["integer", "int", "float", "double", "string", "key", "vector", "rotation",
	"quaternion", "list", "bool", "void"]
## Longest first.
const OPS := ["&&", "||", "==", "!=", "<=", ">=", "++", "--", "+=", "-=", "*=", "/=", "%=",
	"+", "-", "*", "/", "%", "<", ">", "=", "!", "(", ")", "{", "}", "[", "]", ",", ";", ".", ":",
	"&", "|", "^", "~", "@"]

var error := ""
var error_line := 0

func _fail(msg: String, line: int) -> Array:
	error = msg; error_line = line
	return []

static func _is_id_start(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"

static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"

func tokenize(src: String) -> Array:
	error = ""; error_line = 0
	if src.length() > MAX_SOURCE: return _fail("script is too long (max %d characters)" % MAX_SOURCE, 1)
	var out: Array = []
	var i := 0
	var line := 1
	var n := src.length()
	while i < n:
		if out.size() > MAX_TOKENS: return _fail("script has too many tokens (max %d)" % MAX_TOKENS, line)
		var c := src[i]
		if c == "\n":
			line += 1; i += 1; continue
		if c == " " or c == "\t" or c == "\r":
			i += 1; continue
		if c == "/" and i + 1 < n and src[i + 1] == "/":
			while i < n and src[i] != "\n": i += 1
			continue
		if c == "/" and i + 1 < n and src[i + 1] == "*":
			var start_line := line
			i += 2
			while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
				if src[i] == "\n": line += 1
				i += 1
			if i >= n: return _fail("comment never closed", start_line)
			i += 2
			continue
		if _is_id_start(c):
			var j := i
			while j < n and (_is_id_start(src[j]) or _is_digit(src[j])): j += 1
			var w := src.substr(i, j - i)
			var t := "kw" if w in KEYWORDS else ("type" if w in TYPES else "id")
			out.append({"t": t, "v": w, "line": line})
			i = j; continue
		if _is_digit(c) or (c == "." and i + 1 < n and _is_digit(src[i + 1])):
			var j := i
			var is_float := false
			if c == "0" and i + 1 < n and (src[i + 1] == "x" or src[i + 1] == "X"):
				j = i + 2
				while j < n and (_is_digit(src[j]) or src[j].to_lower() in ["a", "b", "c", "d", "e", "f"]): j += 1
				out.append({"t": "int", "v": src.substr(i + 2, j - i - 2).hex_to_int(), "line": line})
				i = j; continue
			while j < n and (_is_digit(src[j]) or src[j] == "."):
				if src[j] == ".": is_float = true
				j += 1
			if j < n and (src[j] == "e" or src[j] == "E"):
				var k := j + 1
				if k < n and (src[k] == "+" or src[k] == "-"): k += 1
				if k < n and _is_digit(src[k]):
					is_float = true; j = k
					while j < n and _is_digit(src[j]): j += 1
			if j < n and (src[j] == "f" or src[j] == "F"):   # 1.5f (C#/Vala habit)
				is_float = true
				var txt := src.substr(i, j - i)
				out.append({"t": "float", "v": txt.to_float(), "line": line})
				i = j + 1; continue
			var num := src.substr(i, j - i)
			if is_float: out.append({"t": "float", "v": num.to_float(), "line": line})
			else:
				if num.length() > 10 or num.to_int() > 2147483647: return _fail("integer too big: " + num, line)
				out.append({"t": "int", "v": num.to_int(), "line": line})
			i = j; continue
		if c == "\"" or (c == "@" and i + 1 < n and src[i + 1] == "\""):
			var tpl := c == "@"
			var start_line := line
			i += 2 if tpl else 1
			var s := ""
			while i < n and src[i] != "\"":
				var ch := src[i]
				if ch == "\n": line += 1
				if ch == "\\" and i + 1 < n:
					var e := src[i + 1]
					match e:
						"n": s += "\n"
						"t": s += "    "   # like LSL: a tab becomes 4 spaces
						"\"": s += "\""
						"\\": s += "\\"
						_: s += "\\" + e
					i += 2; continue
				s += ch; i += 1
			if i >= n: return _fail("string never closed", start_line)
			i += 1
			out.append({"t": "tpl" if tpl else "str", "v": s, "line": start_line})
			continue
		var matched := ""
		for op in OPS:
			if src.substr(i, op.length()) == op:
				matched = op; break
		if matched == "": return _fail("unexpected character '%s'" % c, line)
		out.append({"t": "op", "v": matched, "line": line})
		i += matched.length()
	out.append({"t": "eof", "v": "", "line": line})
	return out
