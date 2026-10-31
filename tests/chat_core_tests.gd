extends RefCounted
## CHAT-1..14: companion chat end to end against a mock provider (AgentBrain.transport), no network.

static func _snap() -> Dictionary:
	var out := {"key": Settings.user_api_key(), "err": Settings.last_chat_error}
	for k in ["mode", "mode_set", "endpoint"]:
		out[k] = Settings.cfg.get_value("llm", k) if Settings.cfg.has_section_key("llm", k) else null
	return out

static func _restore(s: Dictionary) -> void:
	for k in ["mode", "mode_set", "endpoint"]:
		if s[k] == null:
			if Settings.cfg.has_section_key("llm", k): Settings.cfg.erase_section_key("llm", k)
		else: Settings.cfg.set_value("llm", k, s[k])
	Settings.cfg.save(Settings.PATH)
	Settings.set_api_key(s["key"])
	Settings.last_chat_error = s["err"]
	AgentBrain.transport = Callable()

static func _ok_body(content: Variant, calls: Variant = null) -> String:
	var m := {"role": "assistant", "content": content}
	if calls != null: m["tool_calls"] = calls
	return JSON.stringify({"choices": [{"message": m}]})

static func _frames(t: Node, n := 3) -> void:
	for i in n: await t.get_tree().process_frame

static func run(t: Node) -> void:
	var ab: Node = AgentBrain
	var snap := _snap()
	# --- settings: endpoint, mode, status ---
	t.check(Settings.normalize_endpoint(" api.x.ai/v1/chat/completions ") == "https://api.x.ai/v1/chat/completions", "chat: endpoint without scheme gets https://")
	t.check(Settings.normalize_endpoint("") == "" and Settings.normalize_endpoint("ftp://x.y") == "" and Settings.normalize_endpoint("https:///v1") == "" and Settings.normalize_endpoint("not a url") == "", "chat: bad endpoints rejected")
	t.check(Settings.normalize_endpoint("http://localhost:8080/v1/chat/completions") != "", "chat: local dev endpoint allowed")
	t.check(Settings.chat_error_text(HTTPRequest.RESULT_CANT_RESOLVE, 0).contains("DNS"), "chat: DNS failure (ERR_NAME_NOT_RESOLVED equivalent) explained")
	t.check(Settings.chat_error_text(HTTPRequest.RESULT_SUCCESS, 401).contains("key was rejected"), "chat: 401 -> key rejected")
	t.check(Settings.chat_error_text(HTTPRequest.RESULT_SUCCESS, 429).contains("429") and Settings.chat_error_text(HTTPRequest.RESULT_SUCCESS, 200) == "", "chat: 429 explained, 200 is not an error")
	t.check(Settings.chat_error_text(HTTPRequest.RESULT_SUCCESS, 400, "{\"error\":{\"message\":\"bad model\"}}").contains("bad model"), "chat: provider error message surfaced")
	if Settings.cfg.has_section_key("llm", "mode_set"): Settings.cfg.erase_section_key("llm", "mode_set")
	Settings.cfg.set_value("llm", "mode", "canned")
	Settings.cfg.set_value("llm", "endpoint", "https://api.x.ai/v1/chat/completions")
	Settings.set_api_key_from_ui("")
	t.check(not Settings.live_ai() and Settings.chat_status() in ["offline_no_key", "offline_locked"] or Settings.build_default_key() != "", "chat: no key -> offline")
	Settings.set_api_key_from_ui("xk-test-mock-key")
	t.check(str(Settings.get_value("llm", "mode")) == "live" and Settings.live_ai() and Settings.chat_status() == "live", "chat: entering a key turns live chat on")
	Settings.cfg.set_value("llm", "mode", "canned"); Settings.cfg.set_value("llm", "mode_set", true)
	Settings.set_api_key_from_ui("xk-test-mock-key")
	t.check(not Settings.live_ai() and Settings.chat_status() == "offline_mode", "chat: explicit offline choice is respected (status == live_ai)")
	Settings.cfg.set_value("llm", "mode", "live")
	Settings.cfg.set_value("llm", "endpoint", "not a url")
	t.check(not Settings.live_ai() and Settings.chat_status() == "offline_endpoint" and Settings.chat_status_text("offline_endpoint").contains("valid"), "chat: invalid endpoint -> clear offline status")
	Settings.cfg.set_value("llm", "endpoint", "api.x.ai/v1/chat/completions")
	t.check(Settings.live_ai() and Settings.chat_status() == "live", "chat: live with key + mode + endpoint")

	# --- fake companion registered like a real one ---
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar companion_id := \"\"\nvar persona := {}\nfunc get_player_position() -> Vector3: return Vector3.ZERO\n"
	gs.reload()
	var c := Node3D.new(); c.set_script(gs)
	c.companion_id = "chat_test_agent"
	c.persona = JSON.parse_string(FileAccess.get_file_as_string("res://companions/foxy_ani/persona.json"))
	t.add_child(c)
	ab.register_agent(c)
	var replies := []; var fails := []; var think := []
	var on_r := func(id, txt): if id == c.companion_id: replies.append(txt)
	var on_f := func(id, e): if id == c.companion_id: fails.append(e)
	var on_t := func(id, a): if id == c.companion_id: think.append(a)
	ab.reply_ready.connect(on_r); ab.request_failed.connect(on_f); ab.thinking.connect(on_t)
	var seen := {}
	var mock := {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": _ok_body("Hello from the mock provider!")}   # mutated in place (lambdas capture by value)
	ab.transport = func(url: String, headers: Array, body: String) -> Dictionary:
		seen["url"] = url; seen["headers"] = headers; seen["body"] = JSON.parse_string(body)
		return mock

	# 1 happy path
	ab.chat(c.companion_id, "hi there")
	t.check(ab.is_thinking(c.companion_id) and think == [true], "chat: thinking state while the request is in flight")
	await _frames(t)
	t.check(replies == ["Hello from the mock provider!"] and fails.is_empty(), "chat: live reply reaches reply_ready")
	t.check(think == [true, false] and not ab.is_thinking(c.companion_id), "chat: thinking cleared after reply")
	t.check(seen.get("url") == "https://api.x.ai/v1/chat/completions" and "Authorization: Bearer xk-test-mock-key" in seen.get("headers", []), "chat: request uses normalized endpoint + sealed key")
	var sb: Dictionary = seen.get("body", {})
	t.check(sb.get("messages", []).size() >= 2 and sb["messages"][0]["role"] == "system" and sb["messages"].back()["content"] == "hi there", "chat: system prompt + user message sent")
	t.check(sb.has("tools") and not sb["tools"].is_empty() and sb.has("model"), "chat: tool specs + model sent")
	var h: Array = ab._memory[c.companion_id]["history"]
	t.check(h.size() >= 2 and h[-1]["content"] == "Hello from the mock provider!" and h[-2]["content"] == "hi there", "chat: live turn saved to memory")

	# 2 errors always end in an offline reply
	for cse in [[HTTPRequest.RESULT_SUCCESS, 401, "{\"error\":{\"message\":\"bad key\"}}", "rejected"], [HTTPRequest.RESULT_CANT_RESOLVE, 0, "", "DNS"],
			[HTTPRequest.RESULT_TIMEOUT, 0, "", "too long"], [HTTPRequest.RESULT_SUCCESS, 200, "not json", "couldn't read"],
			[HTTPRequest.RESULT_SUCCESS, 200, "{\"choices\":[1]}", "couldn't read"], [HTTPRequest.RESULT_SUCCESS, 200, _ok_body(null), "empty"]]:
		replies.clear(); fails.clear()
		mock.merge({"result": cse[0], "code": cse[1], "body": cse[2]}, true)
		ab.chat(c.companion_id, "hello foxy")
		await _frames(t)
		t.check(fails.size() == 1 and str(fails[0]).contains(cse[3]), "chat: failure reason '%s' reported" % cse[3])
		t.check(replies.size() == 1 and str(replies[0]).strip_edges() != "", "chat: failure '%s' still gets an offline reply" % cse[3])
		t.check(Settings.chat_status() == "offline_error" and not ab.is_thinking(c.companion_id), "chat: status shows error, not stuck thinking (%s)" % cse[3])

	# 3 tool-only turn gets a visible reply; success clears the error
	replies.clear(); fails.clear()
	mock.merge({"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": _ok_body(null, [{"id": "1", "type": "function", "function": {"name": "remember", "arguments": "{\"fact\": \"chat test likes towers\"}"}}])}, true)
	ab.chat(c.companion_id, "remember I like towers")
	await _frames(t)
	t.check(replies.size() == 1 and str(replies[0]).contains("remember") and fails.is_empty(), "chat: tool-only reply shows an action line")
	t.check("chat test likes towers" in ab._memory[c.companion_id]["facts"] and Settings.chat_status() == "live", "chat: tool ran and live status restored")

	# 4 messages typed while waiting are queued, answered in order
	replies.clear()
	var n := [0]
	ab.transport = func(_u: String, _h: Array, body: String) -> Dictionary:
		n[0] += 1
		var last: String = JSON.parse_string(body)["messages"].back()["content"]
		return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": _ok_body("re: " + last)}
	ab.chat(c.companion_id, "one"); ab.chat(c.companion_id, "two")
	await _frames(t, 6)
	t.check(replies == ["re: one", "re: two"] and n[0] == 2, "chat: second message queued, both answered in order")

	# 5 offline mode never touches the transport
	replies.clear(); n[0] = 0
	Settings.cfg.set_value("llm", "mode", "canned")
	ab.chat(c.companion_id, "hello")
	await _frames(t)
	t.check(replies.size() == 1 and str(replies[0]) != "" and n[0] == 0, "chat: offline mode answers without network")
	ab.chat(c.companion_id, "   ")
	t.check(replies.size() == 1, "chat: blank input ignored")

	# 6 connection test
	Settings.cfg.set_value("llm", "mode", "live")
	ab.transport = func(_u, _h, _b) -> Dictionary: return {"result": HTTPRequest.RESULT_CANT_RESOLVE, "code": 0, "body": ""}
	var probe := []
	ab.test_connection(func(ok: bool, m: String): probe.append([ok, m]))
	await _frames(t)
	t.check(probe.size() == 1 and not probe[0][0] and str(probe[0][1]).contains("DNS"), "chat: Test AI connection reports DNS failure")

	ab.reply_ready.disconnect(on_r); ab.request_failed.disconnect(on_f); ab.thinking.disconnect(on_t)
	ab.unregister_agent(c)
	ab.brains.erase(c.companion_id); ab._memory.erase(c.companion_id)
	DirAccess.remove_absolute(ab._mem_path(c.companion_id))
	c.queue_free()
	_restore(snap)

## UI: chat panel shows the reply, the failure reason, and escapes BBCode.
static func run_ui(t: Node) -> void:
	var snap := _snap()
	var s = load("res://scenes/main_world.tscn").instantiate()
	t.add_child(s)
	await t.get_tree().create_timer(1.0).timeout
	var ui = s.get_node("UI")
	var comps: Array = t.get_tree().get_nodes_in_group("companions")
	t.check(not comps.is_empty(), "chat ui: companions spawned")
	if comps.is_empty():
		s.queue_free(); _restore(snap); return
	Settings.cfg.set_value("llm", "endpoint", "https://api.x.ai/v1/chat/completions")
	Settings.set_api_key_from_ui("xk-test-mock-key")
	Settings.cfg.set_value("llm", "mode", "live")
	AgentBrain.transport = func(_u, _h, _b) -> Dictionary: return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": _ok_body("UI mock reply [b]x")}
	ui.show_panel("chat")
	ui.chat_target = null
	ui._send("hello [color=red]")
	await _frames(t)
	var txt: String = ui.chat_log.get_parsed_text()
	t.check(ui.chat_target != null, "chat ui: sending with no target picks a companion")
	t.check(txt.contains("UI mock reply [b]x") and txt.contains("hello [color=red]"), "chat ui: reply shown, brackets escaped")
	AgentBrain.transport = func(_u, _h, _b) -> Dictionary: return {"result": HTTPRequest.RESULT_SUCCESS, "code": 401, "body": ""}
	ui._send("again")
	await _frames(t)
	txt = ui.chat_log.get_parsed_text()
	t.check(txt.contains("Live AI unavailable") and txt.contains("rejected"), "chat ui: failure reason shown in the log")
	t.check(ui.chat_status.text.contains("OFFLINE") and ui.chat_status.text.contains("rejected"), "chat ui: status banner shows the error")
	ui.chat_ic = false
	ui._send("ooc note")
	t.check(ui.chat_log.get_parsed_text().contains("not sent to"), "chat ui: OOC message explains it was not sent")
	ui.chat_ic = true
	ui.show_panel("")
	s.queue_free()
	await _frames(t)
	_restore(snap)
