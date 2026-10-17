class_name ViperKit
extends RefCounted
## Thin helpers over Foxy's Phoenix Glass kit (docs/UI_DESIGN_LANGUAGE.md): theme, cards, rings,
## status-chip colors. All colors come from PhoenixTokens; nothing is redefined here.
const THEME_PATH := "res://themes/phoenix_glass.tres"
const CARD := preload("res://scenes/ui/kit/glass_card.tscn")
const RING := preload("res://scenes/ui/kit/ring_stat.tscn")
const GRAPH := preload("res://scenes/ui/kit/line_graph.tscn")

static func theme() -> Theme: return load(THEME_PATH)

static func card(title: String) -> GlassCard:
	var c: GlassCard = CARD.instantiate(); c.title = title
	return c

## Ring sizes per §8: 120 inline, 160 card, 240 hero.
static func ring(value: float, caption: String, text := "", px := 120, fire := false) -> RingStat:
	var r: RingStat = RING.instantiate()
	r.value = clampf(value, 0.0, 1.0); r.caption = caption; r.display_text = text
	r.custom_minimum_size = Vector2(px, px)
	if fire: r.color_a = PhoenixTokens.VENUS; r.color_b = PhoenixTokens.PHOENIX
	return r

static func graph(points: PackedFloat32Array) -> LineGraph:
	var g: LineGraph = GRAPH.instantiate(); g.custom_minimum_size = Vector2(0, 150); g.points = points
	return g

static func status_color(status: String) -> Color:
	match status:
		"new": return PhoenixTokens.PLATINUM
		"assigned", "reopened": return PhoenixTokens.WARN
		"accepted": return PhoenixTokens.MAGENTA
		"closed": return PhoenixTokens.OK
	return PhoenixTokens.PLATINUM_DIM

static func primary(text: String, f: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.pressed.connect(f)
	return b

static func rich(min_h := 0) -> RichTextLabel:
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.selection_enabled = true
	r.custom_minimum_size = Vector2(0, min_h); r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r
