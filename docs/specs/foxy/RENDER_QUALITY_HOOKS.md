# Spec for Foxy: render quality hooks (RND)

From the RND render pipeline (docs/modules/RENDERING.md). Nothing here edits your files.

## 1. AutoQuality (your autoload)
`RenderPipeline` looks for `/root/AutoQuality` with `register_knob(id, setter, levels)` and `get_tier()`
(optional `get_mode()`, signal `tier_changed(tier)`). It registers 29 knobs as `world.<id>` with levels for
`low/med/high/ultra` (table: `scripts/render/render_tiers.gd`).
- Please call each setter with the level for the new tier on tier change (we also apply `get_tier()` once).
- In "auto" mode our FrameGovernor trims render scale within the tier and emits
  `RenderPipeline.wants_lower_tier` when it sits at the floor for a full window. Please connect it and step
  down one tier (with your own hysteresis / cooldown).
- Without AutoQuality we fall back to Settings LOW/MED/HIGH, so either order of merge works.

## 2. Particles (patch)
`patches/weather_fx_particle_budget.patch` (scripts/fx/weather_fx.gd, touched on feature/v012-avatar):
emitters request from `ParticleBudget` and release on rebuild; biome lookup 4×/s instead of every frame
(audit item). Verified: applies to main, full suite passes with it applied. Club FX, spells and companion
embers should also `ParticleBudget.request("<id>", amount)`.

## 3. Avatar / character shading (spec only, your files)
- Keep character shaders free of `discard` except hair cards; hair alpha-scissor rather than blend on low/med.
- Skin: no SSS on Mobile; wrap lighting + rim term is enough. Give it a `quality` uniform so a
  `client.char_detail` knob can drop detail normals on low.
- Use `visibility_range_end` on companion accessories (~25 m) and the eye/eyelash meshes (~15 m).
- Avatar textures: VRAM compression patch is still open (+2.0 MB pack, about −31 MB GPU memory).

## 4. Client-side render items for you
Star map / flight HUD: use MultiMesh for star points; minimap patch (10 Hz) still pending.
