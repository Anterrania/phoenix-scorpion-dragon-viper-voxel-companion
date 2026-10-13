# Phoenix Scorpion Dragon Viper — Status (2026-10-13)
**Everything is scaffold/plan.** There is no live server, MySQL instance, Boonex Dolphin site, Trac/Jira server, or installable APK. Nothing has been run in Godot yet.

## Exists (scaffold)
- Godot 4 project with Zylann VoxelTerrain world scenes (`scenes/main.tscn`, `main_world.tscn`) and biome generator plus realm presets.
- Companions are CharacterBody3D using VoxelTool (`scripts/agent/companion_agent.gd`). Player dig/place also uses VoxelTool.
- Shared personas (schema v3) in `companions/{foxy_ani,circuit_nova,aaliyah}/persona.json`. Canonical ids (`foxy-ani-firecaster-grey`, `circuit-nova`, `aaliyah`) are mapped by `companions/registry.json` + `scripts/autoload/persona_registry.gd`.
- AI: Local + Grok providers. Importers are import-only (docs/IMPORTERS.md).
- Plan docs in `docs/modules/`: data/MySQL/backup, asset library, issue tracking + wiki, community platform (Boonex), Android admin, needs, star map, DNA, relationships, city building, MobiGlass, OpenSim/OAR, Second Life, offline-first, Sims/SimCity.

## Added 2026-10-13 (afternoon)
- Legacy v1 personas from the zip were merged into v3. Nothing new was needed; the earlier merge already had every field. Provenance is recorded per persona and in docs/PERSONA_IMPORT_LOG.md.
- 7 role companions (schema v3, registered): wellness-listener (non-clinical + crisis disclaimer), tutor, fitness-coach, storyteller, architect, explorer-guide, economy-advisor.
- Docs: PLATFORMS_TESTING, DEV_TEAM, modules/GRINDING_PROGRESSION, PHYSICS_RPG, MULTIPLAYER, ECONOMY_BANKING (virtual currency only; real money gated on Law Bot review).
- Stubs: scripts/economy/ledger.gd, currency_exchange.gd, scripts/progression/skill_by_use.gd.
- DRAFT CI: .github/workflows/export.yml (manual trigger; never run; only the Android preset exists).

## Next
1. Open in Godot 4 with godot_voxel and fix any parse errors.
2. Register PersonaRegistry as an autoload.
3. Authenticate gh, push branches, open PRs.
4. Add the missing export presets and a voxel-enabled Godot build for CI, then do an Android debug APK test on the Motorola.
5. Settle the exchange through the Ledger; add art for the role companions.
