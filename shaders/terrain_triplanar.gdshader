shader_type spatial;
// v0.3 triplanar PBR terrain (no texture files: procedural detail from one small noise texture).
// Biome weights come from a baked biome map; Alaska = snow/ice/granite, Venus = obsidian/basalt
// with emissive lava cracks, Cosmic = crystalline violet ground with magenta/cyan glints.
render_mode cull_back;
// RND-7: body moved to the include so the LOD-fade variant shares it (no duplicated code).
#include "res://shaders/include/terrain_triplanar.gdshaderinc"
