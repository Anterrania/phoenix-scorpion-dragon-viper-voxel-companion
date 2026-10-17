// v0.12 outfit recolor for CC0 MakeHuman clothes: the source texture is split by hue into
// "top" (blue/colored garments) and "bottom" (dark/denim) zones, each recolored from DNA,
// with leather sheen, optional sequin sparkle, gold studs and circuit emission lines.
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float use_normal = 0.0;
uniform vec4 top_color : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform float split_mode = 0.0;      // 0: blue=top dark=bottom (sportsuit); 1: blue=bottom (jeans) else top (jacket)
uniform float top_leather = 0.6;
uniform float bottom_leather = 0.6;
uniform float top_sequin = 0.0;
uniform float bottom_sequin = 0.0;
uniform vec4 sequin_color : source_color = vec4(0.6, 0.2, 0.9, 1.0);
uniform float studs = 0.0;
uniform vec4 stud_color : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform float circuit = 0.0;
uniform vec4 circuit_color : source_color = vec4(0.15, 0.6, 1.0, 1.0);
varying vec3 obj;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex(){ obj = VERTEX; }
void fragment(){
	vec3 t = texture(albedo_tex, UV).rgb;
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	float blue = smoothstep(0.03, 0.12, t.b - max(t.r, t.g * 0.9));
	float is_top = split_mode < 0.5 ? blue : 1.0 - blue;
	vec3 base = mix(bottom_color.rgb, top_color.rgb, is_top);
	float leather = mix(bottom_leather, top_leather, is_top);
	float seq = mix(bottom_sequin, top_sequin, is_top);
	vec3 col = base * (0.55 + lum * 0.9);
	float rough = mix(0.75, 0.32, leather);
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (seq > 0.0) {
		vec2 c = floor(UV * 420.0);
		float sp = hash(c);
		col = mix(col, sequin_color.rgb * (0.6 + sp * 0.9), seq * 0.85);
		metal = mix(metal, 0.8, seq); rough = mix(rough, 0.18 + 0.3 * sp, seq);
		emit += sequin_color.rgb * step(0.985, sp) * seq * 1.5;
	}
	if (studs > 0.0) {
		vec2 g = fract(UV * vec2(70.0, 70.0)) - 0.5;
		float d = step(length(g), 0.18) * step(0.55, hash(floor(UV * 70.0))) * is_top;
		col = mix(col, stud_color.rgb, d * studs); metal = mix(metal, 1.0, d * studs); rough = mix(rough, 0.2, d * studs);
	}
	if (circuit > 0.0) {
		vec2 g = fract(vec2(obj.x * 22.0, obj.y * 9.0));
		float line = (1.0 - smoothstep(0.0, 0.03, abs(g.x - 0.5))) * step(0.55, hash(floor(vec2(obj.x * 22.0, obj.y * 9.0))));
		emit += circuit_color.rgb * line * circuit * 2.2 * (1.0 - is_top);
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = mix(0.35, 0.6, leather);
	EMISSION = emit;
	if (use_normal > 0.5) { NORMAL_MAP = texture(normal_tex, UV).rgb; NORMAL_MAP_DEPTH = 1.0; }
	RIM = leather * 0.3; RIM_TINT = 0.4;
}
