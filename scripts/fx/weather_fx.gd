extends Node3D
## v0.8 ambient weather that follows the player: snowfall (Alaska), embers + ash
## (Venus), star dust (Cosmic), plus footstep dust. Wind gusts drive all particles.
## HEAVEN-3: inside Heaven airspace the biome effects are replaced by the Heaven weather state
## (heaven_fx: "" clear, "rain", "petals", "star_dust"), set by HeavenWorld from HeavenWeather.
var player: Node3D
var generator
var biome := -1
var effects: Array[GPUParticles3D] = []
var footsteps: GPUParticles3D
var _t := 0.0
const HEAVEN_FX := ["", "rain", "petals", "star_dust"]
const HEAVEN_KEY := 1000   # biome codes >= 1000 mean "Heaven weather <index>"
var heaven_fx := ""
var _budget_ids: Array[String] = []   # RND-6 grants held by the current effects

func _clear_effects() -> void:
	for id in _budget_ids: ParticleBudget.release(id)
	_budget_ids.clear()
	for e in effects: e.queue_free()
	effects.clear()

func _add_effect(k: String) -> void:
	var e := ParticleFX.make(k, Settings.quality())
	if e == null: return
	# RND-6: shared per-tier particle pool (scripts/render/particle_budget.gd)
	var id := "weather." + k
	e.amount = maxi(1, ParticleBudget.request(id, e.amount))
	_budget_ids.append(id)
	add_child(e); effects.append(e)

func setup(p: Node3D, gen) -> void:
	player = p; generator = gen
	Settings.quality_changed.connect(func(_q): rebuild())
	footsteps = ParticleFX.make("footstep_dust", Settings.quality())
	footsteps.amount = maxi(1, ParticleBudget.request("weather.footsteps", footsteps.amount))  # RND-6
	add_child(footsteps)

func rebuild() -> void:
	var b := biome
	biome = -1
	if b >= HEAVEN_KEY: set_heaven(HEAVEN_FX[b - HEAVEN_KEY])
	else: set_biome(b)

func set_heaven(fx: String) -> void:
	var k := HEAVEN_KEY + maxi(HEAVEN_FX.find(fx), 0)
	if k == biome: return
	biome = k
	_clear_effects()
	if fx != "": _add_effect(fx)

func set_biome(b: int) -> void:
	if b == biome: return
	biome = b
	_clear_effects()
	for k in ParticleFX.biome_effects(b): _add_effect(str(k))

## Wind/material updates and the biome lookup at most 10x/s; following the player stays per-frame.
var _redraw_acc := 0.0
func _process(delta: float) -> void:
	_t += delta
	_redraw_acc += delta
	var tick := _redraw_acc >= 0.1
	if tick:
		_redraw_acc = 0.0
		ParticleFX.wind = ParticleFX.wind_at(_t)
		for e in effects:
			var m := e.process_material as ParticleProcessMaterial
			if m: m.gravity = Vector3(0, m.gravity.y, 0) + ParticleFX.wind * (0.3 if e.name == "star_dust" else 1.0)
	if player == null: return
	global_position = player.global_position
	if not tick: pass   # biome/heaven lookup only on the 10 Hz tick (RND-6 / audit)
	elif HeavenLayout.contains(player.global_position): set_heaven(heaven_fx)
	elif generator: set_biome(int(generator.biome_at(player.global_position.x, player.global_position.z)))
	if footsteps and player is CharacterBody3D:
		var cb := player as CharacterBody3D
		footsteps.global_position = cb.global_position + Vector3(0, -0.85, 0)
		footsteps.emitting = cb.is_on_floor() and Vector2(cb.velocity.x, cb.velocity.z).length() > 2.0
