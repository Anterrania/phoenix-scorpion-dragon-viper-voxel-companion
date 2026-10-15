# Asset Library

> **Planned module, not implemented. No live servers or services exist.** Phase: 3–6.

- **Structure:** `assets/blocks/` (atlas textures + VoxelBlockyLibrary), `assets/models/` (MagicaVoxel `.vox` → mesh), `assets/props/` (usable object scenes), `assets/vfx/`, `assets/audio/`, `assets/ui/`.
- **Manifest:** `assets/manifest.json` lists id, type, path, license, author, source URL, and which biomes use it.
- **Licensing:** CC0/CC-BY or original work only. Record the license for every asset. No ripped game assets or real brand logos.
- **Mobile budgets:** 1024² atlases, ETC2/ASTC compression, low-poly props, and a LOD for anything over 2k tris.
- **Catalog:** the Build/Buy UI reads the manifest. Optional downloadable asset packs come later.
- Tooling: an import script that checks the manifest against the files and flags missing licenses.
