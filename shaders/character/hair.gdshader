// v0.11 hair cards: alpha-scissor (no sort issues), two-sided, DNA gradient root->tip
// (by object-space height), anisotropic-ish highlight.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 root_color : source_color = vec4(0.4, 0.2, 0.8, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.2, 0.8, 1.0);
uniform float top_y = 1.75;
uniform float tip_y = 1.05;
uniform float alpha_cut = 0.35;
uniform float glow = 0.0;
uniform sampler2D strand_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D strand_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float strand_tiling = 6.0;
uniform int streak_count = 0;          // >0: multi-color streaks (player look)
uniform vec4 streak0 : source_color; uniform vec4 streak1 : source_color; uniform vec4 streak2 : source_color;
uniform vec4 streak3 : source_color; uniform vec4 streak4 : source_color;
float h1(float x){ return fract(sin(x * 91.7) * 43758.5); }
varying float h;
void vertex(){ h = VERTEX.y; }
void fragment(){
	vec4 t = texture(albedo_tex, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float k = clamp((top_y - h) / max(0.01, top_y - tip_y), 0.0, 1.0);
	vec3 c = mix(root_color.rgb, tip_color.rgb, smoothstep(0.3, 1.0, k));
	if (streak_count > 0) {
		float band = floor(UV.x * 26.0);
		int idx = int(h1(band) * float(streak_count)) % streak_count;
		vec4 sc[5] = vec4[](streak0, streak1, streak2, streak3, streak4);
		c = mix(c, sc[idx].rgb, 0.85);
	}
	float fine = texture(strand_mask, UV * vec2(strand_tiling, 1.0)).r;
	ALBEDO = c * (0.22 + lum * 1.1) * (0.8 + 0.4 * fine);
	NORMAL_MAP = texture(strand_n, UV * vec2(strand_tiling, 1.0)).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	ALPHA = t.a * (0.75 + 0.35 * fine);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.42;
	SPECULAR = 0.6;
	EMISSION = c * glow;
	BACKLIGHT = c * 0.25;
}
