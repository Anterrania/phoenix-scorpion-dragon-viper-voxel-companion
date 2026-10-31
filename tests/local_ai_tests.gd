extends RefCounted
## LAI-1..9: on-device AI (LocalLLM + LlmPrompt + AgentBrain local path) against LlmMockBackend. No network, no model.

static func _frames(t: Node, n := 4) -> void:
	for i in n: await t.get_tree().process_frame

## Pure prompt + parse tests.
static func run_prompt(t: Node) -> void:
	var persona := {"system_prompt": "You are Foxy.", "voice_style": "Warm, bold."}
	var specs := [{"type": "function", "function": {"name": "spawn_structure", "description": "Build.", "parameters": {"type": "object", "properties": {"name": {"type": "string"}, "x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}}, "required": ["name", "x", "y", "z"]}}}]
	var loc := LlmPrompt.local_tool_specs(specs)
	t.check(loc[0]["function"]["parameters"]["required"] == ["name"] and specs[0]["function"]["parameters"]["required"].size() == 4, "lai: local tool specs make coordinates optional (original untouched)")
	var sys := LlmPrompt.system_block(persona, ["Phoenix likes purple fire"], loc, "Phoenix")
	t.check(sys.begins_with("You are Foxy.") and sys.contains("Style: Warm") and sys.contains("purple fire") and sys.contains("<tools>") and sys.contains("<tool_call>"), "lai: system block has persona, style, facts, tools")
	t.check(not LlmPrompt.system_block(persona, [], [], "").contains("<tools>"), "lai: no tools block when the companion has no tools")
	var hist := []
	for i in 40: hist.append({"role": "user" if i % 2 == 0 else "assistant", "content": "turn %d %s" % [i, "x".repeat(200)]})
	var b := LlmPrompt.build(sys, hist, "build me a fire altar", "You are at (1, 2, 3).", 900)
	var p: String = b["prompt"]
	t.check(p.begins_with("<|im_start|>system\n") and p.ends_with("<|im_start|>assistant\n") and p.contains("[You are at (1, 2, 3).]\nbuild me a fire altar"), "lai: ChatML prompt, context rides on the last user turn")
	t.check(int(b["kept"]) > 0 and int(b["kept"]) < 40 and int(b["est_tokens"]) <= 900 and p.contains("turn 39") and not p.contains("turn 0 "), "lai: budget keeps the newest turns, drops the oldest")
	var b2 := LlmPrompt.build(sys, hist.slice(0, 4), "hi", "", 1700)
	t.check(str(b2["prompt"]).begins_with(str(LlmPrompt.build(sys, [], "other", "", 1700)["prompt"]).split("<|im_start|>user")[0]), "lai: system block identical across turns (KV cache reuse)")
	var r := LlmPrompt.parse("On it, darling!\n<tool_call>\n{\"name\": \"spawn_structure\", \"arguments\": {\"name\": \"fire_altar\"}}\n</tool_call>", ["spawn_structure"])
	t.check(r["text"] == "On it, darling!" and r["calls"].size() == 1 and r["calls"][0]["args"]["name"] == "fire_altar", "lai: parse text + hermes tool call")
	r = LlmPrompt.parse("<tool_call>\n{\"name\": \"follow\", \"arguments\": {\"enabled\": true}}", ["follow"])
	t.check(r["calls"].size() == 1 and r["text"] == "", "lai: unclosed tool_call (max_tokens) still parsed")
	r = LlmPrompt.parse("Sure!\n{\"name\": \"emote\", \"arguments\": {\"name\": \"dance\"}}", ["emote"])
	t.check(r["calls"].size() == 1 and r["text"] == "Sure!", "lai: bare JSON tool line parsed and hidden")
	r = LlmPrompt.parse("<tool_call>{\"name\": \"delete_world\", \"arguments\": {}}</tool_call>Nope.", ["emote"])
	t.check(r["calls"].is_empty() and r["text"] == "Nope.", "lai: tools not allowed for the companion are dropped")
	r = LlmPrompt.parse("<tool_call>{not json</tool_call>Hi", [])
	t.check(r["calls"].is_empty() and r["text"] == "Hi", "lai: broken tool JSON ignored, no crash")
	t.check(LlmPrompt.parse("enabled: true", [])["text"] == "" and LlmPrompt.parse("I'm here: always.", [])["text"] == "I'm here: always.", "lai: bare argument fragments hidden, normal text kept")
	t.check(LlmPrompt.visible("Hello there <tool") == "Hello there" and LlmPrompt.visible("Hi <tool_call>{\"na") == "Hi" and LlmPrompt.visible("a < b") == "a < b", "lai: streaming hides half-typed tool markup only")
	t.check(LlmPrompt.plausible("spawn_structure", "Build me a fire altar") and not LlmPrompt.plausible("follow", "build me a fire altar") and LlmPrompt.plausible("unknown_tool", "x"), "lai: tool-intent guard (small-model misfires)")
	t.check(LlmPrompt.estimate_tokens("x".repeat(320)) >= 100, "lai: token estimate is conservative")

## Settings modes + LocalLLM state machine with the mock backend.
static func run_state(t: Node) -> void:
	var llm: Node = t.get_node("/root/LocalLLM")
	var snap := {"mode": Settings.cfg.get_value("llm", "mode", null), "mode_set": Settings.cfg.get_value("llm", "mode_set", null)}
	t.check(Settings.DEFAULTS["llm"]["mode"] == "local", "lai: on-device AI is the default mode")
	Settings.cfg.set_value("llm", "mode", "canned")
	if Settings.cfg.has_section_key("llm", "mode_set"): Settings.cfg.erase_section_key("llm", "mode_set")
	t.check(Settings.effective_mode() == "local" or Settings.build_default_key() != "", "lai: old saved default 'canned' migrates to local")
	Settings.cfg.set_value("llm", "mode_set", true)
	t.check(Settings.effective_mode() == "canned" and Settings.chat_status() == "offline_mode" and not Settings.local_ai(), "lai: explicit offline choice still respected")
	Settings.cfg.set_value("llm", "mode", "local")
	t.check(Settings.effective_mode() == "local" and Settings.chat_status().begins_with("local_"), "lai: local mode reports local status")

	var mock := LlmMockBackend.new()
	llm.use_backend(mock, "mock")
	llm.delete_model()
	t.check(llm.backend_kind == "mock" and llm.state == "not_downloaded" and not llm.can_chat() and not Settings.local_ai(), "lai: headless uses mock; no model -> not downloaded")
	t.check(Settings.chat_status_text("local_not_downloaded").contains("Persona replies"), "lai: clear not-downloaded text")
	var cat: Dictionary = llm.load_catalog()
	var ok_cat: bool = not cat["models"].is_empty()
	for m in cat["models"]:
		ok_cat = ok_cat and str(m["url"]).begins_with("https://huggingface.co/Qwen/") and str(m["sha256"]).length() == 64 and int(m["size"]) > 100000000 and m["license"] == "Apache-2.0"
	t.check(ok_cat and str(cat["default"]).contains("0.5b"), "lai: catalog: Qwen2.5 Apache-2.0, https, sha256, size; 0.5B default")
	# Wi-Fi only
	mock.net = "cell"
	t.check(not llm.start_download(false) and llm.state == "waiting_wifi", "lai: no download on mobile data by default")
	t.check(Settings.chat_status_text("local_waiting_wifi").contains("Wi-Fi"), "lai: waiting-for-Wi-Fi text")
	mock.net = "wifi"
	mock.dl_error = "sha256 mismatch"
	t.check(llm.start_download(false) and llm.state == "downloading", "lai: Wi-Fi download starts")
	await _frames(t)
	t.check(llm.state == "error" and llm.last_error.contains("sha256") and not llm.is_downloaded(), "lai: bad checksum -> error, model not marked ok")
	mock.dl_error = ""
	llm.start_download(false)
	await _frames(t)
	t.check(llm.is_downloaded() and llm.state == "downloaded" and llm.can_chat() and Settings.local_ai(), "lai: verified download -> ready to chat")
	t.check(FileAccess.get_file_as_string(llm.model_path() + ".ok").strip_edges() == str(llm.model()["sha256"]), "lai: .ok marker holds the sha256")
	# generate: lazy load + streaming
	var pieces := []
	var done := []
	llm.generate("<|im_start|>user\nhello fox<|im_end|>\n<|im_start|>assistant\n", {}, func(s): pieces.append(s), func(r): done.append(r))
	await _frames(t, 8)
	t.check(done.size() == 1 and str(done[0]["text"]).contains("hello fox") and pieces.size() > 1 and llm.state == "ready", "lai: lazy load, streamed pieces, one done")
	t.check(mock.threads == 4, "lai: 4 threads on an 8-core phone when cool")
	# thermal throttle + pause
	DeviceProfile.set_fake({"thermal": 3, "network": "wifi", "ram_mb": 6000, "battery_pct": 80, "charging": false})
	llm._on_device_changed()
	t.check(llm.throttled() and llm.threads() == 2 and llm.max_tokens(160) < 160 and llm.can_chat(), "lai: thermal SEVERE -> 2 threads, shorter replies")
	DeviceProfile.set_fake({"thermal": 4, "network": "wifi", "ram_mb": 6000, "battery_pct": 80, "charging": false})
	llm._on_device_changed()
	t.check(llm.state == "paused_hot" and not llm.can_chat() and not Settings.local_ai() and Settings.chat_status() == "local_paused_hot", "lai: thermal CRITICAL -> paused, chat falls back")
	DeviceProfile.set_fake({"thermal": 0, "network": "wifi", "ram_mb": 1024, "battery_pct": 80, "charging": false})
	llm._on_device_changed()
	t.check(llm.state == "unsupported_ram" and not llm.can_chat(), "lai: too little RAM -> unsupported_ram")
	DeviceProfile.set_fake({"thermal": 0, "network": "wifi", "ram_mb": 6000, "battery_pct": 80, "charging": false})
	llm._on_device_changed()
	t.check(llm.can_chat() and not llm.throttled(), "lai: cooled down -> back on")
	DeviceProfile.set_fake(null)
	llm._on_device_changed()
	# background pause cancels the running reply
	done.clear()
	llm.generate("<|im_start|>user\nlong story<|im_end|>\n<|im_start|>assistant\n", {}, Callable(), func(r): done.append(r))
	llm.set_paused("background")
	await _frames(t, 6)
	t.check(done.size() == 1 and (str(done[0]["error"]).begins_with("paused") or str(done[0]["stop"]) == "aborted") and llm.state == "paused_bg", "lai: background pause cancels generation")
	llm.set_paused("")
	t.check(llm.can_chat(), "lai: resume after background")
	# idle unload
	llm._idle_left = 0.0
	llm._process(0.1)
	t.check(not mock.loaded and llm.state == "downloaded", "lai: idle -> model unloaded (RAM given back)")
	t.check(llm.summary()["license"] == "Apache-2.0" and llm.summary()["backend"] == "mock", "lai: summary for diagnostics")
	for k in snap:
		if snap[k] == null:
			if Settings.cfg.has_section_key("llm", k): Settings.cfg.erase_section_key("llm", k)
		else: Settings.cfg.set_value("llm", k, snap[k])
	t.set_meta("lai_mock", mock)

## AgentBrain local path: persona + memory in the prompt, streaming, tool dispatch through permissions, fallbacks.
static func run_chat(t: Node) -> void:
	var llm: Node = t.get_node("/root/LocalLLM")
	var mock: LlmMockBackend = t.get_meta("lai_mock") if t.has_meta("lai_mock") else null
	if mock == null or not llm.can_chat():
		t.check(false, "lai: chat tests need run_state first"); return
	var ab: Node = AgentBrain
	var snap := {"mode": Settings.cfg.get_value("llm", "mode", null), "mode_set": Settings.cfg.get_value("llm", "mode_set", null), "key": Settings.user_api_key()}
	Settings.set_api_key("")
	Settings.cfg.set_value("llm", "mode", "local"); Settings.cfg.set_value("llm", "mode_set", true)
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar companion_id := \"\"\nvar persona := {}\nvar calls := []\nfunc get_player_position() -> Vector3: return Vector3(5, 0, 5)\nfunc tool_spawn_structure(a: Dictionary) -> Dictionary: calls.append(a); return {\"ok\": true}\nfunc tool_emote(a: Dictionary) -> Dictionary: calls.append(a); return {\"ok\": true}\n"
	gs.reload()
	var c := Node3D.new(); c.set_script(gs)
	c.companion_id = "lai_test_agent"
	c.persona = {"name": "Foxy Test", "system_prompt": "You are Foxy Test, a fire goddess.", "voice_style": "Warm.", "tools": {"shared": ["remember", "emote"], "world_only": ["spawn_structure"]}}
	t.add_child(c)
	ab.register_agent(c)
	ab._memory[c.companion_id]["facts"] = ["Phoenix likes purple fire"]
	var replies := []
	var partials := []
	var fails := []
	var on_r := func(id: String, txt: String): if id == c.companion_id: replies.append(txt)
	var on_p := func(id: String, txt: String): if id == c.companion_id: partials.append(txt)
	var on_f := func(id: String, e: String): if id == c.companion_id: fails.append(e)
	var tools := []
	var on_x := func(id: String, tool: String, res: Dictionary): if id == c.companion_id: tools.append([tool, res])
	ab.reply_ready.connect(on_r); ab.reply_partial.connect(on_p); ab.request_failed.connect(on_f); ab.tool_executed.connect(on_x)
	t.check(Settings.local_ai() and not Settings.live_ai(), "lai: no key -> on-device chat")

	mock.prompts.clear()
	mock.responder = func(_p: String) -> String: return "Hello sweet flame, I am right here."
	ab.chat(c.companion_id, "hi Foxy")
	await _frames(t, 8)
	var pr: String = mock.prompts.back() if not mock.prompts.is_empty() else ""
	t.check(replies == ["Hello sweet flame, I am right here."] and fails.is_empty(), "lai: local reply reaches reply_ready once")
	t.check(pr.contains("You are Foxy Test") and pr.contains("purple fire") and pr.contains("\"spawn_structure\"") and pr.contains("Player is at (5.0, 0.0, 5.0)") and pr.contains("hi Foxy"), "lai: prompt has persona, memory facts, tools and position")
	t.check(not partials.is_empty() and str(partials.back()).begins_with("Hello sweet"), "lai: reply streams via reply_partial")
	t.check(ab._memory[c.companion_id]["history"].back()["content"] == "Hello sweet flame, I am right here.", "lai: local turn saved to memory")

	# tool call: goes through dispatch_tool, coordinates filled in front of the companion
	replies.clear()
	mock.responder = func(_p: String) -> String: return "Rising from the flames!\n<tool_call>\n{\"name\": \"spawn_structure\", \"arguments\": {\"name\": \"fire_altar\"}}\n</tool_call>"
	ab.chat(c.companion_id, "build me a fire altar")
	await _frames(t, 8)
	# Goes through dispatch_tool: this test companion has no land rights, so Tiers.can/LandGate refuses the build.
	var ran: bool = c.calls.size() == 1 and c.calls[0]["name"] == "fire_altar" and c.calls[0].has("x")
	var gated: bool = not tools.is_empty() and tools.back()[0] == "spawn_structure" and str(tools.back()[1].get("error", "")).begins_with("land:")
	t.check(replies == ["Rising from the flames!"] and (ran or gated), "lai: model tool call goes through dispatch_tool + LandGate")
	var filled: Dictionary = ab._local_args(c, "spawn_structure", {"name": "altar thing"})
	t.check(filled.has("x") and filled.has("y") and filled.has("z") and filled["name"] == "fire_altar" and is_equal_approx(float(filled["z"]), -3.0), "lai: missing coordinates filled 3 m in front, bad names mapped")
	t.check(ab._local_args(c, "carve_area", {"radius": "huge"})["radius"] == 2.0 and ab._local_args(c, "move_to", {})["x"] == 5.0, "lai: carve radius default, move_to goes to the player")
	t.check(not str(partials.back()).contains("tool_call"), "lai: tool markup never streamed to the player")
	# misfire guard + not-allowed tool
	replies.clear(); c.calls.clear()
	mock.responder = func(_p: String) -> String: return "Okay!\n<tool_call>{\"name\": \"spawn_structure\", \"arguments\": {\"name\": \"tower\"}}</tool_call><tool_call>{\"name\": \"carve_area\", \"arguments\": {}}</tool_call>"
	ab.chat(c.companion_id, "how are you today?")
	await _frames(t, 8)
	t.check(replies == ["Okay!"] and c.calls.is_empty(), "lai: unrelated or unpermitted tool calls are not run")
	# tool-only answer gets a visible line
	replies.clear()
	mock.responder = func(_p: String) -> String: return "<tool_call>{\"name\": \"emote\", \"arguments\": {\"name\": \"dance\"}}</tool_call>"
	ab.chat(c.companion_id, "dance for me")
	await _frames(t, 8)
	t.check(replies.size() == 1 and str(replies[0]).contains("emote") and c.calls.back()["name"] == "dance", "lai: tool-only reply still shows a line")
	# context_full -> retry with a smaller prompt
	replies.clear(); mock.prompts.clear()
	mock.gen_error = "context_full"
	mock.responder = func(_p: String) -> String: return "Shorter now."
	ab.chat(c.companion_id, "tell me everything")
	await _frames(t, 12)
	t.check(replies == ["Shorter now."] and mock.prompts.size() == 2 and str(mock.prompts[1]).length() <= str(mock.prompts[0]).length(), "lai: context_full retried with a smaller budget")
	# engine error -> canned persona reply, still exactly one reply
	replies.clear(); fails.clear()
	mock.gen_error = "decode failed"
	ab.chat(c.companion_id, "hello again")
	await _frames(t, 8)
	t.check(replies.size() == 1 and str(replies[0]) != "" and fails.size() == 1 and str(fails[0]).begins_with("on-device AI"), "lai: engine error -> one persona reply + reason")
	t.check(not ab.is_thinking(c.companion_id), "lai: not stuck thinking after an error")
	# paused (hot) -> canned without touching the engine
	replies.clear(); mock.prompts.clear()
	llm.set_paused("hot")
	ab.chat(c.companion_id, "you there?")
	await _frames(t, 6)
	t.check(replies.size() == 1 and mock.prompts.is_empty(), "lai: hot phone -> persona reply, engine untouched")
	llm.set_paused("")
	# live failure falls back to on-device before canned
	replies.clear(); mock.prompts.clear()
	Settings.cfg.set_value("llm", "mode", "live"); Settings.cfg.set_value("llm", "endpoint", "https://api.x.ai/v1/chat/completions")
	Settings.set_api_key("xk-test-mock-key")
	ab.transport = func(_u, _h, _b) -> Dictionary: return {"result": HTTPRequest.RESULT_CANT_RESOLVE, "code": 0, "body": ""}
	mock.responder = func(_p: String) -> String: return "Local backup here."
	ab.chat(c.companion_id, "hey")
	await _frames(t, 10)
	t.check(replies == ["Local backup here."] and mock.prompts.size() == 1, "lai: live failure -> on-device reply (not canned)")
	ab.transport = Callable()
	Settings.last_chat_error = ""

	ab.reply_ready.disconnect(on_r); ab.reply_partial.disconnect(on_p); ab.request_failed.disconnect(on_f); ab.tool_executed.disconnect(on_x)
	ab.unregister_agent(c)
	ab.brains.erase(c.companion_id); ab._memory.erase(c.companion_id)
	DirAccess.remove_absolute(ab._mem_path(c.companion_id))
	c.queue_free()
	mock.responder = Callable()
	llm.delete_model()
	t.check(not llm.is_downloaded() and llm.state == "not_downloaded", "lai: delete model")
	Settings.set_api_key(snap["key"])
	for k in ["mode", "mode_set"]:
		if snap[k] == null:
			if Settings.cfg.has_section_key("llm", k): Settings.cfg.erase_section_key("llm", k)
		else: Settings.cfg.set_value("llm", k, snap[k])

static func run_docs(t: Node) -> void:
	var d := FileAccess.get_file_as_string("res://docs/modules/LOCAL_AI.md")
	t.check(d.contains("Apache-2.0") and d.contains("llama.cpp") and d.contains("MIT") and d.contains("thermal"), "lai: docs/modules/LOCAL_AI.md (licenses, power)")
	var tr := FileAccess.get_file_as_string("res://docs/TASK_TRACKER.csv") if FileAccess.file_exists("res://docs/TASK_TRACKER.csv") else FileAccess.get_file_as_string("res://TASK_TRACKER.csv")
	t.check(tr.contains("LAI-1,") and tr.contains("LAI-9,"), "lai: tracker rows")
	t.check(FileAccess.file_exists("res://addons/viper_llm/plugin.cfg") and FileAccess.file_exists("res://android/plugins/viper_llm/fetch_llama.sh"), "lai: plugin + pinned fetch script present")
