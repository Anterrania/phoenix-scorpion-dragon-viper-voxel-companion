extends CanvasLayer
## v0.2 touch HUD: Jump + Camera (1st/3rd person) buttons, joystick ring hint.
## Buttons consume their own touches, so they never fight the move/look halves.

@export var player_path: NodePath
var player: Node

func _ready() -> void:
	player = get_node_or_null(player_path)
	var jump := _button("Jump", "JUMP", Vector2(-190, -190))
	jump.button_down.connect(func(): Input.action_press("jump"))
	jump.button_up.connect(func(): Input.action_release("jump"))
	var cam := _button("CameraToggle", "VIEW", Vector2(-190, -330))
	cam.pressed.connect(func(): if player and player.has_method("toggle_camera"): player.toggle_camera())
	var gfx := _button("Graphics", "GFX\n" + Settings.QUALITY_NAMES[Settings.quality()], Vector2(-190, -470))
	gfx.add_theme_font_size_override("font_size", 24)
	gfx.pressed.connect(func(): gfx.text = "GFX\n" + Settings.QUALITY_NAMES[Settings.cycle_quality()])
	# v0.5.1 flying: FLY toggle + hold UP / DOWN (shown only while flying).
	var fly := _button("Fly", "FLY", Vector2(-350, -190))
	var up := _button("FlyUp", "▲", Vector2(-350, -470))
	var down := _button("FlyDown", "▼", Vector2(-350, -330))
	for b in [up, down]: b.visible = false
	fly.pressed.connect(func(): if player and player.has_method("toggle_fly"): player.toggle_fly())
	up.button_down.connect(func(): if player: player.fly_vertical = 1.0)
	up.button_up.connect(func(): if player: player.fly_vertical = 0.0)
	down.button_down.connect(func(): if player: player.fly_vertical = -1.0)
	down.button_up.connect(func(): if player: player.fly_vertical = 0.0)
	if player and player.has_signal("flying_changed"):
		player.flying_changed.connect(func(on: bool):
			fly.text = "LAND" if on else "FLY"
			up.visible = on
			down.visible = on)
	# v0.6 combat buttons + shield bar
	var swipe := _button("Swipe", "⚔", Vector2(-510, -190))
	swipe.pressed.connect(func(): if player and player.has_method("melee_swipe"): player.melee_swipe())
	var bolt := _button("Bolt", "🔥", Vector2(-510, -330))
	bolt.pressed.connect(func(): if player and player.has_method("fire_bolt"): player.fire_bolt())
	var sh := ProgressBar.new()
	sh.name = "Shield"
	sh.max_value = 50.0
	sh.value = 50.0
	sh.show_percentage = false
	sh.offset_left = 24; sh.offset_top = 6; sh.offset_right = 324; sh.offset_bottom = 20
	var sfill := StyleBoxFlat.new(); sfill.bg_color = Color(0.35, 0.8, 1.0)
	sh.add_theme_stylebox_override("fill", sfill)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sh)
	if player and player.has_signal("shield_changed"):
		player.shield_changed.connect(func(v: float): sh.value = v)
	var zone := Label.new()
	zone.name = "ZoneLabel"
	zone.offset_left = 340; zone.offset_top = 6
	zone.add_theme_font_size_override("font_size", 24)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zone)
	var tm := Timer.new(); tm.wait_time = 0.5; tm.autostart = true; add_child(tm)
	tm.timeout.connect(func():
		if player:
			var on := CombatZone.is_damage_enabled(player.global_position)
			zone.text = "⚔ COMBAT ZONE (damage on)" if on else "Safe zone"
			zone.modulate = Color(1, 0.3, 0.3) if on else Color(0.6, 1, 0.7))
	var hp := ProgressBar.new()
	hp.name = "Health"
	hp.max_value = 100.0
	hp.value = 100.0
	hp.show_percentage = false
	hp.offset_left = 24; hp.offset_top = 24; hp.offset_right = 324; hp.offset_bottom = 46
	var fill := StyleBoxFlat.new(); fill.bg_color = Color(1, 0.18, 0.82)
	hp.add_theme_stylebox_override("fill", fill)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp)
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(func(v: float): hp.value = v)
	var hint := Label.new()
	hint.name = "MoveHint"
	hint.text = "◯ drag left side to move · drag right side to look"
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 24
	hint.offset_top = -48
	hint.modulate = Color(1, 0.76, 0.23, 0.8)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	get_tree().create_timer(12.0).timeout.connect(hint.queue_free)

func _button(n: String, t: String, off: Vector2) -> Button:
	var b := Button.new()
	b.name = n
	b.text = t
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + 150
	b.offset_bottom = off.y + 120
	b.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.08, 0.55)
	sb.border_color = Color(1, 0.18, 0.82)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(60)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b
