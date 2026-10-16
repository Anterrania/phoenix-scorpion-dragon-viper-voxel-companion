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
