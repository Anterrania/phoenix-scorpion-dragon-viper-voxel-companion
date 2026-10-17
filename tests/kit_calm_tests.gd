extends RefCounted
## Calm premium kit (UI_DESIGN_LANGUAGE §12): GlassCarousel, GlassMenu, theme/radial calm rules.

static func _card(t: Node, txt: String) -> Control:
	var c: GlassCard = load("res://scenes/ui/kit/glass_card.tscn").instantiate()
	c.title = txt
	var r: RingStat = load("res://scenes/ui/kit/ring_stat.tscn").instantiate()
	c.body().add_child(r)
	return c

static func run_scene(t: Node) -> void:
	var tree := t.get_tree()
	# ---------- carousel ----------
	var ps = load("res://scenes/ui/kit/glass_carousel.tscn")
	t.check(ps is PackedScene, "kit: glass_carousel.tscn loads")
	var c: GlassCarousel = ps.instantiate()
	c.size = Vector2(600, 400); c.position = Vector2.ZERO
	tree.root.add_child(c)
	for i in 4: c.add_card(_card(t, "Card %d" % i))
	await tree.process_frame
	c.size = Vector2(600, 400)
	await tree.process_frame
	t.check(c.count() == 4 and c.index == 0, "carousel: 4 cards, starts on first")
	t.check(not c.auto_advance, "carousel: auto-advance off by default (opt-in only)")
	var got := [-1]
	c.page_changed.connect(func(i): got[0] = i)
	t.check(c.release(-200, 0, 0.5) == 1 and got[0] == 1, "carousel: swipe >= 30% width -> next card")
	t.check(c.release(-590, 0, 0.1) == 2, "carousel: long fast swipe moves only ONE card")
	t.check(c.release(-60, 0, 0.5) == 2, "carousel: short slow drag snaps back")
	t.check(c.release(-60, 0, 0.05) == 3, "carousel: flick > 600 px/s -> next")
	t.check(c.release(-300, 0, 0.5) == 3, "carousel: swipe never wraps past the last card")
	t.check(c.release(250, 0, 0.5) == 2, "carousel: swipe right -> previous")
	t.check(c.release(-300, 400, 0.5) == 2, "carousel: vertical drag ignored")
	await tree.create_timer(PhoenixTokens.MOTION.base + 0.1).timeout
	t.check(is_equal_approx(c.strip.position.x, -2 * c.track.size.x), "carousel: snaps to the card (strip at -index*width)")
	t.check(c.interval_s >= 3.0 and is_equal_approx(c.interval_s, PhoenixTokens.MOTION.ambient * 2.0), "carousel: interval from tokens")
	# opt-in auto-advance, pause on touch
	c.go(0, false)
	c.auto_advance = true; c.interval_s = 0.15
	c._resume_acc = c.interval_s; c._auto_acc = 0.0
	await tree.create_timer(0.3).timeout
	t.check(c.index >= 1, "carousel: opt-in auto-advance moves on")
	c.touch(true, Vector2(300, 100))
	var held := c.index
	await tree.create_timer(0.45).timeout
	t.check(c.paused and c.index == held, "carousel: touch pauses auto-advance")
	c.touch(false, Vector2(300, 100))
	t.check(not c.paused and not c.is_auto_running(), "carousel: release waits one interval before resuming")
	await tree.create_timer(0.5).timeout
	t.check(c.index != held, "carousel: auto-advance resumes after the pause")
	c.auto_advance = false
	c.go(c.count() - 1, false); c.auto_advance = true; c._resume_acc = c.interval_s; c._auto_acc = 0.0
	await tree.create_timer(0.25).timeout
	t.check(c.index == 0 or c.index == 1, "carousel: auto-advance loops back to the first card")
	c.auto_advance = false
	# drags on card content reach the carousel
	var ring := c.current().get_node("Pad/VBox/Body").get_child(0) as Control
	t.check(ring.mouse_filter == Control.MOUSE_FILTER_PASS, "carousel: card content passes drags to the track")
	c.set_cards([_card(t, "Only")])
	t.check(c.count() == 1 and c.index == 0, "carousel: set_cards replaces cards")
	c.queue_free()
	# motion rule: snap tween uses MOTION.base within 180-240 ms
	t.check(PhoenixTokens.MOTION.base >= 0.18 and PhoenixTokens.MOTION.base <= 0.24, "calm: base motion 180-240 ms")

	# ---------- glass menu ----------
	var mps = load("res://scenes/ui/kit/glass_menu.tscn")
	t.check(mps is PackedScene, "kit: glass_menu.tscn loads")
	var m: GlassMenu = mps.instantiate(); tree.root.add_child(m)
	for i in 9: m.add_item("i%d" % i, "Item %d" % i, "◎", "3" if i == 0 else "", i == 1)
	t.check(m.ids().size() == GlassMenu.MAX_ROWS, "menu: capped at 7 rows")
	var sel := [""]
	m.item_selected.connect(func(id): sel[0] = id)
	m.row("i2").pressed.emit()
	t.check(sel[0] == "i2", "menu: tap emits item_selected(id)")
	t.check(m.row("i0").custom_minimum_size.y >= PhoenixTokens.TAP_MIN, "menu: rows meet the tap token")
	t.check(m.row("i0").get_theme_font_size("font_size") >= PhoenixTokens.TYPE.body, "menu: row text uses TYPE.body")
	t.check((m.row("i0").get_node("Tail") as Label).text.begins_with("3"), "menu: badge shown")
	var foxy_border: Color = (m.row("i1").get_theme_stylebox("pressed") as StyleBoxFlat).border_color
	var plain_border: Color = (m.row("i2").get_theme_stylebox("pressed") as StyleBoxFlat).border_color
	t.check(Color(foxy_border, 1.0).is_equal_approx(PhoenixTokens.EMBER) and Color(plain_border, 1.0).is_equal_approx(PhoenixTokens.MAGENTA), "menu: ember only on Foxy rows")
	m.set_badge("i0", ""); t.check((m.row("i0").get_node("Tail") as Label).text == "›", "menu: badge cleared")
	m.queue_free()

	# ---------- calm theme / radial / card ----------
	var th: Theme = load("res://themes/phoenix_glass.tres")
	var normal := th.get_stylebox("normal", "Button") as StyleBoxFlat
	t.check(normal.border_color.a <= 0.35 and normal.border_width_left <= 1, "calm: button rim toned down")
	t.check((th.get_stylebox("focus", "Button") as StyleBoxFlat).border_width_left <= 2, "calm: focus ring 2 px")
	t.check(not FileAccess.get_file_as_string("res://scripts/ui/kit/radial_menu.gd").contains("TRANS_BACK"), "calm: radial bloom has no bounce")
	var rm: RadialMenu = load("res://scenes/ui/kit/radial_menu.tscn").instantiate()
	t.check(rm.calm, "calm: radial calm by default (no ember halo)")
	rm.free()
	var gc: GlassCard = load("res://scenes/ui/kit/glass_card.tscn").instantiate(); tree.root.add_child(gc)
	await tree.process_frame
	var gm: ShaderMaterial = gc.get_node("Glass").material
	t.check(float(gm.get_shader_parameter("sparkle")) <= 0.1 and (gm.get_shader_parameter("rim_color") as Color).a <= 0.3 + 0.001, "calm: glass card rim + sparkle toned down")
	gc.queue_free()
	t.check(FileAccess.get_file_as_string("res://docs/UI_DESIGN_LANGUAGE.md").contains("## 12. Calm premium mode"), "calm: design doc section")
