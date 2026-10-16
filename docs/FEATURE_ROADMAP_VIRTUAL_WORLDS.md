# Feature Roadmap — Virtual-World Features (original designs)

These are **original** features for the Phoenix Scorpion Dragon Viper world. They are *inspired by
ideas* proven in OpenSimulator, Aurora-Sim, Second Life, Avination, OpenLife Grid, OSgrid, Dual Universe
and Star Citizen.

**Clean-room rule.** We copy no code, assets, art, UI, names of proprietary systems, or protocol docs
that aren't public from any of them. Second Life, Dual Universe and Star Citizen are proprietary,
so we take ideas only. OpenSimulator (and its Aurora-Sim fork) is BSD-licensed. Later we *may* write an
optional interop bridge (LLSD/LLUDP or the Hypergrid protocol) from the public specs, keeping BSD notices,
but none of that code goes in the game client. Avination, OpenLife and OSgrid are grids run on OpenSim,
and we take only design ideas from them.

**Vision.** A *modern Second Life*: a social, user-shaped virtual world with inventory, wardrobe,
land, building, media and an economy. It has the cinematic scale and seamless space-to-surface
travel of Star Citizen and Dual Universe, and it's lived in by *autonomous AI companions*
who keep the world alive.

Stack: Godot 4.7, Zylann Voxel Tools (smooth Transvoxel + VoxelLodTerrain), mobile renderer, Android first.

| # | Feature (our name) | Inspired by | Godot implementation | Phase |
|---|---|---|---|---|
| 1 | **Physics & collision** (done in v0.4) | all | CharacterBody3D + voxel collision, RigidBody props, SurfacePhysics (ice/lava/water) | 0.4 ✅ |
| 2 | **Sovereign Wardrobe** (avatar customization, outfits, attachments) | SL/OpenSim appearance, SC character creator | `HumanoidModel` parts → data-driven `data/wardrobe/*.json`; BoneAttachment3D slots; later glTF skinned bodies + blendshapes | 0.5 |
| 3 | **Satchel inventory** (items, folders, give/receive) | SL/OpenSim inventory | `Inventory` autoload, Resource-based `ItemDef`, saved to `user://inventory.json`; drag-and-drop UI | 0.5 |
| 4 | **Companion voice & chat** (local chat, whisper/shout radius, voice) | SL local chat + voice | Existing ChatUI + AgentBrain (LLM); radius-based chat bus; Android STT plugin + DisplayServer TTS / cloud TTS | 0.5–0.6 |
| 5 | **Forge-Prims** (in-world building with primitives: box/sphere/cylinder/torus, link sets, scale/rotate gizmos) | SL/OpenSim prims | `Construct` node holding CSG/MeshInstance parts + collision; gizmo tool; serialize to JSON "construct files" | 0.6 |
| 6 | **Voxel Construct building** (sculpt and paint terrain or free-floating constructs, SDF brush) | Dual Universe voxel building | VoxelTool `do_sphere/do_box` on the terrain (already used by companion tools) + separate `VoxelTerrain` for movable constructs; undo stack | 0.6 |
| 7 | **Rune Scripting** (behaviors on objects: touch, timer, collide events) | LSL / OSSL | Sandboxed mini-language or Godot `Expression` with a whitelisted API; event signals on Construct; *no* LSL compatibility layer | 0.7 |
| 8 | **Realm Parcels** (land claims, owner/permissions, ban lists, parcel music/ambience) | SL/OpenSim parcels, DU territory tiles | Grid of parcel Resources over the heightfield; Area3D per parcel; permissions checked before build tools | 0.7 |
| 9 | **Realm Grid** (regions as tiles, region crossing, map) | OpenSim/OSgrid regions | World partitioned into 512 m regions with seeds; streaming handoff; minimap from baked biome map | 0.8 |
| 10 | **Multiplayer Realm Servers** | OpenSim servers, SC servers | Godot high-level multiplayer (ENet/WebSocket), dedicated headless server build, authoritative physics; MultiplayerSynchronizer for avatars/props | 0.9 |
| 11 | **Gatewalk** (Hypergrid-style teleport between realms/servers, avatar + inventory travel with you) | OpenSim Hypergrid | Signed realm-address URLs `anterrania://host/realm`, portal Area3D, server handoff token; optional HG bridge later (BSD, public spec) | 1.0 |
| 12 | **Gatherings** (events calendar, stages, dance/emote sync, concerts using our songs) | SL events | Event Resource + in-world board; AnimationPlayer emotes synced via multiplayer; music streams per parcel | 0.9 |
| 13 | **Aethel economy** (Aethel Coin, marketplace, vendor constructs, rentals) | SL/OpenSim economies, DU markets | Server-authoritative ledger (game-only currency, no real-money cash-out); vendors are scripted Constructs | 1.0 |
| 14 | **Starships** (constructs with thrusters, seats, interiors you can walk in) | Star Citizen, DU | Construct + RigidBody3D with thruster forces; interior uses local physics space (moving-frame CharacterBody) | 1.1 |
| 15 | **Planetary flight & atmosphere** | Star Citizen, DU | Spherical planets: VoxelLodTerrain with spherical SDF generator, radial gravity (Area3D gravity point), atmospheric drag/heat shader | 1.2 |
| 16 | **Seamless Skyfall** (space-to-surface with no loading screen) | Star Citizen, DU | Floating origin (re-center world), double-precision Godot build or origin shifting, LOD planets → terrain streaming | 1.3 |
| 17 | **Star map & system travel** (quantum-style jump between moons/planets) | Star Citizen | Solar-system scene graph, jump-drive timed travel, the ringed planet/moons from the v0.3 sky become real bodies | 1.3 |
| 18 | **Creator tools** (import user glTF meshes and textures, with moderation) | SL mesh upload | Runtime GLTFDocument import, size/poly limits, age-gated mature flag (existing `content.mature_cosmetics_enabled`) | 1.0 |

## v0.5 status (shipped)
- World content: smooth props in each biome, 7 placeholder landmarks with "YOUR INPUT HERE" signs, and Travel menu.
- Wardrobe & Satchel (data-driven, with the 18+ gate), main menu, settings, and companion chat (offline canned replies, plus a live-AI config hook).
- Companion text-to-speech, push-to-talk stub, Phoenix Radio (parcel music), and Follow/Free-roam autonomous companions with a memory log.

## Avatars: DNA blend + SL-style customization
- **Now (0.5):** each phone gets its own avatar from the first-launch creator, with owner and guest roles. The **DNA blend** is our own system, not Star Citizen code. You pick 2–3 parent archetypes (Ember, Frost, Nova, Titan, Sylph), mix them with weight sliders, then fine-tune height, build, shoulders, head, jaw, leg and arm. Morphs drive scale weights on the base model's parts. **Attachment points** are head, hair, face, chest, back, hips, both hands and both feet. Built-in attachments are a halo, crown, wings, cape and scepter. **Alpha masks** hide head, arms, legs, feet or hands. **Runtime .glb import** attaches a user mesh. **Portable avatar file:** `anterrania.avatar.v1` JSON with colors, DNA, sliders, masks and attachments.
- **0.6:** a skinned glTF base body with real blend shapes, so DNA weights drive morph targets. Swappable mesh hair, clothing and body parts with rigging to our skeleton. **Layered textures** (skin → tattoo → underwear → shirt → jacket) composited into one atlas per avatar.
- **0.7:** face DNA (eyes, nose, mouth, brows), body-fit sliders for mesh clothing, and an outfit/folder system.

## Creator marketplace (UGC)
- **Data model now:** `data/marketplace/schema.json`. Items have a creator id, kind, glTF asset with sha256, attach point, alpha masks, SL-style **copy/modify/transfer** next-owner permissions, a price in **Aethel Coin**, a mature flag, and a moderation state (pending/approved/rejected). `Marketplace` (local) imports a .glb into a moderation queue, lists only approved items, hides mature items unless the buyer enabled the gate, and buys from a local Aethel wallet. An in-world **Creator Market vendor** stub stands near spawn.
- **Server (0.8+):** accounts, server-verified creator ids, upload limits (triangle and texture budgets), virus and format checks, human plus automated moderation and a report flow, escrow and payouts, revenue share, and a ban on real-person likenesses and copyrighted or trademarked uploads.

## Second Life concepts mapped to our game
| Second Life | Phoenix Voxel (our version) | Status |
|---|---|---|
| Prims (boxes/spheres you build with) | **Voxels** (smooth Transvoxel + block voxels) and Forge-Prim shapes | v0.6 building |
| Mesh uploads | **.glb uploads** (attachments, clothing, props) | local import ✔, store later |
| Region (256 m sim) | **Region / island** (256×256 m) | data model |
| Parcel | **Parcel** inside a region, with its own permissions and music | data model |
| Estate / private island | **Estate**: regions → **whole planets → star systems** | data model |
| L$ (Linden dollars) | **Aethel Coin (AEC)** | local wallet ✔ |
| Upload fee (L$10) | **AEC upload fee** for mesh / texture / sound | data model |
| Tier / land fees | **Monthly AEC tier fee** for each land tier | data model |
| Groups (land deeding, roles) | **Groups** with roles and deeded land | data model |
| Inventory | **Satchel** (BAG) | ✔ basic |
| Appearance / shapes / alphas | **Avatar creator + DNA blend + alpha masks** | ✔ |
| Attachments (HUD/head/hands…) | **Attachment points** | ✔ |
| Landmarks | **Landmarks** with signs + Teleport list | ✔ |
| Teleport / map TP | **MENU › Teleport** and **◎ MAP** tap-to-teleport | ✔ |
| Fly (Page Up/Down) | **FLY** button + ▲/▼ (keys E/C on PC) | ✔ |
| Parcel music / media | **Phoenix Radio** (user station URL) | ✔ basic |
| Local chat / IM / voice | **TALK** panel, companion voice (TTS), push-to-talk stub | partial |
| Marketplace / vendors | **Creator Market** with SL-style perms + vendor | data model + stub |
| Bots / NPCs | **Autonomous AI companions** (free roam, memory) | ✔ basic |

## Movement: fly & teleport
- **v0.5.1 ✔:** SL-style flight (toggle, up/down, hover, ceiling at 600 m, follows camera pitch, collides with structures). Teleport by landmark list or by tapping the world map.
- **Next:** teleport to friends, home location, landing points per parcel, and flight limits per parcel (no-fly land).

## Land economy & upload fees (data model: `data/economy/land_and_fees.json`)
- **Upload fees** in AEC for mesh, texture, sound and animation. Free for the owner/admin.
- **Land tiers:** parcel → region/island → homestead → **planet** → **star system** (and beyond: sectors/galaxies). Each tier has a buy price, a monthly tier fee and a voxel budget (like land impact).
- **Ownership:** an avatar or group owns land. Groups have roles and abilities and receive deeded land. Rentals, for-sale settings, covenants, estate managers, allow/ban lists, and landing points.
- **Parcel permissions:** build, object entry, scripts, fly, push, damage, access, and media/music URL.
- **Server needed:** land and money need an authoritative server (0.8+). Today it's data model only.

## Combat (opt-in, like SL damage-enabled land)
- **Rules:** combat is only on where the land's `damage` permission is on. Spawn, landmarks and the Lagoon are safe zones by default.
- **Styles:** melee, fire magic and ranged, with health plus regenerating shields. Respawn at home or the nearest landmark.
- **PvE creatures:** frost wyrmling (Alaska), magma crawler (Venus), void wisp (Cosmic).
- **RP combat meter:** opt-in d20 + stat dice, with a turn-based option for roleplay fights.
- Today: lava damage, a health bar and respawn already exist (v0.4). Everything else is in the stub data in `data/gameplay_stubs.json`.

## Roleplay
- RP titlers (name, title, faction, IC/OOC status) and character sheets.
- **IC/OOC channels** with whisper/say/shout at 10/20/100 m.
- /me emotes, pose stands, and couples poses that ask for consent first.
- Factions are built on land groups. RP sims are regions with a covenant and a required titler.

## Breedables
- **Genetics:** two alleles per trait (coat, eyes, wings, glow, size) with a rare mutation chance.
- **Care and breeding:** feeding with Aether Feed bought in Aethel Coin. Neglected pets go dormant and never die. Breeding has a cooldown and needs ownership or permission.
- **Trading and creators:** pets are inventory items with transfer permissions, sold in the Creator Market. Third-party creators upload trait packs and meshes as UGC (upload fees and moderation apply).

## Music: SoundCloud (v0.5.2)
- **Source:** Phoenix Radio uses SoundCloud. The owner's default is `data/music.json` → `default_soundcloud_url` = **Anterranian Monarch** (`https://soundcloud.com/anterrania`). Players can set their own SoundCloud URL in **MENU › Music**.
- **Works now, no key:** the radio shows the track or profile title through SoundCloud's public oEmbed. **▶ Play on SoundCloud** opens the SoundCloud app (or web player) on the phone, which follows SoundCloud's terms and attribution. In-world, a royalty-free fallback track keeps the parcel music going.
- **In-game streaming (optional):** needs SoundCloud API credentials, which require an **Artist Pro** subscription. The flow is client-credentials token → resolve → `/tracks/:id/streams` → progressive MP3 played in-world. Limits: many tracks only offer HLS/AAC, and some are blocked off-platform by the creator; those fall back to the SoundCloud app. Godot can't play HLS/AAC without a plugin.
- **Keys:** the client secret must never ship inside a public APK. For now it can only be typed into Settings on the owner's own phone. Later, a small proxy server holds it.
- **Later:** an embedded WebView with the SoundCloud Widget API (needs an Android WebView plugin), and per-parcel SoundCloud playlists.

## Voice chat
- **Now (0.5):** companions speak replies via `DisplayServer.tts_speak` (one voice per companion, Settings toggle). There's also a 🎤 push-to-talk button that emits `push_to_talk(active)` (stub only, no mic permission yet).
- **0.6:** speech-to-text through an Android STT plugin (on-device `SpeechRecognizer`) sends text to `ChatUI._send()`. Optional cloud TTS voices are matched to each persona.
- **0.8+ (multiplayer):** player-to-player voice through a WebRTC voice server (SFU) with spatial falloff. The local chat radius works like SL whisper/say/shout at 10/20/100 m. Includes mute, block, and a report flow.

## Media streaming (parcel media)
- **Now (0.5):** the `MusicRadio` object downloads an HTTP MP3/OGG (≤12 MB) and loops it. Volume fades with distance inside its radius, the way SL parcel music works. The default track is royalty-free (Kevin MacLeod, CC BY 4.0, credited). The user sets their own station URL in Settings (YOUR INPUT HERE).
- **Next:** true endless streams (Icecast/Shoutcast) using chunked `AudioStreamGenerator` decode or an Android ExoPlayer plugin, now-playing metadata, and a radio per parcel/landmark owned by the land owner.
- **Later:** media screens that show video or web on prims, shared-playback sync in multiplayer, and a DJ stage at Moonlit Wyvern Rink.
- Licensing: streams are user-supplied. The app ships only royalty-free or licensed defaults.

## Living autonomous AI
- **Now (0.5):** `CompanionLife` runs a utility-AI loop per companion with needs (energy, curiosity) and goals (explore, gather, build a small cairn, travel to a landmark, rest). Free roam ↔ Follow me is toggled in chat. Every action goes to a memory log (and AgentBrain facts), and companions recap it when asked "what did you do?".
- **0.6:** builds use the real voxel/prim building system. Companions use the inventory/economy (gather → craft → trade) and pathfinding (navmesh on voxel chunks). Companions talk to each other.
- **0.7:** daily schedules, relationships, and per-companion homes at landmarks. Live-AI planning (LLM picks goals; tools: move_to, build_realm, spawn_structure).
- **Server (0.8+):** persistent world simulation on a headless Godot server. Companions keep travelling, building and gathering while the player is offline. The player gets a "while you were away" recap on login. Memory syncs with the Grok Bot personas.

## Phase order
1. **0.4** Physics & collision (this release).
2. **0.5** Wardrobe, inventory, real companion chat in-game (synced personas).
3. **0.6** Building: Forge-Prims + voxel constructs, save/load.
4. **0.7** Rune Scripting + Realm Parcels.
5. **0.8** Realm Grid and region streaming.
6. **0.9** Multiplayer servers + Gatherings.
7. **1.0** Gatewalk teleport, Aethel economy, creator imports.
8. **1.1–1.3** Ships, planetary flight, seamless space-to-surface, star map.

## Mobile notes
Motorola-class phones: keep physics bodies under ~60 active, use collision LOD 0 only near the player,
and sleep idle RigidBodies. Server-side simulation is needed for big multiplayer realms.
Star Citizen-level fidelity is a direction we aim toward, not something a phone can fully match.
