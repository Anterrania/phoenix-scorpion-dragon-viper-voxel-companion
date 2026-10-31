shader_type spatial;
// HEAVEN-1: emissive trim / signs / lamps for Heaven buildings. Vertex color * energy as HDR
// albedo, unshaded: feeds bloom without any real light (cheap on the Mobile renderer).
render_mode unshaded, cull_back, shadows_disabled;
uniform float energy = 2.4;
uniform float pulse = 0.12;
void fragment() {
	float p = 1.0 + pulse * sin(TIME * 1.7 + VERTEX.x * 0.05);
	ALBEDO = COLOR.rgb * energy * p;
}
