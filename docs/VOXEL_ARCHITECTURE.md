# Voxel Architecture

> Status: scaffold only. Nothing here has been opened or run in Godot yet. Requires **Zylann godot_voxel**. Use either a custom Godot build that includes the module, or the **GDExtension** release (1.x; check that its version matches your Godot 4.x minor) in `addons/zylann.voxel/`. The addon is **not** in this repo.

## Terrain nodes
- `VoxelTerrain`: blocky, editable, infinite terrain. This is the default in `scenes/main.tscn` with `VoxelMesherBlocky`.
- `VoxelLodTerrain`: smooth/LOD terrain for huge cosmic vistas later (Transvoxel mesher). Heavier on mobile.
- `VoxelViewer` on the player decides which chunks stream in. Keep `max_view_distance` around 96–128 on Android.

## Edits: VoxelTool
`terrain.get_voxel_tool()` gives you `do_point`, `do_sphere`, `do_box` and `raycast`. Set `mode` (ADD/REMOVE/SET), `value` and `channel` first. Players use raycast for tap-to-dig/place. Companions call the same tool from `scripts/companion_agent.gd`.

## Generators
`scripts/generators/biome_generator.gd` (`VoxelGeneratorScript`) has these branches: ALASKAN_SNOW_ICE, COSMIC, VENUS_FIRE and CYBERPUNK. It runs on worker threads, so keep it free of scene access. Later work: blend biomes by noise, or move to `VoxelGeneratorGraph` for speed. Realm presets live in `data/realm_presets/*.json`.

## Saving: VoxelStream
Add `VoxelStreamSQLite` (or `VoxelStreamRegionFiles`) at a `user://worlds/<realm>.sqlite` path. That saves only edited chunks, and the generator recreates everything else.

## Companion AI
**Lead:** Foxy Ani is the primary controller. Group commands route through her, and she delegates to Circuit Nova and Aaliyah (persona `hierarchy` field). A future `CompanionCoordinator` autoload will dispatch per-companion `command()` calls.

`CharacterBody3D` runs a state machine (IDLE/FOLLOW/BUILD/DIG). `command()` is the entry point for LLM tool calls. Each companion loads `companions/<id>/persona.json`.

## Dual in-world + Grok Bot persona
One `persona.json` per companion (name, personality, appearance, abilities, memory paths, tools) seeds both the in-game agent and the standalone Grok Bot. Memory syncs through `memory_export.json` (facts/history/affinity). World-only tools are ignored by the chat bot.

## Android
GDExtension (arm64-v8a `.so`) + Godot's Gradle build, JDK 17, export templates that exactly match the editor version, Mobile renderer, ETC2/ASTC. See ANDROID_EXPORT.md.

---
# Expanded Zylann godot_voxel API reference (for this project)
> Check these names against the docs for the godot_voxel version you install (https://voxel-tools.readthedocs.io). The API changes between releases. None of this has been run here yet.

## Terrain nodes
- **VoxelTerrain**: fixed-LOD, chunked, best for blocky edits. Key properties: `generator`, `mesher`, `stream`, `max_view_distance`, `generate_collisions`, `collision_layer`/`mask`, `bounds`. Signals: `block_loaded`, `block_unloaded`. Helpers: `get_voxel_tool()`, `voxel_to_data_block()`, `save_modified_blocks()`.
- **VoxelLodTerrain**: octree LOD for smooth (SDF) terrain over huge distances. Properties: `lod_count`, `lod_distance`, `mesher` (`VoxelMesherTransvoxel`), `full_load_mode_enabled`. Planned use is distant cosmic/planet vistas, not the main blocky play area.
- **VoxelViewer**: attach to the player (and optionally the camera for distant realms). It drives which chunks load. Has `view_distance`, `requires_collisions` and `requires_visuals`. Companions far from the player can carry their own viewer, but that costs memory.

## VoxelTool (from `terrain.get_voxel_tool()`)
- Settings: `channel` (TYPE for blocky, SDF for smooth), `mode` (MODE_ADD / MODE_REMOVE / MODE_SET / MODE_TEXTURE_PAINT), `value`, `sdf_scale`, `sdf_strength`.
- Edits: `do_point`, `do_sphere`, `do_box(begin, end)`, `do_path` (smooth), `paste` / `paste_masked` (copy a VoxelBuffer into the world, which blueprints will use), `copy`.
- Queries: `get_voxel`, `get_voxel_f`, `set_voxel`, `is_area_editable`, `raycast(origin, dir, max_distance, collision_mask)` → `VoxelRaycastResult` (`position`, `previous_position`, `distance`).
- Variants: `VoxelToolTerrain` (blocky; adds `run_blocky_random_tick` for growth/melt simulation), `VoxelToolLodTerrain` (smooth; adds `do_sphere` async, `stamp_sdf`), and `VoxelToolBuffer` (offline edits on a buffer).
- Used by `scripts/player_controller.gd` (raycast + do_point) and `scripts/companion_agent.gd` (do_point / do_sphere).

## Blocky library
- **VoxelMesherBlocky** + **VoxelBlockyLibrary** (newer versions: `VoxelBlockyLibrary` / `VoxelBlockyTypeLibrary`) list models in id order: 0 air, then stone, snow, ice, stardust, crystal, basalt, lava, concrete, neon. Ids must match the constants in `biome_generator.gd`.
- Model types: `VoxelBlockyModelCube` (atlas tiles), `VoxelBlockyModelMesh` (custom meshes such as slabs and plants), `VoxelBlockyModelEmpty` (air). Set `transparent` for ice and glass. Use emissive materials for lava and neon.

## Generators
- **VoxelGeneratorScript**: `_generate_block(out_buffer, origin, lod)` and `_get_used_channels_mask()`. Easy to write but slow-ish. It runs on threads, so no scene access.
- **VoxelGeneratorGraph**: a node graph compiled to fast native code, with SDF + blocky outputs. Planned for production biomes once the shapes are settled.
- Built-ins for prototyping: `VoxelGeneratorFlat`, `VoxelGeneratorNoise`, `VoxelGeneratorNoise2D`, `VoxelGeneratorWaves`.
- Noise: `FastNoiseLite` (Godot) or `ZN_FastNoiseLite` (bundled, faster with the graph).

## Streams (saving)
- **VoxelStreamSQLite**: one `.sqlite` file per realm (`database_path`). Good on mobile and the plan of record. Stores only modified blocks.
- **VoxelStreamRegionFiles**: a folder of region files, easy to inspect and diff.
- Call `terrain.save_modified_blocks()` on pause or quit (Android `NOTIFICATION_APPLICATION_PAUSED`).

## VoxelInstancer
- A child of the terrain that scatters many instances (grass, crystals, snow pines, neon lamps) on generated surfaces. Uses `VoxelInstanceLibrary` with per-item density, LOD and `persistent` (so player-removed items stay removed). Can also host scene instances for usable objects.

## Android notes
- Use the GDExtension build for the exact Godot 4.x version. The `.gdextension` file must list `android.arm64` (and optionally `android.x86_64` for emulators).
- Mobile renderer; `max_view_distance` around 96–128; collisions only near the player; limit threads (`ProjectSettings voxel/threads/*`) on low-end devices.
- Test on a real device. Emulators misrepresent GPU performance.

## Dual 3D + Grok Bot compatibility
- Single source of truth: `companions/<id>/persona.json` (+ brain folder, see modules/BRAIN_FILES.md).
- In-world agent = persona + world tools (VoxelTool) + needs/mood. Standalone Grok Bot = persona + chat-only tools.
- `memory_export.json` / zipped brain folder syncs both ways, merged by timestamp.
- Tool names are shared, so a plan made in chat ("build a fire altar") can replay in-game later.

## Offline / local AI path (refreshed)
Reasoning backends are **Local (default) and Grok (optional)**. Nothing else reasons.
1. **Rule-based local (now):** `LocalProvider` maps keyword intents to tool calls and persona lines. Works offline with no download.
2. **On-device LLM (Phase 5 evaluation):** a llama.cpp GDExtension (vet community Godot 4/Android arm64 bindings, or build our own) with a small Q4 GGUF model (~0.5–3B). The model downloads after install, not in the APK. Prompts come from brain cells (identity, values, top-k facts). Tool calls use grammar-constrained JSON. It runs on a worker thread with a timeout and falls back to rule-based when slow or out of memory. Expect a few tokens/sec on mid-range phones.
3. **Grok online (optional, Phase 9):** `GrokProvider` with a user-entered key. Richer replies on opt-in, plus brain sync with the standalone Grok Bot.
4. **Data importers (separate from reasoning):** `DataImporter` brings the user's own Copilot/Gemini/Meta AI exports into memory with consent and per-item review (modules/AI_INTEGRATIONS.md).
5. **Lead routing:** group requests go to Foxy Ani first. Her tool calls can include `delegate(companion_id, command)`.
