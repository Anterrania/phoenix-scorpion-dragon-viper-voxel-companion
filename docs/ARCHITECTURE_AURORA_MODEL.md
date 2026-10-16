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

## Roadmap naming (aligned)
- **0.8 "Grid Core":** LoginService, AccountService, AssetService, InventoryService, AvatarService, PresenceService, and one Region Server.
- **0.9 "Economy & Land":** EconomyService (Aethel Coin), LandService/EstateService, GroupService, upload fees, MarketplaceService.
- **1.0 "Living Grid":** multi-region GridService, persistent CompanionService, ScriptEngine, MediaService, SearchService.
- **1.x "Hypergrid & Meshing":** HypergridGateway, server meshing, planets and star systems, ExchangeService (after compliance review).
