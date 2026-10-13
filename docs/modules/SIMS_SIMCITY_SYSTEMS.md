# Sims / SimCity-Style Systems — PLAN ONLY
Builds on NEEDS.md, RELATIONSHIPS.md, CITY_BUILDING.md, DNA_GENETICS.md (Seed-style). Don't duplicate those docs; this is the glue.
- **Individual sim loop (Sims):** needs decay → mood (RELATIONSHIPS.md) → choose an action from usable objects that advertise need relief → relationship deltas.
- **Settlement loop (SimCity):** zones (residential/industrial/research) placed as voxel regions, plus power/water/data network graphs and a simple demand meter. Companions are the workers and citizens.
- **Star Citizen layer:** survival needs (O2, hunger, thirst, temperature) only in hostile realms (Venus fire, cosmic). Star map routes between realms (STAR_MAP.md). The MobiGlass HUD shows all of it (MOBIGLASS_UI.md).
- Tick: one sim tick per second, run on a worker thread with low priority on Android.
