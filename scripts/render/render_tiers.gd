class_name RenderTiers
extends RefCounted
## RND-1 world rendering knobs per device tier (docs/modules/RENDERING.md §3).
## Pure data + helpers, no scene access, so every value is unit-tested.
##
## Tier names match Foxy's AutoQuality autoload (scripts/render/auto_quality.gd, her file):
## "low", "med", "high", "ultra". "auto" is a MODE there, never an effective tier here.
## Each knob below is registered with AutoQuality.register_knob(id, setter, levels) by
## RenderPipeline; when AutoQuality is missing, the pipeline applies the same table itself.

const TIERS := ["low", "med", "high", "ultra"]
const FALLBACK_TIER := "med"   # sane mid default when AutoQuality is missing

## knob id -> {tier: value}. Keep every knob present for every tier (tests enforce it).
const KNOBS := {
	# --- voxel terrain (VoxelLodTerrain) ---
	"terrain.view_distance": {"low": 256, "med": 384, "high": 640, "ultra": 1024},
	"terrain.lod_count": {"low": 4, "med": 5, "high": 5, "ultra": 6},
	"terrain.lod_distance": {"low": 32.0, "med": 40.0, "high": 48.0, "ultra": 64.0},
	# Dithered cross-fade between LODs (terrain_triplanar_fade.gdshader). Off on low/med: it draws
	# both LODs for the fade and its `discard` disables early-Z on tile GPUs.
	"terrain.lod_fade": {"low": 0.0, "med": 0.0, "high": 0.25, "ultra": 0.3},
	"camera.far": {"low": 900.0, "med": 1300.0, "high": 2000.0, "ultra": 3000.0},
	# --- terrain shader ---
	"terrain.normal_strength": {"low": 0.6, "med": 0.9, "high": 1.0, "ultra": 1.2},
	"terrain.detail_far": {"low": 25.0, "med": 45.0, "high": 70.0, "ultra": 100.0},  # m; extra samples only nearer
	"terrain.curvature_ao": {"low": 0.0, "med": 0.6, "high": 0.8, "ultra": 1.0},
	"terrain.caustics": {"low": 0.0, "med": 1.0, "high": 1.0, "ultra": 1.0},
	# --- resolution / AA (tile GPUs resolve MSAA on-chip, so 2x is the cheap AA on phones) ---
	"view.render_scale": {"low": 0.7, "med": 0.8, "high": 0.9, "ultra": 1.0},
	"view.upscaler": {"low": "bilinear", "med": "fsr", "high": "fsr", "ultra": "bilinear"},
	"view.msaa": {"low": 0, "med": 2, "high": 2, "ultra": 4},
	# --- lighting (med keeps the v0.3 "no sun shadows" choice: shadows are the costliest pass) ---
	"light.shadows": {"low": false, "med": false, "high": true, "ultra": true},
	"light.shadow_splits": {"low": 1, "med": 1, "high": 2, "ultra": 4},
	"light.shadow_distance": {"low": 0.0, "med": 0.0, "high": 60.0, "ultra": 110.0},
	"light.shadow_atlas": {"low": 1024, "med": 1024, "high": 2048, "ultra": 4096},
	"env.glow": {"low": false, "med": true, "high": true, "ultra": true},
	# --- sky ---
	"sky.cloud_octaves": {"low": 2, "med": 3, "high": 4, "ultra": 5},
	"sky.radiance": {"low": 32, "med": 64, "high": 64, "ultra": 128},
	"sky.incremental": {"low": true, "med": true, "high": false, "ultra": false},
	"sky.aurora": {"low": 0.0, "med": 1.0, "high": 1.0, "ultra": 1.0},
	# --- water ---
	"water.wave_subdiv": {"low": 48, "med": 96, "high": 160, "ultra": 220},
	"water.wave_quality": {"low": 0.0, "med": 1.0, "high": 1.0, "ultra": 1.0},
	"water.depth_fx": {"low": false, "med": false, "high": true, "ultra": true},
	# --- scatter / props / particles ---
	"foliage.density": {"low": 0.35, "med": 0.6, "high": 1.0, "ultra": 1.4},
	"foliage.range": {"low": 40.0, "med": 60.0, "high": 90.0, "ultra": 130.0},
	"props.range": {"low": 70.0, "med": 100.0, "high": 140.0, "ultra": 200.0},
	"particles.budget": {"low": 400, "med": 1200, "high": 2500, "ultra": 4000},
	"particles.emitter_cap": {"low": 150, "med": 450, "high": 900, "ultra": 1400},
}

static func is_tier(t: String) -> bool:
	return t in TIERS

static func sanitize(t: String) -> String:
	return t if is_tier(t) else FALLBACK_TIER

static func value(knob: String, tier: String) -> Variant:
	return KNOBS[knob][sanitize(tier)]

static func levels(knob: String) -> Dictionary:
	return KNOBS[knob]

static func knob_ids() -> Array:
	return KNOBS.keys()

## Legacy Settings graphics/quality (0 LOW, 1 MED, 2 HIGH) -> tier.
static func from_legacy(level: int) -> String:
	return ["low", "med", "high"][clampi(level, 0, 2)]

static func to_legacy(tier: String) -> int:
	return clampi(TIERS.find(sanitize(tier)), 0, 2)

## Effects the Mobile (Vulkan) renderer does not implement. Setting them is a silent no-op
## there, so the pipeline never enables them unless the project runs Forward+ (desktop).
const FORWARD_PLUS_ONLY := ["ssao", "ssr", "ssil", "sdfgi", "volumetric_fog", "taa", "fsr2"]

static func renderer_supports(feature: String, method: String) -> bool:
	if feature in FORWARD_PLUS_ONLY: return method == "forward_plus"
	if feature == "compute": return method != "gl_compatibility"
	return true

## Upscaler name -> Viewport.Scaling3DMode. FSR 1 (spatial) runs on Mobile; FSR 2 needs Forward+.
## At scale 1.0 no upscaler is useful, so always bilinear (zero cost).
static func scaling_mode(name: String, scale: float, method: String) -> int:
	if scale >= 0.999: return Viewport.SCALING_3D_MODE_BILINEAR
	if name == "fsr2" and renderer_supports("fsr2", method): return Viewport.SCALING_3D_MODE_FSR2
	if name == "fsr" or name == "fsr2": return Viewport.SCALING_3D_MODE_FSR
	return Viewport.SCALING_3D_MODE_BILINEAR

static func msaa_mode(samples: int) -> int:
	match samples:
		2: return Viewport.MSAA_2X
		4: return Viewport.MSAA_4X
		8: return Viewport.MSAA_8X
	return Viewport.MSAA_DISABLED

static func shadow_mode(splits: int) -> int:
	match splits:
		2: return DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		4: return DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	return DirectionalLight3D.SHADOW_ORTHOGONAL

## Sky variant per biome / realm: 0 standard, 1 aurora (Alaskan realm), 2 deep starfield (Cosmic).
static func sky_variant(biome: int, realm_sky := "") -> int:
	match realm_sky:
		"aurora": return 1
		"cosmic", "starfield": return 2
		"standard": return 0
	return [1, 0, 2][clampi(biome, 0, 2)]
