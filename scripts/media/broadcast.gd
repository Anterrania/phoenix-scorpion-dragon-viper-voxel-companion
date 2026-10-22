class_name Broadcast
extends RefCounted
## Broadcast + parcel media store (server-side STUB, docs/modules/MEDIA_BROADCAST.md §6).
## Local today, shaped like the planned grid MediaService (Aurora-style service) so the same calls
## move to the server later:
##   streams      user://media/streams.json   [{id, title, kind, ingest_url, parcel, owner, status, has_key}]
##   parcel media user://media/parcel_media.json {"region/parcel": {url, kind, by, at}}
##   stream keys  user://media/stream_keys.json  {stream id: key}  - ONLY written when the owner's
##                encrypted saves are open (SecureFile + OwnerVault). Never returned by list calls.
## Gate: every write needs Tiers.can(actor, "broadcast", parcel) (creator+ tier and media rights on
## the parcel: staff+, the land group, or the parcel allow list). Going live also needs the owner
## session: nothing is ever streamed or posted without the owner's approval.
## INACTIVE: no RTMP encoder ships yet (Godot has none built in; needs an Android plugin, Phase 3).
## go_live() only records the approved state.

const KINDS := ["rtmp", "rtmps", "hls", "youtube_live", "icecast"]
const MEDIA_KINDS := ["video", "audio", "web", "youtube"]
const SCHEMES := {"rtmp": ["rtmp://", "rtmps://"], "rtmps": ["rtmps://"], "hls": ["https://"], "youtube_live": ["rtmps://", "rtmp://"],
	"icecast": ["https://", "http://"], "video": ["https://"], "audio": ["https://", "http://"], "web": ["https://"], "youtube": ["https://"]}

static var root := "user://media"
static var _streams = null
static var _media = null

static func reset_for_tests(r: String) -> void:
	root = r; _streams = null; _media = null

static func _p(n: String) -> String: return root.path_join(n)

static func streams() -> Array:
	if _streams == null:
		var d: Variant = SecureFile.read_json(_p("streams.json"), [])
		_streams = d if d is Array else []
	return _streams

static func parcel_media() -> Dictionary:
	if _media == null:
		var d: Variant = SecureFile.read_json(_p("parcel_media.json"), {})
		_media = d if d is Dictionary else {}
	return _media

static func _parcel_key(parcel: Variant) -> String:
	if parcel is Dictionary: return "%s/%s" % [parcel.get("region", ""), parcel.get("parcel", "")]
	return str(parcel)

static func url_ok(kind: String, url: String) -> bool:
	if url.length() > 2048 or url.contains(" ") or url.contains("\n"): return false
	for s in SCHEMES.get(kind, []):
		if url.to_lower().begins_with(s) and url.length() > s.length() + 3: return true
	return false

static func _err(e: String) -> Dictionary: return {"ok": false, "error": e}

## Add a stream entry. Returns {"ok", "id"} or {"ok": false, "error"}.
static func add_stream(actor: Variant, title: String, kind: String, ingest_url: String, parcel: Variant) -> Dictionary:
	if not Tiers.can(actor, "broadcast", parcel): return _err("No broadcast rights on this parcel.")
	if not kind in KINDS: return _err("Unknown stream type.")
	if not url_ok(kind, ingest_url): return _err("That address doesn't look right for %s." % kind)
	var t := title.strip_edges().left(80)
	if t == "": return _err("Give the stream a title.")
	var id := "st%d_%d" % [Time.get_unix_time_from_system(), streams().size() + 1]
	streams().append({"id": id, "title": t, "kind": kind, "ingest_url": ingest_url, "parcel": _parcel_key(parcel),
		"owner": Tiers.actor_id(actor), "status": "draft", "has_key": false, "created": int(Time.get_unix_time_from_system())})
	if not SecureFile.write_json(_p("streams.json"), streams(), "\t"):
		streams().pop_back(); return _err("Saves are sealed. Unlock first.")
	return {"ok": true, "id": id}

static func find(id: String) -> Dictionary:
	for s in streams():
		if s["id"] == id: return s
	return {}

## List for UI/API: never includes keys.
static func list(parcel: Variant = null) -> Array:
	var pk := _parcel_key(parcel) if parcel != null else ""
	return streams().filter(func(s): return pk == "" or s["parcel"] == pk).map(func(s): return s.duplicate())

## Store a stream key ENCRYPTED. Refused unless the owner's encrypted saves are open.
static func set_stream_key(actor: Variant, id: String, key: String) -> Dictionary:
	var s := find(id)
	if s.is_empty(): return _err("No such stream.")
	if not Tiers.can(actor, "broadcast", s["parcel"]): return _err("No broadcast rights on this parcel.")
	if not (SecureFile.encrypted_mode() and OwnerVault.storage_ready()):
		return _err("Stream keys are only saved encrypted. Unlock in Security first.")
	var k := key.strip_edges()
	if k.length() < 8 or k.length() > 256: return _err("That key looks wrong.")
	var keys: Variant = SecureFile.read_json(_p("stream_keys.json"), {})
	if not keys is Dictionary: keys = {}
	keys[id] = k
	if not SecureFile.write_json(_p("stream_keys.json"), keys): return _err("Saves are sealed. Unlock first.")
	s["has_key"] = true
	SecureFile.write_json(_p("streams.json"), streams(), "\t")
	return {"ok": true, "hint": "••••" + k.right(4)}

## Encoder-only read of a key (owner session required). "" when locked or missing.
static func stream_key_for_encoder(id: String) -> String:
	if not Tiers.owner_session() or not OwnerVault.storage_ready(): return ""
	var keys: Variant = SecureFile.read_json(_p("stream_keys.json"), {})
	return str(keys.get(id, "")) if keys is Dictionary else ""

## Owner approval gate: the stream is marked approved/live only with the owner session.
static func go_live(actor: Variant, id: String) -> Dictionary:
	var s := find(id)
	if s.is_empty(): return _err("No such stream.")
	if not Tiers.can(actor, "broadcast", s["parcel"]): return _err("No broadcast rights on this parcel.")
	if not Tiers.owner_session():
		s["status"] = "awaiting_owner"
		SecureFile.write_json(_p("streams.json"), streams(), "\t")
		return {"ok": false, "error": "Waiting for the owner's approval.", "status": "awaiting_owner"}
	if not s["has_key"] and s["kind"] in ["rtmp", "rtmps", "youtube_live"]: return _err("Add the stream key first.")
	s["status"] = "approved"   # INACTIVE: no encoder yet; Phase 3 starts the RTMP push here
	SecureFile.write_json(_p("streams.json"), streams(), "\t")
	return {"ok": true, "status": "approved"}

static func end_stream(actor: Variant, id: String) -> bool:
	var s := find(id)
	if s.is_empty() or not Tiers.can(actor, "broadcast", s["parcel"]): return false
	s["status"] = "ended"
	return SecureFile.write_json(_p("streams.json"), streams(), "\t")

## Parcel media URL (SL "parcel media": the screen/radio a parcel plays for visitors).
static func set_parcel_media(actor: Variant, parcel: Variant, url: String, kind := "video") -> Dictionary:
	if not Tiers.can(actor, "broadcast", parcel): return _err("No media rights on this parcel.")
	if not kind in MEDIA_KINDS: return _err("Unknown media type.")
	var pk := _parcel_key(parcel)
	if url == "":
		parcel_media().erase(pk)
	else:
		if not url_ok(kind, url): return _err("Use a secure https:// address.")
		parcel_media()[pk] = {"url": url, "kind": kind, "by": Tiers.actor_id(actor), "at": int(Time.get_unix_time_from_system())}
	if not SecureFile.write_json(_p("parcel_media.json"), parcel_media(), "\t"): return _err("Saves are sealed. Unlock first.")
	return {"ok": true}

static func media_for(parcel: Variant) -> Dictionary: return parcel_media().get(_parcel_key(parcel), {})
