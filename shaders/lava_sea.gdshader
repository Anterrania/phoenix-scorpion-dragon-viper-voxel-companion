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
// v0.9 realistic fluids: depth-tinted water with fresnel sky reflection, sun glint and
// crest/shore foam; emissive FLOWING lava (domain-warped scrolling crust over glowing magma);
// ice with frost sparkle.
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform float foam_amount = 1.0;
uniform float lava_flow = 1.0;
float h21(vec2 p) { return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float cosmic; float venus = bmask(wpos.xz, cosmic);
	float alaska = clamp(1.0 - venus - cosmic, 0.0, 1.0);
	float n = texture(detail, wpos.xz * 0.02 + vec2(TIME * 0.004, 0.0)).r;
	float n2 = texture(detail, wpos.xz * 0.08 - vec2(0.0, TIME * 0.01)).r;
	float n3 = texture(detail, wpos.xz * 0.15 + vec2(TIME * 0.02, TIME * 0.013)).r;
	vec3 V = normalize(VIEW);
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(normalize(NORMAL), V), 0.0, 1.0), 5.0);
	// water
	vec3 deep = vec3(0.02, 0.01, 0.09); vec3 shallow = vec3(0.1, 0.06, 0.32);
	vec3 water = mix(deep, shallow, n3 * 0.7 + clamp(wv, 0.0, 1.0) * 0.6);
	vec3 refl = sky_reflect * fres;
	float foam = smoothstep(0.12, 0.3, wv + (n3 - 0.5) * 0.2) * smoothstep(0.4, 0.7, n2 + n3 * 0.5) * foam_amount;
	vec3 H = normalize(normalize(sun_dir) + V);
	float glint = pow(max(dot(normalize(NORMAL), H), 0.0), 220.0) * 6.0;
	vec3 water_col = mix(water + refl, vec3(0.92, 0.88, 1.0), foam);
	// lava: domain-warped flow
	vec2 flow = wpos.xz * 0.04 + vec2(n2, n3) * 0.6 * lava_flow + vec2(TIME * 0.015, TIME * 0.01) * lava_flow;
	float crust_n = texture(detail, flow).r;
	float crust_n2 = texture(detail, flow * 2.7 - vec2(TIME * 0.02)).r;
	float hot = smoothstep(0.42, 0.62, crust_n * 0.65 + crust_n2 * 0.35);
	float pulse = 0.8 + 0.2 * sin(TIME * 1.7 + crust_n * 12.0);
	vec3 magma = mix(vec3(1.0, 0.2, 0.02), vec3(1.0, 0.75, 0.25), crust_n2) * pulse;
	vec3 lava_crust = mix(vec3(0.03, 0.015, 0.015), vec3(0.12, 0.05, 0.03), crust_n2);
	// ice with frost sparkle
	vec3 ice = mix(vec3(0.5, 0.7, 0.85), vec3(0.85, 0.93, 1.0), n2) + sky_reflect * fres * 0.4;
	float frost = step(0.992, h21(wpos.xz * 30.0)) * pow(max(dot(normalize(NORMAL), H), 0.0), 30.0);
	ALBEDO = ice * alaska + mix(lava_crust, magma * 0.3, hot) * venus + water_col * cosmic;
	ROUGHNESS = 0.06 * alaska + mix(0.95, 0.4, hot) * venus + mix(0.02, 0.6, foam) * cosmic;
	METALLIC = 0.15 * cosmic;
	SPECULAR = 0.6;
	NORMAL_MAP = normalize(vec3(n2 - n3, 0.5 + (n - 0.5) * 0.3, 1.2)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.3 * alaska + 0.8 * venus + 1.0 * cosmic;
	float crest = smoothstep(0.15, 0.35, wv) * cosmic;
	EMISSION = magma * hot * 4.5 * venus
		+ (vec3(0.6, 0.1, 0.8) * n2 * 0.3 + vec3(0.9, 0.6, 1.0) * crest * 0.6 + refl * 0.4 + vec3(1.0, 0.9, 0.8) * glint) * cosmic
		+ vec3(0.9, 0.95, 1.0) * frost * 2.0 * alaska;
}
