class_name DanceTimeline
extends RefCounted
## Choreography timeline driven by BeatDetector output. Moves land on beats; phrases of 8 beats
## repeat with variation (deterministic per seed, so every companion in a group dances in sync, or
## offset them for a canon). sample(t) -> {"move", "phase" 0..1, "beat"}; apply(model, t) poses the
## low-poly HumanoidModel (arms/legs/hips) or a RealisticBody skeleton (bone names from v0.11/v0.12).
## Live events: the owner approves a routine before it plays in public (MEDIA_BROADCAST.md §4).

const MOVES := ["step_l", "step_r", "sway", "arms_up", "clap", "spin", "bounce", "point"]
const PHRASE := 8

var bpm := 0.0
var beats: Array = []
var entries: Array = []      # [{"t": sec, "dur": sec, "move": String, "beat": int}]
var rng_seed := 1

static func from_analysis(a: Dictionary, seed_ := 1, moves: Array = MOVES) -> DanceTimeline:
	var d := DanceTimeline.new()
	d.bpm = float(a.get("bpm", 0.0)); d.beats = a.get("beats", []).duplicate(); d.rng_seed = seed_
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var phrase: Array = []
	for i in PHRASE: phrase.append(moves[rng.randi() % moves.size()])
	for i in d.beats.size():
		var dur: float = (d.beats[i + 1] - d.beats[i]) if i + 1 < d.beats.size() else (60.0 / maxf(d.bpm, 1.0))
		if i % (PHRASE * 4) == PHRASE * 4 - 1: phrase[rng.randi() % PHRASE] = moves[rng.randi() % moves.size()]  # vary every 4 phrases
		d.entries.append({"t": float(d.beats[i]), "dur": dur, "move": phrase[i % PHRASE], "beat": i})
	return d

## Entry index active at time t (binary search), -1 before the first beat.
func index_at(t: float) -> int:
	var lo := 0; var hi := entries.size() - 1; var ans := -1
	while lo <= hi:
		var mid := (lo + hi) / 2
		if float(entries[mid]["t"]) <= t: ans = mid; lo = mid + 1
		else: hi = mid - 1
	return ans

func sample(t: float) -> Dictionary:
	var i := index_at(t)
	if i < 0: return {"move": "idle", "phase": 0.0, "beat": -1}
	var e: Dictionary = entries[i]
	return {"move": e["move"], "phase": clampf((t - float(e["t"])) / maxf(float(e["dur"]), 0.001), 0.0, 1.0), "beat": i}

## Pose a model for time t. Returns the move applied.
func apply(model: Node3D, t: float) -> String:
	var s := sample(t)
	if model == null: return s["move"]
	var ph: float = s["phase"]
	var k := sin(ph * PI)            # 0 -> 1 -> 0 over the beat, ease in/out, no bounce overshoot
	var hips := model.get_node_or_null("Hips") as Node3D
	if hips and hips.get_node_or_null("Torso/ArmL"):
		var al := hips.get_node("Torso/ArmL") as Node3D; var ar := hips.get_node("Torso/ArmR") as Node3D
		var ll := hips.get_node("LegL") as Node3D; var lr := hips.get_node("LegR") as Node3D
		match s["move"]:
			"step_l": ll.rotation.x = -0.5 * k; hips.position.x = -0.05 * k
			"step_r": lr.rotation.x = -0.5 * k; hips.position.x = 0.05 * k
			"sway": hips.rotation.z = 0.12 * sin(ph * TAU)
			"arms_up": al.rotation.x = -2.6 * k; ar.rotation.x = -2.6 * k
			"clap": al.rotation = Vector3(-1.2 * k, 0, 0.9 * k); ar.rotation = Vector3(-1.2 * k, 0, -0.9 * k)
			"spin": hips.rotation.y = TAU * ph
			"bounce": hips.position.y = 0.9 + 0.06 * k
			"point": ar.rotation.x = -1.6 * k
	return s["move"]
