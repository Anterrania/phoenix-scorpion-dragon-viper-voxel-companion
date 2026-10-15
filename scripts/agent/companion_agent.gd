extends CharacterBody3D
## Reusable in-game AI companion. Configure with a CompanionConfig resource.
## Idle wander / follow behavior + tool implementations called by AgentBrain.

signal said(text: String)

@export var config: CompanionConfig
@export var player_path: NodePath
@export var world_path: NodePath

var companion_id := ""
var persona := {}
var following := true
var _target: Variant = null   # Vector3 or null
var _idle_timer := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var player: Node3D = get_node_or_null(player_path)
@onready var world: Node = get_node_or_null(world_path)

func _ready() -> void:
	if config == null:
		push_error("CompanionAgent needs a CompanionConfig")
		return
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(config.persona_path))
	persona = p if p is Dictionary else {}
	companion_id = persona.get("id", name)
	_apply_look()
	AgentBrain.register_agent(self)
	AgentBrain.reply_ready.connect(_on_reply)

func _exit_tree() -> void:
	AgentBrain.unregister_agent(self)

func _apply_look() -> void:
	var mesh := get_node_or_null("Body") as MeshInstance3D
	if mesh:
		var m := StandardMaterial3D.new()
		m.albedo_color = config.body_color
		m.emission_enabled = config.emissive > 0.0
		m.emission = config.accent_color
		m.emission_energy_multiplier = config.emissive
		mesh.material_override = m

## Text chat entry point (UI calls this). Voice hook: feed STT text here.
func talk(text: String) -> void:
	AgentBrain.chat(companion_id, text)

func _on_reply(id: String, text: String) -> void:
	if id == companion_id and text != "":
		said.emit(text)
		speak(text)

## Voice hook: replace with TTS (DisplayServer.tts_speak or a cloud TTS).
func speak(text: String) -> void:
	if DisplayServer.tts_get_voices().size() > 0 and persona.get("voice", {}).get("tts_enabled", false):
		DisplayServer.tts_speak(text, DisplayServer.tts_get_voices()[0]["id"])

func get_player_position() -> Vector3:
	return player.global_position if player else Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var goal: Variant = _target
	if following and player and global_position.distance_to(player.global_position) > config.follow_distance:
		goal = player.global_position
	if goal == null:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_idle_timer = randf_range(3.0, 7.0)
			rotate_y(randf_range(-1.0, 1.0))
		velocity.x = move_toward(velocity.x, 0, config.move_speed)
		velocity.z = move_toward(velocity.z, 0, config.move_speed)
	else:
		var to: Vector3 = (goal as Vector3) - global_position
		to.y = 0
		if to.length() < 0.6:
			_target = null
		else:
			var d := to.normalized()
			velocity.x = d.x * config.move_speed
			velocity.z = d.z * config.move_speed
			look_at(global_position + d, Vector3.UP)
			if is_on_wall() and is_on_floor():
				velocity.y = 5.0  # hop up 1-voxel steps
	move_and_slide()

# ---------- tools (invoked by AgentBrain.dispatch_tool) ----------
func _vt():
	return world.get_voxel_tool() if world and world.has_method("get_voxel_tool") else null

func _near(pos: Vector3, max_dist := 64.0) -> bool:
	return pos.distance_to(global_position) <= max_dist

func tool_place_voxel(a: Dictionary) -> Dictionary:
	var vt = _vt()
	var p := Vector3i(int(a.x), int(a.y), int(a.z))
	if vt == null or not _near(Vector3(p)):
		return {"ok": false, "error": "no terrain or too far"}
	vt.channel = 0
	vt.value = clampi(int(a.get("material", 1)), 0, 15)
	vt.do_point(p)
	return {"ok": true}

func tool_carve_area(a: Dictionary) -> Dictionary:
	var vt = _vt()
	var c := Vector3(a.x, a.y, a.z)
	if vt == null or not _near(c):
		return {"ok": false, "error": "no terrain or too far"}
	vt.channel = 0
	vt.mode = 1  # VoxelTool.MODE_REMOVE
	vt.do_sphere(c, clampf(float(a.radius), 1.0, 8.0))
	vt.mode = 0
	return {"ok": true}

func tool_spawn_structure(a: Dictionary) -> Dictionary:
	var vt = _vt()
	var o := Vector3i(int(a.x), int(a.y), int(a.z))
	if vt == null or not _near(Vector3(o)):
		return {"ok": false, "error": "no terrain or too far"}
	vt.channel = 0
	vt.value = clampi(int(a.get("material", 2)), 1, 15)
	match str(a.name):
		"pillar", "tower":
			var h := 6 if a.name == "pillar" else 14
			vt.do_box(o, o + Vector3i(1 if a.name == "pillar" else 3, h, 1 if a.name == "pillar" else 3))
		"wall":
			vt.do_box(o, o + Vector3i(8, 4, 0))
		"hut":
			vt.do_box(o, o + Vector3i(5, 4, 5))
			vt.mode = 1
			vt.do_box(o + Vector3i(1, 0, 1), o + Vector3i(4, 3, 4))
			vt.do_box(o + Vector3i(2, 0, 0), o + Vector3i(3, 2, 0))
			vt.mode = 0
		"arch":
			vt.do_box(o, o + Vector3i(0, 5, 0))
			vt.do_box(o + Vector3i(5, 0, 0), o + Vector3i(5, 5, 0))
			vt.do_box(o + Vector3i(0, 6, 0), o + Vector3i(5, 6, 0))
		"fire_altar":
			vt.do_box(o, o + Vector3i(2, 1, 2))
			vt.value = 9  # emissive "fire" material in the voxel library
			vt.do_point(o + Vector3i(1, 2, 1))
		_:
			return {"ok": false, "error": "unknown structure"}
	return {"ok": true}

func tool_follow(a: Dictionary) -> Dictionary:
	following = bool(a.get("enabled", true))
	_target = null
	return {"ok": true}

func tool_move_to(a: Dictionary) -> Dictionary:
	var t := Vector3(float(a.x), float(a.get("y", global_position.y)), float(a.z))
	if not _near(t, 128.0):
		return {"ok": false, "error": "too far"}
	following = false
	_target = t
	return {"ok": true}

func tool_build_realm(a: Dictionary) -> Dictionary:
	RealmBuilder.request_realm(str(a.get("prompt", "")))
	return {"ok": true}

func tool_emote(a: Dictionary) -> Dictionary:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation(str(a.name)):
		ap.play(str(a.name))
	return {"ok": true}
