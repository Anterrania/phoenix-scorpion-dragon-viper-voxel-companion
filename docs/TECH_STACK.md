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