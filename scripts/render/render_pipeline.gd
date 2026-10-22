class_name RenderPipeline
extends Node
## RND-1 world render pipeline: applies the RenderTiers knob table to the voxel world
## (terrain, terrain/water/sky shaders, sun, environment, viewport, foliage, props, particles).
##
## Quality source, in order:
##  1. Foxy's AutoQuality autoload (/root/AutoQuality, scripts/render/auto_quality.gd). Every
##     knob is registered with register_knob("world.<id>", setter, levels-by-tier); AutoQuality
##     owns the tier, the persisted preference (user://settings) and auto-detection, and calls
##     the setters. We also apply its current get_tier() once after registering (idempotent).
##  2. Fallback when AutoQuality is missing or lacks the API: the legacy Settings graphics
##     quality (LOW/MED/HIGH -> low/med/high), default MED = sane mid defaults.
## In AutoQuality "auto" mode a FrameGovernor trims render scale on sustained slow frames
## (thermal throttling shows up as frame time) and emits wants_lower_tier for AutoQuality.

signal applied(tier: String)
signal wants_lower_tier

const KNOB_PREFIX := "world."
const SHADER_TERRAIN := "res://shaders/terrain_triplanar.gdshader"
const SHADER_TERRAIN_FADE := "res://shaders/terrain_triplanar_fade.gdshader"
const SHADER_SEA := "res://shaders/lava_sea.gdshader"
const SHADER_SEA_DEPTH := "res://shaders/lava_sea_depth.gdshader"
const RADIANCE := {32: Sky.RADIANCE_SIZE_32, 64: Sky.RADIANCE_SIZE_64, 128: Sky.RADIANCE_SIZE_128, 256: Sky.RADIANCE_SIZE_256}

## Visibility range for streamed world props (read by world_content when it fills a cell).
static var props_range := 100.0

var world: Node          # scripts/world.gd instance (duck-typed so tests can pass a stub)
var aq: Node = null      # AutoQuality, if present
var tier := RenderTiers.FALLBACK_TIER
var values := {}         # knob id (no prefix) -> last applied value
var governor := FrameGovernor.new()
var base_scale := 0.8
var registered := false

static func find_auto_quality(tree: SceneTree) -> Node:
	var n: Object = null
	if Engine.has_singleton("AutoQuality"): n = Engine.get_singleton("AutoQuality")
	elif tree and tree.root: n = tree.root.get_node_or_null("AutoQuality")
	if n is Node and n.has_method("register_knob") and n.has_method("get_tier"): return n
	return null

static func method_name() -> String:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "mobile"))

func setup(w: Node, auto_quality: Node = null) -> void:
	world = w
	aq = auto_quality if auto_quality else find_auto_quality(get_tree() if is_inside_tree() else null)
	if aq:
		for id in RenderTiers.knob_ids():
			aq.register_knob(KNOB_PREFIX + id, _setter(id), RenderTiers.levels(id))
		registered = true
		if aq.has_signal("tier_changed"): aq.tier_changed.connect(_on_tier_changed)
		apply_tier(str(aq.get_tier()))
	else:
		apply_tier(RenderTiers.from_legacy(Settings.quality()))
		if not Settings.quality_changed.is_connected(_on_legacy_quality):
			Settings.quality_changed.connect(_on_legacy_quality)

func _setter(id: String) -> Callable:
	return func(v): set_knob(id, v)

func _on_tier_changed(t) -> void:
	tier = RenderTiers.sanitize(str(t))
	governor.reset()
	_apply_scale()

func _on_legacy_quality(level: int) -> void:
	if aq == null: apply_tier(RenderTiers.from_legacy(level))

func auto_mode() -> bool:
	return aq != null and aq.has_method("get_mode") and str(aq.get_mode()) == "auto"

## Applies every knob for a tier (used for the fallback path and once after registering).
func apply_tier(t: String) -> void:
	tier = RenderTiers.sanitize(t)
	governor.reset()
	for id in RenderTiers.knob_ids():
		set_knob(id, RenderTiers.value(id, tier))
	applied.emit(tier)

func _terrain() -> Node:
	return world.get("terrain") if world else null

func set_knob(id: String, v: Variant) -> void:
	values[id] = v
	if world == null: return
	var t := _terrain()
	var tmat: ShaderMaterial = world.get("terrain_mat")
	var smat: ShaderMaterial = world.get("sky_mat")
	var env_node: WorldEnvironment = world.get("env")
	var e: Environment = env_node.environment if env_node else null
	var sun: DirectionalLight3D = world.get("sun")
	var waves: MeshInstance3D = world.get("waves")
	var player: Node3D = world.get("player")
	match id:
		"terrain.view_distance":
			if t and "view_distance" in t: t.view_distance = int(v)
			if player:
				var vv := player.get_node_or_null("VoxelViewer")
				if vv: vv.view_distance = int(v)
		"terrain.lod_count":
			if t and "lod_count" in t: t.lod_count = int(v)
		"terrain.lod_distance":
			if t and "lod_distance" in t: t.lod_distance = float(v)
		"terrain.lod_fade":
			if t and "lod_fade_duration" in t: t.lod_fade_duration = float(v)
			# the discard-based fade lives in its own shader variant (early-Z stays on without it)
			if tmat: tmat.shader = load(SHADER_TERRAIN_FADE if float(v) > 0.0 else SHADER_TERRAIN)
		"camera.far":
			var cam := player.get_node_or_null("Head/Camera3D") as Camera3D if player else null
			if cam: cam.far = float(v)
		"terrain.normal_strength", "terrain.detail_far", "terrain.curvature_ao", "terrain.caustics":
			if tmat: tmat.set_shader_parameter(id.trim_prefix("terrain."), float(v))
		"view.render_scale":
			base_scale = float(v)
			_apply_scale()
		"view.upscaler":
			_apply_scale()
		"view.msaa":
			var vp := _viewport()
			if vp: vp.msaa_3d = RenderTiers.msaa_mode(int(v))
		"light.shadows":
			if sun: sun.shadow_enabled = bool(v)
		"light.shadow_splits":
			if sun: sun.directional_shadow_mode = RenderTiers.shadow_mode(int(v))
		"light.shadow_distance":
			if sun and float(v) > 0.0: sun.directional_shadow_max_distance = float(v)
		"light.shadow_atlas":
			if bool(values.get("light.shadows", false)):
				RenderingServer.directional_shadow_atlas_set_size(int(v), true)
		"env.glow":
			if e: e.glow_enabled = bool(v)
			# Forward+-only effects: real on desktop builds, never toggled on the Mobile renderer
			if e:
				var m := method_name()
				var hi := tier == "ultra" or tier == "high"
				e.ssao_enabled = hi and RenderTiers.renderer_supports("ssao", m)
				e.ssr_enabled = tier == "ultra" and RenderTiers.renderer_supports("ssr", m)
		"sky.cloud_octaves":
			if smat: smat.set_shader_parameter("cloud_octaves", int(v))
		"sky.aurora":
			if smat: smat.set_shader_parameter("aurora_strength", float(v))
		"sky.radiance":
			if e and e.sky: e.sky.radiance_size = RADIANCE.get(int(v), Sky.RADIANCE_SIZE_64)
		"sky.incremental":
			# the sky uses TIME (clouds, aurora), so its radiance re-bakes; incremental spreads
			# that over several frames instead of one hitch
			if e and e.sky: e.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL if bool(v) else Sky.PROCESS_MODE_AUTOMATIC
		"water.wave_subdiv":
			if waves:
				var pm := PlaneMesh.new()
				pm.size = Vector2(700, 700)
				pm.subdivide_width = int(v); pm.subdivide_depth = int(v)
				waves.mesh = pm
		"water.wave_quality":
			if waves and waves.material_override is ShaderMaterial:
				(waves.material_override as ShaderMaterial).set_shader_parameter("wave_quality", float(v))
		"water.depth_fx":
			if waves and waves.material_override is ShaderMaterial:
				(waves.material_override as ShaderMaterial).shader = load(SHADER_SEA_DEPTH if bool(v) else SHADER_SEA)
		"foliage.density":
			var f = world.get("foliage")
			if f: f.set_density(float(v))
		"foliage.range":
			var f2 = world.get("foliage")
			if f2: f2.set_view_range(float(v))
		"props.range":
			props_range = float(v)
			var wc := world.get_node_or_null("WorldContent") if world is Node else null
			if wc: apply_visibility(wc, props_range, true)
		"particles.budget":
			ParticleBudget.configure(int(v), ParticleBudget.emitter_cap)
		"particles.emitter_cap":
			ParticleBudget.configure(ParticleBudget.budget, int(v))

func _viewport() -> Viewport:
	return world.get_viewport() if world is Node and world.is_inside_tree() else null

func effective_scale() -> float:
	return clampf(base_scale * (governor.mult if auto_mode() else 1.0), 0.5, 1.0)

func _apply_scale() -> void:
	var vp := _viewport()
	if vp == null: return
	var s := effective_scale()
	vp.scaling_3d_scale = s
	vp.scaling_3d_mode = RenderTiers.scaling_mode(str(values.get("view.upscaler", "bilinear")), s, method_name())

## Sets a visibility range (distance cull, HLOD-style) on every GeometryInstance3D below
## `root`. With `cells_only`, only streamed scatter cells ("Cell_*" children) are touched, so
## landmarks and the club keep their full draw distance.
static func apply_visibility(root: Node, end: float, cells_only := false) -> int:
	var targets: Array = [root]
	if cells_only: targets = root.get_children().filter(func(c): return str(c.name).begins_with("Cell_"))
	var n := 0
	for t in targets:
		for g in t.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).visibility_range_end = end
			(g as GeometryInstance3D).visibility_range_end_margin = 6.0
			n += 1
	return n

func _process(delta: float) -> void:
	if not auto_mode(): return
	if governor.push(delta * 1000.0):
		_apply_scale()
		if governor.wants_lower_tier(): wants_lower_tier.emit()
