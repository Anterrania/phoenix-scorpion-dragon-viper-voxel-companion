# Interop: Aurora-Sim, OpenSim, Second Life, OSgrid, WhiteCore

> Status 2026-10-17 (VWGAP-3). **Built:** OAR terrain/summary import, IAR notecard import, Admin › Interop status page. **Everything else here is a plan.** Gap checklist: [../VIRTUAL_WORLD_FEATURE_GAP.md](../VIRTUAL_WORLD_FEATURE_GAP.md).

## 0. Principles
- **Import first, bridge last.** Bringing your own regions and inventory in is cheap and useful. A live protocol bridge is expensive and fragile.
- **Our formats stay ours.** Voxels, glTF, PNG/OGG, JSON. We read theirs. We don't write prims or LLUDP.
- **Same gates as everything else.** Preview = anyone who can browse. Import = `Tiers.can(actor, "upload")` (Premium/Creator, staff, or the unlocked owner). Clearing the log = owner only (`admin`). Applying terrain to a region will need `land` on that region.
- **Hostile files are normal.** OSgrid is closing (2026-12-31) after someone flooded it with junk data. Every importer has size, count and path limits.

## 1. Archives (OAR / IAR)
| Piece | Format (from OpenSim `ArchiveConstants.cs`, `RAW32.cs`, `LLRAW.cs`) | Us | Status |
|---|---|---|---|
| Container | gzip'd tar (ustar or GNU long names) | `TarGz.read/write` (64 MB file cap, 128 MB unpacked, 50k entries, `..`/absolute names dropped) | **built** |
| `archive.xml` | `<archive major_version minor_version>`, `size_in_meters` | version + size shown in preview | **built** |
| `terrains/<region>.r32` | float32 little-endian, row-major, square, no header | `OpenSimArchive.parse_r32` → stats → `to_viper_heightmap` (box filter to 64², water 20 m → our −3 m, clamp −20..48) | **built** (stored in `user://interop/terrain/`) |
| `.raw` LLRAW | 13 bytes/px, h = b0·b1/128, rows flipped | `parse_llraw` | **built** |
| `landdata/*.xml` | `LandData`: Name, Area, Flags (PARCEL_FLAG_*), SalePrice | parcel list + `Estate.flags_from_sl` | **built** (preview) |
| `settings/<region>.xml` | RegionSettings: AllowDamage, BlockFly, RestrictPushing, AgentLimit, WaterHeight… | shown in preview | **built** (not applied) |
| `objects/*.xml` | SceneObjectGroup prims | counted | planned: prims → voxel stamps or placeholder boxes (lossy) |
| `assets/<uuid>_<type>` | `texture.jp2`, `notecard.txt`, `script.lsl`, `mesh.llmesh`, `sound.ogg`, `animation.bvh`, `bodypart.txt`, `clothing.txt`… | counted by kind | planned per type, below |
| IAR `inventory/<folder>__<uuid>/<item>__<uuid>.xml` | InventoryItem: Name, AssetID, AssetType, NextPermissions | `inspect_iar` lists items and next-owner copy/modify/transfer (bits 32768/16384/8192) | **built** |
| Notecards | "Linden text version 2 … Text length N" (N in bytes) | `notecard_text` → `user://interop/notecards/` | **built** |

### Asset types
| OpenSim asset | Plan | Feasibility |
|---|---|---|
| Notecard | text, done | easy |
| Texture `.jp2` (JPEG 2000) | Godot can't decode J2K. Options: an OpenJPEG GDExtension, or a desktop/server converter tool → PNG | medium; the converter tool comes first |
| Texture `.tga` / `.jpg` | `Image.load_tga_from_buffer` / `load_jpg_from_buffer` | easy (next) |
| Mesh `.llmesh` | LLSD-binary + zlib per LOD. A converter to glTF is a real project. Users with the original `.dae` should import that: Godot reads Collada and glTF | hard; prefer the `.dae`/`.glb` source |
| Collada `.dae` / glTF `.glb` | `Marketplace` import path (sha256-addressed) | have (.glb) |
| Sound `.ogg` / `.wav` | `AudioStreamOggVorbis.load_from_buffer` | easy |
| Animation `.bvh` | BVH → Godot Animation on our skeleton (bone name map) | medium |
| Bodypart / clothing `.txt` | "LLWearable version 22" param lists → `AvatarAppearance.visual_params` (§5) | medium |
| Script `.lsl` | listed only. Never executed. The LSL-subset translator (§3) may read it later | – |
| Landmark `.txt` | region + local position → `Landmarks` (`viper://` address) | easy |

Permissions: we only import what the archive says the next owner may copy. Items without next-owner copy are listed, not stored. Notecards are the one exception: their text is stored for the owner's own archive, and the next-owner flags are recorded.

### Our own export ("Viper archive")
Same tar.gz container (`TarGz.write`), our content: `viper.json` (format, version), `terrain/<region>.json` heightmaps, `voxels/<chunk>.bin` deltas, `estate.json` (flags + covenant), `objects/*.glb`, `inventory/*.json`. Never OpenSim XML. Planned.

## 2. Grid services shaped like ROBUST
Plan: JSON over HTTPS, one path per service, method names that match OpenSim's ROBUST connectors so Aurora/OpenSim admins recognise them. Our standalone `LocalServices` uses the same method names (ARCHITECTURE_AURORA_MODEL G1).

| ROBUST connector | Ours | Example |
|---|---|---|
| `/assets` (AssetService) | `GET/PUT /assets/{sha256}` | sha256 instead of UUID |
| `/xinventory` | `GET /inventory/{user}/folders`, `POST /inventory/move` | |
| `/avatar` | `GET/PUT /avatar/{user}` (`anterrania.avatar.v1`) | |
| `/presence`, `/griduser` | `PUT /presence`, `GET /griduser/{user}` (last region, home) | home = `Landmarks.home()` |
| `/friends`, `/groups`, `/im` | `/social/*` (Social API) | offline IM = `Social` outbox |
| `/grid` | `GET /regions?x&y`, `POST /regions/register` | |
| `/estate` | `GET/PUT /estate/{region}` incl. flags + covenant | `Estate.sl_parcel_flags` for SL-shaped clients |

## 3. LSL subset → Viper scripting
Clean-room: we implement the **meaning** of a few LSL calls in a sandboxed script runner (GDScript-lite or Lua). We never run real LSL bytecode.

| LSL | Viper | Gate |
|---|---|---|
| `state default`, `state_entry`, `touch_start`, `timer`, `listen`, `on_rez` | usable-object signals | `allow_scripts` (+ `allow_group_scripts`) |
| `llSay/llShout/llWhisper/llRegionSay(channel, msg)` | chat bus, distances from region settings (Aurora `SayDistance` etc.) | rate limit |
| `llListen` | subscribe to channel | max listeners |
| `llSetTimerEvent` | Timer node | min 0.1 s |
| `llGetPos/llSetPos` | node transform | build rights on target parcel |
| `llGetParcelFlags` | `Estate.sl_parcel_flags` (same bits as SL) | – |
| `llGiveInventory`, `llRezObject` | inventory/asset service | next-owner perms, `allow_object_entry`/`sandbox` |
| `llHTTPRequest` | **off** by default; owner-approved allow-list | owner |
| `osNpcCreate/MoveTo/Say/Sit/PlayAnimation` | companion actions (`AgentBrain`), e-stop aware | `AutonomyGuard` |
| `llPushObject` | physics impulse | `allow_push` |

## 4. Hypergrid-style travel and identity
- **Identity:** `user@grid` (HG "home grid" model). The home grid keeps the account, inventory and Aethel balance. A visited grid only gets a signed, short-lived travel token and an appearance copy.
- **Travel:** a gatekeeper endpoint per grid (`/gatekeeper/link`, `/gatekeeper/arrive`) and a `viper://grid/Region/x/y/z` address (extending `Landmarks.address`).
- **Assets abroad:** fetched from the home grid by sha256, cached, and honouring an **export permission** (the Avination lesson: creators must be able to say "never leaves my grid").
- **Money never crosses grids.** No cross-grid currency (legal review).
- **Feasibility:** medium once our grid services exist (G7). Speaking OpenSim's real HG protocol is a separate question (§5).

## 5. Gateway / bridge to OpenSim grids (honest feasibility)
| Option | What it means | Verdict |
|---|---|---|
| A. Full LLUDP client in Godot | Reimplement the SL/OpenSim viewer protocol: UDP message template, CAPS seed + event queue (HTTP/LLSD), login XML-RPC, texture (J2K) and mesh pipelines, prim rendering | **No.** It's a whole viewer, and it's prim-based where we're voxel-based |
| B. Headless bridge service with LibOpenMetaverse (BSD-3, C#) | A server-side bot logs into an OpenSim grid and relays chat, IM, presence and teleports to our app as JSON | **Feasible as a later experiment**: chat/IM/friends presence bridging. No rendering of their world |
| C. Import / export only | OAR/IAR in, our archive out | **Doing it now** |
| D. OpenSim region module that speaks our protocol | Their region exposes heightmap + object summaries to our client read-only | possible research; needs .NET work on their side |
Recommendation: C now, B for comms later, A never. CAPS ideas worth borrowing: a per-session capability URL map (one seed, then named endpoints), which our login token handoff already resembles.

## 6. Avatar appearance mapping (SL / OpenSim → docs/AVATAR_STRUCTURE.md)
| SL/OpenSim | Ours (`AvatarAppearance`) | Notes |
|---|---|---|
| 16 WearableTypes (shape, skin, hair, eyes, shirt, pants, shoes, socks, jacket, gloves, undershirt, underpants, skirt, alpha, tattoo, physics) | `wearables[type]`, clothing stacks up to 5 | same names and order |
| VisualParams (byte 0..255) | `visual_params` id → 0..255 (33 Height, 34 Thickness, 36 Shoulders, 682 Head Size, 17 Jaw, 692/693 Leg/Arm length) | IAR `bodypart.txt` / `clothing.txt` param lists map by id |
| Attachment points (1 Chest, 2 Skull, 5/6 hands, 39 Neck, 40 Avatar Center…) | `attachments[point_id]`, multiple per point | Avination's multi-attach model |
| Baked textures | planned bake compositing | J2K converter needed for SL textures |
| Mesh bodies (Bento rigs) | our realistic body + DNA blend | bone name map needed |

## 7. Licensing (checked in the repos on 2026-10-17)
- **OpenSimulator:** BSD-3-Clause (`LICENSE.txt`).
- **Aurora-Sim:** archived. The licence text in `AuroraDocs/LICENSE.txt` is the OpenSim BSD-3 text. WhiteCore ships it as `Licenses/AuroraSim.license` (the file is empty in the repo, so we rely on the AuroraDocs copy).
- **WhiteCore-Sim:** BSD 3-Clause (`LICENSE`, GitHub reports `bsd-3-clause`). It keeps the OpenSim and Aurora notices.
- **LibOpenMetaverse:** BSD-3 (only relevant for bridge option B).
- **Second Life viewer:** LGPL-2.1. Concepts only, no code.
- Our importers are clean-room reimplementations of public file layouts. If we ever ship code derived from these projects, the BSD notices go into `ThirdPartyLicenses/`.

## 8. Admin › Interop page
MENU › **⇄ Interop**. It shows OAR/IAR counts, failed imports, the last import, a file path box with **Preview** (anyone) and **Import** (Premium/Creator, staff, or the unlocked owner), recent imports, and **Clear log** (unlocked owner). Code: `scripts/admin/interop_screen.gd`, `scripts/interop/*`. Tests: `tests/interop_tests.gd`.
