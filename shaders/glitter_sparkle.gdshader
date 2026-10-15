// STUB (untested). Palette v2 glitter sparkle for Godot 4. Shared by characters, items, props.
// Voxel variant: set use_triplanar = true and use with VoxelTerrain materials (world-space sampling).
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.04, 0.03, 0.05, 1.0);   // Royal Black
uniform vec4 glint_color : source_color = vec4(0.90, 0.89, 0.86, 1.0);  // Platinum
uniform vec4 accent_color : source_color = vec4(0.83, 0.69, 0.22, 1.0); // Gold
uniform sampler2D sparkle_noise : hint_default_white, filter_nearest, repeat_enable;
uniform float sparkle_density : hint_range(0.0, 1.0) = 0.92; // threshold, higher = fewer glints
uniform float sparkle_scale = 40.0;
uniform float twinkle_speed = 2.5;
uniform float emission_strength : hint_range(0.0, 8.0) = 2.0;
uniform float metallic_v : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.25;
uniform bool use_triplanar = false;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float sample_noise(vec2 uv) { return texture(sparkle_noise, uv * sparkle_scale).r; }

void fragment() {
	float n;
	if (use_triplanar) {
		vec3 w = abs(world_nrm); w /= (w.x + w.y + w.z);
		n = sample_noise(world_pos.yz * 0.1) * w.x + sample_noise(world_pos.xz * 0.1) * w.y + sample_noise(world_pos.xy * 0.1) * w.z;
	} else {
		n = sample_noise(UV);
	}
	// Twinkle: per-flake phase from noise, view-dependent glint.
	float phase = fract(n * 37.0);
	float twinkle = 0.5 + 0.5 * sin(TIME * twinkle_speed + phase * 6.2831);
	float view_glint = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float flake = step(sparkle_density, n) * twinkle * (0.4 + 0.6 * view_glint);
	vec3 glint = mix(glint_color.rgb, accent_color.rgb, step(0.5, phase));
	ALBEDO = mix(base_color.rgb, glint, flake);
	METALLIC = metallic_v;
	ROUGHNESS = mix(roughness_v, 0.05, flake);
	EMISSION = glint * flake * emission_strength;
}
