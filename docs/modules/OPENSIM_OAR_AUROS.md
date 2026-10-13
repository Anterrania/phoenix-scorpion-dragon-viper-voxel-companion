# OpenSim / OAR / Aurora-Sim ("Auros") Notes — PLAN ONLY
Status: research notes. No OpenSim/Aurora grid is running or connected.

- **OAR (OpenSim Archive):** tar.gz of region terrain (RAW heightmap), objects (XML prims), assets, parcels. Idea: one-way **import** of a user-owned OAR → convert heightmap into VoxelTerrain realm params + generator seed. Prims → voxel stamps or placeholder meshes (lossy).
- **IAR (inventory archive):** maybe later, for user-owned assets into the asset library (see ASSET_LIBRARY.md). Respect licensing/permissions flags.
- **Aurora-Sim / Auros:** an OpenSim fork, now largely inactive. We'd only use it as a reference for region/estate concepts (estates → realms, regions → chunks of the voxel world).
- **Not planned:** live grid hosting, Hypergrid, or running LSL inside Godot.
- Next steps: write a converter spec (heightmap → `data/realm_presets/*.json`), then a test with a sample OAR.
