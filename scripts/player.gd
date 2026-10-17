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
	floor_snap_length = MovementModel.SNAP_LENGTH
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	floor_constant_speed = true
	var st := Profile.to_style(Profile.avatar())
	refresh_avatar()
	Profile.changed.connect(refresh_avatar)
	Profile.changed.connect(refresh_titler)
	refresh_titler.call_deferred()
	Inventory.equipped_changed.connect(func(t): if t == "player": refresh_avatar())
	set_third_person(st.get("third_person", true))

## v0.5: rebuild the avatar with wardrobe overrides.
func refresh_avatar() -> void:
	if avatar:
		remove_child(avatar)
		avatar.queue_free()
	var pst: Dictionary = Inventory.styled("player", Profile.to_style(Profile.avatar()))
	avatar = RealisticBody.build(RealisticBody.player_style(pst)) if RealisticBody.available() else HumanoidModel.build(pst)
	AvatarDNA.apply_all(avatar, Profile.avatar())  # DNA morphs, alpha masks, attachments
	avatar.name = "Avatar"
	avatar.position.y = -0.85
	avatar.visible = third_person
	add_child(avatar)

func set_third_person(on: bool) -> void:
	third_person = on
	camera.position = TP_CAM if on else FP_CAM
	if avatar: avatar.visible = on
	if titler: titler.visible = on and titler.text != ""

func toggle_camera() -> void:
	set_third_person(not third_person)

func _process(delta: float) -> void:
	_anim_t += delta
	var sp01 := clampf(Vector2(velocity.x, velocity.z).length() / speed, 0.0, 1.0)
	if avatar.has_meta("realistic"): RealisticBody.animate(avatar, _anim_t, sp01)
	else: HumanoidModel.animate(avatar, _anim_t, sp01)
	_pose_tick(delta)
	if health < MAX_HEALTH and surface != SurfacePhysics.Surface.LAVA:
		health = minf(health + delta * 4.0, MAX_HEALTH)
		health_changed.emit(health)
	if global_position.y < -80.0:  # fell through unloaded terrain
		global_position = Vector3(global_position.x, 45, global_position.z)
		velocity = Vector3.ZERO
## v0.8 controller state
var swimming := false
var knock := Vector3.ZERO
var _jump_state := {"coyote": 0.0, "buffer": 0.0}
var _jump_queued := false
func queue_jump() -> void: _jump_queued = true
## Push the player (creature hits, lava, explosions). Ragdoll-lite lean + slide.
func apply_knockback(from_dir: Vector3, force: float) -> void:
	var d := from_dir; d.y = 0.0
	knock += d.normalized() * force + Vector3.UP * force * 0.15
	velocity.y = maxf(velocity.y, force * 0.25)
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
	if on and Restrictions.is_restricted(Tiers.actor_id("self"), "fly"): return   # opt-in restriction (VIEWER-4)
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
	_combat_tick(delta)
	if flying:
		var fi := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if _touch_move != Vector2.ZERO: fi = _touch_move
		# Fly toward where the camera looks (pitch included), like SL.
		var cb := camera.global_transform.basis if camera else transform.basis
		_fly_step(delta, (cb * Vector3(fi.x, 0, fi.y)).normalized() if fi != Vector2.ZERO else Vector3.ZERO)
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_move != Vector2.ZERO:
		input = _touch_move
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var on_floor := is_on_floor()
	var jump_pressed := Input.is_action_just_pressed("jump") or _jump_queued
	_jump_queued = false
	# v0.8 swimming in starlight water: feet below sea level in Cosmic
	var g = _gen()
	swimming = g != null and surface == SurfacePhysics.Surface.WATER and global_position.y - 0.85 < float(g.LAVA_LEVEL) - 0.4
	if swimming:
		var cb := camera.global_transform.basis if camera else transform.basis
		velocity = MovementModel.swim(velocity, cb * Vector3(input.x, 0, input.y), Input.is_action_pressed("jump") or jump_pressed, delta)
	else:
		if not on_floor:
			velocity.y -= gravity * delta
		if MovementModel.jump_tick(_jump_state, on_floor, jump_pressed, delta):
			velocity.y = jump_velocity
			floor_snap_length = 0.0  # don't snap back down on takeoff
		elif on_floor:
			floor_snap_length = MovementModel.SNAP_LENGTH
		if surface == SurfacePhysics.Surface.ICE:
			velocity = SurfacePhysics.steer(velocity, dir * speed, surface, delta)
		else:
			velocity = MovementModel.horizontal(velocity, dir * speed * (0.55 if surface == SurfacePhysics.Surface.WATER else 1.0), on_floor, delta)
	var r := SurfacePhysics.apply(g, global_position, velocity, delta)
	surface = r.surface
	velocity = r.velocity
	global_position = r.position
	if r.damage > 0.0: take_damage(r.damage)
	# v0.8 ragdoll-lite knockback: impulse added on top, decays, avatar leans
	velocity += knock * delta * 8.0
	knock = MovementModel.decay_knock(knock, delta)
	if avatar:
		var t := MovementModel.tilt_for(global_transform.basis.inverse() * knock)
		avatar.rotation.x = lerpf(avatar.rotation.x, t.x, clampf(delta * 10.0, 0.0, 1.0))
		avatar.rotation.z = lerpf(avatar.rotation.z, t.y, clampf(delta * 10.0, 0.0, 1.0))
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
			rb.apply_central_impulse(n.normalized() * force * 0.25 * minf(rb.mass, 40.0))  # v0.8: heavy props resist

# ---------- v0.6 combat ----------
signal shield_changed(v: float)
const MAX_SHIELD := 50.0
const SHIELD_REGEN := 5.0
const MELEE_DAMAGE := 12.0
const MELEE_RANGE := 2.8
var shield := MAX_SHIELD
var _shield_delay := 0.0
var _melee_cd := 0.0
var _bolt_cd := 0.0

## Creature/PvP damage: only on damage-enabled land; shield absorbs first.
func take_combat_damage(amount: float) -> bool:
	if not CombatZone.is_damage_enabled(global_position): return false
	_shield_delay = 3.0
	var absorbed := minf(shield, amount)
	shield -= absorbed
	shield_changed.emit(shield)
	if amount - absorbed > 0.0: take_damage(amount - absorbed)
	return true

func melee_swipe() -> int:
	if _melee_cd > 0.0: return 0
	_melee_cd = 0.5
	set_pose("swipe", 0.35)
	var fwd := -global_transform.basis.z
	var hits := 0
	for c in get_tree().get_nodes_in_group("creatures"):
		var to: Vector3 = c.global_position - global_position
		if c.alive() and to.length() < MELEE_RANGE and fwd.dot(to.normalized()) > 0.3:
			c.hit(MELEE_DAMAGE); hits += 1
	return hits

func fire_bolt() -> Node3D:
	if _bolt_cd > 0.0: return null
	_bolt_cd = 0.8
	set_pose("cast", 0.4)
	var dir := -camera.global_transform.basis.z if camera else -global_transform.basis.z
	var b := FireBolt.new(dir)
	get_parent().add_child(b)
	b.global_position = global_position + Vector3(0, 0.6, 0) + dir * 1.0
	return b

func _combat_tick(delta: float) -> void:
	_melee_cd -= delta; _bolt_cd -= delta; _shield_delay -= delta
	if _shield_delay <= 0.0 and shield < MAX_SHIELD:
		shield = minf(MAX_SHIELD, shield + SHIELD_REGEN * delta)
		shield_changed.emit(shield)

# ---------- v0.6 roleplay: poses + titler ----------
const POSES := ["wave", "bow", "sit", "dance"]
var pose := ""
var _pose_t := 0.0
var titler: Label3D

func set_pose(p: String, dur := 4.0) -> void:
	pose = p
	_pose_t = dur

func _pose_tick(delta: float) -> void:
	if pose == "" or avatar == null: return
	_pose_t -= delta
	if _pose_t <= 0.0:
		pose = ""
		return
	var t := Time.get_ticks_msec() / 1000.0
	var torso := avatar.get_node_or_null("Hips/Torso") as Node3D
	var arm_r := avatar.get_node_or_null("Hips/Torso/ArmR") as Node3D
	var arm_l := avatar.get_node_or_null("Hips/Torso/ArmL") as Node3D
	match pose:
		"wave": if arm_r: arm_r.rotation = Vector3(0, 0, 2.6 + sin(t * 10.0) * 0.4)
		"bow": if torso: torso.rotation.x = -0.8
		"sit":
			avatar.position.y = -1.3
			for leg in ["Hips/LegL", "Hips/LegR"]:
				var n := avatar.get_node_or_null(leg) as Node3D
				if n: n.rotation.x = 1.5
		"dance":
			avatar.rotation.y = sin(t * 4.0) * 0.6
			if arm_r: arm_r.rotation.z = 2.4 + sin(t * 8.0) * 0.5
			if arm_l: arm_l.rotation.z = -2.4 - sin(t * 8.0) * 0.5
		"swipe": if arm_r: arm_r.rotation = Vector3(-1.4, 0, 0.6 + _pose_t * 4.0)
		"cast": if arm_r: arm_r.rotation.x = -1.6
	if _pose_t <= delta + 0.001:
		avatar.position.y = -0.85
		avatar.rotation.y = 0.0

func refresh_titler() -> void:
	if titler == null:
		titler = Label3D.new()
		titler.name = "Titler"
		titler.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		titler.position.y = 1.45
		titler.pixel_size = 0.004
		titler.font_size = 40
		titler.outline_size = 12
		titler.modulate = Color("#ffd04a")
		add_child(titler)
	titler.text = RoleplayProfile.titler_text()
	titler.visible = third_person and titler.text != ""

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	health_changed.emit(health)
	if health <= 0.0:  # respawn at the start, full health
		health = MAX_HEALTH
		shield = MAX_SHIELD
		global_position = Vector3(0, (_gen().height_f(0, 0) if _gen() else 40.0) + 2.0, 0)
		velocity = Vector3.ZERO
		health_changed.emit(health)

func _gen():
	var w := get_parent()
	return w.generator if w and "generator" in w else null
