class_name LlmMockBackend
extends RefCounted
## Stand-in for the ViperLLM Android plugin on desktop, CI and in tests (no native code, no network).
## Same methods and signals as android/plugins/viper_llm/.../ViperLlmPlugin.kt, so LocalLLM can't tell them apart.
## Signals are emitted deferred, like the plugin's (which come from worker threads).

signal llm_loaded(ok: bool, info_or_err: String)
signal llm_token(req: int, piece: String)
signal llm_done(req: int, result_json: String)
signal dl_progress(done_mb: float, total_mb: float)
signal dl_done(ok: bool, path: String, err: String)

## Tests: Callable(prompt: String) -> String. Default answers like a tiny in-character model.
var responder: Callable = Callable()
var net := "wifi"           # network_kind(): wifi | cell | none
var free_mb := 100000
var load_error := ""        # non-empty: load_model fails with this message
var gen_error := ""         # non-empty: next generate fails with this error ("context_full" etc.), then clears
var dl_error := ""          # non-empty: download fails with this message
var loaded := false
var threads := 0
var prompts: Array = []     # every prompt generate() received (tests inspect)
var _cancel := false
var _downloading := false
var _busy := 0

func get_plugin_version() -> int: return 1
func native_ok() -> bool: return true
func native_error() -> String: return ""
func init_backend() -> String: return "mock"
func cpu_count() -> int: return 8
func is_loaded() -> bool: return loaded
func is_busy() -> bool: return _busy > 0
func info() -> String: return JSON.stringify({"loaded": loaded, "model": "mock", "threads": threads})
func network_kind() -> String: return net
func free_space_mb(_dir: String) -> int: return free_mb
func is_downloading() -> bool: return _downloading
func cancel_download() -> void: _cancel = true
func set_threads(n: int) -> void: threads = n
func cancel() -> void: _cancel = true
func unload() -> void: loaded = false

func load_model(path: String, _n_ctx: int, n_threads: int) -> void:
	threads = n_threads
	var ok := load_error == "" and FileAccess.file_exists(path)
	loaded = ok
	_emit_loaded.call_deferred(ok, info() if ok else (load_error if load_error != "" else "model file missing"))

func _emit_loaded(ok: bool, s: String) -> void: llm_loaded.emit(ok, s)

func generate(req: int, prompt: String, max_tokens: int, _temp: float, _top_p: float, _seed: int) -> void:
	prompts.append(prompt)
	_cancel = false
	_busy += 1
	_run.call_deferred(req, prompt, max_tokens)

func _run(req: int, prompt: String, max_tokens: int) -> void:
	_busy -= 1
	if gen_error != "":
		var e := gen_error; gen_error = ""
		llm_done.emit(req, JSON.stringify({"text": "", "error": e, "stop": "error", "prompt_tokens": prompt.length() / 3}))
		return
	var out := str(responder.call(prompt)) if responder.is_valid() else _default_reply(prompt)
	var pieces := out.split(" ")
	var text := ""
	var n := 0
	var stop := "eos"
	for i in pieces.size():
		if _cancel: stop = "aborted"; break
		if n >= max_tokens: stop = "max_tokens"; break
		var p: String = pieces[i] + (" " if i < pieces.size() - 1 else "")
		text += p; n += 1
		llm_token.emit(req, p)
	llm_done.emit(req, JSON.stringify({"text": text, "error": "", "stop": stop, "prompt_tokens": prompt.length() / 3,
		"reused_tokens": 0, "gen_tokens": n, "prefill_ms": 1, "gen_ms": 1}))

static func _default_reply(prompt: String) -> String:
	var u := prompt.rsplit("<|im_start|>user\n", true, 1)
	var said := u[1].split("<|im_end|>")[0].strip_edges() if u.size() > 1 else ""
	if said.contains("]\n"): said = said.split("]\n", true, 1)[1]
	return "Mm, I hear you: %s" % said.left(60)

func download(url: String, dest: String, sha256: String, _size: int, allow_metered: bool) -> bool:
	if not url.begins_with("https://"):
		_emit_dl.call_deferred(false, dest, "only https downloads are allowed"); return false
	if _downloading: return false
	if net == "none" or (net == "cell" and not allow_metered):
		_emit_dl.call_deferred(false, dest, "waiting_wifi"); return false
	_downloading = true
	_cancel = false
	_finish_dl.call_deferred(dest, sha256)
	return true

func _finish_dl(dest: String, sha256: String) -> void:
	_downloading = false
	if _cancel: dl_done.emit(false, dest, "cancelled"); return
	if dl_error != "": dl_done.emit(false, dest, dl_error); return
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null: dl_done.emit(false, dest, "cannot write"); return
	f.store_string("MOCK-GGUF " + sha256)
	f.close()
	dl_progress.emit(1.0, 1.0)
	dl_done.emit(true, dest, "")

func _emit_dl(ok: bool, p: String, e: String) -> void: dl_done.emit(ok, p, e)
