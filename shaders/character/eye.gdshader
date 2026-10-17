// v0.11 eye: MakeHuman eye texture, iris recolored by DNA, glossy cornea highlight, optional glow.
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 iris : source_color = vec4(0.2, 0.9, 0.4, 1.0);
uniform float glow = 0.0;
void fragment(){
	vec3 t = texture(albedo_tex, UV).rgb;
	float sat = max(t.r, max(t.g, t.b)) - min(t.r, min(t.g, t.b));
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	float is_iris = smoothstep(0.08, 0.2, sat) * (1.0 - smoothstep(0.75, 0.9, lum));
	vec3 c = mix(t, iris.rgb * (0.4 + lum * 1.6), is_iris);
	ALBEDO = c;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	CLEARCOAT = 1.0; CLEARCOAT_ROUGHNESS = 0.02;
	EMISSION = iris.rgb * is_iris * glow;
}
