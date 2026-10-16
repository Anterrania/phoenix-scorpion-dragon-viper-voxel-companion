class_name KineticScroll
extends ScrollContainer
## v0.7 phone-friendly scrolling: drag anywhere (even on buttons) to scroll, with
## momentum. A drag past the threshold cancels the button tap under the finger.

const THRESHOLD := 18.0
const FRICTION := 4.5
var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _vel := 0.0
var _cancel_sent := false

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var bar := get_v_scroll_bar()
	bar.custom_minimum_size.x = 26
	var grab := StyleBoxFlat.new(); grab.bg_color = Color(1, 0.18, 0.82, 0.85); grab.set_corner_radius_all(12)
	var track := StyleBoxFlat.new(); track.bg_color = Color(1, 1, 1, 0.08); track.set_corner_radius_all(12)
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]: bar.add_theme_stylebox_override(k, grab)
	bar.add_theme_stylebox_override("scroll", track)

func _active() -> bool:
	return is_visible_in_tree()

func _input(e: InputEvent) -> void:
	if not _active(): return
	var pos := Vector2.ZERO
	var pressed := false
	var is_press := false
	var is_motion := false
	if e is InputEventScreenTouch and e.index == 0:
		pos = e.position; is_press = true; pressed = e.pressed
	elif e is InputEventScreenDrag and e.index == 0:
		pos = e.position; is_motion = true
	else:  # mouse is emulated as touch (project setting), so touch covers desktop too
		return
	if pos.x < -500: return  # our own synthetic cancel
	if is_press:
		if pressed:
			if get_global_rect().has_point(pos):
				_down = true; _dragging = false; _start = pos; _last = pos; _vel = 0.0; _cancel_sent = false
		else:
			if _dragging:
				get_viewport().set_input_as_handled()  # swallow the tap at the end of a drag
			_down = false
			_dragging = false
	elif is_motion and _down:
		if not _dragging and pos.distance_to(_start) > THRESHOLD:
			_dragging = true
			_cancel_button_press()
		if _dragging:
			var dy := pos.y - _last.y
			scroll_vertical -= int(dy)
			_vel = -dy / maxf(get_process_delta_time(), 0.001)
			get_viewport().set_input_as_handled()
		_last = pos

## Release any half-pressed button by sending a release far off-screen.
func _cancel_button_press() -> void:
	if _cancel_sent: return
	_cancel_sent = true
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	r.position = Vector2(-1000, -1000)
	r.global_position = r.position
	Input.parse_input_event(r)

func _process(delta: float) -> void:
	if not _down and absf(_vel) > 5.0:
		scroll_vertical += int(_vel * delta)
		_vel = lerpf(_vel, 0.0, clampf(FRICTION * delta, 0.0, 1.0))
	elif not _down:
		_vel = 0.0

## Test helper: simulate a drag of dy pixels starting at p.
func simulate_drag(p: Vector2, dy: float) -> void:
	_down = true; _dragging = true; _start = p; _last = p
	scroll_vertical -= int(dy)
	_vel = -dy * 30.0
	_down = false
