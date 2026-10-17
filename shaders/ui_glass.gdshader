// Phoenix Glass: frosted panel. Blurs what is behind (screen mip LOD), tints, adds rim + sparkle.
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.06, 0.03, 0.08, 0.62);
uniform vec4 rim_color : source_color = vec4(1.0, 0.18, 0.72, 0.55);
uniform vec2 rect_size = vec2(400.0, 300.0); // set by GlassCard
uniform float corner_radius_px = 28.0;
uniform float rim_width_px = 1.5;
uniform float sparkle = 0.25;
float sdbox(vec2 p, vec2 b, float r){ vec2 q = abs(p) - b + r; return length(max(q,0.0)) + min(max(q.x,q.y),0.0) - r; }
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment(){
	vec2 p = (UV - 0.5) * rect_size;
	float d = sdbox(p, rect_size * 0.5, corner_radius_px);
	float inside = 1.0 - smoothstep(-1.0, 0.5, d);
	vec3 bg = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	vec3 col = mix(bg, tint.rgb, tint.a);
	col += vec3(0.08) * (1.0 - UV.y) * 0.6; // top sheen
	float rim = 1.0 - smoothstep(0.0, rim_width_px, abs(d + rim_width_px));
	col = mix(col, rim_color.rgb, rim * rim_color.a);
	float s = step(0.996, hash(floor(UV * 180.0) + floor(TIME * 2.0)));
	col += vec3(1.0, 0.85, 0.5) * s * sparkle;
	COLOR = vec4(col, inside);
}
