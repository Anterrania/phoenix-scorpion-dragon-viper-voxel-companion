# Foxy spec: character creator (SBX-35)

Owner: **Foxy** (v0.12 avatar work). Dev side: `AvatarDNA`, `AvatarAppearance`, `Profile.save_profile`,
owner-only avatar edits through the security gate.

## Abilities
- Start from a preset or random; sliders grouped by body, face, hair, skin; undo/redo; randomise one group.
- Heritage blend: pick two parent presets and a mix slider (maps onto DNA genes).
- Outfit and accessories from the wardrobe, with mature gating as today.
- Save multiple looks (outfits) and switch quickly.
- Performance rank: show a simple cost badge (triangles, textures, attachments) so heavy looks are
  visible before upload, VRChat-style concept. Cap uploads per tier (`Tiers.can(actor, "upload")`).
- Companions' looks: owner only (`Profile.is_owner()`).
- Old saves must load with the new optional DNA fields (covered by dev tests after v0.12).
