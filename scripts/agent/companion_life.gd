class_name CompanionLife
extends Node
## v0.5 autonomous companion life: needs/goals loop that runs on its own when the
## companion is in FREE ROAM. Goals: explore, gather, build, travel (biome /
## landmark), rest, return when called. Keeps a memory log it can recite in chat.
## Later: server-side simulation so companions keep living while you're offline.

signal did(text: String)
const GOALS := ["explore", "gather", "build", "travel", "rest"]
var agent: Node3D
var goal := ""
var timer := 0.0
var energy := 1.0       # needs: energy drains while working, refills while resting
var curiosity := 0.6
var log_entries: Array = []
var built := 0
var gathered := {}

func _init(a: Node3D) -> void:
	agent = a
	name = "Life"

func free_roam() -> bool:
	return not agent.following and not AutonomyGuard.paused()   # e-stop pauses autonomy

func log_action(t: String) -> void:
	log_entries.append(t)
	if log_entries.size() > 30: log_entries.pop_front()
	did.emit(t)
	var ab := agent.get_node_or_null("/root/AgentBrain") if agent.is_inside_tree() else null
	if ab and ab._memory.has(agent.companion_id): ab.remember_fact(agent.companion_id, t)

func recap() -> String:
	if log_entries.is_empty(): return "Nothing yet - set me to Free roam and I'll go explore."
	return "Lately I " + "; ".join(PackedStringArray(log_entries.slice(-4))) + "."

## Utility AI: score each goal from needs, pick the best (with a little randomness).
func choose_goal(rng_val: float = randf()) -> String:
	if energy < 0.25: return "rest"
	var scores := {
		"explore": curiosity + rng_val * 0.3,
		"gather": 0.5 + (0.3 if gathered.size() < 2 else 0.0) + fmod(rng_val * 7.0, 0.3),
		"build": (0.9 if _total_gathered() >= 3 else 0.1),
		"travel": 0.35 + fmod(rng_val * 3.0, 0.4),
		"rest": 1.0 - energy,
	}
	var best := "explore"
	for g in scores:
		if scores[g] > scores[best]: best = g
	return best

func _total_gathered() -> int:
	var t := 0
	for k in gathered: t += int(gathered[k])
	return t

func _world():
	return agent.world

func _process(delta: float) -> void:
	if agent == null or not free_roam(): return
	timer -= delta
	if goal == "rest":
		energy = minf(1.0, energy + delta * 0.1)
	if timer > 0.0 and not (agent._target == null and goal in ["explore", "gather", "travel"]): return
	_finish(goal)
	goal = choose_goal()
	timer = randf_range(8.0, 16.0)
	_start(goal)

func _start(g: String) -> void:
	var p: Vector3 = agent.global_position
	match g:
		"explore":
			var a := randf() * TAU
			agent._target = p + Vector3(cos(a), 0, sin(a)) * randf_range(15.0, 35.0)
		"gather":
			agent._target = p + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
		"travel":
			var wc = _world().get_node_or_null("WorldContent") if _world() else null
			if wc and not wc.landmarks.is_empty():
				var l: Dictionary = wc.landmarks[randi() % wc.landmarks.size()]
				var lp: Vector3 = l["position"]
				if lp.distance_to(p) < 250.0:
					agent._target = lp + Vector3(randf_range(-8, 8), 0, 14)
					set_meta("dest", l["name"])
					return
			agent._target = p + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
			set_meta("dest", "the next ridge")
		"rest", "build":
			agent._target = null

func _finish(g: String) -> void:
	var gen = _world().generator if _world() and "generator" in _world() else null
	var biome := "the realm"
	if gen: biome = ["the Alaskan tundra", "the Venus wastes", "the Cosmic expanse"][gen.biome_at(agent.global_position.x, agent.global_position.z)]
	match g:
		"explore":
			energy -= 0.15; curiosity = maxf(0.2, curiosity - 0.1)
			log_action("explored %s" % biome)
		"gather":
			energy -= 0.1
			var item: String = ["crystal shard", "obsidian chunk", "aurora ice"][randi() % 3] if gen == null else ["aurora ice", "obsidian chunk", "crystal shard"][gen.biome_at(agent.global_position.x, agent.global_position.z)]
			gathered[item] = int(gathered.get(item, 0)) + 1
			log_action("gathered a %s" % item)
		"build":
			energy -= 0.2
			gathered.clear()
			var choice: String = AgentBrain.build_choice(agent.companion_id) if "companion_id" in agent else ""
			var bp: Vector3 = agent.global_position - agent.global_basis.z * 3.0
			if choice != "" and AgentBrain.dispatch_tool(agent.companion_id, "spawn_structure", {"name": choice, "x": bp.x, "y": bp.y, "z": bp.z}).get("ok", false):
				log_action("built a %s in %s (my own choice)" % [choice.replace("_", " "), biome])
			else:
				build_cairn()
				log_action("built a little crystal cairn in %s" % biome)
		"travel":
			energy -= 0.15; curiosity = minf(1.0, curiosity + 0.2)
			log_action("travelled to %s" % str(get_meta("dest", "somewhere new")))
		"rest":
			log_action("rested and recharged")

## Small structure built from smooth props (v0.6 will use real voxel building).
func build_cairn() -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := Node3D.new()
	n.name = "Cairn_%s_%d" % [agent.companion_id, built]
	for i in 3:
		var r := PropKit.rock(rng, "#5a5466")
		r.scale = Vector3.ONE * (0.8 - i * 0.2)
		r.position.y = i * 0.7
		n.add_child(r)
	var c := PropKit.crystal_cluster(rng)
	c.position.y = 2.0
	n.add_child(c)
	var parent: Node = _world() if _world() else agent.get_parent()
	if parent:
		parent.add_child(n)
		n.global_position = agent.global_position + agent.global_transform.basis.z * -1.5 + Vector3(0, -0.9, 0)
	built += 1
	return n
