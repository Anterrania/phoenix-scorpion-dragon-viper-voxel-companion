extends CharacterBody3D
## First-person player. Keyboard/mouse on desktop; touch: left half = virtual
## joystick, right half = look drag. External UI can call set_move_vector().

@export var speed := 6.0
@export var jump_velocity := 5.5
@export var look_sensitivity := 0.004
@export var touch_look_sensitivity := 0.008
@export var joystick_radius := 120.0

signal health_changed(hp: float)
const MAX_HEALTH := 100.0
const PUSH_FORCE := 6.0
var health := MAX_HEALTH
var surface := 0  # SurfacePhysics.Surface

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
		for k in ["skin", "hair", "eyes", "outfit", "accent", "trim", "beard", "jacket", "top", "pants"]:
			if d.has(k): out[k] = Color(str(d[k]))
		if d.get("hair_streaks", []) is Array and not d["hair_streaks"].is_empty():
			var arr: Array = []
			for c in d["hair_streaks"]: arr.append(Color(str(c)))
			out["hair_streaks"] = arr
		out["crown"] = bool(d.get("crown", false))
		out["look"] = str(d.get("look", "royal"))
		out["glow"] = float(d.get("glow", 1.5))
		out["third_person"] = str(d.get("default_camera", "third_person")) == "third_person"
	return out

func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	floor_constant_speed = true
	var st := Profile.to_style(Profile.avatar())
	refresh_avatar()
	Profile.changed.connect(refresh_avatar)
	Inventory.equipped_changed.connect(func(t): if t == "player": refresh_avatar())
	set_third_person(st.get("third_person", true))

## v0.5: rebuild the avatar with wardrobe overrides.
func refresh_avatar() -> void:
	if avatar:
		remove_child(avatar)
		avatar.queue_free()
	avatar = HumanoidModel.build(Inventory.styled("player", Profile.to_style(Profile.avatar())))
	AvatarDNA.apply_all(avatar, Profile.avatar())  # DNA morphs, alpha masks, attachments
	avatar.name = "Avatar"
	avatar.position.y = -0.85
	avatar.visible = third_person
	add_child(avatar)

func set_third_person(on: bool) -> void:
	third_person = on
	camera.position = TP_CAM if on else FP_CAM
	if avatar: avatar.visible = on

func toggle_camera() -> void:
	set_third_person(not third_person)

func _process(delta: float) -> void:
	_anim_t += delta
	HumanoidModel.animate(avatar, _anim_t, clampf(Vector2(velocity.x, velocity.z).length() / speed, 0.0, 1.0))
	if health < MAX_HEALTH and surface != SurfacePhysics.Surface.LAVA:
		health = minf(health + delta * 4.0, MAX_HEALTH)
		health_changed.emit(health)
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

## v0.5.1 Second Life-style flying: toggle, up/down, hover in place when idle.
signal flying_changed(on: bool)
const FLY_SPEED := 14.0
const FLY_VERTICAL := 8.0
const FLY_CEILING := 600.0
var flying := false
var fly_vertical := 0.0   # -1 down .. 1 up (HUD buttons / keys)

func set_flying(on: bool) -> void:
	flying = on
	velocity.y = 2.0 if on else velocity.y
	flying_changed.emit(on)

func toggle_fly() -> void:
	set_flying(not flying)

func _fly_step(delta: float, dir: Vector3) -> void:
	var v := fly_vertical
	if Input.is_physical_key_pressed(KEY_E): v = 1.0
	if Input.is_physical_key_pressed(KEY_C): v = -1.0
	var target := dir * FLY_SPEED + Vector3.UP * v * FLY_VERTICAL
	velocity = velocity.lerp(target, clampf(delta * 4.0, 0.0, 1.0))  # smooth, hovers at 0
	if global_position.y > FLY_CEILING and velocity.y > 0.0: velocity.y = 0.0
	var g = _gen()
	if g:
		var floor_y: float = maxf(g.height_f(global_position.x, global_position.z), g.LAVA_LEVEL) + 1.0
		if global_position.y < floor_y:
			global_position.y = floor_y
			velocity.y = maxf(velocity.y, 0.0)
	var col := move_and_collide(velocity * delta)
	if col: velocity = velocity.slide(col.get_normal())

func _physics_process(delta: float) -> void:
	if flying:
		var fi := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if _touch_move != Vector2.ZERO: fi = _touch_move
		# Fly toward where the camera looks (pitch included), like SL.
		var cb := camera.global_transform.basis if camera else transform.basis
		_fly_step(delta, (cb * Vector3(fi.x, 0, fi.y)).normalized() if fi != Vector2.ZERO else Vector3.ZERO)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_move != Vector2.ZERO:
		input = _touch_move
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity = SurfacePhysics.steer(velocity, dir * speed, surface, delta)
	var r := SurfacePhysics.apply(_gen(), global_position, velocity, delta)
	surface = r.surface
	velocity = r.velocity
	global_position = r.position
	if r.damage > 0.0: take_damage(r.damage)
	move_and_slide()
	push_bodies(self, PUSH_FORCE)

## v0.4: shove RigidBody props we walk into.
static func push_bodies(body: CharacterBody3D, force: float) -> void:
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		var rb := c.get_collider() as RigidBody3D
		if rb:
			rb.freeze = false
			var n := -c.get_normal()
			n.y = 0.0
			rb.apply_central_impulse(n.normalized() * force / maxf(rb.mass, 1.0) * 4.0)

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	health_changed.emit(health)
	if health <= 0.0:  # respawn at the start, full health
		health = MAX_HEALTH
		global_position = Vector3(0, (_gen().height_f(0, 0) if _gen() else 40.0) + 2.0, 0)
		velocity = Vector3.ZERO
		health_changed.emit(health)

func _gen():
	var w := get_parent()
	return w.generator if w and "generator" in w else null
