class_name VsEngine
extends RefCounted
## Vala Script runtime: objects, running scripts, the chat bus, elements (slots), timers and gates.
## One instance per region simulator (tests make their own). Pure data out: everything a script does
## to the world becomes an entry in `effects` (and the `effect` signal) that the client renders.
##
## Gates, in order, for every world-changing call (set_text, set_color, set_pos, rez, give_item,
## teleport, die, and element methods marked world-changing):
##   1. e-stop (AutonomyGuard.paused()) -> every script halts; nothing runs until the owner resumes.
##   2. estate/parcel `allow_scripts` (or `allow_group_scripts` for land-group members) for the
##      object's parcel. The unlocked owner (Tiers.owner_session()) overrides it.
##   3. Tiers.can(script_owner, "build", {region, parcel}) (teleport: "enter" on the destination).
##   4. per-script rate limits (RATES).
## Companion (bot) authors never start a script directly: load_script() files an owner-approval
## proposal through EveCore.propose_update and the script waits until the owner approves it.

signal effect(e: Dictionary)

const RATES := {"chat": [20, 10.0], "world": [40, 10.0], "rez": [5, 10.0], "give": [10, 10.0],
	"teleport": [2, 10.0], "http": [5, 20.0], "screen": [30, 1.0]}
const CHAT_RANGE := {"whisper": 10.0, "say": 20.0, "shout": 100.0}
const MAX_SCRIPTS_PER_OBJECT := 16
const MAX_EFFECTS := 512
const MAX_LOG := 200
const UPDATE_HZ := 10.0          # DU-style update/flush events are throttled to 10 per second

var objects := {}       # id -> {key, name, owner, region, parcel, pos, rot, text, color, alpha, alive}
var scripts := {}       # script id -> VsVM
var script_object := {} # script id -> object id
var pending := {}       # script id -> {object, src, owner, name, proposal}
var elements := {}      # element id -> {type, object, state: {}}
var links := {}         # script id -> {slot: element id}
var effects: Array = []
var log: Array = []     # debug console: {script, level, line, msg, t}
var clock := 0.0
var halted := false
var _rate := {}         # "script|kind" -> [times]
var _resets: Array = []
var _upd_acc := 0.0
var _seq := 0
## Owner-controlled HTTP: off by default, https only, host allowlist.
var http_enabled := false
var http_allow: Array = []
var http_queue: Array = []
## Who is nearby for sensor(): Callable(object) -> Array of {key, name, pos}. Tests set it.
var sensor_source: Callable

# ---------------- objects + scripts ----------------
func add_object(oid: String, owner: String, region: String, parcel := "", pos := Vector3.ZERO, nm := "Object") -> Dictionary:
	var o := {"key": oid, "name": nm.left(63), "owner": owner, "region": region, "parcel": parcel, "pos": pos,
		"rot": Quaternion.IDENTITY, "text": "", "color": Vector3.ONE, "alpha": 1.0, "alive": true}
	objects[oid] = o
	return o

func scripts_on(oid: String) -> Array:
	return script_object.keys().filter(func(s): return script_object[s] == oid)

## Compile + start (or queue for approval). Returns {ok, id, error, line, pending, proposal}.
func load_script(oid: String, src: String, author: String, nm := "script") -> Dictionary:
	if not objects.has(oid): return {"ok": false, "error": "no such object", "line": 0}
	if scripts_on(oid).size() + pending.values().filter(func(p): return p["object"] == oid).size() >= MAX_SCRIPTS_PER_OBJECT:
		return {"ok": false, "error": "too many scripts in this object (max %d)" % MAX_SCRIPTS_PER_OBJECT, "line": 0}
	var c := VsParser.new().compile(src)
	if not c["ok"]: return c
	_seq += 1
	var sid := "%s#%d" % [oid, _seq]
	if Tiers.is_bot(author) and author != Tiers.OWNER_ID:
		var prop: Dictionary = EveCore.for_companion(author).propose_update(
			"Run Vala Script '%s' in %s (%d lines). Source kept for review." % [nm.left(40), oid, src.count("\n") + 1])
		pending[sid] = {"object": oid, "src": src, "owner": author, "name": nm, "proposal": prop["id"], "program": c["program"]}
		return {"ok": true, "id": sid, "pending": true, "proposal": prop["id"], "error": "", "line": 0}
	_start(sid, oid, c["program"], nm)
	return {"ok": true, "id": sid, "pending": false, "error": "", "line": 0}

func _start(sid: String, oid: String, prog: Dictionary, nm: String) -> void:
	var vm := VsVM.new(prog, sid, nm)
	vm.host = self
	scripts[sid] = vm
	script_object[sid] = oid
	vm.start()
	_pump(vm)

## Start companion scripts whose proposal the owner approved; drop rejected ones. Returns started ids.
func activate_approved() -> Array:
	var started: Array = []
	var states := {}
	for p in EveCore.proposals(): states[p["id"]] = p["state"]
	for sid in pending.keys():
		var st := str(states.get(pending[sid]["proposal"], ""))
		if st == "Approved":
			var p: Dictionary = pending[sid]
			pending.erase(sid)
			_start(sid, p["object"], p["program"], p["name"])
			started.append(sid)
		elif st == "Rejected" or st == "":
			if st == "Rejected": pending.erase(sid)
	return started

func remove_script(sid: String) -> void:
	scripts.erase(sid); script_object.erase(sid); links.erase(sid); pending.erase(sid)

func owner_of(vm) -> String: return str(objects.get(script_object.get(vm.id, ""), {}).get("owner", ""))
func obj_of(vm) -> Dictionary: return objects.get(script_object.get(vm.id, ""), {})

# ---------------- gates ----------------
func _owner_override(vm) -> bool:
	return owner_of(vm) == Tiers.OWNER_ID and Tiers.owner_session()

func scripts_allowed(vm) -> bool:
	var o := obj_of(vm)
	if o.is_empty(): return false
	if _owner_override(vm): return true
	var r: String = o["region"]
	var pc: String = o["parcel"]
	var allow = Estate.parcel_get(r, pc, "allow_scripts") if pc != "" else Estate.region_get(r, "allow_scripts")
	if bool(allow): return true
	var grp = Estate.parcel_get(r, pc, "allow_group_scripts") if pc != "" else Estate.region_get(r, "allow_group_scripts")
	return bool(grp) and Tiers._in_land_group(owner_of(vm), {"region": r, "parcel": pc})

func estop_check() -> bool:
	if AutonomyGuard.paused() and not halted: halt_all("emergency stop")
	return halted

## Halts every script (e-stop or owner). Queues are dropped; state is kept for inspection.
func halt_all(reason := "halted") -> void:
	halted = true
	for vm in scripts.values(): vm.queue.clear()
	_log_engine("all scripts halted: " + reason, "warn")

## Owner only, and only once the e-stop is released.
func resume_all() -> bool:
	if not Tiers.owner_session() or AutonomyGuard.paused(): return false
	halted = false
	_log_engine("scripts resumed by owner", "info")
	return true

func may_run(vm) -> bool:
	if estop_check(): return false
	if not scripts_allowed(vm):
		_log(vm, "scripts are off on this land", 0, "warn")
		return false
	return true

func _rate_ok(vm, kind: String) -> bool:
	if _owner_override(vm) and kind != "http": return true
	var lim: Array = RATES[kind]
	var k := "%s|%s" % [vm.id, kind]
	var ts: Array = _rate.get(k, []).filter(func(t): return clock - t < lim[1])
	if ts.size() >= lim[0]:
		_rate[k] = ts
		_log(vm, "rate limit: too many %s calls (max %d per %ds)" % [kind, lim[0], int(lim[1])], 0, "warn")
		return false
	ts.append(clock)
	_rate[k] = ts
	return true

func world_ok(vm, action := "build", target: Variant = null, kind := "world") -> bool:
	if estop_check(): return false
	if not scripts_allowed(vm): return false
	var o := obj_of(vm)
	var tgt: Variant = target if target != null else {"region": o["region"], "parcel": o["parcel"]}
	if not _owner_override(vm) and not Tiers.can(owner_of(vm), action, tgt):
		_log(vm, "not allowed: %s here needs %s rights" % [action, action], 0, "warn")
		return false
	return _rate_ok(vm, kind)

# ---------------- host API used by VsVM ----------------
func _emit(e: Dictionary) -> void:
	e["t"] = clock
	effects.append(e)
	if effects.size() > MAX_EFFECTS: effects = effects.slice(-MAX_EFFECTS)
	effect.emit(e)

func object_get(vm, what: String) -> Variant:
	var o := obj_of(vm)
	return o.get(what, "")

func world_call(vm, nm: String, a: Array, line: int) -> Variant:
	var o := obj_of(vm)
	match nm:
		"set_text":
			if not world_ok(vm): return 0
			o["text"] = VsVM.to_str(a[0]).left(254)
			if a.size() > 1 and a[1] is Vector3: o["color"] = a[1]
			_emit({"kind": "set_text", "object": o["key"], "text": o["text"], "color": o["color"]})
		"set_color":
			if not a[0] is Vector3: vm._fail("set_color needs a vector <r, g, b>", line); return 0
			if not world_ok(vm): return 0
			o["color"] = a[0].clamp(Vector3.ZERO, Vector3.ONE)
			_emit({"kind": "set_color", "object": o["key"], "color": o["color"]})
		"set_alpha":
			if not world_ok(vm): return 0
			o["alpha"] = clampf(float(a[0]) if (a[0] is int or a[0] is float) else 1.0, 0.0, 1.0)
			_emit({"kind": "set_alpha", "object": o["key"], "alpha": o["alpha"]})
		"set_pos":
			if not a[0] is Vector3: vm._fail("set_pos needs a vector", line); return 0
			var to: Vector3 = a[0]
			if to.distance_to(o["pos"]) > 10.0: to = o["pos"] + (to - o["pos"]).normalized() * 10.0   # 10 m per call
			var dest := {"region": o["region"], "parcel": Estate.parcel_id(to) if o["parcel"] != "" else ""}
			if not world_ok(vm, "build", dest): return 0
			o["pos"] = to
			_emit({"kind": "set_pos", "object": o["key"], "pos": to})
		"set_rot":
			if not a[0] is Quaternion: vm._fail("set_rot needs a rotation", line); return 0
			if not world_ok(vm): return 0
			o["rot"] = a[0].normalized()
			_emit({"kind": "set_rot", "object": o["key"], "rot": o["rot"]})
		"rez":
			if not a[1] is Vector3: vm._fail("rez needs an item name and a vector", line); return 0
			if (a[1] as Vector3).distance_to(o["pos"]) > 10.0: _log(vm, "rez: too far (max 10 m)", line, "warn"); return ""
			if not bool(Estate.region_get(o["region"], "allow_object_entry")) and not _owner_override(vm): _log(vm, "rez: objects can't enter here", line, "warn"); return ""
			if not world_ok(vm, "build", null, "rez"): return ""
			_seq += 1
			var nid := "%s/rez%d" % [o["key"], _seq]
			add_object(nid, o["owner"], o["region"], o["parcel"], a[1], VsVM.to_str(a[0]))
			_emit({"kind": "rez", "object": o["key"], "item": VsVM.to_str(a[0]), "new": nid, "pos": a[1]})
			return nid
		"give_item":
			if not world_ok(vm, "build", null, "give"): return 0
			_emit({"kind": "give_item", "object": o["key"], "to": VsVM.to_str(a[0]), "item": VsVM.to_str(a[1])})
			return 1
		"teleport":
			if not a[1] is Vector3: vm._fail("teleport needs a key and a vector", line); return 0
			var who := VsVM.to_str(a[0])
			# only the object's owner can be moved by default (like a permission-granted teleport)
			if who != o["owner"] and not _owner_override(vm): _log(vm, "teleport: only the object's owner can be moved", line, "warn"); return 0
			var dest := {"region": o["region"], "parcel": Estate.parcel_id(a[1]) if o["parcel"] != "" else ""}
			if not world_ok(vm, "enter", dest, "teleport"): return 0
			_emit({"kind": "teleport", "object": o["key"], "who": who, "pos": a[1]})
			return 1
		"die":
			if not world_ok(vm): return 0
			o["alive"] = false
			_emit({"kind": "die", "object": o["key"]})
			for sid in scripts_on(o["key"]): scripts[sid].running = false
	return 0

func chat(vm, kind: String, channel: int, msg: String, line: int) -> void:
	if not _rate_ok(vm, "chat"): return
	var o := obj_of(vm)
	if kind == "owner":
		_emit({"kind": "owner_say", "object": o["key"], "to": o["owner"], "msg": msg})
		return
	_emit({"kind": "chat", "mode": kind, "object": o["key"], "name": o["name"], "channel": channel, "msg": msg})
	if channel == VsVM.CONSTS["DEBUG_CHANNEL"]: _log(vm, msg, line, "debug")
	_deliver(channel, o["key"], o["name"], msg, o["pos"], CHAT_RANGE.get(kind, -1.0), o["region"], vm.id)

## Avatar or companion chat into the bus (from the client).
func hear(channel: int, from_key: String, from_name: String, msg: String, pos := Vector3.ZERO, region := "") -> void:
	_deliver(channel, from_key, from_name, msg.left(1024), pos, 20.0, region, "")

func _deliver(channel: int, from_key: String, from_name: String, msg: String, pos: Vector3, rng: float, region: String, from_sid: String) -> void:
	if estop_check(): return
	for sid in scripts:
		if sid == from_sid: continue   # a script never hears itself
		var vm: VsVM = scripts[sid]
		var o := obj_of(vm)
		if region != "" and o.get("region", "") != region: continue
		if rng >= 0.0 and (o["pos"] as Vector3).distance_to(pos) > rng: continue
		for h in vm.listens:
			var l: Dictionary = vm.listens[h]
			if l["channel"] != channel: continue
			if l["name"] != "" and l["name"] != from_name: continue
			if l["key"] != "" and l["key"] != from_key: continue
			if l["msg"] != "" and l["msg"] != msg: continue
			vm.post("listen", [channel, from_name, from_key, msg])
			break
		_pump(vm)

func log_line(vm, msg: String, line: int, level := "info") -> void: _log(vm, msg, line, level)
func script_error(vm, msg: String, line: int) -> void: _log(vm, "stopped: " + msg, line, "error")

func _log(vm, msg: String, line: int, level: String) -> void:
	log.append({"script": vm.id if vm else "", "level": level, "line": line, "msg": msg, "t": clock})
	if log.size() > MAX_LOG: log = log.slice(-MAX_LOG)
func _log_engine(msg: String, level: String) -> void: _log(null, msg, 0, level)

func request_reset(vm) -> void: _resets.append(vm.id)

func sensor_scan(vm) -> void:
	if not sensor_source.is_valid(): return
	var o := obj_of(vm)
	var rng: float = vm.sensor_req.get("range", 0.0)
	var want: String = vm.sensor_req.get("name", "")
	var found: Array = []
	for d in sensor_source.call(o):
		if want != "" and str(d.get("name", "")) != want: continue
		if (d.get("pos", Vector3.ZERO) as Vector3).distance_to(o["pos"]) <= rng: found.append(d)
		if found.size() >= 16: break
	if found.is_empty(): vm.post("no_sensor", [])
	else: vm.post("sensor", [found.size()], found)

## Queue an HTTP request for the host app. Off unless the owner turned it on; https and allowlist only.
func http(vm, url: String, method: String, body: String, line: int) -> String:
	if not http_enabled: _log(vm, "http is off (the owner can turn it on)", line, "warn"); return ""
	if not url.begins_with("https://"): _log(vm, "http: https only", line, "warn"); return ""
	var host := url.trim_prefix("https://").split("/")[0].split(":")[0].to_lower()
	if host == "" or host.contains("@") or not host in http_allow: _log(vm, "http: %s isn't on the owner's allowlist" % host, line, "warn"); return ""
	if not method in ["GET", "POST", "PUT", "DELETE"]: _log(vm, "http: method not allowed", line, "warn"); return ""
	if estop_check() or not _rate_ok(vm, "http"): return ""
	_seq += 1
	var k := "http-%d" % _seq
	http_queue.append({"key": k, "script": vm.id, "url": url, "method": method, "body": body.left(2048)})
	return k

func http_reply(k: String, status: int, body: String) -> void:
	for r in http_queue:
		if r["key"] == k and scripts.has(r["script"]):
			scripts[r["script"]].post("http_response", [k, status, body.left(2048)])
			_pump(scripts[r["script"]])
	http_queue = http_queue.filter(func(r): return r["key"] != k)

## Owner sets HTTP. Returns "" or an error.
func set_http(enabled: bool, allow: Array) -> String:
	if not Tiers.owner_session(): return "Owner unlock needed."
	http_enabled = enabled
	http_allow = allow.map(func(h): return str(h).to_lower().strip_edges()).filter(func(h): return h != "" and not h.contains("/"))
	return ""

# ---------------- elements (Dual Universe-style slots) ----------------
func add_element(eid: String, type: String, oid := "") -> bool:
	if not VsVM.ELEMENT_API.has(type): return false
	var st := {}
	match type:
		"door": st = {"open": false}
		"light": st = {"on": false, "color": Vector3.ONE, "intensity": 1.0}
		"screen": st = {"ops": [], "color": Vector3.ONE, "background": Vector3.ZERO, "frame": []}
		"engine": st = {"thrust": 0.0, "max": 1000.0}
		"container": st = {"items": [], "capacity": 100}
		"sensor": st = {"range": 10.0, "detected": []}
		"button": st = {"pressed": false}
	elements[eid] = {"type": type, "object": oid, "state": st}
	return true

## Link a script's declared slot to an element. Only the element's object owner (or owner) may link.
func link(sid: String, slot: String, eid: String) -> String:
	var vm: VsVM = scripts.get(sid)
	if vm == null: return "no such script"
	if not vm.program["slots"].has(slot): return "the script has no slot '%s'" % slot
	if not elements.has(eid): return "no such element"
	if elements[eid]["type"] != vm.program["slots"][slot]: return "slot '%s' needs a %s" % [slot, vm.program["slots"][slot]]
	var eo: String = elements[eid]["object"]
	if eo != "" and objects.has(eo) and objects[eo]["owner"] != owner_of(vm) and not Tiers.owner_session(): return "that element belongs to someone else"
	if not links.has(sid): links[sid] = {}
	links[sid][slot] = eid
	return ""

## Element events from the world (door opened by hand, button pressed...).
func element_event(eid: String, what: String) -> void:
	for sid in links:
		for slot in links[sid]:
			if links[sid][slot] == eid and scripts.has(sid):
				scripts[sid].post("element", [slot, what])
				_pump(scripts[sid])

func element_call(vm, slot: String, method: String, args: Array, line: int) -> Variant:
	var eid: String = links.get(vm.id, {}).get(slot, "")
	if eid == "" or not elements.has(eid):
		_log(vm, "slot '%s' isn't linked to an element" % slot, line, "warn")
		return 0
	var el: Dictionary = elements[eid]
	var spec: Array = VsVM.ELEMENT_API[el["type"]][method]
	if spec[1] and not world_ok(vm, "build", null, "screen" if el["type"] == "screen" else "world"): return 0
	var st: Dictionary = el["state"]
	var out: Variant = 0
	match el["type"] + "." + method:
		"door.open": st["open"] = true
		"door.close": st["open"] = false
		"door.toggle": st["open"] = not st["open"]
		"door.is_open": return 1 if st["open"] else 0
		"light.on": st["on"] = true
		"light.off": st["on"] = false
		"light.toggle": st["on"] = not st["on"]
		"light.is_on": return 1 if st["on"] else 0
		"light.set_color": if args[0] is Vector3: st["color"] = (args[0] as Vector3).clamp(Vector3.ZERO, Vector3.ONE)
		"light.set_intensity": st["intensity"] = clampf(_f(args[0]), 0.0, 10.0)
		"screen.width": return VsVM.SCREEN_W
		"screen.height": return VsVM.SCREEN_H
		"screen.clear": st["ops"] = []
		"screen.set_color": if args[0] is Vector3: st["color"] = args[0]
		"screen.set_background": if args[0] is Vector3: st["background"] = args[0]
		"screen.text", "screen.rect", "screen.line", "screen.circle":
			if st["ops"].size() >= VsVM.SCREEN_MAX_OPS: _log(vm, "screen: too many shapes (max %d per frame)" % VsVM.SCREEN_MAX_OPS, line, "warn"); return 0
			var op := {"op": method, "color": st["color"]}
			match method:
				"text": op.merge({"x": _f(args[0]), "y": _f(args[1]), "text": VsVM.to_str(args[2]).left(200)})
				"rect": op.merge({"x": _f(args[0]), "y": _f(args[1]), "w": _f(args[2]), "h": _f(args[3])})
				"line": op.merge({"x1": _f(args[0]), "y1": _f(args[1]), "x2": _f(args[2]), "y2": _f(args[3])})
				"circle": op.merge({"x": _f(args[0]), "y": _f(args[1]), "r": _f(args[2])})
			st["ops"].append(op)
			return 0
		"screen.flush":
			st["frame"] = st["ops"].duplicate(true)
			_emit({"kind": "screen", "element": eid, "background": st["background"], "ops": st["frame"]})
			return 0
		"engine.set_thrust": st["thrust"] = clampf(_f(args[0]), -st["max"], st["max"])
		"engine.get_thrust": return st["thrust"]
		"engine.max_thrust": return st["max"]
		"container.count": return st["items"].size()
		"container.items": return st["items"].duplicate()
		"container.capacity": return st["capacity"]
		"sensor.detected": return st["detected"].duplicate()
		"sensor.range": return st["range"]
		"sensor.set_range": st["range"] = clampf(_f(args[0]), 0.0, 96.0)
		"button.is_pressed": return 1 if st["pressed"] else 0
	if spec[1]: _emit({"kind": "element", "element": eid, "type": el["type"], "method": method, "state": st.duplicate(true)})
	return out

static func _f(v: Variant) -> float: return float(v) if (v is int or v is float) else 0.0

# ---------------- input + tick ----------------
func touch(oid: String, av_key: String, av_name: String, pos := Vector3.ZERO) -> void:
	_object_event(oid, ["touch_start", "touch_end"], [1], [{"key": av_key, "name": av_name, "pos": pos}])

func collide(oid: String, key: String, nm: String, pos := Vector3.ZERO) -> void:
	_object_event(oid, ["collision_start"], [1], [{"key": key, "name": nm, "pos": pos}])

func changed(oid: String, flags: int) -> void: _object_event(oid, ["changed"], [flags], [])
func rezzed(oid: String, param := 0) -> void: _object_event(oid, ["on_rez"], [param], [])

func _object_event(oid: String, evs: Array, args: Array, det: Array) -> void:
	if estop_check(): return
	for sid in scripts_on(oid):
		for ev in evs: scripts[sid].post(ev, args, det)
		_pump(scripts[sid])

func _pump(vm: VsVM) -> void:
	if halted or not vm.running: return
	vm.run_queue()
	_do_resets()

func _do_resets() -> void:
	while not _resets.is_empty():
		var sid: String = _resets.pop_front()
		if scripts.has(sid): scripts[sid].reset(); scripts[sid].run_queue()

## Advance the simulation. Timers fire, DU-style update/flush run at UPDATE_HZ.
func tick(dt: float) -> void:
	if estop_check(): return
	clock += dt
	_upd_acc += dt
	var do_upd := _upd_acc >= 1.0 / UPDATE_HZ
	var step := _upd_acc
	if do_upd: _upd_acc = 0.0
	for sid in scripts.keys():
		var vm: VsVM = scripts[sid]
		if not vm.running: continue
		vm.advance(dt)
		if do_upd:
			vm.post("update", [step])
			vm.post("flush", [step])
		_pump(vm)

## Owner-facing summary for the HUD debug console (Foxy renders it).
func status() -> Array:
	var out: Array = []
	for sid in scripts:
		var vm: VsVM = scripts[sid]
		out.append({"id": sid, "name": vm.name, "object": script_object[sid], "state": vm.state, "running": vm.running,
			"error": vm.error, "line": vm.error_line, "memory": vm.memory_used(), "steps": vm.total_steps})
	for sid in pending:
		out.append({"id": sid, "name": pending[sid]["name"], "object": pending[sid]["object"], "state": "awaiting owner approval",
			"running": false, "error": "", "line": 0, "memory": 0, "steps": 0})
	return out
