# Foxy spec: crafting and infusion (SBX-F6)

Owner: **Foxy**. Survival-sandbox and RPG concepts, our own recipes.

## Abilities
- Recipes that take voxel materials (by palette id) and crafted parts, at a station (hands, workbench, forge, infuser).
- Skill gate per recipe, plus XP on craft. Quality tiers from skill.
- Infusion: add one effect to a crafted item (the enchanting concept). Effects come from our own table.
- Crafted items carry creator id + copy/modify/transfer perms, so they can be sold through `MarketDelivery`.
- Crafting on a parcel obeys estate build rules (`Tiers.can(actor, "build", parcel)`).
- Quest objectives: report `QuestEngine.report(actor, "build", item_id)`.

## Reference
Inactive reference: `scripts/sim/crafting.gd` + `data/sim/recipes.json` (SBX-SIM-4).
