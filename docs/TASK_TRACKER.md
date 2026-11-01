# Task Tracker
Status: ✅ done (written, untested) · 🔄 in progress · ⏳ todo · 🧊 future. The older `TASK_TRACKER.csv` is kept for history.

| ID | Phase | Task | Status |
|---|---|---|---|
| 0.1 | 0 | project.godot (Mobile renderer, landscape) | ✅ |
| 0.2 | 0 | scenes/main.tscn: VoxelTerrain, player, foxy_ani + circuit_nova | ✅ |
| 0.3 | 0 | biome_generator.gd (4 biomes) | ✅ |
| 0.4 | 0 | companion_agent.gd (persona load, state machine, VoxelTool) | ✅ |
| 0.5 | 0 | player_controller.gd (touch+keys, raycast dig/place) | ✅ |
| 0.6 | 0 | ai_provider.gd (Local + Grok only) + data_importer.gd (Copilot/Gemini/Meta import) | ✅ |
| 0.10 | 0 | Offline AI notes refreshed (PRI-4) | ✅ |
| 0.7 | 0 | Shared personas v2 (foxy_ani, circuit_nova, aaliyah) | ✅ |
| 0.8 | 0 | Architecture, Android, roadmap, module docs | ✅ |
| 0.9 | 0 | Push branch + open PR | ⏳ blocked: gh login |
| 1.1 | 1 | Install godot_voxel GDExtension, open project, fix errors | ⏳ |
| 1.2 | 1 | Build VoxelBlockyLibrary ids 0–9 | ⏳ |
| 1.3 | 1 | Verify player movement + dig/place | ⏳ |
| 2.1 | 2 | Chat UI → AIProvider → companion command() | ⏳ |
| 2.2a | 0 | Merge v1/v2 personas into short ids; Foxy Ani lead | ✅ |
| 2.2 | 2 | Memory save/load | ⏳ |
| 2.3 | 2 | Companion pathing | ⏳ |
| 3.1 | 3 | VoxelStreamSQLite per realm, save on pause | ⏳ |
| 3.2 | 3 | Realm switcher + VoxelInstancer decor | ⏳ |
| 4.1 | 4 | Android toolchain (JDK 17, SDK, templates) | ⏳ |
| 4.2 | 4 | First debug APK on device | ⏳ |
| 4.3 | 4 | Perf pass | ⏳ |
| 5.1 | 5 | llama.cpp GDExtension evaluation | 🧊 |
| 5.2 | 5 | Brain files + MobiGlass UI | 🧊 |
| 6.x | 6 | Needs, relationships, usable objects, particles | 🧊 |
| 7.x | 7 | DNA genetics | 🧊 |
| 8.x | 8 | Star map, city building, economy | 🧊 |
| 9.x | 9 | Cloud AI providers, social hooks, scripting | 🧊 |
| PRI-1 | 1 | Verify scaffold in voxel-enabled Godot | ⛔ blocked: needs Godot + godot_voxel install |
| PRI-5 | 0 | Future systems notes (docs/modules) | ✅ |
| PRI-6 | 0 | Android export pipeline plan (ANDROID_EXPORT.md) | ✅ |
| PRI-7 | 0 | Social hooks design (SOCIAL_HOOKS.md) | ✅ |
| 0.11 | 0 | Planned modules: data/backup, assets, issue tracking, community, admin tools | ✅ |
| 0.12 | 0 | COORDINATION.md (Dev Bot / Task Manager / Foxy Ani) | ✅ |
| S.1 | side | Music video concept (idea doc) | ✅ |
| 5.3 | 5 | Viper OS admin: tickets / wiki / SVN-style revisions / repo timeline (`docs/ADMIN_TRACKER.md`) | ✅ headless-tested |
| 5.4 | 5 | Kit components from UI_DESIGN_LANGUAGE §8: SwipePages, SegmentedPills, PillRow, PagedList, RingTimeline, Toast, HoldButton, SignupStepper | ✅ headless-tested |
| 5.5 | 5 | Local sign-up stepper (name → avatar → voice → realm) | ✅ headless-tested |
| 5.6 | 5 | §9 holographic nameplates + ember aura; §10 minimap/compass/HUD restyle | ⏳ after v0.10 |
| 5.7 | 5 | Admin perf check on device (glass budget, 60 fps) | ⏳ needs APK |
| V.1 | Viper | Integrate the user's Universe / MeshSystem / DNA Vala/C# code (not on the box yet; first once provided) | ⏳ blocked: source needed |
| V.2 | Viper | 3D OS shell (desktop-in-world, windows as glass panels) | 🧊 |
| V.3 | Viper | Server meshing across region servers (after Aurora-model grid G-phases) | 🧊 |
| V.4 | Viper | Interplanetary travel (star map + seamless realm transitions) | 🧊 |
| V.5 | Viper | Planetary destruction / large-scale voxel events | 🧊 |
| 5.8 | 5 | Owner PIN/passphrase (PBKDF2), session gate + 30-min auto-lock, encrypted saves + migration, audit hash chain, e-stop, Security panel, radial launcher (`docs/SECURITY.md`) | ✅ headless-tested, needs device test |
| SEC-FIX-1 | SEC | Retire unsalted legacy owner-code hash: PBKDF2 bootstrap only, refused once a PIN exists, legacy slots migrated (`docs/SECURITY_DEVICE_TEST_PLAN.md` F1) | ✅ headless-tested, needs device test |
| SEC-FIX-2 | SEC | LLM API key sealed in `secrets.bin`, one-time blanking of `settings.cfg` (F2) | ✅ headless-tested, needs device test |
| SEC-FIX-3 | SEC | E-stop file MAC under vault key, fail closed (F3) | ✅ headless-tested, needs device test |
| SEC-FIX-4 | SEC | arm64-only Android export, tests clean up after themselves (F4, F5) | ✅ |
| SEC-FIX-5 | SEC | First-run "Create owner PIN or passphrase" on a fresh install (no vault, no bootstrap, no owner data); confirmation required; refused if any vault file exists, even corrupted; logged to the admin timeline | ✅ headless-tested, needs device test |
| SEC-FIX-6 | SEC | Owner-upgrade PIN setup: pre-vault device with owner role, no vault file, no bootstrap gets the confirmed create flow, logged `security/owner_setup_upgrade`; legacy code refused after | ✅ headless-tested, needs device test |
| LIFE-1 | LIFE | Realm world seeds (gravity, atmosphere, temp, radiation, water, day, soil) + WorldEnv | ✅ headless-tested |
| LIFE-2 | LIFE | Tolerance genome, viability, spawn lists, non-sexual creature combine (old saves compatible) | ✅ headless-tested |
| LIFE-3 | LIFE | Survival vitals (Survival.vitals, vitals_changed), suits/habitats, SIR disease, vaccines, ecology on Dormancy + sim_tick_hz | ✅ headless-tested |
| LIFE-4 | LIFE | LivingGate: owner exemption only when unlocked, e-stop, per-estate survival on/off/softcore with realm defaults | ✅ headless-tested |
| LIFE-5 | LIFE | Governance: nations, laws, elections, embassies, borders, civic-credit taxes (Aethel Coin tax LEGAL REVIEW) | ✅ headless-tested |
| LIFE-6 | LIFE | Geology ores by realm/depth, recipe graph, blueprints w/ perms (AEC sales/payouts LEGAL REVIEW), Industry bridge | ✅ headless-tested |
| LIFE-7 | LIFE | Land: no object caps, render budgets, planet/region/chunk addressing, floating origin, SectorPager | ✅ headless-tested |
| LIFE-8 | LIFE | Foxy client: vitals HUD, suit, scanner, crafting, DNA, symptoms, gov screens, client floating origin (docs/specs/foxy/LIVING_WORLD_CLIENT.md) | ⏳ planned (Foxy) |
| REL-013-1 | v0.13 | Brain Cell core: lock (owner-only unlock), versioned append-only vault, hash-chained local ledger, recall, in-world scene snapshots, Foxy / no-personality presets (`docs/modules/BRAIN_V013.md`) | ✅ headless-tested, needs device test |
| REL-013-2 | v0.13 | Companion menu → Admin > Companions (owner only); main-menu rows commented out, redirect | ✅ headless-tested, needs device test |
| REL-013-3 | v0.13 | New icon set (launcher, adaptive fg/bg/monochrome, favicons), script-generated | ✅ headless-tested, needs device test |
| REL-013-4 | v0.13 | Creator Sparks: views, tips, 70% marketplace share; in-game only | ✅ headless-tested |
| REL-013-5 | v0.13 | Trac logging `docs/trac/` | ✅ |
| REL-013-6 | v0.13 | Ship v0.13.0-debug arm64 APK | ⏳ after merge |
| REL-013-7 | v0.13 | Voice: default-voice fallback on Android, pitch/rate/locale/voice settings | ✅ headless-tested, needs device test |
| REL-013-8 | v0.13 | Cinematic companion intro | ✅ headless-tested, needs device test |
| DEMO-1 | v0.13 | One build for everyone, no demo flavor | ✅ headless-tested |
| INT-NSFW | INT | Not built — blocked pending owner decision | ⛔ blocked |
