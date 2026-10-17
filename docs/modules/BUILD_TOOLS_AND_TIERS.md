# In-world Build Tools, Roles & Tiers (design spec)

> **Status:** design spec, 2026-10-17. Most of this is **Planned**. Each section marks what is **Built** (in the code on `main` today), **Partial**, or **Planned**. Currency features are marked **LEGAL REVIEW REQUIRED**.
>
> **Who builds what.** Foxy (UI lead) implements the **build engine and the build-tool HUD after v0.12 merges**. Roles and tiers (`scripts/security/tiers.gd`, `Tiers.can`, the role editor) are being built on `feature/social-dolphin`, which is not on origin yet. The Dev Bot (this doc) owns the spec, admin, security, wiki, tickets, the ads and rental carousels, the events board, land info panels and the tier editor screen. Full split: [§9 Ownership](#9-ownership).

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
| Estate: region + 64 m parcel settings (access lists, terraform rights, fly/build/damage switches, media/music URL), encrypted save | `scripts/world/estate.gd` | **Partial**: saved, but `allow_build` / `allow_fly` / `allow_damage` are never read, and the land panel passes `true` as "is owner" to `can_terraform` (fix proposed in `patches/land_tools_terraform_owner_check.patch`) |
| 16-material voxel palette with glitter emission | `scripts/generators/voxel_palette.gd` | **Partial**: tested, not used at runtime. The build engine's material picker should use it. |
| Procedural props + placeholder landmarks | `scripts/world/prop_kit.gd`, `landmark_builder.gd` | **Built** (placeholders) |
| Land tiers, upload fees (placeholder AEC prices) | `data/economy/land_and_fees.json` | **Data only** |
| Order book (Lindex-style), ledger | `scripts/economy/currency_exchange.gd`, `ledger.gd` | **Scaffold**, not in the UI. LEGAL REVIEW REQUIRED. |
| Select / move / rotate / scale, linking, properties panel, undo stack, permission overlay, blueprints, copy/paste | none | **Planned** (this doc) |
| Roles & tiers, `Tiers.can` | `feature/social-dolphin` (in progress) | **Planned** on `main` |

## 3. Build engine (Foxy implements, after v0.12)
Every action below calls **`Tiers.can(actor, "build", parcel)`** first (or the more specific key from §5: `carve`, `paint`, `upload`). A `false` result shows a toast ("You can't build here") and does nothing. The engine never edits voxels directly from UI code; it goes through one `BuildOp` path so permissions, undo, logging and the e-stop are always applied.

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
- Each tool call goes `AgentBrain.dispatch_tool` → allow-list check → e-stop check → **`Tiers.can(companion_actor, key, parcel)`** → `BuildOp`. Bots use the **Builder/Staff** role.
- Rate limit per bot (for example 12 tool calls per turn, the current `MAX_TOOLS_PER_TURN`, plus a voxel budget per minute per parcel).
- Learned build habits stay **data-only brain cells** that need owner approval (`BrainLearner` → Proposals). A bot can never grant itself a role or a parcel right.
- Every bot build is logged (`EveCore.log_build` + a revision) and can be undone by the owner or an estate manager.

## 4. Roles (from `Tiers`, built on `feature/social-dolphin`)
Roles, lowest to highest: **Guest, Resident, Premium/Creator, Builder/Staff, Estate Manager, Owner**.
- Default role is **Guest**. Bots and employees use **Builder/Staff**.
- **Owner** also needs an unlocked owner session (`Profile.is_owner()`, which is `role == owner` and `OwnerVault.is_unlocked()`).
- Role changes are **owner-only**, made in the admin tier editor (Dev Bot owns that screen).
- Roles are saved through the encrypted save path (`SecureFile`).

API every caller uses (stable, documented by the Tiers PR):
```gdscript
Tiers.can(actor, action: String, parcel = null) -> bool
```
It combines the role with `Estate` parcel access (`can_enter`, access lists, bans), terraform rights and the parcel's `allow_build` switch.

## 5. What each role can do (proposal; final table lives in `tiers.gd`)
| Permission key | Guest | Resident | Premium/Creator | Builder/Staff | Estate Manager | Owner |
|---|---|---|---|---|---|---|
| `build` (place/carve/paint/copy/paste) | sandbox only | own or rented parcel | own/rented + group parcels | anywhere the estate allows staff | their estate | everywhere |
| `carve` terrain (Terraform brush) | no | own parcel, if region terraform ≠ owner_only | same | estate-allowed | their estate | everywhere |
| `paint` | sandbox | own/rented | own/rented/group | estate-allowed | their estate | everywhere |
| `upload` (mesh/texture/sound) | no | no | yes (fee, LEGAL REVIEW REQUIRED) | yes (free) | yes | yes |
| `land_buy` | no | yes (LEGAL REVIEW REQUIRED) | yes | no (staff build, they don't own) | no | yes |
| `land_rent` | no | yes | yes | no | manages rentals | yes |
| `marketplace` (sell) | no | yes | yes | no | yes | yes |
| `advertise` (book an ad slot) | no | no | yes | no | approves slots on their estate | yes |
| `host_event` | no | yes (own parcel) | yes | yes | yes | yes |
| `admin` (admin screen writes, tier editor) | no | no | no | tickets/wiki only | estate tools only | everything |

A **sandbox** is a public build area that auto-cleans (like SL sandboxes); planned per region.

## 6. Land, rentals, ads, events
### 6.1 Rentals (Planned; LEGAL REVIEW REQUIRED for any AEC price)
- **Parcel rental**: a parcel (64 m grid cell or a merged group of cells) for a period.
- **Region rental**: a whole region, estate manager rights delegated for the period.
- **Time-based**: hourly/daily slots for events and shops.
- Rental object: `{parcel_ids, renter, start, end, price_aec, auto_renew, voxel_budget}` stored with the estate (`user://estate.cfg` today; grid service later). When a rental ends, builds are returned to the renter's inventory as a blueprint, never deleted.
- `Tiers.can(renter, "build", parcel)` returns true only between `start` and `end`.

### 6.2 Advertising slots (Planned)
- **Billboards**: fixed in-world frames on parcels (the 7 landmark placeholder frames are candidates).
- **In-world carousels**: a 3D glass frame that shows one ad card at a time with the kit carousel behaviour (§7).
- Booking needs `advertise`; an estate manager or the owner approves each ad before it shows. No tracking, no third-party ad networks.
- Ad card: image (webp, ≤ 512 px, ETC2/ASTC on device), title ≤ 40 chars, one link target (a parcel, event or marketplace item, not a web URL by default).

### 6.3 Events board (Planned)
- A list of events (title, host, parcel, start/end in the viewer's local time, category, capacity).
- Hosts need `host_event`. Events link to their parcel ("Teleport" button) and show in the land info panel.
- Shown as a glass carousel of upcoming events on the admin Home and in the world map.

### 6.4 Land info panel (Partial)
Built today: the Region / Estate panel (texture, water, sun, access, terraform, fly/build/damage switches, media). Planned: a read-only "About Land" panel for everyone with parcel name, owner, area, voxel budget used/total, rental status and end date, for-sale price (LEGAL REVIEW REQUIRED), current events, and the permission summary from `Tiers.can`.

## 7. UI (Phoenix Glass, calm premium)
Reuse the kit; do not invent new styles:
- `scenes/ui/kit/`: ring stat, radial menu, glass card, line graph, and the new **`glass_carousel.tscn`** (Dev Bot builds it).
- `themes/phoenix_glass.tres`, `shaders/ui_glass.gdshader`, and `scripts/ui/kit/phoenix_tokens.gd` for **every** color, size and timing. Never hard-code values.

**Carousel spec** (`scenes/ui/kit/glass_carousel.tscn`): snaps one card per swipe; page dots under the card; auto-advance **only** when the list opts in (ads, event lists), never for content the user is reading; any touch pauses auto-advance.

**Motion and layout rules (from Foxy):**
- Transitions 180–240 ms, ease-out. No bounce, no spin.
- At most **one accent glow** per screen.
- The **ember** accent only on Foxy-related items.
- Tap targets **≥ 80 px**. Labels **≥ 16 sp** (Phoenix has eye strain).
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
| `tiers.gd`, `Tiers.can`, role persistence | social worker, `feature/social-dolphin` | Dev Bot does not create `tiers.gd` |
| Admin, security, wiki, tickets, tier editor screen | **Dev Bot** | |
| Ads and rental carousels, events board, land info panels | **Dev Bot** | Built on the kit carousel |
| Kit carousel + glass menu component, calm-premium theme pass | **Dev Bot** (handed over by Foxy) | |

## 10. Phased plan (small PRs)
Tracker rows BUILD-1 … BUILD-10 in `docs/TASK_TRACKER.csv`.
1. **BUILD-1** (Dev Bot): kit `glass_carousel.tscn` + glass menu, calm-premium tokens, admin Home on the carousel. Tests for snap, dots, opt-in auto-advance, pause on touch.
2. **BUILD-2** (social worker): `Tiers` + `Tiers.can` + role persistence + tests. Dev Bot reviews the API against this doc.
3. **BUILD-3** (Dev Bot): admin tier editor (owner-only), wiki page `docs/wiki/roles-tiers.md` with real status.
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
