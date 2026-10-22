# In-world Build Tools, Roles & Tiers (design spec)

> **Status:** design spec, 2026-10-17. Most of this is **Planned**. Each section marks what is **Built** (in the code on `main` today), **Partial**, or **Planned**. Currency features are marked **LEGAL REVIEW REQUIRED**.
>
> **Who builds what.** Foxy (UI lead) implements the **build engine and the build-tool HUD after v0.12 merges**. Roles and tiers are **built**: `scripts/security/tiers.gd` (`Tiers.can`, PR #26, merged as `1a07535`) is the source of truth, with the owner-only role editor in Admin › Community › Roles and the wiki page `docs/wiki/tiers.md`. The Dev Bot (this doc) owns the spec, admin, security, wiki, tickets, the ads and rental carousels, the events board, land info panels and the tier editor screen. Full split: [§9 Ownership](#9-ownership).

## 1. Goals
- Second Life / Firestorm-class build tools, rebuilt for voxels on a phone: one-handed, big targets, no tiny gizmo handles.
- Mainly for **bots and staff** (companions, employees). Other users get **tiered** access: what you can build depends on your role and on the parcel.
- Our own code first: the build engine, gizmos, grid and permission overlay are GDScript on Zylann godot_voxel. No third-party build plugins.
- Every build action is permission-checked, logged, undoable, and stoppable by the e-stop.

## 2. What exists today (grep of `main`, 2026-10-17)
| Piece | Where | Status |
|---|---|---|
| Terrain brush: Raise, Lower, Flatten, Smooth, Noise, Revert, with size 1–12 m and strength | `scripts/world/terraform.gd` (`Terraform.apply`, `brush_value`), land panel in `scripts/ui/ui_root.gd` | **Built** |
| Companion build tools: `place_voxel`, `carve_area` (sphere, r ≤ 8), `spawn_structure` (tower, hut, arch, pillar, wall, fire_altar), `build_realm` | `scripts/agent/companion_agent.gd` `tool_*`, dispatched by `AgentBrain.dispatch_tool` | **Built** |
| Tool allow-list per companion (`persona.json` tools) + e-stop (`AutonomyGuard.paused()` blocks every tool) | `scripts/autoload/agent_brain.gd` | **Built** |
| Build log: every companion build and owner terraform goes to Eve Core (`log_build`) and the revision timeline (`ViperAdminData.record_world_edit`, summaries only) | `scripts/ai/eve_core.gd`, `scripts/admin/tracker/viper_admin_data.gd` | **Built** |
| Realm presets (whole-realm generation) | `scripts/autoload/realm_builder.gd`, `data/realm_presets/` | **Built** |
| Estate: region + 64 m parcel settings (access lists, terraform rights, fly/build/damage switches, media/music URL), encrypted save | `scripts/world/estate.gd` | **Partial**: `Tiers.can(…, "build", parcel)` now reads `allow_build`, `terraform`, access lists and bans, companion tools call `Tiers.can` through `LandGate` (AUDIT-4) and `allow_damage` / `allow_fly` are read by `LandGate` (AUDIT-3; player wiring is `patches/player_fly_estate_rule.patch`); the terraform brush still doesn't call `Tiers.can`; the land panel passes `true` as "is owner" to `can_terraform` (fix proposed in `patches/land_tools_terraform_owner_check.patch`) |
| 16-material voxel palette with glitter emission | `scripts/generators/voxel_palette.gd` | **Partial**: tested, not used at runtime. The build engine's material picker should use it. |
| Procedural props + placeholder landmarks | `scripts/world/prop_kit.gd`, `landmark_builder.gd` | **Built** (placeholders) |
| Land tiers, upload fees (placeholder AEC prices) | `data/economy/land_and_fees.json` | **Data only** |
| Order book (Lindex-style), ledger | `scripts/economy/currency_exchange.gd`, `ledger.gd` | **Scaffold**, not in the UI. LEGAL REVIEW REQUIRED. |
| Select / move / rotate / scale, linking, properties panel, undo stack, permission overlay, blueprints, copy/paste | none | **Planned** (this doc) |
| Roles & tiers, `Tiers.can`, owner-only role editor | `scripts/security/tiers.gd`, `scripts/admin/community_screen.gd` (PR #26) | **Built** (not yet called by any build path) |

## 3. Build engine (Foxy implements, after v0.12)
Every action below calls **`Tiers.can(actor, "build", parcel)`** first (`upload` for uploads; the proposed `carve` / `paint` keys in §5 once `tiers.gd` adds them). A `false` result shows a toast ("You can't build here") and does nothing. The engine never edits voxels directly from UI code; it goes through one `BuildOp` path so permissions, undo, logging and the e-stop are always applied.

### 3.1 Operations
| Op | What it does | Notes |
|---|---|---|
| **Place** | Add voxels with the current brush/shape and material | Raycast from the camera (the v0.1 `player_controller.gd` raycast, now INACTIVE, is the reference) |
| **Carve** | Remove voxels with the brush/shape | Same as `carve_area`, any shape |
| **Paint** | Change material only, keep shape | Material picker = `VoxelPalette` (16 ids) + estate land textures |
| **Select** | Box or lasso a voxel region or a linked object | Selection = AABB + optional mask, shown as a platinum outline |
| **Move / Rotate / Scale** | Gizmo on the selection | Rotate snaps 15°/90°; scale is voxel-integer on blocky, free on smooth SDF |
| **Copy / Paste** | Copy the selection into a clipboard blueprint, paste with a ghost preview | Paste checks the target parcel, not the source |
| **Blueprints** | Saved, named selections (JSON: size, palette, run-length voxel data, author, version) | Bots and staff can place blueprints by name, like `spawn_structure` today |
| **Link / Unlink** | Group several selections or props into one object with a root | Like SL linksets; the root holds the properties |
| **Undo / Redo** | Per-actor stack, 50 steps | Stores before/after voxel blocks of the touched AABB only |

### 3.2 Brush & shapes
Sphere, cube, cylinder, cone, wedge, plane (wall), line (two taps), and "fill" (flood within a selection). Size uses the ring dial (1–12 m, same limits as `Terraform.MIN_SIZE`/`MAX_SIZE`), strength 0–100%. Smooth terrain uses SDF brushes (`Terraform.brush_value` falloff); blocky builds use exact voxels.

### 3.3 Snap & grid
Grid sizes 0.25 / 0.5 / 1 / 2 / 4 m, shown as a faint platinum grid on the target face only (never a full-screen grid). Snap to grid, to face, and to parcel edge. Rotation snap 15° / 90°.

### 3.4 Properties panel
For a selection or linked object: name, description, owner, creator, material, size, position (editable numbers), linked parts, permissions (copy / modify / transfer, as in SL), "for sale" (price in AEC, LEGAL REVIEW REQUIRED), and the parcel it sits on. Opens as a bottom sheet.

### 3.5 Permissions overlay
A toggle that tints parcels on the ground: soft **OK** green where you may build, nothing where you may not, gold outline on your own parcels. It reads the same `Tiers.can` answer the engine uses, so the overlay can never disagree with the engine.

### 3.6 Bot & companion build API (BrainCore / AgentBrain tools)
- Keep the existing tools (`place_voxel`, `carve_area`, `spawn_structure`, `build_realm`) and add `paint_area`, `place_blueprint(name, x, y, z, rot)`, `copy_region`, `undo_last`.
- Each tool call goes `AgentBrain.dispatch_tool` → allow-list check → e-stop check → **`Tiers.can(companion_id, "build", parcel)`** → `BuildOp`. Bots that build for the owner get the **Builder/Staff** tier from the owner with **`Tiers.set_role(companion_id, "staff")`** (owner session required; each change is an audit revision `role/<id>`). Live since fix/audit-gates: `LandGate.companion_tool_error` maps `place_voxel`/`carve_area`/`spawn_structure` to `build` and `build_realm` to `land`.
- Rate limit per bot (for example 12 tool calls per turn, the current `MAX_TOOLS_PER_TURN`, plus a voxel budget per minute per parcel).
- Learned build habits stay **data-only brain cells** that need owner approval (`BrainLearner` → Proposals). A bot can never grant itself a role or a parcel right.
- Every bot build is logged (`EveCore.log_build` + a revision) and can be undone by the owner or an estate manager.

## 4. Roles (`scripts/security/tiers.gd`, built in PR #26)
`Tiers` is the source of truth; this section only summarises it. Tiers, lowest to highest: **Guest** (`guest`), **Resident** (`resident`), **Premium/Creator** (`creator`), **Builder/Staff** (`staff`, bots and employees), **Estate Manager** (`estate_manager`), **Owner** (`owner`).
- The default tier is **Guest**. A device with a saved profile is Resident.
- **Owner** also needs an unlocked owner session (`Profile.is_owner()`); a locked owner counts as Guest.
- Role changes are **owner-only** (`Tiers.set_tier`, Admin › Community › Roles). Nobody can be made Owner; `admin` and `roles` are owner-only actions.
- Roles and matrix overrides are saved to `user://social/roles.json` through `SecureFile` (encrypted once an OwnerVault exists).
- With the e-stop on (`AutonomyGuard.paused()`), bots can only `browse`.
- **Note for the build engine:** `Tiers.assigned_tier` gives companions **Resident** by default. Resident can build only where the parcel's terraform rule is `everyone`, or `group` with membership/allow-list. For bots to build on owner-only land, the owner assigns them **Builder/Staff** in the role editor (or a `bot:` id gets Staff). This is deliberate: bots never raise their own tier.

Stable API every build caller uses:
```gdscript
Tiers.can(actor, action: String, target = null) -> bool
# actor: "self", a member id, or {"id": ..., "tier": ...} (a Dictionary may only lower the tier)
# target for build/land/enter: {"region": r, "parcel": p}, "region/parcel" or "region"
```
For `build`, `land` and `enter` it combines the tier with Estate bans, access lists, group land, `allow_build` and the terraform rule (`Tiers._land_ok`).

## 5. What each tier can do
Built action keys in `Tiers.ACTIONS` that matter here, with the default matrix (each tier has everything of the tiers below it):
| Key | Lowest tier | Notes |
|---|---|---|
| `enter` | Guest | plus parcel access rules |
| `build` | Resident | plus `allow_build` + terraform rule; Staff and up may build on owner-only land |
| `event_create` | Premium/Creator | hosting events (events board) |
| `classified` | Premium/Creator | classifieds tied to ad slots (SOCIAL-7) |
| `upload` | Premium/Creator | mesh/texture/sound; fees LEGAL REVIEW REQUIRED |
| `marketplace` | Premium/Creator | selling; AEC pricing LEGAL REVIEW REQUIRED |
| `moderate` | Builder/Staff | moderation queue |
| `land` | Estate Manager | region/estate settings and land |
| `admin`, `roles` | Owner only | admin writes, role editor |

**Proposed new keys** (to add to `tiers.gd` in its own PR, owner of `tiers.gd` decides): `carve` (terrain brush, separate from voxel `build`), `paint`, `land_rent`, `advertise` (book an ad slot; `classified` may cover it), `blueprint_place` for bots. Until then the build engine uses `build` for place/carve/paint/copy/paste/blueprints, exactly as Foxy's spec says: every action calls `Tiers.can(actor, "build", parcel)`.

A **sandbox** is a public build area (terraform rule `everyone`) that auto-cleans, like SL sandboxes; planned per region.

## 6. Land, rentals, ads, events
### 6.1 Rentals (Planned; LEGAL REVIEW REQUIRED for any AEC price)
- **Parcel rental**: a parcel (64 m grid cell or a merged group of cells) for a period.
- **Region rental**: a whole region, estate manager rights delegated for the period.
- **Time-based**: hourly/daily slots for events and shops.
- Rental object: `{parcel_ids, renter, start, end, price_aec, auto_renew, voxel_budget}` stored with the estate (`user://estate.cfg` today; grid service later). When a rental ends, builds are returned to the renter's inventory as a blueprint, never deleted.
- Planned: `Tiers.can(renter, "build", parcel)` returns true only between `start` and `end` (needs rental data in `Tiers._land_ok`).

### 6.2 Advertising slots (Planned)
- **Billboards**: fixed in-world frames on parcels (the 7 landmark placeholder frames are candidates).
- **In-world carousels**: a 3D glass frame that shows one ad card at a time with the kit carousel behaviour (§7).
- Booking needs `classified` today (or a future `advertise` key); an estate manager or the owner approves each ad before it shows. No tracking, no third-party ad networks.
- Ad card: image (webp, ≤ 512 px, ETC2/ASTC on device), title ≤ 40 chars, one link target (a parcel, event or marketplace item, not a web URL by default).

### 6.3 Events board (Planned)
- A list of events (title, host, parcel, start/end in the viewer's local time, category, capacity).
- Hosts need `event_create`. Events link to their parcel ("Teleport" button) and show in the land info panel.
- Shown as a glass carousel of upcoming events on the admin Home and in the world map.

### 6.4 Land info panel (Partial)
Built today: the Region / Estate panel (texture, water, sun, access, terraform, fly/build/damage switches, media). Planned: a read-only "About Land" panel for everyone with parcel name, owner, area, voxel budget used/total, rental status and end date, for-sale price (LEGAL REVIEW REQUIRED), current events, and the permission summary from `Tiers.can`.

## 7. UI (Phoenix Glass, calm premium)
Reuse the kit; do not invent new styles:
- `scenes/ui/kit/`: ring stat, radial menu, glass card, line graph, and the new **`glass_carousel.tscn`** and **`glass_menu.tscn`** (built in BUILD-1; see UI_DESIGN_LANGUAGE §12).
- `themes/phoenix_glass.tres`, `shaders/ui_glass.gdshader`, and `scripts/ui/kit/phoenix_tokens.gd` for **every** color, size and timing. Never hard-code values.

**Carousel spec** (`scenes/ui/kit/glass_carousel.tscn`): snaps one card per swipe; page dots under the card; auto-advance **only** when the list opts in (ads, event lists), never for content the user is reading; any touch pauses auto-advance.

**Motion and layout rules (from Foxy):**
- Transitions 180–240 ms, ease-out. No bounce, no spin.
- At most **one accent glow** per screen.
- The **ember** accent only on Foxy-related items.
- Tap targets **≥ 80 px**. Labels **≥ 16 sp** (Phoenix has eye strain).
- **Sizing:** Phoenix wants **Compact** as the default (smallest usable text and icons) with a **Large** toggle. The scale variables are being added to `phoenix_tokens.gd` on `feature/phone-display-media`; build-tool UI must read sizes from those tokens, never fixed numbers. The 80 px / 16 sp floors above apply to the Large setting and to anything Phoenix taps often; Compact must still meet platform minimums (48 dp tap targets).
- Premium and restrained: generous spacing, few glass layers (≤ 3), no flashing, no confetti, no campy effects.

**Build HUD (Foxy's, spec only):** bottom-third layout; the operation is a radial menu (Place, Carve, Paint, Select, Move, Copy/Paste, Undo), the brush size is a ring dial, materials are a carousel of palette swatches, the gizmo has three big drag rings (not thin arrows), and the properties panel is a bottom sheet. The permissions overlay toggle sits next to the brush dial.

## 8. Real-world ties (concepts)
- **Map**: the world map (`world_map_view.gd`) can show parcels for rent, events and ads as pins. Later, optional real-world map anchors for estates (opt-in, no location tracking).
- **Time**: events show in the viewer's local time; the region sun can follow the device's local time (a new "real time" sun mode next to fixed / cycle).
- **Weather**: an optional "mirror local weather" mode for a region, using a weather source chosen by the owner. Off by default, no location sent without consent.
All of this is **Planned** and offline-first; nothing needs a server to run.

## 9. Ownership
| Area | Owner | Notes |
|---|---|---|
| Build engine (place, carve, paint, select, move/rotate/scale, copy/paste, blueprints, undo) | **Foxy**, after v0.12 | Every op calls `Tiers.can(actor, "build", parcel)` |
| Build-tool HUD (gizmo, brush, blueprint picker), land-tools sheet, main HUD, minimap | **Foxy** | Dev Bot sends patches under `patches/` instead of editing |
| Companion History, Proposals and voice panels | **Foxy** | |
| `tiers.gd`, `Tiers.can`, role persistence, Community › Roles editor | social worker (PR #26, merged) | Dev Bot does not edit `tiers.gd`; new keys go through its owner |
| Admin, security, wiki, tickets | **Dev Bot** | |
| Ads and rental carousels, events board, land info panels | **Dev Bot** | Built on the kit carousel |
| Kit carousel + glass menu component, calm-premium theme pass | **Dev Bot** (handed over by Foxy) | |

## 10. Phased plan (small PRs)
Tracker rows BUILD-1 … BUILD-10 in `docs/TASK_TRACKER.csv`.
1. **BUILD-1** (Dev Bot): kit `glass_carousel.tscn` + glass menu, calm-premium tokens, admin Home on the carousel. Tests for snap, dots, opt-in auto-advance, pause on touch.
2. **BUILD-2** ✅ (PR #26): `Tiers` + `Tiers.can` + role persistence + tests.
3. **BUILD-3** ✅ (PR #26): owner-only role editor (Admin › Community › Roles) + `docs/wiki/tiers.md`.
4. **BUILD-4** (Foxy, after v0.12): `BuildOp` core: place / carve / paint with undo stack, Tiers check, e-stop, log + revision. Headless tests on a VoxelTool stub.
5. **BUILD-5** (Foxy): build HUD: radial ops, brush ring dial, material carousel (VoxelPalette), snap/grid.
6. **BUILD-6** (Foxy): select + move/rotate/scale gizmo, copy/paste, blueprints JSON.
7. **BUILD-7** (Dev Bot): enforce estate `allow_build` / terraform rights through `Tiers.can` (replaces `patches/land_tools_terraform_owner_check.patch`), permissions overlay data.
8. **BUILD-8** (Dev Bot): companion build API v2 (`paint_area`, `place_blueprint`, `undo_last`) through `Tiers.can` with Builder/Staff role, rate limits, tests.
9. **BUILD-9** (Dev Bot): land info panel, events board, rental records (no real-money flows; prices are placeholders, LEGAL REVIEW REQUIRED).
10. **BUILD-10** (Dev Bot): ad slots: billboard + in-world carousel, approval queue in admin.

## 11. Open questions for Phoenix
- Who besides you is an Estate Manager at first?
- Which regions get a public sandbox?
- Ad rules: what kinds of ads are allowed, and do they need your approval every time?
