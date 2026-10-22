shader_type spatial;
// RND-5 instanced ground cover (MultiMesh). Vertex colour = albedo, COLOR.a = sway weight
// (0 at the root, 1 at the tip). Per-instance phase from the instance's world position.
// Unlit-ish (no specular), double-sided, no textures: one tiny program for every tuft.
render_mode cull_disabled, specular_disabled;
uniform float sway = 0.12;
uniform vec2 wind = vec2(1.2, 0.4);
uniform float emit = 0.0;
varying vec3 col;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = TIME * 1.7 + dot(o.xz, vec2(0.37, 0.21));
	VERTEX.xz += normalize(wind + vec2(0.001)) * sin(ph) * sway * COLOR.a * length(wind);
	col = COLOR.rgb;
}
void fragment() {
	ALBEDO = col;
	ROUGHNESS = 0.9;
	EMISSION = col * emit;
}
