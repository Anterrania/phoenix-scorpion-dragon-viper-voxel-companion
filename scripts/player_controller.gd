# Player: keyboard/mouse + touch move, look, jump, and VoxelTool raycast dig/place.
# Requires Zylann godot_voxel (pinned: GDExtension 1.7x, Godot 4.7.2). Merged from old scripts/player.gd.
# Touch: left half drag = move; right half drag = look; right tap = dig;
#        right long-press = place; two-finger tap = jump.
extends CharacterBody3D

@export var terrain_path: NodePath = NodePath("../VoxelTerrain")
@export var speed := 5.0
@export var jump_velocity := 5.5
@export var mouse_sensitivity := 0.003
@export var touch_look_sensitivity := 0.006
@export var reach := 8.0
@export var place_block_id := 1
@export var long_press_time := 0.4

## Camera may live under a Head pivot (scenes/player.tscn) or directly under the body.
@onready var head: Node3D = get_node_or_null("Head")
@onready var camera: Camera3D = get_node_or_null("Head/Camera3D") if has_node("Head/Camera3D") else get_node_or_null("Camera3D")
var _vt: VoxelTool
var _move_touch := -1
var _move_origin := Vector2.ZERO
var _move_vec := Vector2.ZERO
var _look_touch := -1
var _look_start := 0.0
var _look_moved := false
var _touches := 0
var _jump_requested := false

func _ready() -> void:
	var terrain := get_node_or_null(terrain_path)
	if terrain and terrain.has_method("get_voxel_tool"):
		_vt = terrain.get_voxel_tool()
		_vt.channel = VoxelBuffer.CHANNEL_TYPE
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## External UI (on-screen joystick) can drive movement.
func set_move_vector(v: Vector2) -> void:
	_move_vec = v.limit_length(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: dig()
		elif event.button_index == MOUSE_BUTTON_RIGHT: place()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _on_touch(e: InputEventScreenTouch) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	_touches = max(0, _touches + (1 if e.pressed else -1))
	if e.pressed and _touches >= 2:
		_jump_requested = true
	if e.pressed:
		if e.position.x < half and _move_touch == -1:
			_move_touch = e.index; _move_origin = e.position
		elif _look_touch == -1:
			_look_touch = e.index; _look_moved = false
			_look_start = Time.get_ticks_msec() / 1000.0
	elif e.index == _move_touch:
		_move_touch = -1; _move_vec = Vector2.ZERO
	elif e.index == _look_touch:
		_look_touch = -1
		if not _look_moved:
			if Time.get_ticks_msec() / 1000.0 - _look_start >= long_press_time: place()
			else: dig()

func _on_drag(e: InputEventScreenDrag) -> void:
	if e.index == _move_touch:
		_move_vec = ((e.position - _move_origin) / 80.0).limit_length(1.0)
	elif e.index == _look_touch:
		if e.relative.length() > 2.0: _look_moved = true
		_look(e.relative * touch_look_sensitivity)

func _look(d: Vector2) -> void:
	rotate_y(-d.x)
	var pitch: Node3D = head if head else camera
	pitch.rotation.x = clampf(pitch.rotation.x - d.y, -1.4, 1.4)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if (Input.is_action_just_pressed("jump") or _jump_requested) and is_on_floor():
		velocity.y = jump_velocity
	_jump_requested = false
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _move_vec != Vector2.ZERO:
		input = _move_vec
	var dir := (global_basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

func _raycast() -> VoxelRaycastResult:
	if _vt == null: return null
	return _vt.raycast(camera.global_position, -camera.global_basis.z, reach)

func dig() -> void:
	var hit := _raycast()
	if hit == null: return
	_vt.mode = VoxelTool.MODE_REMOVE
	_vt.do_point(hit.position)

func place() -> void:
	var hit := _raycast()
	if hit == null: return
	if Vector3i(global_position.floor()) == hit.previous_position: return
	_vt.mode = VoxelTool.MODE_ADD
	_vt.value = place_block_id
	_vt.do_point(hit.previous_position)
