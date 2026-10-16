shader_type spatial;
// Low-lying fluid plane: molten lava in Venus, frozen glacial ice elsewhere, void-glass in Cosmic.
uniform sampler2D biome_map : filter_linear, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float map_half = 4096.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float bv = texture(biome_map, (wpos.xz + map_half) / (2.0 * map_half)).r;
	float venus = smoothstep(-0.15, -0.55, bv);
	float cosmic = smoothstep(0.15, 0.55, bv);
	float n = texture(detail, wpos.xz * 0.02 + vec2(TIME * 0.004, 0.0)).r;
	float n2 = texture(detail, wpos.xz * 0.08 - vec2(0.0, TIME * 0.01)).r;
	vec3 ice = mix(vec3(0.5, 0.7, 0.85), vec3(0.85, 0.93, 1.0), n2);
	vec3 lava_crust = vec3(0.05, 0.02, 0.02);
	float hot = smoothstep(0.45, 0.65, n * 0.6 + n2 * 0.4);
	vec3 voidg = vec3(0.04, 0.01, 0.1);
	ALBEDO = mix(mix(ice, lava_crust, venus), voidg, cosmic);
	ROUGHNESS = mix(mix(0.05, 0.9 - hot * 0.6, venus), 0.02, cosmic);
	METALLIC = 0.3 * cosmic;
	EMISSION = vec3(1.0, 0.35, 0.05) * hot * 5.0 * venus + vec3(0.6, 0.1, 0.8) * n2 * 0.4 * cosmic;
}
