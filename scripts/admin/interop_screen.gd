class_name InteropScreen
extends Control
## Viper OS Admin > Interop (MENU > ⇄ Interop). Import status for OpenSim / Aurora-Sim / WhiteCore
## archives (docs/modules/INTEROP.md). Phoenix Glass kit, portrait, one short scrolling page.
## - Status: counts + the last import. Anyone can look.
## - Import: path field + Preview (anyone) + Import (Premium/Creator, staff or unlocked owner).
## - Clear log: unlocked owner only.
## Phone rules (docs/UI_DESIGN_LANGUAGE.md): text >= 16 px (we use 20), taps >= 80 px, no extra glows.
signal closed

const TEXT_PX := 20
const TAP_PX := 80
var body: VBoxContainer
var path_edit: LineEdit
var import_btn: Button
var clear_btn: Button
var preview_label: Label

static func open(parent: Node) -> InteropScreen:
	var existing := parent.get_node_or_null("InteropScreen")
	if existing: return existing
	var s := InteropScreen.new()
	s.name = "InteropScreen"
	parent.add_child(s)
	return s

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = PhoenixTokens.VOID; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "bottom"]: m.add_theme_constant_override("margin_" + s, PhoenixTokens.space(5))
	m.add_theme_constant_override("margin_top", PhoenixTokens.space(6))
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.space(4)); m.add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new(); title.text = "Interop"; title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(TAP_PX, TAP_PX)
	x.add_theme_font_size_override("font_size", 28)
	x.pressed.connect(func(): closed.emit(); queue_free()); head.add_child(x)
	v.add_child(head)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", PhoenixTokens.space(4)); sc.add_child(body)
	refresh()

func _card(t: String) -> GlassCard:
	var c := ViperKit.card(t)
	var tl := c.get_node_or_null("Pad/VBox/Title")
	if tl: tl.add_theme_font_size_override("font_size", 18)
	return c

func _text(t: String, col := PhoenixTokens.PLATINUM, px := TEXT_PX) -> Label:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px); l.add_theme_color_override("font_color", col)
	return l

func _btn(t: String, f: Callable) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(TAP_PX * 2, TAP_PX)
	b.add_theme_font_size_override("font_size", 22); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(f)
	return b

func toast(t: String, variant := "ok") -> void: Toast.show_toast(self, t, variant)

func refresh() -> void:
	if body == null: return
	for c in body.get_children(): body.remove_child(c); c.queue_free()
	var st := InteropImport.status()
	var s := _card("Import status"); body.add_child(s)
	var row := HFlowContainer.new(); row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", PhoenixTokens.space(5)); s.body().add_child(row)
	row.add_child(ViperKit.ring(minf(1.0, st["oar"] / 10.0), "regions (OAR)", str(st["oar"])))
	row.add_child(ViperKit.ring(minf(1.0, st["iar"] / 10.0), "inventory (IAR)", str(st["iar"])))
	row.add_child(ViperKit.ring(minf(1.0, st["failed"] / 10.0), "failed", str(st["failed"]), 120, true))
	var last: Dictionary = st["last"]
	s.body().add_child(_text("Last: " + (_row_text(last) if not last.is_empty() else "nothing imported yet."), PhoenixTokens.PLATINUM_DIM))
	# import
	var tier := Tiers.tier_of(Tiers.SELF)
	var can_import := Tiers.can(Tiers.SELF, "upload")
	var c := _card("Import an OAR or IAR"); body.add_child(c)
	c.body().add_child(_text("From OpenSim, Aurora-Sim, WhiteCore or OSgrid. Terrain and notecard text come in. Objects, scripts and textures are listed only.", PhoenixTokens.PLATINUM_DIM))
	path_edit = LineEdit.new(); path_edit.placeholder_text = "File path, e.g. /sdcard/Download/region.oar"
	path_edit.custom_minimum_size = Vector2(0, TAP_PX); path_edit.add_theme_font_size_override("font_size", TEXT_PX)
	c.body().add_child(path_edit)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", PhoenixTokens.space(3))
	h.add_child(_btn("Preview", func(): preview(path_edit.text.strip_edges())))
	import_btn = _btn("Import", func(): do_import(path_edit.text.strip_edges()))
	import_btn.disabled = not can_import; h.add_child(import_btn)
	c.body().add_child(h)
	c.body().add_child(_text("You are: %s. %s" % [Tiers.label(tier), "You can import." if can_import else "Importing needs Premium/Creator, staff, or the owner unlock (Security)."],
		PhoenixTokens.PLATINUM if can_import else PhoenixTokens.WARN))
	preview_label = _text("", PhoenixTokens.PLATINUM_DIM); c.body().add_child(preview_label)
	# recent
	var r := _card("Recent imports"); body.add_child(r)
	var rows := InteropImport.log_entries()
	if rows.is_empty(): r.body().add_child(_text("None yet.", PhoenixTokens.PLATINUM_DIM))
	for e in rows.slice(0, 6): r.body().add_child(_text(_row_text(e), PhoenixTokens.PLATINUM if e.get("ok", false) else PhoenixTokens.WARN))
	clear_btn = _btn("Clear log (owner)", func():
		toast("Log cleared" if InteropImport.clear_log(Tiers.SELF) else "Owner unlock needed.", "ok")
		refresh())
	clear_btn.disabled = not Tiers.can(Tiers.SELF, "admin"); r.body().add_child(clear_btn)
	var p := _card("Planned"); body.add_child(p)
	p.body().add_child(_text("Apply terrain to a region · objects to voxel stamps · LSL-subset scripts · Hypergrid-style travel. See the Interop wiki page.", PhoenixTokens.PLATINUM_DIM))

static func _row_text(e: Dictionary) -> String:
	var k := str(e.get("kind", "?")).to_upper()
	if not e.get("ok", false): return "%s %s · failed: %s" % [k, e.get("file", ""), e.get("error", "")]
	if e.has("terrain"): return "%s %s · terrain %s, %d→%d px" % [k, e.get("file", ""), e["terrain"]["region"], int(e["terrain"]["src_size"]), int(e["terrain"]["size"])]
	return "%s %s · %d notecards" % [k, e.get("file", ""), int(e.get("notecards", {}).get("count", 0))]

func preview(path: String) -> Dictionary:
	var r := InteropImport.inspect(path, Tiers.SELF)
	if preview_label:
		if not r["ok"]: preview_label.text = "Can't read: " + str(r["error"])
		elif r["kind"] == "oar":
			preview_label.text = "OAR v%s · %s m · %d terrain · %d objects · %d parcels" % [r["version"], r["region_size"], r["terrains"].size(), r["objects"], r["parcels"].size()]
		else:
			preview_label.text = "IAR · %d items · %d notecards · %d textures" % [r["items"].size(), r["notecards"].size(), r["textures"].size()]
	return r

func do_import(path: String) -> Dictionary:
	var row := InteropImport.import_file(path, Tiers.SELF)
	toast("Imported" if row["ok"] else str(row.get("error", "Failed")), "ok" if row["ok"] else "warn")
	refresh()
	return row
