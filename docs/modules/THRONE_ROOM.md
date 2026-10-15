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

## Phoenix wing throne & throne-room scene (batch_22)
- **Phoenix Wing Throne** (`phoenix_wing_throne` in `data/items/furniture.json`) — winged phoenix seat on a raised dais under a golden phoenix sigil, constellation-line wall decor. Distinct from the eagle-orb `monarch_throne` family (batch_04 / batch_15).
- Concept scene (`batch_22/02`) shows the Monarch in **Phoenix God** regalia on the dais. May serve as the primary hall centerpiece or as an alternate Monarch seat (player choice).
- Related wardrobe: `monarch_phoenix_god_regalia` (batch_22/01). Related landmark: `anterranian_capitol` (batch_22/03).
- Gold **'8'** floor seal appears in the crystal-hall regalia shot (batch_22/01); same recurring symbol as rings / household emblems — meaning still user-pending.
