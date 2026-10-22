// Shared body of the terrain shaders (see terrain_triplanar.gdshader for the history header).

uniform sampler2D biome_map : filter_linear, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float map_half = 4096.0;
uniform float glitter = 1.0;
// v0.8 procedural detail normal map (NoiseTexture2D as_normal_map), triplanar-sampled at two scales
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 1.0;
uniform float macro_variation = 1.0;
// v0.9 estate land texture override (0 = biome default) + sub-biome variety + snow sparkle
uniform int land_texture = 0;
uniform float snow_sparkle = 1.0;
uniform float biome_variety = 1.0;

// RND-7 (2026-10-17) render pipeline additions, all tier-driven by scripts/render/render_pipeline.gd:
//  * Transvoxel seam stitching + hidden inactive transition cells (engine-provided uniform/attribute)
//  * dithered LOD cross-fade (u_lod_fade, active when VoxelLodTerrain.lod_fade_duration > 0)
//  * cheap curvature AO from screen-space derivatives (darkens creases, no extra textures)
//  * distance-gated detail: fine detail + near normal samples only within detail_far metres
//  * fake caustics on submerged Cosmic ground (below water_height)
uniform int u_transition_mask;      // set by godot_voxel per mesh block
#ifdef LOD_FADE
uniform vec2 u_lod_fade;            // set by godot_voxel: x = progress, y = 1 fade in / 0 fade out
#endif
uniform float detail_far = 60.0;
uniform float curvature_ao = 0.6;
uniform float caustics = 1.0;
uniform float water_height = -3.0;
uniform float tri_sharpness = 4.0;

varying vec3 wpos;
varying vec3 wnrm;

// Transvoxel stitching. CUSTOM0.xyz = secondary (stitched) position, CUSTOM0.w = packed int:
// bits 0-5 sides the cell touches, 8-13 sides the vertex lies on, 16-23 transition side (0 = regular).
// u_transition_mask bits 0-5: which sides have a lower-resolution neighbour.
vec3 transvoxel_vertex(vec3 v, vec4 c0) {
	int packed = floatBitsToInt(c0.w);
	int sides = u_transition_mask & 63;
	int cell_sides = packed & 63;
	int vert_sides = (packed >> 8) & 63;
	int tside = (packed >> 16) & 255;
	// move to the stitched position when the cell borders a coarser neighbour, unless the vertex
	// also sits on a side whose neighbour is NOT coarser (that edge must stay put)
	bool move = (sides & cell_sides) != 0 && (vert_sides & ~sides) == 0;
	vec3 p = move ? c0.xyz : v;
	// transition-cell triangles are only wanted on sides that border a coarser block;
	// collapse the others to the origin (degenerate = not rasterised, no extra draw call)
	bool keep = tside == 0 || (tside & sides) != 0;
	return keep ? p : vec3(0.0);
}

void vertex() {
	VERTEX = transvoxel_vertex(VERTEX, CUSTOM0);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(vec3 p, vec3 n, float sc) {
	vec3 w = pow(abs(n), vec3(tri_sharpness));
	w /= (w.x + w.y + w.z);
	return texture(detail, p.yz * sc).r * w.x + texture(detail, p.xz * sc).r * w.y + texture(detail, p.xy * sc).r * w.z;
}

float hash3(vec3 p) { return fract(sin(dot(floor(p), vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

void fragment() {
	vec3 n = normalize(wnrm);
	float bv = texture(biome_map, (wpos.xz + map_half) / (2.0 * map_half)).r;
	float venus = smoothstep(-0.15, -0.55, bv);
	float cosmic = smoothstep(0.15, 0.55, bv);
	float alaska = clamp(1.0 - venus - cosmic, 0.0, 1.0);
	float cam_d = length(wpos - CAMERA_POSITION_WORLD);
	bool near_detail = cam_d < detail_far;
	float d1 = tri(wpos, n, 0.035);
	float d2 = tri(wpos, n, 0.21);
	// RND-7: the finest octave is invisible past detail_far; skip its 3 samples there
	float d3 = near_detail ? tri(wpos, n, 0.9) : 0.5;
	float slope = 1.0 - n.y;           // 0 flat .. 1 cliff
	float strata = sin(wpos.y * 1.7 + d1 * 6.0) * 0.5 + 0.5;

	// --- Alaska: granite cliffs, wind-packed snow on flats, blue ice in lowlands
	vec3 granite = mix(vec3(0.24, 0.25, 0.27), vec3(0.42, 0.42, 0.44), d2) * (0.8 + 0.25 * strata);
	vec3 snow = mix(vec3(0.82, 0.86, 0.92), vec3(0.97, 0.98, 1.0), d3);
	vec3 ice = mix(vec3(0.45, 0.66, 0.82), vec3(0.75, 0.88, 0.95), d2);
	float snow_w = smoothstep(0.42, 0.25, slope + (d1 - 0.5) * 0.3);
	float ice_w = smoothstep(2.0, -1.0, wpos.y) * snow_w;
	// v0.9 sub-biomes: tundra moss / heather meadows on low flats, frozen lakes stay icy
	float sub = texture(detail, wpos.xz * 0.0015).r;
	vec3 moss = mix(vec3(0.16, 0.22, 0.13), vec3(0.34, 0.27, 0.36), d2);
	float moss_w = smoothstep(0.55, 0.7, sub) * smoothstep(12.0, 4.0, wpos.y) * smoothstep(0.35, 0.1, slope) * biome_variety;
	snow = mix(snow, moss, moss_w * 0.85);
	vec3 a_col = mix(mix(granite, snow, snow_w), ice, ice_w);
	float a_rough = mix(mix(0.85, 0.55, snow_w), 0.12, ice_w);
	float a_metal = 0.0;

	// --- Venus: glassy obsidian + rough basalt, glowing magma cracks
	vec3 basalt = mix(vec3(0.07, 0.05, 0.05), vec3(0.2, 0.12, 0.09), d2) * (0.8 + 0.3 * strata);
	vec3 obsid = vec3(0.02, 0.015, 0.025) + vec3(0.06, 0.02, 0.05) * d3;
	float ob_w = smoothstep(0.45, 0.6, d1);
	vec3 v_col = mix(basalt, obsid, ob_w);
	// v0.9 Venus sub-biome: pale volcanic ash dunes + sulphur crust
	vec3 ash = mix(vec3(0.32, 0.28, 0.26), vec3(0.55, 0.47, 0.3), d3);
	float ash_w = smoothstep(0.35, 0.2, sub) * smoothstep(0.3, 0.05, slope) * biome_variety;
	v_col = mix(v_col, ash, ash_w);
	float v_rough = mix(0.9, 0.08, ob_w);
	float crack = smoothstep(0.014, 0.0, abs(d2 - 0.5)) * smoothstep(0.55, 0.65, d1) * smoothstep(0.5, 0.1, slope) * smoothstep(14.0, 0.0, wpos.y);
	vec3 v_emit = vec3(1.0, 0.32, 0.05) * crack * 4.0;

	// --- Cosmic: dark crystalline ground, iridescent facets, star glints
	vec3 facet = 0.5 + 0.5 * cos(6.2831 * (d2 * 1.5 + vec3(0.0, 0.33, 0.67)));
	vec3 c_col = mix(vec3(0.03, 0.01, 0.08), vec3(0.18, 0.07, 0.34), d1) + facet * 0.06;
	float c_rough = 0.5;
	float c_metal = 0.3;

	ALBEDO = a_col * alaska + v_col * venus + c_col * cosmic;
	// v0.9 estate land textures (Region/Estate > Ground Textures)
	if (land_texture == 1) ALBEDO = mix(granite, snow, snow_w);
	else if (land_texture == 2) ALBEDO = v_col;
	else if (land_texture == 3) ALBEDO = c_col + facet * 0.1;
	else if (land_texture == 4) ALBEDO = mix(vec3(0.12, 0.26, 0.1), vec3(0.3, 0.42, 0.16), d2);
	else if (land_texture == 5) ALBEDO = mix(vec3(0.62, 0.5, 0.34), vec3(0.82, 0.7, 0.5), d3) * (0.9 + 0.1 * strata);
	else if (land_texture == 6) ALBEDO = ash;
	ROUGHNESS = a_rough * alaska + v_rough * venus + c_rough * cosmic;
	METALLIC = a_metal * alaska + c_metal * cosmic;
	// Anterranian glitter: sparse view-dependent glints (platinum/gold/magenta per biome)
	vec3 gc = wpos * 14.0;
	float g = step(0.993, hash3(gc)) * smoothstep(0.22, 0.05, length(fract(gc) - 0.5)) * smoothstep(45.0, 8.0, length(wpos - CAMERA_POSITION_WORLD)) * pow(max(dot(normalize(VIEW), NORMAL), 0.0), 2.0);
	vec3 gcol = vec3(0.9, 0.95, 1.0) * alaska + vec3(1.0, 0.75, 0.25) * venus + mix(vec3(1.0, 0.2, 0.8), vec3(0.3, 0.9, 1.0), d3) * cosmic;
	// v0.9 sparkly snow: dense tiny view-aligned crystal glints on snow only
	vec3 sp = wpos * 40.0;
	float spark = step(0.985, hash3(sp)) * pow(max(dot(reflect(-normalize(VIEW), NORMAL), vec3(0.3, 0.8, 0.5)), 0.0), 24.0) * smoothstep(25.0, 3.0, length(wpos - CAMERA_POSITION_WORLD));
	EMISSION = v_emit * venus + gcol * g * glitter * 2.5 + vec3(0.9, 0.95, 1.0) * spark * snow_w * (1.0 - moss_w) * alaska * snow_sparkle * 3.0;
	// cheap micro-normal from detail noise
	vec3 w3 = pow(abs(n), vec3(4.0)); w3 /= (w3.x + w3.y + w3.z);
	vec3 nm1 = texture(detail_normal, wpos.yz * 0.25).rgb * w3.x + texture(detail_normal, wpos.xz * 0.25).rgb * w3.y + texture(detail_normal, wpos.xy * 0.25).rgb * w3.z;
	// RND-7: near-field normal sample only within detail_far (was: always sampled, weighted to 0 far away)
	vec3 nm2 = near_detail ? texture(detail_normal, wpos.xz * 1.1).rgb : nm1;
	float near = smoothstep(min(60.0, detail_far), 10.0, cam_d);
	NORMAL_MAP = normalize(mix(nm1, nm2, 0.35 * near) * 2.0 - 1.0) * 0.5 + 0.5;
	// snow/ice smoother, rock & basalt rougher normals
	NORMAL_MAP_DEPTH = normal_strength * mix(1.4, 0.5, snow_w * alaska) * (0.6 + 0.4 * near);
	// macro albedo variation breaks up tiling at distance
	ALBEDO *= mix(1.0, 0.85 + 0.3 * texture(detail, wpos.xz * 0.004).r, macro_variation);
	// ambient occlusion from crevices
	AO = mix(1.0, smoothstep(0.2, 0.7, d2), 0.5);
	// RND-7 curvature AO: where normals converge across the pixel footprint the surface is
	// concave (valleys, cliff bases, terraform pits) -> darken. Signed so ridges stay lit.
	if (curvature_ao > 0.0) {
		vec3 dpx = dFdx(wpos); vec3 dpy = dFdy(wpos);
		vec3 dnx = dFdx(n); vec3 dny = dFdy(n);
		float kx = dot(dnx, dpx) / max(dot(dpx, dpx), 1e-5);
		float ky = dot(dny, dpy) / max(dot(dpy, dpy), 1e-5);
		float concave = clamp(-(kx + ky) * 2.5, 0.0, 1.0);
		AO *= 1.0 - concave * 0.45 * curvature_ao;
	}
	AO_LIGHT_AFFECT = 0.4;
	// RND-7 fake caustics: two scrolling samples of the detail noise, min-combined into bright
	// thin lines, only on submerged Cosmic (starlight water) ground and fading with depth.
	if (caustics > 0.0 && wpos.y < water_height && cosmic > 0.01) {
		float depth = water_height - wpos.y;
		float c1 = texture(detail, wpos.xz * 0.11 + vec2(TIME * 0.03, TIME * 0.017)).r;
		float c2 = texture(detail, wpos.xz * 0.13 - vec2(TIME * 0.021, TIME * 0.027)).r;
		float lines = pow(1.0 - abs(c1 - c2) * 2.0, 6.0);
		EMISSION += vec3(0.45, 0.6, 1.0) * lines * cosmic * caustics * smoothstep(8.0, 0.5, depth) * 0.8;
	}
	// RND-7 LOD cross-fade: complementary screen-space dither, so the parent and child meshes never
	// draw the same pixel. Must stay last (discard after all writes).
	// Compiled only into terrain_triplanar_fade.gdshader: `discard` turns off early-Z / hidden
	// surface removal on tile GPUs for the whole material, so tiers without fading never pay for it.
#ifdef LOD_FADE
	float fade_h = hash3(vec3(FRAGCOORD.xy, 0.0));
	if (u_lod_fade.y > 0.5) { if (u_lod_fade.x < fade_h) discard; }
	else if (u_lod_fade.x > 0.0) { if (u_lod_fade.x > fade_h) discard; }
#endif
}
