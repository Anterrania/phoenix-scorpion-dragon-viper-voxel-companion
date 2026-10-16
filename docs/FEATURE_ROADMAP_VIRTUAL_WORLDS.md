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
