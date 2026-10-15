# Tech Stack & Agent Architecture

- **Engine:** Godot 4.3+, Mobile renderer, GDScript.
- **Voxels:** Zylann godot_voxel (`VoxelTerrain`, `VoxelMesherBlocky`, `VoxelGeneratorNoise2D`, `VoxelTool`). Requires the custom Godot build or GDExtension.
- **AI:** any OpenAI-compatible chat-completions endpoint with tool calling; a Grok/xAI endpoint (`https://api.x.ai/v1/chat/completions`) is configurable. Local LLM (godot-llm) is a later option.
- **Platform:** Android API 26+, arm64.

## Agent architecture
```
Player chat ─► CompanionAgent.talk() ─► AgentBrain.chat(id)
                                         │ system prompt = persona.json + memory facts + positions
                                         ▼
                                   LLM endpoint (HTTPRequest, key from Settings)
                                         │ content + tool_calls
                                         ▼
                  AgentBrain.dispatch_tool ─► CompanionAgent.tool_<name>() ─► VoxelTool on VoxelTerrain
                                         │
                                   memory saved to user://memory/<id>.json
```
- **CompanionAgent** (scene + script): body, follow/idle locomotion, tool implementations, voice hook.
- **CompanionConfig** (Resource): persona path + Godot-only look/movement.
- **AgentBrain** (autoload): HTTP, prompt assembly, memory load/save/export/import, tool allow-list per persona, max 12 tools per turn, range limits (64 voxels for edits).
- **RealmBuilder** (autoload): realm prompt → JSON validated against `data/schema/realm_params.schema.json`; preset fallback.
- **Settings** (autoload): `user://settings.cfg`.

## Dual compatibility
The same `persona.json` drives the in-game agent and the standalone chat bot. See BOT_INTEGRATION.md. World tools only work in-game.

## "Self-modification" — safe design
No root, exploits, or privilege escalation. "Self-modification" means:
- **Data/config hot-reload:** companions and the player can propose new realm presets, persona tweaks, or structures; they are written to `user://realm_overrides/` / `user://` only after the player approves in a confirmation dialog, then reloaded live.
- **Validation:** everything is JSON validated against schemas; no downloaded or LLM-generated code is executed.
- **Standard Android permissions only:** INTERNET, ACCESS_NETWORK_STATE, VIBRATE; RECORD_AUDIO only when voice is enabled (runtime prompt); media import through the system file picker (Storage Access Framework).
- **Kill switch (planned, M3):** Settings toggle disables all LLM tool execution.


---

## Earlier version (from main)

# Tech Stack & Implementation Plan

## Engine Choice: Godot 4.x
- Free, open-source, excellent Android export (GABE for on-device builds)
- Voxel Tools by Zylann: real-time editable terrains, infinite worlds, blocky + smooth
- Performance suitable for mobile with proper chunking and LOD

## AI Companion Layer
- Personality: Drawn from provided videos/images (goddess of fire, cosmic dancer, monarchy shining light)
- Memory: Persistent across sessions (local + optional cloud)
- World Building: AI generates voxel structures from natural language prompts (user or self)
- Integration options: godot-llm for local models, or API to Grok for advanced reasoning

## Android Specifics
- Target: Modern Android (API 26+)
- Permissions: Camera, storage for media import, optional for deeper companion features (within OS limits)
- Export: APK for sideload / testing, AAB for Play Store
- Performance: Voxel chunk streaming, low-poly companions + high-fidelity portraits for UI

## Immediate Next Implementation
1. Create basic Godot project folder structure
2. Add voxel terrain demo scene
3. Placeholder companion NPCs with dialogue
4. Prompt-to-voxel builder prototype
5. Character asset pipeline from generated/provided images

References:
- https://github.com/Zylann/godot_voxel
- Godot Android Build Environment (GABE)
- Prior research: security gaskets, authenticity, self-modification notes (fail-closed)