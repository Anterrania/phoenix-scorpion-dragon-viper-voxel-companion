class_name ViperRadial
extends RadialMenu
## HUD radial launcher on Foxy's RadialMenu (UI_DESIGN_LANGUAGE §8). Six evenly spaced items,
## clockwise from 12 o'clock: Admin (12, opens the dashboard), Security (2, shield, opens lock +
## audit), Chat (4), Map (6), Proposals (8), Menu (10). Collapsed it is only the hub, so it doesn't
## block the world.
const ITEMS := ["Admin", "Security", "Chat", "Map", "Proposals", "Menu"]
const GLYPHS := ["◎", "", "✦", "◉", "✔", "☰"]   # Security draws a shield (emoji fonts vary on Android)
const OPEN_PX := 360.0     # base sizes, scaled by PhoenixTokens.icon_scale (Settings > Display)
const CLOSED_PX := 120.0
const EDGE_PX := 76.0      # hub center distance from the right edge
const Y_FRAC := 0.55       # hub center height as a fraction of the screen
var _anchor_center := Vector2.ZERO
## Re-anchor on resize/rotation (2026-10-17): the hub used to keep its first position, so after
## rotating to landscape it sat mid-screen or off the edge.
var follow_viewport := true

func _init() -> void:
	items.assign(ITEMS); glyphs.assign(GLYPHS)
	open = false

func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(reanchor)
	var st := get_node_or_null("/root/Settings")
	if st and st.has_signal("display_changed"): st.display_changed.connect(reanchor)
	_resize()

## Hub center for a viewport size (right edge, Y_FRAC down), kept on screen at any icon scale.
static func anchor_for(vp: Vector2) -> Vector2:
	var half := CLOSED_PX * PhoenixTokens.icon_scale / 2.0
	return Vector2(vp.x - maxf(EDGE_PX * PhoenixTokens.icon_scale, half + 8.0), clampf(vp.y * Y_FRAC, half + 8.0, vp.y - half - 8.0))

func reanchor() -> void:
	if not follow_viewport or not is_inside_tree(): return
	_anchor_center = anchor_for(get_viewport().get_visible_rect().size)
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
	button_radius = PhoenixTokens.icon(36.0)
	var s := (OPEN_PX if open else CLOSED_PX) * PhoenixTokens.icon_scale
	custom_minimum_size = Vector2(s, s); size = Vector2(s, s)
	position = _anchor_center - size / 2.0
	if open and is_inside_tree():   # keep the open ring fully on screen (landscape / Large)
		var vp := get_viewport().get_visible_rect().size
		position = position.clamp(Vector2.ZERO, (vp - size).max(Vector2.ZERO))

func _draw() -> void:
	super._draw()
	if _t <= 0.01: return
	var p := _item_pos(ITEMS.find("Security"))
	var w := 14.0
	var pts := PackedVector2Array([p + Vector2(0, -17), p + Vector2(w, -11), p + Vector2(w, 2), p + Vector2(0, 17), p + Vector2(-w, 2), p + Vector2(-w, -11)])
	draw_colored_polygon(pts, Color(PhoenixTokens.GOLD, 0.25 * _t))
	pts.append(pts[0])
	draw_polyline(pts, PhoenixTokens.GOLD * Color(1, 1, 1, _t), 2.5, true)
