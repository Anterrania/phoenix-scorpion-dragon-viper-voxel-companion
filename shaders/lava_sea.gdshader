shader_type spatial;
// v0.8 fluid plane: Gerstner-style waves on starlight water (Cosmic) and slow lava swell (Venus),
// flat glossy ice (Alaska). Fresnel sky reflection + sun glint; detail-noise normals.
render_mode cull_disabled;
uniform sampler2D biome_map : filter_linear, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float map_half = 4096.0;
uniform float wave_height = 0.35;
uniform float wave_quality = 1.0;  // 0 low .. 1 high
uniform vec3 sky_reflect : source_color = vec3(0.45, 0.55, 0.85);
varying vec3 wpos;
varying float wv;
float bmask(vec2 xz, out float cosmic) {
	float bv = texture(biome_map, (xz + map_half) / (2.0 * map_half)).r;
	cosmic = smoothstep(0.15, 0.55, bv);
	return smoothstep(-0.15, -0.55, bv);
}
vec3 gerstner(vec2 p, vec2 d, float steep, float wl, float t) {
	float k = 6.2831 / wl; float c = sqrt(9.8 / k); float f = k * (dot(d, p) - c * t); float a = steep / k;
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cosmic; float venus = bmask(w.xz, cosmic);
	vec3 g = gerstner(w.xz, normalize(vec2(1, 0.3)), 0.25, 18.0, TIME) + gerstner(w.xz, normalize(vec2(-0.4, 1)), 0.18, 9.0, TIME * (venus > 0.5 ? 0.15 : 1.0));
	if (wave_quality > 0.5) g += gerstner(w.xz, normalize(vec2(0.7, -0.7)), 0.12, 4.0, TIME);
	VERTEX += g * (cosmic + venus * 0.35) * (wave_height / 0.35);
	wv = g.y;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float cosmic; float venus = bmask(wpos.xz, cosmic);
	float n = texture(detail, wpos.xz * 0.02 + vec2(TIME * 0.004, 0.0)).r;
	float n2 = texture(detail, wpos.xz * 0.08 - vec2(0.0, TIME * 0.01)).r;
	float n3 = texture(detail, wpos.xz * 0.15 + vec2(TIME * 0.02, TIME * 0.013)).r;
	vec3 ice = mix(vec3(0.5, 0.7, 0.85), vec3(0.85, 0.93, 1.0), n2);
	vec3 lava_crust = vec3(0.05, 0.02, 0.02);
	float hot = smoothstep(0.45, 0.65, n * 0.6 + n2 * 0.4);
	vec3 water = mix(vec3(0.03, 0.01, 0.12), vec3(0.12, 0.05, 0.3), n3);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 5.0);
	vec3 refl = sky_reflect * (0.04 + 0.96 * fres);
	ALBEDO = mix(mix(ice, lava_crust, venus), water + refl * 0.6, cosmic);
	ROUGHNESS = mix(mix(0.05, 0.9 - hot * 0.6, venus), 0.03, cosmic);
	METALLIC = mix(0.0, 0.2, cosmic);
	SPECULAR = 0.6;
	NORMAL_MAP = normalize(vec3(n2 - n3, 0.5 + (n - 0.5) * 0.3, 1.2)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.3, 1.0, cosmic);
	float crest = smoothstep(0.15, 0.35, wv) * cosmic;
	EMISSION = vec3(1.0, 0.35, 0.05) * hot * 5.0 * venus + vec3(0.6, 0.1, 0.8) * n2 * 0.4 * cosmic + vec3(0.9, 0.6, 1.0) * crest * 0.8 + refl * fres * cosmic * 0.5;
}
