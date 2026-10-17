# Virtual-world feature gap: Viper OS vs Aurora-Sim, WhiteCore, OpenSim, OSgrid, Second Life, Avination, OpenLife Grid

> Status: research + checklist, 2026-10-17. Ticket VWGAP-1. Companion docs: [modules/INTEROP.md](modules/INTEROP.md) (how to be cross-compatible), [ENCRYPTION.md](ENCRYPTION.md), [ARCHITECTURE_AURORA_MODEL.md](ARCHITECTURE_AURORA_MODEL.md).
> Marks: **have** = in code and tested headless · **partial** = data model or UI exists but not the whole feature · **missing** = nothing in code. Priority P0 (next) … P3 (someday). "Cross-compat" says how far we can honestly match the reference system.

## Sources (verified)
| Source | How it was read | Notes |
|---|---|---|
| Aurora-Sim | `git clone --depth 1 github.com/aurora-sim/Aurora-Sim` (archived, last push 2014-01-13) | module tree `Aurora/Modules/*`, `Aurora/Services/*`, `IOpenRegionSettingsModule.cs`; licence text in `AuroraDocs/LICENSE.txt` = OpenSim BSD-3 |
| WhiteCore-Sim | `git clone --depth 1 github.com/WhiteCoreSim/WhiteCore-Dev` (the `WhiteCore-Development` name in the brief doesn't exist; `WhiteCore-Dev` is the live repo, pushed 2026-05-18) | `LICENSE` = BSD 3-Clause; `Licenses/` keeps OpenSim + Aurora notices |
| OpenSimulator | `git clone --depth 1 github.com/opensim/opensim` (mirror of opensimulator.org git) | `LICENSE.txt` BSD-3; archive constants, terrain loaders, OSSL NPC API, RegionSettings, Services |
| opensimulator.org wiki | **unreachable from the box today** (WebFetch + curl timed out). Release list via search: 0.9.3.0 (2024-11-08), 0.9.3.1 in development | facts above taken from the source tree instead |
| OSgrid | osgrid.org + Hypergrid Business (Oct 2026) | OSgrid build 0.9.3.dev (2026-04-17, .NET 8); **OSgrid closes 2026-12-31** after junk-data flooding (asset store 5 → 17 TB). Residents are told to export OARs/IARs now |
| Second Life wiki | wiki.secondlife.com (`llGetParcelFlags` table used for our flag bits) | viewer code is LGPL: concepts only |
| Avination | web.archive.org snapshot of avination.com (2016), Hypergrid Business (2010, 2011, 2015, 2017, 2020), opensimulator.org Grid List entry (via search), SL Newser (2014) | the Avination wiki itself was **not recoverable** (no archive hits). Closed March 2017 |
| OpenLife Grid (3DX, "OLG") | Wikipedia, rip.so obituary, lokazionel.fr review, npirl.blogspot.com (2008) | the OLG wiki was **not recoverable** (archive 404). Closed 2013-11-18 as 3DMee. Documentation is thin, so the OLG section only lists what those sources state |

## 1. Regions, estates, parcels
| Feature | Reference | Viper OS evidence | Mark | Prio | Cross-compat |
|---|---|---|---|---|---|
| Region grid (256 m) | OpenSim GridService | `MapData.region_of/region_name`, map grid | have | – | coordinates only |
| Estate / region settings: water, sun, terrain texture | OpenSim RegionSettings | `Estate` REGION_DEFAULTS + Region/Estate panel | have | – | OAR settings import (preview) |
| Access lists, ban list, group-only | SL About Land › Access | `Estate.can_enter`, `Tiers._land_ok` | have | – | – |
| Parcels (64 m grid) | SL 4 m land grid | `Estate.parcel_id` | partial (fixed grid; no join/divide) | P2 | – |
| Parcel flags: fly, build, damage | SL PARCEL_FLAG_* | `allow_fly/allow_build/allow_damage` | partial: **stored, only build is enforced** (fly/damage not read by player code) | P1 | SL bits via `Estate.sl_parcel_flags` |
| Push, scripts, landmark, set-home, object entry, voice, local sound, show-in-search, maturity, agent limit, sandbox, resell, join/divide | SL + OpenSim RegionSettings | **new** optional keys in `Estate.REGION_DEFAULTS` (old saves read SL defaults) | partial (stored + UI toggles; landmark/set-home enforced by `Landmarks`) | P1 | bit mapping both ways (`flags_from_sl`) |
| Estate covenant | SL/OpenSim Covenant + CovenantChangedDateTime | **new** `Estate.set_covenant` (estate managers + owner), text box in Region/Estate | have | – | text only |
| Estate managers | SL/OpenSim | `Tiers` tier `estate_manager` | have | – | – |
| Land sale, auctions | SL land sale; Aurora `World/Auction` | – | missing | P2 | concept (legal review for money) |
| Rentals / tier (monthly land fee) | SL tier; grids rent regions | – (ad/rental carousels planned in BUILD_TOOLS_AND_TIERS) | missing | P2 | concept |
| Telehub / spawn point | OpenSim estate telehub | Welcome Island spawn | partial | P3 | – |
| Region restart, visitor log, banned viewers | Aurora `Restart`, `VisitorLogger`, `BannedViewersModule` | – | missing | P3 | server phase |

## 2. Grid services (ROBUST / Aurora data services)
| Service | Reference | Viper OS | Mark | Prio | Cross-compat |
|---|---|---|---|---|---|
| Asset (content-addressed) | AssetService / FSAssets | sha256 on .glb import (`Marketplace`) | partial | P1 | JSON API shaped like ROBUST `/assets` |
| Inventory | XInventory | `Inventory` (satchel/wardrobe) | partial | P1 | IAR import (notecards now) |
| Avatar appearance | AvatarService | `AvatarAppearance` (OpenSim wearables + attach points) | have (local) | – | see INTEROP §5 |
| Presence / GridUser | PresenceService / GridUserService | radar only | missing | P1 (G3) | API-shape |
| Friends | FriendsService | `Social.friend_*` | have (local) | – | – |
| IM + offline IM | Aurora `AuroraOfflineMessagesModule` | `Social.send_message` + outbox | have (local) | – | – |
| Groups (roles, notices, land) | GroupsService / Aurora Groups | `Social.group_*`, `group_claim_land` | have (local) | – | – |
| Profiles + picks | UserProfilesService / Aurora profile | `Social.profile`, `add_pick` | have (local) | – | – |
| Search (places, events, classifieds) | Aurora search / OpenSim search module | map landmark search; `show_in_search` flag stored | partial | P2 | – |
| Economy hooks | OpenSim MoneyModule, WhiteCore `Modules/Currency` (incl. ScheduledPayments) | `ledger.gd`, `currency_exchange.gd` scaffolds | partial ⚠ legal review | P2 | concept only |
| Map tiles | MapImageService, Warp3DMap | client-baked map + minimap | have (local) | – | – |
| Abuse reports | Aurora `AbuseReports` (+GUI) | `Social.report` + Community › Reports | have (local) | – | – |
| Login / accounts / auth | LLLoginService, UserAccount, Authentication | local Profile + OwnerVault | partial (device only) | P0 for multiplayer | own protocol, not LLLogin |
| Web UI (account, region admin) | Aurora/WhiteCore `Modules/Web` | in-app Viper Admin | partial | P2 | – |

## 3. Travel, landmarks, Hypergrid
| Feature | Reference | Viper OS | Mark | Prio | Cross-compat |
|---|---|---|---|---|---|
| Teleport to landmark / map click | SL | `UIRoot.teleport`, Travel + map panels | have | – | – |
| Personal landmarks, Set Home, teleport history | SL Landmarks / Teleport History | **new** `Landmarks` store + Travel panel buttons | have | – | `viper://Region/x/y/z` SLURL-like |
| Hypergrid (gatekeeper, HG inventory, HG friends/IM) | OpenSim `HypergridService` | – | missing | P3 | design in INTEROP §4 |
| Aurora IWC (inter-world comms) | Aurora | – | missing | P3 | concept |

## 4. Archives
| Feature | Reference | Viper OS | Mark | Prio | Cross-compat |
|---|---|---|---|---|---|
| OAR import: terrain | OpenSim `terrains/*.r32`, LLRAW | **new** `OpenSimArchive.parse_r32/parse_llraw` + `InteropImport` | have (stored heightmap) | – | real OARs |
| OAR import: parcels, settings, counts | `landdata/*.xml`, `settings/*.xml` | **new** `inspect_oar` | have (preview) | – | real OARs |
| Apply imported terrain to a region | – | – | missing | P1 | – |
| OAR objects (prims) → voxels | `objects/*.xml` | counted only | missing | P2 | lossy by design |
| IAR import: notecards, item list, next-owner perms | IAR `inventory/` + `assets/` | **new** `inspect_iar` | have | – | real IARs |
| Textures (JPEG 2000) | `*_texture.jp2` | listed, flagged | missing (needs converter) | P2 | needs a J2K decoder |
| Own export ("Viper OAR") | – | `TarGz.write` exists; no exporter | missing | P2 | our own JSON in a tar.gz |

## 5. Scripting, NPCs, objects
| Feature | Reference | Viper OS | Mark | Prio | Cross-compat |
|---|---|---|---|---|---|
| LSL events (touch, timer, listen), chat channels | LSL | – (plan in modules/SECOND_LIFE_SCRIPTING.md) | missing | P2 | LSL **subset** (INTEROP §3) |
| OSSL `osNpc*` (create, move, say, sit, animate, appearance) | OpenSim NPC module | companions: autonomy, say, roam (`AgentBrain`, `companion_agent.gd`) | partial (richer AI, no script API) | P2 | map osNpc verbs to companion actions |
| Object permissions incl. next-owner | SL/OpenSim PermissionMask | `Marketplace` copy/modify/transfer; IAR next-owner read | partial | P1 | bit values match (8192/16384/32768) |
| Prim building / linksets | SL build tools | Foxy: voxel build tools (BUILD_TOOLS_AND_TIERS) | partial (Foxy) | P1 | no prim compat |
| Media on a prim | SL MOAP | parcel `media_url` stored, music radio plays parcel music | partial | P2 | URL only |
| Voice | Vivox / Freeswitch | companion TTS (`companion_voice.gd`); no player voice | partial | P2 | no Vivox |

## 6. Environment and physics
| Feature | Reference | Viper OS | Mark | Prio | Cross-compat |
|---|---|---|---|---|---|
| Windlight / EEP sky presets, day cycle | SL EEP, OpenSim LightShare / EEP (`settings.bin`) | `EnvironmentPresets` + estate sun | have (own presets) | – | EEP assets not read |
| Wind, clouds | OpenSim Wind, Aurora Cloud | weather FX particles | partial | P3 | – |
| Physics engine | ODE / BulletSim / ubODE | Godot physics + `movement_model`, `surface_physics` | have | – | – |
| Aurora region extras (say/shout distances, max prim scale, minimap toggle, show tags, max groups) | `IOpenRegionSettingsModule` | – | missing | P3 | names kept in INTEROP §6 |

## 7. Avination and OpenLife Grid (rows for docs/modules/VIEWER_PARITY.md)
Same columns as the viewer parity table. Owner "Foxy" = client/HUD work; "Grok Bot" = server/admin pieces.

| feature | source | ours | owner | status |
|---|---|---|---|---|
| Grid-specific currency (Avination C$ "CareCoins", bidirectionally convertible; L$→C$ transfer terminals until Linden Lab stopped it) | Hypergrid Business 2010/2015; OpenSim Grid List | Aethel Coin ledger + exchange scaffold, real money off pending legal review | Grok Bot | partial |
| Currency theft response (2015: $126k stolen → switch to a new currency) | Hypergrid Business 2015 | lesson: server-authoritative ledger, idempotency keys, rate limits (ARCHITECTURE_AURORA_MODEL) | Grok Bot | planned |
| Region rental, fixed monthly tier, no setup fee ($40 → $60/region; 15k, later 45k prims) | Hypergrid Business 2010/2011; avination.com 2016; SL Newser 2014 | no rentals yet; tiers have inactive membership prices | Grok Bot | missing |
| Fully managed sims (no technical knowledge to own) | avination.com 2016 | standalone phone mode; grid hosting later | Grok Bot | planned |
| Built-in combat system (CCS add-on $15/month, free health meters) | Hypergrid Business 2010/2011 | combat zones, fire bolt, `allow_damage` flag | Foxy | partial |
| Content protection: closed grid, no HG, no OAR/IAR export, no god powers; export permission concept | Hypergrid Business 2011/2017 | owner lock, next-owner perms read on import; export permission flag not yet | Grok Bot | partial |
| Script engine near SL parity (XMREngine) | OpenSim Grid List | no script engine yet; LSL subset planned | Grok Bot | missing |
| Multi-attachments (Avination donated the code to OpenSim) | Hypergrid Business tag page | `AvatarAppearance` multiple items per attach point | Foxy | have |
| Mentors / help team in-world ("A-team"), welcome area with signs | avination.com 2016; SL Newser 2014 | Welcome Island, help panel; no mentor role | Foxy | partial |
| Trial home for newcomers (free house for two weeks) | SL Newser 2014 | – | Grok Bot | missing |
| No web marketplace on purpose (visit stores in-world); JEVN networked vendors + web shop | SL Newser 2014; Hypergrid Business 2010 | local marketplace + in-world vendor stub | Foxy | partial |
| Payment methods (e.g. paysafecard), blocking an unauthorised exchange (VirWoX) | avination.com 2016 | none; legal review first | Grok Bot | planned |
| Dedicated viewer recommended (upload glitches in others) | SL Newser 2014 | our own Godot client | Foxy | have |
| Grid closure handling: regions + inventories saved, currency lost (2017) | Hypergrid Business 2017 | encrypted backups; OAR/IAR import for refugees (OSgrid 2026) | Grok Bot | partial |
| OLG Sceneflip: one region swaps between alternate full scenes (up to 5), e.g. for shows/RP | lokazionel.fr | – (fits RealmBuilder presets + estate) | Grok Bot | missing |
| OLG SSO: grid-supplied replacements for heavy scripts, to save resources | lokazionel.fr | – (native modules instead of scripts is our default) | Grok Bot | missing |
| OLG Lite regions (4,000 prims, cheaper, e.g. waterways between regions) and sandbox region | lokazionel.fr | – | Grok Bot | missing |
| OLG own viewer only + content-protection contract (Second Inventory) | lokazionel.fr | own client | Foxy | have |
| OLG WindLight skies, mesh objects, ODE physics, proprietary 3DXServer | Wikipedia; rip.so; npirl 2008 | environment presets, glTF, Godot physics | Foxy | have |
| OLG in-world voice | search summary only, **not verified in a primary source** | – | Foxy | unverified |
| OLG/3DMee closure: no clear export path, rent refunded (2013) | rip.so | lesson: always offer export | Grok Bot | planned |

## Top missing features (priority order)
1. **P0 Grid login + presence + asset services** (G3) – everything multi-user depends on it.
2. **P1 Enforce the stored estate flags** (fly, damage, push, scripts, object entry) in player/combat/build code (Foxy for client paths).
3. **P1 Apply an imported OAR heightmap to a region** (generator hook + "land" permission). Timely: OSgrid closes 2026-12-31.
4. **P1 Object permissions end to end** (next-owner on every inventory transfer) and an export-permission flag.
5. **P2 LSL-subset script engine** (events + chat channels + timers, sandboxed).
6. **P2 Land sale, auctions, rentals** (no real money until legal review).
7. **P2 Search** (places, events, classifieds) honouring `show_in_search`.
8. **P2 JPEG 2000 → PNG converter** for IAR/OAR textures.
9. **P2 Sceneflip-style scene slots per region** (OLG idea).
10. **P3 Hypergrid-style federation**.

## Licensing
OpenSim, Aurora-Sim and WhiteCore are BSD-3-Clause (checked in each repo). We reimplement concepts and file layouts with attribution and copy no code; if a bridge ever links their libraries, it keeps their notices. The Second Life viewer is LGPL: concepts only. LibOpenMetaverse is BSD-3. Avination's and OLG's server code was never public. Their features are listed from public descriptions only.
