class_name DisplaySettings
extends RefCounted
## Display / accessibility settings (Settings > Display). Persisted in user://settings.cfg [display]:
##   text_scale  1.0 (compact, smallest usable: micro 13 px, label 15 px) .. 2.0
##   icon_scale  1.0 (compact taps 56 px) .. 2.0          Large = 80 px taps, micro type >= 18 px
##   max_view    true = tighter margins/gaps so the most content fits
##   orientation "auto" (sensor: rotates with the phone) | "portrait" (locked upright)
## apply() writes PhoenixTokens.text_scale / icon_scale / space_scale and scales the shared Phoenix
## Glass theme, so every screen built on the kit follows. Default is COMPACT (Phoenix, 2026-10-17).

const SECTION := "display"
const DEFAULTS := {"text_scale": 1.0, "icon_scale": 1.0, "max_view": false, "orientation": "auto"}
const ORIENTATIONS := ["auto", "portrait"]
const ORIENTATION_LABELS := {"auto": "Auto-rotate", "portrait": "Portrait"}
const THEME_PATH := "res://themes/phoenix_glass.tres"

static var store: Object = null          # tests inject a fake {get_value, set_value}; default /root/Settings
static var last_orientation := -1        # DisplayServer.ScreenOrientation last requested (tests read this)
static var apply_count := 0

static func _store() -> Object:
	if store != null: return store
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("Settings") if ml is SceneTree else null

static func get_opt(key: String) -> Variant:
	var s := _store()
	var d: Variant = DEFAULTS.get(key)
	return s.get_value(SECTION, key, d) if s else d

static func _set_opt(key: String, v: Variant) -> void:
	var s := _store()
	if s: s.set_value(SECTION, key, v)

# ---------- values (always clamped) ----------
static func text_scale() -> float: return PhoenixTokens.clamp_text(float(get_opt("text_scale")))
static func icon_scale() -> float: return PhoenixTokens.clamp_icon(float(get_opt("icon_scale")))
static func max_view() -> bool: return bool(get_opt("max_view"))
static func orientation() -> String:
	var o := str(get_opt("orientation"))
	return o if o in ORIENTATIONS else "auto"
static func is_large() -> bool:
	return text_scale() >= PhoenixTokens.LARGE_TEXT - 0.001 and icon_scale() >= PhoenixTokens.LARGE_ICON - 0.001

static func set_text_scale(v: float) -> float:
	_set_opt("text_scale", PhoenixTokens.clamp_text(v)); apply(); return text_scale()
static func set_icon_scale(v: float) -> float:
	_set_opt("icon_scale", PhoenixTokens.clamp_icon(v)); apply(); return icon_scale()
static func set_max_view(on: bool) -> void:
	_set_opt("max_view", on); apply()
static func set_orientation(o: String) -> String:
	_set_opt("orientation", o if o in ORIENTATIONS else "auto"); apply(); return orientation()

## One-tap Large (first-run screen and Settings > Display). Off = back to compact.
static func set_large(on: bool) -> void:
	_set_opt("text_scale", PhoenixTokens.LARGE_TEXT if on else PhoenixTokens.TEXT_MIN)
	_set_opt("icon_scale", PhoenixTokens.LARGE_ICON if on else PhoenixTokens.ICON_MIN)
	apply()

static func reset() -> void:
	for k in DEFAULTS: _set_opt(k, DEFAULTS[k])
	apply()

# ---------- apply ----------
static func screen_orientation_for(o: String) -> int:
	return DisplayServer.SCREEN_PORTRAIT if o == "portrait" else DisplayServer.SCREEN_SENSOR

static func apply() -> void:
	apply_count += 1
	PhoenixTokens.text_scale = text_scale()
	PhoenixTokens.icon_scale = icon_scale()
	PhoenixTokens.space_scale = PhoenixTokens.MAX_VIEW_SPACE if max_view() else 1.0
	scale_theme(load(THEME_PATH) as Theme, PhoenixTokens.text_scale)
	last_orientation = screen_orientation_for(orientation())
	if DisplayServer.get_name() != "headless": DisplayServer.screen_set_orientation(last_orientation)
	var s := _store()
	if s and s.has_signal("display_changed"): s.emit_signal("display_changed")

## Scale every font size in a theme from its original (base) values, kept in theme meta.
static func scale_theme(th: Theme, k: float) -> void:
	if th == null: return
	if not th.has_meta("base_font_sizes"):
		var base := {"__default": th.default_font_size}
		for t in th.get_font_size_type_list():
			for n in th.get_font_size_list(t): base["%s/%s" % [t, n]] = th.get_font_size(n, t)
		th.set_meta("base_font_sizes", base)
	var b: Dictionary = th.get_meta("base_font_sizes")
	th.default_font_size = int(round(int(b["__default"]) * k))
	for key in b:
		if key == "__default": continue
		var parts := str(key).split("/")
		th.set_font_size(parts[1], parts[0], int(round(int(b[key]) * k)))

# ---------- layout helpers (resize / rotation) ----------
static func is_portrait_size(s: Vector2) -> bool: return s.y >= s.x

## Side margin that keeps lines readable: phones in portrait use the token gap; wide screens
## (landscape, tablets) center a column of at most `max_w` px.
static func side_margin(s: Vector2, max_w := 960.0) -> int:
	var m := PhoenixTokens.space(5)
	if not is_portrait_size(s) and s.x > max_w + 2 * m: m = int((s.x - max_w) / 2.0)
	return m

## Grid columns for tiles of `tile_w` px at the current width (at least 1).
static func columns_for(width: float, tile_w := 300.0) -> int:
	return maxi(1, int(width / maxf(tile_w * PhoenixTokens.icon_scale, 1.0)))

## Keep a MarginContainer's side margins right on every resize / rotation / display change.
static func attach_responsive(m: MarginContainer, max_w := 960.0) -> void:
	var fix := func():
		if not is_instance_valid(m) or not m.is_inside_tree(): return
		var mm := side_margin(m.get_viewport().get_visible_rect().size, max_w)
		m.add_theme_constant_override("margin_left", mm); m.add_theme_constant_override("margin_right", mm)
	var hook := func():
		var vp := m.get_viewport()
		if vp and not vp.size_changed.is_connected(fix): vp.size_changed.connect(fix)
		var st := _store()
		if st and st.has_signal("display_changed") and not st.is_connected("display_changed", fix): st.connect("display_changed", fix)
		fix.call()
	if m.is_inside_tree(): hook.call()
	else: m.tree_entered.connect(hook, CONNECT_ONE_SHOT)

## Rescale a screen built with hard-coded sizes (e.g. the main HUD panels) to the current scale.
## The first visit remembers each control's own font size / button height as its base; later calls
## rescale from that base, so calling it again (after a change, or after new rows) never compounds.
## text_k / tap_k map that screen's base sizes onto compact (e.g. 24 px text -> 18 px = 0.75).
static func rescale_tree(root: Node, text_k := 1.0, tap_k := 1.0) -> int:
	var n := 0
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "Control", true, false))
	for c in nodes:
		if not c is Control: continue
		var ctl := c as Control
		if ctl.has_theme_font_size_override("font_size"):
			if not ctl.has_meta("ds_fs"): ctl.set_meta("ds_fs", ctl.get_theme_font_size("font_size"))
			ctl.add_theme_font_size_override("font_size", maxi(PhoenixTokens.TYPE.micro, int(round(float(ctl.get_meta("ds_fs")) * text_k * PhoenixTokens.text_scale))))
			n += 1
		if ctl is BaseButton and ctl.custom_minimum_size.y > 0.0:
			if not ctl.has_meta("ds_h"): ctl.set_meta("ds_h", ctl.custom_minimum_size.y)
			ctl.custom_minimum_size.y = maxf(PhoenixTokens.tap(), round(float(ctl.get_meta("ds_h")) * tap_k * PhoenixTokens.icon_scale))
	return n
