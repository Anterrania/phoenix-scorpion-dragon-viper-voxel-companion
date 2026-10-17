class_name LandSafetyScreen
extends Control
## Viewer parity admin screen (MENU > ⚖ Land & Safety). Phoenix Glass kit, portrait, swipe tabs:
##   Land (+ Estate cards) · Access · Objects · Safety · Limits
## Land/Access/Objects = the About Land + Region/Estate floaters (ParcelTools).
## Safety = mute, block and derender lists (ModerationLists). Limits = opt-in restrictions (Restrictions).
## Compact by default: PhoenixTokens.TAP_MIN taps, TYPE body/label text; calm, no custom motion, no glow.
## Foxy owns the in-world land-tools sheet; this is the admin view of the same data.
signal closed

const TABS := ["Land", "Access", "Objects", "Safety", "Limits"]   # kit max is 5; Estate cards sit under Land
const BAN_HOURS := [0.0, 1.0, 24.0, 168.0]
const AUTO_RETURN := [0, 5, 10, 30, 60, 240, 1440]
var region := "Spawn"
var parcel := "0_0"
var here := Vector3.ZERO
var pages: SwipePages
var boxes := {}
var last_status := ""
var _ban_hours_i := 0

static func open(parent: Node, p_region := "Spawn", p_parcel := "0_0", p_here := Vector3.ZERO) -> LandSafetyScreen:
	var existing := parent.get_node_or_null("LandSafetyScreen")
	if existing: return existing
	var s: LandSafetyScreen = load("res://scenes/admin/land_safety_screen.tscn").instantiate()
	s.region = p_region; s.parcel = p_parcel; s.here = p_here
	parent.add_child(s)
	return s

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = PhoenixTokens.VOID; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "bottom"]: m.add_theme_constant_override("margin_" + s, PhoenixTokens.SPACE[4])
	m.add_theme_constant_override("margin_top", PhoenixTokens.SPACE[5])
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.SPACE[3]); m.add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new(); title.text = "Land & Safety"; title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN, PhoenixTokens.TAP_MIN)
	x.pressed.connect(func(): closed.emit(); queue_free()); head.add_child(x)
	v.add_child(head)
	pages = SwipePages.new(); pages.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(pages)
	for t in TABS:
		var sc := ScrollContainer.new(); sc.name = t
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var b := VBoxContainer.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_constant_override("separation", PhoenixTokens.SPACE[3])
		sc.add_child(b); pages.add_page(t, sc); boxes[t] = b
	pages.page_changed.connect(func(_i): refresh())
	ParcelTools.sweep_bans(region, parcel)
	refresh()

# ---------- small builders ----------
func _say(err: String, ok_text := "Saved") -> void:
	last_status = err if err != "" else ok_text
	Toast.show_toast(self, last_status, "err" if err != "" else "ok")
	refresh()

func _card(t: String, parent: Node) -> VBoxContainer:
	var c := ViperKit.card(t); parent.add_child(c)
	return c.body()

func _text(t: String, col := PhoenixTokens.PLATINUM) -> Label:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", PhoenixTokens.TYPE["body"]); l.add_theme_color_override("font_color", col)
	return l

func _btn(t: String, f: Callable, disabled := false) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN * 2, PhoenixTokens.TAP_MIN)
	b.add_theme_font_size_override("font_size", PhoenixTokens.TYPE["body"]); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = disabled; b.pressed.connect(f)
	return b

func _edit(placeholder: String, text := "") -> LineEdit:
	var e := LineEdit.new(); e.placeholder_text = placeholder; e.text = text
	e.custom_minimum_size = Vector2(0, PhoenixTokens.TAP_MIN); e.add_theme_font_size_override("font_size", PhoenixTokens.TYPE["body"])
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e

func _row(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", PhoenixTokens.SPACE[3])
	for i in items: h.add_child(i)
	return h

func _clear(b: Node) -> void:
	for c in b.get_children(): b.remove_child(c); c.queue_free()

func _cycle(opts: Array, cur: Variant) -> Variant: return opts[(opts.find(cur) + 1) % opts.size()]

func can_edit() -> bool: return ParcelTools.can_manage_parcel("self", region, parcel)

# ---------- tabs ----------
func refresh() -> void:
	if boxes.is_empty(): return
	_land(boxes["Land"]); _access(boxes["Access"]); _objects(boxes["Objects"])
	_estate(boxes["Land"]); _safety(boxes["Safety"]); _limits(boxes["Limits"])

func _land(b: VBoxContainer) -> void:
	_clear(b)
	var ro := not can_edit()
	b.add_child(_text("Region %s · Parcel %s" % [region, parcel], PhoenixTokens.GOLD))
	if ro: b.add_child(_text("View only. The parcel owner, estate managers or you (unlocked) can edit.", PhoenixTokens.PLATINUM_DIM))
	var g := ParcelTools.general(region, parcel)
	var c := _card("About this parcel", b)
	var nm := _edit("Parcel name", str(g["name"])); nm.name = "ParcelName"; c.add_child(nm)
	var ds := _edit("Description", str(g["description"])); c.add_child(ds)
	c.add_child(_btn("Category: " + str(g["category"]).replace("_", " ").capitalize(), func():
		_say(ParcelTools.set_general("self", region, parcel, {"category": _cycle(ParcelTools.CATEGORIES, g["category"])})), ro))
	c.add_child(_btn("Save name and description", func():
		_say(ParcelTools.set_general("self", region, parcel, {"name": nm.text, "description": ds.text})), ro))
	c.add_child(_text("Owner: %s · Group: %s" % [g["owner_id"] if str(g["owner_id"]) != "" else "estate", g["group"] if str(g["group"]) != "" else "none"], PhoenixTokens.PLATINUM_DIM))
	c.add_child(_text("Selling land: planned (needs Aethel Coin and legal review).", PhoenixTokens.PLATINUM_DIM))
	var o := _card("Arrival", b)
	var tp := str(ParcelTools.get_value(region, parcel, "tp_routing"))
	o.add_child(_btn("Teleports: " + tp.replace("_", " "), func():
		_say(ParcelTools.set_options("self", region, parcel, {"tp_routing": _cycle(ParcelTools.TP_ROUTING, tp)})), ro))
	o.add_child(_btn("Set landing point here", func(): _say(ParcelTools.set_options("self", region, parcel, {"landing_point": here})), ro))
	var see := bool(ParcelTools.get_value(region, parcel, "see_avatars"))
	o.add_child(_btn("Avatars seen from outside: " + ("on" if see else "off"), func():
		_say(ParcelTools.set_options("self", region, parcel, {"see_avatars": not see})), ro))
	var md := _card("Media & music", b)
	var mu := _edit("Media URL (https://)", str(ParcelTools.get_value(region, parcel, "media_url"))); md.add_child(mu)
	var mz := _edit("Music URL (https://)", str(ParcelTools.get_value(region, parcel, "music_url"))); md.add_child(mz)
	md.add_child(_btn("Save media", func(): _say(ParcelTools.set_media("self", region, parcel, {"media_url": mu.text, "music_url": mz.text})), ro))

func _access(b: VBoxContainer) -> void:
	_clear(b)
	var ro := not can_edit()
	var acc := str(ParcelTools.get_value(region, parcel, "access"))
	var c := _card("Who can come in", b)
	c.add_child(_btn("Access: " + acc.replace("_", " "), func():
		_say(ParcelTools.set_access("self", region, parcel, {"access": _cycle(Estate.ACCESS, acc)})), ro))
	var adult := bool(ParcelTools.get_value(region, parcel, "adult_only"))
	c.add_child(_btn("Adults only: " + ("on" if adult else "off"), func():
		_say(ParcelTools.set_access("self", region, parcel, {"adult_only": not adult})), ro))
	var al := _card("Allowed", b)
	var who := _edit("Name to allow"); al.add_child(_row([who, _btn("Allow", func(): _say(ParcelTools.allow("self", region, parcel, who.text)), ro)]))
	for p in ParcelTools.allowed(region, parcel):
		al.add_child(_row([_text(str(p)), _btn("Remove", func(): _say(ParcelTools.disallow("self", region, parcel, p)), ro)]))
	var bn := _card("Banned", b)
	var bw := _edit("Name to ban")
	var hrs: float = BAN_HOURS[_ban_hours_i]
	bn.add_child(bw)
	bn.add_child(_row([_btn("For: " + ("always" if hrs == 0.0 else "%d h" % int(hrs)), func():
		_ban_hours_i = (_ban_hours_i + 1) % BAN_HOURS.size(); refresh(), ro),
		_btn("Ban", func(): _say(ParcelTools.ban("self", region, parcel, bw.text, hrs)), ro)]))
	var ex: Dictionary = ParcelTools.get_value(region, parcel, "ban_expiry")
	for p in ParcelTools.banned(region, parcel):
		var left := "always" if not ex.has(p) else "%d h left" % ceili((int(ex[p]) - Time.get_unix_time_from_system()) / 3600.0)
		bn.add_child(_row([_text("%s · %s" % [p, left]), _btn("Unban", func(): _say(ParcelTools.unban("self", region, parcel, p)), ro)]))

func _objects(b: VBoxContainer) -> void:
	_clear(b)
	var ro := not can_edit()
	var n := ParcelTools.object_counts(region, parcel)
	var c := _card("Land impact", b)
	c.add_child(_text("Total %d · Owner %d · Group %d · Others %d" % [n["total"], n["owner"], n["group"], n["other"]]))
	var ar := int(ParcelTools.get_value(region, parcel, "auto_return_min"))
	c.add_child(_btn("Auto-return others' objects: " + ("off" if ar == 0 else "after %d min" % ar), func():
		_say(ParcelTools.set_auto_return("self", region, parcel, _cycle(AUTO_RETURN, ar))), ro))
	c.add_child(_btn("Return everyone else's objects", func():
		var r := ParcelTools.return_objects("self", region, parcel, {"class": "other"})
		_say(r["error"], "Returned %d" % r["returned"]), ro))
	var ow := _card("By owner", b)
	if n["by_owner"].is_empty(): ow.add_child(_text("No objects here.", PhoenixTokens.PLATINUM_DIM))
	for who in n["by_owner"]:
		ow.add_child(_row([_text("%s · %d" % [who, n["by_owner"][who]]), _btn("Return", func():
			var r := ParcelTools.return_objects("self", region, parcel, {"owner": who})
			_say(r["error"], "Returned %d" % r["returned"]), ro)]))

func _estate(b: VBoxContainer) -> void:   # appended under the Land tab
	var is_owner := Tiers.tier_of("self") == "owner"
	var c := _card("Estate managers", b)
	var who := _edit("Name")
	c.add_child(_row([who, _btn("Add", func(): _say(ParcelTools.add_manager("self", region, who.text)), not is_owner)]))
	for p in ParcelTools.managers(region):
		c.add_child(_row([_text(str(p)), _btn("Remove", func(): _say(ParcelTools.remove_manager("self", region, p)), not is_owner)]))
	var em := _card("Message the estate", b)
	var msg := _edit("Message")
	em.add_child(_row([msg, _btn("Send", func(): _say(ParcelTools.estate_message("self", region, msg.text), "Sent"))]))
	var dbg := _card("Region tools", b)
	dbg.add_child(_text("Restart, kick, top scripts and top colliders need the region server. Planned.", PhoenixTokens.PLATINUM_DIM))
	dbg.add_child(_text("Covenant and parcel flags: MENU > 🏛 Region / Estate.", PhoenixTokens.PLATINUM_DIM))

func _safety(b: VBoxContainer) -> void:
	_clear(b)
	var c := _card("Mute or block", b)
	var who := _edit("Name or object id"); c.add_child(who)
	c.add_child(_row([_btn("Mute", func(): var r := ModerationLists.mute("self", who.text); _say(r["error"], "Muted")),
		_btn("Block", func(): var r := ModerationLists.block("self", who.text); _say(r["error"], "Blocked")),
		_btn("Derender", func(): var r := ModerationLists.derender("self", who.text, "object", true); _say(r["error"], "Hidden"))]))
	var ml := _card("Muted", b)
	var mutes := ModerationLists.mutes("self")
	if mutes.is_empty(): ml.add_child(_text("Nobody muted.", PhoenixTokens.PLATINUM_DIM))
	for m in mutes:
		var t: String = m["target"]
		ml.add_child(_row([_text("%s · %s" % [m["label"], m["kind"]]), _btn("Unmute", func(): var r := ModerationLists.unmute("self", t); _say(r["error"], "Unmuted"))]))
	var dl := _card("Hidden (derendered)", b)
	for d in ModerationLists.derendered("self"):
		var t: String = d["target"]
		dl.add_child(_row([_text("%s · %s" % [d["label"], "saved" if d["permanent"] else "until teleport"]),
			_btn("Show", func(): var r := ModerationLists.rerender("self", t); _say(r["error"], "Shown"))]))
	dl.add_child(_btn("Clear temporary", func(): _say("", "Cleared %d" % ModerationLists.clear_temporary("self"))))
	var tp := ModerationLists.rerender_after_tp("self")
	dl.add_child(_btn("Show temporary after teleport: " + ("on" if tp else "off"), func():
		var r := ModerationLists.set_rerender_after_tp("self", not tp); _say(r["error"])))

func _limits(b: VBoxContainer) -> void:
	_clear(b)
	var me := Tiers.actor_id("self")
	var c := _card("Restrictions (opt-in, adults only)", b)
	if Restrictions.suspended():
		c.add_child(_text("Suspended: emergency stop or switched off.", PhoenixTokens.WARN))
	var on := Restrictions.enabled(me)
	c.add_child(_text("Lets people you choose turn off a few of your own abilities for a while. Off by default.", PhoenixTokens.PLATINUM_DIM))
	if on: c.add_child(_btn("Turn off", func(): _say(Restrictions.disable("self", me))))
	else: c.add_child(_btn("I'm 18 or older. Turn on", func(): _say(Restrictions.enable("self", me, true))))
	var sw := _btn("Safeword: clear all now", func(): _say("", "Cleared %d" % Restrictions.safeword("self")))
	sw.name = "Safeword"; c.add_child(sw)
	var cs := _card("Who may restrict you", b)
	var src := _edit("Name")
	cs.add_child(_row([src, _btn("Allow", func(): _say(Restrictions.consent("self", me, src.text)), not on)]))
	for s in Restrictions.consents(me):
		cs.add_child(_row([_text(str(s)), _btn("Revoke", func(): _say(Restrictions.revoke("self", me, s)))]))
	var ac := _card("Active now", b)
	var act := Restrictions.active(me)
	if act.is_empty(): ac.add_child(_text("None.", PhoenixTokens.PLATINUM_DIM))
	for r in act:
		ac.add_child(_text("%s · from %s" % [Restrictions.BEHAVIOURS.get(r["behaviour"], r["behaviour"]), r["source"]]))
	if Tiers.tier_of("self") == "owner":
		var off := Restrictions.global_off()
		ac.add_child(_btn("Owner: " + ("switch on" if off else "switch off for everyone"), func(): _say(Restrictions.set_global_off("self", not off))))

# ---------- test helpers ----------
func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children(): _walk(c, out)

func min_font_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if (n is Label or n is Button or n is LineEdit) and n.is_visible_in_tree() and (n as Control).get_theme_font_size("font_size") < px: return false
	return true

func min_tap_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if n is BaseButton and n.custom_minimum_size.y < px and not n.get_parent() is TabBar: return false
	return true
