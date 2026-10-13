# Project Structure

```
project.godot                 Godot 4.3+ project, Mobile renderer, autoloads
export_presets.cfg            Android preset (arm64, API 26+). No keystore secrets.
scenes/
  main_world.tscn             VoxelTerrain + Player + 3 CompanionAgents + chat UI
  player.tscn                 First-person CharacterBody3D + VoxelViewer
  companion_agent.tscn        Reusable in-game AI companion body
scripts/
  world.gd                    Builds blocky voxel library, applies realm params
  player.gd                   WASD/mouse + touch joystick (left) / look (right)
  chat_ui.gd                  Text chat panel
  autoload/settings.gd        user://settings.cfg (endpoint, model, API key)
  autoload/agent_brain.gd     LLM calls, per-companion memory, tool dispatch
  autoload/realm_builder.gd   Prompt -> realm JSON, validation, presets, hot-reload
  agent/companion_agent.gd    Follow/idle behavior + tool_* implementations
  agent/companion_config.gd   CompanionConfig resource class
resources/characters/*.tres   One CompanionConfig per companion
companions/<id>/persona.json  Portable persona (shared with standalone chat bot)
companions/<id>/memory_export.json  Memory sync format template
data/schema/realm_params.schema.json
data/realm_presets/*.json     6 realm presets
docs/                         Design + setup docs, TASK_TRACKER.csv
```

Runtime data (never committed): `user://settings.cfg`, `user://memory/<id>.json`, `user://realm_overrides/*.json`.
