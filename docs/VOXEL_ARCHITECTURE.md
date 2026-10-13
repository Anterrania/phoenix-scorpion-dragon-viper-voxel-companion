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
`CharacterBody3D` runs a state machine (IDLE/FOLLOW/BUILD/DIG). `command()` is the entry point for LLM tool calls. Each companion loads `companions/<id>/persona.json`.

## Dual in-world + Grok Bot persona
One `persona.json` per companion (name, personality, appearance, abilities, memory paths, tools) seeds both the in-game agent and the standalone Grok Bot. Memory syncs through `memory_export.json` (facts/history/affinity). World-only tools are ignored by the chat bot.

## Android
GDExtension (arm64-v8a `.so`) + Godot's Gradle build, JDK 17, export templates that exactly match the editor version, Mobile renderer, ETC2/ASTC. See ANDROID_EXPORT.md.
