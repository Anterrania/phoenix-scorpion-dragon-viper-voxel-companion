# Foxy spec: build mode, crafting station and constraints (SBX-F2)


> 2026-10-22: written before the dev/Foxy split. Ids like SBX-SIM-n point at the inactive reference model in `scripts/sim/` (Foxy owns those features now). Dev-side APIs: QuestEngine (SBX-2), WorldHost (SBX-3), MarketDelivery (SBX-5), FreePlay (SBX-7).
Owner: **Foxy** (build-mode client). Dev side: `Crafting` (scripts/sim/crafting.gd), `ParcelTools`,
`Terraform`, `PropKit`, `Tiers.can(actor, "build", parcel)`.

## Build/buy mode abilities
- Place, rotate, move and delete pieces on a grid with snap; walls and floors by drag; room fill.
- Catalogue of placeable items from the satchel/marketplace inventory; place counts against parcel
  object limits (`ParcelTools.register_object`).
- Constraints between parts: weld, hinge, rope, wheel (physics props), Garry's Mod-style concept.
- Every placement asks `Tiers.can(actor, "build", {"region": r, "parcel": p})` first.

## Crafting station sheet
- Open at a station (workbench / forge / infuser) or hands: list `Crafting.available(inventory, station)`.
- Show inputs with voxel material names (`Crafting.material_name`), skill gate, batch count stepper.
- Craft: `Crafting.craft(recipe, inventory, station, parcel, times, randf())` → show `made` or the reason.
- Infuse: pick an item + infusion → `Crafting.infuse(item, id, inventory, "infuser", parcel)`.
- Nothing is consumed on failure, so the sheet can always call and show the reason.
