extends RefCounted
## Brain-cell core tests. Called from tests/run_tests.gd (_brain_tests). Uses a throwaway user:// root.

static func _rm_tree(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p): return
	for d in DirAccess.get_directories_at(p): _rm_tree(p.path_join(d))
	for f in DirAccess.get_files_at(p): DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)

static func run(t: Node) -> void:
	var root := "user://test_brains_%d" % Time.get_ticks_usec()
	var persona_foxy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companions/foxy_ani/persona.json"))
	var persona_nova: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companions/circuit_nova/persona.json"))

	# --- schema / validation ---
	var good := BrainCell.make("t_ok", "foxy_ani", {"type": "chat_keyword", "any": ["x"]}, {"type": "say", "text": "hi"}, 0.5, "user")
	t.check(BrainCell.validate(good) == "", "brain: valid cell passes")
	var bad := good.duplicate(true); bad["action"] = {"type": "exec", "code": "OS.execute('rm')"}
	t.check(BrainCell.validate(bad) != "", "brain: code/exec action rejected")
	var bad2 := good.duplicate(true); bad2["id"] = "../../etc"
	t.check(BrainCell.validate(bad2) != "", "brain: path-like id rejected")
	var big := good.duplicate(true); big["action"]["text"] = "x".repeat(5000)
	t.check(BrainCell.validate(big) != "", "brain: oversized cell rejected")
	var tools := BrainCore.flatten_tools(persona_foxy.get("tools"))
	t.check("place_voxel" in tools and "remember" in tools, "brain: v3 persona tools flatten")
	var badtool := BrainCell.make("t_tool", "foxy_ani", {"type": "chat_keyword", "any": ["x"]}, {"type": "tool", "name": "format_disk", "args": {}}, 0.5, "user")
	t.check(BrainCell.validate(badtool, tools) != "", "brain: tool outside persona whitelist rejected")

	# --- seed loading + evaluation ---
	var foxy := BrainCore.new("foxy_ani", persona_foxy, root)
	t.check(foxy.load_errors.is_empty(), "brain: foxy seed cells load cleanly %s" % str(foxy.load_errors))
	t.check(foxy.cells.size() >= 5 and foxy.is_lead, "brain: foxy has seed cells and is lead")
	var r := foxy.best({"type": "chat", "text": "hello there"}, {"player": "Phoenix"})
	t.check(r.get("cell_id") == "greet" and "Phoenix" in str(r["action"].get("text")), "brain: keyword trigger + {player} render")
	t.check(foxy.best({"type": "chat", "text": "zzz"}).is_empty(), "brain: no match -> empty")
	t.check(not foxy.evaluate({"type": "tick", "needs": {"energy": 10}}).is_empty(), "brain: need_below trigger fires")
	for c in ["circuit_nova", "aaliyah"]:
		var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companions/%s/persona.json" % c))
		var b := BrainCore.new(c, p, root)
		t.check(b.load_errors.is_empty() and b.cells.size() >= 3 and not b.is_lead, "brain: %s seed cells load, member rank" % c)
		t.check(JSON.parse_string(FileAccess.get_file_as_string("res://data/schema/brain_cell.schema.json")) != null, "brain: schema json parses")

	# --- memory layer ---
	t.check(foxy.memory.add_fact("Player loves aurora skies"), "brain: fact stored")
	t.check(not foxy.memory.add_fact("Player loves aurora skies"), "brain: duplicate fact ignored")
	t.check(not foxy.memory.add_fact("card 4111111111111111"), "brain: card-like number refused")
	t.check(not foxy.memory.add_fact("mail me at someone@example.com"), "brain: email refused")
	foxy.memory.log_episode("chat", {"text": "my password is hunter2"})
	t.check(foxy.memory.episodes().back().get("text") == "[redacted]", "brain: sensitive episode redacted")

	# --- reinforcement + versioning + rollback ---
	var w0 := float(foxy.cells["greet"]["weight"])
	t.check(foxy.reinforce("greet", 1.0) and float(foxy.cells["greet"]["weight"]) > w0, "brain: reinforce raises weight")
	t.check(foxy.versions("greet").size() == 2, "brain: seed snapshot + new version stored")
	t.check(foxy.rollback("greet"), "brain: rollback ok")
	t.check(is_equal_approx(float(foxy.cells["greet"]["weight"]), w0), "brain: rollback restores seed weight")

	# --- proposals: approval gating, lead-only delegate, rate limit ---
	var say := BrainCell.make("likes_aurora", "foxy_ani", {"type": "chat_keyword", "any": ["aurora"]}, {"type": "say", "text": "Aurora skies again? Yes!"}, 0.6, "self_proposed")
	var pr := foxy.propose(say, "player mentions aurora often")
	t.check(pr.get("status") == "pending" and not foxy.cells.has("likes_aurora"), "brain: low-risk proposal pending by default")
	t.check(foxy.approve("likes_aurora").get("ok") and foxy.cells.has("likes_aurora"), "brain: approve applies cell")
	var toolc := BrainCell.make("auto_dig", "foxy_ani", {"type": "chat_keyword", "any": ["tunnel"]}, {"type": "tool", "name": "carve_area", "args": {"radius": 2}}, 0.5, "self_proposed")
	t.check(foxy.propose(toolc, "test", true).get("status") == "pending", "brain: high-risk tool proposal always needs approval")
	t.check(foxy.reject("auto_dig") and not foxy.cells.has("auto_dig"), "brain: reject discards proposal")
	var nova := BrainCore.new("circuit_nova", persona_nova, root)
	var dl := BrainCell.make("nova_delegate", "circuit_nova", {"type": "event", "name": "x"}, {"type": "delegate", "to": "aaliyah", "command": "dig"}, 0.5, "self_proposed")
	t.check(not nova.propose(dl).get("ok"), "brain: non-lead cannot hold delegate cells")
	var limited := 0
	for i in 10:
		var c := BrainCell.make("spam_%d" % i, "circuit_nova", {"type": "chat_keyword", "any": ["s%d" % i]}, {"type": "say", "text": "x"}, 0.3, "self_proposed")
		if nova.propose(c).get("error", "").begins_with("rate limit"): limited += 1
	t.check(limited > 0, "brain: proposal rate limit enforced")

	# --- learner from experience ---
	var aal := BrainCore.new("aaliyah", JSON.parse_string(FileAccess.get_file_as_string("res://companions/aaliyah/persona.json")), root)
	aal.memory.log_episode("taught", {"when": "goodnight", "reply": "Sweet dreams, {player}."})
	for i in 3:
		aal.memory.log_episode("chat", {"text": "make a tunnel please"})
		aal.memory.log_episode("tool", {"name": "carve_area", "ok": true, "args": {"radius": 2}})
	aal.memory.log_episode("feedback", {"cell_id": "greet", "reward": 1.0})
	var rep := BrainLearner.learn(aal)
	var ids: Array = rep["proposed"].map(func(p): return p["id"])
	t.check("taught_goodnight" in ids, "brain: learner proposes taught reply")
	t.check("auto_tunnel_carve_area" in ids, "brain: learner proposes repeated keyword->tool pattern")
	t.check(rep["reinforced"] == 1, "brain: learner applies feedback reinforcement")
	t.check(aal.pending().size() == 2, "brain: learned proposals wait for approval")

	# --- coordination bus (Foxy lead) ---
	var bus := BrainBus.new()
	var got := {}
	for id in ["foxy_ani", "circuit_nova", "aaliyah"]:
		var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companions/%s/persona.json" % id))
		bus.register(id, func(m): got[id] = m["command"]; return {"ok": true}, p.get("abilities", []))
	var res := bus.post_group_task({"command": "build", "text": "build a neon structure and decorate the home", "from": "player"})
	t.check(res.size() == 3 and got.get("foxy_ani") == "build", "brain: lead receives group task and delegates (%d steps)" % res.size())
	t.check(res.all(func(x): return x.get("ok")), "brain: all delegated steps ok")
	bus.unregister("foxy_ani")
	t.check(not bus.post_group_task({"command": "build"})[0].get("ok"), "brain: group task fails cleanly without lead")

	# --- portable export ---
	var ex := foxy.export_portable()
	t.check(ex["schema"] == "phoenix.brain_export/1" and ex["cells"].size() >= 5 and "Never execute" in ex["usage"], "brain: portable export for Grok Bots")
	_rm_tree(root)

## AgentBrain regression: v3 personas store tools as {shared, world_only, chat}; dispatch must accept them.
static func run_agent_brain(t: Node) -> void:
	var ab: Node = t.get_node_or_null("/root/AgentBrain")
	if ab == null:
		t.check(false, "brain: AgentBrain autoload present"); return
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar companion_id := \"\"\nvar persona := {}\n"
	gs.reload()
	var fake := Node3D.new()
	fake.set_script(gs)
	fake.companion_id = "brain_test_agent"
	fake.persona = JSON.parse_string(FileAccess.get_file_as_string("res://companions/foxy_ani/persona.json"))
	t.add_child(fake)
	ab._agents[fake.companion_id] = fake
	ab._memory[fake.companion_id] = ab.load_memory(fake.companion_id)
	var r: Dictionary = ab.dispatch_tool(fake.companion_id, "remember", {"fact": "brain test fact"})
	t.check(r.get("ok", false), "brain: AgentBrain accepts v3 persona tool dict (remember)")
	ab._agents.erase(fake.companion_id)
	ab._memory.erase(fake.companion_id)
	DirAccess.remove_absolute(ab._mem_path(fake.companion_id))
	fake.queue_free()
