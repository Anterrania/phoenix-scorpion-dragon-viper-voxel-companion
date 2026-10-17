# v0.11: Realistic companions and soft particles

- **Body:** a CC0 MakeHuman/MPFB 2 rigged human (`assets/characters/mh_female.glb`, about 28k vertices across body, hair cards, eyes, brows, lashes, sportsuit and shoes, with 1024 px textures). Godot's importer builds the LODs. It's generated with `tools/mh/gen_makehuman.py`, and the license is recorded in `art/LICENSES.md`.
- **`RealisticBody`:** applies avatar_dna through three shaders:
  - `shaders/character/skin.gdshader`: wrap and backscatter lighting that looks like subsurface scattering on the mobile renderer, chrome metal, procedural freckles, and circuit emission below the neck.
  - `hair.gdshader`: alpha-scissor two-sided hair cards with a root-to-tip DNA gradient.
  - `eye.gdshader`: the MakeHuman eye texture with the iris recolored, plus clearcoat.
- **Pose and motion:** arms are posed down from the A-pose, and idle/walk animation is procedural on the rig.
- **Foxy:** purple-to-magenta hair, green eyes, silver-blue chrome skin, and a subtle aura (a low warm light and 14 soft embers).
- **Aaliyah:** red hair, green eyes, freckles. Her horns are removed.
- **Circuit Nova:** chrome skin, curly violet afro hair cards, and blue circuit emission plus a light.
- **Particles:** `SoftParticle` generates a radial-gradient texture used as additive (glows) or alpha (snow, dust) billboard materials. All `ParticleFX` effects and the aura use it, and `SoftParticle.sanitize()` fixes any untextured quad on a companion model.
- **Fallback:** the primitive `HumanoidModel` is used only if the GLB is missing, and it logs a warning when that happens. The player avatar is still on `HumanoidModel`, because its attachment and DNA-slider system is tied to those nodes.
