class_name Net
extends RefCounted
## Net: data saver + message packing + HTTP cache for every network helper we own.
## Docs: docs/modules/POWER_AND_DATA.md §4. Self-written, engine APIs only (no dependencies).
##  - set_data_mode("full" | "normal" | "saver"): AutoConfig sets it from the PowerData policy.
##    Readers: media_kbps(), thumbnails_only(), autoplay_ok(), large_download_ok(bytes), prefetch_ok().
##  - pack()/unpack(): batch messages into one deflate-compressed frame (PackedByteArray.compress).
##  - delta()/apply_delta(): send only the state keys that changed.
##  - HTTP cache: ETag / Last-Modified revalidation (request_headers() + on_response()), GET only.
##  - Session counter: count(bytes_in, bytes_out) feeds Settings > Device & compatibility > Battery & data.
## Nothing here sends anything by itself. Cache files stay on the device (user://cache/http).

const MODES := ["full", "normal", "saver"]
## Media bitrate (kbps) per mode: audio, video/clips.
const MEDIA_KBPS := {"full": {"audio": 256, "video": 4000}, "normal": {"audio": 128, "video": 1500}, "saver": {"audio": 64, "video": 400}}
## Image size caps (longest side, px) per mode.
const IMAGE_PX := {"full": {"image": 2048, "thumb": 512}, "normal": {"image": 1280, "thumb": 320}, "saver": {"image": 640, "thumb": 160}}
## In saver mode, downloads above this wait for Wi-Fi.
const LARGE_DOWNLOAD_BYTES := 5 * 1024 * 1024
const FRAME_MAGIC := 0x56  # 'V'
const COMPRESS_MIN := 128  # smaller frames are not worth compressing

static var mode := "normal"
static var bytes_in := 0
static var bytes_out := 0
static var saved_bytes := 0        # bytes avoided (304 hits + compression)
static var cache_root := "user://cache/http"
static var _index: Dictionary = {}  # url -> {etag, last_modified, file, size}
static var _loaded := false

static func set_data_mode(m: String) -> void:
	mode = m if m in MODES else "normal"

static func media_kbps(kind := "audio") -> int: return int(MEDIA_KBPS[mode].get(kind, 128))
static func image_px(kind := "image") -> int: return int(IMAGE_PX[mode].get(kind, 1280))
static func thumbnails_only() -> bool: return mode == "saver"
static func autoplay_ok() -> bool: return mode != "saver"
static func prefetch_ok() -> bool: return mode == "full"
static func large_download_ok(size_bytes: int) -> bool: return mode != "saver" or size_bytes < LARGE_DOWNLOAD_BYTES

# ---------- session counter ----------
static func count(i: int, o := 0) -> void:
	bytes_in += maxi(i, 0); bytes_out += maxi(o, 0)

static func session_mb() -> float: return snappedf(float(bytes_in + bytes_out) / 1048576.0, 0.01)

static func reset_session() -> void:
	bytes_in = 0; bytes_out = 0; saved_bytes = 0

# ---------- batching + compression ----------
## Frame: [magic, flag(0 raw / 1 deflate), u32 raw size, payload]. Payload = JSON array of messages.
static func pack(messages: Array) -> PackedByteArray:
	var raw := JSON.stringify(messages).to_utf8_buffer()
	var out := PackedByteArray([FRAME_MAGIC, 0, 0, 0, 0, 0])
	out.encode_u32(2, raw.size())
	var body := raw
	if raw.size() >= COMPRESS_MIN:
		var z := raw.compress(FileAccess.COMPRESSION_DEFLATE)
		if z.size() < raw.size():
			body = z; out[1] = 1
			saved_bytes += raw.size() - z.size()
	out.append_array(body)
	return out

static func unpack(frame: PackedByteArray) -> Array:
	if frame.size() < 6 or frame[0] != FRAME_MAGIC: return []
	var n := frame.decode_u32(2)
	if n > 16 * 1024 * 1024: return []   # refuse absurd frames
	var body := frame.slice(6)
	var raw := body.decompress(n, FileAccess.COMPRESSION_DEFLATE) if frame[1] == 1 else body
	var d: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return d if d is Array else []

# ---------- state delta ----------
## {"set": {changed or new keys}, "del": [removed keys]}. Values compare with ==; nested dicts are sent whole.
static func delta(prev: Dictionary, cur: Dictionary) -> Dictionary:
	var s := {}
	var del: Array = []
	for k in cur:
		if not prev.has(k) or prev[k] != cur[k]: s[k] = cur[k]
	for k in prev:
		if not cur.has(k): del.append(k)
	return {"set": s, "del": del}

static func is_empty_delta(d: Dictionary) -> bool:
	return (d.get("set", {}) as Dictionary).is_empty() and (d.get("del", []) as Array).is_empty()

static func apply_delta(base: Dictionary, d: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in d.get("set", {}): out[k] = d["set"][k]
	for k in d.get("del", []): out.erase(k)
	return out

# ---------- HTTP cache (ETag / Last-Modified) ----------
static func _index_path() -> String: return cache_root.path_join("index.json")

static func _load() -> void:
	if _loaded: return
	_loaded = true
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(_index_path())) if FileAccess.file_exists(_index_path()) else null
	_index = d if d is Dictionary else {}

static func _save() -> void:
	DirAccess.make_dir_recursive_absolute(cache_root)
	var f := FileAccess.open(_index_path(), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_index))

static func reset_cache_for_tests(root: String) -> void:
	cache_root = root; _index = {}; _loaded = false

## Extra request headers for a GET of url: If-None-Match / If-Modified-Since when we hold a copy.
static func request_headers(url: String, headers: Array = []) -> PackedStringArray:
	_load()
	var out := PackedStringArray(headers)
	var e: Dictionary = _index.get(url, {})
	if e.is_empty() or not FileAccess.file_exists(cache_root.path_join(str(e.get("file", "")))): return out
	if str(e.get("etag", "")) != "": out.append("If-None-Match: " + str(e["etag"]))
	if str(e.get("last_modified", "")) != "": out.append("If-Modified-Since: " + str(e["last_modified"]))
	return out

static func _header(headers: PackedStringArray, name: String) -> String:
	var n := name.to_lower() + ":"
	for h in headers:
		if h.to_lower().begins_with(n): return h.substr(n.length()).strip_edges()
	return ""

## Call with the HTTPRequest result. Returns the body to use: the cached copy on 304, else the new body
## (stored when the server sent a validator). Also counts session bytes.
static func on_response(url: String, code: int, headers: PackedStringArray, body: PackedByteArray) -> PackedByteArray:
	_load()
	count(body.size())
	var e: Dictionary = _index.get(url, {})
	var path := cache_root.path_join(str(e.get("file", "")))
	if code == 304 and not e.is_empty() and FileAccess.file_exists(path):
		saved_bytes += int(e.get("size", 0))
		return FileAccess.get_file_as_bytes(path)
	if code >= 200 and code < 300 and body.size() > 0:
		var etag := _header(headers, "ETag")
		var lm := _header(headers, "Last-Modified")
		var nostore := _header(headers, "Cache-Control").to_lower().contains("no-store")
		if (etag != "" or lm != "") and not nostore and body.size() <= 8 * 1024 * 1024:
			DirAccess.make_dir_recursive_absolute(cache_root)
			var fn := url.sha256_text().substr(0, 24) + ".bin"
			var f := FileAccess.open(cache_root.path_join(fn), FileAccess.WRITE)
			if f:
				f.store_buffer(body); f.close()
				_index[url] = {"etag": etag, "last_modified": lm, "file": fn, "size": body.size()}
				_save()
	return body
