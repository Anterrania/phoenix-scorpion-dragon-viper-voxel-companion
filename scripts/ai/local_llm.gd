extends Node
## LocalLLM (autoload): on-device companion AI, no API key, no server.
## Android: the self-written ViperLLM plugin (android/plugins/viper_llm, llama.cpp under MIT) runs a small
## Apache-2.0 Qwen2.5 GGUF model on the CPU. Desktop / CI / tests: LlmMockBackend (same API), so headless runs pass.
##
## Model file: downloaded once (Wi-Fi only by default) to user://models/, SHA-256 checked by the plugin, then a
## "<file>.ok" marker holding the hash is written. Loaded lazily on the first chat (or warm_up() when the chat
## panel opens) and unloaded after IDLE_UNLOAD_S without use to give the RAM back.
## PowerData: thermal >= PAUSE_THERMAL or app in background -> paused (running reply cancelled, chat falls back
## to offline replies); thermal >= THROTTLE_THERMAL, saver mode or low battery -> 2 threads and shorter replies.
## Docs: docs/modules/LOCAL_AI.md.

signal state_changed(state: String)
signal progress_changed(done_mb: float, total_mb: float)

const PLUGIN := "ViperLLM"
const CATALOG := "res://data/ai/local_models.json"
const MODEL_DIR := "user://models"
const SECTION := "local_ai"
const IDLE_UNLOAD_S := 300.0
const GEN_TIMEOUT_S := 120.0
const PAUSE_THERMAL := 4        # Android THERMAL_STATUS_CRITICAL
const THROTTLE_THERMAL := 3     # THERMAL_STATUS_SEVERE (AutoConfig.THERMAL_STEP_DOWN)
const LOW_BATTERY_PCT := 15
const DEFAULTS := {"model": "auto", "wifi_only": true, "auto_download": true, "enabled": true}

## unsupported | unsupported_ram | not_downloaded | waiting_wifi | downloading | downloaded | loading | ready | paused_hot | paused_bg | error
var state := "not_downloaded"
var last_error := ""
var backend: Object = null
var backend_kind := ""          # "native" | "mock" | ""
var backend_desc := ""          # CPU variant the plugin picked (e.g. libggml-cpu-android_armv8.2_2.so)
var dl_done_mb := 0.0
var dl_total_mb := 0.0
var last_stats: Dictionary = {}
var _catalog: Dictionary = {}
var _queue: Array = []          # pending {req, prompt, opts, on_piece, on_done}
var _active: Dictionary = {}    # in-flight request
var _next_req := 1
var _loaded_id := ""
var _loading := false
var _idle_left := 0.0
var _gen_left := 0.0
var _thermal := -1
var _power := "balanced-saver"
var _paused_reason := ""
var _store: ConfigFile = null   # tests: in-memory settings

func _ready() -> void:
	_catalog = load_catalog()
	DirAccess.make_dir_recursive_absolute(MODEL_DIR)
	if Engine.has_singleton(PLUGIN):
		use_backend(Engine.get_singleton(PLUGIN), "native")
	else:
		use_backend(LlmMockBackend.new(), "mock")
	var dp := get_node_or_null("/root/DeviceProfile")
	if dp and dp.has_signal("caps_changed"): dp.caps_changed.connect(func(_c): _on_device_changed())
	var ac := get_node_or_null("/root/AutoConfig")
	if ac and ac.has_signal("power_changed"): ac.power_changed.connect(func(m: String, _r): _power = m; _on_device_changed())
	_on_device_changed()
	# First run: fetch the model in the background once on Wi-Fi (real phones only; the mock never auto-downloads).
	if backend_kind == "native": get_tree().create_timer(8.0).timeout.connect(maybe_auto_download)

## Swap the backend (tests pass an LlmMockBackend). kind: "native" | "mock".
func use_backend(b: Object, kind := "mock") -> void:
	if backend:
		for s in ["llm_loaded", "llm_token", "llm_done", "dl_progress", "dl_done"]:
			for c in backend.get_signal_connection_list(s):
				if c["callable"].get_object() == self: backend.disconnect(s, c["callable"])
	backend = b
	backend_kind = kind
	_queue.clear(); _active = {}; _loaded_id = ""; _loading = false
	if b == null: _set_state("unsupported"); return
	if kind == "native" and not bool(b.call("native_ok")):
		last_error = str(b.call("native_error"))
		_set_state("unsupported"); return
	backend_desc = str(b.call("init_backend"))
	if kind == "native" and backend_desc == "none":
		last_error = "no CPU backend could load on this phone"
		_set_state("unsupported"); return
	b.connect("llm_loaded", _on_loaded, CONNECT_DEFERRED)
	b.connect("llm_token", _on_token, CONNECT_DEFERRED)
	b.connect("llm_done", _on_done, CONNECT_DEFERRED)
	b.connect("dl_progress", _on_dl_progress, CONNECT_DEFERRED)
	b.connect("dl_done", _on_dl_done, CONNECT_DEFERRED)
	_refresh_state()

# ---------- settings + catalog ----------
func use_store(c: ConfigFile) -> void: _store = c

func pref(key: String) -> Variant:
	var d: Variant = DEFAULTS.get(key)
	if _store: return _store.get_value(SECTION, key, d)
	var s := get_node_or_null("/root/Settings")
	return s.get_value(SECTION, key, d) if s else d

func set_pref(key: String, v: Variant) -> void:
	if _store: _store.set_value(SECTION, key, v)
	else: Settings.set_value(SECTION, key, v)
	_refresh_state()

static func load_catalog() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG)) if FileAccess.file_exists(CATALOG) else null
	return d if d is Dictionary else {"default": "", "models": []}

func models() -> Array: return _catalog.get("models", [])

func model_entry(id: String) -> Dictionary:
	for m in models():
		if str(m.get("id")) == id: return m
	return {}

## The model to use: the user's pick, or "auto" = the catalog default (0.5B: fast on any phone with 2 GB+).
func model_id() -> String:
	var p := str(pref("model"))
	if p != "auto" and not model_entry(p).is_empty(): return p
	return str(_catalog.get("default", ""))

func model() -> Dictionary: return model_entry(model_id())

func model_path(m: Dictionary = {}) -> String:
	if m.is_empty(): m = model()
	return MODEL_DIR.path_join(str(m.get("file", "missing.gguf")))

func is_downloaded(m: Dictionary = {}) -> bool:
	if m.is_empty(): m = model()
	var p := model_path(m)
	if not FileAccess.file_exists(p) or not FileAccess.file_exists(p + ".ok"): return false
	return FileAccess.get_file_as_string(p + ".ok").strip_edges() == str(m.get("sha256", ""))

func ram_ok(m: Dictionary = {}) -> bool:
	if m.is_empty(): m = model()
	var ram := int(_dp("ram_mb", -1))
	return ram <= 0 or ram >= int(m.get("min_ram_mb", 0))

# ---------- state ----------
func _set_state(s: String) -> void:
	if s == state: return
	state = s
	state_changed.emit(s)

func _refresh_state() -> void:
	if backend == null or state == "unsupported": return
	if model().is_empty(): last_error = "no model in catalog"; _set_state("error"); return
	if _paused_reason != "": _set_state("paused_bg" if _paused_reason == "background" else "paused_hot"); return
	if not ram_ok(): _set_state("unsupported_ram"); return
	if bool(backend.call("is_downloading")): _set_state("downloading"); return
	if not is_downloaded():
		if state in ["waiting_wifi", "error"]: return
		_set_state("not_downloaded"); return
	if _loading: _set_state("loading"); return
	_set_state("ready" if _loaded_id == model_id() and bool(backend.call("is_loaded")) else "downloaded")

## Chat can use the on-device model right now (it may still need a few seconds to load).
func can_chat() -> bool:
	return bool(pref("enabled")) and state in ["downloaded", "loading", "ready"]

func is_busy() -> bool: return not _active.is_empty() or not _queue.is_empty()

## Short status key for Settings.chat_status(): "local_" + state.
func status() -> String: return "local_" + state

static func status_text(st: String, done_mb := 0.0, total_mb := 0.0) -> String:
	match st:
		"local_ready": return "● ON-DEVICE AI ready (no key, works offline)"
		"local_downloaded": return "● ON-DEVICE AI ready (loads on first message)"
		"local_loading": return "● ON-DEVICE AI waking up…"
		"local_downloading": return "◐ Downloading on-device AI %d / %d MB. Persona replies until it's done." % [int(done_mb), int(total_mb)]
		"local_waiting_wifi": return "○ On-device AI downloads on Wi-Fi (Settings › Companion AI to use mobile data). Persona replies for now."
		"local_not_downloaded": return "○ On-device AI not downloaded yet (Settings › Companion AI). Persona replies for now."
		"local_paused_hot": return "○ On-device AI paused: phone is hot. Persona replies until it cools down."
		"local_paused_bg": return "○ On-device AI paused in the background."
		"local_unsupported": return "○ On-device AI isn't available on this device. Persona replies (or add an API key for live AI)."
		"local_unsupported_ram": return "○ This phone has too little memory for the on-device AI. Persona replies."
		_: return "○ On-device AI hit a problem. Persona replies for now."

# ---------- power / thermal ----------
func _dp(key: String, fb: Variant) -> Variant:
	var dp := get_node_or_null("/root/DeviceProfile")
	return dp.get_value(key, fb) if dp else fb

func _on_device_changed() -> void:
	_thermal = int(_dp("thermal", -1))
	var ac := get_node_or_null("/root/AutoConfig")
	var bg := bool(ac.background) if ac and "background" in ac else false
	var why := "background" if bg or _power == "background" else ("hot" if _thermal >= PAUSE_THERMAL else "")
	set_paused(why)
	_refresh_state()   # RAM / Wi-Fi may have changed even when the pause reason didn't
	if why == "" and backend and _loaded_id != "": backend.call("set_threads", threads())
	if why == "" and str(_dp("network", "")) == "wifi" and state == "waiting_wifi": maybe_auto_download()

## why: "" (run), "hot", "background". Pausing cancels the running reply (it ends with stop "aborted").
func set_paused(why: String) -> void:
	if why == _paused_reason: return
	_paused_reason = why
	if why != "" and backend and not _active.is_empty(): backend.call("cancel")
	_refresh_state()

func throttled() -> bool:
	if _thermal >= THROTTLE_THERMAL or _power == "saver": return true
	return int(_dp("battery_pct", 100)) <= LOW_BATTERY_PCT and not bool(_dp("charging", false))

## Big cores only: 4 threads on 8-core phones, 2 when throttled or on small phones.
func threads() -> int:
	var cores := int(backend.call("cpu_count")) if backend else 4
	if throttled() or cores < 6: return 2
	return 4

func max_tokens(requested := 0) -> int:
	var n := requested if requested > 0 else int(model().get("max_tokens", 160))
	return maxi(32, int(n * 0.6)) if throttled() else n

func n_ctx() -> int: return int(model().get("n_ctx", 2048))

## Prompt budget for LlmPrompt.build (leaves room for the reply).
func prompt_budget() -> int: return n_ctx() - max_tokens() - 64

# ---------- download ----------
func maybe_auto_download() -> void:
	if backend == null or not bool(pref("auto_download")) or not bool(pref("enabled")): return
	if state in ["not_downloaded", "waiting_wifi"]: start_download(false)

## allow_metered: the player confirmed mobile data. Returns false if it could not start.
func start_download(allow_metered := false) -> bool:
	if backend == null or state in ["unsupported", "unsupported_ram"] or is_downloaded(): return false
	if bool(backend.call("is_downloading")): return true
	var m := model()
	var net := str(backend.call("network_kind"))
	if bool(pref("wifi_only")) and not allow_metered and net != "wifi":
		_set_state("waiting_wifi"); return false
	var need_mb := int(int(m.get("size", 0)) / 1048576) + 64
	if int(backend.call("free_space_mb", ProjectSettings.globalize_path(MODEL_DIR))) < need_mb:
		last_error = "not enough free space (%d MB needed)" % need_mb
		_set_state("error"); return false
	dl_total_mb = float(m.get("size", 0)) / 1048576.0
	var ok := bool(backend.call("download", str(m["url"]), ProjectSettings.globalize_path(model_path(m)), str(m["sha256"]), int(m["size"]), allow_metered or not bool(pref("wifi_only"))))
	if ok: last_error = ""; _set_state("downloading")
	return ok

func cancel_download() -> void:
	if backend: backend.call("cancel_download")

## Removes the model file (and partial download). Never touches anything else.
func delete_model(id := "") -> void:
	var m := model() if id == "" else model_entry(id)
	if m.is_empty(): return
	if model_id() == str(m.get("id")) and backend and _loaded_id != "":
		backend.call("unload"); _loaded_id = ""
	for suffix in ["", ".ok", ".part"]:
		if FileAccess.file_exists(model_path(m) + suffix): DirAccess.remove_absolute(model_path(m) + suffix)
	if state in ["error", "waiting_wifi"]: _set_state("not_downloaded")
	_refresh_state()

func _on_dl_progress(done_mb: float, total_mb: float) -> void:
	dl_done_mb = done_mb
	if total_mb > 0.0: dl_total_mb = total_mb
	progress_changed.emit(dl_done_mb, dl_total_mb)

func _on_dl_done(ok: bool, path: String, err: String) -> void:
	var m := model()
	if ok and path == ProjectSettings.globalize_path(model_path(m)):
		var f := FileAccess.open(model_path(m) + ".ok", FileAccess.WRITE)
		if f: f.store_string(str(m.get("sha256", ""))); f.close()
		last_error = ""
		_set_state("downloaded")
	elif err == "waiting_wifi":
		_set_state("waiting_wifi")
	elif err == "cancelled":
		_set_state("not_downloaded")
	else:
		last_error = err
		_set_state("error")
	_refresh_state()

# ---------- load + generate ----------
## Load now so the first reply is quick (called when the chat panel opens).
func warm_up() -> void:
	if can_chat() and _loaded_id != model_id() and not _loading: _load()

func _load() -> void:
	_loading = true
	_set_state("loading")
	backend.call("load_model", ProjectSettings.globalize_path(model_path()), n_ctx(), threads())

func _on_loaded(ok: bool, info_or_err: String) -> void:
	_loading = false
	if ok:
		_loaded_id = model_id(); last_error = ""; _idle_left = IDLE_UNLOAD_S
		_set_state("ready")
		_pump()
	else:
		_loaded_id = ""; last_error = info_or_err
		_set_state("error")
		_fail_all("load_failed: " + info_or_err)

## Queue a completion. opts: max_tokens, temperature, top_p, seed. on_piece(text_so_far) while streaming;
## on_done(result) once: {text, error, stop, prompt_tokens, reused_tokens, gen_tokens, prefill_ms, gen_ms}.
## Returns the request id, or 0 when the model can't run now (on_done is still called, with an error).
func generate(prompt: String, opts: Dictionary, on_piece: Callable, on_done: Callable) -> int:
	if not can_chat():
		on_done.call_deferred({"text": "", "error": "unavailable: " + state, "stop": "error"})
		return 0
	var req := _next_req; _next_req += 1
	_queue.append({"req": req, "prompt": prompt, "opts": opts, "on_piece": on_piece, "on_done": on_done, "text": ""})
	if _loaded_id != model_id() or not bool(backend.call("is_loaded")):
		if not _loading: _load()
	else:
		_pump()
	return req

func _pump() -> void:
	if not _active.is_empty() or _queue.is_empty() or _loaded_id == "": return
	_active = _queue.pop_front()
	var o: Dictionary = _active["opts"]
	_gen_left = GEN_TIMEOUT_S
	backend.call("generate", int(_active["req"]), str(_active["prompt"]), max_tokens(int(o.get("max_tokens", 0))),
		float(o.get("temperature", 0.7)), float(o.get("top_p", 0.9)), int(o.get("seed", -1)))

func cancel_all() -> void:
	_fail_all("cancelled")
	if backend: backend.call("cancel")

func _fail_all(err: String) -> void:
	var all := _queue.duplicate()
	if not _active.is_empty(): all.push_front(_active)
	_queue.clear(); _active = {}
	for r in all: r["on_done"].call({"text": r.get("text", ""), "error": err, "stop": "error"})

func _on_token(req: int, piece: String) -> void:
	if _active.is_empty() or int(_active["req"]) != req: return
	_active["text"] += piece
	_gen_left = GEN_TIMEOUT_S
	if _active["on_piece"].is_valid(): _active["on_piece"].call(_active["text"])

func _on_done(req: int, result_json: String) -> void:
	if _active.is_empty() or int(_active["req"]) != req: return
	var r: Variant = JSON.parse_string(result_json)
	var res: Dictionary = r if r is Dictionary else {"text": _active["text"], "error": "bad result", "stop": "error"}
	if str(res.get("stop")) == "aborted" and _paused_reason != "": res["error"] = "paused_" + _paused_reason
	last_stats = res.duplicate(); last_stats.erase("text")
	var cb: Callable = _active["on_done"]
	_active = {}
	_idle_left = IDLE_UNLOAD_S
	cb.call(res)
	_pump()

func _process(delta: float) -> void:
	if not _active.is_empty():
		_gen_left -= delta
		if _gen_left <= 0.0:
			backend.call("cancel")
			var cb: Callable = _active["on_done"]; var t: String = _active["text"]
			_active = {}
			cb.call({"text": t, "error": "timeout", "stop": "error"})
			_pump()
	elif _loaded_id != "" and _queue.is_empty():
		_idle_left -= delta
		if _idle_left <= 0.0:
			backend.call("unload"); _loaded_id = ""
			_refresh_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: set_paused("background")
	elif what == NOTIFICATION_APPLICATION_RESUMED: _on_device_changed()

## One-line summary for Settings / diagnostics.
func summary() -> Dictionary:
	var m := model()
	return {"state": state, "backend": backend_kind, "cpu": backend_desc, "model": str(m.get("name", "")), "license": str(m.get("license", "")),
		"size_mb": int(int(m.get("size", 0)) / 1048576), "threads": threads(), "throttled": throttled(), "error": last_error, "stats": last_stats}
