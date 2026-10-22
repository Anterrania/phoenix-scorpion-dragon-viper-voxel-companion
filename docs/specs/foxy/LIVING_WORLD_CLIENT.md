# Living world client spec (owner=Foxy)

owner=Foxy. These are the server/system APIs to read. Do not write vitals client-side.

1. **Vitals / life-support HUD:** read `Survival.vitals(id)`, subscribe to `vitals_changed(id, vitals)`. Show o2_sat, co2, core_c, pressure_ok,
   radiation_msv, hydration, calories, fatigue, health, suit_o2_h, state and alerts. Hide the HUD when `mode == "off"`, and show a crown badge when `exempt`.
2. **Suit UI:** suits come from `WorldEnv.suit(id)` and the tank is `suit_o2_h`. Refill calls `Survival.refill_suit`.
3. **Mining tool / scanner / voxel extraction:** `Geology.deposit_at` / `survey` for the scanner, and `Materials.mine` for extraction. Show errors as returned.
4. **Blueprint crafting screen:** `Materials.recipes()`, `check()`, `craft()`, `raw_cost()`; `Blueprints.owned_by`, `list_for_sale`, `buy`.
   Aethel Coin buttons stay disabled with the label "Legal review".
5. **DNA match view:** `Genome.compatible`, `viability`, `spawnable`. Creatures only. Never offer it on avatars or companions.
6. **Symptom / cure UI:** `Disease.symptoms`, `cases`, `treat`, `vaccinate`. Family-friendly icons, no gore.
7. **Government screens:** `Governance.*` (nation, laws, elections, embassies, borders, taxes in civic credits).
8. **Companion needs / moods:** read companion vitals from `Survival.vitals(companion_id)`. While the e-stop is on, show "paused".
9. **Client floating origin + streaming LOD:** use `Land.rebase(pos, viewer_sector)` and `Land.render_budget(AutoQuality tier)`.
   Rebase when the camera crosses a sector (1024 m).
