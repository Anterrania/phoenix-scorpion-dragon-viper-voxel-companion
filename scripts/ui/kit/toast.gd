class_name Toast
extends PanelContainer
## Toast (§8): 56 px glass pill at the top safe area, icon ring + <= 6 words, 2.5 s auto-dismiss,
## swipe up to dismiss, ONE at a time. Variants: ok / warn / err / ember (companion speaking).
const GROUP := "phoenix_toast"
const LIFE_S := 2.5
const VARIANTS := {"ok": PhoenixTokens.OK, "warn": PhoenixTokens.WARN, "err": PhoenixTokens.ERR, "ember": PhoenixTokens.EMBER}
var text := ""
var variant := "ok"
var _press_y := 0.0

static func show_toast(parent: Node, p_text: String, p_variant := "ok") -> Toast:
	for t in parent.get_tree().get_nodes_in_group(GROUP): t.queue_free()
	var words := p_text.split(" ", false)
	var t := Toast.new()
	t.text = " ".join(words.slice(0, 6))
	t.variant = p_variant if VARIANTS.has(p_variant) else "ok"
	parent.add_child(t)
	return t

func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_preset(Control.PRESET_CENTER_TOP); position.y = 24
	custom_minimum_size = Vector2(0, PhoenixTokens.tap()); grow_horizontal = Control.GROW_DIRECTION_BOTH
	var c: Color = VARIANTS[variant]
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(PhoenixTokens.GLASS, 0.9); sb.border_color = Color(c, 0.8)
	sb.set_border_width_all(2); sb.set_corner_radius_all(PhoenixTokens.RADIUS.pill)
	sb.content_margin_left = 16; sb.content_margin_right = 22
	add_theme_stylebox_override("panel", sb)
	var l := Label.new(); l.text = "◉  " + text; l.add_theme_color_override("font_color", PhoenixTokens.PLATINUM)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; add_child(l)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, PhoenixTokens.MOTION.fast)
	tw.tween_interval(LIFE_S)
	tw.tween_property(self, "modulate:a", 0.0, PhoenixTokens.MOTION.fast)
	tw.tween_callback(queue_free)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton or e is InputEventScreenTouch:
		if e.pressed: _press_y = e.position.y
		elif _press_y - e.position.y > 24: queue_free()
