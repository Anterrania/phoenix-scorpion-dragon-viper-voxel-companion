shader_type spatial;
// HEAVEN-1: glowing waterways, canals, pools and the lagoon. Flowing bands + fresnel sheen,
// translucent; no screen texture reads (Mobile-safe, one pass).
render_mode blend_mix, cull_disabled, shadows_disabled, depth_draw_opaque;
uniform vec3 deep = vec3(0.05, 0.42, 0.62);
uniform vec3 glow = vec3(0.45, 0.95, 1.0);
uniform float flow = 0.6;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float t = TIME * flow;
	float bands = sin(wpos.x * 0.35 + wpos.z * 0.22 + t * 2.0) * 0.5 + 0.5;
	float ripple = sin(wpos.x * 1.7 - t * 3.0) * sin(wpos.z * 1.3 + t * 2.4) * 0.5 + 0.5;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 base = mix(deep, glow, bands * 0.35 + ripple * 0.15) * COLOR.rgb;
	ALBEDO = base;
	EMISSION = glow * (0.35 + 0.4 * bands * ripple) * COLOR.rgb;
	ROUGHNESS = 0.04;
	METALLIC = 0.1;
	SPECULAR = 0.8;
	ALPHA = clamp(0.72 + fres * 0.25, 0.0, 0.95);
}
