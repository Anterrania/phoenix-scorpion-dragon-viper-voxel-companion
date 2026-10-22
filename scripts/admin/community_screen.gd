class_name CommunityScreen
extends Control
## Viper OS Admin > Community (MENU > 👥 Community). Phoenix Glass kit, portrait, five swipe tabs:
## Overview · Reports · Approvals · Groups · Roles.
## - Reports: the moderation queue (Social.moderation_queue / Social.moderate), staff + unlocked owner.
##   Reports are grouped per target; auto-held items (Social.REPORT_HOLD reports) come first.
##   Decisions: Hide · Mature (age-gate it) · Keep (dismiss; releases a held item).
## - Approvals: companion posts waiting in the owner approval queue (same queue as MENU > Proposals).
## - Roles: tier editor (Tiers.set_tier). Anyone can look; only the unlocked owner can save.
## Phone rules (docs/UI_DESIGN_LANGUAGE.md): text >= 16 px (we use 20+), taps >= 80 px, short cards,
## no custom motion (kit transitions only), no extra glows.
signal closed

const TABS := ["Overview", "Reports", "Approvals", "Groups", "Roles"]
const TEXT_PX := 20
const TAP_PX := 80
var pages: SwipePages
var boxes := {}
var save_roles_btn: Button
var pending_tiers := {}   # member id -> tier chosen in the editor, saved by save_roles()
var _new_member: LineEdit

static func open(parent: Node) -> CommunityScreen:
	var existing := parent.get_node_or_null("CommunityScreen")
	if existing: return existing
	var s: CommunityScreen = load("res://scenes/admin/community_screen.tscn").instantiate()
	parent.add_child(s)
	return s

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = PhoenixTokens.VOID; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "bottom"]: m.add_theme_constant_override("margin_" + s, PhoenixTokens.SPACE[5])
	m.add_theme_constant_override("margin_top", PhoenixTokens.SPACE[6])
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.SPACE[4]); m.add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new(); title.text = "Community"; title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(TAP_PX, TAP_PX)
	x.add_theme_font_size_override("font_size", 28)
	x.pressed.connect(func(): closed.emit(); queue_free()); head.add_child(x)
	v.add_child(head)
	pages = SwipePages.new(); pages.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(pages)
	for t in TABS:
		var sc := ScrollContainer.new(); sc.name = t
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var b := VBoxContainer.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_constant_override("separation", PhoenixTokens.SPACE[4])
		sc.add_child(b); pages.add_page(t, sc); boxes[t] = b
	pages.page_changed.connect(func(_i): refresh())
	refresh()

func toast(t: String, variant := "ok") -> void: Toast.show_toast(self, t, variant)

## Kit cards title at 15 px (PhoenixTokens.TYPE.label); phone rule here is >= 16, so bump locally.
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

func _row(buttons: Array) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", PhoenixTokens.SPACE[3])
	for b in buttons: h.add_child(b)
	return h

func _clear(b: Node) -> void:
	for c in b.get_children(): b.remove_child(c); c.queue_free()

func refresh() -> void:
	if pages == null: return
	Social.sync_approvals()
	_overview(); _reports(); _approvals(); _groups(); _roles()

# ---------- Overview ----------
func _overview() -> void:
	var b: VBoxContainer = boxes["Overview"]; _clear(b)
	var s := Social.stats()
	var c := _card("Community"); b.add_child(c)
	var row := HFlowContainer.new(); row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", PhoenixTokens.SPACE[5]); c.body().add_child(row)
	row.add_child(ViperKit.ring(minf(1.0, s["members"] / 50.0), "members", str(s["members"])))
	row.add_child(ViperKit.ring(minf(1.0, s["groups"] / 10.0), "groups", str(s["groups"])))
	row.add_child(ViperKit.ring(minf(1.0, s["posts"] / 100.0), "posts", str(s["posts"])))
	row.add_child(ViperKit.ring(minf(1.0, s["open_reports"] / 10.0), "reports", str(s["open_reports"]), 120, true))
	if int(s.get("held_posts", 0)) > 0: c.body().add_child(_text("%d post(s) held for review. See Reports." % s["held_posts"], PhoenixTokens.WARN))
	c.body().add_child(_text("Local only. Nothing leaves this phone yet.", PhoenixTokens.PLATINUM_DIM))
	var e := _card("Example data"); b.add_child(e)
	e.body().add_child(_text("Fake members for testing. Labelled [EXAMPLE].", PhoenixTokens.PLATINUM_DIM))
	var owner := Tiers.tier_of(Tiers.SELF) == "owner"
	var add := _btn("Add examples", func(): _done(Social.seed_examples(Tiers.SELF)))
	var rm := _btn("Remove examples", func(): _done(Social.clear_examples(Tiers.SELF)))
	add.disabled = not owner; rm.disabled = not owner
	e.body().add_child(_row([add, rm]))
	if not owner: e.body().add_child(_text("Owner unlock needed (Security).", PhoenixTokens.WARN))

func _done(r: Dictionary) -> void:
	toast("Done" if r["ok"] else str(r["error"]), "ok" if r["ok"] else "warn")
	refresh()

# ---------- Reports ----------
func _reports() -> void:
	var b: VBoxContainer = boxes["Reports"]; _clear(b)
	if not Tiers.can(Tiers.SELF, "moderate"):
		b.add_child(_text("Staff or owner only. Unlock in Security.", PhoenixTokens.WARN)); return
	var list := Social.moderation_queue(Tiers.SELF)
	if list.is_empty(): b.add_child(_text("No open reports.", PhoenixTokens.PLATINUM_DIM)); return
	for r in list.slice(0, 7):
		var head := "%s · %s%s" % [str(r["kind"]).capitalize(), r["target"], "  ×%d" % r["count"] if int(r["count"]) > 1 else ""]
		var c := _card(head); b.add_child(c)
		if r["held"]: c.body().add_child(_text("Held: hidden until you decide.", PhoenixTokens.WARN))
		if str(r["snippet"]) != "": c.body().add_child(_text("“%s”" % str(r["snippet"]), PhoenixTokens.PLATINUM_DIM))
		c.body().add_child(_text(" · ".join(r["reasons"]) if not r["reasons"].is_empty() else "(no reason given)"))
		var rid: String = r["report_id"]
		var row := [_btn("Hide", func(): _done(Social.moderate(Tiers.SELF, rid, "hide")))]
		if str(r["kind"]) in ["post", "story", "clip", "reply", "event", "group"] and not r["mature"]:
			row.append(_btn("Mature", func(): _done(Social.moderate(Tiers.SELF, rid, "mature"))))
		row.append(_btn("Keep", func(): _done(Social.moderate(Tiers.SELF, rid, "dismiss"))))
		c.body().add_child(_row(row))

# ---------- Approvals ----------
func _approvals() -> void:
	var b: VBoxContainer = boxes["Approvals"]; _clear(b)
	b.add_child(_text("Companion posts wait here for you. Same queue as MENU › Proposals.", PhoenixTokens.PLATINUM_DIM))
	var list := Social.pending_posts()
	if list.is_empty(): b.add_child(_text("Nothing waiting.", PhoenixTokens.PLATINUM_DIM)); return
	for p in list.slice(0, 7):
		var c := _card(Social.profile(p["author"]).get("display_name", p["author"])); b.add_child(c)
		c.body().add_child(_text(str(p["text"]).left(280)))
		var pid: String = str(p.get("proposal_id", ""))
		var ok := _btn("Approve", func(): _decide(pid, true))
		var no := _btn("Reject", func(): _decide(pid, false))
		ok.disabled = not EveCore.owner_ok(); no.disabled = ok.disabled
		c.body().add_child(_row([ok, no]))

func _decide(pid: String, yes: bool) -> void:
	if EveCore.decide(pid, yes): Social.sync_approvals(); toast("Approved" if yes else "Rejected")
	else: toast("Owner unlock needed", "warn")
	refresh()

# ---------- Groups ----------
func _groups() -> void:
	var b: VBoxContainer = boxes["Groups"]; _clear(b)
	var gs := Social.all_groups()
	if gs.is_empty(): b.add_child(_text("No groups yet.", PhoenixTokens.PLATINUM_DIM)); return
	for g in gs.slice(0, 7):
		var c := _card(("[%s] " % g["tag"] if str(g["tag"]) != "" else "") + str(g["name"])); b.add_child(c)
		c.body().add_child(_text("%d members · %s" % [g["members"].size(), "open" if g["open"] else "invite only"]))
		if not g["land"].is_empty(): c.body().add_child(_text("Land: " + ", ".join(g["land"]), PhoenixTokens.GOLD))
		if not g["notice"].is_empty(): c.body().add_child(_text("Notice: " + str(g["notice"]["text"]).left(140), PhoenixTokens.PLATINUM_DIM))

# ---------- Roles (owner-only save) ----------
func _members() -> Array:
	var ids := {}
	for id in Social.db()["profiles"]: ids[id] = true
	for id in Tiers.roles()["assign"]: ids[id] = true
	for id in pending_tiers: ids[id] = true
	ids.erase(Tiers.OWNER_ID)
	var out := ids.keys(); out.sort()
	return out

func _roles() -> void:
	var b: VBoxContainer = boxes["Roles"]; _clear(b)
	var owner := Tiers.tier_of(Tiers.SELF) == "owner"
	var c := _card("Member tiers"); b.add_child(c)
	for id in _members().slice(0, 12):
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", PhoenixTokens.SPACE[3])
		var l := _text(str(id)); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		var ob := OptionButton.new(); ob.custom_minimum_size = Vector2(260, TAP_PX); ob.add_theme_font_size_override("font_size", 22)
		var cur: String = pending_tiers.get(id, Tiers.assigned_tier(id))
		for i in Tiers.ORDER.size() - 1:   # never "owner"
			ob.add_item(Tiers.label(Tiers.ORDER[i]), i)
		ob.select(maxi(0, Tiers.ORDER.find(cur)))
		var mid: String = id
		ob.item_selected.connect(func(i): pending_tiers[mid] = Tiers.ORDER[i])
		h.add_child(ob); c.body().add_child(h)
	_new_member = LineEdit.new(); _new_member.placeholder_text = "Member or bot id"
	_new_member.custom_minimum_size = Vector2(0, TAP_PX); _new_member.add_theme_font_size_override("font_size", 22)
	c.body().add_child(_new_member)
	c.body().add_child(_row([_btn("Add member", func():
		var id := _new_member.text.strip_edges()
		if id != "" and id != Tiers.OWNER_ID: pending_tiers[id] = Tiers.assigned_tier(id)
		_roles())]))
	save_roles_btn = _btn("Save roles", func():
		var e := save_roles()
		toast("Roles saved" if e == "" else e, "ok" if e == "" else "warn"))
	save_roles_btn.disabled = not owner
	c.body().add_child(save_roles_btn)
	if not owner: c.body().add_child(_text("Only you can save. Unlock in Security.", PhoenixTokens.WARN))
	var mc := _card("What each tier can do"); b.add_child(mc)
	var mx := Tiers.matrix()
	for t in Tiers.ORDER:
		mc.body().add_child(_text(Tiers.label(t), PhoenixTokens.GOLD, 22))
		mc.body().add_child(_text(", ".join(mx.get(t, [])).replace("_", " "), PhoenixTokens.PLATINUM_DIM))

## Owner only. Returns "" on success or the first error.
func save_roles() -> String:
	if not AdminGate.ok(): return AdminGate.DENIED
	for id in pending_tiers.keys():
		var e := Tiers.set_role(id, pending_tiers[id])
		if e != "": return e
		pending_tiers.erase(id)
	refresh()
	return ""

# ---------- self-checks for tests (phone rules) ----------
func _walk(n: Node, out: Array) -> void:
	for ch in n.get_children():
		out.append(ch); _walk(ch, out)

func min_font_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if (n is Label or n is Button or n is LineEdit) and n.is_visible_in_tree() and (n as Control).get_theme_font_size("font_size") < px:
			print("community: small text ", n.get_path(), " ", (n as Control).get_theme_font_size("font_size"))
			return false
	return true

func min_tap_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if n is BaseButton and n.custom_minimum_size.y < px and not n.get_parent() is TabBar: return false
	return true
