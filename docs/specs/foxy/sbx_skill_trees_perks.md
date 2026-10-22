# Foxy spec: skill trees, perks and body stats (SBX-F5)

Owner: **Foxy**. RPG and open-world concepts, our own trees and numbers.

## Abilities
- Skills that level by use (`scripts/progression/skill_by_use.gd`, already shipped), and a character level.
- Perk points from levels; perk trees with level gates, prerequisites and ranks; respec (the owner can respec anyone).
- Body stats trained by use (stamina, swimming/lung capacity, strength), with slow decay.
- Quest rewards arrive as `{"xp": {skill: n}}` from `QuestEngine.claim()`. Feed them into SkillByUse.
- Nothing is bought with Aethel Coin. No paid XP boosts.

## Reference
Inactive reference: `scripts/sim/perk_tree.gd` + `data/sim/perks.json` (SBX-SIM-2).
