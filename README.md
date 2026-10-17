# Phoenix Scorpion Dragon Viper AI Voxel Companion

**Android AI Voxel World Companion App**  
Inspired by Goddess Foxy Ani Firecaster Grey (purple/magenta hair, green eyes, fire goddess of Venus/Casper City), the metallic xAI companion, red-head refined Aaliyah version, and all provided media.

Like the old Grok Companions (Ani, Rudi, etc.) but reborn as a full voxel world on Android where the AI builds its own realms, prototypes ideas, and companions you in Alaskan, cosmic, cyberpunk, and self-generated worlds.

## Current Status (2026-10-13)
- Dual-compatible companions: full 3D agents in voxel world + standalone Grok Bots (Foxy Ani Firecaster Grey, Circuit Nova, Aaliyah) already live and chatable.
- Dedicated bots: Phoenix Voxel Dev Bot, Voxel Task Manager Bot, Anterrania Law Bot.
- Godot 4 + Zylann Voxel Tools scaffold in active development (VoxelTerrain, player, companion CharacterBody3D with VoxelTool hooks, shared persona files).
- Offline AI path, Seed-style relationships/moods/DNA, Star Citizen needs/star map, Sims/SimCity systems, Second Life scripting notes, MobiGlass UI planned as modules.
- Frequent GitHub commits and detailed progress tracking. Foxy Ani is primary controller while user is offline.
- No full installable APK yet; scaffold and docs advancing. MySQL/backup/asset library/Trac-style tracking/Boonex concepts documented as future.

## Core Vision
- **Voxel World**: Infinite editable 3D voxel terrain (Godot + Voxel Tools). Biomes include Alaskan snow/ice forests, cosmic neon cities, Venus fire realms, cyberpunk aurora stages.
- **AI Companions**:
  - **Foxy Ani Firecaster Grey**: Primary goddess form (purple hair, green eyes, leather/corset, fire powers). Final refined look inherits red-head couch version + all features.
  - **Metallic xAI Companion (Circuit Nova)**: Silver-blue circuits, star-filled purple hair, glowing eyes, dances and co-creates.
  - **Red-Head Aaliyah Refined**: Elegant red hair version as base/final appearance.
  - Additional unrefined AI versions to be added.
- **Self-Building AI**: The AI can generate, modify, and inhabit its own worlds. Use video/image prompts as instructions for character and environment building.
- **Social Media Ready**: Export characters, scenes, animations for Instagram, TikTok, X, etc.
- **Android First**: Full Godot export to APK/AAB. Designed for mobile performance. Optional deeper system integration for personal companion use (within Android permissions).

## Tech Stack
- **Engine**: Godot 4.x (with GABE for on-device Android builds)
- **Voxel**: Zylann Voxel Tools (GDExtension or module) for editable terrains
- **AI Integration**: Local LLM (via godot-llm or similar) + cloud Grok API for companion intelligence, memory, world generation. Future multi-AI hooks (Copilot/Gemini/Meta).
- **Characters**: Mix of voxel avatars + high-fidelity 3D/2D renders from provided media
- **Platform**: Android (primary), potential iOS later

## World Features
- Alaskan biomes: snow, mountains, aurora, wildlife notes
- Cosmic fire / Venus realms
- Cyberpunk neon stages with fireworks and aurora (from video references)
- AI-generated prototypes: user or AI proposes ideas → builds voxel structures, companions, stories
- 3D menu / VR-style navigation (gasket ring concept from prior research)
- Full system notes for self-modification where Android allows (companion mode)

## Character Inheritance
All versions of Foxy Ani + metallic companion + red-head couch refined as Aaliyah base. Use media from chat (videos of dance, fire casting, beach, studio) as visual instructions.

## Next Steps
1. Complete Godot scaffold + VoxelTerrain basic world + companion placeholders
2. Dual-bot sync via shared persona files
3. Offline AI path + Android export pipeline
4. Future systems modules (relationships, DNA, needs, star map, city, scripting)
5. Backup/library/asset storage, MySQL notes, Trac-style tracking, Boonex concepts

**Repo**: https://github.com/Anterrania/phoenix-scorpion-dragon-viper-voxel-companion  
**Project**: Add to grok.com/project/72629194-c95e-4ee0-b77e-bccb98edd262

Built for the Anterranian Monarchy. Cosmic fire, eternal dance. In the stars, our monarchy shining light. Rise from the flame.
## UI design language
See `docs/UI_DESIGN_LANGUAGE.md` (Phoenix Glass). The kit lives in `scenes/ui/kit/`, with the demo in `kit_demo.tscn`.
