# Voxel World Plan

| Phase | Milestone | Done when |
|---|---|---|
| M0 | Scaffold (this PR) | Project opens in voxel-enabled Godot; terrain generates from tundra preset; player walks; companions follow |
| M1 | Playable terrain | Blocky library with 15 materials, dig/place by player tap, chunk view distance tuned for mid-range phones (≥30 fps) |
| M2 | Realms | All 6 presets switchable; RealmBuilder LLM path validated; structures auto-scattered from `structures[]`; per-biome sky/particles |
| M3 | Companion agents | Chat UI for each companion, tool calls building in-world, memory persists, export/import working |
| M4 | Art | Voxel character models (MagicaVoxel → .vox import), animations (idle, walk, dance, fire_cast), Aaliyah home base |
| M5 | Android release | Signed AAB, settings UI for endpoint/key, touch HUD, performance pass |
| M6 | Self-building | Approved hot-reload of presets/structures, saved worlds (VoxelStreamSQLite), sharing/export clips |

## Biomes
- **Alaskan tundra:** low rolling snow, aurora green accent, sparse huts.
- **Alaskan boreal:** spruce forests (instanced voxel trees), warm cabin light.
- **Alaskan glacier:** tall blue-ice ridges, arches, bright light.
- **Cosmic:** floating pillars, ring arches, starfield, dark sky.
- **Cyberpunk:** neon towers, aurora-and-fireworks stage.
- **Venus fire:** caldera, fire altars, ember fog.

## Performance targets
View distance 128 (low-end 96), max 12 tool edits per turn, edit radius ≤8, LOD terrain (`VoxelLodTerrain`) evaluated in M5.

## Heaven Welcome Island (HEAVEN-1..6): the default start realm for everyone
Full design: [docs/modules/HEAVEN.md](modules/HEAVEN.md). Client UI spec for Foxy: [docs/specs/foxy/HEAVEN_CLIENT.md](specs/foxy/HEAVEN_CLIENT.md).

Real-world scale, smooth voxel floating islands high above the ground world (y 470 to 1100, 720 m radius
centred on the origin), in the same VoxelLodTerrain (Transvoxel, LOD, voxel collisions). The Main Mall glass dome
is in the centre. 13 district islands ring it: the Transportation Hub (spawn) at the bottom of the map, then
Food Court, Gardens, Residential, Apartments, School, Office, Downtown, Casino (free play only), Theme Park, Beach,
Poolrooms and Warehouses. The Spirit Realm and The Beyond float higher and are reached by portals. Ring bridges,
floating roads to the Mall and glowing aqueduct waterways join them.

| Phase | What | Status |
|---|---|---|
| H1 | Layout data, island SDF terrain, district buildings, Hub spawn, Kelvin weather, Heaven ambience | **playable** (this PR) |
| H2 | Fly gate (owner + owner-granted members), studio gate, void catch, transit kiosks | **playable** (this PR) |
| H3 | Enterable shops (clothes, shoes, hair, looks, accessories): free house items + creator listings through MarketDelivery | **playable** (this PR); priced buys stay LEGAL REVIEW |
| H4 | Grids = realms: world picker (menu + Community shell), start-world setting (Heaven default) | **playable** (this PR) |
| H5 | **Built live:** data-driven district files + companion edits (EveCore proposals, owner approval or standing grant) streaming into the running world; in-world "Direct a change" | **playable** (this PR) |
| H5b | **Edits from chat (HEAVEN-9):** companions call `heaven_edit` from chat (live and on-device), always via owner approval unless they hold a build grant; companion undo; the companion reports back (CHAT-16) | **playable** |
| H6 | Vehicles on the floating roads, tram between Hub platforms (sbx_vehicles_driving) | planned |
| H7 | Upper floors + interiors per building type, apartments you can own (Land budgets) | planned |
| H8 | Companion flight-follow for granted companions; shoes/hair/glow style keys in the avatar model (Foxy) | planned |
| H9 | Spirit Realm / The Beyond content, events at the Mall plaza screen | planned |
| H10 | **Persistent Heaven server**: shared, multi-user Heaven; companions keep building 24/7 | planned |

**24/7 building needs a persistent server.** Phase 1 runs on the phone: companions build, and edits are approved and
applied, only while the app is open. They can't keep working while the owner is away. Building on around the clock,
with many visitors seeing the same Heaven, needs H10: a persistent server that runs the companions' build loop,
holds the edit log and streams changes to clients. The edit format (`user://heaven/edits.json`, ops add/set/remove
over the base district files) is meant to move to that server unchanged.

Performance: islands build one per frame (spawn island first), and small props sit in a separate "Detail" mesh
whose range follows `RenderPipeline.props_range` (RenderTiers). Far islands are a single low-poly impostor batch.
Rides animate from the absolute clock and sleep beyond `260 m × Dormancy.SLEEP_FACTOR`. All Heaven geometry is
about 100k triangles over 16 islands, in roughly 40 draw calls (5 shared materials per island batch).
