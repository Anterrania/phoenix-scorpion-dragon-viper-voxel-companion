# Buildable Throne Room — PLAN
A player-built royal hall in the home realm. It uses props from `data/items/furniture.json`.

- **Layout template (blueprint):** about 21×12×31 voxels. Raised 3-step dais at the north end. The Monarch's throne sits center-dais and Foxy's consort throne to its right, one step lower or level (player choice). There's a carpet runner (magenta with gold trim) from the doors to the dais, and pillar rows with gold capitals.
- **Decor:** "Anterrania" banners behind the dais, constellation emissive voxels in the ceiling, braziers with phoenix-fire particles, and an orb crest above the doors.
- **Building:** the player places it themselves, or asks Atlas Forge (architect) to construct it in phases with VoxelTool (floor → walls → dais → pillars → props). Thrones snap to the grid and have a sit point.
- **Function (later):** a council session spot (elder/heir council companions gather), wardrobe and regalia display, and a ceremony trigger (coronation event). Permissions: only the owner can sit on the Monarch's throne (MULTIPLAYER.md realm roles).
- Cosmetic/social only. No real-money items.

## Throne concept variants (batch_15 / batch_16)
- **Monarch throne** — additional art: black tufted back, magenta seat, twin eagles, ringed-orb crest with crescent (`batch_15/04`). Same `monarch_throne` prop family as batch_04.
- **Foxy consort throne** — additional art with oval ringed gem, crescent+sun, eagles (`batch_15/05`). Plaque in the art reads **ATERNA** (missing E); official motto remains **AETERNA**.
- **Heir throne (Solarian)** — magenta-winged variant with banner **POTENTIA HERES SEMI-DIVUS** (`batch_15/06`) confirms the prince heir inscription.
- **Heir throne (Lumira)** — batch_16/01 variant (black wings, gold spires, oval magenta gem with pearl + celestial ring, crescent crest). Visible banners roughly **POTENTIA … SEMI DEIVA SERVA** (possible **HERES**). Confirms feminine **SEMI DEIVA** for Princess Lumira vs **SEMI-DIVUS** for Solarian; exact sash wording still soft-confirm.
- Heir thrones may sit on side daises or a second-row council platform (player choice). All snap to the voxel grid with sit points.
