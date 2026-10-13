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

## Added 2026-10-13 (late morning)
- export_presets.cfg: Linux, Windows, macOS, Web (single-threaded), iOS (Xcode project only). Written by hand and never exported.
- export.yml DRAFT: Godot 4.7.2-stable + godot_voxel GDExtension v1.7x (versions checked against the releases; Dev Bot pins the final one), official Java/Android setup, debug keystore generation, and release keystore from secrets.
- PLATFORMS_TESTING.md: web threading/COOP-COEP problem, workarounds, voxel-on-web risk + fallback.
- Blocker for Dev Bot: project.godot still declares Godot 4.3, but the extension needs 4.5+.

## Added 2026-10-13 (midday)
- Concept art batch_01 (6 images) + docs/ART_BIBLE.md; new omni-worker utility companion (schema v3, registered). Images 02–05 are unassigned, awaiting user naming.

- Concept art batch_02 (2 rings + 4 royals), ART_BIBLE Regalia & Jewelry section, data/items/regalia.json stubs. Royals unassigned; motto spelling needs user confirmation.

- Primary motto "Anterrania". Royal wardrobe batch_03 + data/items/wardrobe.json (cosmetic only; boudoir set mature/hidden by default). 8 new named companions (Vex, Celestia Nyx, Aether-Weave Regent, Seraph Halcyon, elder council Ignatius/Vesperine Pyre, heir council Solarian/Lumira): names assigned by Foxy, user may rename. 19 companions are registered in total.

- Batch_04 royal assets: boudoir set II (mature/hidden), royal heels, boots (2 variants), royal SUV (vehicles.json + PHYSICS_RPG vehicles), two thrones (furniture.json) + modules/THRONE_ROOM.md.

## Next
1. Open in Godot 4 with godot_voxel and fix any parse errors.
2. Register PersonaRegistry as an autoload.
3. Authenticate gh, push branches, open PRs.
4. Add the missing export presets and a voxel-enabled Godot build for CI, then do an Android debug APK test on the Motorola.
5. Settle the exchange through the Ledger; add art for the role companions.

## Update: palette v2 + batch 05
- Final palette v2 (black/magenta/gold/platinum + glitter sparkle) documented in ART_BIBLE; applied as tags to all companion personas and all items.
- Stub `shaders/glitter_sparkle.gdshader` (untested; not run in Godot yet).
- Batch 05: heir thrones for Solarian and Lumira (Lumira inscription awaits user confirmation), Monarch and Foxy royal denim.

## Update: batch 06
- 14 designs: 5 wardrobe, 2 weapons (new weapons.json), 6 armor/uniforms (new armor.json), 1 signet band. Duplicates skipped.
- Weapons/armor have placeholder stats tied to PHYSICS_RPG; sidearms fictional, in-game only. All cosmetic/gameplay only, no real money.
- Motto spelling AETERNA now canonical everywhere.
