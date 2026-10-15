extends CharacterBody3D
## First-person player. Keyboard/mouse on desktop; touch: left half = virtual
## joystick, right half = look drag. External UI can call set_move_vector().

@export var speed := 6.0
@export var jump_velocity := 5.5
@export var look_sensitivity := 0.004
@export var touch_look_sensitivity := 0.008
@export var joystick_radius := 120.0

@onready var head: Node3D = $Head
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _touch_move := Vector2.ZERO
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _look_index := -1

func set_move_vector(v: Vector2) -> void:
	_touch_move = v.limit_length(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
