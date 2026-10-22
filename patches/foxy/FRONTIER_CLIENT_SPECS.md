# Frontier client specs for Foxy (spec only, no code in your files)

From the systems side (feature/spacesim-parity). Everything here is **yours**: client UI and data for the star map and routes, the flight HUD, the wrist hub, construct building, docking/landing, the co-pilot and the scanner. I only supply data APIs. Use the Phoenix Glass kit and `PhoenixTokens` (compact default, TAP_MIN 56, Large 80). Calm premium: restrained glass, no extra glows, kit motion only. **Concepts only:** our own names and art, never another game's names, icons or layouts.

## Data APIs you can call today (all static, all return `{"ok", "error", ...}` on writes)
| Need | Call |
|---|---|
| Can this actor do X? | `Tiers.can(actor, "trade" / "contract" / "industry" / "ship_own" / "insure" / "territory" / "mission_create")` |
| Planets for the star map | `ShardModel.planets(built_only)` → `{id, name, system, preset, biome, status}` |
| Which server/shard (grid later) | `ShardModel.server_of("local", "aurora_tundra/0/3")` |
| Player's ships | `ShipRegistry.fleet(id)`, `ship(id)`, `deploy(actor, id, shard, region)`, `stow(actor, id, hangar)` |
| Insurance + losses | `ShipRegistry.INSURANCE`, `insure()`, `claim()`, `losses(owner)` |
| Contracts for the wrist hub | `ContractsBoard.board(viewer, kind)`, `accept()`, `complete()`, `mine(id)`, `reputation(id, faction)` |
| Market glance | `OrderBook.book(item, location)`, `history(item)`; show `OrderBook.LEGAL` near any price |
| Industry | `Industry.recipes()`, `jobs(id, true)`, `collect(actor)` |
| Land under the player | `Territory.claim_of(region, Estate.parcel_id(pos))`, `Territory.can(actor, "mine"/"dig"/"build"/"deploy", region, parcel)` |
| Org tags over avatars (tap only) | `Social.groups_of(id)` + `OrgRights.rights_of(gid, id)` |
| Comfort | `ComfortPrefs.all()`, `bindings()`, `apply_camera(cam, in_vehicle)`; honour `travel_fx`, `vignette_on_turn`, `snap_turn`, `camera_shake`, `horizon_lock` |

## 1. Wrist hub (our own take on a wrist computer)
- **Open:** a HUD button and a two-finger upward swipe. On a phone it's a flat bottom sheet (portrait) that covers 70% of the height, with a 3D wrist quad only in vehicle and VR views later.
- **Apps (one row of 8 round icons, swipe for more):** Home (name, tier, time, region, alerts), Contracts, Map (opens your star map), Fleet (ships + insurance), Market (glance only), Industry (jobs + Collect), Org (groups, titles), Comms (Social inbox + notifications), Settings (Comfort).
- **Rules:** one card per item, at most 5 cards before "More". Every coin number has the legal-review line. Bots see the e-stop banner.

## 2. Overview + launcher (nearby list and side launcher concepts)
- **Overview:** a collapsible right-edge panel listing nearby entities. Columns: icon, name, distance, and standing (friend / org / blocked). Filters are pill presets: All · People · Companions · Ships · Landmarks. Tap selects and long-press opens actions (message, profile, track). Data comes from your radar plus `Social` and `OrgRights`.
- **Launcher:** extend the radial launcher with a "Frontier" wedge (wrist hub, map, fleet, contracts). Keep the existing 12 o'clock Admin wedge.

## 3. Flight HUD + MFD panels
- **Layout (portrait):** speed and altitude at the top centre, power triangle at the bottom left (engines / shields / systems, drag the dot), and target info at the bottom right. Two MFD slots sit above the thumbs and swap with a swipe.
- **MFD pages:** Power, Shields, Comms (hail a landing pad → docking UI), Scan (scanner overlay), Cargo (Inventory/Satchel), Travel (route steps from your star map).
- **Comfort:** use `fov_vehicle`, a vignette while turning if `vignette_on_turn` is set, no shake unless `camera_shake` is on, and a level horizon when `horizon_lock` is on.

## 4. Jump / quantum-style travel UI
- **Flow:** pick a destination on your star map → route card (steps, ETA, fuel later) → **hold to spool** (1.5 s ring fill) → align arrow → travel. During travel, show a calm streak effect scaled by `ComfortPrefs.travel_fx` (0 = a plain fade), then arrive at the planet.
- **Blocked states:** in a no-travel zone, or "region closed" from `Tiers.can(actor, "enter", region)`.
- **Ship check:** `ShipRegistry.ship(id)["state"] == "deployed"`. On arrival, call `ShipRegistry.deploy`/`stow` as the player lands or parks.

## 5. Docking + landing
- **Hail:** Comms MFD → "Request landing" → assigned pad marker → auto-align assist (on by default on phones) → touchdown → "Stow ship?" (calls `ShipRegistry.stow(actor, id, pad_or_home)`).

## 6. Scanner overlay
- A ping ring from the ship or the player, revealing landmarks, ships and resources for 10 s. Resource pings read `Territory.claim_of` (claimed / free) and later the ore pools.

## 7. Construct building (yours, after the build-tools engine)
- Uses the same `Tiers.can(actor, "build", {region, parcel})` plus `Territory.can(actor, "build", region, parcel)` on claimed land. Register finished ships with `ShipRegistry.register(actor, "construct:<id>", name, size)`.

## 8. Star map data (yours)
- Read planets from `ShardModel.planets()`. You own the route graph and the jump links. If you'd like the route graph to live in `data/frontier/`, add it there; I won't edit it.
