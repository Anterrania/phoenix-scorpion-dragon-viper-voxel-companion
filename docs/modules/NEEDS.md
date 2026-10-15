# Needs

> **Future module, not implemented.** Phase: Phase 6. Design notes only.

Each companion and the player get needs with values from 0 to 100 that decay over time (Sims-style), plus survival stats like Star Citizen's hunger/thirst.
| Need | Decay | Refilled by |
|---|---|---|
| Hunger | -1/2 min | food objects, cooking stations |
| Energy | -1/3 min, faster when building | beds, couches, sleep |
| Social | -1/4 min alone | chat, emotes, shared activities |
| Fun | -1/5 min | dance, games, exploring realms |
| Hygiene | slow | showers, hot springs |
| Comfort | context | furniture, temperature (Alaskan cold vs. Venus heat) |
| Purpose | slow | building projects, quests |
- Implement as a `NeedsComponent` node with a `Dictionary` and a tick on a Timer, not every frame.
- Utility AI: the lowest need weighted by personality picks the next action (eat/sleep/talk/build).
- Needs shift mood (see RELATIONSHIPS.md). Low energy means slower building.
- Save inside the memory export file. Can be turned off in Settings (relaxed/creative mode).
