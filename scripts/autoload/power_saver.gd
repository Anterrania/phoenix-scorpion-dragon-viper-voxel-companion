extends Node
## v0.12 battery: on Android cap the frame rate at 30, and when the app is paused or loses focus
## pause the scene tree and drop to 5 fps; restore on resume. Desktop/headless runs are untouched.

const ACTIVE_FPS := 30
const BACKGROUND_FPS := 5
var backgrounded := false
var _was_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _android(): Engine.max_fps = ACTIVE_FPS

func _android() -> bool:
	return OS.has_feature("android")

func _notification(what: int) -> void:
	if not _android(): return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT: set_background(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN: set_background(false)

func set_background(on: bool) -> void:
	if on == backgrounded: return
	backgrounded = on
	if on:
		_was_paused = get_tree().paused
		get_tree().paused = true
		Engine.max_fps = BACKGROUND_FPS
	else:
		get_tree().paused = _was_paused
		Engine.max_fps = ACTIVE_FPS
