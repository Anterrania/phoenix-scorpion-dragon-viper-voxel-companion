# Rendering (RND): techniques, evaluation, measurements

Status: RND-1..RND-10, 2026-10-22. Branch feature/render-pipeline. Owner: us (world, terrain, generators,
world shaders, render pipeline). Client visuals (HUD, avatars/companions, character shaders, minimap,
flight HUD, star map, AutoQuality) are Foxy's: see docs/specs/foxy/RENDER_QUALITY_HOOKS.md.

All code here is self-written. Techniques come from public, general descriptions (greedy meshing,
triplanar mapping, Gerstner waves, ordered dithering); no engine or shader code was copied.

## 1. Renderer and constraints
- `project.godot`: `rendering_method="mobile"` (Vulkan Mobile renderer), ETC2/ASTC import on, MSAA 3D 2x.
- Mobile renderer facts that drive every verdict below: no SSAO, SSR, SSIL, SDFGI, VoxelGI-quality GI,
  volumetric fog, TAA or FSR 2 (all Forward+ only). FSR 1 (spatial) and MSAA work. Compute shaders are
  available (Vulkan), not on Compatibility/GLES3. `RenderTiers.renderer_supports()` encodes this, and the
  pipeline never turns on a Forward+-only effect on Mobile. (The old High preset set `ssr_enabled` and
  `ssao_enabled`; on Mobile those were silent no-ops. Removed and commented in world.gd.)
- Target: mid-range Android at 30–60 fps, arm64 only, APK growth ≤ ~1 MB.

## 2. Current techniques (after this branch)
- **Terrain:** VoxelLodTerrain + VoxelMesherTransvoxel (smooth SDF), mesh optimisation on, collision on
  LOD 0 only. SDF from `scripts/generators/smooth_terrain_generator.gd` (heightfield, ±4 m band).
- **Terrain shading:** triplanar PBR from one 256² noise texture + one procedural detail normal map, a
  baked 256² biome map, sub-biomes, glitter, snow sparkle, estate land textures. Shared body in
  `shaders/include/terrain_triplanar.gdshaderinc`; variants `terrain_triplanar.gdshader` (default) and
  `terrain_triplanar_fade.gdshader` (LOD cross-fade).
- **Water/lava/ice:** far flat plane + near subdivided Gerstner plane, one shared body
  `shaders/include/fluid_sea.gdshaderinc`; variants `lava_sea.gdshader` and `lava_sea_depth.gdshader`.
- **Sky:** procedural `cinematic_sky.gdshader` (gradient, Mie-ish sun halo, stars, ringed planet, moons,
  fbm clouds) + realm variants (aurora, deep starfield) and night star boost.
- **Atmosphere:** exponential depth fog + aerial perspective + height fog, ACES, glow, colour grading.
- **Quality:** `scripts/render/render_tiers.gd` (29 knobs × low/med/high/ultra) applied by
  `scripts/render/render_pipeline.gd`, registered with Foxy's AutoQuality via `register_knob`.

## 3. Quality pipeline (RND-1, RND-2)
- Knob ids are registered as `world.<id>` with `AutoQuality.register_knob(id, setter, levels_by_tier)`.
  AutoQuality owns the tier, the persisted preference, device auto-detect and the tier UI; our setters
  are idempotent and also applied once from `get_tier()` after registering.
- Fallback when AutoQuality is not present (e.g. main before v0.12): the legacy Settings LOW/MED/HIGH maps
  to low/med/high; default MED = sane mid defaults. "auto" is a mode, never an effective tier.
- **FrameGovernor** (`scripts/render/frame_governor.gd`, thermal-aware): in AutoQuality "auto" mode it
  watches the p90 frame time over 60-frame windows. Phones throttle when hot and that shows up as frame
  time (Godot has no portable thermal API), so frame time is the thermal signal. It trims render scale
  by 0.05 steps down to 0.75× of the tier's scale (drop fast, recover slowly) and emits
  `wants_lower_tier` when pinned at the floor so AutoQuality can step down a tier.
- Med tier changes vs the old MED preset: view 512 → 384 m, render scale 0.85 → 0.8 with FSR 1 upscale,
  MSAA 0 → 2x (tile GPUs resolve MSAA on-chip, so it is the cheapest real AA there).

## 4. Candidate evaluation

| Candidate | Verdict | Reason / what was done | Measured |
|---|---|---|---|
| Greedy meshing | **apply now** (blocky content only) | `scripts/render/greedy_mesher.gd` for player builds, voxel props and the inactive blocky path. **n.a. for smooth Transvoxel**: Transvoxel emits triangles along an SDF isosurface, not axis-aligned faces, so there is nothing to merge. | 32³ house-like build: 7,974 naive faces → 2,042 quads (−74%), 113 ms in GDScript (one-off per edit; native port later) |
| LOD tuning + transition blending | **apply now** (fade gated high/ultra) | `lod_distance` per tier (32/40/48/64 m), `lod_count` 4/5/5/6. Dithered cross-fade variant (`LOD_FADE`, godot_voxel `u_lod_fade`) only on high/ultra: it draws both LODs while fading and its `discard` defeats early-Z on tile GPUs. | Triangles per meshed 16³ block, LOD0..5: 283/286/320/322/271/386 (same before/after; transition meshes 0% in the bench window) |
| SDF generation | **apply now** | RND-3 band fill: only voxels within the ±4 m SDF band are written per voxel; air/rock above/below use `fill_area_f`. Output proven identical to the old loop by tests. | gen ms/block LOD0..5: 0.98/1.18/1.07/1.02/0.93/0.93 → 0.64/0.59/0.56/0.53/0.49/0.44 (−35…−53%) |
| Mesh optimisation | keep on | Transvoxel `mesh_optimization_enabled`. | off: 668 tris/0.09 ms → on: 283 tris/0.27 ms per block (−58% tris for +0.18 ms on worker threads) |
| Occlusion culling (OccluderInstance3D) | **later** | Godot occluders must be baked from static meshes; voxel terrain streams and is edited, so baking does not fit, and open terrain gives little occlusion. Revisit for landmarks/city interiors and caves (portal/cave heuristic: hide interior props when the camera is above the surface band). | — |
| Visibility ranges / HLOD | **apply now** | `visibility_range_end` + fade margin on streamed props (`props.range` 70/100/140/200 m) and foliage cells. HLOD for landmarks: later (needs merged proxy meshes). | Props beyond range skip the draw entirely |
| MultiMesh / GPU instancing | **apply now** (foliage) | `scripts/render/foliage_scatter.gd`: one MultiMeshInstance3D per biome per 48 m cell, deterministic pure placement, slope/water rejection, no shadows/collision/textures. VoxelInstancer: later (it binds to VoxelLodTerrain blocks and would replace our cell streamer; evaluate after on-device profiling). Crowds: later (skinned instancing not in Godot 4.7 core). | med: 25 cells × ≤156 instances = ≤3,900 tufts in ≤75 draw calls (vs ~3,900 as separate nodes) |
| Compute shaders | **later / not viable for now** | Vulkan Mobile supports them, but Compatibility fallback does not, godot_voxel already meshes on worker threads, and GPU readback of meshes would add latency. Candidate later: GPU erosion/weather maps. | — |
| SDF normals, triplanar, texture arrays | **apply now** (triplanar), later (arrays) | Triplanar already; finest octave skipped beyond `detail_far` (25/45/70/100 m) saves 3 samples/pixel far away; near normal sample likewise. Texture arrays: later, when real material textures arrive (procedural now = no texture files). | ~4 fewer texture fetches per far terrain pixel |
| Detail normal maps | **apply now** | Procedural detail normal map (no file), strength per tier 0.6/0.9/1.0/1.2. | 0 bytes added |
| Lighting / GI | **apply now** (cheap), **not viable on mobile** (SDFGI/VoxelGI) | Single directional light; shadows off on low/med, PSSM 2 splits 60 m on high, 4 splits 110 m on ultra, atlas 1024/2048/4096. Fake AO: curvature AO from screen-space derivatives in the terrain shader (0/0.6/0.8/1.0) + existing crevice AO. Sky ambient + reflections from a 32/64/128 radiance map, incremental update on low/med. SDFGI, VoxelGI, SSAO, SSIL: Forward+ only or too heavy. Light probes/baked GI: later (streamed terrain cannot be baked; possible for fixed interiors). | — |
| Fog, height fog | **apply now** (kept) | Exponential + aerial perspective + height fog. Volumetric fog is Forward+ only: not viable. | — |
| Water | **apply now** | All tiers: sky-gradient reflection from the reflected view ray (no textures). High/ultra `DEPTH_FX` variant: depth fade and shoreline foam from the depth buffer, fake caustics on submerged Cosmic ground (terrain shader, below `water_height`). Wave mesh subdivisions 48/96/160/220. Real SSR/planar reflections: not on Mobile / too costly. | — |
| Sky | **apply now** | Day/night star boost, aurora curtains (Alaskan realm), deep starfield + galactic band + nebula (Cosmic realm). Variant detail skipped in the radiance pass (`AT_CUBEMAP_PASS`) so ambient/reflections stay cheap. | — |
| GPU particles with budgets | **apply now** (budget), patch for Foxy's emitter | `scripts/render/particle_budget.gd`: one shared pool per tier (400/1200/2500/4000), per-emitter cap (150/450/900/1400). Weather hookup is a patch (her branch touches weather_fx.gd). | — |
| MSAA / FXAA / TAA | **apply now** | MSAA 0/2x/2x/4x. FXAA off (blurs UI-scale text in-world, little gain over MSAA on tile GPUs). TAA: Forward+ only. | — |
| FSR / render scale | **apply now** | Render scale 0.7/0.8/0.9/1.0, FSR 1 on med/high, bilinear at 1.0 or low. FSR 2: Forward+ only. Governor trims scale under load. | — |
| Shader precompilation / ubershader | **engine-provided + kept small** | Godot 4.4+ compiles pipelines in the background and uses ubershaders until specialised variants are ready, plus a pipeline cache. We keep variants to 2 terrain + 2 water + 1 sky and switch variants only on tier change. | — |
| ASTC/ETC2 | **already on** | `import_etc2_astc=true`. World shaders use procedural textures (no files). Avatar textures: Foxy's patch `avatar_textures_vram_compression.patch` (+2.0 MB pack, −31 MB GPU). | — |
| Frame pacing, thermal-aware quality | **apply now** | FrameGovernor (above). Frame pacing: Android swappy is engine-managed; we do not cap FPS ourselves (AutoQuality may). | — |

## 5. Measurements (headless, this box, 2026-10-22)
- Bench: `godot --headless --path . -s tools/render/mesh_bench.gd [-- --opt=0]` and
  `tools/render/greedy_bench.gd`. 24 blocks of 16³ per LOD, seed 1337. Numbers in §4.
- Draw calls: not obtainable headless (dummy renderer). Foliage draws are bounded by cells × biomes.
- **Export pack** (`--export-pack Android`): origin/main 1d4f15c **9,102,272** bytes → this branch
  **9,137,240** bytes (**+34,968 bytes, +0.38%**). Well under the 1 MB budget; no textures added.

## 6. Superseded code
Commented with notes, not deleted: the old `apply_quality` body in world.gd and the pre-RND-3 generator
loop (`_generate_block_reference`, kept for the equality test).
