# Glitter materials (palette v2) — SCAFFOLD, not yet created in the editor

Planned resources (create in Godot 4 once the engine pin lands):
- `resources/materials/glitter_sparkle.tres` — ShaderMaterial using `shaders/glitter_sparkle.gdshader`,
  `sparkle_noise` = NoiseTexture2D (FastNoiseLite cellular, 256px, seamless). Shared by all companions, wardrobe, regalia, props.
- `resources/materials/glitter_sparkle_voxel.tres` — same shader, `use_triplanar = true`, lower density/emission for terrain/blocks.
- Per-item tint overrides via `set_instance_shader_parameter` / material duplicates (magenta, gold, platinum glint colours).
- Mobile: keep emission low, disable on low-end preset (settings toggle "Sparkle FX").
