class_name GlassCarousel
extends VBoxContainer
## Glass carousel (calm premium, docs/UI_DESIGN_LANGUAGE.md §12). One card per swipe, snapping, page dots.
## - Swipe: the strip follows the finger 1:1; on release it moves at most ONE card, when the drag
##   travels >= 30% of the width or flicks faster than 600 px/s (same thresholds as SwipePages).
## - Auto-advance: OFF unless the list opts in (`auto_advance = true`, for ads and event lists only;
##   never for content someone is reading). Any touch pauses it; it resumes one interval after release.
## - Motion: PhoenixTokens.MOTION.base (0.24 s), TRANS_CUBIC ease-out. No bounce, no spin, no glow.
## - Sizes, colors and timings come from PhoenixTokens. The carousel accepts its own drags, so a
##   swipe on it never changes the parent SwipePages tab.
signal page_changed(i: int)

const SWIPE_FRACTION := 0.3          # same rule as SwipePages (§7)
const FLICK_PX_S := 600.0
@export var auto_advance := false
## Auto-advance interval: 2 x the ambient token (2.4 s) = 4.8 s.
@export var interval_s := PhoenixTokens.MOTION.ambient * 2.0
@export var wrap_auto := true        # auto-advance loops back to the first card; swipes never wrap

var track: Control
var strip: Control
var dots: Control
var index := 0
var paused := false                  # true while a finger is down
var _cards: Array[Control] = []
var _press := Vector2.ZERO
var _press_t := 0
var _down := false
var _auto_acc := 0.0
var _resume_acc := 0.0
var _tween: Tween

func _init() -> void:
	add_theme_constant_override("separation", PhoenixTokens.space(3))
	track = Control.new(); track.name = "Track"; track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_STOP
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.gui_input.connect(_on_input)
	track.resized.connect(_layout)
	add_child(track)
	strip = Control.new(); strip.name = "Strip"; strip.mouse_filter = Control.MOUSE_FILTER_PASS
	track.add_child(strip)
	dots = _Dots.new(); dots.name = "Dots"; dots.carousel = self
	dots.custom_minimum_size = Vector2(0, PhoenixTokens.space(5))
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dots)

func count() -> int: return _cards.size()
func current() -> Control: return _cards[index] if index < _cards.size() else null

func add_card(c: Control) -> void:
	_pass_through(c)
	strip.add_child(c); _cards.append(c)
	c.minimum_size_changed.connect(_layout)
	_layout()

## Let drags that start on a card's content (rings, labels, panels) reach the track. Buttons keep taps.
static func _pass_through(n: Node) -> void:
	if n is Control and not (n is BaseButton) and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for ch in n.get_children(): _pass_through(ch)

func set_cards(cards: Array) -> void:
	for c in _cards: strip.remove_child(c); c.queue_free()
	_cards.clear(); index = 0
	for c in cards: add_card(c)
	_snap(false)

func _width() -> float: return track.size.x if track.size.x > 0 else maxf(1.0, size.x)

func _layout() -> void:
	var w := _width()
	var h := 0.0
	for c in _cards: h = maxf(h, c.get_combined_minimum_size().y)
	track.custom_minimum_size.y = h
	for k in _cards.size():
		_cards[k].position = Vector2(k * w, 0); _cards[k].size = Vector2(w, maxf(h, track.size.y))
	if not _down and (_tween == null or not _tween.is_running()): strip.position.x = -index * w
	dots.queue_redraw()

## Go to card i (clamped). animate=false jumps. Returns the new index.
func go(i: int, animate := true) -> int:
	var n := clampi(i, 0, maxi(0, _cards.size() - 1))
	var changed := n != index
	index = n
	_snap(animate)
	if changed: page_changed.emit(index)
	return index

func next() -> int: return go(index + 1)
func prev() -> int: return go(index - 1)

func _snap(animate: bool) -> void:
	var x := -index * _width()
	if _tween: _tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(strip, "position:x", x, PhoenixTokens.MOTION.base).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else: strip.position.x = x
	dots.queue_redraw()

## Swipe decision (also used by tests). dx < 0 = next card. Moves at most one card.
func release(dx: float, dy: float, dt: float) -> int:
	var w := _width()
	if dy > absf(dx): return go(index)
	if absf(dx) >= SWIPE_FRACTION * w or absf(dx) / maxf(dt, 0.016) > FLICK_PX_S:
		return go(index + (1 if dx < 0 else -1))
	return go(index)

## Touch / pointer: pause while down, follow 1:1, decide on release.
func touch(pressed: bool, p := Vector2.ZERO) -> void:
	if pressed:
		_down = true; paused = true; _press = p; _press_t = Time.get_ticks_msec()
		if _tween: _tween.kill()
	elif _down:
		_down = false; paused = false; _resume_acc = 0.0; _auto_acc = 0.0
		var dt := maxf(0.016, (Time.get_ticks_msec() - _press_t) / 1000.0)
		release(p.x - _press.x, absf(p.y - _press.y), dt)

func _on_input(e: InputEvent) -> void:
	var press_ev: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
	if press_ev:
		touch(e.pressed, e.position); track.accept_event()
	elif (e is InputEventMouseMotion or e is InputEventScreenDrag) and _down:
		strip.position.x = -index * _width() + (e.position.x - _press.x)
		track.accept_event()

## Pause timer: after a touch the carousel waits one full interval before auto-advancing again.
func is_auto_running() -> bool: return auto_advance and not paused and _cards.size() > 1 and _resume_acc >= interval_s

func _process(d: float) -> void:
	if not auto_advance or _cards.size() < 2: return
	if paused: return
	if _resume_acc < interval_s: _resume_acc += d; _auto_acc = 0.0; return
	_auto_acc += d
	if _auto_acc >= interval_s:
		_auto_acc = 0.0
		if index + 1 < _cards.size(): go(index + 1)
		elif wrap_auto: go(0)

func _ready() -> void:
	_resume_acc = interval_s   # first auto-advance one interval after showing
	_layout()

## Page dots: active dot gold, others platinum-dim. Decorative only (swipe is the control).
class _Dots extends Control:
	var carousel: GlassCarousel
	func _draw() -> void:
		if carousel == null or carousel.count() < 2: return
		var r := PhoenixTokens.space(1) * 1.5
		var gap := PhoenixTokens.space(3)
		var n := carousel.count()
		var w := n * r * 2.0 + (n - 1) * gap
		var x0 := (size.x - w) / 2.0 + r
		for k in n:
			var on := k == carousel.index
			draw_circle(Vector2(x0 + k * (r * 2.0 + gap), size.y / 2.0), r * (1.0 if on else 0.8),
				PhoenixTokens.GOLD if on else Color(PhoenixTokens.PLATINUM_DIM, 0.45))
