class_name MicCapture
extends Node
## Microphone capture for voice chat, the voice changer and mic-driven lip sync.
## AudioStreamMicrophone -> bus "Mic" [VoiceFx chain + AudioEffectCapture]. The Mic bus is silent
## (volume -80 dB) to the speakers unless monitor = true (hear yourself through the morph, use headphones).
## Needs: audio/driver/enable_input=true (project.godot), RECORD_AUDIO declared (export preset) and
## granted at runtime (DeviceCheck.ensure("microphone") is called by start()).
signal level(rms: float)

const BUS := "Mic"
var player: AudioStreamPlayer
var capture: AudioEffectCapture
var lip := LipSync.new()
var monitor := false
var preset := "natural"
var running := false
var last_error := ""

func start() -> bool:
	last_error = ""
	if not DeviceCheck.audio_input_enabled(): last_error = "Audio input is off in project settings."; return false
	if not DeviceCheck.ensure("microphone"): last_error = "Allow the microphone in Settings > Device."; return false
	var i := VoiceFx.ensure_bus(preset, BUS)
	capture = null
	for k in AudioServer.get_bus_effect_count(i):
		if AudioServer.get_bus_effect(i, k) is AudioEffectCapture: capture = AudioServer.get_bus_effect(i, k)
	if capture == null:
		capture = AudioEffectCapture.new(); capture.buffer_length = 0.2
		AudioServer.add_bus_effect(i, capture)
	# volume (not mute): a muted bus can skip its effects, which would starve the capture
	AudioServer.set_bus_volume_db(i, 0.0 if monitor else -80.0)
	if player == null:
		player = AudioStreamPlayer.new(); player.stream = AudioStreamMicrophone.new(); player.bus = BUS
		add_child(player)
	player.play(); running = true
	return true

func set_preset(p: String) -> void:
	preset = p if VoiceFx.PRESETS.has(p) else "natural"
	if running: VoiceFx.ensure_bus(preset, BUS)

func stop() -> void:
	running = false
	if player: player.stop()

func _process(delta: float) -> void:
	if not running or capture == null: return
	var n := capture.get_frames_available()
	if n <= 0: return
	var frames := capture.get_buffer(n)
	var r := LipSync.rms(frames)
	lip.feed_rms(r, delta)
	level.emit(r)
