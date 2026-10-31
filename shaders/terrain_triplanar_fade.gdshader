shader_type spatial;
// RND-7 terrain variant with dithered LOD cross-fade (high/ultra tiers). Same body as
// terrain_triplanar.gdshader plus the u_lod_fade discard.
render_mode cull_back;
#define LOD_FADE
#include "res://shaders/include/terrain_triplanar.gdshaderinc"
