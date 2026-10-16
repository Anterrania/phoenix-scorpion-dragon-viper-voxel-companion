extends Node3D
## v0.8 ambient weather that follows the player: snowfall (Alaska), embers + ash
## (Venus), star dust (Cosmic), plus footstep dust. Wind gusts drive all particles.
var player: Node3D
var generator
var biome := -1
var effects: Array[GPUParticles3D] = []
var footsteps: GPUParticles3D
var _t := 0.0

func setup(p: Node3D, gen) -> void:
	player = p; generator = gen
	Settings.quality_changed.connect(func(_q): rebuild())
	footsteps = ParticleFX.make("footstep_dust", Settings.quality())
	add_child(footsteps)

func rebuild() -> void:
	var b := biome
	biome = -1
	set_biome(b)

func set_biome(b: int) -> void:
	if b == biome: return
	biome = b
	for e in effects: e.queue_free()
	effects.clear()
	for k in ParticleFX.biome_effects(b):
		var e := ParticleFX.make(k, Settings.quality())
		add_child(e); effects.append(e)

func _process(delta: float) -> void:
	_t += delta
	ParticleFX.wind = ParticleFX.wind_at(_t)
	for e in effects:
		var m := e.process_material as ParticleProcessMaterial
		if m: m.gravity = Vector3(0, m.gravity.y, 0) + ParticleFX.wind * (0.3 if e.name == "star_dust" else 1.0)
	if player == null: return
	global_position = player.global_position
	if generator: set_biome(int(generator.biome_at(player.global_position.x, player.global_position.z)))
	if footsteps and player is CharacterBody3D:
		var cb := player as CharacterBody3D
		footsteps.global_position = cb.global_position + Vector3(0, -0.85, 0)
		footsteps.emitting = cb.is_on_floor() and Vector2(cb.velocity.x, cb.velocity.z).length() > 2.0
