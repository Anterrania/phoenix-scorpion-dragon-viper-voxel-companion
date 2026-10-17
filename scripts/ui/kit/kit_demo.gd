extends Control
## Phoenix Glass kit demo (portrait 720x1280).
const RING := preload("res://scenes/ui/kit/ring_stat.tscn")
const CARD := preload("res://scenes/ui/kit/glass_card.tscn")
const GRAPH := preload("res://scenes/ui/kit/line_graph.tscn")
const RADIAL := preload("res://scenes/ui/kit/radial_menu.tscn")
func _ready() -> void:
	var col: VBoxContainer = $Margin/Col
	var tabs := TabBar.new(); for t in ["Home", "Realm", "Crew", "Admin"]: tabs.add_tab(t)
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER; col.add_child(tabs)
	var stats := CARD.instantiate(); stats.title = "Foxy · Today"; col.add_child(stats)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 24)
	stats.body().add_child(row)
	for d in [[0.72, "XP", ""], [0.45, "Build", ""], [0.9, "Ember", "9/10"]]:
		var r := RING.instantiate(); r.value = d[0]; r.caption = d[1]; r.display_text = d[2]
		r.custom_minimum_size = Vector2(170, 170)
		if d[1] == "Ember": r.color_a = PhoenixTokens.VENUS; r.color_b = PhoenixTokens.PHOENIX
		row.add_child(r)
	var g := CARD.instantiate(); g.title = "Realm visitors · 10 days"; col.add_child(g)
	var big := Label.new(); big.text = "1,284"; big.theme_type_variation = &"DisplayLabel"; g.body().add_child(big)
	var lg := GRAPH.instantiate(); lg.custom_minimum_size = Vector2(0, 150); g.body().add_child(lg)
	var rc := CenterContainer.new(); rc.size_flags_vertical = SIZE_EXPAND_FILL; col.add_child(rc)
	var rm := RADIAL.instantiate(); rm.custom_minimum_size = Vector2(360, 360); rc.add_child(rm)
	var b := Button.new(); b.text = "Rise from the flame"; b.custom_minimum_size = Vector2(0, 64); col.add_child(b)
