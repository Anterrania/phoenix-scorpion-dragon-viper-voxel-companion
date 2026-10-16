class_name AppControl
extends RefCounted
## v0.9 Exit + Background (minimize) for phones. Exit = get_tree().quit().
## Background = OS.move_to_background() when the engine has it; otherwise Android's
## Activity.moveTaskToBack(true) through the AndroidRuntime singleton (Godot 4.4+);
## otherwise minimize the window (desktop) and pause/mute as a last resort.

static func exit_app(tree: SceneTree) -> void:
	tree.quit()

## Returns which path was used: "os", "android", "window", or "paused".
static func to_background(tree: SceneTree) -> String:
	if OS.has_method("move_to_background"):
		OS.call("move_to_background")
		return "os"
	if Engine.has_singleton("AndroidRuntime"):
		var rt = Engine.get_singleton("AndroidRuntime")
		var act = rt.getActivity() if rt else null
		if act:
			act.moveTaskToBack(true)
			return "android"
	if OS.get_name() not in ["Android", "iOS"] and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		return "window"
	tree.paused = true
	AudioServer.set_bus_mute(0, true)
	return "paused"

static func resume(tree: SceneTree) -> void:
	tree.paused = false
	AudioServer.set_bus_mute(0, false)

static func is_portrait(vp: Viewport) -> bool:
	var s := vp.get_visible_rect().size
	return s.y >= s.x
