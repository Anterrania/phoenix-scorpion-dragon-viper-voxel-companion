# Phoenix Scorpion Dragon Viper — Status (2026-10-13)
**Everything is scaffold/plan.** There is no live server, MySQL instance, Boonex Dolphin site, Trac/Jira server, or installable APK. Nothing has been run in Godot yet.

## Exists (scaffold)
- Godot 4 project with Zylann VoxelTerrain world scenes (`scenes/main.tscn`, `main_world.tscn`) and biome generator plus realm presets.
- Companions are CharacterBody3D using VoxelTool (`scripts/agent/companion_agent.gd`). Player dig/place also uses VoxelTool.
- Shared personas (schema v3) in `companions/{foxy_ani,circuit_nova,aaliyah}/persona.json`. Canonical ids (`foxy-ani-firecaster-grey`, `circuit-nova`, `aaliyah`) are mapped by `companions/registry.json` + `scripts/autoload/persona_registry.gd`.
- AI: Local + Grok providers. Importers are import-only (docs/IMPORTERS.md).
- Plan docs in `docs/modules/`: data/MySQL/backup, asset library, issue tracking + wiki, community platform (Boonex), Android admin, needs, star map, DNA, relationships, city building, MobiGlass, OpenSim/OAR, Second Life, offline-first, Sims/SimCity.

## Next
1. Open in Godot 4 with godot_voxel and fix any parse errors.
2. Register PersonaRegistry as an autoload.
3. Authenticate gh, push branches, open PRs.
4. Android export test build.
