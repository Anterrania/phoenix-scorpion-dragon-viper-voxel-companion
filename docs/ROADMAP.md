# Roadmap

> **No APK exists yet.** Nothing has been run in Godot. Below is the realistic path to an **offline-capable, installable Android APK**.

## Phase 0: Scaffold ✅ (local branch `feature/godot-voxel-scaffold`)
Project, main scene, biome generator stub, player controller, companion agent, AI adapter stub, shared personas, docs.

## Phase 1: Runs on desktop (≈1–2 weeks)
- Pin a Godot 4.x version and install the matching godot_voxel GDExtension.
- Open the project, fix API drift and parse errors, create the VoxelBlockyLibrary (ids 0–9).
- Get player walk/jump/look and dig/place working with keyboard and mouse.

## Phase 2: Companions act (≈2 weeks)
- Follow/build/dig with basic pathing; chat UI → `AIProvider` (local rule-based) → `command()`.
- Memory saves to `user://memory`. Merge the v1 and v2 persona ids.

## Phase 3: Realms + saving (≈2 weeks)
- Four biomes tuned, VoxelStreamSQLite per realm, realm switcher, VoxelInstancer decorations.

## Phase 4: First installable APK (offline) (≈1–2 weeks)
- JDK 17, Android SDK, matching export templates, arm64-v8a, Gradle build (docs/ANDROID_EXPORT.md).
- Touch controls verified on a real device. Debug APK sideloaded with `adb install`.
- **Offline-capable at this point**, because the AI is rule-based and on-device and nothing needs the network.
- Performance pass: view distance, threads, particle budget.

## Phase 5: Smarter offline AI + UI
- Evaluate a llama.cpp GDExtension with a small GGUF model as an optional download. Benchmark tokens/sec on the target phone; if it's too slow, rule-based stays the default.
- Brain-file format (modules/BRAIN_FILES.md), MobiGlass UI, and multi-provider adapter shapes.

## Phase 6: Life sim layer
Needs, relationships (opt-in romance), usable objects, particles/VFX polish, balance pass.

## Phase 7: DNA / genetics avatars

## Phase 8: Star map, city building, economy

## Phase 9: Online extras (all optional and opt-in)
Cloud AI providers (Grok, Gemini, Azure/Copilot route, Meta Llama), standalone-bot brain sync, social hooks with user-approved posting, Smartbot-style automation and in-world scripting.

## Viper OS (long-term, after Phase 9)
Viper OS is the umbrella for the admin, tracker and later the in-world operating system. The first step already exists: the local admin (`docs/ADMIN_TRACKER.md`), with tickets, wiki, r-numbered revisions shared with brain cells, a repo timeline and local sign-up.
- **V0 (first, once the code is provided):** integrate the user's own Universe / MeshSystem / DNA code (Vala/C#). It is **not on the box or in the repo yet**. The cleaned `core/vala/AnterranianEveCore.vala` is the only Vala here so far.
- **V1 3D OS shell:** the admin and companion panels become glass windows in the world (§9/§10 of UI_DESIGN_LANGUAGE).
- **V2 Server meshing:** split regions dynamically across simulators, building on the Aurora-model grid (ARCHITECTURE_AURORA_MODEL.md, phases G0–G7).
- **V3 Interplanetary travel:** the star map plus seamless realm transitions (streaming VoxelLodTerrain planets).
- **V4 Planetary destruction:** large-scale voxel events, server-authoritative, with region rollback via snapshots.
All V-phases are future research. None of them exists yet.

## Release track
Signed release APK/AAB, privacy policy (AI + social data), Play Store listing. Any needed legal/business structure gets coordinated with the Business Setup and Law bots.
