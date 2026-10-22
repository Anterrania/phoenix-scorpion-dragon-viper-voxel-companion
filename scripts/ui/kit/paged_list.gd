class_name PagedList
extends VBoxContainer
## At most 7 visible rows, then pages (§1.5 / §8 Admin table). builder: Callable(item) -> Control.
const PAGE_SIZE := 7
var items: Array = []
var page := 0
var builder: Callable
var _rows: VBoxContainer
var _label: Label

func _init() -> void:
	add_theme_constant_override("separation", PhoenixTokens.space(3))
	_rows = VBoxContainer.new(); _rows.add_theme_constant_override("separation", PhoenixTokens.space(2)); add_child(_rows)
	var nav := HBoxContainer.new(); nav.alignment = BoxContainer.ALIGNMENT_CENTER; nav.add_theme_constant_override("separation", 16)
	var prev := Button.new(); prev.text = "‹"; prev.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap())
	prev.pressed.connect(func(): go(page - 1)); nav.add_child(prev)
	_label = Label.new(); _label.add_theme_color_override("font_color", PhoenixTokens.PLATINUM_DIM); nav.add_child(_label)
	var nxt := Button.new(); nxt.text = "›"; nxt.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap())
	nxt.pressed.connect(func(): go(page + 1)); nav.add_child(nxt)
	add_child(nav)

func pages() -> int: return maxi(1, ceili(items.size() / float(PAGE_SIZE)))

func set_items(p_items: Array, p_builder: Callable, keep_page := false) -> void:
	items = p_items; builder = p_builder
	go(page if keep_page else 0)

func go(p: int) -> void:
	page = clampi(p, 0, pages() - 1)
	for c in _rows.get_children(): _rows.remove_child(c); c.queue_free()
	for it in items.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE): _rows.add_child(builder.call(it))
	_label.text = "%d / %d" % [page + 1, pages()]

func row_count() -> int: return _rows.get_child_count()
func row(i: int) -> Control: return _rows.get_child(i)
