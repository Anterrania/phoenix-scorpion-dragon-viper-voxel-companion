# Foxy spec: shouts and powers (SBX-F7)

Owner: **Foxy**. RPG concept (learned powers with cooldowns), our own powers, names and effects.

## Abilities
- Powers learned from quests (`QuestEngine` reward `items: ["power_x"]`) or exploring.
- Cooldowns, charge-up tiers, one equipped power plus one quick slot.
- Utility powers everywhere (light, push, slow fall, calm a creature).
- Damaging powers only where estate `allow_damage` is on (the fire bolt already follows this).
- Companions can use powers only when the e-stop is off (`AutonomyGuard`).
