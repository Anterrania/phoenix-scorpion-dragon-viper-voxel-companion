# Server Architecture: the Aurora-Sim / OpenSim model, modernized

We follow the proven **Aurora-Sim / OpenSimulator grid architecture**: central **grid services** plus many **region servers**, with **Hypergrid** for linking grids together. On top of that we add Dual Universe-style seamless voxel worlds and Star Citizen-style polish and server meshing. This is a clean-room design. We use OpenSim/Aurora concepts (they're BSD-licensed) and copy no code into the client. An optional future interop bridge would keep the BSD notices.

## Topology
```
 Android/PC client (Godot)  ──login──►  Login Service ──► session + region handoff
        │  UDP/WebSocket (region protocol)                     │
        ▼                                                     ▼
 Region Servers (headless Godot "sims")  ◄──── Grid Services (HTTP/gRPC, ROBUST-style)
  - one per 256 m region / voxel chunk set      Asset · Inventory · Avatar · Grid/Region
  - physics, scripts, AI companions, NPCs       Presence · Auth/Accounts · Friends · Groups
  - neighbours + border crossing                Currency/Economy · Land/Estate · Search
  - later: server meshing (dynamic split)       Marketplace · Exchange · Moderation · Media
                         ▲
                         └── Hypergrid gateway (inter-grid TP, foreign-asset fetch)
```

## Aurora-Sim / OpenSim service → our component
| Aurora-Sim / OpenSim | What it does | Ours (planned name) | Status in client today |
|---|---|---|---|
| ROBUST server / Aurora.Server | Hosts the grid services | **Anterrania Grid** (`grid-core`) | none (server phase 0.8+) |
| LoginService (LLLoginService) | Auth, session, start location | **LoginService** | local profile (`Profile` autoload) |
| UserAccountService / AuthenticationService | Accounts, passwords, tokens | **AccountService** (+ owner/admin roles) | owner/guest role, local code |
| AvatarService (appearance) | Saved appearance, wearables | **AvatarService** (`anterrania.avatar.v1` JSON: DNA + attachments) | ✔ local avatar file |
| AssetService (+ FSAssets) | Content-addressed blobs (mesh, textures, sounds) | **AssetService** (sha256-addressed glTF/PNG/OGG, CDN) | ✔ sha256 on .glb import |
| InventoryService (XInventory) | Folders/items per user, perms | **InventoryService** (Satchel) | ✔ local Satchel/wardrobe |
| GridService | Region registry, map, coordinates | **GridService** (256 m regions → planets → star systems) | ✔ region grid on map/status bar |
| GridUserService / PresenceService | Who's online, last position | **PresenceService** | radar (companions/creatures) |
| FriendsService / Instant Messaging | Friends, IM, offline IM | **SocialService** | — |
| GroupsService (Aurora Groups) | Groups, roles, land deeding | **GroupService** (factions/RP) | data model |
| Currency module (Aurora/third-party, e.g. "money server") | L$ balance, transfers | **EconomyService** (Aethel Coin ledger) | local wallet |
| LindeX-style exchange (3rd-party on OpenSim) | Currency market | **ExchangeService (AEX)** ⚠ compliance review | data model |
| Land/Parcel + EstateService | Parcels, estates, covenants, bans | **LandService + EstateService** (parcel→region→planet→system) | data model |
| Search / Directory (Aurora search) | Places, events, classifieds | **SearchService** | landmark search on map |
| Map tile service (MapImageService) | World map tiles | **MapTileService** | ✔ client-baked map |
| Media / parcel media | Music/video URLs | **MediaService** (SoundCloud, parcel music) | ✔ Phoenix Radio |
| Simulation region (OpenSim.exe / Aurora region) | Physics, scripts, objects | **Region Server** (headless Godot + voxel terrain) | client sims locally |
| Physics engine (ODE/BulletSim/ubODE) | Collisions | Godot Jolt/GodotPhysics | ✔ |
| Scripting (XEngine / YEngine, LSL/OSSL) | In-world scripts | **ScriptEngine** (sandboxed GDScript-lite / Lua, LSL-like API) | — |
| NPC module (OSSL osNpc*) | Bots/NPCs | **CompanionService** (LLM agents, persistent autonomy) | ✔ local autonomy |
| Hypergrid (HG 2.0, gatekeeper, HG inventory) | Inter-grid TP + assets | **HypergridGateway** | — |
| Aurora "IWC" / region linking | Cross-grid comms | Federation API | — |
| Marketplace (SL; 3rd-party on OpenSim) | Store + delivery | **MarketplaceService** + merchant outbox | local draft listings |

## Modernization (Dual Universe / Star Citizen)
- **Voxels instead of prims:** regions hold voxel chunks and Forge-Prim shapes. Edits replicate as chunk deltas.
- **Seamless planets:** regions tile spherical planets, with space-to-surface transitions and no loading screens.
- **Server meshing:** busy regions split dynamically, quiet ones merge. An entity authority handoff replaces SL-style hard border crossings.
- **Persistent simulation:** companions, breedables and creatures tick on region servers even while their owners are offline.
- **Modern transport:** QUIC or WebSocket region protocol, a CDN for assets, OAuth-style login, and gRPC between services.

## Region servers (simulators)
- **Process:** a headless Godot 4.7.2 export (`--headless`, server build) running the same `scripts/` as the client: voxel terrain (godot_voxel), physics, AgentBrain/BrainCore companions, NPCs, scripts.
- **Unit:** one region = a 256 m × 256 m column of voxel chunks (seeded by GridService, so terrain regenerates deterministically). Only edited chunks persist (`VoxelStreamSQLite` per region, backed up to AssetService).
- **Authority:** the region server owns physics, voxel edits, inventory transfers inside the region, companion ticks and brain-cell evaluation. Clients predict movement but the server is authoritative.
- **Neighbours:** each region knows its 8 neighbours (from GridService) and streams border chunks plus agents within ~32 m of a border. Crossing hands the avatar over: the old region sends state, the new one acks, then the client is told to switch.
- **Scale-out later:** server meshing splits a hot region into sub-authorities by entity, without hard borders (1.x).
- **Hosting:** container per region (Docker/K8s), 1 vCPU / 1–2 GB to start. Regions register with GridService at boot and send a heartbeat to PresenceService.

## Grid services layer (ROBUST-style, stateless HTTP/gRPC + Postgres/Redis/S3)
| Service | Owns | Key APIs (draft) | Notes |
|---|---|---|---|
| **Auth / Accounts** | accounts, roles (owner/admin/resident/guest), sessions | `POST /login`, `POST /token/refresh`, `GET /me` | OAuth2-style tokens; device-bound refresh; owner account is the one that approves brain/Eve proposals |
| **User / Profile** | display name, avatar ref, settings sync | `GET/PUT /users/{id}` | mirrors local `Profile` autoload |
| **Grid** | region registry, coordinates, seeds, map tiles | `GET /regions?x&y`, `POST /regions/register` | seed per region feeds the voxel generators (same as offline) |
| **Presence** | who is online, current region, last position | `PUT /presence`, `GET /presence/{id}` | Redis TTL keys |
| **Asset** | immutable content-addressed blobs (glTF, PNG, OGG, voxel chunk snapshots) | `PUT /assets/{sha256}`, `GET /assets/{sha256}` | S3/CDN; client cache keyed by sha256 (already used on .glb import) |
| **Inventory** | per-user folders/items, permissions (copy/mod/transfer) | `GET /inventory/{user}`, `POST /inventory/move` | Satchel/wardrobe sync |
| **Currency (Aethel Coin)** | double-entry ledger, balances, transfers, fees | `GET /wallet`, `POST /transfer` (idempotency key), `GET /ledger` | server-authoritative; the client never mints. Real-money purchase/exchange stays OFF until legal/compliance review (coordinate with Business Setup / Law bots) |
| **Land & Estates** | parcels, estates, covenants, access lists, ownership, rent | `GET /parcels?region`, `POST /parcels/{id}/buy` | parcel → region → planet → system hierarchy; estate managers per estate |
| **Groups / Social** | groups, roles, friends, IM | standard REST + WebSocket push | later phase |
| **Brain / Eve sync** | opt-in backup of `user://brains/<id>` + Eve logs, owner proposal queue | `PUT /brains/{companion}` (zip), `GET /proposals` | private by default and encrypted at rest; owner approval stays on the owner's device/account |

## Simulator ↔ viewer protocol (decision)
- **Chosen:** our own small protocol over **WebSocket (TLS) now, with QUIC/WebTransport later**, carrying binary messages (Godot `PackedByteArray` / MessagePack-style). We use Godot's `WebSocketMultiplayerPeer` for v1 because it works on Android, desktop and web with one code path, then move hot paths (movement, voxel deltas) to UDP/QUIC (ENet or a WebTransport GDExtension) once profiled.
- **Messages:** login handoff token → `region_join`; then `agent_update` (input + predicted pose, 10–20 Hz), `entity_snapshot` (server, delta-compressed), `voxel_delta` (chunk id + run-length edits), `chat`/`companion_say`, `inventory_op`, `land_op`, `currency_op` (forwarded to grid with an idempotency key).
- **Rejected:** the **LLUDP / Second Life viewer protocol**. It's large, prim-based and ties us to SL viewers, and our client is the Godot app. An optional **interop bridge** to OpenSim/Hypergrid can come later as a separate service (with BSD notices kept).
- **Assets:** never pushed over the region socket. Clients fetch by sha256 from AssetService/CDN.

## Offline single-player = "standalone" mode
OpenSim's *standalone* mode runs grid services in-process. We do the same:
- Today's app already **is** standalone. Region simulation runs in the client, and "services" are local autoloads: `Profile` (auth/user), `Inventory`, `RealmBuilder`/generators (grid + seeds), economy `ledger.gd` (currency), `estate.gd` (land), and `AgentBrain`/`BrainCore`/`EveCore` (companions + owner proposals).
- **Rule:** every gameplay call goes through a thin **service interface** (`LocalServices` now, `GridServices` later) with the same method names as the grid APIs above. Switching modes swaps the implementation, not the gameplay code.
- Offline stays first-class. No account is needed, and the local AI (rule-based + brain cells) works without network. Grok online is an optional upgrade.
- **Sync on connect (opt-in):** local inventory/avatar/brains upload as the user's starting state. Land and currency stay separate per grid (local coins are never converted into grid Aethel Coin).

## Migration path (standalone → grid)
1. **Interfaces first (no server):** wrap the existing autoloads behind `LocalServices` (`auth`, `inventory`, `asset`, `currency`, `land`, `presence`, `grid`) and add tests that call through the interface.
2. **Headless region:** run the existing project with `--headless` as a region server with a single region, then connect one client over WebSocket (movement + chat + voxel deltas).
3. **Minimal grid:** Auth + Grid + Presence + Asset services (one small HTTP service plus Postgres and S3-compatible storage). `GridServices` implements the interface. The client gets a "Connect to grid" toggle, with standalone as the default.
4. **Persistence:** Inventory and avatar services. Region chunk snapshots go to Asset, and the brain/Eve backup is opt-in.
5. **Economy & land:** Currency ledger (server-authoritative), parcels/estates, purchase flows. Legal review before any real-money feature.
6. **Many regions:** neighbours + crossings, map tiles, search, groups/social.
7. **Scale + federation:** server meshing, planets/star systems, Hypergrid-style gateway.

## Phases (detailed; maps to "Roadmap naming" below)
| Phase | Deliverable | Exit test |
|---|---|---|
| G0 (now) | Standalone app (local services), brain cells + owner proposals, Eve Core | ✅ suite passes headless (Godot 4.7.2 + voxel 1.7x) |
| G1 | `LocalServices` interface + tests; protocol message schema doc | gameplay code no longer calls autoloads directly for auth/inventory/currency/land |
| G2 | Headless region server + WebSocket client join (1 region, 2 clients) | two clients see each other move and edit voxels |
| G3 | Auth/Grid/Presence/Asset services (0.8 "Grid Core") | login → region handoff → asset fetch by sha256 |
| G4 | Inventory/Avatar + opt-in brain backup | inventory survives reinstall on a second device |
| G5 | Currency + Land/Estates (0.9 "Economy & Land") | ledger balances reconcile; parcel purchase is atomic |
| G6 | Multi-region + crossings + map (1.0 "Living Grid") | walk across 4 regions with no drop |
| G7 | Meshing + federation (1.x) | hot region splits under load test |

None of the server components exist yet. This is a plan. Costs, hosting provider and legal structure for currency are open questions (see `docs/PENDING_USER_QUESTIONS.md`).

## Roadmap naming (aligned)
- **0.8 "Grid Core":** LoginService, AccountService, AssetService, InventoryService, AvatarService, PresenceService, and one Region Server.
- **0.9 "Economy & Land":** EconomyService (Aethel Coin), LandService/EstateService, GroupService, upload fees, MarketplaceService.
- **1.0 "Living Grid":** multi-region GridService, persistent CompanionService, ScriptEngine, MediaService, SearchService.
- **1.x "Hypergrid & Meshing":** HypergridGateway, server meshing, planets and star systems, ExchangeService (after compliance review).
