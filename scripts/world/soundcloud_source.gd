class_name SoundCloudSource
extends Node
## v0.5.2 SoundCloud as Phoenix Radio's streaming source.
## Tier A (no key, works now): oEmbed (public, keyless) for title/artist shown on the
##   radio, and "Play on SoundCloud" opens the SoundCloud app / web player via an
##   Android intent (OS.shell_open). Music plays in SoundCloud, with its attribution,
##   ads and controls. In-game volume/proximity can't control it.
## Tier B (needs SoundCloud API credentials, Artist Pro): client-credentials token ->
##   /resolve -> track -> /tracks/:id/streams -> progressive MP3 URL -> played in-world
##   by MusicRadio. Many tracks only offer HLS/AAC or are blocked off-platform; those
##   fall back to Tier A. Never ship the client secret in a public APK; a small proxy
##   server should hold it later (see docs).

signal info_ready(info: Dictionary)
signal stream_ready(mp3_url: String)
signal failed(reason: String)
const CONFIG := "res://data/music.json"
const OEMBED := "https://soundcloud.com/oembed?format=json&url=%s"
const API := "https://api.soundcloud.com"
var _http: HTTPRequest

static func config() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return d if d is Dictionary else {}

static func is_soundcloud_url(u: String) -> bool:
	var s := u.strip_edges().to_lower()
	return s.begins_with("https://soundcloud.com/") or s.begins_with("https://on.soundcloud.com/") or s.begins_with("https://m.soundcloud.com/")

## User's own URL (Settings) beats the owner's default; placeholder = none.
static func active_url() -> String:
	var u := str(Settings.get_value("music", "soundcloud_url", "")).strip_edges()
	if is_soundcloud_url(u): return u
	var t := current_track()
	if is_soundcloud_url(str(t.get("url", ""))): return str(t["url"])
	var d := str(config().get("default_soundcloud_url", "")).strip_edges()
	return d if is_soundcloud_url(d) else ""

## v0.10 owner default playlist (cosmic series). Explicit titles are filtered out defensively.
static func is_explicit(title: String) -> bool:
	var tl := title.to_lower()
	for w in config().get("explicit_title_terms", []):
		if tl.contains(str(w)): return true
	return false

static func playlist() -> Array:
	return config().get("default_playlist", []).filter(func(t): return t is Dictionary and not is_explicit(str(t.get("title", ""))) and not is_explicit(str(t.get("url", "")).replace("-", " ")))

static func current_track() -> Dictionary:
	var pl := playlist()
	if pl.is_empty(): return {}
	return pl[posmod(int(Settings.get_value("music", "playlist_index", 0)), pl.size())]

static func step_track(delta: int) -> Dictionary:
	var pl := playlist()
	if pl.is_empty(): return {}
	Settings.set_value("music", "playlist_index", posmod(int(Settings.get_value("music", "playlist_index", 0)) + delta, pl.size()))
	return current_track()

## Title for the UI: user's own link, else the playlist track title.
static func now_title() -> String:
	if is_soundcloud_url(str(Settings.get_value("music", "soundcloud_url", ""))): return "Your SoundCloud link"
	return str(current_track().get("title", ""))

static func has_api_credentials() -> bool:
	return str(Settings.get_value("music", "sc_client_id", "")) != "" and str(Settings.get_value("music", "sc_client_secret", "")) != ""

## Tier A: open the SoundCloud app (if installed) or the web player.
static func open_external(u: String) -> bool:
	if not is_soundcloud_url(u): return false
	return OS.shell_open(u) == OK

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)

func fetch_info(u: String) -> void:
	if not is_soundcloud_url(u):
		failed.emit("no SoundCloud URL set (YOUR INPUT HERE)")
		return
	var r := await _http_get(OEMBED % u.uri_encode())
	if r.is_empty():
		failed.emit("oEmbed lookup failed")
		return
	info_ready.emit({"title": str(r.get("title", "")), "author": str(r.get("author_name", "")), "thumbnail": str(r.get("thumbnail_url", ""))})

## Tier B: resolve to a progressive MP3 stream (requires credentials).
func resolve_stream(u: String) -> void:
	if not has_api_credentials():
		failed.emit("no API credentials - opening SoundCloud app instead")
		return
	var auth := Marshalls.utf8_to_base64("%s:%s" % [Settings.get_value("music", "sc_client_id"), Settings.get_value("music", "sc_client_secret")])
	var tok := await _post("https://secure.soundcloud.com/oauth/token", "grant_type=client_credentials", ["Authorization: Basic " + auth, "Content-Type: application/x-www-form-urlencoded"])
	var at := str(tok.get("access_token", ""))
	if at == "":
		failed.emit("token request failed"); return
	var h := ["Authorization: OAuth " + at, "accept: application/json; charset=utf-8"]
	var res := await _http_get(API + "/resolve?url=" + u.uri_encode(), h)
	var track: Dictionary = res
	if str(res.get("kind", "")) in ["playlist", "user"]:
		var tracks: Array = res.get("tracks", [])
		if tracks.is_empty() and str(res.get("kind")) == "user":
			var lst := await _http_get(API + "/users/%s/tracks?limit=20" % str(res.get("id")), h)
			tracks = lst.get("collection", []) if lst.has("collection") else []
		if tracks.is_empty():
			failed.emit("no streamable tracks"); return
		tracks.shuffle()
		for t in tracks:  # skip missing / blocked / HLS-only tracks
			var mp3 := await _track_mp3(t, h)
			if mp3 != "":
				stream_ready.emit(mp3)
				return
		failed.emit("no tracks streamable in-game - use Play on SoundCloud")
		return
	var one := await _track_mp3(track, h)
	if one == "": failed.emit("track not streamable in-game - opening SoundCloud app instead")
	else: stream_ready.emit(one)

func _track_mp3(track: Dictionary, h: Array) -> String:
	if str(track.get("access", "playable")) == "blocked" or not bool(track.get("streamable", true)): return ""
	var streams := await _http_get(API + "/tracks/%s/streams" % str(track.get("id")), h)
	return pick_mp3(streams)

static func pick_mp3(streams: Dictionary) -> String:
	for k in ["http_mp3_128_url", "preview_mp3_128_url"]:
		if str(streams.get(k, "")) != "": return str(streams[k])
	return ""

func _http_get(url: String, headers: Array = []) -> Dictionary:
	return await _req(url, headers, HTTPClient.METHOD_GET, "")

func _post(url: String, body: String, headers: Array) -> Dictionary:
	return await _req(url, headers, HTTPClient.METHOD_POST, body)

func _req(url: String, headers: Array, method: int, body: String) -> Dictionary:
	if _http == null: return {}
	if _http.request(url, PackedStringArray(headers), method, body) != OK: return {}
	var r: Array = await _http.request_completed
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS or int(r[1]) >= 400: return {}
	var d: Variant = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	return d if d is Dictionary else {}
