extends CharacterBody3D
## First-person player. Keyboard/mouse on desktop; touch: left half = virtual
## joystick, right half = look drag. External UI can call set_move_vector().

@export var speed := 6.0
@export var jump_velocity := 5.5
@export var look_sensitivity := 0.004
@export var touch_look_sensitivity := 0.008
@export var joystick_radius := 120.0

@export var avatar_path := "res://data/player_avatar.json"

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
var avatar: Node3D
var third_person := true
var _anim_t := 0.0
const FP_CAM := Vector3(0, 0, 0)
const TP_CAM := Vector3(0.45, 0.55, 3.4)

static func load_avatar_style(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := {"look": "royal"}
	if d is Dictionary:
		for k in ["skin", "hair", "eyes", "outfit", "accent", "trim"]:
			if d.has(k): out[k] = Color(str(d[k]))
		out["look"] = str(d.get("look", "royal"))
		out["glow"] = float(d.get("glow", 1.5))
		out["third_person"] = str(d.get("default_camera", "third_person")) == "third_person"
	return out

func _ready() -> void:
	var st := load_avatar_style(avatar_path)
	avatar = HumanoidModel.build(st)
	avatar.name = "Avatar"
	avatar.position.y = -0.85
	add_child(avatar)
	set_third_person(st.get("third_person", true))

func set_third_person(on: bool) -> void:
	third_person = on
	camera.position = TP_CAM if on else FP_CAM
	if avatar: avatar.visible = on

func toggle_camera() -> void:
	set_third_person(not third_person)

func _process(delta: float) -> void:
	_anim_t += delta
	HumanoidModel.animate(avatar, _anim_t, clampf(Vector2(velocity.x, velocity.z).length() / speed, 0.0, 1.0))
	if global_position.y < -80.0:  # fell through unloaded terrain
		global_position = Vector3(global_position.x, 45, global_position.z)
		velocity = Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _touch_move := Vector2.ZERO
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _look_index := -1

func set_move_vector(v: Vector2) -> void:
	_touch_move = v.limit_length(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		toggle_camera()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * look_sensitivity)
	elif event is InputEventScreenTouch:
		var half := get_viewport().get_visible_rect().size.x * 0.5
		if event.pressed:
			if event.position.x < half and _joy_index == -1:
				_joy_index = event.index
				_joy_origin = event.position
			elif _look_index == -1:
				_look_index = event.index
		else:
			if event.index == _joy_index:
				_joy_index = -1
				_touch_move = Vector2.ZERO
			elif event.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _joy_index:
			_touch_move = ((event.position - _joy_origin) / joystick_radius).limit_length(1.0)
		elif event.index == _look_index:
			_look(event.relative * touch_look_sensitivity)

func _look(d: Vector2) -> void:
	rotate_y(-d.x)
	head.rotate_x(-d.y)
	head.rotation.x = clamp(head.rotation.x, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_move != Vector2.ZERO:
		input = _touch_move
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * speed if dir else move_toward(velocity.x, 0, speed)
	velocity.z = dir.z * speed if dir else move_toward(velocity.z, 0, speed)
	move_and_slide()
