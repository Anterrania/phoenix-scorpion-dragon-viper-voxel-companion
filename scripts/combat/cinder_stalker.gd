class_name CinderStalker
extends Node3D
## v0.6 original PvE creature: a six-legged ember beetle-lizard that patrols the
## combat zone, chases the player inside it and bites. Respawns after defeat.

const MAX_HP := 40.0
const SPEED := 3.2
const CHASE := 5.0
const BITE := 8.0
var hp := MAX_HP
var home := Vector3.ZERO
var zone_radius := 25.0
var player: Node3D
var generator
var _wp := Vector3.ZERO
var _cool := 0.0
var _dead_t := 0.0
var _t := randf() * 10.0
var body: Node3D

func setup(h: Vector3, r: float, p: Node3D, g) -> void:
	home = h; zone_radius = r; player = p; generator = g
	name = "CinderStalker"
	add_to_group("creatures")
	body = Node3D.new()
	add_child(body)
	var K = PropKit
	K.part(body, K.sphere(0.6, 12), K.mat("#2a0c08", 0.3, 0.4, 0.4), Vector3(0, 0.6, 0), Vector3(1, 0.6, 1.6))
	K.part(body, K.sphere(0.35, 10), K.mat("#3a1008", 0.3, 0.4, 0.4), Vector3(0, 0.75, -0.95))
	for s in [-1.0, 1.0]:
		K.part(body, K.sphere(0.07, 6), K.mat("#ffcc22", 5.0), Vector3(s * 0.15, 0.85, -1.22))
		for i in 3:
			K.part(body, K.cone(0.03, 0.06, 0.7, 5), K.mat("#1a0806"), Vector3(s * 0.55, 0.35, -0.5 + i * 0.5), Vector3.ONE, Vector3(0, 0, s * 0.8))
	for i in 4:
		K.part(body, K.cone(0.0, 0.12, 0.45, 5), K.mat("#ff5a14", 2.5), Vector3(0, 1.0, -0.4 + i * 0.3))
	global_position = h
	_pick_wp()

func _pick_wp() -> void:
	var a := randf() * TAU
	_wp = home + Vector3(cos(a), 0, sin(a)) * randf() * zone_radius * 0.8

func alive() -> bool:
	return hp > 0.0

func hit(dmg: float) -> void:
	if not alive(): return
	hp -= dmg
	body.scale = Vector3.ONE * 1.15
	if hp <= 0.0:
		visible = false
		_dead_t = 15.0

func _process(delta: float) -> void:
	_t += delta
	if not alive():
		_dead_t -= delta
		if _dead_t <= 0.0:
			hp = MAX_HP; visible = true; global_position = home; _pick_wp()
		return
	body.scale = body.scale.lerp(Vector3.ONE, delta * 6.0)
	_cool -= delta
	var target := _wp
	var spd := SPEED
	var chasing := false
	if player and CombatZone.is_damage_enabled(player.global_position) and global_position.distance_to(player.global_position) < 14.0:
		target = player.global_position; spd = CHASE; chasing = true
	var to := target - global_position
	to.y = 0
	if to.length() > 1.6:
		var step := to.normalized() * spd * delta
		var np := global_position + step
		if Vector2(np.x - home.x, np.z - home.z).length() <= zone_radius:  # stay in zone
			global_position = np
		rotation.y = atan2(-to.x, -to.z)
	elif not chasing:
		_pick_wp()
	elif _cool <= 0.0 and player.has_method("take_combat_damage"):
		player.take_combat_damage(BITE)
		_cool = 1.2
	if generator:
		global_position.y = maxf(generator.height_f(global_position.x, global_position.z), generator.LAVA_LEVEL)
	body.position.y = absf(sin(_t * 10.0)) * 0.05
