# Foxy spec: needs, moods and relationships (SBX-F1)

Owner: **Foxy** (client feature + its data). Concepts from life sims, rebuilt in our own code; no names or numbers copied.

## Abilities
- Decaying needs per companion/NPC (hunger, energy, social, fun, hygiene, comfort, purpose), ticking on a timer, not every frame.
- Moodlets with timers that add up to one mood; mood unlocks or blocks some interactions.
- Autonomy: when free-roaming, a companion picks the action that best relieves its most urgent need, weighted by personality (DNA traits).
- Relationships: friendship and romance levels with history; family links through DNA lineage.
- Relaxed mode: needs off (Settings).
- Comfort/rested buff from beds, fires and shelter.

## Hooks into dev systems
- Quest objectives can be reported from need actions: `QuestEngine.report(actor, "use", "plant", 1, now)`.
- Permissions: anything that writes another member's data goes through `Tiers.can`; companion changes the owner makes need `Profile.is_owner()`.

## Reference
An inactive reference model exists in `scripts/sim/needs_mood.gd` (SBX-SIM-1) plus `patches/companion_life_needs_mood.patch`. It was written before the split. Adopt it, change it or replace it.
