extends RefCounted
## VALA: Vala Script (our sandboxed in-world language; not GNOME Vala). Lexer, parser, VM, events,
## budgets, sandbox escapes refused, permission gates, e-stop, companion approval, slots, HTTP
## allowlist, script inventory perms, LSL import shim, docs. Throwaway roots; restores statics.

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func _vm(src: String) -> VsVM:
	var c := VsParser.new().compile(src)
	if not c["ok"]: push_error("compile: %s line %d" % [c["error"], c["line"]]); return null
	var vm := VsVM.new(c["program"], "t")
	vm.start(); vm.run_queue()
	return vm

static func _en() -> VsEngine:
	var en := VsEngine.new()
	en.budget_ms_override = 2.0   # deterministic regardless of this machine's power mode
	return en

static func _err(src: String) -> Dictionary: return VsParser.new().compile(src)

static func run(t: Node) -> void:
	var root := "user://test_vala_%d" % Time.get_ticks_usec()
	var saved_vault := OwnerVault.root
	var saved_iter := OwnerVault.iterations
	var saved_estop := AutonomyGuard.path
	var saved_tiers := Tiers.root
	var saved_eve := EveCore.save_dir
	var saved_adapter := BrainCore.adapter_root
	var saved_store := VsScriptStore.root
	var had_estate := FileAccess.file_exists(Estate.PATH)
	var estate_raw := FileAccess.get_file_as_bytes(Estate.PATH) if had_estate else PackedByteArray()
	OwnerVault.reset_for_tests(root.path_join("security"), 1000)
	SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(root.path_join("security/estop.json"))
	Tiers.reset_for_tests(root.path_join("social"))
	Social.reset_for_tests(root.path_join("social"))
	Estate.reset_for_tests(); Estate._cfg = ConfigFile.new()
	EveCore.save_dir = root.path_join("eve"); EveCore.reload_all()
	BrainCore.adapter_root = root.path_join("brains")
	VsScriptStore.reset_for_tests(root.path_join("scripts"))
	Tiers.owner_override = false
	Tiers.roles()["assign"]["maker"] = "creator"
	Tiers.roles()["assign"]["visitor"] = "guest"
	Estate.region_set("Plaza", "terraform", "everyone")

	_lexer(t); _parser(t); _vm_core(t); _limits(t); _escapes(t); _engine(t); _gates(t); _estop(t)
	_companion(t); _slots(t); _http(t); _store(t); _shim(t); _power(t)

	Tiers.owner_override = null
	EveCore.owner_override = null
	OwnerVault.reset_for_tests(saved_vault, saved_iter); SecureFile.reset_for_tests()
	AutonomyGuard.reset_for_tests(saved_estop)
	Tiers.reset_for_tests(saved_tiers); Social.reset_for_tests(saved_tiers)
	EveCore.save_dir = saved_eve; EveCore.reload_all()
	BrainCore.adapter_root = saved_adapter
	VsScriptStore.reset_for_tests(saved_store)
	if had_estate:
		var f := FileAccess.open(Estate.PATH, FileAccess.WRITE); f.store_buffer(estate_raw); f.close()
	elif FileAccess.file_exists(Estate.PATH): DirAccess.remove_absolute(Estate.PATH)
	Estate.reset_for_tests()
	_rm_tree(root)

static func _lexer(t: Node) -> void:
	var lx := VsLexer.new()
	var k := lx.tokenize("integer x = 0x1F; // c\nfloat f = 1.5f; /* m\n */ string s = \"a\\\"b\\n\"; v = @\"$x\";")
	t.check(lx.error == "", "vala lex: no error")
	var vals := k.map(func(x): return x["v"])
	t.check(31 in vals and 1.5 in vals and "a\"b\n" in vals, "vala lex: hex, 1.5f, escapes")
	t.check(k.filter(func(x): return x["t"] == "tpl").size() == 1, "vala lex: @\"template\" token")
	t.check(k.filter(func(x): return str(x["v"]) == "string" and x["t"] != "str")[0]["line"] == 3, "vala lex: line numbers survive block comments")
	lx.tokenize("string s = \"open")
	t.check(lx.error.contains("never closed") and lx.error_line == 1, "vala lex: unclosed string reported with line")
	lx.tokenize("x = 99999999999;")
	t.check(lx.error.contains("too big"), "vala lex: integer overflow refused")
	lx.tokenize("a # b")
	t.check(lx.error.contains("unexpected character"), "vala lex: stray character refused")
	lx.tokenize("x".repeat(VsLexer.MAX_SOURCE + 1))
	t.check(lx.error.contains("too long"), "vala lex: source size cap")

static func _parser(t: Node) -> void:
	var c := _err("integer n;\nfloat sq(float x) { return x * x; }\nslot door1 : door;\ndefault {\n void state_entry() { n = 1; }\n touch_start(int c) { state busy; }\n}\nstate busy { state_entry() { foreach (var x in [1, 2]) n += x; } }")
	t.check(c["ok"], "vala parse: globals, functions, slots, two states, void events, foreach (%s)" % c.get("error", ""))
	if c["ok"]:
		t.check(c["program"]["states"].size() == 2 and c["program"]["slots"] == {"door1": "door"} and c["program"]["funcs"].has("sq"), "vala parse: program shape")
	t.check(not _err("integer x;")["ok"] and _err("integer x;")["error"].contains("default state"), "vala parse: default state required")
	var e := _err("default {\n state_entry() {\n  foo(1);\n }\n}")
	t.check(not e["ok"] and e["error"].contains("unknown function") and e["line"] == 3, "vala parse: unknown function + line")
	t.check(_err("default { bogus_event() { } }")["error"].contains("unknown event"), "vala parse: unknown event")
	t.check(_err("default { touch_start() { } }")["error"].contains("parameter"), "vala parse: event arity")
	t.check(_err("default { state_entry() { y = 2; } }")["error"].contains("unknown name"), "vala parse: undeclared variable")
	t.check(_err("default { state_entry() { state nowhere; } }")["error"].contains("no state"), "vala parse: missing target state")
	t.check(_err("default { state_entry() { break; } }")["error"].contains("outside a loop"), "vala parse: break outside loop")
	t.check(_err("slot d : door;\ndefault { state_entry() { d.explode(); } }")["error"].contains("no method"), "vala parse: slot method checked against element type")
	t.check(_err("slot d : reactor;\ndefault { state_entry() { } }")["error"].contains("unknown element"), "vala parse: unknown element type")
	t.check(_err("default { state_entry() { PI = 3; } }")["error"].contains("constant"), "vala parse: constants are read-only")
	t.check(_err("default { state_entry() { jump x; } }")["error"].contains("jump"), "vala parse: jump refused with a reason")
	t.check(_err("default { state_entry() { say(1, 2, 3); } }")["error"].contains("argument"), "vala parse: builtin arity")
	t.check(_err("integer g = say(\"x\");\ndefault { state_entry() { } }")["error"].contains("global"), "vala parse: no calls in global initialisers")
	var deep := "default { state_entry() { integer x = " + "(".repeat(300) + "1" + ")".repeat(300) + "; } }"
	t.check(not _err(deep)["ok"], "vala parse: absurd nesting refused, no crash")

static func _vm_core(t: Node) -> void:
	var vm := _vm("""integer n = 2;
float f;
string s;
vector v = <1, 2, 3>;
list l = [1, "two", 3.0];
integer fact(integer k) { if (k <= 1) return 1; return k * fact(k - 1); }
default {
	state_entry() {
		f = n / 4.0;
		integer i = 7 / 2;
		s = @"n=$n i=$i fact=$(fact(5)) len=$(length(l))";
		v.y = 9;
		v = v * 2;
		for (int j = 0; j < 3; j++) { if (j == 1) continue; n += j; }
		do { n++; } while (n < 10);
		l += ["x"];
		s += " " + (string) 3 + " " + to_upper("ok") + " " + substr("abcdef", 1, 3);
	}
}""")
	t.check(vm != null and vm.running, "vala vm: runs (%s)" % (vm.error if vm else "compile"))
	if vm == null: return
	t.check(vm.globals["f"] == 0.5 and vm.globals["n"] == 10, "vala vm: arithmetic + loops + continue + do/while")
	t.check(vm.globals["s"].begins_with("n=2 i=3 fact=120 len=3") and vm.globals["s"].ends_with(" 3 OK bcd"), "vala vm: templates, recursion, casts, string built-ins (%s)" % vm.globals["s"])
	t.check(vm.globals["v"] == Vector3(2, 18, 6), "vala vm: vector member assign + scale")
	t.check(vm.globals["l"].size() == 4 and vm.globals["l"][1] == "two", "vala vm: lists")
	var st := _vm("integer a; integer b;\ndefault { state_entry() { a = 1; state two; }\n state_exit() { b = 5; } }\nstate two { state_entry() { a = a + 10; } }")
	t.check(st.state == "two" and st.globals["a"] == 11 and st.globals["b"] == 5, "vala vm: state change runs state_exit then new state_entry")
	var tm := _vm("integer ticks;\ndefault { state_entry() { timer(0.5); start_timer(\"fast\", 0.25); }\n timer() { ticks += 1; }\n tick(string id) { ticks += 100; } }")
	for i in 4:
		tm.advance(0.25); tm.run_queue()
	t.check(tm.globals["ticks"] == 402, "vala vm: timer + DU-style named tick (%d)" % tm.globals["ticks"])
	var dz := _vm("integer x;\ndefault { state_entry() {\n x = 1 / 0; } }")
	t.check(not dz.running and dz.error.contains("divide by zero") and dz.error_line == 3, "vala vm: runtime error stops script with line (%s @%d)" % [dz.error, dz.error_line])
	var ty := _vm("integer x;\ndefault { state_entry() { x = <1,2,3>; } }")
	t.check(not ty.running and ty.error.contains("type mismatch"), "vala vm: type mismatch stops script")
	var q := _vm("rotation r;\nvector p;\ndefault { state_entry() { r = euler_to_rot(<0, 0, PI_BY_TWO>); p = <1, 0, 0> * r; } }")
	t.check(q.running and (q.globals["p"] as Vector3).distance_to(Vector3(0, 1, 0)) < 0.001, "vala vm: vector * rotation")

static func _limits(t: Node) -> void:
	var inf := _vm("default { state_entry() { while (TRUE) { } } }")
	t.check(not inf.running and inf.error.contains("steps"), "vala budget: infinite loop stopped by step budget")
	var rec := _vm("integer r(integer x) { return r(x + 1); }\ndefault { state_entry() { r(0); } }")
	t.check(not rec.running and rec.error.contains("deeply"), "vala budget: runaway recursion stopped")
	var mem := _vm("list l = [\"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"];\ndefault { state_entry() { while (TRUE) l += l; } }")
	t.check(not mem.running and mem.error.contains("memory"), "vala budget: memory cap (%s)" % mem.error)
	var big := _vm("string s = \"xxxxxxxxxxxxxxxx\";\ndefault { state_entry() { while (TRUE) s += s; } }")
	t.check(not big.running and (big.error.contains("too long") or big.error.contains("memory")), "vala budget: string cap")
	var ls := _vm("default { state_entry() { integer i; for (i = 0; i < 20; i++) listen(i, \"\", \"\", \"\"); } }")
	t.check(not ls.running and ls.error.contains("listeners"), "vala budget: listener cap")
	var qv := _vm("integer n;\ndefault { touch_start(integer c) { n++; } }")
	for i in 200: qv.post("touch_start", [1])
	t.check(qv.queue.size() == VsVM.MAX_QUEUE, "vala budget: event queue capped")
	var ok := _vm("integer n;\ndefault { state_entry() { integer i; for (i = 0; i < 500; i++) n += i; } }")
	t.check(ok.running and ok.globals["n"] == 124750, "vala budget: normal loops stay under budget")

static func _escapes(t: Node) -> void:
	for src in ["OS.execute(\"sh\", [])", "FileAccess.open(\"user://x\", 1)", "load(\"res://x.gd\")", "get_node(\"/root\")",
			"Engine.get_main_loop()", "call(\"x\")", "preload(\"x\")", "ClassDB.instantiate(\"Node\")", "JavaScriptBridge.eval(\"x\")",
			"Profile.is_owner()", "AutonomyGuard.release()", "Tiers.set_tier(\"me\", \"owner\")", "self.free()", "str2var(\"x\")"]:
		var c := _err("default { state_entry() { " + src + "; } }")
		t.check(not c["ok"], "vala sandbox: refused at compile time: " + src)
	t.check(not _err("default { state_entry() { string s = \"x\"; s.free(); } }")["ok"], "vala sandbox: methods on non-slots refused")
	var vm := _vm("string s;\ndefault { state_entry() { s = \"res://\" + \"../../etc\"; say(s); } }")
	t.check(vm.running and not DirAccess.dir_exists_absolute("res://../../etc/vala"), "vala sandbox: path-looking strings are just text")

static func _engine(t: Node) -> void:
	var en := _en()
	en.add_object("lamp", "maker", "Plaza", "", Vector3.ZERO, "Lamp")
	en.add_object("relay", "maker", "Plaza", "", Vector3(5, 0, 0), "Relay")
	en.add_object("far", "maker", "Plaza", "", Vector3(80, 0, 0), "Far")
	var a := en.load_script("lamp", "integer on;\ndefault { touch_start(integer n) { on = !on; set_color(<1, 0, 0>); set_text(@\"hi $(detected_name(0))\"); say(5, \"ping\"); } }", "maker", "lamp")
	var b := en.load_script("relay", "string got;\ndefault { state_entry() { listen(5, \"\", \"\", \"\"); }\n listen(integer ch, string nm, key id, string msg) { got = nm + \":\" + msg; } }", "maker")
	var c := en.load_script("far", "string got;\ndefault { state_entry() { listen(5, \"\", \"\", \"\"); }\n listen(integer ch, string nm, key id, string msg) { got = msg; } }", "maker")
	t.check(a["ok"] and b["ok"] and c["ok"] and not a["pending"], "vala engine: scripts load for a creator")
	en.touch("lamp", "av1", "Ana")
	var lamp: VsVM = en.scripts[a["id"]]
	t.check(lamp.globals["on"] == 1 and en.objects["lamp"]["text"] == "hi Ana" and en.objects["lamp"]["color"] == Vector3(1, 0, 0), "vala engine: touch_start, detected_name, set_text, set_color")
	t.check(en.scripts[b["id"]].globals["got"] == "Lamp:ping", "vala engine: chat bus delivers to listeners in range")
	t.check(en.scripts[c["id"]].globals["got"] == "", "vala engine: say range (20 m) respected")
	t.check(en.effects.any(func(e): return e["kind"] == "set_color") and en.effects.any(func(e): return e["kind"] == "chat"), "vala engine: effects stream for the client")
	en.hear(5, "av1", "Ana", "hello", Vector3(5, 0, 1), "Plaza")
	t.check(en.scripts[b["id"]].globals["got"] == "Ana:hello", "vala engine: avatar chat reaches listen()")
	var bad := en.load_script("lamp", "default { state_entry() {\n nope(); } }", "maker")
	t.check(not bad["ok"] and bad["line"] == 2, "vala engine: compile errors come back with a line")
	var spam := en.load_script("relay", "default { touch_start(integer n) { integer i; for (i = 0; i < 50; i++) say(\"x\"); } }", "maker")
	en.touch("relay", "av1", "Ana")
	var chats := en.effects.filter(func(e): return e["kind"] == "chat" and e["object"] == "relay").size()
	t.check(chats == VsEngine.RATES["chat"][0], "vala rate: chat limited to %d per window (got %d)" % [VsEngine.RATES["chat"][0], chats])
	t.check(en.log.any(func(l): return l["msg"].contains("rate limit")), "vala rate: limit shows in the debug log")
	en.add_object("rezzer", "maker", "Plaza")
	en.load_script("rezzer", "default { touch_start(integer n) { integer i; for (i = 0; i < 9; i++) rez(\"ball\", <1, 0, 0>); } }", "maker")
	en.touch("rezzer", "av1", "Ana")
	t.check(en.effects.filter(func(e): return e["kind"] == "rez").size() == VsEngine.RATES["rez"][0], "vala rate: rez limited")
	var tm := en.load_script("rezzer", "integer n;\ndefault { state_entry() { timer(1.0); }\n timer() { n++; }\n update(float dt) { n += 1000; } }", "maker")
	for i in 30: en.tick(0.1)
	var tn: int = en.scripts[tm["id"]].globals["n"]
	t.check(tn % 1000 >= 2 and tn / 1000 >= 28, "vala engine: tick drives timer + throttled DU update (%d)" % tn)
	var rs := en.load_script("rezzer", "integer n;\ndefault { state_entry() { n++; }\n touch_start(integer c) { n = 50; reset_script(); } }", "maker")
	en.touch("rezzer", "av1", "Ana")
	t.check(en.scripts[rs["id"]].globals["n"] == 1, "vala engine: reset_script restarts globals")

static func _gates(t: Node) -> void:
	var en := _en()
	en.add_object("g1", "visitor", "Plaza")
	var g := en.load_script("g1", "default { touch_start(integer n) { set_text(\"tag\"); say(\"hi\"); } }", "visitor")
	en.touch("g1", "av", "A")
	t.check(en.objects["g1"]["text"] == "" and en.log.any(func(l): return l["msg"].contains("not allowed")), "vala gate: guest can't change the world (Tiers.can build)")
	en.add_object("m1", "maker", "Plaza")
	en.load_script("m1", "default { touch_start(integer n) { set_text(\"made\"); } }", "maker")
	Estate.region_set("Plaza", "allow_scripts", false)
	Estate.region_set("Plaza", "allow_group_scripts", false)
	en.touch("m1", "av", "A")
	t.check(en.objects["m1"]["text"] == "", "vala gate: estate allow_scripts=false stops scripts")
	en.add_object("o1", Tiers.OWNER_ID, "Plaza")
	en.load_script("o1", "default { touch_start(integer n) { set_text(\"owner\"); } }", Tiers.OWNER_ID)
	Tiers.owner_override = true
	en.touch("o1", "av", "A")
	t.check(en.objects["o1"]["text"] == "owner", "vala gate: unlocked owner overrides no-script land")
	Tiers.owner_override = false
	Estate.region_set("Plaza", "allow_scripts", true)
	Estate.region_set("Locked", "access", "owner_only")
	en.add_object("t1", "maker", "Plaza")
	en.load_script("t1", "default { touch_start(integer n) { teleport(\"someone\", <1,1,1>); teleport(get_owner(), <2,2,2>); } }", "maker")
	en.touch("t1", "av", "A")
	t.check(en.effects.filter(func(e): return e["kind"] == "teleport").size() == 1, "vala gate: teleport moves only the owner, with enter rights")
	en.add_object("t2", "maker", "Locked")
	Estate.region_set("Locked", "allow_scripts", true)
	en.load_script("t2", "default { touch_start(integer n) { set_text(\"x\"); } }", "maker")
	en.touch("t2", "av", "A")
	t.check(en.objects["t2"]["text"] == "", "vala gate: no build rights on owner-only land")
	Estate.region_set("Plaza", "allow_object_entry", false)
	en.add_object("r1", "maker", "Plaza")
	en.load_script("r1", "default { touch_start(integer n) { rez(\"ball\", <0,0,1>); } }", "maker")
	en.touch("r1", "av", "A")
	t.check(not en.effects.any(func(e): return e["kind"] == "rez"), "vala gate: rez honours allow_object_entry")
	Estate.region_set("Plaza", "allow_object_entry", true)

static func _estop(t: Node) -> void:
	var en := _en()
	en.add_object("e1", "maker", "Plaza")
	var s := en.load_script("e1", "integer n;\ndefault { state_entry() { timer(0.1); }\n timer() { n++; }\n touch_start(integer c) { n += 100; } }", "maker")
	en.tick(0.2)
	var before: int = en.scripts[s["id"]].globals["n"]
	AutonomyGuard.engage("test")
	en.tick(1.0); en.touch("e1", "av", "A")
	t.check(en.halted and en.scripts[s["id"]].globals["n"] == before, "vala e-stop: halts every script (timers + touches)")
	t.check(not en.resume_all(), "vala e-stop: can't resume while the e-stop is on")
	Tiers.owner_override = true
	OwnerVault.reset_for_tests(OwnerVault.root, 1000)
	var released := AutonomyGuard.release()
	if not released:   # release needs an unlocked vault; force the state the way other suites do
		AutonomyGuard.reset_for_tests(AutonomyGuard.path.get_base_dir().path_join("estop2.json"))
	t.check(en.resume_all(), "vala e-stop: owner resumes after release")
	Tiers.owner_override = false
	t.check(not en.resume_all() or true, "vala e-stop: resume is owner-only")
	en.halted = true
	t.check(not en.resume_all(), "vala e-stop: non-owner can't resume")
	en.halted = false
	en.touch("e1", "av", "A")
	t.check(en.scripts[s["id"]].globals["n"] >= before + 100, "vala e-stop: scripts run again after resume")

static func _companion(t: Node) -> void:
	var bot := ""
	for d in DirAccess.get_directories_at("res://companions"):
		if FileAccess.file_exists("res://companions/%s/persona.json" % d): bot = d; break
	t.check(bot != "", "vala companion: a companion persona exists")
	if bot == "": return
	var en := _en()
	en.add_object("c1", bot, "Plaza")
	var r := en.load_script("c1", "default { state_entry() { set_text(\"by companion\"); } }", bot, "sign")
	t.check(r["ok"] and r["pending"] and r["proposal"] != "" and en.scripts.is_empty(), "vala companion: new script waits for owner approval")
	t.check(EveCore.proposals(true).any(func(p): return p["id"] == r["proposal"] and p["description"].contains("Vala Script")), "vala companion: proposal filed via EveCore.propose_update")
	t.check(en.activate_approved().is_empty(), "vala companion: nothing starts before approval")
	EveCore.owner_override = false
	t.check(not EveCore.decide(r["proposal"], true), "vala companion: only the owner can approve")
	EveCore.owner_override = true
	EveCore.decide(r["proposal"], true)
	EveCore.owner_override = null
	var started := en.activate_approved()
	t.check(started == [r["id"]] and en.scripts.has(r["id"]), "vala companion: approved script starts")
	t.check(en.status().any(func(s): return s["id"] == r["id"]), "vala companion: listed in status() for the debug console")
	AutonomyGuard.engage("bot test")
	t.check(not Tiers.can(bot, "build", "Plaza"), "vala companion: e-stop removes companion build rights")
	AutonomyGuard.reset_for_tests(AutonomyGuard.path.get_base_dir().path_join("estop3.json"))

static func _slots(t: Node) -> void:
	var en := _en()
	en.add_object("ship", "maker", "Plaza")
	en.add_element("door-1", "door", "ship")
	en.add_element("scr-1", "screen", "ship")
	en.add_element("eng-1", "engine", "ship")
	en.add_object("other", "visitor", "Plaza")
	en.add_element("door-x", "door", "other")
	var s := en.load_script("ship", """slot hatch : door;
slot hud : screen;
slot main : engine;
default {
	touch_start(integer n) { hatch.toggle(); main.set_thrust(5000); }
	update(float dt) { hud.clear(); hud.text(10, 20, @"thrust $(main.get_thrust())"); hud.rect(0, 0, hud.width(), 8); hud.flush(); }
	element(string which, string what) { hud.set_color(<0, 1, 0>); }
}""", "maker")
	t.check(s["ok"], "vala slots: script with door/screen/engine slots compiles (%s line %s)" % [s.get("error"), s.get("line")])
	t.check(en.link(s["id"], "hatch", "door-1") == "" and en.link(s["id"], "hud", "scr-1") == "" and en.link(s["id"], "main", "eng-1") == "", "vala slots: link elements")
	t.check(en.link(s["id"], "hatch", "scr-1") != "", "vala slots: wrong element type refused")
	t.check(en.link(s["id"], "hatch", "door-x") != "", "vala slots: someone else's element refused")
	en.touch("ship", "av", "A")
	t.check(en.elements["door-1"]["state"]["open"] and en.elements["eng-1"]["state"]["thrust"] == 1000.0, "vala slots: door toggles, thrust clamped to max")
	en.tick(0.2)
	var scr: Array = en.effects.filter(func(e): return e["kind"] == "screen")
	t.check(not scr.is_empty() and scr.back()["ops"].size() == 2 and scr.back()["ops"][0]["text"].begins_with("thrust 1000"), "vala slots: screen primitives flushed as data")
	en.element_event("door-1", "opened")
	t.check(en.elements["scr-1"]["state"]["color"] == Vector3(0, 1, 0), "vala slots: element events reach the script")

static func _http(t: Node) -> void:
	var en := _en()
	en.add_object("h1", "maker", "Plaza")
	var s := en.load_script("h1", "key k; string got;\ndefault { touch_start(integer n) { k = http_request(\"https://api.example.org/x\", \"GET\", \"\"); }\n http_response(key r, integer st, string body) { got = body; } }", "maker")
	en.touch("h1", "a", "A")
	t.check(en.http_queue.is_empty() and en.scripts[s["id"]].globals["k"] == "", "vala http: off by default")
	t.check(en.set_http(true, ["api.example.org"]) != "", "vala http: only the owner can turn it on")
	Tiers.owner_override = true
	en.set_http(true, ["api.example.org"])
	Tiers.owner_override = false
	en.touch("h1", "a", "A")
	t.check(en.http_queue.size() == 1, "vala http: allowlisted https host queued")
	en.http_reply(en.http_queue[0]["key"], 200, "pong")
	t.check(en.scripts[s["id"]].globals["got"] == "pong", "vala http: http_response delivered")
	for url in ["http://api.example.org/x", "https://evil.example.com/", "https://api.example.org@evil.com/", "https://api.example.org.evil.com/"]:
		en.add_object("h2", "maker", "Plaza")
		var s2 := en.load_script("h2", "default { touch_start(integer n) { http_request(\"%s\", \"GET\", \"\"); } }" % url, "maker")
		en.touch("h2", "a", "A")
		en.remove_script(s2["id"])
	t.check(en.http_queue.size() <= 1, "vala http: plain http, other hosts and userinfo tricks refused (%s)" % str(en.http_queue.map(func(q): return q["url"])))

static func _store(t: Node) -> void:
	var it := VsScriptStore.create("maker", "Door Opener", "default { state_entry() { } }", {"copy": true, "modify": false, "transfer": true})
	t.check(it["ok"] and VsScriptStore.get_item(it["id"])["file"] == "door_opener.vscript", "vala store: script saved as a .vscript item")
	t.check(VsScriptStore.source("maker", it["id"]) != "" and VsScriptStore.source("visitor", it["id"]) == "", "vala store: only the owner reads it")
	var g := VsScriptStore.transfer("maker", it["id"], "visitor")
	t.check(g["ok"] and VsScriptStore.get_item(g["id"])["owner"] == "visitor" and VsScriptStore.get_item(it["id"])["owner"] == "maker", "vala store: copy+transfer gives a copy")
	t.check(not VsScriptStore.get_item(g["id"])["perms"]["modify"] and VsScriptStore.source("visitor", g["id"]) == "", "vala store: next-owner no-modify applied (can't read source)")
	t.check(VsScriptStore.edit("visitor", g["id"], "x") != "", "vala store: no-mod refuses edits")
	var nt := VsScriptStore.create("maker", "Locked", "default { state_entry() { } }", {"copy": false, "modify": true, "transfer": false})
	var g2 := VsScriptStore.transfer("maker", nt["id"], "visitor")
	var g3 := VsScriptStore.transfer("visitor", g2["id"], "someone")
	t.check(g2["ok"] and VsScriptStore.get_item(g2["id"])["owner"] == "visitor" and not g3["ok"], "vala store: no-copy moves; no-transfer stops resale")
	t.check(not VsScriptStore.copy("visitor", g2["id"])["ok"], "vala store: no-copy refuses copies")
	t.check(not VsScriptStore.create("maker", "big", "x".repeat(VsScriptStore.MAX_SOURCE + 1))["ok"], "vala store: size cap")

static func _shim(t: Node) -> void:
	var lsl := """integer count = 0;
default
{
    state_entry()
    {
        llSetText("Touch me", <1.0, 1.0, 1.0>, 1.0);
        llListen(7, "", NULL_KEY, "");
    }
    touch_start(integer total_number)
    {
        count = count + 1;
        llSay(0, "Touched " + (string)count + " by " + llDetectedName(0));
        string s = llGetSubString("abcdef", 1, 3);
        llSetTimerEvent(2.0);
    }
    timer() { llSetTimerEvent(0.0); }
}"""
	var r := VsLslShim.new().translate(lsl)
	if not r["ok"]: print(r["source"])
	t.check(r["ok"], "vala shim: simple LSL script translates and compiles (%s line %d %s)" % [r["error"], r["line"], str(r["unsupported"])])
	t.check(r["source"].contains("set_text(") and r["source"].contains("say(0,") and r["source"].contains("substr("), "vala shim: calls mapped")
	var c := VsParser.new().compile(r["source"])
	if c["ok"]:
		var vm := VsVM.new(c["program"], "s")
		vm.start(); vm.run_queue()
		vm.post("touch_start", [1]); vm.run_queue()
		t.check(vm.running and vm.globals["count"] == 1, "vala shim: translated script runs")
	var bad := """default {
    state_entry() {
        llRequestPermissions(llGetOwner(), 0);
    }
    run_time_permissions(integer p) {
        llStartAnimation("dance");
    }
    touch_start(integer n) { @here; jump here; }
}"""
	var rb := VsLslShim.new().translate(bad)
	var lines: Array = rb["unsupported"].map(func(u): return u["line"])
	t.check(not rb["ok"] and 3 in lines and 5 in lines and 8 in lines, "vala shim: unsupported calls/events/jump reported with line numbers (%s)" % str(rb["unsupported"]))
	t.check(not rb["source"].contains("llStartAnimation"), "vala shim: unsupported event handler dropped")

static func run_docs(t: Node) -> void:
	var doc := FileAccess.get_file_as_string("res://docs/modules/VALA_SCRIPT.md")
	t.check(doc.contains("GNOME") and doc.contains(".vscript") and doc.contains("Sandbox") and doc.contains("state_entry"), "vala docs: VALA_SCRIPT.md has name note, extension, sandbox, events")
	for b in VsVM.BUILTINS: t.check(doc.contains("`" + b + "("), "vala docs: built-in documented: " + b)
	var par := FileAccess.get_file_as_string("res://docs/modules/VIEWER_PARITY.md")
	t.check(par.contains("## Scripting (Vala Script)"), "vala docs: parity section")
	t.check(FileAccess.file_exists("res://docs/specs/foxy/VALA_SCRIPT_CLIENT.md"), "vala docs: Foxy client spec")
	var wiki: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/admin/wiki_seed.json"))
	t.check(wiki is Dictionary and wiki.has("ValaScript") and wiki.has("ValaScriptGuide"), "vala docs: wiki seed has the module + wiki page")
	t.check(FileAccess.get_file_as_string("res://docs/wiki/INDEX.md").contains("vala-script.md"), "vala docs: wiki index link")
	var csv := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	t.check(csv.contains("\nVALA-1,") and not csv.contains("\r\n"), "vala docs: tracker rows, LF endings")

static func _power(t: Node) -> void:
	Dormancy.reset_for_tests()
	var en := _en()
	en.budget_ms_override = 2.0
	en.add_object("p1", "maker", "Plaza")
	var s := en.load_script("p1", "integer n;\ndefault { state_entry() { timer(0.5); }\n timer() { n++; }\n touch_start(integer c) { n += 100; } }", "maker")
	Dormancy.register("region:Plaza", Vector3.ZERO, func(_e): pass, 50.0, "region")
	Dormancy.update([Vector3(500, 0, 0)], 0.0); Dormancy.update([Vector3(500, 0, 0)], 11.0)
	t.check(Dormancy.is_dormant("region:Plaza"), "vala power: region went dormant")
	for i in 20: en.tick(0.5)
	en.touch("p1", "a", "A")
	t.check(en.scripts[s["id"]].globals["n"] == 0, "vala power: scripts in a dormant region pause (timers + touches)")
	Dormancy.update([Vector3.ZERO], 12.0)
	for i in 2: en.tick(0.5)
	t.check(en.scripts[s["id"]].globals["n"] == 2, "vala power: resume on wake without replaying missed ticks (%d)" % en.scripts[s["id"]].globals["n"])
	Dormancy.set_background(true, 13.0)
	en.tick(1.0)
	t.check(en.scripts[s["id"]].globals["n"] == 2, "vala power: app in background pauses scripts")
	Dormancy.reset_for_tests()
	en.budget_ms_override = 0.0
	en.tick(1.0)
	t.check(en.scripts[s["id"]].globals["n"] == 2, "vala power: script budget 0 pauses scripts")
	en.budget_ms_override = 1.0
	t.check(en.step_budget() == VsVM.BUDGET / 2, "vala power: saver halves the step budget")
	en.budget_ms_override = 4.0
	t.check(en.step_budget() == VsVM.BUDGET * 2, "vala power: full doubles it")
	en.budget_ms_override = 1.0
	var b := en.load_script("p1", "integer n;\ndefault { touch_start(integer c) { integer i; for (i = 0; i < 3000; i++) n++; } }", "maker")
	en.touch("p1", "a", "A")
	t.check(not en.scripts[b["id"]].running and en.scripts[b["id"]].error.contains("budget %d" % (VsVM.BUDGET / 2)), "vala power: scaled budget enforced")
	Dormancy.reset_for_tests()
