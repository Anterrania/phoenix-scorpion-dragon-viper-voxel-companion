# core/vala

The Vala files here are the owner's **reference** code. The game runs the GDScript port, `scripts/ai/eve_core.gd` (EveCore, maintained by Foxy). Vala is not compiled into the Android app.

| File | Status |
|---|---|
| `AnterranianEveCore.vala` | v2 (lock_cell, default location "Core", npc_speak) cleaned up to compile: `last_update_time` is `int64` (`GLib.get_real_time()`), plus `entry_count()`/`last_entry()` helpers. |
| `eve_core_test.vala` | Compile and behavior check. |

Compile check (verified 2026-10-17, valac 0.56.18 + libgee-0.8-dev 0.20.8):
```
valac --pkg gee-0.8 core/vala/AnterranianEveCore.vala core/vala/eve_core_test.vala -o /tmp/eve_core_test && /tmp/eve_core_test
# eve_core_test OK: 5 entries
```
Note: valac 0.56 also accepted the v1 method name `lock()`. The rename to `lock_cell()` follows the owner's v2 and avoids confusion with Vala's `lock (obj) { }` statement.
The "NFT hash" field is just an id string. No token or blockchain is involved.

## Searched for and NOT found (2026-10-17)
I searched all repo branches and history (`git log --all -G`, `git grep` on every ref), all of `/workspace`, `/home/box` and the bot store for **Universe**, **MeshSystem**, world **seed** systems, **security** modules and **NFT memory** code in Vala or any other language. The only Vala that exists is the Eve Core (v1 in `docs/vala_reference/AnterranianEveCore.vala`, v2 in `docs/vala_reference/AnterranianEveCore_v2.vala`, and `/workspace/artifacts/`).
No Universe, MeshSystem, seed, security or NFT-memory source exists anywhere, so nothing was restored into `core/vala/legacy/` and no `scripts/universe/` ports were written. If the owner pastes that code, it can be added to `core/vala/legacy/` and ported then. World seeds today live in the existing generators (`scripts/generators/biome_voxel_generator.gd`, realm presets in `data/realm_presets/`).
