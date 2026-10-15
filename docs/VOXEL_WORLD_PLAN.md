# Voxel World Plan

| Phase | Milestone | Done when |
|---|---|---|
| M0 | Scaffold (this PR) | Project opens in voxel-enabled Godot; terrain generates from tundra preset; player walks; companions follow |
| M1 | Playable terrain | Blocky library with 15 materials, dig/place by player tap, chunk view distance tuned for mid-range phones (≥30 fps) |
| M2 | Realms | All 6 presets switchable; RealmBuilder LLM path validated; structures auto-scattered from `structures[]`; per-biome sky/particles |
| M3 | Companion agents | Chat UI for each companion, tool calls building in-world, memory persists, export/import working |
| M4 | Art | Voxel character models (MagicaVoxel → .vox import), animations (idle, walk, dance, fire_cast), Aaliyah home base |
| M5 | Android release | Signed AAB, settings UI for endpoint/key, touch HUD, performance pass |
| M6 | Self-building | Approved hot-reload of presets/structures, saved worlds (VoxelStreamSQLite), sharing/export clips |

## Biomes
- **Alaskan tundra:** low rolling snow, aurora green accent, sparse huts.
- **Alaskan boreal:** spruce forests (instanced voxel trees), warm cabin light.
- **Alaskan glacier:** tall blue-ice ridges, arches, bright light.
- **Cosmic:** floating pillars, ring arches, starfield, dark sky.
- **Cyberpunk:** neon towers, aurora-and-fireworks stage.
- **Venus fire:** caldera, fire altars, ember fog.

## Performance targets
View distance 128 (low-end 96), max 12 tool edits per turn, edit radius ≤8, LOD terrain (`VoxelLodTerrain`) evaluated in M5.
