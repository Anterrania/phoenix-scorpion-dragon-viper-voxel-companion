# Art licenses

## Companion body: `assets/characters/mh_female.glb`, `assets/characters/mh_eye.png`
- **Source:** MakeHuman / MPFB 2 (MakeHuman Community). The body, the `game_engine` rig, the skin (`young_caucasian_female`), the eyes, eyebrows (`eyebrow001`), eyelashes (`eyelashes01`), hair (`long01`, `afro01`), outfit (`female_sportsuit01`) and shoes (`shoes02`) all come from the MakeHuman system assets pack (`makehuman_system_assets_cc0.zip`).
- **License:** **CC0 1.0** (public domain). MakeHuman's assets and exported models were released as CC0 in 2020. No attribution is required; we credit it anyway.
- **How it was generated:** headless Blender 4.2.3 with MPFB 2, using `tools/mh/gen_makehuman.py`. Textures were downscaled to 1024 px, macro shape keys were baked, and the result was exported as GLB. Godot generates mesh LODs on import.
- **Downloads:** https://files.makehumancommunity.org/plugins/mpfb2-latest.zip and https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip

## Particle texture
- Procedurally generated in code (`SoftParticle`, a radial gradient). No external asset.

## v0.12 character bodies
- `assets/characters/{foxy_ani,aaliyah,circuit_nova,default_female,phoenix_player}.glb`: CC0, generated with MakeHuman/MPFB 2 by `tools/mh/gen_makehuman.py` (specs in the generator inputs). Face blend shapes come from MPFB's bundled expression-unit targets (CC0).
- Owner-provided models: none used. The `.glb` files the media catalog lists for Foxy, Aaliyah and Circuit Nova (M2079–M2093, `/workspace/media-archive/history/companions/*/*.glb`) are byte-identical (sha256) copies of these generated MakeHuman files, not separate owner models.
