class_name RingTimeline
extends VBoxContainer
## Timeline (§8): vertical spine of 20 px rings, fire gradient ring for companion events, magenta for
## owner/system (repo commits included). Each row: time + one-line summary; tap expands into a GlassCard.
## One day at a time; swipe left/right (or ‹ ›) for other days.
## events: [{when: ISO, kind, title, author, ref, actor: "companion"|"owner"|"system"}]
signal item_selected(ref: String)
const CARD := preload("res://scenes/ui/kit/glass_card.tscn")
var events: Array = []
var days: Array = []         # "YYYY-MM-DD", newest first
var day_index := 0
var detail_provider: Callable   # (ref) -> BBCode String; optional
var _day_label: Label
var _list: VBoxContainer
var _expanded := ""
var _press := Vector2.ZERO

func _init() -> void:
	add_theme_constant_override("separation", PhoenixTokens.space(3))
	var head := HBoxContainer.new(); head.alignment = BoxContainer.ALIGNMENT_CENTER; head.add_theme_constant_override("separation", 16)
	var p := Button.new(); p.text = "‹"; p.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap()); p.pressed.connect(func(): show_day(day_index + 1))
	_day_label = Label.new(); _day_label.theme_type_variation = &"CaptionLabel"
	var n := Button.new(); n.text = "›"; n.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap()); n.pressed.connect(func(): show_day(day_index - 1))
	head.add_child(p); head.add_child(_day_label); head.add_child(n)
	add_child(head)
	_list = VBoxContainer.new(); _list.add_theme_constant_override("separation", 0); add_child(_list)
	gui_input.connect(_on_input)

func set_events(ev: Array) -> void:
	events = ev
	var seen := {}
	days = []
	for e in ev:
		var d := str(e.get("when", "")).left(10)
		if d != "" and not seen.has(d): seen[d] = true; days.append(d)
	days.sort(); days.reverse()
	show_day(clampi(day_index, 0, maxi(0, days.size() - 1)))

func day_events() -> Array:
	if days.is_empty(): return []
	return events.filter(func(e): return str(e.get("when", "")).left(10) == days[day_index])

func show_day(i: int) -> void:
	if days.is_empty(): _day_label.text = "NO EVENTS"; _clear(); return
	day_index = clampi(i, 0, days.size() - 1)
	_day_label.text = days[day_index]
	_rebuild()

func _clear() -> void:
	for c in _list.get_children(): _list.remove_child(c); c.queue_free()

func _rebuild() -> void:
	_clear()
	for e in day_events():
		var ref := str(e.get("ref", ""))
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
		var dot := _Ring.new(); dot.fire = e.get("actor", "system") == "companion"
		row.add_child(dot)
		var b := Button.new(); b.flat = true; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = PhoenixTokens.tap(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.text = "%s  %s" % [str(e.get("when", "")).substr(11, 5), str(e.get("title", ""))]
		b.pressed.connect(func(): toggle(ref))
		row.add_child(b)
		_list.add_child(row)
		if ref == _expanded:
			var card := CARD.instantiate(); card.title = "%s · %s" % [e.get("kind", ""), e.get("author", "")]
			var rt := RichTextLabel.new(); rt.bbcode_enabled = true; rt.fit_content = true
			rt.text = detail_provider.call(ref) if detail_provider.is_valid() else str(e.get("title", ""))
			card.body().add_child(rt)
			_list.add_child(card)

func toggle(ref: String) -> void:
	_expanded = "" if _expanded == ref else ref
	item_selected.emit(ref)
	_rebuild()

func expanded() -> String: return _expanded

func _on_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		if e.pressed: _press = e.position
		else:
			var dx: float = e.position.x - _press.x
			if absf(dx) > 120: show_day(day_index + (1 if dx > 0 else -1))   # swipe right = older day

class _Ring extends Control:
	var fire := false
	func _init() -> void: custom_minimum_size = Vector2(32, PhoenixTokens.tap()); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Vector2(16, size.y / 2)
		draw_line(Vector2(16, 0), Vector2(16, size.y), Color(PhoenixTokens.PLATINUM, 0.2), 2.0)
		draw_circle(c, 10, PhoenixTokens.VOID)
		if fire:
			for i in 24:
				var t := float(i) / 24
				var col := PhoenixTokens.VENUS.lerp(PhoenixTokens.EMBER, t * 2) if t < 0.5 else PhoenixTokens.EMBER.lerp(PhoenixTokens.PHOENIX, (t - 0.5) * 2)
				draw_arc(c, 8, -PI / 2 + TAU * t, -PI / 2 + TAU * (t + 1.0 / 24), 3, col, 3.0, true)
		else:
			draw_arc(c, 8, 0, TAU, 32, PhoenixTokens.MAGENTA, 3.0, true)
