// v0.11 realistic skin: albedo texture tinted by DNA, wrap lighting + red-shifted backscatter
// (subsurface-like on the mobile renderer), optional chrome (metal) and circuit emission, freckles.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;
uniform float metal = 0.0;
uniform float rough = 0.55;
uniform float sss = 0.35;
uniform vec4 sss_color : source_color = vec4(0.9, 0.35, 0.25, 1.0);
uniform float freckles = 0.0;
uniform vec4 circuit_color : source_color = vec4(0.15, 0.6, 1.0, 1.0);
uniform float circuit = 0.0;
varying vec3 obj;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex(){ obj = VERTEX; }
void fragment(){
	vec3 base = texture(albedo_tex, UV).rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(base, tint.rgb * (0.55 + lum * 0.9), tint_mix);
	if (freckles > 0.0) {
		// cheeks/nose band on the face front (object space, MakeHuman ~1.6m tall, faces +Z)
		float band = smoothstep(1.47, 1.49, obj.y) * (1.0 - smoothstep(1.522, 1.532, obj.y)) * smoothstep(0.1, 0.118, obj.z);
		vec2 q = obj.xy * 560.0;
		vec2 c = floor(q);
		vec2 f = fract(q) - 0.5;
		float r = 0.18 + 0.2 * hash(c + 7.0);
		float dot_ = step(0.8, hash(c)) * (1.0 - smoothstep(r * 0.6, r, length(f))) * band;
		col = mix(col, col * vec3(0.7, 0.52, 0.42), dot_ * freckles * 0.8);
	}
	ALBEDO = col * 0.78;
	METALLIC = metal;
	ROUGHNESS = mix(rough, 0.18, metal);
	if (circuit > 0.0) {
		vec2 g = fract(vec2(obj.x * 18.0 + obj.z * 7.0, obj.y * 14.0));
		float line = (1.0 - smoothstep(0.0, 0.02, abs(g.x - 0.5))) * step(0.5, hash(floor(vec2(obj.x * 18.0 + obj.z * 7.0, obj.y * 14.0))));
		float hline = (1.0 - smoothstep(0.0, 0.018, abs(g.y - 0.5))) * step(0.7, hash(floor(vec2(obj.x * 18.0 + obj.z * 7.0, obj.y * 14.0)) + 3.1));
		float body = 1.0 - smoothstep(1.38, 1.42, obj.y);
		EMISSION = circuit_color.rgb * max(line, hline) * circuit * 2.6 * body;
	}
	RIM = 0.25; RIM_TINT = 0.5;
}
void light(){
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + sss) / (1.0 + sss), 0.0, 1.0);
	vec3 scatter = sss_color.rgb * sss * (1.0 - metal) * clamp(ndl + 0.5, 0.0, 1.0) * (1.0 - clamp(ndl, 0.0, 1.0)) * 0.6;
	DIFFUSE_LIGHT += (wrap + scatter) * ATTENUATION * LIGHT_COLOR / PI * (1.0 - metal * 0.5);
	vec3 h = normalize(VIEW + LIGHT);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), mix(24.0, 160.0, metal));
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR * mix(0.12, 1.2, metal) * clamp(ndl, 0.0, 1.0);
}
