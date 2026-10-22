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

Dual Universe, EVE Online and Star Citizen rows belong to the feature/spacesim-parity worker. That branch
wasn't on main when this was written. See also: `docs/modules/` on feature/spacesim-parity. Merge its rows
here, de-duplicated, when it lands.

See also: docs/FEATURE_ROADMAP_VIRTUAL_WORLDS.md, docs/modules/SOCIAL.md, docs/modules/RESTRICTIONS.md,
docs/wiki/viewer-features.md.

---

## Device compatibility

Our own code: DEVICE_COMPAT.md. Features only. The columns are the platforms we match; "ours" is the evidence.

| feature | Firestorm / SL viewer | Space sims (SC/EVE/DU) | mobile games baseline | ours | owner | status |
|---|---|---|---|---|---|---|
| Hardware detect + auto graphics preset on first run | ✓ (GPU table) | ✓ | ✓ | `DeviceProfile` + `DeviceCaps.score` → `AutoConfig` tier recommendation | us + Foxy (AutoQuality) | have |
| Manual preset always wins, reset to recommended | ✓ | ✓ | ✓ | `[compat]` prefs + last-auto rule, Reset to auto | us | have |
| UI scale by screen / form factor | ✓ (UI size pref) | ✓ | ✓ | `AutoConfig.UI_SCALE` (phone compact, TV 1.6×) | us + phone worker | have |
| Gamepad support with hot-plug | — | ✓ | ✓ | `input_scheme_of`, `joy_connection_changed`, pad events on move/jump | us; HUD = Foxy | partial (HUD) |
| Feature toggles by capability, with a reason | partial | ✓ | ✓ | `FeatureRegistry` | us | have |
| Thermal / FPS governor | — | partial | ✓ | Foxy AutoQuality (we pass the thermal level and profile) | Foxy | planned (v0.12+) |
| TV / 10-foot UI | — | — | partial | form_factor tv + gamepad | us + Foxy | partial |
| XR mode | ✓ (old SL VR mode) | ✓ (SC no; DU no; EVE no) | — | feature flag only | Foxy | planned (future) |

## Power & data

| feature | Firestorm / SL viewer | Space sims | social apps baseline | ours | owner | status |
|---|---|---|---|---|---|---|
| Battery saver mode (auto on low battery / power saver / heat) | — | — | ✓ | PowerData `saver` (POWER_AND_DATA.md) | us + Foxy | have (needs plugin for inputs) |
| Background pause + keepalive | ✓ (minimized FPS cap) | ✓ | ✓ | `background` mode + `Dormancy.set_background` | us | have |
| Data saver: low bitrate, no autoplay, thumbnails on cell | — | — | ✓ | `Net.set_data_mode`, Data saver Auto/On/Off | us; feed UI = Foxy | have |
| Defer large downloads to Wi-Fi, prefetch on charger | — | ✓ (launcher) | ✓ | `defer_large_downloads`, `prefetch` budgets | us | have (API) |
| HTTP caching (ETag / Last-Modified) | ✓ (asset cache) | ✓ | ✓ | `Net.request_headers` / `on_response` in MusicRadio + SoundCloud | us | have |
| Batched, compressed, delta network state | ✓ (UDP msg packing) | ✓ | ✓ | `Net.pack/unpack/delta` | us | have (API; grid sync to adopt) |
| Interest management: sleep with no viewer, cheap catch-up | ✓ (region idle) | ✓ (EVE/DU idle grids) | — | `Dormancy` | us; living-world / Vala / social adopt | have (API) |
| Session data usage readout | — | — | ✓ | Battery & data card | us | have |

## Scripting (Vala Script)

Details in VALA_SCRIPT.md. It's our own language and is not GNOME Vala.

| feature | SL / OpenSim (LSL, OSSL) | Dual Universe (Lua) | ours | owner | status |
|---|---|---|---|---|---|
| States + events + typed vars | ✓ | — | `.vscript` states/events | us | have |
| Element slots, tick/update/flush | — | ✓ | `slot x : door;` + unit events | us | have |
| Screens | prim media / text | screen units (HTML/Lua) | data-only draw ops, 320×180 | us; render = Foxy | have (render: Foxy) |
| Chat + listen channels | ✓ | — | say/whisper/shout/region_say/listen | us | have |
| HTTP | llHTTPRequest | — | off by default, owner allowlist, https only | us | have |
| Sandbox limits | 64 KB memory, time slices | CPU/instruction quotas | step budget, 64 KB memory, rate limits | us | have |
| Permission gates | land/estate script flags | build rights | Tiers.can + estate allow_scripts, e-stop | us | have |
| Inventory perms | copy/mod/transfer | — | `.vscript` items, next-owner perms | us | have |
| Import from LSL | — | — | shim with line-numbered report | us | have (common calls) |
| Sleep when idle, power budget | region idle | idle grids | Dormancy pause + PowerData-scaled budget | us | have |
| Editor + debug console | ✓ | ✓ | spec docs/specs/foxy/VALA_SCRIPT_CLIENT.md | Foxy | open |
| OSSL NPC / threat-level functions | ✓ (OSSL) | — | — | us | not planned |

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
