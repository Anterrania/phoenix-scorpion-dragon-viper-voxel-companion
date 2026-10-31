# Server Meshing, Shards and Persistent Planets (concept)

> **Concept + simulation model.** `scripts/spacesim/shard_model.gd` simulates the layout and is headless-tested. Real region servers come with the grid phase in [ARCHITECTURE_AURORA_MODEL.md](../ARCHITECTURE_AURORA_MODEL.md). Concepts only, inspired by public space-sim talks. No other game's code or terms are used in-game.

## Why
Phoenix's long-term vision is the first 3D OS: persistent planets, travel between planets by any means, planetary war, and very large scale. The Aurora/OpenSim model gives us grid services and fixed 256 m regions. This doc says how fixed regions become **meshed authority** without hard borders.

## Layers
| Layer | What it holds | Lives in | Today |
|---|---|---|---|
| Universe | systems → planets (`data/frontier/planets.json`) | GridService | 1 system, 3 built planets, 2 planned |
| Persistent planet state | voxel chunk deltas, claims (Territory), parcels (Estate) | AssetService + LandService (global DB) | local files on the phone |
| Shard | one live copy of the universe: entities, physics, NPCs, companions | a pool of region servers | one shard "local" |
| Server | authority over territories: a planet or a quadtree cell "planet/q/q" | headless Godot sim | one server "srv1" |
| Instance | events, concerts, arenas on servers from the reserve pool | instance servers | modelled (`open_instance`) |

## Rules (as modelled in ShardModel)
- **Split:** a territory whose load passes `SPLIT_AT` (80%) of server capacity splits into 4 child cells. Child 0 stays, and children 1–3 go to fresh servers. The depth limit is `MAX_DEPTH` (4).
- **Merge:** four sibling cells whose combined load drops under `MERGE_AT` (30%) merge back onto one server. Empty servers are released.
- **Authority lookup:** the longest matching territory prefix wins (`server_of`).
- **Entities:** *unstowed* entities exist in one shard. *Stowed* ones live in the global DB and can unstow into any shard. `ShipRegistry.stow/deploy` already follows this rule, so a parked ship follows its owner to another shard.
- **Persistence:** planets never belong to a shard. Voxel edits and claims are global, so every shard sees the same terrain and the same owners.
- **Hand-off (grid phase):** entity authority transfers between servers (replacing SL-style border crossings). The old server streams state, the new one acks, and the client switches. That's the same handshake as the Aurora doc's neighbour crossing, applied per entity instead of per region.
- **Owner only:** adding shards or saving a layout needs `Tiers.can(actor, "admin")`.

## Mapping to the Aurora model
| Aurora/OpenSim piece | Meshed equivalent |
|---|---|
| Region server per 256 m region | server per territory cell (planet or quadtree cell), cells resize with load |
| Neighbour border crossing | per-entity authority hand-off |
| GridService region registry | territory → server map per shard (ShardModel layout) |
| PresenceService | players → shard + cell |
| Estate/Land services | global, shared by all shards (Estate + Territory) |

## Phases
1. **Now (standalone):** one shard, one server, everything local. The model runs in tests and in the Frontier → Overview card.
2. **Grid 0.8:** static meshing. Each planet gets its own server, and instances run on reserve servers.
3. **Grid 1.x:** dynamic split/merge from live load reports (`report_load`) and entity hand-off.
4. **Later:** cross-shard entity transfer for items, and fewer, bigger shards as capacity grows.

## Open questions for Phoenix
- Target players per shard for the first grid test?
- Should planetary war damage (voxel destruction) persist forever, or regrow on a timer per region?
