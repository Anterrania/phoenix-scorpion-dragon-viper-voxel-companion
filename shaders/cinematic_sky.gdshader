shader_type sky;
// v0.3 cinematic alien sky: physically-flavoured atmosphere gradient, sun disk + halo, star field
// that shows through the thin upper atmosphere, a ringed gas giant and two moons.
// No TIME use, so the radiance map only re-bakes when biome colors change (cheap on mobile).
uniform vec3 top_color : source_color = vec3(0.05, 0.09, 0.25);
uniform vec3 horizon_color : source_color = vec3(0.42, 0.56, 0.78);
uniform vec3 ground_color : source_color = vec3(0.1, 0.1, 0.12);
uniform float star_strength = 0.6;
// v0.8 procedural clouds
uniform float cloud_cover = 0.45;
uniform float cloud_speed = 0.006;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.97, 0.95);
uniform int cloud_octaves = 4;
uniform vec3 planet_dir = vec3(-0.35, 0.5, -0.8);
uniform vec3 planet_color : source_color = vec3(0.75, 0.42, 0.85);
uniform vec3 moon1_dir = vec3(0.5, 0.45, -0.6);
uniform vec3 moon2_dir = vec3(0.2, 0.62, 0.75);
// RND-8 realm sky variants + night. 0 standard, 1 aurora (Alaskan realm), 2 deep starfield (Cosmic).
// Variant detail is skipped in the radiance/cubemap pass (AT_CUBEMAP_PASS), so reflections and
// ambient light stay cheap and only the visible sky pays for it.
uniform int sky_variant = 0;
uniform float aurora_strength = 1.0;
uniform vec3 aurora_low : source_color = vec3(0.15, 1.0, 0.55);
uniform vec3 aurora_high : source_color = vec3(0.85, 0.25, 0.95);

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p, int oct) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 6; i++) { if (i >= oct) break; s += a * vnoise(p); p = p * 2.03 + 7.1; a *= 0.5; }
	return s;
}
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

vec3 body(vec3 dir, vec3 c, float radius, vec3 col, vec3 sun, out float mask) {
	vec3 cd = normalize(c);
	float d = acos(clamp(dot(dir, cd), -1.0, 1.0));
	mask = smoothstep(radius, radius * 0.985, d);
	// fake sphere normal for lit/shadow side
	vec3 t = normalize(cross(cd, vec3(0.0, 1.0, 0.0)));
	vec3 b = cross(t, cd);
	vec2 uv = vec2(dot(dir - cd, t), dot(dir - cd, b)) / radius;
	vec3 nrm = normalize(t * uv.x + b * uv.y + cd * sqrt(max(1.0 - dot(uv, uv), 0.0)) * -1.0);
	float lit = clamp(dot(nrm, sun) * 0.9 + 0.12, 0.0, 1.0);
	float bands = 0.85 + 0.15 * sin(uv.y * 22.0 + sin(uv.x * 5.0) * 1.5);
	return col * lit * bands;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun = normalize(LIGHT0_DIRECTION);
	float up = dir.y;
	vec3 col;
	if (up >= 0.0) {
		col = mix(horizon_color, top_color, pow(up, 0.45));
		// Mie-ish forward scatter around the sun
		float mu = max(dot(dir, sun), 0.0);
		col += LIGHT0_COLOR * (pow(mu, 8.0) * 0.25 + pow(mu, 120.0) * 1.5) * LIGHT0_ENERGY * 0.6;
		// stars: fade near horizon and in bright skies
		vec3 cell = floor(dir * 260.0);
		float s = step(0.9965, hash(cell));
		float tw = hash(cell + 3.1);
		float dark = 1.0 - clamp(dot(top_color, vec3(0.6)) * 2.5, 0.0, 1.0);
		// RND-8 night: stars brighten once the sun is below the horizon (day/night cycle)
		float night = smoothstep(0.05, -0.2, sun.y);
		col *= 1.0 - night * 0.55;
		col += vec3(0.8 + tw * 0.2, 0.85, 1.0) * s * star_strength * smoothstep(0.05, 0.4, up) * (0.3 + dark + night * 1.2);
		if (!AT_CUBEMAP_PASS) {
			if (sky_variant == 1 && aurora_strength > 0.0) {
				// aurora: wavy vertical curtains on a virtual dome, drifting slowly
				vec2 auv = dir.xz / (up + 0.3);
				float wav = auv.x * 1.4 + fbm(auv * 0.6 + vec2(TIME * 0.02, 0.0), 2) * 3.5;
				float curtain = pow(1.0 - abs(sin(wav)), 5.0);
				float rays = 0.6 + 0.4 * vnoise(vec2(wav * 9.0, TIME * 0.3));
				float band = smoothstep(0.08, 0.3, up) * smoothstep(0.85, 0.45, up);
				float mask_a = curtain * rays * band * (0.25 + dark + night) * aurora_strength;
				col += mix(aurora_low, aurora_high, smoothstep(0.2, 0.7, up)) * mask_a * 0.9;
			} else if (sky_variant == 2) {
				// deep starfield: a second, finer star layer, a soft galactic band and nebula tint
				vec3 cell2 = floor(dir * 620.0);
				float s2 = step(0.9975, hash(cell2)) * (0.4 + 0.6 * hash(cell2 + 1.7));
				vec3 gal_n = normalize(vec3(0.3, 0.9, 0.3));
				float gal = exp(-pow(dot(dir, gal_n) * 4.0, 2.0));
				float neb = fbm(dir.xz / (up + 0.2) * 1.2, 3);
				col += vec3(0.85, 0.9, 1.0) * s2 * star_strength * (0.6 + gal);
				col += mix(vec3(0.25, 0.05, 0.35), vec3(0.05, 0.2, 0.4), neb) * gal * neb * 0.5 * star_strength;
			}
		}
		// gas giant with tilted rings (computed in the planet's tangent plane)
		float pm;
		vec3 p = body(dir, planet_dir, 0.15, planet_color, sun, pm);
		vec3 pd = normalize(planet_dir);
		vec3 pt = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
		vec3 pb = cross(pt, pd);
		vec2 puv = vec2(dot(dir - pd, pt), dot(dir - pd, pb)) / 0.15;
		vec2 rr = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * puv;
		float re = length(vec2(rr.x, rr.y / 0.22));
		float ring = smoothstep(1.3, 1.36, re) * smoothstep(2.1, 1.95, re) * (0.7 + 0.3 * sin(re * 40.0));
		ring *= step(0.0, dot(dir, pd)) * (1.0 - pm * step(rr.y, 0.0));
		col = mix(col, p, pm * (1.0 - ring * step(0.0, rr.y)));
		col += vec3(0.95, 0.85, 0.75) * ring * 0.6;
		float m1; vec3 mo1 = body(dir, moon1_dir, 0.045, vec3(0.85, 0.85, 0.9), sun, m1);
		col = mix(col, mo1, m1);
		float m2; vec3 mo2 = body(dir, moon2_dir, 0.028, vec3(1.0, 0.75, 0.45), sun, m2);
		col = mix(col, mo2, m2);
		// v0.8 clouds: planar projection, sun-lit edges, fade to horizon
		vec2 cuv = dir.xz / (up + 0.12) * 1.6 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float cn = fbm(cuv, cloud_octaves);
		float cm = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.3, cn) * smoothstep(0.0, 0.18, up);
		float silver = pow(max(dot(dir, sun), 0.0), 6.0);
		vec3 cc = mix(cloud_color * (0.55 + 0.45 * LIGHT0_ENERGY), LIGHT0_COLOR * 1.6, silver * (1.0 - cm) * 0.8);
		cc = mix(cc, horizon_color, 0.25);
		col = mix(col, cc, cm * 0.9);
		// sun disk
		col += LIGHT0_COLOR * smoothstep(0.9995, 0.9999, dot(dir, sun)) * 20.0;
	} else {
		col = mix(horizon_color * 0.8, ground_color, clamp(-up * 3.0, 0.0, 1.0));
	}
	COLOR = col;
}
