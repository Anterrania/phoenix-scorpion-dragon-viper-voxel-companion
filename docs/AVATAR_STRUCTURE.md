# Avatar structure (v0.9): Aurora-Sim/OpenSim appearance + Star Citizen-style DNA

Code: `scripts/agent/avatar_appearance.gd` (`AvatarAppearance`). It feeds the existing
`AvatarDNA` morph/blend/attach pipeline (`scripts/agent/avatar_dna.gd`).

## Modelled on OpenSim / Aurora-Sim `AvatarAppearance`
| OpenSim field | Here | Notes |
|---|---|---|
| `Serial` | `serial` | bumps on every change (for future grid sync) |
| `VisualParams` (byte[]) | `visual_params` id → 0..255 | SL param ids where one exists (33 Height, 34 Thickness, 36 Shoulders, 682 Head Size, 17 Jaw, 692/693 Leg/Arm length) |
| `Wearables[WearableType]` | `wearables[type]` → stack | 16 types: shape, skin, hair, eyes (body parts, one each), shirt, pants, shoes, socks, jacket, gloves, undershirt, underpants, skirt, alpha, tattoo, physics. Clothing stacks up to 5 layers |
| `Texture` / bake faces | (next) | baked layers will composite skin + tattoo + clothing layers into one texture per region (head/upper/lower/eyes/hair) |
| `AvatarAttachments` | `attachments[point_id]` | OpenSim attach point ids (1 Chest, 2 Skull, 5/6 hands, 7/8 feet, 9 Spine, 10 Pelvis, 11 Mouth, 17 Nose, 39 Neck, 40 Avatar Center). Multiple items per point ("add" like Firestorm) |
| `AvatarHeight` | `avatar_height` | |

## Mapping to Star Citizen-style modular DNA
- `dna_blend[slot]` = up to 3 parent heads/bodies + weights, per slot:
  head, eyes, brows, nose, ears, mouth, jaw, face, body, skin, hair.
- Body parts feed slots: shape → body, skin → skin, hair → hair, eyes → eyes.
- `to_dna_sliders()` converts visual params into AvatarDNA's -1..1 sliders.
- `to_dna_attachments()` converts attachments into AvatarDNA attach entries (mesh/GLB).
- Alpha wearables map to `AvatarDNA.MASKS` (hide body parts under mesh clothing).

## Next
1. Save `AvatarAppearance` in the profile next to the current avatar dict (migration).
2. Bake layer compositing (skin → tattoo → underwear → shirt/pants → jacket).
3. Wardrobe UI: Outfits / Wear / Add / Take off, by wearable type (Firestorm-style).
4. Grid sync: send `to_dict()` to the region server when the Aurora-style server lands.
