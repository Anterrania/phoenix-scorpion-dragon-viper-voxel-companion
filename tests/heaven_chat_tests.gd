extends RefCounted
## HEAVEN-9 (heaven_edit chat tool, approval-gated, undo) + CHAT-16 (tool results back to the model).
## Live path uses the AgentBrain.transport mock; on-device path uses the LlmMockBackend from local_ai_tests.run_state.

static func _ok_body(content: Variant, calls: Variant = null) -> String:
	var m := {"role": "assistant", "content": content}
	if calls != null: m["tool_calls"] = calls
	return JSON.stringify({"choices": [{"message": m}]})

static func _frames(t: Node, n := 3) -> void:
	for i in n: await t.get_tree().process_frame

static func _cfg_get(k: String) -> Variant:
	return Settings.cfg.get_value("llm", k) if Settings.cfg.has_section_key("llm", k) else null

static func _cfg_put(k: String, v: Variant) -> void:
	if v == null:
		if Settings.cfg.has_section_key("llm", k): Settings.cfg.erase_section_key("llm", k)
	else: Settings.cfg.set_value("llm", k, v)

static func _agent(t: Node, id: String, tools: Variant, at: Vector3) -> Node3D:
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar companion_id := \"\"\nvar persona := {}\nfunc get_player_position() -> Vector3: return global_position\n"
	gs.reload()
	var c := Node3D.new(); c.set_script(gs)
	c.companion_id = id
	c.persona = {"name": id, "system_prompt": "You are %s." % id, "voice_style": "Warm.", "tools": tools}
	t.add_child(c)
	c.global_position = at
	AgentBrain.register_agent(c)
	return c

static func _drop(c: Node) -> void:
	var ab: Node = AgentBrain
	ab.unregister_agent(c)
	ab.brains.erase(c.companion_id); ab._memory.erase(c.companion_id); ab._live_body.erase(c.companion_id)
	DirAccess.remove_absolute(ab._mem_path(c.companion_id))
	c.queue_free()

static func _call(name: String, args: Dictionary, id := "c1") -> Dictionary:
	return {"id": id, "type": "function", "function": {"name": name, "arguments": JSON.stringify(args)}}

static func run(t: Node) -> void:
	var ab: Node = AgentBrain
	var root := "user://test_heaven_chat_%d" % Time.get_ticks_usec()
	var old_eve := EveCore.save_dir
	EveCore.save_dir = root.path_join("eve"); EveCore.reset_cache()
	HeavenAccess.reset_for_tests(root.path_join("heaven"))
	HeavenEdits.reset_for_tests(root.path_join("heaven"))
	var snap := {"key": Settings.user_api_key(), "err": Settings.last_chat_error}
	for k in ["mode", "mode_set", "endpoint", "tool_followup"]: snap[k] = _cfg_get(k)
	# The owner is unlocked on this phone: chat must STILL not self-approve Heaven edits.
	Tiers.owner_override = true; EveCore.owner_override = true

	var hub := HeavenLayout.island("transport_hub")
	var spot := HeavenLayout.frame(hub) * Vector3(-20.0, 0.0, 25.0) + Vector3(0, HeavenLayout.walk_y(hub), 0)
	var c := _agent(t, "hc_builder", {"shared": ["remember", "emote"], "world_only": ["spawn_structure"]}, spot)
	var talker := _agent(t, "hc_talker", ["remember", "emote"], spot)
	t.check(HeavenEdits.TOOL_NAME in ab.tools_of(c) and not (HeavenEdits.TOOL_NAME in ab.tools_of(talker)), "heaven chat: builders get heaven_edit, talk-only companions don't")
	t.check(HeavenEdits.TOOL_NAME in ab.WORLD_TOOLS, "heaven chat: heaven_edit is world-only (not exposed by standalone bots)")
	t.check(ab.dispatch_tool(talker.companion_id, "heaven_edit", {"op": "add", "type": "lamp", "x": spot.x, "y": spot.y, "z": spot.z}).get("error", "") == "tool not allowed for this companion", "heaven chat: non-builder refused")

	# --- live path ---
	Settings.cfg.set_value("llm", "endpoint", "https://api.x.ai/v1/chat/completions")
	Settings.set_api_key_from_ui("xk-test-mock-key")
	Settings.cfg.set_value("llm", "mode", "live"); Settings.cfg.set_value("llm", "mode_set", true)
	_cfg_put("tool_followup", null)
	var replies := []
	var on_r := func(id, txt): if id == c.companion_id: replies.append(txt)
	ab.reply_ready.connect(on_r)
	var seen := []
	var answers := [_ok_body(null, [_call("heaven_edit", {"op": "add", "type": "lamp", "x": spot.x, "y": spot.y, "z": spot.z, "note": "for the arrivals"})]),
		_ok_body("I asked you to approve the new lamp, love.")]
	ab.transport = func(_u: String, _h: Array, body: String) -> Dictionary:
		seen.append(JSON.parse_string(body))
		return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": answers[mini(seen.size() - 1, answers.size() - 1)]}
	var base := HeavenEdits.pieces("transport_hub").size()
	ab.chat(c.companion_id, "put a lamp here")
	await _frames(t, 6)
	var first: Dictionary = seen[0] if seen.size() > 0 else {}
	var names := []
	for s in first.get("tools", []): names.append(s["function"]["name"])
	t.check("heaven_edit" in names and str(first.get("messages", [{}])[0].get("content", "")).contains("You are in Heaven"), "heaven chat: live request offers heaven_edit + Heaven hint")
	var pend := HeavenEdits.edits("pending").filter(func(e): return e["by"] == c.companion_id)
	t.check(pend.size() == 1 and HeavenEdits.pieces("transport_hub").size() == base, "heaven chat: edit from chat waits for approval even with the owner unlocked")
	var pid := str(pend[0].get("proposal", "")) if not pend.is_empty() else "?"
	t.check(EveCore.proposals(true).filter(func(p): return str(p["id"]) == pid).size() == 1, "heaven chat: proposal filed via EveCore.propose_update")
	t.check(seen.size() == 2 and replies == ["I asked you to approve the new lamp, love."], "chat-16: live tool results go back for one follow-up reply")
	var fu: Dictionary = seen[1] if seen.size() > 1 else {}
	var msgs: Array = fu.get("messages", [])
	var tool_msg: Dictionary = msgs.back() if not msgs.is_empty() else {}
	t.check(msgs.size() >= 2 and msgs[-2].get("tool_calls", []).size() == 1 and tool_msg.get("role", "") == "tool" and tool_msg.get("tool_call_id", "") == "c1", "chat-16: follow-up carries the assistant tool_calls + tool message")
	var tres: Variant = JSON.parse_string(str(tool_msg.get("content", "")))
	t.check(tres is Dictionary and tres.get("state", "") == "pending" and tres.get("ok", false) and fu.get("tool_choice", "") == "none", "chat-16: tool result says pending; follow-up asks for words only")
	t.check(ab._memory[c.companion_id]["history"].back()["content"] == "I asked you to approve the new lamp, love.", "chat-16: follow-up reply saved to memory")

	# owner approves -> applied (live rebuild bump)
	var rev0 := HeavenEdits.revision("transport_hub")
	EveCore.decide(str(pend[0]["proposal"]), true)
	HeavenEdits.sync()
	t.check(HeavenEdits.pieces("transport_hub").size() == base + 1 and HeavenEdits.revision("transport_hub") > rev0, "heaven chat: owner approval applies the chat edit")
	t.check(ab.dispatch_tool(c.companion_id, "heaven_edit", {"op": "undo", "target": "last"}).get("error", "").contains("Only the owner"), "heaven chat: approved change can't be undone by the companion without a grant")

	# follow-up fails -> canned follow-up line (no request_failed, no second tool run)
	replies.clear(); seen.clear()
	var fails := []
	var on_f := func(id, e): if id == c.companion_id: fails.append(e)
	ab.request_failed.connect(on_f)
	answers[1] = "not json"
	answers[0] = _ok_body(null, [_call("heaven_edit", {"op": "add", "type": "bench", "x": spot.x, "y": spot.y, "z": spot.z})])
	ab.chat(c.companion_id, "add a bench here please")
	await _frames(t, 6)
	t.check(replies.size() == 1 and str(replies[0]).contains("asked the owner to approve") and fails.is_empty(), "chat-16: follow-up failure -> canned result line, no error")
	t.check(HeavenEdits.edits("pending").filter(func(e): return e["by"] == c.companion_id).size() == 1, "chat-16: tools run once per turn (follow-up never re-runs them)")

	# undo a pending change -> withdrawn, approval later does nothing
	var u: Dictionary = ab.dispatch_tool(c.companion_id, "heaven_edit", {"op": "undo"})
	var wd := HeavenEdits.edits("withdrawn")
	t.check(u.get("ok", false) and u.get("state", "") == "withdrawn" and wd.size() == 1, "heaven chat: undo withdraws my pending change")
	EveCore.decide(str(wd[0]["proposal"]), true)
	HeavenEdits.sync()
	t.check(HeavenEdits.pieces("transport_hub").size() == base + 1 and HeavenEdits.edits("withdrawn").size() == 1, "heaven chat: withdrawn change is never applied (kept in the log)")
	t.check(ab.dispatch_tool(c.companion_id, "heaven_edit", {"op": "undo"}).has("error"), "heaven chat: nothing left to undo")

	# standing build grant -> applied at once; undo reverts
	t.check(HeavenAccess.grant(Tiers.SELF, "build", c.companion_id, 1) == "", "heaven chat: owner grants a standing build grant")
	var rev1 := HeavenEdits.revision("transport_hub")
	var g: Dictionary = ab.dispatch_tool(c.companion_id, "heaven_edit", {"op": "add", "type": "tree", "x": spot.x + 4.0, "y": spot.y, "z": spot.z})
	t.check(g.get("state", "") == "applied" and HeavenEdits.pieces("transport_hub").size() == base + 2 and HeavenEdits.revision("transport_hub") > rev1, "heaven chat: build grant -> applied at once, island rebuilds")
	var ug: Dictionary = ab.dispatch_tool(c.companion_id, "heaven_edit", {"op": "undo", "target": str(g.get("edit_id", ""))})
	t.check(ug.get("state", "") == "reverted" and HeavenEdits.pieces("transport_hub").size() == base + 1, "heaven chat: granted companion undoes its own change")
	t.check(ab.dispatch_tool(c.companion_id, "heaven_edit", {"op": "add", "type": "lamp", "x": 3000.0, "y": 10.0, "z": 0.0}).get("error", "").contains("not on a Heaven island"), "heaven chat: spots off Heaven refused")
	HeavenAccess.revoke(Tiers.SELF, "build", c.companion_id, 2)

	# follow-up switched off -> one request only
	replies.clear(); seen.clear()
	_cfg_put("tool_followup", false)
	answers[0] = _ok_body("Here you go!", [_call("emote", {"name": "wave"})])
	ab.chat(c.companion_id, "wave at me")
	await _frames(t, 6)
	t.check(seen.size() == 1 and replies == ["Here you go!"], "chat-16: follow-up can be switched off (llm/tool_followup)")
	_cfg_put("tool_followup", null)

	ab.reply_ready.disconnect(on_r); ab.request_failed.disconnect(on_f)
	ab.transport = Callable()
	_drop(talker)

	# --- on-device path (needs local_ai_tests.run_state: mock model downloaded) ---
	var llm: Node = t.get_node("/root/LocalLLM")
	var mock: LlmMockBackend = t.get_meta("lai_mock") if t.has_meta("lai_mock") else null
	if mock != null and llm.can_chat():
		Settings.set_api_key("")
		Settings.cfg.set_value("llm", "mode", "local"); Settings.cfg.set_value("llm", "mode_set", true)
		var lr := []
		var on_lr := func(id, txt): if id == c.companion_id: lr.append(txt)
		ab.reply_ready.connect(on_lr)
		mock.prompts.clear()
		mock.responder = func(p: String) -> String:
			if p.contains("<tool_response>"): return "Waiting on your yes for the fountain, my king."
			return "<tool_call>{\"name\": \"heaven_edit\", \"arguments\": {\"op\": \"add\", \"type\": \"fountains\"}}</tool_call>"
		var n_pend := HeavenEdits.edits("pending").size()
		ab.chat(c.companion_id, "put a fountain right here")
		await _frames(t, 14)
		var p2: String = mock.prompts[1] if mock.prompts.size() > 1 else ""
		t.check(HeavenEdits.edits("pending").size() == n_pend + 1 and str(HeavenEdits.edits("pending").back()["piece"]["type"]) == "fountain", "heaven chat: on-device model's heaven_edit filed (coords filled, type word mapped)")
		t.check(mock.prompts.size() == 2 and p2.contains("<tool_response>") and p2.contains("pending") and str(mock.prompts[0]).contains("You are in Heaven"), "chat-16: on-device follow-up prompt has the tool result")
		t.check(lr == ["Waiting on your yes for the fountain, my king."], "chat-16: on-device follow-up reply reaches the chat")
		# plain chat: no tools -> no second generation
		lr.clear(); mock.prompts.clear()
		mock.responder = func(_p: String) -> String: return "Hi love."
		ab.chat(c.companion_id, "hi")
		await _frames(t, 8)
		t.check(lr == ["Hi love."] and mock.prompts.size() == 1, "chat-16: no tools -> no follow-up generation")
		mock.responder = Callable()
		ab.reply_ready.disconnect(on_lr)
	else:
		t.check(false, "heaven chat: on-device tests need local_ai_tests.run_state first")

	_drop(c)
	Settings.set_api_key(snap["key"])
	for k in ["mode", "mode_set", "endpoint", "tool_followup"]: _cfg_put(k, snap[k])
	Settings.cfg.save(Settings.PATH)
	Settings.last_chat_error = snap["err"]
	Tiers.owner_override = null; EveCore.owner_override = null
	EveCore.save_dir = old_eve; EveCore.reset_cache()

static func run_docs(t: Node) -> void:
	var tr := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv")
	t.check(tr.contains("HEAVEN-9,") and tr.contains("CHAT-16,"), "heaven chat: tracker rows")
	t.check(FileAccess.get_file_as_string("res://docs/modules/HEAVEN.md").contains("HEAVEN-9") and FileAccess.get_file_as_string("res://docs/modules/LOCAL_AI.md").contains("CHAT-16"), "heaven chat: module docs")
