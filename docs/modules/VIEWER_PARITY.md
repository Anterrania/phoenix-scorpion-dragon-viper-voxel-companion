# Viewer & grid feature parity (the only parity table)

Status: living document, VIEWER-1 (Phoenix standing directive, 2026-10-17). Owners: us (admin, server,
systems, wiki) and Foxy (client HUD and build). Foxy fills in `ours` and `status` on her rows after v0.12.

**Rules.** Features only. Every description here is our own wording. No wiki text, product names in UI,
art or code is copied. Firestorm and the SL viewer are LGPL-2.1, so we take concepts only and keep a
clean-room implementation. DarkStorm is a copybot-style fork (see "DarkStorm" below): its content-copying
features are **won't build**.

**Columns.** `feature | Firestorm | Phoenix | DarkStorm | Avination | OLG 3DX | ours | owner | status`
- Source cells: ✓ = the source documents it; a short note = it documents a variant; `?` = not verified;
  `—` = not documented / not applicable; `pending research` = rows still coming from another worker.
- `ours`: evidence in this repo (file or menu path). `status`: have · partial · missing · planned ·
  n/a (doesn't apply to a phone voxel world) · won't (unsafe or content theft).
- Priority: P0 safety/ownership, P1 core parity, P2 nice to have, P3 later/grid.

**Sources and limits.** wiki.firestormviewer.org sits behind a bot check and refused every automated
fetch (WebFetch and curl both got the challenge page, 2026-10-17). Firestorm rows come from the public
mirror of its wiki pages, the Second Life wiki (About Land, Estate Menu, RLV API) and long hands-on
knowledge of the viewer. Phoenix Viewer (Firestorm's V1-era predecessor, discontinued) rows are from
community write-ups; anything not confirmed is `?`. Avination and Open Life Grid 3DX rows are owned by the
docs/virtual-world-gap worker and were not on that branch yet, so they read `pending research`. Space-sim
rows (Dual Universe, EVE Online, Star Citizen) belong to feature/spacesim-parity: see "Space sims".

---

## Firestorm / Phoenix / DarkStorm

### Land: About Land (parcel) — ours

| feature | Firestorm | Phoenix | DarkStorm | Avination | OLG 3DX | ours | owner | status |
|---|---|---|---|---|---|---|---|---|
| Parcel name, description, category | ✓ General tab | ✓ | ✓ (FS 4.5 base) | pending research | pending research | `ParcelTools.set_general`, MENU > ⚖ Land & Safety > Land | us | have (P1) |
| Parcel owner, group, area, claimed date | ✓ | ✓ | ✓ | pending research | pending research | `ParcelTools.general` (owner_id, group via `Tiers.land_group`, 64 m grid = 4096 m²) | us | partial: no claimed date |
| Land for sale / deed to group / abandon | ✓ | ✓ | ✓ | pending research | pending research | sale fields stored, price **INACTIVE** (Aethel Coin + LEGAL REVIEW); group claim = `Social.group_claim_land` | us | partial (P2) |
| Covenant view | ✓ Covenant tab | ✓ | ✓ | pending research | pending research | gap worker: `Estate.set_covenant` (docs/virtual-world-gap, not on main yet) | us (gap) | planned |
| Object counts by owner / group / others | ✓ Objects tab | ✓ | ✓ | pending research | pending research | `ParcelTools.object_counts` (land impact), Land & Safety > Objects | us | have |
| Return objects (by owner, by class) to Lost and Found | ✓ | ✓ | ✓ | pending research | pending research | `ParcelTools.return_objects` → per-owner Lost and Found, never deleted | us | have |
| Auto-return after N minutes | ✓ | ✓ | ✓ | pending research | pending research | `ParcelTools.set_auto_return` + `auto_return_sweep` | us | have |
| Object registry (build engine reports rezzes) | n/a (server) | n/a | n/a | — | — | `ParcelTools.register_object` (Foxy's build tools call it) | us → Foxy calls | have (API) |
| Options: build, scripts, fly, push, landmarks, object entry, damage, voice, search | ✓ Options tab | ✓ | ✓ | pending research | pending research | `Estate` allow_fly/build/damage on main; push/scripts/landmark/entry/voice/search flags on docs/virtual-world-gap | us (gap) | partial |
| Landing point + teleport routing (anywhere / landing point / blocked) | ✓ | ✓ | ✓ | pending research | pending research | `ParcelTools.set_options`, `teleport_target` | us | have (consumer: teleport) |
| Avatars visible from outside the parcel / avatar sounds | ✓ (newer SL) | — | — | pending research | pending research | `see_avatars`, `avatar_sounds` stored | us + Foxy renders | partial |
| Parcel media URL, loop, auto-scale, description | ✓ Media tab | ✓ | ✓ | pending research | pending research | `ParcelTools.set_media` (http/https only, 1 KB cap) | us | have (data) |
| Parcel music stream URL | ✓ Sound tab | ✓ | ✓ | pending research | pending research | `Estate` music_url → `MusicRadio`; validated via `set_media` | us | have |
| Access: public / group / allow list / owner only | ✓ Access tab | ✓ | ✓ | pending research | pending research | `Estate.ACCESS` + `Tiers._land_ok`; `ParcelTools.set_access` | us | have |
| Allow / ban lists with add/remove | ✓ | ✓ | ✓ | pending research | pending research | `ParcelTools.allow/disallow/ban/unban` (300 cap) | us | have |
| Timed bans (hours) | ✓ | ? | ? | pending research | pending research | `ParcelTools.ban(..., hours)` + `sweep_bans` | us | have |
| Block entry: no payment info / not age-verified | ✓ | ✓ | ✓ | pending research | pending research | `adult_only` + `entry_ok(adult)`; payment info n/a | us | partial: no age verification service yet |
| Sell access passes | ✓ | ✓ | ✓ | pending research | pending research | pass fields stored, **INACTIVE** (coin + legal) | us | planned (P3) |
| Experiences allow/block | ✓ | — | — | pending research | pending research | — (we have no experiences system) | us | n/a for now |
| Parcel environment (sky/water) | ✓ Environment tab | windlight per parcel ? | ? | pending research | pending research | region sun/water in `Estate`; presets in `EnvPresets` | us + Foxy UI | partial |
| Traffic / dwell stats | ✓ | ✓ | ✓ | pending research | pending research | — | us | planned (needs server) |

### Region / Estate — ours

| feature | Firestorm | Phoenix | DarkStorm | Avination | OLG 3DX | ours | owner | status |
|---|---|---|---|---|---|---|---|---|
| Estate managers list | ✓ Estate tab | ✓ | ✓ | pending research | pending research | `ParcelTools.add_manager/remove_manager` (owner only, max 15, no companions) | us | have |
| Estate-wide access + ban list | ✓ Access tab | ✓ | ✓ | pending research | pending research | region-level `Estate` allowed/banned + `ParcelTools` with parcel "" | us | have |
| Estate message to everyone in the region | ✓ | ✓ | ✓ | pending research | pending research | `ParcelTools.estate_message` (local log until grid) | us | partial |
| Region restart / delay restart | ✓ Debug tab | ✓ | ✓ | pending research | pending research | `ParcelTools.region_debug` **INACTIVE** stub | us | planned (server) |
| Kick / teleport home a user, freeze | ✓ | ✓ | ✓ | pending research | pending research | stub (offline build has no other avatars) | us | planned (server) |
| Top scripts / top colliders, disable scripts/physics/collisions | ✓ | ✓ | ✓ | pending research | pending research | stub; gap branch adds `physics_enabled` | us | planned (server) |
| Terrain textures, heights, water height, raise/lower limits | ✓ Terrain tab | ✓ | ✓ | pending research | pending research | `Estate` land_texture, water_height; `Terraform` | us | have |
| Fixed sun / day cycle | ✓ | ✓ | ✓ | pending research | pending research | `Estate` sun_fixed, sun_hour, day_length_h | us | have |
| Maturity rating, agent limit, resell, join/divide | ✓ Region tab | ✓ | ✓ | pending research | pending research | docs/virtual-world-gap estate flags | us (gap) | planned |
| Covenant editor | ✓ Covenant tab | ✓ | ✓ | pending research | pending research | docs/virtual-world-gap `Estate.set_covenant` | us (gap) | planned |

### Moderation & personal safety — ours

| feature | Firestorm | Phoenix | DarkStorm | Avination | OLG 3DX | ours | owner | status |
|---|---|---|---|---|---|---|---|---|
| Block list (avatar / object / group) | ✓ People > Block List | ✓ mute list | ✓ | pending research | pending research | `ModerationLists.block` = `Social.block` + mute all | us | have (P0) |
| Partial mute (chat / voice / sounds / particles) | ✓ | ? | ? | pending research | pending research | `ModerationLists.mute(channels)` | us | have |
| Mute filter for chat / IM | ✓ | ✓ | ✓ | pending research | pending research | `ModerationLists.filter_lines` (chat UI hook for Foxy) | us + Foxy | have (API) |
| Derender temporary / permanent (asset blacklist) | ✓ World > Asset Blacklist | ? | ✓ | pending research | pending research | `ModerationLists.derender(permanent)`, Land & Safety > Safety | us; renderer skip = Foxy | have (data) |
| Re-render temporary derenders after teleport (pref) | ✓ | — | ? | pending research | pending research | `set_rerender_after_tp`, `on_teleport` hooked in `ui_root.teleport` | us | have |
| Report abuse | ✓ | ✓ | ✓ | pending research | pending research | `Social.report` + Community > Reports | us | have |
| Spam protection (IM/dialog/inventory floods) | ✓ | ✓ | ? | pending research | pending research | — | us | missing (P1, follow-up) |
| Keyword alerts in chat | ✓ | ✓ | ? | pending research | pending research | — | Foxy (chat UI) | missing (P2) |
| Autoresponse / busy / away | ✓ | ✓ | ? | pending research | pending research | — | Foxy (chat) + us (store) | missing (P2) |

### Restrictions (RLV-style) — ours

| feature | Firestorm | Phoenix | DarkStorm | Avination | OLG 3DX | ours | owner | status |
|---|---|---|---|---|---|---|---|---|
| Opt-in restriction API | ✓ RLVa (pref, off by default) | ✓ RLVa | ? | pending research | pending research | `Restrictions` (docs/modules/RESTRICTIONS.md) | us | partial: API + admin, consumers via patch |
| Prevent-only behaviours (fly, landmarks TP, map TP, chat send, IM send, rez, edit, inventory, minimap, map, location, names, stand, far touch) | ✓ | ✓ | ? | pending research | pending research | `Restrictions.BEHAVIOURS` | us | have (data) |
| Forced actions (force TP, force sit, attach/detach, outfit, chat redirect) | ✓ | ✓ | ? | — | — | **won't**: not built on purpose | us | won't |
| Per-source consent, safeword, owner override, e-stop | partial (RLVa has no global safeword) | ? | ? | — | — | `consent`, `safeword`, `owner_clear_all`, `set_global_off`, `AutonomyGuard` | us | have |
| Active restrictions list | ✓ RLVa Active Commands floater | ? | ? | — | — | Land & Safety > Limits | us | have |

### Client HUD, floaters, preferences — Foxy

Foxy owns these rows completely, data included. `ours`/`status` are hers to fill after v0.12; what is
written below is only what exists in the repo today. The reference column describes what viewers offer.

| feature | Firestorm | Phoenix | DarkStorm | Avination | OLG 3DX | ours | owner | status |
|---|---|---|---|---|---|---|---|---|
| People radar: name, distance, age, seen time, alerts on enter/leave, actions (IM, profile, TP to, zoom, ban/eject for land owners) | ✓ | ✓ (the original radar) | ✓ | pending research | pending research | MENU > ◉ Nearby (`ui_root._build_radar`, companions + creatures) | Foxy | partial |
| Area search: find objects by name/desc/owner/group, filters, beacons, walk/TP to | ✓ | ✓ | ✓ | pending research | pending research | — | Foxy | missing |
| Quick prefs: graphics preset, draw distance, environment preset, avatar complexity cap, shadows | ✓ | — | ✓ | pending research | pending research | `Settings.QUALITY` Low/Med/High, MENU > ☀ Environment | Foxy | partial |
| Graphics prefs → Mobile renderer presets with per-setting clamps (draw distance, LOD, shadows, render scale, FPS cap) | ✓ (desktop) | ✓ | ✓ | — | — | `Settings.QUALITY` table | Foxy (phone worker on scale) | partial |
| Camera floater + flycam, camera presets, mouselook, orbit/pan | ✓ | ✓ | ✓ | — | — | `hud.gd` CameraToggle | Foxy | partial |
| Build / edit floater tabs: General, Object, Features, Texture, Content | ✓ | ✓ | ✓ | — | — | build HUD on v0.12 branch | Foxy | planned (spec below) |
| Prim torture (taper, twist, hollow, path cut) → voxel shape tools (extrude, bevel, hollow, mirror, lathe) | ✓ prims | ✓ | ✓ | — | — | `Terraform.OPS`, v0.12 build tools | Foxy | planned |
| Align tool, grid options (size, snap, local/world/reference), link / unlink, linkset view | ✓ | partial | ✓ | — | — | — | Foxy | planned (spec below) |
| Export / copy someone else's content | — | — | ✓ (copybot) | — | — | **won't** | — | won't |
| Export your own builds (with full perms) | ✓ (own creations only) | ✓ | ✓ | pending research | pending research | interop worker: OAR/IAR | us (gap) | planned |
| Poser + AO (stands, walks, sits, typing, swim, fly sets) | ✓ AO + poser | ✓ AO | ✓ AO | — | — | — | Foxy | missing |
| Contact sets (colour-coded friend groups) | ✓ | — | ? | — | — | `Social.friends_of` is the data source | Foxy | missing |
| Minimap upgrades: parcel lines, for-sale overlay, avatar dots, zoom, rotate | ✓ | ✓ | ✓ | — | — | `scripts/ui/minimap.gd` | Foxy | partial |
| World map: regions, events, land for sale, TP | ✓ | ✓ | ✓ | pending research | pending research | `world_map_view.gd`, MENU > ◎ World Map | Foxy | partial |
| Teleport history + landmarks bar + favourites | ✓ | ✓ | ✓ | pending research | pending research | gap branch `scripts/world/landmarks.gd` (uncommitted); MENU > 🗺 Destinations | Foxy (data from gap) | planned |
| Inventory: filters, recent, worn, search, folders, outfits | ✓ | ✓ | ✓ | — | — | MENU > 👜 Wardrobe; `Inventory` autoload | Foxy | partial |
| Media / parcel stream bar (play, pause, volume, now playing) | ✓ | ✓ | ✓ | — | — | MENU > ♪ Music (`MusicRadio`) | Foxy | partial |
| Snapshot floater (to album, to disk, sizes, hide UI) | ✓ | ✓ | ✓ | — | — | Social snapshot-to-album on Foxy's list | Foxy | planned |
| Local textures (preview your own image on a face before upload) | ✓ | — | ? | — | — | — | Foxy | missing (P2) |
| Chat prefs: timestamps, bubbles, typing indicator, IM logs (encrypted) | ✓ | ✓ | ✓ | — | — | `floating_text.gd` bubbles; chat in `ui_root` | Foxy | partial |
| Menu search, pie / radial menus | ✓ | ✓ pie | ✓ pie | — | — | radial launcher (`viper_radial.gd`) | Foxy | partial |
| Beacons, property lines, ban lines | ✓ | ✓ | ✓ | — | — | — | Foxy | missing |
| Skins / UI modes (V1-style, compact) | ✓ | — | — | — | — | Phoenix Glass compact default + Large toggle (phone worker) | Foxy | partial |

### Menus (map, not separate features)

| menu | what viewers put there | where it lands for us |
|---|---|---|
| Avatar | appearance, outfits, AO, poser, movement, health, profile | Avatar, Wardrobe (Foxy); profile = Community |
| Comm | friends, groups, contact sets, IM, voice, block list, conversation log | Community (us), Land & Safety > Safety (us), voice (phone worker) |
| World | about land, region/estate, teleport history, landmarks, map, minimap, area search, environment, asset blacklist | Land & Safety + Region / Estate (us), map/TP/search (Foxy) |
| Build | edit floater, align, grid, link, upload, pathfinding | Foxy's build HUD; uploads gated by `Tiers.can(…, "upload")` |
| Content | marketplace, search, destinations, events | Marketplace (economy), Destinations, events (Social roadmap) |
| Advanced / Developer | render toggles, debug settings, stats, rebake, UI tests | Viper Admin (us) debug cards; render toggles = Foxy |

### DarkStorm

DarkStorm was a 2014 fork of Firestorm 4.5.2 for SL and OpenSim. What we could verify: its release notes
list an AO fix, multi-perms, HPA import, an OpenSim grid manager, an object pie menu, unlocked Collada and
linkset export, inventory asset-UUID copy and login spoofing. It was widely reported as a copybot tool
against SL's terms. **We build none of the copying, export-others' or spoofing features.** The ordinary
items (AO, pie menu, grid manager) are already Firestorm rows above. No wiki or manual was found, so every
other DarkStorm cell is `?`.

---

## Grid side (Avination / Open Life Grid 3DX / OpenSim grids)

| feature | Firestorm | Phoenix | DarkStorm | Avination | OLG 3DX | ours | owner | status |
|---|---|---|---|---|---|---|---|---|
| Currency buy/sell + balance + transaction history | ✓ (client UI) | ✓ | ✓ | pending research | pending research | `CurrencyExchange`, `Ledger` — LEGAL REVIEW required | us | partial |
| Marketplace / in-world vendors / delivery | ✓ (web + client) | — | — | pending research | pending research | `Marketplace`, `VendorStub` | us | partial |
| Land sales and rentals (rental boxes, tiers, renew) | ✓ (via scripts) | ✓ | ✓ | pending research | pending research | sale fields INACTIVE; rentals in BUILD_TOOLS_AND_TIERS.md (audit worker) | us | planned |
| Events listing + calendar + notices | ✓ Search > Events | ✓ | ✓ | pending research | pending research | Welcome Island events; `Social.event_create` INACTIVE stub | us | partial |
| Group tools: roles, notices, land, chat, enrolment fee | ✓ | ✓ | ✓ | pending research | pending research | `Social` groups, roles, notices, `group_claim_land` | us | partial: no group chat/fee |
| Hypergrid / OSgrid-style travel and foreign identity | ✓ (OpenSim build) | ✓ | ✓ | pending research | pending research | INTEROP.md (gap worker) | us (gap) | planned |
| Grid manager (multiple grids in login) | ✓ | ✓ | ✓ | pending research | pending research | — | us (gap) | planned (P3) |
| Offline IM delivery | ✓ | ✓ | ✓ | pending research | pending research | `Social.send_message` outbox + `flush_outbox` | us | have (local) |
| Profiles + picks + classifieds | ✓ | ✓ | ✓ | pending research | pending research | `Social.profile`, picks; classifieds INACTIVE | us | partial |
| Search (places, people, groups, land) | ✓ | ✓ | ✓ | pending research | pending research | `show_in_search` flag (gap); no search service | us | planned |

## Space sims

Dual Universe, EVE Online and Star Citizen. Concepts only, our own names. Source of truth and priorities:
[SPACESIM_PARITY.md](SPACESIM_PARITY.md). Coin settlement, upkeep and payouts stay off (LEGAL REVIEW REQUIRED).
The star map and route planner are Foxy's (patches/foxy/FRONTIER_CLIENT_SPECS.md).

| feature | source | ours | owner | status |
|---|---|---|---|---|
| Voxel terrain dig/fill tools | DU | `scripts/world/terraform.gd` raise/lower/flatten/smooth/noise/revert on smooth SDF; phone brush | us | built |
| Voxel construct building (cores, voxel hulls, elements) | DU | none in scripts; build tools queued (BUILD-*); phone: tap-place blocks on a construct grid | Foxy | missing · P1 |
| Construct blueprints (save/paste a build) | DU | none; Industry blueprints cover recipes only; phone: "save build" to Satchel | Foxy | missing · P1 |
| Element system (engines, containers, screens, doors) | DU | none; phone: elements = props with a small action list (`scripts/world/prop_kit.gd` style) | Foxy | missing · P2 |
| Lua scripting on control units | DU | docs only (`SMARTBOT_AND_SCRIPTING.md`, `SECOND_LIFE_SCRIPTING.md`); phone: sandboxed script cards, owner approval | us | missing · P2 |
| Territory tiles + claim beacon | DU | `Territory.claim` on Estate parcels (64 m tile), regions opened via Estate `allow_claims` | us | built |
| Territory upkeep / tax + grace | DU | `Territory.renew`, grace `GRACE_DAYS`; coin upkeep INACTIVE (LEGAL REVIEW REQUIRED) | us | partial · P1 |
| RDMS policies (actors, rights, tags) | DU | `OrgRights.add_policy` / `allowed` with org/member/friends/all actors and tags | us | built |
| Organisations with legates / super legate | DU | Social groups (owner/officer/member) + `OrgRights` titles | us | built |
| Org polls + news bulletins | DU | Social `group_notice` built; polls are Social roadmap stubs (`poll_create` INACTIVE) | us | partial · P2 |
| Markets on planets (buy/sell orders) | DU | `OrderBook` per item + location (region id or global) | us | built |
| Industry units + schematics | DU | `Industry.start` jobs + blueprint gate (`needs_blueprint`) | us | built |
| Industry talents (speed/efficiency) | DU | TE/ME research on blueprints; talents → future skills queue | us | partial · P2 |
| Mining units + ore pools per tile | DU | `Industry.add_materials` hook + Territory `mine` right; pools missing | us | missing · P2 |
| Planets + moons, seamless space-surface | DU | 3 built realms (`map_data.gd` REALMS), `data/frontier/planets.json`; seamless transition missing | Foxy | partial · P1 |
| Warp drive between bodies | DU | none; Foxy's star map + jump routes; phone: tap destination, confirm, short calm transition | Foxy | missing · P1 |
| Safe zones vs PvP space | DU | Estate `allow_damage` + `CombatZone` (Ember Arena); Territory contests only on damage land | us | built |
| Construct ownership trading | DU | `ShipRegistry` owners incl. `org:`; trading via contracts (item exchange) | us | partial · P2 |
| Abandoned construct reclaim | DU | none; would use ShipRegistry state + Territory release | us | missing · P3 |
| Market orders: buy/sell, range, duration | EVE | `OrderBook.place` days 0..90, location, partial fills | us | built |
| Broker fee + sales tax as sinks | EVE | `BROKER_BPS` 1%, `SALES_TAX_BPS` 2%, tracked in `sinks` | us | built |
| Contracts: item exchange, courier w/ collateral, auction | EVE | `ContractsBoard` kinds + auction extension + collateral (recorded only) | us | built |
| Contract availability public/private/corp | EVE | `availability` public / private:<id> / org:<gid> | us | built |
| Manufacturing jobs + job slots | EVE | `Industry` slots by tier (`SLOTS`), timed jobs run while app is closed | us | built |
| Blueprint originals vs copies; ME/TE research; copying | EVE | `Industry` original/copy, ME 0..10, TE 0..20, copy keeps research | us | built |
| Invention (T2 from copies) | EVE | none; tier-3 recipes exist (`jump_coil`); invention later | us | missing · P3 |
| Corporation roles (director, accountant, factory, station...) | EVE | `OrgRights.RIGHTS` (wallet_view, factory, station, diplomat...) | us | built |
| Titles = role bundles | EVE | `OrgRights.set_title` / `assign_title`; officers can't grant manage_titles | us | built |
| Alliances + executor corp | EVE | `OrgRights.alliance_*`, executor passes on leave | us | built |
| Corp wallet divisions | EVE | rights `wallet_view`/`wallet_take` exist; wallets INACTIVE (LEGAL REVIEW) | us | partial · P2 |
| Skills training queue (offline) | EVE | `skill_by_use.gd` (use-based only); queue missing; companions would share it | us | missing · P2 |
| Sovereignty (system ownership, upgrades) | EVE | `Territory.sovereign(region)` by claim share; upgrades missing | us | partial · P2 |
| Wormholes (unstable links, mass limits) | EVE | none; would be timed star-map links | Foxy | missing · P3 |
| Fleets (hierarchy, broadcasts, fleet warp) | EVE | none; Social groups + `fleet` org right only | us | missing · P2 |
| Overview (sortable nearby list) | EVE | `◉ Nearby` radar panel (`ui_root.gd` `_build_radar`); filters/columns missing | Foxy | partial · P2 |
| Neocom (side launcher menu) | EVE | MENU grid + radial launcher (`viper_radial.gd`); wrist hub spec for Foxy | Foxy | partial · P2 |
| Killmails | EVE | `ShipRegistry.report_loss` loss reports (no public board) | us | partial · P2 |
| Ship insurance levels | EVE | `ShipRegistry.INSURANCE` basic/plus/fleet, tier-gated; hull restore, no payouts | us | built |
| Standings / reputation | EVE | `ContractsBoard.reputation` per faction with ranks | us | built |
| Asset safety / hangar per station | EVE | `ShipRegistry` hangars + stow; item hangars missing | us | partial · P2 |
| mobiGlas wrist computer + apps | SC | design notes `MOBIGLASS_UI.md`; spec in FRONTIER_CLIENT_SPECS (original "wrist hub") | Foxy | missing · P1 |
| Contracts Manager app (general/personal/accepted/history/beacons) | SC | `ContractsBoard` (service = help beacon, private = personal); UI by Foxy | us | built |
| Quantum travel (spool, calibrate, jump) | SC | none; Foxy's star map; phone: hold to spool, calm streak effect (`ComfortPrefs.travel_fx`) | Foxy | missing · P1 |
| Server meshing (static → dynamic) | SC | `ShardModel` split/merge + instances; doc `SERVER_MESHING.md` | us | partial · P3 |
| Shards + persistent entity stow/unstow | SC | `ShardModel` + `ShipRegistry.stow/deploy` across shards | us | built |
| Ship MFDs (power, shields, comms, scan) | SC | none; spec for Foxy | Foxy | missing · P1 |
| Personal/physicalised inventory + cargo grid | SC | Inventory autoload + Satchel (`scripts/autoload/inventory.gd`); cargo grid missing | Foxy | partial · P2 |
| Freight elevator / hangar storage | SC | `ShipRegistry` hangars; elevator UI n/a on phone (a list instead) | Foxy | partial · P3 |
| Insurance claim timer + expedite | SC | `ShipRegistry.claim` timer by size × plan, expedite halves (fee 0) | us | built |
| Hangar (personal, persistent) | SC | `ShipRegistry` hangar "home"; in-world hangar scene missing | Foxy | partial · P2 |
| Missions with faction reputation ranks | SC | `ContractsBoard` mission kind + `REP_RANKS` | us | built |
| Crafting with blueprints from missions | SC | `Industry.grant_blueprint("system", ...)` hook; mission reward wiring later | us | partial · P2 |
| Star map (systems, routes, search) | SC | `STAR_MAP.md` notes; world map is 2D per realm (`world_map_view.gd`) | Foxy | missing · P1 |
| Party / friends / comms channels | SC | Social friends, messages, groups (`social.gd`) | us | built |
| Service beacons (pay for help) | SC | `ContractsBoard` kind `service` | us | built |
| Keybind profiles + remapping | SC | `ComfortPrefs` touch/keyboard/gamepad profiles, custom remaps, duplicate check | us | built |
| FOV / motion blur / head bob / comfort | SC | `ComfortPrefs` fov, vignette, snap turn, shake, head bob, motion blur, horizon lock, calm preset | us | built |
| Head/eye tracking | SC | n/a for now: phone front camera tracking is heavy and drains battery; revisit with the camera work | us | n/a |
| Graphics presets | SC/EVE | `Settings.QUALITY` low/med/high (`settings.gd`) | us | built |
| Scanner / ping overlay | SC | none; spec for Foxy | Foxy | missing · P2 |
| Docking + landing (ATC, pads) | SC | none; spec for Foxy | Foxy | missing · P1 |
| Co-pilot / crew AI | SC | companions exist (`companion_agent.gd`); co-pilot role is Foxy's | Foxy | partial · P2 |
| Planetary war + destruction | vision | `Territory.contest/resolve` on damage land; voxel destruction later | us | partial · P3 |
| Economy currency + exchange | all | `currency_exchange.gd` (pair), `OrderBook` (multi-item), `ledger.gd`; settlement off (LEGAL REVIEW REQUIRED) | us | partial · P1 |
| Player-run stations / structures | EVE/DU | Estate regions + `station` org right; structure services missing | us | missing · P3 |
| Cross-shard item transfer | SC | `ShipRegistry` stowed ships follow; items later | us | partial · P3 |
| Mining (handheld/ship) | SC/EVE | none; would feed `Industry.add_materials` | Foxy | missing · P2 |
| Salvage | SC | n/a for now: needs ship damage model first | us | n/a |
| Real-money ship sales / pledges | SC | n/a: never. No paid ships; all items are in-game only (ECONOMY.md rules) | us | n/a |
| PLEX-style time cards | EVE | n/a: no real-money items without legal review | us | n/a |
| Full-loot PvP everywhere | EVE | n/a: safe by default; PvP only on land marked damage-enabled | us | n/a |

See also: docs/FEATURE_ROADMAP_VIRTUAL_WORLDS.md, docs/modules/SOCIAL.md, docs/modules/RESTRICTIONS.md,
docs/wiki/viewer-features.md.

---

## Spec for Foxy (client UI parity)

Everything below follows the Phoenix Glass kit, `PhoenixTokens` sizes (compact default, TAP_MIN 56,
Large 80), portrait + auto-rotate, motion 180–240 ms ease-out, no bounce, at most one glow. Bottom sheets,
not floating windows. Max 5 tabs per `SwipePages`.

**1. Edit sheet (build/edit floater).** Tabs: *General · Object · Features · Texture · Content*.
- General: name, description, owner (read-only), group, permissions (next owner copy/modify/transfer),
  "for sale" (INACTIVE: coin + legal), click action. Write through the build engine; call
  `ParcelTools.register_object(owner, region, parcel, {name, impact, group})` on rez.
- Object: position, rotation, size (numeric fields + steppers, 0.1 m and 1 m), lock, physics, phantom,
  temporary. Voxel shape tools stand in for prim torture: extrude, bevel, hollow, mirror, lathe, smooth.
- Features: light (colour, radius, falloff), glow (one per object, respects the one-glow rule), flexi → cloth.
- Texture: voxel palette + material, repeats, offset, rotation, "local texture" preview (device-only,
  never uploaded until the owner confirms; uploads need `Tiers.can(actor, "upload")`).
- Content: scripts/companion behaviours attached to the object; read-only unless owner.
- Every action first asks `Tiers.can(actor, "build", {"region": r, "parcel": p})` and
  `not Restrictions.is_restricted(id, "edit"/"rez")`.

**2. Align + grid.** Align selected along X/Y/Z (min, centre, max), distribute evenly. Grid: size
(0.25/0.5/1/2/4 m), snap on/off, world / local / reference-object axes, sub-division lines while dragging.

**3. Link / unlink.** Link up to 256 voxel parts into one object; root part highlighted; unlink returns
parts in place. "Edit linked" toggle edits one part.

**4. Camera.** Orbit, pan, zoom pads; presets (rear, front, group shot, custom ×3); flycam via two-thumb
control; mouselook toggle; camera can't leave a parcel with `see_avatars` off.

**5. HUD radar.** Rows: name, distance, tier badge, status. Long-press: profile (`Social.profile`), IM,
mute/block (`ModerationLists`), derender, and for land managers ban/eject (`ParcelTools.ban`). Skip
anyone `ModerationLists.is_derendered`. Hide names when `Restrictions.is_restricted(self, "shownames")`.

**6. Minimap.** Parcel lines, for-sale overlay, avatar dots, zoom 3 steps, north-up / rotate toggle. Hidden
when `is_restricted(self, "showminimap")`.

**7. Safety hooks in her files** — `patches/viewer_parity_hud_hooks.patch`: makes `player.set_flying` honour
the `fly` restriction (one line). Checked with `git apply --check` on main and on feature/v012-avatar.
Still to wire on her side: `tplm` / `tploc` in landmark and map teleports, `sendchat`/`sendim` in chat,
`filter_lines` in nearby chat, derender skip in the renderer, `teleport_target` before teleports.
