# Player look: Phoenix, Anterranian Sovereign (v0.3)

Source: 3 reference images made by the user in the Grok app, stored in `art/references/player_phoenix/`.
Settings live in `data/player_avatar.json` (look `"phoenix"`), and the model is built by `HumanoidModel._build_phoenix_extras`.

| Trait | Reference | In game (v0.3) |
|---|---|---|
| Skin | warm brown | `#8a5636` PBR skin with warm backlight |
| Eyes | amber/brown, dark eyeliner | amber `#c07a22` irises, black liner strokes, strong brows |
| Hair | long, wild, wavy; streaks of black, magenta/pink, purple, platinum-white, gold | 26 layered strands plus a wavy second layer and face-framing fringe, cycling 8 streak colors, anisotropic sheen |
| Beard | black goatee / chin beard | tapered goatee + thin mustache |
| Ears | gold hoops | gold torus hoops |
| Neck | studded black choker; layered gold chains, dragon + scorpion pendants | studded choker, 3 gold chains, dragon medallion with magenta gem, scorpion pendant |
| Jacket | black leather moto, gold studs, gold phoenix/dragon embroidery | open two-panel leather jacket, lapels, shoulder studs, emissive gold embroidery strokes |
| Top | purple/magenta sequins | metallic emissive purple "sequin" material |
| Pants | black leather, gold chain belts | glossy black leather, 2 gold chain belts |

Limits: everything is built procedurally from smooth primitives (no sculpted mesh or textures yet),
so the face and hair read as stylized at phone distance, not as a portrait match. Next step: a
sculpted/rigged base mesh with baked textures (see art/LICENSES.md).
