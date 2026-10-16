shader_type sky;
// v0.3 cinematic alien sky: physically-flavoured atmosphere gradient, sun disk + halo, star field
// that shows through the thin upper atmosphere, a ringed gas giant and two moons.
// No TIME use, so the radiance map only re-bakes when biome colors change (cheap on mobile).
uniform vec3 top_color : source_color = vec3(0.05, 0.09, 0.25);
uniform vec3 horizon_color : source_color = vec3(0.42, 0.56, 0.78);
uniform vec3 ground_color : source_color = vec3(0.1, 0.1, 0.12);
uniform float star_strength = 0.6;
uniform vec3 planet_dir = vec3(-0.35, 0.5, -0.8);
uniform vec3 planet_color : source_color = vec3(0.75, 0.42, 0.85);
uniform vec3 moon1_dir = vec3(0.5, 0.45, -0.6);
uniform vec3 moon2_dir = vec3(0.2, 0.62, 0.75);

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
		col += vec3(0.8 + tw * 0.2, 0.85, 1.0) * s * star_strength * smoothstep(0.05, 0.4, up) * (0.3 + dark);
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
		// sun disk
		col += LIGHT0_COLOR * smoothstep(0.9995, 0.9999, dot(dir, sun)) * 20.0;
	} else {
		col = mix(horizon_color * 0.8, ground_color, clamp(-up * 3.0, 0.0, 1.0));
	}
	COLOR = col;
}
