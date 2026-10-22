class_name VsParser
extends RefCounted
## Vala Script parser + checker. Source -> program Dictionary (AST of plain Dictionaries).
## Syntax: C-like, Vala/C#-flavoured surface (`var`, typed locals, `state Name { }` blocks,
## @"templates $name $(expr)", foreach) over an LSL-style event model (states + event handlers).
## The checker refuses, at compile time: unknown functions (there is no way to name an engine or OS
## object), unknown events, wrong argument counts, undeclared variables, slot methods that the slot's
## element type doesn't have, and `state X;` to a state that doesn't exist.
##
## program = {globals: [{type, name, init, line}], funcs: {name: {ret, params: [[type, name]], body, line}},
##            states: {name: {events: {event: {params, body, line}}, line}}, slots: {name: type}}

const TYPE_ALIAS := {"int": "integer", "double": "float", "quaternion": "rotation", "bool": "integer"}
const MAX_DEPTH := 200   # nesting depth for the recursive-descent parser

var toks: Array = []
var p := 0
var error := ""
var error_line := 0
var _no_gt := 0
var _depth := 0
var _in_global_init := false

static func norm_type(t: String) -> String: return TYPE_ALIAS.get(t, t)

## Parse + check. Returns {ok, program, error, line}.
func compile(src: String) -> Dictionary:
	var lx := VsLexer.new()
	toks = lx.tokenize(src)
	if lx.error != "": return {"ok": false, "error": lx.error, "line": lx.error_line}
	p = 0; error = ""; error_line = 0
	var prog := _program()
	if error == "": _check(prog)
	if error != "": return {"ok": false, "error": error, "line": error_line}
	return {"ok": true, "program": prog, "error": "", "line": 0}

# ---------------- token helpers ----------------
func _peek(o := 0) -> Dictionary: return toks[min(p + o, toks.size() - 1)]
func _is(t: String, v: Variant = null, o := 0) -> bool:
	var k := _peek(o)
	return k["t"] == t and (v == null or k["v"] == v)
func _op(v: String, o := 0) -> bool: return _is("op", v, o)
func _next() -> Dictionary:
	var k := _peek(); p = min(p + 1, toks.size() - 1); return k
func _line() -> int: return int(_peek()["line"])
func _err(msg: String, line := -1) -> void:
	if error == "":
		error = msg; error_line = line if line >= 0 else _line()
func _expect_op(v: String) -> bool:
	if _op(v): _next(); return true
	_err("expected '%s' but found '%s'" % [v, str(_peek()["v"]) if _peek()["t"] != "eof" else "end of script"])
	return false
func _expect_id() -> String:
	if _is("id"): return str(_next()["v"])
	_err("expected a name but found '%s'" % str(_peek()["v"]))
	return ""

# ---------------- program ----------------
func _program() -> Dictionary:
	var prog := {"globals": [], "funcs": {}, "states": {}, "slots": {}}
	while error == "" and not _is("eof"):
		var line := _line()
		if _is("kw", "using"):
			_next()
			while error == "" and not _op(";") and not _is("eof"): _next()
			_expect_op(";")
		elif _is("kw", "slot"):
			_next()
			var nm := _expect_id()
			_expect_op(":")
			var ty := _expect_id()
			_expect_op(";")
			if error != "": break
			if not VsVM.ELEMENT_API.has(ty): _err("unknown element type '%s' (use one of %s)" % [ty, ", ".join(VsVM.ELEMENT_API.keys())], line)
			elif prog["slots"].has(nm): _err("slot '%s' declared twice" % nm, line)
			else: prog["slots"][nm] = ty
		elif _is("kw", "default"):
			_next(); _state_block(prog, "default", line)
		elif _is("kw", "state"):
			_next()
			var nm := "default" if _is("kw", "default") else ""
			if nm == "default": _next()
			else: nm = _expect_id()
			_state_block(prog, nm, line)
		elif _is("type") or _is("kw", "var"):
			var ty := norm_type(str(_next()["v"]))
			var nm := _expect_id()
			if _op("("):
				_function(prog, ty, nm, line)
			else:
				if ty == "void": _err("a variable can't be void", line)
				var init = null
				if _op("="):
					_next()
					_in_global_init = true
					init = _expr()
					_in_global_init = false
				elif ty == "var": _err("'var' needs a starting value", line)
				_expect_op(";")
				prog["globals"].append({"type": ty, "name": nm, "init": init, "line": line})
		elif _is("id") and _op("(", 1):
			var nm := str(_next()["v"])
			_function(prog, "void", nm, line)
		else:
			_err("expected a variable, function, slot or state at top level, found '%s'" % str(_peek()["v"]))
	if error == "" and not prog["states"].has("default"): _err("every script needs a default state", 1)
	return prog

func _params() -> Array:
	var ps: Array = []
	_expect_op("(")
	while error == "" and not _op(")"):
		if not _is("type"): _err("expected a parameter type"); break
		var ty := norm_type(str(_next()["v"]))
		var nm := _expect_id()
		ps.append([ty, nm])
		if _op(","): _next()
		elif not _op(")"): _err("expected ',' or ')' in parameters"); break
	_expect_op(")")
	return ps

func _function(prog: Dictionary, ret: String, nm: String, line: int) -> void:
	if prog["funcs"].has(nm): _err("function '%s' defined twice" % nm, line); return
	if VsVM.BUILTINS.has(nm): _err("'%s' is a built-in function name" % nm, line); return
	var ps := _params()
	var body := _block()
	prog["funcs"][nm] = {"ret": ret, "params": ps, "body": body, "line": line}

func _state_block(prog: Dictionary, nm: String, line: int) -> void:
	if prog["states"].has(nm): _err("state '%s' defined twice" % nm, line); return
	var st := {"events": {}, "line": line}
	_expect_op("{")
	while error == "" and not _op("}") and not _is("eof"):
		var eline := _line()
		if _is("type", "void"): _next()   # `void touch_start(int n)` is fine too (Vala habit)
		var ev := _expect_id()
		if error != "": break
		if not VsVM.EVENTS.has(ev): _err("unknown event '%s'" % ev, eline); break
		if st["events"].has(ev): _err("event '%s' defined twice in state %s" % [ev, nm], eline); break
		var ps := _params()
		var want: Array = VsVM.EVENTS[ev]
		if error == "" and ps.size() != want.size():
			_err("event '%s' takes %d parameter(s)" % [ev, want.size()], eline); break
		var body := _block()
		st["events"][ev] = {"params": ps, "body": body, "line": eline}
	_expect_op("}")
	prog["states"][nm] = st

# ---------------- statements ----------------
func _block() -> Array:
	var out: Array = []
	if not _expect_op("{"): return out
	_depth += 1
	if _depth > MAX_DEPTH: _err("code is nested too deeply")
	while error == "" and not _op("}") and not _is("eof"):
		out.append(_stmt())
	_depth -= 1
	_expect_op("}")
	return out

func _body() -> Array:
	if _op("{"): return _block()
	return [_stmt()]

func _stmt() -> Dictionary:
	var line := _line()
	if _op("{"): return {"k": "block", "body": _block(), "line": line}
	if _op(";"): _next(); return {"k": "block", "body": [], "line": line}
	if _is("type") or _is("kw", "var"):
		var d := _decl()
		_expect_op(";")
		return d
	if _is("kw"):
		var w := str(_peek()["v"])
		match w:
			"if":
				_next(); _expect_op("(")
				var c := _expr(); _expect_op(")")
				var th := _body()
				var el: Array = []
				if _is("kw", "else"):
					_next(); el = _body()
				return {"k": "if", "c": c, "then": th, "else": el, "line": line}
			"while":
				_next(); _expect_op("(")
				var c := _expr(); _expect_op(")")
				return {"k": "while", "c": c, "body": _body(), "line": line}
			"do":
				_next()
				var b := _body()
				if not _is("kw", "while"): _err("expected 'while' after do { }"); return {}
				_next(); _expect_op("(")
				var c := _expr(); _expect_op(")"); _expect_op(";")
				return {"k": "do", "c": c, "body": b, "line": line}
			"for":
				_next(); _expect_op("(")
				var init: Array = []
				while error == "" and not _op(";"):
					init.append(_decl() if (_is("type") or _is("kw", "var")) else {"k": "expr", "e": _expr(), "line": line})
					if _op(","): _next()
					else: break
				_expect_op(";")
				var c = null if _op(";") else _expr()
				_expect_op(";")
				var step: Array = []
				while error == "" and not _op(")"):
					step.append({"k": "expr", "e": _expr(), "line": line})
					if _op(","): _next()
					else: break
				_expect_op(")")
				return {"k": "for", "init": init, "c": c, "step": step, "body": _body(), "line": line}
			"foreach":
				_next(); _expect_op("(")
				if not (_is("type") or _is("kw", "var")): _err("foreach needs a type or var"); return {}
				var ty := norm_type(str(_next()["v"]))
				var nm := _expect_id()
				if not _is("kw", "in"): _err("expected 'in' in foreach"); return {}
				_next()
				var it := _expr(); _expect_op(")")
				return {"k": "foreach", "type": ty, "name": nm, "iter": it, "body": _body(), "line": line}
			"return":
				_next()
				var e = null if _op(";") else _expr()
				_expect_op(";")
				return {"k": "return", "e": e, "line": line}
			"break":
				_next(); _expect_op(";"); return {"k": "break", "line": line}
			"continue":
				_next(); _expect_op(";"); return {"k": "continue", "line": line}
			"state":
				_next()
				var nm := "default" if _is("kw", "default") else ""
				if nm == "default": _next()
				else: nm = _expect_id()
				_expect_op(";")
				return {"k": "state", "name": nm, "line": line}
			"jump":
				_err("'jump' and labels are not supported (use loops, break and continue)"); return {}
	var e := _expr()
	_expect_op(";")
	return {"k": "expr", "e": e, "line": line}

func _decl() -> Dictionary:
	var line := _line()
	var ty := norm_type(str(_next()["v"]))
	if ty == "void": _err("a variable can't be void", line)
	var nm := _expect_id()
	var init = null
	if _op("="):
		_next(); init = _expr()
	elif ty == "var": _err("'var' needs a starting value", line)
	return {"k": "decl", "type": ty, "name": nm, "init": init, "line": line}

# ---------------- expressions ----------------
const BIN_LEVELS := [["||"], ["&&"], ["|"], ["^"], ["&"], ["==", "!="], ["<", ">", "<=", ">="], ["+", "-"], ["*", "/", "%"]]
const ASSIGN_OPS := ["=", "+=", "-=", "*=", "/=", "%="]

func _expr() -> Dictionary:
	_depth += 1
	if _depth > MAX_DEPTH: _err("expression is nested too deeply"); _depth -= 1; return {"k": "lit", "v": 0, "line": _line()}
	var e := _assign()
	_depth -= 1
	return e

func _assign() -> Dictionary:
	var line := _line()
	var lhs := _bin(0)
	if _is("op") and str(_peek()["v"]) in ASSIGN_OPS:
		var op := str(_next()["v"])
		if not lhs.get("k") in ["var", "member"]: _err("can only assign to a variable or a .x/.y/.z/.s part", line)
		var rhs := _assign()
		return {"k": "assign", "op": op, "target": lhs, "value": rhs, "line": line}
	return lhs

func _bin(level: int) -> Dictionary:
	if level >= BIN_LEVELS.size(): return _unary()
	var a := _bin(level + 1)
	while error == "" and _is("op") and str(_peek()["v"]) in BIN_LEVELS[level]:
		if _no_gt > 0 and _op(">"): break   # closes a <x, y, z> vector literal
		var line := _line()
		var op := str(_next()["v"])
		var b := _bin(level + 1)
		a = {"k": "bin", "op": op, "a": a, "b": b, "line": line}
	return a

func _unary() -> Dictionary:
	var line := _line()
	if _is("op") and str(_peek()["v"]) in ["!", "-", "~"]:
		var op := str(_next()["v"])
		return {"k": "un", "op": op, "a": _unary(), "line": line}
	if _op("++") or _op("--"):
		var op := str(_next()["v"])
		var t := _unary()
		if t.get("k") != "var": _err("++/-- needs a variable", line)
		return {"k": "incdec", "op": op, "prefix": true, "target": t, "line": line}
	if _op("(") and _is("type", null, 1) and _op(")", 2):   # cast: (string) x
		_next()
		var ty := norm_type(str(_next()["v"]))
		_next()
		return {"k": "cast", "type": ty, "a": _unary(), "line": line}
	return _postfix()

func _postfix() -> Dictionary:
	var e := _primary()
	while error == "":
		var line := _line()
		if _op("."):
			_next()
			var nm := _expect_id()
			if _op("("):
				if e.get("k") != "var": _err("only a slot can have methods: name.method(...)", line); break
				var args := _args()
				e = {"k": "mcall", "obj": e["name"], "method": nm, "args": args, "line": line}
			else:
				e = {"k": "member", "obj": e, "name": nm, "line": line}
		elif _op("["):
			_next()
			var save := _no_gt; _no_gt = 0
			var idx := _expr()
			_no_gt = save
			_expect_op("]")
			e = {"k": "index", "obj": e, "idx": idx, "line": line}
		elif _op("++") or _op("--"):
			if e.get("k") != "var": break
			var op := str(_next()["v"])
			e = {"k": "incdec", "op": op, "prefix": false, "target": e, "line": line}
		else: break
	return e

func _args() -> Array:
	var args: Array = []
	_expect_op("(")
	var save := _no_gt; _no_gt = 0
	while error == "" and not _op(")"):
		args.append(_expr())
		if _op(","): _next()
		elif not _op(")"): _err("expected ',' or ')' in call"); break
	_no_gt = save
	_expect_op(")")
	return args

func _primary() -> Dictionary:
	var line := _line()
	var k := _peek()
	match k["t"]:
		"int", "float", "str":
			_next(); return {"k": "lit", "v": k["v"], "line": line}
		"tpl":
			_next(); return _template(str(k["v"]), line)
		"kw":
			if k["v"] in ["true", "false"]:
				_next(); return {"k": "lit", "v": 1 if k["v"] == "true" else 0, "line": line}
			if k["v"] == "null":
				_next(); return {"k": "lit", "v": "", "line": line}
		"id":
			_next()
			var nm := str(k["v"])
			if _op("("):
				if _in_global_init: _err("global starting values can't call functions", line)
				return {"k": "call", "name": nm, "args": _args(), "line": line}
			return {"k": "var", "name": nm, "line": line}
		"op":
			if k["v"] == "(":
				_next()
				var save := _no_gt; _no_gt = 0
				var e := _expr()
				_no_gt = save
				_expect_op(")")
				return e
			if k["v"] == "[":
				_next()
				var items: Array = []
				var save := _no_gt; _no_gt = 0
				while error == "" and not _op("]"):
					items.append(_expr())
					if _op(","): _next()
					elif not _op("]"): _err("expected ',' or ']' in list"); break
				_no_gt = save
				_expect_op("]")
				return {"k": "list", "items": items, "line": line}
			if k["v"] == "<":
				_next()
				var items: Array = []
				_no_gt += 1
				while error == "":
					items.append(_bin(0))
					if _op(","): _next()
					else: break
				_no_gt -= 1
				_expect_op(">")
				if items.size() != 3 and items.size() != 4: _err("a vector has 3 parts and a rotation 4", line)
				return {"k": "vec", "items": items, "line": line}
	_err("unexpected '%s'" % (str(k["v"]) if k["t"] != "eof" else "end of script"), line)
	_next()
	return {"k": "lit", "v": 0, "line": line}

## @"Hi $name, you have $(count + 1) coins. $$ is a dollar sign."
func _template(raw: String, line: int) -> Dictionary:
	var parts: Array = []
	var buf := ""
	var i := 0
	while i < raw.length():
		var c := raw[i]
		if c == "$" and i + 1 < raw.length():
			var d := raw[i + 1]
			if d == "$":
				buf += "$"; i += 2; continue
			if d == "(":
				var depth := 1
				var j := i + 2
				while j < raw.length() and depth > 0:
					if raw[j] == "(": depth += 1
					elif raw[j] == ")": depth -= 1
					j += 1
				if depth != 0: _err("template $( ) never closed", line); break
				if buf != "": parts.append(buf); buf = ""
				var sub := VsParser.new()
				var lx := VsLexer.new()
				sub.toks = lx.tokenize(raw.substr(i + 2, j - i - 3))
				if lx.error != "": _err("in template: " + lx.error, line); break
				for t in sub.toks: t["line"] = line
				var e: Dictionary = sub._expr()
				if sub.error == "" and not sub._is("eof"): sub._err("extra text in $( )")
				if sub.error != "": _err("in template: " + sub.error, line); break
				parts.append(e)
				i = j; continue
			if VsLexer._is_id_start(d):
				var j := i + 1
				while j < raw.length() and (VsLexer._is_id_start(raw[j]) or VsLexer._is_digit(raw[j])): j += 1
				if buf != "": parts.append(buf); buf = ""
				parts.append({"k": "var", "name": raw.substr(i + 1, j - i - 1), "line": line})
				i = j; continue
		buf += c; i += 1
	if buf != "": parts.append(buf)
	return {"k": "tpl", "parts": parts, "line": line}

# ---------------- checker ----------------
var _prog: Dictionary
var _scopes: Array = []
var _loop := 0

func _check(prog: Dictionary) -> void:
	_prog = prog
	var globals := {}
	for g in prog["globals"]:
		if globals.has(g["name"]) or prog["slots"].has(g["name"]): _err("'%s' declared twice" % g["name"], g["line"]); return
		if VsVM.CONSTS.has(g["name"]): _err("'%s' is a built-in constant" % g["name"], g["line"]); return
		if g["init"] != null:
			_scopes = [globals]
			_check_expr(g["init"])
		globals[g["name"]] = true
	for nm in prog["funcs"]:
		var f: Dictionary = prog["funcs"][nm]
		_scopes = [globals, _param_scope(f["params"])]
		_loop = 0
		_check_body(f["body"])
	for sn in prog["states"]:
		for ev in prog["states"][sn]["events"]:
			var h: Dictionary = prog["states"][sn]["events"][ev]
			_scopes = [globals, _param_scope(h["params"])]
			_loop = 0
			_check_body(h["body"])
		if error != "": return

func _param_scope(ps: Array) -> Dictionary:
	var s := {}
	for x in ps: s[x[1]] = true
	return s

func _declared(nm: String) -> bool:
	for s in _scopes:
		if s.has(nm): return true
	return VsVM.CONSTS.has(nm)

func _check_body(stmts: Array) -> void:
	_scopes.append({})
	for s in stmts:
		if error != "": break
		_check_stmt(s)
	_scopes.pop_back()

func _check_stmt(s: Dictionary) -> void:
	if s.is_empty(): return
	match s["k"]:
		"block": _check_body(s["body"])
		"decl":
			if s["init"] != null: _check_expr(s["init"])
			if _scopes.back().has(s["name"]): _err("'%s' declared twice here" % s["name"], s["line"])
			_scopes.back()[s["name"]] = true
		"expr": _check_expr(s["e"])
		"if":
			_check_expr(s["c"]); _check_body(s["then"]); _check_body(s["else"])
		"while", "do":
			_check_expr(s["c"]); _loop += 1; _check_body(s["body"]); _loop -= 1
		"for":
			_scopes.append({})
			for x in s["init"]: _check_stmt(x)
			if s["c"] != null: _check_expr(s["c"])
			for x in s["step"]: _check_stmt(x)
			_loop += 1; _check_body(s["body"]); _loop -= 1
			_scopes.pop_back()
		"foreach":
			_check_expr(s["iter"])
			_scopes.append({s["name"]: true})
			_loop += 1; _check_body(s["body"]); _loop -= 1
			_scopes.pop_back()
		"return":
			if s["e"] != null: _check_expr(s["e"])
		"break", "continue":
			if _loop == 0: _err("'%s' outside a loop" % s["k"], s["line"])
		"state":
			if not _prog["states"].has(s["name"]): _err("no state named '%s'" % s["name"], s["line"])

func _check_expr(e: Dictionary) -> void:
	if error != "" or e.is_empty(): return
	match e["k"]:
		"lit": pass
		"var":
			if not _declared(e["name"]):
				if _prog["slots"].has(e["name"]): _err("slot '%s' can only be used as %s.method(...)" % [e["name"], e["name"]], e["line"])
				else: _err("unknown name '%s'" % e["name"], e["line"])
		"bin": _check_expr(e["a"]); _check_expr(e["b"])
		"un", "cast": _check_expr(e["a"])
		"assign":
			var tgt: Dictionary = e["target"]
			var root: Dictionary = tgt if tgt["k"] == "var" else tgt["obj"]
			if root.get("k") != "var": _err("can only assign to a variable", e["line"]); return
			if VsVM.CONSTS.has(root["name"]): _err("can't change the constant '%s'" % root["name"], e["line"]); return
			_check_expr(tgt); _check_expr(e["value"])
		"incdec":
			if VsVM.CONSTS.has(e["target"]["name"]): _err("can't change the constant '%s'" % e["target"]["name"], e["line"]); return
			_check_expr(e["target"])
		"member":
			_check_expr(e["obj"])
			if not e["name"] in ["x", "y", "z", "s"]: _err("'.%s' isn't a vector/rotation part (use .x .y .z .s)" % e["name"], e["line"])
		"index": _check_expr(e["obj"]); _check_expr(e["idx"])
		"vec", "list":
			for x in e["items"]: _check_expr(x)
		"tpl":
			for x in e["parts"]:
				if x is Dictionary: _check_expr(x)
		"call":
			var nm: String = e["name"]
			var argc: int = e["args"].size()
			if _prog["funcs"].has(nm):
				if argc != _prog["funcs"][nm]["params"].size(): _err("%s() takes %d argument(s)" % [nm, _prog["funcs"][nm]["params"].size()], e["line"]); return
			elif VsVM.BUILTINS.has(nm):
				var ar: Array = VsVM.BUILTINS[nm]
				if argc < ar[0] or argc > ar[1]: _err("%s() takes %s argument(s)" % [nm, str(ar[0]) if ar[0] == ar[1] else "%d to %d" % ar], e["line"]); return
			else:
				_err("unknown function '%s' (scripts can only call Vala Script built-ins and their own functions)" % nm, e["line"]); return
			for a in e["args"]: _check_expr(a)
		"mcall":
			var obj: String = e["obj"]
			if not _prog["slots"].has(obj): _err("'%s' is not a slot; only slots have methods" % obj, e["line"]); return
			var api: Dictionary = VsVM.ELEMENT_API[_prog["slots"][obj]]
			if not api.has(e["method"]): _err("a %s has no method '%s' (it has %s)" % [_prog["slots"][obj], e["method"], ", ".join(api.keys())], e["line"]); return
			if e["args"].size() != int(api[e["method"]][0]): _err("%s.%s() takes %d argument(s)" % [obj, e["method"], api[e["method"]][0]], e["line"]); return
			for a in e["args"]: _check_expr(a)
