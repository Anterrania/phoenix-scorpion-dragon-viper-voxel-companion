# Heaven client spec (owner=Foxy)

owner=Foxy. Heaven Welcome Island is built and playable on `feature/heaven-welcome-island` (HEAVEN-1..6).
This spec covers the client polish that belongs to Foxy's files, plus the one hook owned by the chat branch.
Everything below reads system APIs. The client must never decide a rule on its own.

## APIs to read
- Layout: `HeavenLayout.islands()`, `island(id)`, `district_at(pos)`, `contains(pos)`, `spawn()`, `arrival(id)`.
- Weather: `HeavenWeather.report(district_id, HeavenWeather.today(), hour)` → `{state, label, kelvin, text, fx, wind_ms, humidity}`. Temperatures display in **kelvin** (`fmt_k`).
- Access: `HeavenAccess.can_fly(actor)`, `can_studio(actor)`, `members(kind)` with kinds `fly`, `studio`, `build`; `grant` / `revoke` / `grant_many` (owner only; show the returned reason).
- Shops: `HeavenShops.shops()`, `stock(shop_id, Inventory)`, `creator_listings(shop_id)`, `wear(...)`, `buy(listing_id, now, {"shown_price": p})`. Priced buttons stay labelled "Legal review" until the profile has a confirmed age and country.
- Live edits: `HeavenEdits.pieces(island)`, `edits(state)`, `revision(island)`, `describe(edit)`, `revert(actor, id)`; `HeavenDirector.parse(text, spot, piece)`.
- Runtime: the `HeavenWorld` node (child of the world) has `travel_to(id)`, `go_spawn()`, `begin_point(cb)`, `aim_point()`, `poll_edits()`, `hud_text()`.

## 1. Avatar style keys (humanoid_model.gd is Foxy's)
The Heaven house items set these style keys through `Inventory.styled()`:
- outfit: `outfit`, `jacket`, `top`, `pants`, `trim`. These are already used.
- shoes: `boots`. Check that the boots/shoes mesh reads it.
- hair: `hair`. This is already used; confirm that streaks keep their own colours.
- looks: `glow` (soft emissive rim), `eyes` (iris colour). Add `glow` as a low-cost emission on skin and clothing (Mobile renderer, no extra pass).
- accent: `halo` (gold ring above the head), `wing_trim`, `chain`. Add them as optional parts, hidden when the key is absent.
Values are `#rrggbb` strings converted to Color; any other value passes through unchanged.

## 2. Direct a change (polish)
A working version lives in `HeavenScreen` (page "direct"). The steps are: pick a companion, tap 🎯 to point (crosshair, then "Use this spot"), say the change, and press Ask.
- Replace the typed box with the chat composer's mic button. The text then goes to `HeavenDirector.parse`, or to the companion's model, which calls the `heaven_edit` tool itself.
- While pointing, draw a ghost preview of the piece at `aim_point()` (glass material, no collision).
- Show the companion's bubble line (`show_bubble`) and a toast with the result: "applied" or "waiting for approval".
- The pending list needs per-item Approve / Reject (call `EveCore.decide(proposal, ok)` and then `HeavenEdits.sync()`). Undo for applied edits is owner only.

## 3. Chat tool hook (owned by fix/chat-core, not this branch)
**Done (HEAVEN-9):** `AgentBrain` registers `heaven_edit` for builder companions; see docs/modules/HEAVEN.md "Edits from chat". The Direct-a-change UI keeps calling `HeavenEdits.tool_call(..., directed = true)` itself.

Register `HeavenEdits.TOOL_SPEC` (name **`heaven_edit`**) in the companion tool registry. On a call, run
`HeavenEdits.tool_call(companion_id, args, now)` with **`directed = false`**: a companion acting on its own always
goes through approval unless it holds the owner's standing `build` grant. Only the in-person Direct-a-change UI,
with the unlocked owner present, passes `directed = true`. Voxel tools (`place_voxel`, `carve_area`, …) in Heaven
are already refused by `LandGate.companion_tool_error` without the studio grant; the returned reason tells the model to use `heaven_edit` instead.

## 4. Companion flight-follow
Granted companions (`HeavenAccess.can_fly(companion_id)`) may fly after the owner in Heaven. The others walk, or
teleport with the owner when transit is used (`HeavenWorld.place_player` already moves companions).

## 5. HUD
- Show `HeavenWorld.hud_text()` in the status bar while `HeavenLayout.contains(player)`. A plain label is already drawn at the top left; replace it with the kit status chip.
- When `player.fly_refused(reason)` fires, show the reason as a toast and grey out the fly button in Heaven if `LandGate.can_fly(Tiers.SELF, pos)` is false.

## 6. World picker
`WorldPicker` already works (Glass). Foxy may move it into the social shell's tab bar. Keep "Make this my start world" (`Settings world/start_realm`).

Never show security internals (vault, grants file paths) in public UI.
