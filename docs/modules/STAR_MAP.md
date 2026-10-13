# Star Map

> **Future module, not implemented.** Phase: Phase 8. Design notes only.

- A galaxy of **realms**: each star system holds planets, and each planet is a seed + biome preset (Alaskan, cosmic, Venus fire, cyberpunk, more later).
- A 3D star map scene (MeshInstance points + lines) with travel routes, discovered/undiscovered systems and companion homeworlds.
- Travel works as a scene transition: load a new VoxelTerrain with the right generator and seed, and point its VoxelStream at that planet's save file.
- Procedural naming and lore hooks from LORE_AND_WORLD_NOTES.md.
- Later: ships as buildable voxel structures (Dual Universe-style), and quantum-travel-like transitions.

- Companion hooks (scaffold): **Celestia Nyx** (star-map keeper / lore) paired with **Azura Stellaris** (navigator / route plotting; concept art `assets/concept_art/batch_13/02_azura_stellaris_star_chart_robe.jpg`).
