class_name ViperRadial
extends RadialMenu
## HUD radial launcher on Foxy's RadialMenu (UI_DESIGN_LANGUAGE §8). Six evenly spaced items,
## clockwise from 12 o'clock: Admin (12, opens the dashboard), Security (2, shield, opens lock +
## audit), Chat (4), Map (6), Proposals (8), Menu (10). Collapsed it is only the hub, so it doesn't
## block the world.
const ITEMS := ["Admin", "Security", "Chat", "Map", "Proposals", "Menu"]
const GLYPHS := ["◎", "", "✦", "◉", "✔", "☰"]   # Security draws a shield (emoji fonts vary on Android)
const OPEN_PX := 360.0
const CLOSED_PX := 120.0
var _anchor_center := Vector2.ZERO

func _init() -> void:
	items.assign(ITEMS); glyphs.assign(GLYPHS)
	open = false

func _ready() -> void:
	super._ready()
	_resize()

## o'clock position of an item (12 = top), from the same spacing RadialMenu uses.
static func clock_of(id: String) -> int:
	var i := ITEMS.find(id)
	var h := int(round(12.0 * i / ITEMS.size())) % 12
	return 12 if h == 0 else h

func set_open(v: bool) -> void:
	super.set_open(v)
	if is_inside_tree(): _resize()

func _resize() -> void:
	if _anchor_center == Vector2.ZERO: _anchor_center = position + size / 2.0
	var s := OPEN_PX if open else CLOSED_PX
	custom_minimum_size = Vector2(s, s); size = Vector2(s, s)
	position = _anchor_center - size / 2.0

func _draw() -> void:
	super._draw()
	if _t <= 0.01: return
	var p := _item_pos(ITEMS.find("Security"))
	var w := 14.0
	var pts := PackedVector2Array([p + Vector2(0, -17), p + Vector2(w, -11), p + Vector2(w, 2), p + Vector2(0, 17), p + Vector2(-w, 2), p + Vector2(-w, -11)])
	draw_colored_polygon(pts, Color(PhoenixTokens.GOLD, 0.25 * _t))
	pts.append(pts[0])
	draw_polyline(pts, PhoenixTokens.GOLD * Color(1, 1, 1, _t), 2.5, true)
