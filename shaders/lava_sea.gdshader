shader_type spatial;
// v0.8 fluid plane: Gerstner-style waves on starlight water (Cosmic) and slow lava swell (Venus),
// flat glossy ice (Alaska). Fresnel sky reflection + sun glint; detail-noise normals.
render_mode cull_disabled;
// RND-9: body moved to the include so the depth-FX variant shares it.
#include "res://shaders/include/fluid_sea.gdshaderinc"
