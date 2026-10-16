class_name MapData
extends RefCounted
## v0.7 shared terrain map image for minimap + world map (baked once per world).
const HALF := 2048.0   # metres each side of origin
const RES := 256
const REGION := 256.0  # SL-style region size (m)
static var _tex: ImageTexture
static var _gen_id := 0
const BIOME_COLORS := [Color("#a8c4e0"), Color("#d4602a"), Color("#5a2a9a")]
const REALMS := ["Alaskan Aurora Tundra", "Venus Fire Wastes", "Cosmic Glitter Expanse"]

static func texture(g) -> ImageTexture:
	if g == null: return null
	if _tex and _gen_id == g.get_instance_id(): return _tex
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	for y in RES:
		for x in RES:
			var w := uv_to_world(Vector2(x + 0.5, y + 0.5) / RES)
			var h: float = g.height_f(w.x, w.y)
			var c: Color = BIOME_COLORS[g.biome_at(w.x, w.y)]
			if h < g.LAVA_LEVEL: c = c.darkened(0.55)
			img.set_pixel(x, y, c.lightened(clampf(h / 120.0, 0.0, 0.35)))
	_tex = ImageTexture.create_from_image(img)
	_gen_id = g.get_instance_id()
	return _tex

static func uv_to_world(uv: Vector2) -> Vector2:
	return (uv * 2.0 - Vector2.ONE) * HALF

static func world_to_uv(xz: Vector2) -> Vector2:
	return (xz / HALF + Vector2.ONE) * 0.5

static func region_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / REGION), floori(p.z / REGION))

static func region_name(p: Vector3) -> String:
	var r := region_of(p)
	return "Region %s%d" % [char(77 + clampi(r.x, -12, 12)), r.y + 50]  # e.g. "Region M50" at spawn
