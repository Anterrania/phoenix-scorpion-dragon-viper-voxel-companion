class_name SwipePages
extends VBoxContainer
## Tabs (§8): pill TabBar with <= 5 tabs + swipeable pages. A horizontal swipe changes page when it
## travels >= 30% of the width or flicks faster than 600 px/s (§7). Reduced motion: no slide, just switch.
signal page_changed(i: int)
const MAX_TABS := 5
var bar: TabBar
var stack: Control
var _pages: Array[Control] = []
var _press := Vector2.ZERO
var _press_t := 0
var _down := false

func _init() -> void:
	add_theme_constant_override("separation", PhoenixTokens.SPACE[4])
	bar = TabBar.new(); bar.tab_alignment = TabBar.ALIGNMENT_CENTER; bar.clip_tabs = false
	bar.custom_minimum_size.y = PhoenixTokens.TAP_MIN
	bar.tab_changed.connect(_show)
	add_child(bar)
	stack = Control.new(); stack.size_flags_vertical = Control.SIZE_EXPAND_FILL; stack.clip_contents = true
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.gui_input.connect(_on_input)
	add_child(stack)

## Returns false (and adds nothing) past MAX_TABS.
func add_page(title: String, page: Control) -> bool:
	if _pages.size() >= MAX_TABS: return false
	bar.add_tab(title)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = _pages.is_empty()
	stack.add_child(page); _pages.append(page)
	return true

func count() -> int: return _pages.size()
func current() -> int: return bar.current_tab
func go(i: int) -> void: if i >= 0 and i < _pages.size(): bar.current_tab = i

func _show(i: int) -> void:
	for k in _pages.size(): _pages[k].visible = k == i; _pages[k].position.x = 0
	page_changed.emit(i)

func _on_input(e: InputEvent) -> void:
	var pressed_ev: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
	if pressed_ev and e.pressed: _press = e.position; _press_t = Time.get_ticks_msec(); _down = true
	elif pressed_ev and _down:
		_down = false
		var dt := maxf(0.016, (Time.get_ticks_msec() - _press_t) / 1000.0)
		release(e.position.x - _press.x, absf(e.position.y - _press.y), dt)
	elif (e is InputEventMouseMotion or e is InputEventScreenDrag) and _down and current() >= 0:
		_pages[current()].position.x = e.position.x - _press.x   # 1:1 follow

## Swipe decision (also used by tests). dx < 0 = next page.
func release(dx: float, dy: float, dt: float) -> int:
	if current() >= 0: _pages[current()].position.x = 0
	var w := maxf(1.0, stack.size.x if stack.size.x > 0 else 720.0)
	if dy > absf(dx): return current()
	if absf(dx) >= 0.3 * w or absf(dx) / dt > 600.0:
		go(current() + (1 if dx < 0 else -1))
	return current()
