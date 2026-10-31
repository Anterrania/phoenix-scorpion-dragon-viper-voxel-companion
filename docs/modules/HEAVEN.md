# Heaven Welcome Island (HEAVEN-1..6)

Default start realm for every user (Settings `world/start_realm`, default `heaven`). Self-written. Concepts only;
no code, assets or names taken from any other game, viewer or grid.

## Files
| File | Role |
|---|---|
| `data/heaven/heaven_layout.json` | Islands (centre, radius, top, depth, kind), bridges, roads, waterways, portals, spawn |
| `data/heaven/districts/<island>.json` | **Data-driven** building layout per island: pieces `{id, type, at:[x,z], yaw, w,d,h,r, color, trim, shop, name, text}` in island-local metres (-z faces the Mall). Generated once by `tools/heaven_districts.py`, then edited live |
| `data/heaven/shops.json`, `shop_items.json` | Shops (13) and free house items (21) |
| `data/heaven/grids.json` | Grids = realms for the world picker |
| `scripts/heaven/heaven_layout.gd` | Layout queries + island SDF shape (top lip, tapered underside) |
| `scripts/heaven/heaven_terrain_generator.gd` | Ground generator + islands in one VoxelLodTerrain (band fill, same as RND-3) |
| `scripts/heaven/heaven_mesh_kit.gd` | ArrayMesh batch builder: 5 shared materials (solid, metal, glow, glass, water); one collision shape per batch |
| `scripts/heaven/heaven_builder.gd` | District pieces → meshes, shop interiors, triggers, labels |
| `scripts/heaven/heaven_world.gd` | Runtime: progressive build, links, impostors, rides, rules, prompts, live-edit polling, pointing |
| `scripts/heaven/heaven_access.gd` | Fly / studio / build grants (SecureFile, owner-only changes, logged) |
| `scripts/heaven/heaven_edits.gd` | Live edit overlay + EveCore proposals + companion `heaven_edit` tool |
| `scripts/heaven/heaven_director.gd` | "Direct a change" words → tool args (offline keyword rules) |
| `scripts/heaven/heaven_weather.gd` | Kelvin weather (3-hour slots, district offsets, gentle states) |
| `scripts/heaven/heaven_shops.gd` | Shop stock, creator listings, wear, buy (MarketDelivery, LegalReview) |
| `scripts/heaven/heaven_screen.gd`, `world_picker.gd` | Glass UI: Transit · Shop · Casino · Weather · Access · Direct; Worlds |
| `shaders/heaven_glow.gdshader`, `heaven_water.gdshader` | Unshaded glow; flowing translucent water |

## Rules
- **Flying:** only the unlocked owner and members the owner grants (`fly`). Estate rank gives no bypass. Without
  the right, the sky ceiling stays 20 m under the islands, take-off in Heaven is refused (`player.fly_refused`),
  and a flight that enters Heaven airspace lands. Transit kiosks and portals are free for everyone.
- **Studio:** voxel tools / terraform in Heaven need `studio` (owner-granted). The terraform reference field in
  Heaven is the island SDF.
- **Casino:** FreePlay only (play tokens, odds shown). No Aethel Coin wagers or payouts. The casino game also needs
  18+ and a launch country, which the app doesn't record yet, so spins are refused with the reason shown.
- **Shops:** house items are free and go straight to the wardrobe. Creator listings are fixed-price only and go
  through `MarketDelivery.deliver`, which checks the shown price. Aethel purchases stay LEGAL REVIEW.

## Built live (HEAVEN-6)
1. A companion calls `heaven_edit` (`HeavenEdits.tool_call`) or the owner uses **Direct a change**.
2. The edit is validated: editable types only, inside the plaza, sizes clamped, `#rrggbb` colours, 40-character text.
3. Approval:
   - With a standing `build` grant for that companion, the edit applies at once and is logged.
   - Otherwise `EveCore.for_companion(id).propose_update("[heaven-edit <id>] …")` queues it. The owner approves or rejects it in the Proposals panel or on the Heaven Direct page, and `HeavenEdits.sync()` applies or drops it.
   - With the unlocked owner directing in person, the instruction counts as the approval: proposal plus approval in one step.
4. Applied edits overlay the base district files in order. `revision(island)` goes up, and `HeavenWorld.poll_edits()`
   (every 1.5 s) rebuilds only that island in place, with no restart.
5. Undo is owner-only. It marks the edit `reverted`; history is never deleted.
   (HEAVEN-9 adds companion undo of the companion's own changes, below.)

## Edits from chat (HEAVEN-9)
- `heaven_edit` is in the companion tool registry (`AgentBrain.tools_of`): every companion that can build
  (`spawn_structure`) gets it, in live chat (OpenAI tools schema, `AgentBrain.heaven_schema()`) and in on-device chat.
  It is world-only (`AgentBrain.WORLD_TOOLS`), so standalone chat bots never expose it.
- A call runs `HeavenEdits.tool_call(companion, args, now, directed = false)` through `AgentBrain.dispatch_tool`
  (e-stop and persona permissions apply). **Chat never self-approves**, even when the unlocked owner is the one typing:
  the edit becomes an EveCore proposal (`propose_update`) and waits for the owner (Proposals panel or Heaven ›
  Direct a change), unless that companion holds the owner's standing `build` grant, in which case it applies at once.
  Only the in-person Direct-a-change UI passes `directed = true`.
- `op: "undo"` (`HeavenEdits.companion_undo`, target = edit id or `last`): a companion takes back its own change.
  A pending change becomes `withdrawn` (sync never applies it, even if approved later). An applied change can be
  reverted by the companion only if it holds the `build` grant; otherwise the owner undoes it. Nothing is deleted.
- The result goes back to the model (CHAT-16) so the companion says whether the change is done or waiting for
  approval. If the model can't answer, the chat shows `HeavenEdits.status_line` ("I asked the owner to approve: …").
- In Heaven, the companion's prompt says where it is and that `heaven_edit` is the way to change Heaven (voxel tools
  there still need the studio grant).
- On-device: missing coordinates are filled 3 m in front of the companion, plural or loose type words are mapped
  through `HeavenDirector.TYPE_WORDS`, and the intent guard needs a build/change word in the player's message.
- Tests: `tests/heaven_chat_tests.gd`.

**Runs while the app is open.** True 24/7 building while the owner is away needs a persistent server (H10). It
would run the companions' build loop server-side, keep the edit log and stream changes to every client. The edit
format is designed to move there unchanged.

## Performance (Mobile renderer)
- Islands build one per frame, nearest first. The spawn island builds synchronously so arrival is never on air.
- Main batch per island with no range limit. The small-prop "Detail" batch range is `max(RenderPipeline.props_range × 1.6, 110 m)`,
  refreshed on `RenderPipeline.applied`.
- Far islands: one impostor batch, visible only beyond 85 % of the voxel view distance.
- Rides: absolute-clock pose (no catch-up replay), awake within 260 m, asleep beyond 260 × `Dormancy.SLEEP_FACTOR`.
- Whole Heaven ≈ 100k triangles, 5 shared materials; Label3D signs obey Settings `ui/show_labels`.
