# DNA / Genetics

> **Future module, not implemented.** Phase: Phase 7. Design notes only.

Star Citizen-style DNA blending for faces and bodies, adapted to voxel/mesh characters.
- **Genome** is a JSON vector of morph weights (face shape, eyes, nose, jaw, body height and build) plus palette genes (hair, eye and skin colors) and trait genes (emissive accents, fire essence).
- **Blending:** choose 2–3 "parents" (e.g. Aaliyah + Foxy Ani + Circuit Nova accents, matching the CHARACTER_BLUEPRINT inheritance rules). The child is a weighted lerp plus small mutation noise.
- **Rendering:** for mesh bodies, genes drive blend shapes on a base mesh. For voxel bodies, genes pick voxel part variants and palettes.
- Stored as `genome` in persona.json (future schema v3) so the standalone bot's avatar art can match.
- Original characters only; no scanning of real people's likenesses.
