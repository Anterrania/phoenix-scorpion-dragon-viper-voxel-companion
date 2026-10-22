shader_type spatial;
// RND-9 water variant for high/ultra: depth fade + shoreline foam (reads the depth buffer, so it
// renders in the transparent pass). Same body as lava_sea.gdshader.
render_mode cull_disabled, depth_draw_always;
#define DEPTH_FX
#include "res://shaders/include/fluid_sea.gdshaderinc"
