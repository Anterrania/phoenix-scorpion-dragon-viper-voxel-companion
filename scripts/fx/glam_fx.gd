class_name GlamFx
extends RefCounted
## v0.13.1 GLAM-1: the glamorous pass — glitter, sparkle, shine, bloom and drifting magic motes.
## Original look (Viper OS palette: gold, magenta, platinum on void black); no third-party art or IP.
## Every texture is drawn here in code. Levels (Settings look/glam): "off" | "subtle" (default) | "full".
## Battery: PowerSaver.saver or a background app drops "full" to "subtle"; "off" is always respected.
##  - bloom(env):          soft additive glow on bright things (Environment glow).
##  - sparkle_layer():     twinkling 4-point stars over a screen (CPUParticles2D, behind content).
##  - shine(control):      a slow diagonal sheen across a button/panel (canvas_item shader).
##  - magic_motes():       golden/magenta motes that drift and swirl around a 3D node (CPUParticles3D).

const LEVELS := ["off", "subtle", "full"]
const GOLD := Color("#f5c451")
const MAGENTA := Color("#ff2db8")
const PLATINUM := Color("#e6e4ec")
const AMOUNTS := {"off": 0, "subtle": 18, "full": 48}
const MOTES := {"off": 0, "subtle": 24, "full": 64}

static var _star: ImageTexture = null
static var _dot: ImageTexture = null

static func level() -> String:
	var l := str(Settings.get_value("look", "glam", "subtle"))
	if not l in LEVELS: l = "subtle"
	if l == "full":
		var ps: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("PowerSaver") if Engine.get_main_loop() is SceneTree else null
		if ps and bool(ps.get("saver")): l = "subtle"
	return l

static func set_level(l: String) -> bool:
	if not l in LEVELS: return false
	Settings.set_value("look", "glam", l)
	return true

## 4-point star sprite with a soft core (drawn per pixel, 32x32, white -> tinted by particles).
static func star_texture() -> ImageTexture:
	if _star: return _star
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var dx := absf(x - c) / c
			var dy := absf(y - c) / c
			var cross := maxf(1.0 - (dx * 7.0 + dy) , 1.0 - (dy * 7.0 + dx))
			var core := 1.0 - sqrt(dx * dx + dy * dy) * 2.2
			var a := clampf(maxf(cross, core), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_star = ImageTexture.create_from_image(img)
	return _star

static func dot_texture() -> ImageTexture:
	if _dot: return _dot
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	_dot = ImageTexture.create_from_image(img)
	return _dot

static func palette_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, GOLD); g.set_color(1, PLATINUM)
	g.add_point(0.5, MAGENTA)
	return g

## Bloom: soft glow on emissive / bright pixels. Returns true when applied.
static func bloom(env: Environment, lvl := "") -> bool:
	if env == null: return false
	var l := lvl if lvl != "" else level()
	var keys := ["glow_enabled", "glow_intensity", "glow_bloom", "glow_hdr_threshold", "glow_blend_mode"]
	if not env.has_meta("glam_base"):   # remember the world's own glow so "off" puts it back
		var base := {}
		for k in keys: base[k] = env.get(k)
		env.set_meta("glam_base", base)
	if l == "off":
		var b: Dictionary = env.get_meta("glam_base")
		for k in keys: env.set(k, b[k])
		return false
	env.glow_enabled = true
	env.glow_intensity = 0.9 if l == "subtle" else 1.25
	env.glow_bloom = 0.08 if l == "subtle" else 0.18
	env.glow_hdr_threshold = 1.1 if l == "subtle" else 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT if l == "subtle" else Environment.GLOW_BLEND_MODE_ADDITIVE
	return true

## Twinkling stars across a full-rect overlay. Ignores input. Empty Control when glam is off.
static func sparkle_layer(kind := "ui", lvl := "") -> Control:
	var l := lvl if lvl != "" else level()
	var holder := Control.new()
	holder.name = "GlamSparkles"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	if int(AMOUNTS[l]) == 0: return holder
	var p := CPUParticles2D.new()
	p.name = "Sparkles"
	p.texture = star_texture()
	p.amount = int(AMOUNTS[l]) if kind == "ui" else int(AMOUNTS[l]) * 2
	p.lifetime = 2.6
	p.preprocess = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(540, 1000)
	p.position = Vector2(540, 1000)
	p.direction = Vector2(0, -1); p.spread = 30.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 2.0; p.initial_velocity_max = 10.0
	p.angular_velocity_min = -40.0; p.angular_velocity_max = 40.0
	p.scale_amount_min = 0.25; p.scale_amount_max = 0.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0)); curve.add_point(Vector2(0.3, 1)); curve.add_point(Vector2(0.6, 0.4)); curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve   # twinkle: grow, flicker down, vanish
	p.color_initial_ramp = palette_ramp()
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	holder.add_child(p)
	holder.resized.connect(func():
		p.position = holder.size / 2.0
		p.emission_rect_extents = holder.size / 2.0)
	return holder

const SHINE_SHADER := """shader_type canvas_item;
uniform float speed = 0.35;
uniform float width = 0.12;
uniform float strength = 0.35;
uniform vec4 tint : source_color = vec4(1.0, 0.93, 0.75, 1.0);
void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float x = fract(TIME * speed) * 2.4 - 0.7;
	float d = abs((UV.x + UV.y * 0.5) - x);
	float band = smoothstep(width, 0.0, d) * strength;
	COLOR = vec4(base.rgb + tint.rgb * band * base.a, base.a);
}
"""
static var _shine_shader: Shader = null

## Slow sheen across a Control (buttons, cards). No-op when glam is off.
static func shine(c: CanvasItem, lvl := "") -> bool:
	var l := lvl if lvl != "" else level()
	if c == null: return false
	if l == "off":
		if c.material is ShaderMaterial and (c.material as ShaderMaterial).shader == _shine_shader: c.material = null
		return false
	if _shine_shader == null:
		_shine_shader = Shader.new(); _shine_shader.code = SHINE_SHADER
	var m := ShaderMaterial.new(); m.shader = _shine_shader
	m.set_shader_parameter("strength", 0.22 if l == "subtle" else 0.4)
	c.material = m
	return true

## Magic motes swirling around a 3D node (player, companion, altar). Returns null when off.
static func magic_motes(lvl := "") -> CPUParticles3D:
	var l := lvl if lvl != "" else level()
	if int(MOTES[l]) == 0: return null
	var p := CPUParticles3D.new()
	p.name = "MagicMotes"
	p.amount = int(MOTES[l])
	p.lifetime = 3.5
	p.preprocess = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 1.4
	p.gravity = Vector3(0, 0.25, 0)
	p.orbit_velocity_min = 0.08; p.orbit_velocity_max = 0.2   # gentle swirl around the node
	p.initial_velocity_min = 0.05; p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.03; p.scale_amount_max = 0.08
	p.color_initial_ramp = palette_ramp()
	var q := QuadMesh.new(); q.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = dot_texture()
	mat.emission_enabled = true; mat.emission = GOLD; mat.emission_energy_multiplier = 2.0   # catches bloom
	q.material = mat
	p.mesh = q
	return p

## Apply the pass to the running app: bloom on the world, sparkles behind the main menu, sheen on
## primary buttons, motes around the player. Safe to call again after a level change.
static func apply(ui: Node) -> Dictionary:
	var l := level()
	var out := {"level": l, "bloom": false, "motes": false}
	var world: Node = ui.get("world") if ui else null
	var env_node: WorldEnvironment = world.get("env") if world and "env" in world else null
	if env_node: out["bloom"] = bloom(env_node.environment, l)
	var player: Node = ui.get("player") if ui else null
	if player:
		var old := player.get_node_or_null("MagicMotes")
		if old: old.queue_free()
		var m := magic_motes(l)
		if m:
			player.add_child(m); m.position = Vector3(0, 1.0, 0)
			out["motes"] = true
	return out
