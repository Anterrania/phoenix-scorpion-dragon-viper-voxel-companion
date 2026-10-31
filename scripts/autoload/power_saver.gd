extends Node
## v0.12 battery: on Android cap the frame rate at 30, and when the app is paused or loses focus
## pause the scene tree and drop to 5 fps; restore on resume. When AutoConfig's PowerData says "saver"
## (battery low, phone hot, OS power saver or mobile data) the cap drops to 20 fps (t118u).
## Desktop/headless runs are untouched.

const ACTIVE_FPS := 30
const BACKGROUND_FPS := 5
const SAVER_FPS := 20
var backgrounded := false
var saver := false
var _was_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _android(): _apply_fps()
	if _android(): _hook_power.call_deferred()   # AutoConfig loads after this autoload

func _hook_power() -> void:
	var ac := get_node_or_null("/root/AutoConfig")
	if ac and ac.has_signal("power_changed"):
		ac.power_changed.connect(func(mode: String, _r): set_saver(mode == "saver"))
		set_saver(str(ac.last_plan.get("power_mode", "")) == "saver")

## Pure: the frame cap for a state (tested).
static func target_fps(bg: bool, low_power: bool) -> int:
	if bg: return BACKGROUND_FPS
	return SAVER_FPS if low_power else ACTIVE_FPS

func set_saver(on: bool) -> void:
	saver = on
	_apply_fps()

func _apply_fps() -> void:
	Engine.max_fps = target_fps(backgrounded, saver)

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
	else:
		get_tree().paused = _was_paused
	_apply_fps()
