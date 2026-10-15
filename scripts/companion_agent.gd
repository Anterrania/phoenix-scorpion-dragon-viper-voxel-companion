# In-world companion agent. Loads the shared persona (same schema as the standalone Grok Bot).
# Requires Zylann godot_voxel. NOT yet run in Godot.
extends CharacterBody3D

enum State { IDLE, FOLLOW, BUILD, DIG }

@export var companion_id := "foxy_ani"
@export var terrain_path: NodePath
@export var player_path: NodePath
@export var speed := 4.0
@export var build_block_id := 1

var persona: Dictionary = {}
var state: State = State.IDLE
var _terrain: Node
var _player: Node3D
var _voxel_tool: VoxelTool
var _task_timer := 0.0

func _ready() -> void:
	persona = load_persona(companion_id)
	_terrain = get_node_or_null(terrain_path)
	_player = get_node_or_null(player_path)
	if _terrain and _terrain.has_method("get_voxel_tool"):
		_voxel_tool = _terrain.get_voxel_tool()
	state = State.FOLLOW

static func load_persona(id: String) -> Dictionary:
	var path := "res://companions/%s/persona.json" % id
	if not FileAccess.file_exists(path):
		push_warning("Persona not found: " + path)
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_task_timer -= delta
	match state:
		State.IDLE:
			velocity.x = 0; velocity.z = 0
		State.FOLLOW:
			_follow_player()
		State.BUILD:
			place_block(global_position + -global_basis.z * 2.0)
			state = State.FOLLOW
		State.DIG:
			dig_sphere(global_position + -global_basis.z * 2.0 + Vector3.DOWN, 2.0)
			state = State.FOLLOW
	move_and_slide()

func _follow_player() -> void:
	if _player == null:
		return
	var to := _player.global_position - global_position
	to.y = 0
	if to.length() > 3.0:
		var dir := to.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0; velocity.z = 0

# Called by chat/LLM tool calls (e.g. "place_voxel", "carve_area").
func command(action: String) -> void:
	match action:
		"build": state = State.BUILD
		"dig": state = State.DIG
		"follow": state = State.FOLLOW
		"stay": state = State.IDLE

func place_block(pos: Vector3) -> void:
	if _voxel_tool == null: return
	_voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	_voxel_tool.mode = VoxelTool.MODE_ADD
	_voxel_tool.value = build_block_id
	_voxel_tool.do_point(Vector3i(pos.floor()))

func dig_sphere(center: Vector3, radius: float) -> void:
	if _voxel_tool == null: return
	_voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	_voxel_tool.mode = VoxelTool.MODE_REMOVE
	_voxel_tool.do_sphere(center, radius)
