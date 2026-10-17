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
varying float h;
void vertex(){ h = VERTEX.y; }
void fragment(){
	vec4 t = texture(albedo_tex, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float k = clamp((top_y - h) / max(0.01, top_y - tip_y), 0.0, 1.0);
	vec3 c = mix(root_color.rgb, tip_color.rgb, smoothstep(0.3, 1.0, k));
	ALBEDO = c * (0.22 + lum * 1.1);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.42;
	SPECULAR = 0.6;
	EMISSION = c * glow;
	BACKLIGHT = c * 0.25;
}
