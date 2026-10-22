class_name HoldButton
extends Button
## Destructive pill (UI_DESIGN_LANGUAGE §8 Buttons): ERR rim, hold 0.6 s to confirm while a ring fills.
## Emits `confirmed` only after a full hold; a short tap does nothing (shows the hint instead).
signal confirmed
const HOLD_S := 0.6
var _t := -1.0

func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, PhoenixTokens.tap())
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PhoenixTokens.OBSIDIAN, 0.85); sb.border_color = PhoenixTokens.ERR
	sb.set_border_width_all(2); sb.set_corner_radius_all(PhoenixTokens.RADIUS.pill); sb.set_content_margin_all(14)
	for k in ["normal", "hover", "pressed", "focus"]: add_theme_stylebox_override(k, sb)
	button_down.connect(func(): _t = 0.0)
	button_up.connect(func(): _t = -1.0; queue_redraw())
	tooltip_text = "Hold to confirm"

func _process(d: float) -> void:
	if _t < 0.0: return
	_t += d
	queue_redraw()
	if _t >= HOLD_S:
		_t = -1.0
		confirmed.emit()

## Test/accessibility hook: run a full hold synchronously.
func simulate_hold() -> void: confirmed.emit()

func _draw() -> void:
	if _t <= 0.0: return
	var r := size.y * 0.32
	var c := Vector2(size.y * 0.5, size.y * 0.5)
	draw_arc(c, r, -PI / 2, -PI / 2 + TAU * clampf(_t / HOLD_S, 0, 1), 32, PhoenixTokens.ERR, 4.0, true)
