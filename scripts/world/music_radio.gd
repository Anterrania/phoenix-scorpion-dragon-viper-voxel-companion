class_name MusicRadio
extends Node3D
## v0.5 in-world radio (Second Life "parcel music" concept): plays a station/track
## URL to everyone standing inside its radius, fading with distance.
## Now: downloads an HTTP MP3/OGG track (up to MAX_BYTES) and loops it.
## Later: true endless Icecast/HTTP streaming via chunked decode (see roadmap).

const MAX_BYTES := 12 * 1024 * 1024
@export var radius := 45.0
var player: Node3D
var audio: AudioStreamPlayer
var http: HTTPRequest
var status := "idle"
var label: Label3D
var url := ""

func setup(p: Node3D) -> void:
	player = p
	name = "PhoenixRadio"
	var K = PropKit
	K.part(self, K.cone(0.5, 0.7, 2.2, 16), K.mat("#0b0910", 0.0, 0.7, 0.2), Vector3(0, 1.1, 0))
	K.part(self, K.torus(0.35, 0.55), K.mat("#ff2fd0", 3.0), Vector3(0, 1.6, 0.6), Vector3.ONE, Vector3(PI / 2, 0, 0))
	K.part(self, K.sphere(0.25, 10), K.mat("#f2bd3a", 1.0, 1.0, 0.2), Vector3(0, 2.5, 0))
	K.collider(self, K.cyl_shape(0.6, 2.2), Vector3(0, 1.1, 0))
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position.y = 3.4
	label.font_size = 48; label.pixel_size = 0.007; label.outline_size = 12
	label.modulate = Color("#ffd04a")
	add_child(label)
	audio = AudioStreamPlayer.new()
	audio.volume_db = -80.0
	add_child(audio)
	http = HTTPRequest.new()
	http.body_size_limit = MAX_BYTES
	http.timeout = 60.0
	add_child(http)
	http.request_completed.connect(_on_done)
	_update_label()
	if bool(Settings.get_value("music", "enabled", true)): tune(station_url())

static func station_url() -> String:
	var u := str(Settings.get_value("music", "user_url", "")).strip_edges()
	return u if u != "" else str(Settings.get_value("music", "url", ""))

func tune(u: String) -> void:
	url = u
	if u == "": return
	http.cancel_request()
	status = "loading"
	_update_label()
	if http.request(u) != OK: status = "error"; _update_label()

func _update_label() -> void:
	if label:
		label.text = "♪ Phoenix Radio (%s)\n★ YOUR INPUT HERE: your station URL (Settings)" % status

static func stream_from_bytes(bytes: PackedByteArray, u: String) -> AudioStream:
	if u.to_lower().contains(".ogg"):
		return AudioStreamOggVorbis.load_from_buffer(bytes)
	var s := AudioStreamMP3.new()
	s.data = bytes
	s.loop = true
	return s

func _on_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400 or body.is_empty():
		status = "offline"
		_update_label()
		return
	audio.stream = stream_from_bytes(body, url)
	audio.play()
	status = "playing"
	_update_label()

func _process(_d: float) -> void:
	if player == null or audio == null or not audio.playing: return
	var d := global_position.distance_to(player.global_position)
	var base := float(Settings.get_value("music", "volume_db", -12.0))
	audio.volume_db = -80.0 if d > radius else lerpf(base, base - 18.0, d / radius)
