# Space-Sim Parity: Dual Universe · EVE Online · Star Citizen

> **Concepts only.** This page compares game *concepts* from Dual Universe, EVE Online and Star Citizen with Viper OS. Everything we build is our own code, names and art. No game's code, assets, UI art, names or trademarks go into in-game content. Game names appear here only to say where an idea came from. The public wording is "inspired by classic space-sim games". It never claims endorsement or included code.

Researched 2026-10-17 from the Dual Universe wiki and devblogs, the EVE University wiki and EVE support pages, the Star Citizen wiki and RSI comm-links. Sources are listed at the end. Evidence comes from `rg` against `scripts/` and `docs/` on `origin/main` 2f54951 plus this branch (feature/spacesim-parity).

**Ownership (agreed with Foxy, 2026-10-17).** *Foxy* owns the star map and its jump/quantum routes (client and data), the ship and flight HUD, the wrist hub, voxel ship and construct building, docking and landing UI, the co-pilot, and the scanner overlay. *Us (systems)* owns the market and order book, industry and blueprints, territory, org/corp tools, contracts and missions, persistent planets with the shard/server model, ship ownership and insurance gating, and comfort and keybind preferences. Client specs for Foxy are in [`patches/foxy/FRONTIER_CLIENT_SPECS.md`](../../patches/foxy/FRONTIER_CLIENT_SPECS.md).

**Status key:** built = in the app now (headless-tested) · partial = some of it · missing = not built · n/a = doesn't fit a phone voxel OS (with the reason). Priority: P0 (now) to P3 (later).

## Top missing items by priority (after this PR)
1. **P1 · Foxy:** star map route planner with jump/quantum travel between planets (data + UI). STAR_MAP.md is design notes only; no code (`rg -il "quantum|starmap" scripts` = 0 before this branch).
2. **P1 · Foxy:** ship/flight HUD with MFD-style panels, and the docking and landing UI. Vehicles exist only as data (`data/items/vehicles.json`).
3. **P1 · Foxy:** voxel construct building (cores, elements, blueprints of builds). The build-tools engine is already queued after v0.12 (BUILD-* tickets).
4. **P1 · us:** coin settlement for market, contracts, upkeep and insurance. It's blocked on **LEGAL REVIEW REQUIRED**, and everything records numbers only.
5. **P1 · us:** grid services for the Frontier stores (market, contracts, orgs, claims) so more than one phone shares them. This is the Aurora-model grid phase.
6. **P2 · us:** skills training queue (time-based, offline). `skill_by_use.gd` covers learning by use only.
7. **P2 · us:** sandboxed in-world scripting (a Lua-like or LSL-like subset) for elements and boards. Design notes only so far.
8. **P2 · us + Foxy:** fleets/parties with roles and broadcasts, plus the overview list (Foxy draws it, we supply the data).
9. **P2 · us:** mining and resource pools per territory feeding Industry (`Industry.add_materials` is the hook).
10. **P3 · us:** wormhole-style unstable links and real server meshing on region servers.

## Built in this PR (reach it: **MENU → 🪐 Frontier**)
| System | File | Tier gate (`Tiers.can`) |
|---|---|---|
| Org/corp roles, titles, tag policies, alliances (extends Social groups) | `scripts/spacesim/org_rights.gd` | group roles, `group_create` for alliances, `admin` override |
| Market order book (AEC, **LEGAL REVIEW REQUIRED**, settlement off) | `scripts/spacesim/order_book.gd` | `trade` (resident+), org `trade` right |
| Contracts + missions board, reputation | `scripts/spacesim/contracts_board.gd` | `contract` (resident+), `mission_create` (staff+) |
| Industry: recipes, blueprints (original/copy, ME/TE), job slots | `scripts/spacesim/industry.gd`, `data/frontier/recipes.json` | `industry` (resident+), org `factory`/`research` |
| Territory claims tied to Estate, upkeep/grace, sovereignty, contests | `scripts/spacesim/territory.gd` | `territory` (creator+), `land` to open regions |
| Ship ownership, hangars, stow/unstow, insurance plans, loss reports | `scripts/spacesim/ship_registry.gd` | `ship_own`, `insure` + plan minimum tier |
| Persistent planets + shards/servers meshing model | `scripts/spacesim/shard_model.gd`, `data/frontier/planets.json`, [SERVER_MESHING.md](SERVER_MESHING.md) | `admin` (owner only) |
| Comfort + keybind profiles (FOV, motion comfort, touch/keyboard/gamepad) | `scripts/spacesim/comfort_prefs.gd` | none (comfort is never paywalled) |
| Frontier hub screen (5 swipe tabs: Home · Trade · Industry · Holdings · Comfort) | `scripts/admin/frontier_screen.gd` | read-only except Comfort |

New Tiers actions: `trade`, `contract`, `industry`, `ship_own`, `insure` (resident), `territory` (creator), `mission_create` (staff). The owner can change them in the Community → Roles matrix like any other action.

## Parity rows (VIEWER_PARITY format, ready to merge under "Dual Universe / EVE Online / Star Citizen")

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

## Voxel / phone notes
- **Portrait first:** every Frontier screen is a short card list with swipe tabs, compact `PhoenixTokens` sizes (TAP_MIN 56) and one action per card.
- **Time-based systems** (industry jobs, claims, insurance timers) use timestamps, so nothing runs on the phone while it's closed. Results arrive the next time you open the app.
- **Bots and staff:** companions are residents in Tiers and obey the e-stop (`AutonomyGuard`). Their public posts still go through owner approval.
- **Coin:** every Aethel Coin number (prices, rewards, upkeep, premiums) is recorded only. **LEGAL REVIEW REQUIRED** before any of it moves.

## Sources
- Dual Universe wiki: [Territory Control](https://dualuniverse.fandom.com/wiki/Territory_Control), [RDMS](https://dualuniverse.fandom.com/wiki/Rights_%26_Duties_Management_System), [Industry Units](https://dualuniverse.fandom.com/wiki/Industry_Units), [Schematics](https://dualuniverse.fandom.com/wiki/Schematics), [Travel](https://dualuniverse.fandom.com/wiki/Travel); devblog "Mining Units 101".
- EVE: support [Broker Fee and Sales Tax](https://support.eveonline.com/hc/en-us/articles/203218962), [Courier](https://support.eveonline.com/hc/en-us/articles/203218982), [Item Exchange](https://support.eveonline.com/hc/en-us/articles/206758389), [Auction](https://support.eveonline.com/hc/en-us/articles/203280371), [Roles Listing](https://support.eveonline.com/hc/en-us/articles/203217712), [Insurance](https://support.eveonline.com/hc/en-us/articles/212726885), [Sovereignty Hub](https://support.eveonline.com/hc/en-us/articles/14339751569436); EVE University [Managing corporation members](https://wiki.eveuniversity.org/Managing_corporation_members), [Blueprints](https://wiki.eveuniversity.org/Blueprints), [Neocom](https://wiki.eveuniversity.org/Neocom).
- Star Citizen: [mobiGlas](https://starcitizen.tools/MobiGlas), [Letter from the Chairman 2026-08-27](https://starcitizen.tools/Comm-Link:Letter_from_the_Chairman_-_2026-08-27) (4.10 quasi-dynamic server meshing), [Server Meshing Q&A](https://api.star-citizen.wiki/comm-links/18397), RSI [Ship Insurance FAQ](https://support.robertsspaceindustries.com/hc/en-us/articles/360000093467), [Game Options](https://starcitizen.tools/Game_Options).

Not verified: exact current DU numbers (DU is a live game, and fan-wiki pages may be stale) and SC crafting details beyond 4.10 community indexes. Exact numbers weren't needed, because we copy concepts, not values.
