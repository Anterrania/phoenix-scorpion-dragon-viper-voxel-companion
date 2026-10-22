class_name VsVM
extends RefCounted
## Vala Script interpreter: one running script (our own sandboxed language, NOT GNOME Vala).
## Tree-walking interpreter over the VsParser AST. The sandbox is structural: the only things a
## script can reach are the built-ins below and its own linked element slots. Every built-in that
## changes the world goes through `host` (VsEngine), which checks Tiers.can, the estate
## allow_scripts flag, rate limits and the e-stop. There is no file, OS, node, class or engine access.
##
## Limits (per script): BUDGET steps per event, MEMORY_CAP bytes (estimated), MAX_CALL_DEPTH,
## MAX_QUEUE pending events, MAX_LISTENS listeners. Going over a limit stops the script with a
## reason and a line number (like a crashed LSL script); the owner can reset it.

const BUDGET := 20000
const MEMORY_CAP := 65536
const MAX_CALL_DEPTH := 64
const MAX_QUEUE := 64
const MAX_LISTENS := 16
const MAX_STRING := 16384

## event -> parameter types
const EVENTS := {
	"state_entry": [], "state_exit": [], "on_rez": ["integer"], "changed": ["integer"],
	"touch_start": ["integer"], "touch": ["integer"], "touch_end": ["integer"],
	"collision_start": ["integer"], "collision": ["integer"], "collision_end": ["integer"],
	"timer": [], "listen": ["integer", "string", "key", "string"],
	"sensor": ["integer"], "no_sensor": [], "http_response": ["key", "integer", "string"],
	# Dual Universe-style unit events
	"start": [], "stop": [], "tick": ["string"], "update": ["float"], "flush": ["float"],
	"element": ["string", "string"],
}
## built-in -> [min args, max args]
const BUILTINS := {
	# chat
	"say": [1, 2], "whisper": [1, 2], "shout": [1, 2], "region_say": [2, 2], "owner_say": [1, 1],
	"listen": [1, 4], "listen_remove": [1, 1],
	# object
	"set_text": [1, 3], "set_color": [1, 1], "set_alpha": [1, 1], "get_pos": [0, 0], "set_pos": [1, 1],
	"get_rot": [0, 0], "set_rot": [1, 1], "get_owner": [0, 0], "get_key": [0, 0], "get_name": [0, 0],
	"rez": [2, 2], "give_item": [2, 2], "teleport": [2, 2], "die": [0, 0],
	# timers + sensing
	"timer": [1, 1], "start_timer": [2, 2], "stop_timer": [1, 1], "sensor": [2, 2], "sensor_remove": [0, 0],
	"detected_key": [1, 1], "detected_name": [1, 1], "detected_pos": [1, 1],
	# net (off by default)
	"http_request": [3, 3],
	# script
	"reset_script": [0, 0], "get_state": [0, 0], "time": [0, 0], "now": [0, 0], "free_memory": [0, 0],
	"debug": [1, 1],
	# strings
	"length": [1, 1], "substr": [2, 3], "index_of": [2, 2], "to_upper": [1, 1], "to_lower": [1, 1],
	"trim": [1, 1], "replace": [3, 3], "split": [2, 2], "join": [2, 2], "contains": [2, 2],
	# lists
	"list_slice": [3, 3], "list_find": [2, 2], "list_insert": [3, 3], "list_remove": [2, 2], "list_sort": [1, 1],
	# math
	"abs": [1, 1], "floor": [1, 1], "ceil": [1, 1], "round": [1, 1], "sqrt": [1, 1], "pow": [2, 2],
	"min": [2, 2], "max": [2, 2], "sin": [1, 1], "cos": [1, 1], "tan": [1, 1], "atan2": [2, 2],
	"rand": [1, 1], "vec_mag": [1, 1], "vec_norm": [1, 1], "vec_dist": [2, 2], "euler_to_rot": [1, 1],
	"rot_to_euler": [1, 1],
}
## Built-ins that change the world (gated by VsEngine.world_ok).
const WORLD_CALLS := ["set_text", "set_color", "set_alpha", "set_pos", "set_rot", "rez", "give_item", "teleport", "die"]
const CONSTS := {
	"PI": PI, "TWO_PI": TAU, "PI_BY_TWO": PI / 2.0, "DEG_TO_RAD": PI / 180.0, "RAD_TO_DEG": 180.0 / PI,
	"ZERO_VECTOR": Vector3.ZERO, "ZERO_ROTATION": Quaternion.IDENTITY, "NULL_KEY": "00000000-0000-0000-0000-000000000000",
	"PUBLIC_CHANNEL": 0, "DEBUG_CHANNEL": 2147483647, "TRUE": 1, "FALSE": 0, "EOF": "\n\n\n",
	"CHANGED_INVENTORY": 1, "CHANGED_COLOR": 2, "CHANGED_SHAPE": 4, "CHANGED_SCALE": 8, "CHANGED_TEXTURE": 16,
	"CHANGED_LINK": 32, "CHANGED_ALLOWED_DROP": 64, "CHANGED_OWNER": 128, "CHANGED_REGION": 256,
	"CHANGED_TELEPORT": 512, "CHANGED_REGION_START": 1024,
}
## Dual Universe-style elements. type -> {method: [argc, world_changing, returns]}
const ELEMENT_API := {
	"door": {"open": [0, true], "close": [0, true], "toggle": [0, true], "is_open": [0, false]},
	"light": {"on": [0, true], "off": [0, true], "toggle": [0, true], "is_on": [0, false],
		"set_color": [1, true], "set_intensity": [1, true]},
	"screen": {"clear": [0, true], "text": [3, true], "rect": [4, true], "line": [4, true], "circle": [3, true],
		"set_color": [1, true], "set_background": [1, true], "flush": [0, true], "width": [0, false], "height": [0, false]},
	"engine": {"set_thrust": [1, true], "get_thrust": [0, false], "max_thrust": [0, false]},
	"container": {"count": [0, false], "items": [0, false], "capacity": [0, false]},
	"sensor": {"detected": [0, false], "range": [0, false], "set_range": [1, true]},
	"button": {"is_pressed": [0, false]},
}
const SCREEN_W := 320
const SCREEN_H := 180
const SCREEN_MAX_OPS := 256

var program: Dictionary
var id := ""
var name := "script"
var host = null              # VsEngine (or a test double); null = pure computation only
var globals := {}
var gtypes := {}
var state := "default"
var running := true
var error := ""
var error_line := 0
var queue: Array = []
var listens := {}            # handle -> {channel, name, key, msg}
var next_listen := 1
var timer_period := 0.0
var timer_left := 0.0
var named_timers := {}       # id -> [period, left]
var sensor_req := {}         # {name, range}
var detected: Array = []     # [{key, name, pos}]
var steps := 0
var total_steps := 0
var _depth := 0
var _pending_state := ""
var _in_event := ""
var _ret = null
var _abort := false
var _started := false

enum { OK, BRK, CONT, RET, STATE, ABORT }

func _init(prog: Dictionary, script_id := "", script_name := "script") -> void:
	program = prog; id = script_id; name = script_name
	_reset_globals()

func _reset_globals() -> void:
	globals = {}; gtypes = {}
	steps = 0
	for g in program["globals"]:
		gtypes[g["name"]] = g["type"]
		var v = default_of(g["type"]) if g["init"] == null else _eval(g["init"], [globals])
		if g["type"] != "var": v = coerce(g["type"], v, g["line"])
		globals[g["name"]] = v

static func default_of(t: String) -> Variant:
	match t:
		"integer": return 0
		"float": return 0.0
		"string", "key": return ""
		"vector": return Vector3.ZERO
		"rotation": return Quaternion.IDENTITY
		"list": return []
	return 0

func coerce(t: String, v: Variant, line := 0) -> Variant:
	match t:
		"integer":
			if v is int: return v
			if v is float: return int(v)
			if v is String: return v.to_int()
		"float":
			if v is float: return v
			if v is int: return float(v)
			if v is String: return v.to_float()
		"string", "key":
			return to_str(v)
		"vector":
			if v is Vector3: return v
		"rotation":
			if v is Quaternion: return v
		"list":
			if v is Array: return v
			return [v]
		"var": return v
	_fail("type mismatch: can't use %s as %s" % [type_name(v), t], line)
	return default_of(t)

static func type_name(v: Variant) -> String:
	if v is int: return "integer"
	if v is float: return "float"
	if v is String: return "string"
	if v is Vector3: return "vector"
	if v is Quaternion: return "rotation"
	if v is Array: return "list"
	return "unknown"

static func to_str(v: Variant) -> String:
	if v is String: return v
	if v is int: return str(v)
	if v is float: return "%.6f" % v
	if v is Vector3: return "<%.5f, %.5f, %.5f>" % [v.x, v.y, v.z]
	if v is Quaternion: return "<%.5f, %.5f, %.5f, %.5f>" % [v.x, v.y, v.z, v.w]
	if v is Array:
		var s := ""
		for x in v: s += to_str(x)
		return s
	return str(v)

static func truthy(v: Variant) -> bool:
	if v is int or v is float: return v != 0
	if v is String: return v != ""
	if v is Vector3: return v != Vector3.ZERO
	if v is Quaternion: return v != Quaternion.IDENTITY
	if v is Array: return not v.is_empty()
	return false

static func mem_of(v: Variant) -> int:
	if v is String: return 16 + v.length()
	if v is Array:
		var n := 16
		for x in v: n += mem_of(x)
		return n
	if v is Vector3: return 24
	if v is Quaternion: return 32
	return 8

func memory_used() -> int:
	var n := 0
	for k in globals: n += mem_of(globals[k])
	return n

func _fail(msg: String, line := 0) -> void:
	if not running: return
	running = false; _abort = true
	error = msg; error_line = line
	if host != null and host.has_method("script_error"): host.script_error(self, msg, line)

# ---------------- events ----------------
func start() -> void:
	if _started: return
	_started = true
	post("state_entry", [])
	post("start", [])

## Queue an event if the current state handles it (LSL drops events with no handler).
func post(ev: String, args: Array, det: Array = []) -> bool:
	if not running or not handles(ev): return false
	if queue.size() >= MAX_QUEUE: queue.pop_front()
	queue.append([ev, args, det])
	return true

func handles(ev: String) -> bool:
	return program["states"].has(state) and program["states"][state]["events"].has(ev)

## Run queued events. Returns how many ran.
func run_queue(max_events := 8) -> int:
	var n := 0
	while running and not queue.is_empty() and n < max_events:
		var q: Array = queue.pop_front()
		run_event(q[0], q[1], q[2])
		n += 1
	return n

func run_event(ev: String, args: Array, det: Array = []) -> void:
	if not running or not handles(ev): return
	if host != null and host.has_method("may_run") and not host.may_run(self): return
	var h: Dictionary = program["states"][state]["events"][ev]
	var scope := {}
	var types := {}
	for i in h["params"].size():
		var pt: String = h["params"][i][0]
		scope[h["params"][i][1]] = coerce(pt, args[i] if i < args.size() else default_of(pt), h["line"])
		types[h["params"][i][1]] = pt
	detected = det
	steps = 0; _abort = false; _pending_state = ""; _depth = 0; _in_event = ev
	_exec(h["body"], [globals, scope], [{}, types])
	total_steps += steps
	_in_event = ""
	if running and memory_used() > MEMORY_CAP: _fail("out of memory (%d of %d bytes)" % [memory_used(), MEMORY_CAP], h["line"])
	if running and _pending_state != "": _change_state(_pending_state)

func _change_state(to: String) -> void:
	if to == state: return
	run_event("state_exit", [])
	if not running: return
	state = to
	listens.clear()          # listeners belong to the state they were opened in
	queue.clear()
	sensor_req = {}
	run_event("state_entry", [])

func reset() -> void:
	running = true; error = ""; error_line = 0; state = "default"; queue.clear(); listens.clear()
	timer_period = 0.0; named_timers.clear(); sensor_req = {}; _started = false; total_steps = 0
	_reset_globals()
	start()

## Advance timers by dt seconds (VsEngine calls this from its tick).
func advance(dt: float) -> void:
	if not running: return
	if timer_period > 0.0:
		timer_left -= dt
		if timer_left <= 0.0:
			timer_left += timer_period
			if timer_left <= 0.0: timer_left = timer_period
			if not _queued("timer"): post("timer", [])
	for tid in named_timers.keys():
		var t: Array = named_timers[tid]
		t[1] -= dt
		if t[1] <= 0.0:
			t[1] = t[0]
			post("tick", [tid])

func _queued(ev: String) -> bool:
	for q in queue:
		if q[0] == ev: return true
	return false

# ---------------- statements ----------------
func _tick_step(line: int) -> bool:
	steps += 1
	if steps > BUDGET:
		_fail("ran out of steps (budget %d per event)" % BUDGET, line)
		return false
	return not _abort

func _exec(stmts: Array, env: Array, tenv: Array) -> int:
	env.append({}); tenv.append({})
	var r := OK
	for s in stmts:
		r = _stmt(s, env, tenv)
		if r != OK: break
	env.pop_back(); tenv.pop_back()
	return r

func _stmt(s: Dictionary, env: Array, tenv: Array) -> int:
	if s.is_empty(): return OK
	if not _tick_step(s["line"]): return ABORT
	match s["k"]:
		"block": return _exec(s["body"], env, tenv)
		"decl":
			var ty: String = s["type"]
			var v = default_of(ty) if s["init"] == null else _eval(s["init"], env)
			if _abort: return ABORT
			if ty != "var": v = coerce(ty, v, s["line"])
			env.back()[s["name"]] = v
			tenv.back()[s["name"]] = ty
		"expr":
			_eval(s["e"], env, tenv)
		"if":
			var c = _eval(s["c"], env, tenv)
			if _abort: return ABORT
			return _exec(s["then"] if truthy(c) else s["else"], env, tenv)
		"while":
			while true:
				var c = _eval(s["c"], env, tenv)
				if _abort: return ABORT
				if not truthy(c): break
				var r := _exec(s["body"], env, tenv)
				if r == BRK: break
				if r in [RET, STATE, ABORT]: return r
				if not _tick_step(s["line"]): return ABORT
		"do":
			while true:
				var r := _exec(s["body"], env, tenv)
				if r == BRK: break
				if r in [RET, STATE, ABORT]: return r
				var c = _eval(s["c"], env, tenv)
				if _abort: return ABORT
				if not truthy(c): break
		"for":
			env.append({}); tenv.append({})
			var out := OK
			for x in s["init"]: _stmt(x, env, tenv)
			while not _abort:
				if s["c"] != null and not truthy(_eval(s["c"], env, tenv)): break
				if _abort: break
				var r := _exec(s["body"], env, tenv)
				if r == BRK: break
				if r in [RET, STATE, ABORT]: out = r; break
				for x in s["step"]: _stmt(x, env, tenv)
			env.pop_back(); tenv.pop_back()
			return ABORT if _abort else out
		"foreach":
			var it = _eval(s["iter"], env, tenv)
			if _abort: return ABORT
			var seq: Array = []
			if it is Array: seq = it
			elif it is String:
				for ch in it: seq.append(ch)
			else: _fail("foreach needs a list or string", s["line"]); return ABORT
			for x in seq:
				env.append({s["name"]: x}); tenv.append({s["name"]: s["type"]})
				var r := _exec(s["body"], env, tenv)
				env.pop_back(); tenv.pop_back()
				if r == BRK: break
				if r in [RET, STATE, ABORT]: return r
		"return":
			_ret = null if s["e"] == null else _eval(s["e"], env, tenv)
			return ABORT if _abort else RET
		"break": return BRK
		"continue": return CONT
		"state":
			_pending_state = s["name"]
			return STATE
	return ABORT if _abort else OK

# ---------------- expressions ----------------
func _find(nm: String, env: Array) -> int:
	for i in range(env.size() - 1, -1, -1):
		if env[i].has(nm): return i
	return -1

func _type_of(nm: String, env: Array, tenv: Array) -> String:
	var i := _find(nm, env)
	if i == 0: return str(gtypes.get(nm, "var"))
	if i > 0 and i < tenv.size(): return str(tenv[i].get(nm, "var"))
	return "var"

func _eval(e: Dictionary, env: Array, tenv: Array = []) -> Variant:
	if _abort or e.is_empty(): return 0
	if not _tick_step(e.get("line", 0)): return 0
	var line: int = e.get("line", 0)
	match e["k"]:
		"lit": return e["v"]
		"var":
			var i := _find(e["name"], env)
			if i >= 0: return env[i][e["name"]]
			if CONSTS.has(e["name"]): return CONSTS[e["name"]]
			_fail("unknown name '%s'" % e["name"], line); return 0
		"tpl":
			var s := ""
			for x in e["parts"]:
				s += x if x is String else to_str(_eval(x, env, tenv))
			return _cap_str(s, line)
		"vec":
			var p: Array = []
			for x in e["items"]:
				var v = _eval(x, env, tenv)
				if not (v is int or v is float): _fail("vector parts must be numbers", line); return 0
				p.append(float(v))
			return Vector3(p[0], p[1], p[2]) if p.size() == 3 else Quaternion(p[0], p[1], p[2], p[3])
		"list":
			var out: Array = []
			for x in e["items"]:
				var v = _eval(x, env, tenv)
				if v is Array: _fail("a list can't hold another list", line); return []
				out.append(v)
			return out
		"un":
			var a = _eval(e["a"], env, tenv)
			match e["op"]:
				"!": return 0 if truthy(a) else 1
				"-":
					if a is int or a is float or a is Vector3: return -a
					if a is Quaternion: return a.inverse()
				"~":
					if a is int: return ~a
			_fail("can't use %s on %s" % [e["op"], type_name(a)], line); return 0
		"cast": return coerce(e["type"], _eval(e["a"], env, tenv), line)
		"bin":
			if e["op"] == "&&":
				return 1 if truthy(_eval(e["a"], env, tenv)) and truthy(_eval(e["b"], env, tenv)) else 0
			if e["op"] == "||":
				return 1 if truthy(_eval(e["a"], env, tenv)) or truthy(_eval(e["b"], env, tenv)) else 0
			return binop(e["op"], _eval(e["a"], env, tenv), _eval(e["b"], env, tenv), line)
		"assign":
			var tgt: Dictionary = e["target"]
			var rhs = _eval(e["value"], env, tenv)
			if _abort: return 0
			var vn: String = tgt["name"] if tgt["k"] == "var" else tgt["obj"]["name"]
			var i := _find(vn, env)
			if i < 0: _fail("unknown name '%s'" % vn, line); return 0
			var cur = env[i][vn]
			var nv
			if tgt["k"] == "var":
				nv = rhs if e["op"] == "=" else binop(e["op"].left(1), cur, rhs, line)
				var ty := _type_of(vn, env, tenv)
				if ty != "var": nv = coerce(ty, nv, line)
			else:
				var part: String = tgt["name"]
				var old = _member(cur, part, line)
				var pv = rhs if e["op"] == "=" else binop(e["op"].left(1), old, rhs, line)
				nv = _set_member(cur, part, float(pv) if (pv is int or pv is float) else 0.0, line)
			if _abort: return 0
			if mem_of(nv) > MEMORY_CAP: _fail("out of memory", line); return 0
			env[i][vn] = nv
			return nv
		"incdec":
			var vn: String = e["target"]["name"]
			var i := _find(vn, env)
			if i < 0: _fail("unknown name '%s'" % vn, line); return 0
			var cur = env[i][vn]
			if not (cur is int or cur is float): _fail("++/-- needs a number", line); return 0
			var nv = cur + (1 if e["op"] == "++" else -1)
			env[i][vn] = nv
			return nv if e["prefix"] else cur
		"member": return _member(_eval(e["obj"], env, tenv), e["name"], line)
		"index":
			var o = _eval(e["obj"], env, tenv)
			var ix = _eval(e["idx"], env, tenv)
			if not ix is int: _fail("index must be an integer", line); return 0
			if o is Array or o is String:
				var n: int = o.size() if o is Array else o.length()
				var k: int = ix if ix >= 0 else n + ix
				if k < 0 or k >= n: return "" if o is String else 0
				return o[k]
			_fail("can only index a list or string", line); return 0
		"call": return _call(e, env, tenv)
		"mcall":
			var args: Array = []
			for a in e["args"]: args.append(_eval(a, env, tenv))
			if _abort: return 0
			if host == null or not host.has_method("element_call"): return 0
			return host.element_call(self, str(e["obj"]), str(e["method"]), args, line)
	_fail("can't evaluate '%s'" % e["k"], line)
	return 0

func _cap_str(s: String, line: int) -> String:
	if s.length() > MAX_STRING: _fail("string too long (max %d)" % MAX_STRING, line); return ""
	return s

func _member(v: Variant, part: String, line: int) -> Variant:
	if v is Vector3 and part in ["x", "y", "z"]: return v[["x", "y", "z"].find(part)]
	if v is Quaternion:
		match part:
			"x": return v.x
			"y": return v.y
			"z": return v.z
			"s": return v.w
	_fail("'.%s' needs a vector or rotation" % part, line)
	return 0.0

func _set_member(v: Variant, part: String, f: float, line: int) -> Variant:
	if v is Vector3 and part in ["x", "y", "z"]:
		v[["x", "y", "z"].find(part)] = f; return v
	if v is Quaternion:
		match part:
			"x": v.x = f
			"y": v.y = f
			"z": v.z = f
			"s": v.w = f
		return v
	_fail("'.%s' needs a vector or rotation" % part, line)
	return v

func binop(op: String, a: Variant, b: Variant, line: int) -> Variant:
	if _abort: return 0
	var num_a: bool = a is int or a is float
	var num_b: bool = b is int or b is float
	match op:
		"+":
			if a is Array:
				var r: Array = a.duplicate()
				if b is Array: r.append_array(b)
				else: r.append(b)
				if r.size() > 4096 or mem_of(r) > MEMORY_CAP: _fail("out of memory (list too big)", line); return []
				return r
			if b is Array:
				var r: Array = [a]; r.append_array(b); return r
			if a is String or b is String: return _cap_str(to_str(a) + to_str(b), line)
			if num_a and num_b: return a + b
			if a is Vector3 and b is Vector3: return a + b
			if a is Quaternion and b is Quaternion: return a + b
		"-":
			if num_a and num_b: return a - b
			if a is Vector3 and b is Vector3: return a - b
			if a is Quaternion and b is Quaternion: return a - b
		"*":
			if num_a and num_b: return a * b
			if a is Vector3 and num_b: return a * float(b)
			if num_a and b is Vector3: return b * float(a)
			if a is Vector3 and b is Vector3: return a.dot(b)
			if a is Vector3 and b is Quaternion: return b * a
			if a is Quaternion and b is Quaternion: return b * a   # LSL order: a then b
		"/":
			if num_b and float(b) == 0.0: _fail("math error: divide by zero", line); return 0
			if a is int and b is int: return a / b
			if num_a and num_b: return float(a) / float(b)
			if a is Vector3 and num_b: return a / float(b)
			if a is Vector3 and b is Quaternion: return b.inverse() * a
			if a is Quaternion and b is Quaternion: return b.inverse() * a
		"%":
			if a is int and b is int:
				if b == 0: _fail("math error: modulo by zero", line); return 0
				return a % b
			if a is Vector3 and b is Vector3: return a.cross(b)
		"==":
			if num_a and num_b: return 1 if float(a) == float(b) else 0
			return 1 if typeof(a) == typeof(b) and a == b else 0
		"!=":
			if num_a and num_b: return 1 if float(a) != float(b) else 0
			return 0 if typeof(a) == typeof(b) and a == b else 1
		"<", ">", "<=", ">=":
			if num_a and num_b or (a is String and b is String):
				match op:
					"<": return 1 if a < b else 0
					">": return 1 if a > b else 0
					"<=": return 1 if a <= b else 0
					">=": return 1 if a >= b else 0
		"&": if a is int and b is int: return a & b
		"|": if a is int and b is int: return a | b
		"^": if a is int and b is int: return a ^ b
	_fail("can't use %s on %s and %s" % [op, type_name(a), type_name(b)], line)
	return 0

# ---------------- calls ----------------
func _call(e: Dictionary, env: Array, tenv: Array) -> Variant:
	var nm: String = e["name"]
	var line: int = e["line"]
	var args: Array = []
	for a in e["args"]: args.append(_eval(a, env, tenv))
	if _abort: return 0
	if program["funcs"].has(nm):
		var f: Dictionary = program["funcs"][nm]
		_depth += 1
		if _depth > MAX_CALL_DEPTH: _fail("functions call each other too deeply (max %d)" % MAX_CALL_DEPTH, line); return 0
		var scope := {}
		var types := {}
		for i in f["params"].size():
			scope[f["params"][i][1]] = coerce(f["params"][i][0], args[i], line)
			types[f["params"][i][1]] = f["params"][i][0]
		_ret = null
		var r := _exec(f["body"], [globals, scope], [{}, types])
		_depth -= 1
		var out = _ret
		_ret = null
		if r == STATE: _fail("'state' can't be used inside a function", line); return 0
		if out == null: return default_of(f["ret"]) if f["ret"] != "void" else 0
		return coerce(f["ret"], out, line) if f["ret"] != "void" else 0
	return builtin(nm, args, line)

func _n(v: Variant, line: int) -> float:
	if v is int or v is float: return float(v)
	_fail("expected a number, got %s" % type_name(v), line)
	return 0.0

func _s(v: Variant) -> String: return to_str(v)

func _world(nm: String, args: Array, line: int) -> Variant:
	if host == null: return 0
	return host.world_call(self, nm, args, line)

func builtin(nm: String, a: Array, line: int) -> Variant:
	if nm in WORLD_CALLS: return _world(nm, a, line)
	match nm:
		"say", "whisper", "shout":
			var ch := 0 if a.size() == 1 else int(_n(a[0], line))
			var msg := _s(a[-1]).left(1024)
			if host: host.chat(self, nm, ch, msg, line)
			return 0
		"region_say":
			if host: host.chat(self, "region", int(_n(a[0], line)), _s(a[1]).left(1024), line)
			return 0
		"owner_say":
			if host: host.chat(self, "owner", 0, _s(a[0]).left(1024), line)
			return 0
		"debug":
			if host: host.log_line(self, _s(a[0]).left(512), line, "debug")
			return 0
		"listen":
			if listens.size() >= MAX_LISTENS: _fail("too many listeners (max %d)" % MAX_LISTENS, line); return 0
			var h := next_listen
			next_listen += 1
			listens[h] = {"channel": int(_n(a[0], line)), "name": _s(a[1]) if a.size() > 1 else "",
				"key": _s(a[2]) if a.size() > 2 else "", "msg": _s(a[3]) if a.size() > 3 else ""}
			return h
		"listen_remove":
			listens.erase(int(_n(a[0], line))); return 0
		"get_pos": return host.object_get(self, "pos") if host else Vector3.ZERO
		"get_rot": return host.object_get(self, "rot") if host else Quaternion.IDENTITY
		"get_owner": return host.object_get(self, "owner") if host else ""
		"get_key": return host.object_get(self, "key") if host else id
		"get_name": return host.object_get(self, "name") if host else name
		"timer":
			var t := _n(a[0], line)
			timer_period = 0.0 if t <= 0.0 else maxf(t, 0.1)
			timer_left = timer_period
			return 0
		"start_timer":
			if named_timers.size() >= 8 and not named_timers.has(_s(a[0])): _fail("too many timers (max 8)", line); return 0
			var t := maxf(_n(a[1], line), 0.1)
			named_timers[_s(a[0])] = [t, t]
			return 0
		"stop_timer": named_timers.erase(_s(a[0])); return 0
		"sensor":
			sensor_req = {"name": _s(a[0]), "range": clampf(_n(a[1], line), 0.0, 96.0)}
			if host: host.sensor_scan(self)
			return 0
		"sensor_remove": sensor_req = {}; return 0
		"detected_key", "detected_name", "detected_pos":
			var i := int(_n(a[0], line))
			if i < 0 or i >= detected.size(): return Vector3.ZERO if nm == "detected_pos" else ""
			var d: Dictionary = detected[i]
			return d.get({"detected_key": "key", "detected_name": "name", "detected_pos": "pos"}[nm], "")
		"http_request":
			if host == null: return ""
			return host.http(self, _s(a[0]), _s(a[1]), _s(a[2]), line)
		"reset_script":
			if host: host.request_reset(self)
			_abort = true
			return 0
		"get_state": return state
		"time": return host.clock if host else 0.0
		"now": return int(Time.get_unix_time_from_system())
		"free_memory": return MEMORY_CAP - memory_used()
		"length":
			if a[0] is Array: return a[0].size()
			return _s(a[0]).length()
		"substr":
			var s := _s(a[0])
			return s.substr(int(_n(a[1], line)), int(_n(a[2], line)) if a.size() > 2 else -1)
		"index_of": return _s(a[0]).find(_s(a[1]))
		"contains":
			if a[0] is Array: return 1 if a[0].has(a[1]) else 0
			return 1 if _s(a[0]).contains(_s(a[1])) else 0
		"to_upper": return _s(a[0]).to_upper()
		"to_lower": return _s(a[0]).to_lower()
		"trim": return _s(a[0]).strip_edges()
		"replace": return _cap_str(_s(a[0]).replace(_s(a[1]), _s(a[2])), line)
		"split":
			var sep := _s(a[1])
			if sep == "": _fail("split needs a separator", line); return []
			var parts := _s(a[0]).split(sep)
			if parts.size() > 1024: _fail("out of memory (split)", line); return []
			return Array(parts)
		"join":
			if not a[0] is Array: return _s(a[0])
			var ss: PackedStringArray = []
			for x in a[0]: ss.append(to_str(x))
			return _cap_str(_s(a[1]).join(ss), line)
		"list_slice":
			if not a[0] is Array: _fail("list_slice needs a list", line); return []
			return a[0].slice(int(_n(a[1], line)), int(_n(a[2], line)))
		"list_find":
			if not a[0] is Array: return -1
			return a[0].find(a[1])
		"list_insert":
			if not a[0] is Array: _fail("list_insert needs a list", line); return []
			var r: Array = a[0].duplicate()
			r.insert(clampi(int(_n(a[2], line)), 0, r.size()), a[1])
			return r
		"list_remove":
			if not a[0] is Array: _fail("list_remove needs a list", line); return []
			var r: Array = a[0].duplicate()
			var k := int(_n(a[1], line))
			if k >= 0 and k < r.size(): r.remove_at(k)
			return r
		"list_sort":
			if not a[0] is Array: return []
			var r: Array = a[0].duplicate()
			r.sort_custom(func(x, y): return str(x) < str(y) if not ((x is int or x is float) and (y is int or y is float)) else x < y)
			return r
		"abs":
			return absi(a[0]) if a[0] is int else absf(_n(a[0], line))
		"floor": return int(floor(_n(a[0], line)))
		"ceil": return int(ceil(_n(a[0], line)))
		"round": return int(round(_n(a[0], line)))
		"sqrt":
			var x := _n(a[0], line)
			if x < 0.0: _fail("math error: sqrt of a negative number", line); return 0.0
			return sqrt(x)
		"pow": return pow(_n(a[0], line), _n(a[1], line))
		"min": return a[0] if _n(a[0], line) <= _n(a[1], line) else a[1]
		"max": return a[0] if _n(a[0], line) >= _n(a[1], line) else a[1]
		"sin": return sin(_n(a[0], line))
		"cos": return cos(_n(a[0], line))
		"tan": return tan(_n(a[0], line))
		"atan2": return atan2(_n(a[0], line), _n(a[1], line))
		"rand": return randf() * _n(a[0], line)
		"vec_mag": return a[0].length() if a[0] is Vector3 else 0.0
		"vec_norm": return a[0].normalized() if a[0] is Vector3 else Vector3.ZERO
		"vec_dist": return a[0].distance_to(a[1]) if a[0] is Vector3 and a[1] is Vector3 else 0.0
		"euler_to_rot":
			if not a[0] is Vector3: _fail("euler_to_rot needs a vector", line); return Quaternion.IDENTITY
			return Quaternion.from_euler(a[0])
		"rot_to_euler":
			if not a[0] is Quaternion: _fail("rot_to_euler needs a rotation", line); return Vector3.ZERO
			return a[0].get_euler()
	_fail("unknown function '%s'" % nm, line)
	return 0
