class_name BootIntro
extends CanvasLayer
## v0.16 BRAND: OS-style boot animation. The Viper emblem fades into the crest video, then it settles on the
## crest. Plays once per launch, tap/click/back to skip, and never blocks the app: a missing video, a decode
## failure or a stall just closes it (hard cap MAX_SECONDS). Headless runs (tests, CI) skip it.

const VIDEO := "res://assets/brand/viper_boot.ogv"
const CREST := "res://assets/brand/viper_crest.png"
const MAX_SECONDS := 10.0
var _player: VideoStreamPlayer
var _crest: TextureRect
var _done := false

static func should_play() -> bool:
	return DisplayServer.get_name() != "headless" and ResourceLoader.exists(VIDEO)

static func show_on(parent: Node) -> BootIntro:
	if not should_play(): return null
	var b := BootIntro.new()
	parent.add_child(b)
	return b

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.027, 0.024, 0.039, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed: finish())
	add_child(bg)
	_crest = TextureRect.new()
	if ResourceLoader.exists(CREST): _crest.texture = load(CREST)
	_crest.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crest.visible = false
	add_child(_crest)
	_player = VideoStreamPlayer.new()
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stream = load(VIDEO)
	if stream == null: finish(); return
	_player.stream = stream
	_player.finished.connect(_on_finished)
	add_child(_player)
	_player.resized.connect(_fit)
	_fit()
	_player.play()
	var skip := Label.new()
	skip.text = "Tap to skip"
	skip.add_theme_color_override("font_color", Color(0.91, 0.75, 0.38, 0.7))
	skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip.position.y -= 60
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skip)
	get_tree().create_timer(MAX_SECONDS, true).timeout.connect(finish)
	get_tree().create_timer(2.5, true).timeout.connect(func():
		if is_instance_valid(_player) and not _player.is_playing() and not _done: _on_finished())

## Keep the square video square and centred in portrait and landscape.
func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var side := minf(vs.x, vs.y) * 0.92
	_player.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_player.size = Vector2(side, side)
	_player.position = (vs - _player.size) * 0.5

func _on_finished() -> void:
	if _done: return
	_crest.visible = true   # settle on the final crest frame
	if is_instance_valid(_player): _player.visible = false
	get_tree().create_timer(0.7, true).timeout.connect(finish)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled(); finish()

func finish() -> void:
	if _done: return
	_done = true
	if is_instance_valid(_player): _player.stop()
	var tw := create_tween()
	for c in get_children():
		if c is CanvasItem: tw.parallel().tween_property(c, "modulate:a", 0.0, 0.4)
	tw.finished.connect(queue_free)
