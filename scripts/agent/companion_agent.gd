extends CharacterBody3D
## Reusable in-game AI companion. Configure with a CompanionConfig resource.
## Idle wander / follow behavior + tool implementations called by AgentBrain.

signal said(text: String)
const PlayerScript := preload("res://scripts/player.gd")

@export var config: CompanionConfig
@export var player_path: NodePath
@export var world_path: NodePath

var companion_id := ""
var persona := {}
var following := true
var _target: Variant = null   # Vector3 or null
var _idle_timer := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var model: Node3D
var _anim_t := randf() * 10.0
var _bubble: Label3D
var _bubble_time := 0.0
var _greet_cooldown := 0.0
var _was_near := false
const BUBBLE_SECONDS := 7.0

@onready var player: Node3D = get_node_or_null(player_path)
@onready var world: Node = get_node_or_null(world_path)

func _ready() -> void:
	if config == null:
		push_error("CompanionAgent needs a CompanionConfig")
		return
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(config.persona_path))
	persona = p if p is Dictionary else {}
	companion_id = persona.get("id", name)
	add_to_group("companions")
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	_apply_look()
	AgentBrain.register_agent(self)
	AgentBrain.reply_ready.connect(_on_reply)

func _exit_tree() -> void:
	AgentBrain.unregister_agent(self)

func _apply_look() -> void:
	var box := get_node_or_null("Body")
	if box: box.queue_free()
	model = HumanoidModel.build(config.style())
	add_child(model)
	model.position.y = -0.85  # capsule centre -> feet
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.text = persona.get("display_name", persona.get("name", name))
		label.position.y = 1.35
		label.modulate = config.accent_color.lightened(0.3)
		label.outline_size = 10
		label.font_size = 40
		label.pixel_size = 0.004
	_bubble = Label3D.new()
	_bubble.name = "ChatBubble"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position.y = 1.75
	_bubble.pixel_size = 0.0035
	_bubble.font_size = 36
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.06, 0.02, 0.08, 0.9)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.width = 520
	_bubble.no_depth_test = true
	_bubble.visible = false
	add_child(_bubble)
	get_tree().create_timer(1.5 + randf() * 2.5).timeout.connect(func(): show_bubble(greeting()))

## Greeting from persona.json (starter_message), falling back to name + role.
func greeting() -> String:
	var g := str(persona.get("starter_message", ""))
	return g if g != "" else "Hi, I'm %s." % persona.get("name", name)

func idle_line() -> String:
	var lines: Array = persona.get("game_lines", [])
	return str(lines[randi() % lines.size()]) if lines.size() > 0 else greeting()

func show_bubble(text: String) -> void:
	if _bubble == null: return
	_bubble.text = text
	_bubble.visible = true
	_bubble_time = BUBBLE_SECONDS

## World-space formation slot in front/side of the player (never behind).
func slot_position() -> Vector3:
	if player == null: return global_position
	return player.global_position + player.global_transform.basis * config.slot_offset

func _process(delta: float) -> void:
	_anim_t += delta
	var sp := Vector2(velocity.x, velocity.z).length() / maxf(config.move_speed, 0.1) if config else 0.0
	HumanoidModel.animate(model, _anim_t, clampf(sp, 0.0, 1.0))
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0: _bubble.visible = false
	_greet_cooldown -= delta
	if player:
		var near := global_position.distance_to(player.global_position) < 4.0
		if near and not _was_near and _greet_cooldown <= 0.0 and _bubble_time <= 0.0:
			show_bubble(idle_line())
			_greet_cooldown = 25.0
		_was_near = near

## Text chat entry point (UI calls this). Voice hook: feed STT text here.
func talk(text: String) -> void:
	AgentBrain.chat(companion_id, text)

func _on_reply(id: String, text: String) -> void:
	if id == companion_id and text != "":
		said.emit(text)
		show_bubble(text)
		speak(text)

## Voice hook: replace with TTS (DisplayServer.tts_speak or a cloud TTS).
func speak(text: String) -> void:
	if DisplayServer.tts_get_voices().size() > 0 and persona.get("voice", {}).get("tts_enabled", false):
		DisplayServer.tts_speak(text, DisplayServer.tts_get_voices()[0]["id"])

func get_player_position() -> Vector3:
	return player.global_position if player else Vector3.ZERO

func _physics_process(delta: float) -> void:
	if config == null: return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if player and (global_position.y < -64.0 or global_position.distance_to(player.global_position) > 48.0):
		global_position = slot_position() + Vector3.UP * 2.0  # catch-up teleport
		velocity = Vector3.ZERO
	var goal: Variant = _target
	if following and player:
		goal = slot_position()
	var moving := false
	if goal != null:
		var to: Vector3 = (goal as Vector3) - global_position
		to.y = 0
		if to.length() > config.follow_distance:
			moving = true
			var d := to.normalized()
			var spd := config.move_speed * clampf(to.length() / 3.0, 0.6, 1.8)
			velocity.x = d.x * spd
			velocity.z = d.z * spd
			_face(global_position + d, delta)
			if is_on_wall() and is_on_floor():
				velocity.y = 5.0  # hop up 1-voxel steps
		elif not following:
			_target = null
	if not moving:
		velocity.x = move_toward(velocity.x, 0, config.move_speed)
		velocity.z = move_toward(velocity.z, 0, config.move_speed)
		if player:
			_face(player.global_position, delta)
	# v0.4: separation steering - never overlap other companions or the player.
	var sep := SurfacePhysics.separation(global_position, neighbour_positions())
	velocity.x += sep.x
	velocity.z += sep.z
	var gen = world.generator if world and "generator" in world else null
	var r := SurfacePhysics.apply(gen, global_position, velocity, delta)
	if r.surface == SurfacePhysics.Surface.LAVA and following and player:
		r.velocity = Vector3(0, r.velocity.y, 0) + (player.global_position - global_position).normalized() * 6.0
	velocity = r.velocity
	global_position = r.position
	move_and_slide()
	PlayerScript.push_bodies(self, 3.0)

func neighbour_positions() -> Array:
	var out: Array = []
	if player: out.append(player.global_position)
	for a in get_tree().get_nodes_in_group("companions"):
		if a != self: out.append(a.global_position)
	return out

## Smoothly yaw toward a point (models face -Z like Godot's look_at).
func _face(p: Vector3, delta: float) -> void:
	var to := p - global_position
	to.y = 0
	if to.length() < 0.05: return
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))

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
