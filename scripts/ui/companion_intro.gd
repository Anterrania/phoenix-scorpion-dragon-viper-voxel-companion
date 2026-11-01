class_name CompanionIntro
extends Control
## v0.13 INTRO-1: cinematic, video-style reveal when a companion is added.
## A short "trailer" built from in-engine shapes (no video file, works offline):
##   fade_in  -> letterbox bars slide in (2.39:1 film framing)
##   flare    -> a gold/magenta flare ring blooms, sparkles burst
##   reveal   -> the companion's name scales up out of the light, the role fades in under it
##   line     -> the companion's greeting is shown and spoken (CompanionVoice)
##   outro    -> everything fades, the overlay frees itself and emits finished(companion_id)
## Tap anywhere to skip. speed > 1 plays faster (tests use it); the order of phases never changes.

signal finished(companion_id: String)
signal phase_changed(phase: String)

const PHASES := ["fade_in", "letterbox", "flare", "reveal", "line", "outro"]
const DURATIONS := {"fade_in": 0.5, "letterbox": 0.6, "flare": 0.9, "reveal": 1.2, "line": 2.2, "outro": 0.7}

var companion_id := ""
var display_name := "Companion"
var role_text := ""
var greeting := "Rise from the flame."
var persona := {}
var speed := 1.0
var speak := true
var phase := ""
var phases_seen: Array = []
var done := false

var _bg: ColorRect
var _top: ColorRect
var _bot: ColorRect
var _ring: Panel
var _name: Label
var _role: Label
var _line: Label
var _sparks: CPUParticles2D
var _tw: Tween

static func total_seconds() -> float:
	var t := 0.0
	for p in PHASES: t += float(DURATIONS[p])
	return t

## Build and start an intro over `host`. persona = persona.json dictionary.
static func play(host: Node, cid: String, p_persona: Dictionary, p_speed := 1.0) -> CompanionIntro:
	var c := CompanionIntro.new()
	c.name = "CompanionIntro"
	c.companion_id = cid
	c.persona = p_persona
	c.display_name = str(p_persona.get("display_name", p_persona.get("name", cid)))
	c.role_text = str(p_persona.get("role", ""))
	var g := str(p_persona.get("greeting", ""))
	if g != "": c.greeting = g
	c.speed = maxf(0.1, p_speed)
	host.add_child(c)
	return c

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new(); _bg.color = Color(PhoenixTokens.VOID, 0.0); _bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_bg)
	_top = _bar(true); _bot = _bar(false)
	_ring = Panel.new(); _ring.name = "Flare"
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0); sb.border_color = PhoenixTokens.GOLD
	sb.set_border_width_all(6); sb.set_corner_radius_all(200); sb.shadow_color = Color(PhoenixTokens.MAGENTA, 0.8); sb.shadow_size = 24
	_ring.add_theme_stylebox_override("panel", sb)
	_ring.size = Vector2(400, 400); _ring.pivot_offset = _ring.size / 2.0
	_ring.set_anchors_preset(Control.PRESET_CENTER); _ring.position -= _ring.size / 2.0
	_ring.scale = Vector2(0.05, 0.05); _ring.modulate.a = 0.0; _ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_sparks = CPUParticles2D.new(); _sparks.name = "Sparkles"; _sparks.emitting = false; _sparks.one_shot = true
	_sparks.amount = 90; _sparks.lifetime = 1.6; _sparks.explosiveness = 0.85; _sparks.spread = 180.0
	_sparks.initial_velocity_min = 120.0; _sparks.initial_velocity_max = 420.0; _sparks.gravity = Vector2(0, 60)
	_sparks.scale_amount_min = 2.0; _sparks.scale_amount_max = 5.0
	var grad := Gradient.new(); grad.set_color(0, PhoenixTokens.GOLD); grad.set_color(1, Color(PhoenixTokens.MAGENTA, 0.0))
	_sparks.color_ramp = grad
	add_child(_sparks)
	_name = _text(display_name, 64, PhoenixTokens.PLATINUM, -40)
	_role = _text(role_text, 28, PhoenixTokens.GOLD, 40)
	_line = _text("“%s”" % greeting, 30, PhoenixTokens.MAGENTA, 120)
	_name.pivot_offset = Vector2(get_viewport_rect().size.x / 2.0, 40)
	_name.scale = Vector2(0.6, 0.6)
	_layout_center()
	_run()

func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new(); r.color = Color.BLACK; r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.name = "LetterboxTop" if top else "LetterboxBottom"
	r.anchor_left = 0.0; r.anchor_right = 1.0
	var a := 0.0 if top else 1.0
	r.anchor_top = a
	r.anchor_bottom = a
	r.offset_top = 0.0; r.offset_bottom = 0.0
	add_child(r)
	return r

func _text(t: String, fs: int, col: Color, dy: float) -> Label:
	var l := Label.new(); l.text = t; l.modulate.a = 0.0; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs); l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9)); l.add_theme_constant_override("outline_size", 8)
	l.anchor_left = 0.0; l.anchor_right = 1.0; l.anchor_top = 0.5; l.anchor_bottom = 0.5
	l.offset_left = 24; l.offset_right = -24; l.offset_top = dy - 40; l.offset_bottom = dy + 40
	add_child(l)
	return l

func _layout_center() -> void:
	var vp := get_viewport_rect().size
	_sparks.position = vp / 2.0
	_ring.position = vp / 2.0 - _ring.size / 2.0

func _d(p: String) -> float: return float(DURATIONS[p]) / speed

func _enter(p: String) -> void:
	phase = p
	phases_seen.append(p)
	phase_changed.emit(p)
	if p == "flare":
		_sparks.restart()
		_sparks.emitting = true
	if p == "line" and speak and companion_id != "":
		CompanionVoice.speak(companion_id, persona, greeting)

func _run() -> void:
	var bar_h := get_viewport_rect().size.y * 0.12
	_tw = create_tween()
	_tw.tween_callback(_enter.bind("fade_in"))
	_tw.tween_property(_bg, "color:a", 0.92, _d("fade_in"))
	_tw.tween_callback(_enter.bind("letterbox"))
	_tw.tween_property(_top, "offset_bottom", bar_h, _d("letterbox"))
	_tw.parallel().tween_property(_bot, "offset_top", -bar_h, _d("letterbox"))
	_tw.tween_callback(_enter.bind("flare"))
	_tw.tween_property(_ring, "modulate:a", 1.0, _d("flare") * 0.3)
	_tw.parallel().tween_property(_ring, "scale", Vector2(1.3, 1.3), _d("flare")).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(_enter.bind("reveal"))
	_tw.tween_property(_name, "modulate:a", 1.0, _d("reveal") * 0.5)
	_tw.parallel().tween_property(_name, "scale", Vector2.ONE, _d("reveal")).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_property(_ring, "modulate:a", 0.25, _d("reveal"))
	_tw.tween_property(_role, "modulate:a", 1.0, _d("reveal") * 0.4)
	_tw.tween_callback(_enter.bind("line"))
	_tw.tween_property(_line, "modulate:a", 1.0, _d("line") * 0.3)
	_tw.tween_interval(_d("line") * 0.7)
	_tw.tween_callback(_enter.bind("outro"))
	_tw.tween_property(self, "modulate:a", 0.0, _d("outro"))
	_tw.tween_callback(_finish)

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed): skip()

## Jump to the end (tap to skip).
func skip() -> void:
	if done: return
	if _tw and _tw.is_valid(): _tw.kill()
	if not "outro" in phases_seen: _enter("outro")
	_finish()

func _finish() -> void:
	if done: return
	done = true
	finished.emit(companion_id)
	queue_free()
