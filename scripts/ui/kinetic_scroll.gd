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
# v0.15 SCROLL-1: sub-pixel accumulator + time-based velocity (the old per-frame delta made flings jumpy).
var _pos_f := 0.0
var _last_t := 0
const MAX_VEL := 6000.0

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO   # v0.15: bar only when the list overflows
	var bar := get_v_scroll_bar()
	# bar.custom_minimum_size.x = 26
	bar.custom_minimum_size.x = 14   # v0.15: slimmer; the body keeps a right gutter so it never covers buttons
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
				_pos_f = float(scroll_vertical); _last_t = Time.get_ticks_usec()
		else:
			if _dragging:
				get_viewport().set_input_as_handled()  # swallow the tap at the end of a drag
				if Time.get_ticks_usec() - _last_t > 80000: _vel = 0.0   # finger paused before lifting: no fling
			_down = false
			_dragging = false
	elif is_motion and _down:
		if not _dragging and pos.distance_to(_start) > THRESHOLD:
			_dragging = true
			_cancel_button_press()
		if _dragging:
			var dy := pos.y - _last.y
			# scroll_vertical -= int(dy)
			# _vel = -dy / maxf(get_process_delta_time(), 0.001)
			_pos_f = clampf(_pos_f - dy, 0.0, _max_scroll())
			scroll_vertical = int(round(_pos_f))
			var now := Time.get_ticks_usec()
			var dt := maxf(float(now - _last_t) / 1000000.0, 0.004)
			_last_t = now
			_vel = clampf(lerpf(_vel, -dy / dt, 0.6), -MAX_VEL, MAX_VEL)
			get_viewport().set_input_as_handled()
		_last = pos

## Release any half-pressed button by sending a release far off-screen.
func _cancel_button_press() -> void:
	if _cancel_sent: return
	_cancel_sent = true
	# v0.15.1 SCROLL-FIX: the release alone FIRED the button under the finger. Godot's BaseButton decides on
	# release from "pressing_inside", which only changes on mouse motion, so a release at (-1000,-1000) with
	# no motion before it counted as a tap: the first drag on the menu ran that menu row (closing the menu)
	# instead of scrolling. Move the pointer off the button first, then release. Far off in window pixels, so
	# it stays off-screen at any stretch scale.
	var far := Vector2(-100000, -100000)
	var m := InputEventMouseMotion.new()
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	m.position = far
	m.global_position = far
	Input.parse_input_event(m)
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	# r.position = Vector2(-1000, -1000)
	r.position = far
	r.global_position = r.position
	Input.parse_input_event(r)

func _process(delta: float) -> void:
	if not _down and absf(_vel) > 5.0:
		# scroll_vertical += int(_vel * delta)
		if absf(_pos_f - scroll_vertical) > 2.0: _pos_f = float(scroll_vertical)
		_pos_f = clampf(_pos_f + _vel * delta, 0.0, _max_scroll())
		scroll_vertical = int(round(_pos_f))
		if _pos_f <= 0.0 or _pos_f >= _max_scroll(): _vel = 0.0
		_vel = lerpf(_vel, 0.0, clampf(FRICTION * delta, 0.0, 1.0))
	elif not _down:
		_vel = 0.0

func _max_scroll() -> float:
	var bar := get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)

## Test helper: simulate a drag of dy pixels starting at p.
func simulate_drag(p: Vector2, dy: float) -> void:
	_down = true; _dragging = true; _start = p; _last = p
	scroll_vertical -= int(dy)
	_vel = -dy * 30.0
	_down = false
