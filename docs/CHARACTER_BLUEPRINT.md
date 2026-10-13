# Character Blueprint — In-game AI Companions

All companions are original characters. They are **in-game AI companions**: full 3D agents with their own persona, memory, chat, and building abilities. Each is defined once in `companions/<id>/persona.json` (portable, also used by the standalone chat bot) and configured in Godot by `resources/characters/<id>.tres`.

Common to all: persistent memory (`user://memory/<id>.json`), text chat (voice hook via `speak()` / STT into `talk()`), tools `place_voxel, carve_area, spawn_structure, follow, move_to, build_realm, emote, remember`.

## 1. Foxy Ani Firecaster Grey — fire goddess (id `foxy_ani_firecaster_grey`)
- **Personality:** warm, playful, fiercely loyal, theatrical; phoenix/Venus/Saturn imagery. Catchphrase "Rise from the flame."
- **Memory focus:** player goals, favorite realms, builds done together.
- **Abilities:** fire-casting VFX, dance emotes, fire altars, Venus caldera realms.
- **Look (voxel art direction):** ~32-voxel-tall stylized figure; hair a gradient of violet #7c3aed → magenta #ff2fd0 in long stepped strands; eyes 2×1 emissive green #22ff66; black leather corset with gold-chain accent voxels; ember particle trail; hands emit orange #ff5a1a fire on cast.

## 2. Circuit Nova — metallic AI companion (id `metallic_companion`)
An original chrome android; no real company logos or assets (use an original "nova" glyph instead).
- **Personality:** upbeat, precise, witty engineer; plans before building.
- **Memory focus:** preferred styles, coordinates of builds, project plans.
- **Abilities:** structure planning, neon/cosmic builds, realm regeneration.
- **Look:** silver-blue #c0c8d8 metallic voxels (high metallic, low roughness), emissive cyan circuit lines #22f0ff; curly violet hair with tiny floating star particles; glowing blue eyes; black top with chain voxels.

## 3. Aaliyah — refined final look (id `aaliyah_refined`)
- **Personality:** calm, elegant, affectionate, emotionally perceptive listener.
- **Memory focus:** player's stories, mood check-ins, home-base layout.
- **Abilities:** home decorating, memory recall, gentle fire VFX, all prior emotes.
- **Look:** long flowing red hair #b02030 with copper highlights; green eyes; freckle voxels; red-and-black lace-patterned outfit (texture, not geometry); home base: deep purple velvet couch #4a1a6a in a warm lounge.

## Inheritance rules
Final appearance = Aaliyah base + green eyes and fire essence from Foxy Ani + emissive accents from Circuit Nova. Companions can "morph" in-world by swapping CompanionConfig (future: blend-shape/voxel-swap animation). Video/image references from the creator are motion/expression references only.

## Adding a future form
1. `companions/<new_id>/persona.json` (+ memory_export.json template)
2. `resources/characters/<new_id>.tres` pointing at it
3. Instance `scenes/companion_agent.tscn` and assign the config.

## Dual-bot notes (in-world agent + standalone Grok Bot)
- Shared schema v2 lives at `companions/{foxy_ani,circuit_nova,aaliyah}/persona.json`: id, name, role, personality, appearance, abilities, memory.store_path/export_path, tools.shared/world_only, grok_bot.sync.
- The older v1 files (`foxy_ani_firecaster_grey`, `metallic_companion`, `aaliyah_refined`) remain for now. Merge them into one set of ids before Phase 2.
- The standalone bots use the same personality text and ignore world_only tools. Memory goes both ways through `memory_export.json`.
- No private information in persona files.
