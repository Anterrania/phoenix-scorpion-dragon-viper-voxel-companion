# Sandbox, Open-World & Virtual-World Parity (SBX)

Features and abilities only. No design, UI, names, characters, lore, assets, code or trademarks are copied: every row is a concept rebuilt in our own code. Game titles appear here only to say where an idea was seen.

- **Split (agreed with Foxy, 2026-10-17):** dev builds the system/server side (quests and missions, on-demand worlds and region bundles, inventory migration, market delivery, magic-box vendors, region rental, free-play chance games, the legal gates). Foxy builds the client features and their data: needs, moods and relationships; household and build mode; vehicles, driving and the in-world phone hub (non-violent by default, combat only where estate `allow_damage` is on); skill trees, crafting and shouts/powers; companion teams, pets, mounts and formations; and every HUD, dialogue, radio and creator screen. Foxy items have a spec in `docs/specs/foxy/` and `owner = Foxy` rows.
- **Money and chance:** every Aethel Coin and chance path goes through `LegalReview` (`scripts/economy/legal_review.gd`), deny by default. See [LEGAL_REVIEW_GATES.md](LEGAL_REVIEW_GATES.md). Casino-style and chance games are **free-play only** with earned play tokens: no Aethel Coin wagers or payouts, no paid spins, no paid loot boxes (LATER, flag off, LEGAL REVIEW). Anything else involving Aethel Coin is marked **LEGAL REVIEW**.
- **Permissions:** every system check goes through `SandboxGate.can` -> `Tiers.can`. Owner-only verbs need `Tiers.owner_session()` (= `Profile.is_owner()`) and the owner actor.
- **Parity table:** the single table is meant to be `docs/modules/VIEWER_PARITY.md`. It was **not on `main`** when this branch was cut (feature/viewer-parity and feature/social-media-parity are still open), so the sandbox rows live in the "Parity table (sandbox section)" below. When VIEWER_PARITY.md lands, move this section in unchanged as its own "Sandbox / open-world / virtual-world" section.

Status key: **have** = in the app now · **partial** = some of it built · **missing** = not built, not scheduled · **planned** = has a tracker row · **n.a.** = not applicable or refused on purpose.

## 1. Capability inventory by source

### Life sim: The Sims (1 to 4, plus spin-offs)
- **Needs:** six to eight decaying motives (hunger, energy, hygiene, bladder, social, fun, comfort, room/environment), each pulling the sim toward objects that advertise relief.
- **Moods and emotions:** moodlets with timers that stack into one emotion, which unlocks or blocks interactions.
- **Personality:** traits, aspirations with milestone rewards, likes and dislikes, lifetime wishes.
- **Relationships:** two axes (friendship and romance), family trees, aging and life stages, inheritance.
- **Careers:** rabbit-hole jobs and active careers, daily tasks, performance, promotions, a skill gate per level, part-time and freelance work.
- **Skills:** skill-by-use with level-gated interactions, plus skill books and teaching.
- **Households and lots:** household funds, bills, lot types (residential and community), home ownership, roommates.
- **Build/buy:** walls, rooms, roofs, stairs, terrain paint, a catalog, object placement grid and free placement, and blueprints from a gallery.
- **Autonomy:** free will levels and queued interactions.
- **Other:** the shared online gallery for sharing lots and characters; seasons, weather and holidays; neighborhood stories.

### Open world: Grand Theft Auto (III, Vice City, San Andreas, IV, V, Online)
- **Vehicles:** cars, bikes, boats, aircraft, per-class handling, damage, garages, customisation shops, impound and recovery.
- **Missions:** contact givers, mission chains, side jobs (taxi, delivery, rescue), timed objectives, fail states, checkpoints and replays.
- **Wanted level:** a heat rating that escalates police response; stars decay out of sight; escapes include respray and hiding. Violent, so ours is **n.a. by default** and only exists where estate `allow_damage` is on, as non-lethal "heat" (Foxy).
- **Gangs, territory and respect (San Andreas):** turf held by groups, takeover waves and defence, a respect meter that limits recruits, recruitable followers.
- **Stats and skills (San Andreas):** stamina, muscle, fat, lung capacity, driving, flying and weapon skills, all trained by use. Diet and exercise change the body.
- **Radio:** stations per vehicle, talk shows, a custom user track station.
- **Property:** safehouses as save and respawn points, businesses with income, garages.
- **Heists (V, Online):** a setup and finale structure, crew roles and cuts, approach choices.
- **Other:** a phone hub for contacts, internet and missions; stock markets; apartments; crews and organisations; passive mode; jobs made by players in a content creator.

### RPG: Skyrim (and the series)
- **Skills and perks:** skill-by-use leveling, perk trees per skill (constellations), and a character level drawn from skill gains.
- **Crafting:** smithing, tempering, alchemy, enchanting, cooking.
- **Factions:** joinable guilds with questlines, rank-ups and crime per hold.
- **Followers:** followers with commands, carry weight and marriage. Mounts.
- **Magic:** spells and shouts (powers on cooldown).
- **Dialogue:** topic-based conversation with speech checks.
- **Quests:** a radiant quest generator, a journal and a quest marker.
- **Housing:** buy and build houses.
- **Mods:** load order, script extender and a creation kit.

### Browser/idle MMO: League of Angels (and similar)
- **Combat and progression:** formation party combat (auto-battle); a guardian companion that buffs formation slots.
- **Guilds:** guild level, donations, daily wages by rank, a guild store paid in a contribution currency, guild bosses and events.
- **Idle and dailies:** AFK/idle progression with offline rewards, daily quests and login streaks.
- **Gacha:** hero recruitment by card draw (gacha). Ours is **paid gacha: LATER, LEGAL REVIEW**; only free-play draws with earned tokens are allowed.
- **Upgrades and modes:** mounts with upgrades, gem slots, team arenas and dungeons, cross-server PvP.

### Social casino: Game of Thrones Slots Casino (and social slots)
- **Slots:** themed reel machines with levels, bonus rounds, progressive meters.
- **Engagement loops:** daily bonuses and timed free coin, quests and seasons, collections and albums, alliances and leaderboards.
- **Purchases:** coin purchases. Ours is **refused**: chance games are free-play only, play tokens can't be bought, and casino content is 18+ ([LEGAL_REVIEW_GATES.md](LEGAL_REVIEW_GATES.md)).

### OpenSim grids: InWorldz and its marketplace
- **Grid:** a commercial OpenSim-family grid (closed 2018) with its own script engine (Phlox), region rental and land tiers.
- **Inventory and permissions:** SL-style inventory with copy, modify and transfer permissions and next-owner permissions.
- **Marketplace:** a web marketplace that delivered to in-world inventory.
- **Migration:** a grid shutdown that pushed residents to move their inventory to other grids. That is the case our inventory migration covers.

### OpenSim grids: Kitely and Kitely Market
- **On-demand worlds:** cloud-hosted worlds that sleep when empty and wake on teleport (seconds up to about a minute).
- **Billing:** per-minute visitor billing (Premium Worlds; the owner can subsidise visitor groups) and later fixed-price worlds.
- **World archives:** export and import of worlds as OAR, with an export report listing what was left out.
- **Marketplace:** product variations; permissions derived from the contents (modify if any item has it, copy and transfer only if all items have them); a merchant-set **Export** permission (default off) that controls OAR inclusion and off-grid delivery.
- **Delivery:** to the buyer, as a gift, or to an avatar on another grid. Off-grid orders are boxed and wait for the recipient to click an IM.
- **Merchant tools:** test delivery and redelivery; magic boxes and in-world vendors.

### Sandbox games and virtual worlds
- **Minecraft:** voxel mining and building; crafting recipes and smelting; redstone logic; survival, creative and adventure modes; villagers and trading; enchanting; servers, plugins and datapacks; realms (hosted worlds); a marketplace.
- **Roblox:** games made by users with scripting, a group economy, game passes and developer products, avatar catalog with UGC, private servers, badges, and parental controls with age-gated experiences.
- **No Man's Sky:** procedural planets; ship, freighter and base building; refining and crafting; missions from guilds; settlement management; multiplayer expeditions.
- **Rust:** survival needs, base building with upkeep and decay, tool cupboards (building privilege), raids, wipes.
- **Valheim:** comfort and rested buffs, boss-gated progression tiers, portals that block metal transfer, dedicated servers.
- **Garry's Mod:** a physics sandbox with tool and physgun; addon workshop; game modes (roleplay, prop hunt) made by players; server-side Lua.
- **Fallout (3, NV, 4, 76):** SPECIAL stats and perk cards, settlement building, faction reputation, crafting and weapon mods, companions with affinity, camps (76).
- **Red Dead Online:** roles (trader, bounty hunter, collector) with role ranks, camps, horse bonding, a honor/morality meter, posse.
- **Animal Crossing:** real-time clock and seasons, daily resource respawn, island designing, villager relationships, museum collections, island visits (Dodo-style codes), a turnip-style market (refused: speculation with currency).
- **IMVU:** avatar rooms, a creator catalog with derivation (derive from another creator's product with royalties), and age-verified access passes.
- **Sansar:** scene hosting on demand, events, a store with a creator economy.
- **VRChat:** worlds and avatars made by users, an SDK with Udon-style scripting, instance types (public, friends+, invite), trust ranks, safety shields.
- **Decentraland, The Sandbox:** parcel ownership, scene SDKs and builder tools, events, wearables. **Blockchain and NFT land and items: n.a., HARD-disabled.**
- **Entropia Universe:** a real-cash economy, deeds, land areas with tax. **Real-money economy: n.a., HARD-disabled.**
- **Active Worlds:** building with object paths, world servers, a teleport/warp grid, citizen/tourist tiers, and universe-level world hosting.

## 2. What dev shipped in this branch (system side)

| Tracker | System | File | Notes |
|---|---|---|---|
| SBX-1 | SandboxGate (verb -> Tiers action map, owner verbs) | `scripts/sandbox/sandbox_gate.gd` | No new Tiers actions; owner verbs need owner session + owner actor |
| SBX-2 | Quest / mission engine | `scripts/sandbox/quest_engine.gd`, `data/sandbox/quests.json` | Objectives (collect, visit, talk, use, build, deliver, defeat, photo, custom); any/sequence order; optional objectives; prereqs; branches (`next`); timed missions with timeout and leave-region fail; repeatables with cooldown; creator-authored drafts, owner publishes; journal and track API; play-token rewards; Aethel rewards refused (LATER) |
| SBX-3 | On-demand worlds + region bundles | `scripts/sandbox/world_host.gd` | stored -> starting -> running -> stopping; spin-up/idle timers; keep-awake schedules; phone budget (MAX_RUNNING, least-recently-visited empty region sleeps first); `viper-region-bundle` v1 export with an export report and import (owner only); people lists never exported; designed to share fields with the OAR converter plan in OPENSIM_OAR_AUROS.md |
| SBX-4 | Inventory migration | `scripts/sandbox/inventory_migration.gd` | OpenSim mask bits (transfer 0x2000, modify 0x4000, copy 0x8000) or CMT text; conservative carry-over (next owner = owner AND next-owner); migrate only your own creations, full-perm or export-flagged items; scripts flagged `needs_port`; old-grid names dropped; dry run; idempotent re-runs; owner can migrate for a member |
| SBX-5 | Market delivery + magic box | `scripts/sandbox/market_delivery.gd` | Derived product perms; draft/active/paused; delivery to the Received folder; gifts need transfer; off-grid boxed + accept, needs export; redelivery; magic box on a buildable parcel shows live stock; fixed-price Aethel through AethelLedger (price shown, 13+, launch country, spend limit); chance-won items can't be listed |
| SBX-6 | Region rental + visitor meter | `scripts/sandbox/region_rental.gd` | Terms per minute, hour, day or week; min and max units; leases add the renter to the allowed list and allow_build, renewals extend, expiry takes access back; priced rent only quotes (LATER, LEGAL REVIEW); owner hand-grant; per-visitor minute meter that reports only |
| SBX-7 | Free-play chance games | `scripts/sandbox/free_play.gd` | Server-side odds plus a public odds table; earned play tokens only; prizes are play tokens or account-bound cosmetics; casino-style 18+; every roll is audit-logged |
| SBX-LEGAL-1..5 | Legal gates + ledgers | `scripts/economy/legal_review.gd`, `play_tokens.gd`, `aethel_ledger.gd`, `spend_limits.gd` | See LEGAL_REVIEW_GATES.md |

## 3. Parity table (sandbox section)

| Source | Feature | Viper status | Owner | Tracker |
|---|---|---|---|---|
| The Sims | Decaying needs/motives drive actions | planned | Foxy | SBX-F1 |
| The Sims | Moodlets -> emotion, gating interactions | planned | Foxy | SBX-F1 |
| The Sims | Traits, aspirations, likes/dislikes | partial (DNA traits, persona) | Foxy | SBX-F1 |
| The Sims | Friendship + romance axes, family tree | planned | Foxy | SBX-F1 |
| The Sims | Careers with levels and daily tasks | missing (quest engine can model job tasks) | dev | SBX-12 |
| The Sims | Skill-by-use with level gates | partial (SkillByUse scaffold) | Foxy | SBX-F5 |
| The Sims | Household funds, bills, roommates | missing | Foxy | SBX-F2 |
| The Sims | Build/buy mode, catalog, blueprints | partial (voxel build, estate) | Foxy | SBX-F2 |
| The Sims | Shared gallery for lots and characters | partial (region bundle + portable avatar file) | dev | SBX-3 |
| The Sims | Autonomy / free-will levels | partial (companion free roam) | Foxy | SBX-F1 |
| The Sims | Seasons, weather, holidays | partial (weather fx) | dev | SBX-22 |
| GTA III / VC / SA / IV / V | Drivable vehicles, classes, damage, garages | missing | Foxy | SBX-F3 |
| GTA | Vehicle customisation shops | missing | Foxy | SBX-F3 |
| GTA | Missions, contacts, chains, timed objectives, fail states | have | dev | SBX-2 |
| GTA | Side jobs (taxi, delivery, rescue) as repeatables | have (repeatable quests) | dev | SBX-2 |
| GTA | Wanted level / heat | n.a. by default; non-lethal heat only where allow_damage | Foxy | SBX-F13 |
| GTA San Andreas | Gang territory, takeover waves, respect meter | missing (estate groups exist) | dev | SBX-14 |
| GTA San Andreas | Recruitable followers capped by respect | planned | Foxy | SBX-F8 |
| GTA San Andreas | Body stats from diet/exercise, stamina, lung capacity | planned | Foxy | SBX-F5 |
| GTA | Radio stations in vehicles, custom track station | partial (music radio, SoundCloud) | Foxy | SBX-F10 |
| GTA | Safehouses as save/respawn points | partial (home/landmarks) | Foxy | SBX-F2 |
| GTA | Businesses with income | missing (Aethel income LEGAL REVIEW) | dev | SBX-17 |
| GTA V / Online | Heists: setup + finale, crew roles, approach choices | missing (quest prereqs + branches are the base) | dev | SBX-16 |
| GTA | In-world phone hub (contacts, jobs, browser) | planned | Foxy | SBX-F4 |
| GTA Online | Passive mode | have (damage off by default per estate) | dev | — |
| GTA Online | Jobs made by players in a content creator | partial (creator-authored quests, owner publishes) | dev | SBX-2 |
| GTA V | Stock market | n.a. (speculation with currency, HARD-disabled exchange) | dev | SBX-LEGAL-1 |
| Skyrim | Skill-by-use + perk trees + character level | partial (SkillByUse scaffold) | Foxy | SBX-F5 |
| Skyrim | Smithing, alchemy, enchanting, cooking | missing | Foxy | SBX-F6 |
| Skyrim | Joinable factions with questlines and ranks | partial (Social groups + quest prereqs) | dev | SBX-14 |
| Skyrim | Followers with commands, marriage | partial (companions) | Foxy | SBX-F8 |
| Skyrim | Shouts / powers with cooldowns | partial (fire bolt) | Foxy | SBX-F7 |
| Skyrim | Topic dialogue with checks | planned | Foxy | SBX-F9 |
| Skyrim | Radiant (generated) quests | missing (definitions are data, generator later) | dev | SBX-12 |
| Skyrim | Quest journal + quest marker | have (journal/track API); UI planned | Foxy | SBX-F9 |
| Skyrim | Mods / load order / creation kit | missing | dev | SBX-19 |
| Skyrim | Mounts | planned | Foxy | SBX-F8 |
| League of Angels | Formation party combat, guardian buffs slots | planned | Foxy | SBX-F8 |
| League of Angels | Guild level, donations, wages, guild store | missing (wages/currency LEGAL REVIEW) | dev | SBX-14 |
| League of Angels | Idle / offline progression | missing | dev | SBX-15 |
| League of Angels | Dailies + login streaks | partial (repeatable quests); play-token daily source missing | dev | SBX-12 |
| League of Angels | Paid gacha recruitment | n.a. now; LATER (paid_loot_box flag off, LEGAL REVIEW) | dev | SBX-LEGAL-1 |
| League of Angels | Free draws with earned tokens | have (free play) | dev | SBX-7 |
| Game of Thrones Slots Casino | Reel machines, bonus rounds | have (free-play reels, 18+, play tokens only) | dev | SBX-7 |
| Game of Thrones Slots Casino | Published odds | have (FreePlay.odds) | dev | SBX-7 |
| Game of Thrones Slots Casino | Daily free coin / timed bonus | n.a. (refills refused; tokens only from play) | dev | SBX-LEGAL-2 |
| Game of Thrones Slots Casino | Buying coins for slots | n.a. (HARD: play_token_purchase, coin_wager) | dev | SBX-LEGAL-1 |
| Game of Thrones Slots Casino | Collections, albums, quests, seasons | partial (quests); collections missing | dev | SBX-12 |
| Game of Thrones Slots Casino | Alliances + leaderboards | partial (Social groups) | dev | SBX-14 |
| Game of Thrones Slots Casino | Slots UI with odds panel + age gate | planned | Foxy | SBX-F12 |
| InWorldz | Copy/modify/transfer + next-owner perms | have (Marketplace perms, migration carry-over) | dev | SBX-4 |
| InWorldz | Inventory migration after a grid closes | have | dev | SBX-4 |
| InWorldz | Own script engine | partial (no LSL; scripts flagged needs_port) | dev | SBX-18 |
| InWorldz | Region rental, land tiers | have (free terms + owner grant); paid LATER | dev | SBX-6 |
| InWorldz Marketplace | Web store -> in-world inventory delivery | have | dev | SBX-5 |
| Kitely | On-demand regions (sleep/wake) | have | dev | SBX-3 |
| Kitely | Per-minute visitor billing | partial (meter only; aethel_metering LATER) | dev | SBX-6 |
| Kitely | World export/import + export report | have (Viper region bundle) | dev | SBX-3 |
| Kitely | OAR file import/export | planned | dev | SBX-9 |
| Kitely Market | Derived product permissions | have | dev | SBX-5 |
| Kitely Market | Export permission per product | have | dev | SBX-5 |
| Kitely Market | Delivery to other grids (boxed + accept) | have (local model); cross-grid protocol planned | dev | SBX-11 |
| Kitely Market | Gift delivery, redelivery, test delivery | have (gift, redeliver); test delivery missing | dev | SBX-5 |
| Kitely Market | Magic box / in-world vendor | have | dev | SBX-5 |
| Minecraft | Voxel mine/build | have | dev | — |
| Minecraft | Crafting recipes, smelting | planned | Foxy | SBX-F6 |
| Minecraft | Redstone-style logic | missing | dev | SBX-18 |
| Minecraft | Survival / creative / adventure modes | partial (estate allow_damage, build rules) | dev | SBX-20 |
| Minecraft | Villager trading | partial (vendors, magic box) | dev | SBX-5 |
| Minecraft | Servers, plugins, datapacks | missing | dev | SBX-19 |
| Minecraft | Realms (hosted worlds) | have (on-demand worlds) | dev | SBX-3 |
| Roblox | Games made by users with scripting | missing | dev | SBX-18 |
| Roblox | Private servers / instances | partial (estate access lists) | dev | SBX-3 |
| Roblox | Badges | missing | dev | SBX-12 |
| Roblox | Parental controls + age-gated experiences | partial (LegalReview age gates, mature flag) | dev | SBX-LEGAL-1 |
| Roblox | Game passes / dev products | partial (fixed-price items only) | dev | SBX-5 |
| No Man's Sky | Procedural planets, cross-planet travel | partial (realms, star map plan) | dev | — |
| No Man's Sky | Base + ship building | partial (voxel build) | Foxy | SBX-F2 |
| No Man's Sky | Guild missions, expeditions | have (quests); co-op expeditions missing | dev | SBX-16 |
| Rust | Base upkeep/decay, building privilege | partial (estate build rights); decay missing | dev | SBX-20 |
| Rust | Raids, wipes | n.a. by default (only where allow_damage) | dev | — |
| Valheim | Comfort / rested buffs | planned | Foxy | SBX-F1 |
| Valheim | Boss-gated tiers | have (quest prereqs) | dev | SBX-2 |
| Valheim | Portals with carry rules | partial (teleport); carry rules missing | dev | SBX-20 |
| Garry's Mod | Physics sandbox tools | partial (physics props) | Foxy | SBX-F2 |
| Garry's Mod | Game modes + addon workshop | missing | dev | SBX-19 |
| Fallout | Perk cards / SPECIAL | planned | Foxy | SBX-F5 |
| Fallout | Settlement building | partial (city building plan) | Foxy | SBX-F2 |
| Fallout | Faction reputation | partial (quest rewards carry reputation deltas) | dev | SBX-14 |
| Fallout | Companion affinity | planned | Foxy | SBX-F1 |
| Red Dead Online | Roles with ranks | missing (quest lines per role) | dev | SBX-12 |
| Red Dead Online | Camps, horse bonding | planned | Foxy | SBX-F8 |
| Red Dead Online | Honor / morality meter | missing | Foxy | SBX-F1 |
| Animal Crossing | Real-time clock, seasons, daily respawn | partial (day cycle) | dev | SBX-22 |
| Animal Crossing | Museum / collections | missing | dev | SBX-12 |
| Animal Crossing | Island visits by code | partial (estate access) | dev | SBX-3 |
| Animal Crossing | Turnip-style price speculation | n.a. (HARD) | dev | SBX-LEGAL-1 |
| IMVU | Creator catalog with derivation and royalties | missing (Aethel royalties LEGAL REVIEW) | dev | SBX-17 |
| IMVU | Age-verified access pass | partial (age gates in LegalReview; verification missing) | dev | SBX-LEGAL-5 |
| Sansar | Scenes hosted on demand + events | have (on-demand worlds); events board BUILD-9 | dev | SBX-3 |
| VRChat | Instance types (public / friends+ / invite) | partial (access lists) | dev | SBX-3 |
| VRChat | Trust ranks + safety shields | partial (tiers, mute/block) | dev | — |
| VRChat | World SDK + scripting | missing | dev | SBX-18 |
| Decentraland | Parcel scenes + builder | partial (estate parcels, bundles) | dev | SBX-3 |
| Decentraland / The Sandbox | NFT land, wearables, tokens | n.a. (HARD: nft_blockchain) | dev | SBX-LEGAL-1 |
| The Sandbox | Voxel asset maker + game maker | partial (voxel build); game maker missing | dev | SBX-18 |
| Entropia Universe | Real-cash economy, deeds | n.a. (HARD: real_money_gaming, aethel_cashout) | dev | SBX-LEGAL-1 |
| Entropia Universe | Land areas with owner tax | partial (rental terms); tax missing | dev | SBX-6 |
| Active Worlds | World servers, universe hosting | have (on-demand worlds) | dev | SBX-3 |
| Active Worlds | Citizen / tourist tiers | have (Tiers guest/resident) | dev | — |
| Active Worlds | Object-path building | have (voxel + props) | dev | — |
| All | Character creator | partial (avatar DNA) | Foxy | SBX-F11 |
| All | Mission HUD markers, heat, minimap pins | planned | Foxy | SBX-F13 |

## 4. Top remaining gaps (dev side, ranked)
1. **SBX-10:** the grid-server authority. QuestEngine, FreePlay, the ledgers and LegalReview run on the device now, so they have to move behind the grid server before anything multi-user or money-related ships.
2. **SBX-9:** OAR converter in both directions, mapped to the bundle fields.
3. **SBX-11:** cross-grid delivery protocol (signed order plus accept link).
4. **SBX-18:** UGC game modes and scripting (LSL port path, logic blocks).
5. **SBX-16:** co-op missions and heist-style crews (multiplayer quest state).
6. **SBX-14:** group/faction progression, territory and reputation.
7. **SBX-12:** generated quests, achievements, badges, collections and earned play-token sources.
8. **SBX-15:** idle/offline companion progression.
9. **SBX-20:** survival rules per estate (decay/upkeep, portal carry rules, modes).
10. **SBX-17:** businesses and creator royalties. LEGAL REVIEW: these need Aethel income rules.
