class_name AdminScreen
extends Control
## Viper OS Admin, built on the Phoenix Glass kit (docs/UI_DESIGN_LANGUAGE.md §8).
## Portrait-first (720x1280). Five swipeable tabs (§8 Tabs): Home · Tickets · Wiki · Timeline · Profile.
## - Tickets: segmented filter pills + admin-table pill rows (<= 7, then pages), swipe left for workflow actions.
## - Wiki: pill rows of pages, rendered Trac-style links, edit + history.
## - Timeline: ring timeline (one day at a time) of git commits + in-app revisions; hold-to-confirm revert.
## - Profile: sign-up stepper (name -> avatar -> voice -> realm -> done), local only.
## Data: ViperAdminData (user://viper). No accounts, no servers.

signal closed

const TABS := ["Home", "Tickets", "Wiki", "Timeline", "Profile"]
const TICKET_FILTERS := [["open", "Open"], ["new", "New"], ["accepted", "Mine"], ["closed", "Closed"], ["all", "All"]]

var pages: SwipePages
var home: VBoxContainer
var ticket_filter: SegmentedPills
var ticket_list: PagedList
var ticket_detail: VBoxContainer
var ticket_view: RichTextLabel
var ticket_actions: HFlowContainer
var wiki_filter: SegmentedPills
var wiki_list: PagedList
var wiki_detail: VBoxContainer
var wiki_view: RichTextLabel
var wiki_edit: TextEdit
var timeline: RingTimeline
var revert_btn: HoldButton
var profile_box: VBoxContainer
var stepper: SignupStepper
var current_ticket := 0
var current_page := "WikiStart"
var author := "local"
var write_profile := true   # tests set false so user://profile.json is never touched

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var pn := get_node_or_null("/root/Profile")
	if pn: author = pn.display_name()
	var bg := ColorRect.new(); bg.color = PhoenixTokens.VOID; bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, PhoenixTokens.SPACE[5])
	m.add_theme_constant_override("margin_top", PhoenixTokens.SPACE[6]); m.add_theme_constant_override("margin_bottom", PhoenixTokens.SPACE[5])
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.SPACE[4]); m.add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new(); title.text = "Viper OS"; title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var close := Button.new(); close.text = "✕"; close.name = "Close"
	close.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN, PhoenixTokens.TAP_MIN)
	close.pressed.connect(func(): closed.emit(); queue_free())
	head.add_child(close); v.add_child(head)
	pages = SwipePages.new(); pages.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(pages)
	_build_home(); _build_tickets(); _build_wiki(); _build_timeline(); _build_profile()
	pages.page_changed.connect(func(_i): refresh())
	refresh()

func _page(n: String) -> VBoxContainer:
	var sc := ScrollContainer.new(); sc.name = n
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var b := VBoxContainer.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_constant_override("separation", PhoenixTokens.SPACE[4])
	sc.add_child(b); pages.add_page(n, sc)
	return b

func toast(t: String, variant := "ok") -> void: Toast.show_toast(self, t, variant)

func refresh() -> void:
	_refresh_home(); _refresh_tickets(); _refresh_wiki(); _refresh_timeline(); _refresh_profile()

# ---------- Home ----------
func _build_home() -> void: home = _page("Home")

func dashboard_stats() -> Dictionary:
	var c := ViperAdminData.tickets().counts_by_status()
	var total := 0
	for k in c: total += int(c[k])
	var pending := 0
	for cid in _companion_ids(): pending += BrainCore.owner_proposals(cid, true).size()
	var needs := {}
	if is_inside_tree():
		for a in get_tree().get_nodes_in_group("companions"):
			var life = a.get("life")
			if life: needs[str(a.get("companion_id"))] = float(life.energy)
	return {"tickets": c, "total": total, "pending_proposals": pending, "needs": needs, "head": ViperAdminData.revisions().head()}

func _companion_ids() -> Array:
	return Array(DirAccess.get_directories_at("res://companions")) if DirAccess.dir_exists_absolute("res://companions") else []

## Revisions per day for the last n days (oldest first), for the LineGraph.
func revisions_per_day(n := 10) -> PackedFloat32Array:
	var out := PackedFloat32Array(); out.resize(n)
	var today := Time.get_unix_time_from_system() + int(Time.get_time_zone_from_system().get("bias", 0)) * 60   # local wall clock
	for r in ViperAdminData.revisions().history("", "", 100000):
		var age := int((today - Time.get_unix_time_from_datetime_string(str(r["t"]).left(19))) / 86400.0)
		if age >= 0 and age < n: out[n - 1 - age] += 1
	return out

func _refresh_home() -> void:
	if home == null: return
	for ch in home.get_children(): home.remove_child(ch); ch.queue_free()
	var s := dashboard_stats()
	var tot := maxi(1, s["total"])
	var tc := ViperKit.card("Tickets"); home.add_child(tc)
	var row := HFlowContainer.new(); row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", PhoenixTokens.SPACE[5]); tc.body().add_child(row)
	var open: int = s["total"] - int(s["tickets"].get("closed", 0))
	row.add_child(ViperKit.ring(float(open) / tot, "open", str(open)))
	row.add_child(ViperKit.ring(float(s["tickets"].get("accepted", 0)) / tot, "accepted", str(s["tickets"].get("accepted", 0))))
	row.add_child(ViperKit.ring(float(s["tickets"].get("closed", 0)) / tot, "closed", str(s["tickets"].get("closed", 0))))
	var bc := ViperKit.card("Companions"); home.add_child(bc)
	var row2 := HFlowContainer.new(); row2.alignment = FlowContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("h_separation", PhoenixTokens.SPACE[5]); bc.body().add_child(row2)
	row2.add_child(ViperKit.ring(minf(1.0, s["pending_proposals"] / 10.0), "proposals", str(s["pending_proposals"])))
	for cid in s["needs"]: row2.add_child(ViperKit.ring(s["needs"][cid], str(cid).split("_")[0], "", 120, true))
	var sc := ViperKit.card("Security"); home.add_child(sc)
	var row3 := HFlowContainer.new(); row3.alignment = FlowContainer.ALIGNMENT_CENTER
	row3.add_theme_constant_override("h_separation", PhoenixTokens.SPACE[5]); sc.body().add_child(row3)
	var chain := ViperAdminData.revisions().verify_chain()
	row3.add_child(ViperKit.ring(1.0 if chain["ok"] else 0.0, "audit " + ("verified" if chain["ok"] else "broken"), "✓" if chain["ok"] else "✗"))
	row3.add_child(ViperKit.ring(float(OwnerVault.seconds_left()) / maxf(1.0, OwnerVault.lock_minutes() * 60.0), "owner", "open" if OwnerVault.is_unlocked() else "locked"))
	row3.add_child(ViperKit.ring(0.0 if AutonomyGuard.paused() else 1.0, "companions", "paused" if AutonomyGuard.paused() else "live", 120, true))
	var sl := Label.new(); sl.text = SecurityScreen.audit_text(chain); sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc.body().add_child(sl)
	var gc := ViperKit.card("Revisions · 10 days"); home.add_child(gc)
	var big := Label.new(); big.text = "r%d" % s["head"]; big.theme_type_variation = &"DisplayLabel"; gc.body().add_child(big)
	gc.body().add_child(ViperKit.graph(revisions_per_day(10)))
	var rc := ViperKit.card("Report"); home.add_child(rc)
	var rt := ViperKit.rich(); rt.text = report_text(); rc.body().add_child(rt)

func report_text() -> String:
	var ts := ViperAdminData.tickets()
	var by_ms := {}; var by_pr := {}
	for t in ts.query():
		var ms: String = t["milestone"] if t["milestone"] != "" else "(none)"
		if not by_ms.has(ms): by_ms[ms] = {"open": 0, "closed": 0}
		by_ms[ms]["closed" if t["status"] == "closed" else "open"] += 1
		if t["status"] != "closed": by_pr[t["priority"]] = int(by_pr.get(t["priority"], 0)) + 1
	var kinds := {}
	for r in ViperAdminData.revisions().history("", "", 100000): kinds[r["kind"]] = int(kinds.get(r["kind"], 0)) + 1
	var s := "[b]Milestones[/b]\n"
	var ks := by_ms.keys(); ks.sort()
	for ms in ks:
		var o: int = by_ms[ms]["open"]; var c: int = by_ms[ms]["closed"]
		s += "  %s  %d/%d closed (%d%%)\n" % [ms, c, o + c, roundi(100.0 * c / maxi(1, o + c))]
	s += "\n[b]Open by priority[/b]  " + "  ".join(TicketStore.PRIORITIES.map(func(p): return "%s %d" % [p, int(by_pr.get(p, 0))]))
	s += "\n[b]Revisions by kind[/b]  " + "  ".join(kinds.keys().map(func(k): return "%s %d" % [k, kinds[k]]))
	s += "\n[b]Repository[/b]  %d commits (exported at build time)" % RepoTimeline.commits().size()
	return s

# ---------- Tickets ----------
func _build_tickets() -> void:
	var b := _page("Tickets")
	ticket_filter = SegmentedPills.new().setup(TICKET_FILTERS, "open")
	ticket_filter.changed.connect(func(_id): _refresh_tickets())
	b.add_child(ticket_filter)
	ticket_list = PagedList.new(); b.add_child(ticket_list)
	ticket_detail = VBoxContainer.new(); ticket_detail.visible = false
	ticket_detail.add_theme_constant_override("separation", PhoenixTokens.SPACE[4]); b.add_child(ticket_detail)
	var back := Button.new(); back.text = "‹ Tickets"; back.custom_minimum_size.y = PhoenixTokens.TAP_MIN
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): current_ticket = 0; _refresh_tickets())
	ticket_detail.add_child(back)
	var card := ViperKit.card("Ticket"); ticket_detail.add_child(card)
	ticket_view = ViperKit.rich(); ticket_view.meta_clicked.connect(_on_link); card.body().add_child(ticket_view)
	ticket_actions = HFlowContainer.new(); ticket_actions.add_theme_constant_override("h_separation", 8); card.body().add_child(ticket_actions)
	var cm := LineEdit.new(); cm.placeholder_text = "Comment: #12, r42, WikiName…"; cm.custom_minimum_size.y = 64
	card.body().add_child(cm)
	card.body().add_child(ViperKit.primary("Comment", func():
		if ViperAdminData.tickets().comment(current_ticket, cm.text, author): cm.text = ""; _show_ticket(); toast("Comment added")))
	var nt := LineEdit.new(); nt.placeholder_text = "New ticket summary"; nt.custom_minimum_size.y = 64; b.add_child(nt)
	b.add_child(ViperKit.primary("＋ New ticket", func():
		var id := ViperAdminData.tickets().create({"summary": nt.text}, author)
		if id: nt.text = ""; current_ticket = id; toast("Ticket #%d created" % id); _refresh_tickets()
		else: toast("Summary needed", "warn")))

func filtered_tickets() -> Array:
	var f := ticket_filter.selected if ticket_filter else "open"
	var out: Array = []
	for t in ViperAdminData.tickets().query():
		var ok := false
		if f == "open": ok = t["status"] != "closed"
		elif f == "all": ok = true
		elif f == "accepted": ok = t["status"] == "accepted" and (t["owner"] == author or t["owner"] == "")
		else: ok = t["status"] == f
		if ok: out.append(t)
	return out

func _ticket_row(t: Dictionary) -> PillRow:
	var acts: Array = TicketStore.WORKFLOW.get(t["status"], []).map(func(s): return [s, s.capitalize()])
	var r := PillRow.new().setup("#%d %s" % [t["id"], t["summary"]], t["status"], acts,
		"%s · %s" % [t["priority"], t["milestone"] if t["milestone"] != "" else "no milestone"],
		str(t["owner"]).left(1).to_upper() if t["owner"] != "" else "◎")
	r.chip_color = ViperKit.status_color(t["status"])
	var id: int = t["id"]
	r.tapped.connect(func(): current_ticket = id; _refresh_tickets())
	r.action.connect(func(to): do_transition(id, to))
	return r

func do_transition(id: int, to: String) -> int:
	var rv := ViperAdminData.tickets().transition(id, to, author, "fixed", author)
	toast(("#%d → %s · r%d" % [id, to, rv]) if rv else "Not allowed", "ok" if rv else "err")
	_refresh_tickets()
	return rv

func _refresh_tickets() -> void:
	if ticket_list == null: return
	var detail := current_ticket > 0 and not ViperAdminData.tickets().get_ticket(current_ticket).is_empty()
	ticket_list.visible = not detail; ticket_filter.visible = not detail; ticket_detail.visible = detail
	ticket_list.set_items(filtered_tickets(), _ticket_row, true)
	if detail: _show_ticket()

func _show_ticket() -> void:
	var t := ViperAdminData.tickets().get_ticket(current_ticket)
	for c in ticket_actions.get_children(): c.queue_free()
	if t.is_empty(): return
	var w := ViperAdminData.wiki()
	var s := "[font_size=28]#%d %s[/font_size]\n[color=#%s]%s[/color] [color=#9c98a8]· %s · %s · %s · owner %s[/color]\n\n%s" % [
		t["id"], t["summary"].replace("[", "[lb]"), ViperKit.status_color(t["status"]).to_html(false), t["status"].to_upper(),
		t["type"], t["priority"], t["milestone"], t["owner"] if t["owner"] != "" else "—", w.render(t["description"])]
	if not t["revisions"].is_empty():
		s += "\n[color=#9c98a8]Revisions[/color] " + " ".join(t["revisions"].map(func(r): return "[url=rev:%d]r%d[/url]" % [r, r]))
	for c in t["comments"]:
		s += "\n\n[color=#ff2db8]%s[/color] [color=#9c98a8]%s[/color]\n%s" % [c["author"], str(c["t"]).left(16), w.render(c["text"])]
	ticket_view.text = s
	for to in TicketStore.WORKFLOW.get(t["status"], []):
		var dest: String = to
		var b := Button.new(); b.text = "→ " + dest.capitalize(); b.custom_minimum_size.y = PhoenixTokens.TAP_MIN
		b.pressed.connect(func(): do_transition(current_ticket, dest))
		ticket_actions.add_child(b)

# ---------- Wiki ----------
func _build_wiki() -> void:
	var b := _page("Wiki")
	wiki_filter = SegmentedPills.new().setup([["pages", "Pages"], ["recent", "Recent"]], "pages")
	wiki_filter.changed.connect(func(_id): _refresh_wiki())
	b.add_child(wiki_filter)
	wiki_list = PagedList.new(); b.add_child(wiki_list)
	wiki_detail = VBoxContainer.new(); wiki_detail.visible = false
	wiki_detail.add_theme_constant_override("separation", PhoenixTokens.SPACE[4]); b.add_child(wiki_detail)
	var back := Button.new(); back.text = "‹ Wiki"; back.custom_minimum_size.y = PhoenixTokens.TAP_MIN
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): current_page = ""; _refresh_wiki())
	wiki_detail.add_child(back)
	var card := ViperKit.card("Page"); wiki_detail.add_child(card)
	wiki_view = ViperKit.rich(); wiki_view.meta_clicked.connect(_on_link); card.body().add_child(wiki_view)
	wiki_edit = TextEdit.new(); wiki_edit.custom_minimum_size = Vector2(0, 360); wiki_edit.visible = false
	wiki_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; card.body().add_child(wiki_edit)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
	var hist := Button.new(); hist.text = "⟲ History"; hist.custom_minimum_size.y = 64
	hist.pressed.connect(func(): pages.go(TABS.find("Timeline")); _refresh_timeline("wiki/" + current_page))
	var edit := Button.new(); edit.text = "✎ Edit"; edit.custom_minimum_size.y = 64
	edit.pressed.connect(func(): wiki_edit.visible = not wiki_edit.visible; wiki_edit.text = ViperAdminData.wiki().get_text(current_page))
	row.add_child(hist); row.add_child(edit)
	row.add_child(ViperKit.primary("Save", func(): save_wiki_edit()))
	wiki_detail.add_child(row)
	current_page = ""

func save_wiki_edit() -> int:
	if not wiki_edit.visible: return 0
	var rv := ViperAdminData.wiki().save_page(current_page, wiki_edit.text, author)
	if rv: wiki_edit.visible = false; open_page(current_page); toast("Saved as r%d" % rv)
	else: toast("Nothing to save", "warn")
	return rv

func _page_row(n: String) -> PillRow:
	var w := ViperAdminData.wiki()
	var r := PillRow.new().setup(n, "r%d" % int(w.pages.get(n, {}).get("rev", 0)), [], str(w.pages.get(n, {}).get("source", "")), "W")
	r.chip_color = PhoenixTokens.GOLD
	r.tapped.connect(func(): open_page(n))
	return r

func _refresh_wiki() -> void:
	if wiki_list == null: return
	var detail := current_page != ""
	wiki_list.visible = not detail; wiki_filter.visible = not detail; wiki_detail.visible = detail
	var names: Array = ViperAdminData.wiki().names()
	if wiki_filter.selected == "recent":
		names.sort_custom(func(a, b): return int(ViperAdminData.wiki().pages[a]["rev"]) > int(ViperAdminData.wiki().pages[b]["rev"]))
	wiki_list.set_items(names, _page_row, true)
	if detail: open_page(current_page)

func open_page(n: String) -> void:
	current_page = n
	if wiki_detail and not wiki_detail.visible: _refresh_wiki(); return
	var w := ViperAdminData.wiki()
	wiki_view.text = ("[font_size=28]%s[/font_size]\n\n" % n) + (w.render(w.get_text(n)) if w.pages.has(n) else "[color=#9c98a8]New page. Tap Edit to write it.[/color]")

# ---------- Timeline ----------
func _build_timeline() -> void:
	var b := _page("Timeline")
	timeline = RingTimeline.new(); timeline.detail_provider = timeline_detail
	timeline.item_selected.connect(func(_r): _sync_revert())
	b.add_child(timeline)
	revert_btn = HoldButton.new(); revert_btn.visible = false; revert_btn.custom_minimum_size.y = 64
	revert_btn.confirmed.connect(func(): revert_selected())
	b.add_child(revert_btn)

static func _actor(r: Dictionary) -> String:
	if r.get("kind") == "brain_cell": return "companion"
	return "system" if r.get("author") == "system" else "owner"

func _refresh_timeline(prefix := "") -> void:
	if timeline == null: return
	var ev: Array = []
	if prefix == "":
		for e in RepoTimeline.merged(ViperAdminData.revisions(), 400):
			e["actor"] = "system"
			if e["kind"] == "revision": e["actor"] = _actor(ViperAdminData.revisions().get_rev(int(e["ref"].substr(1))))
			ev.append(e)
	else:
		for r in ViperAdminData.revisions().history(prefix):
			ev.append({"when": r["t"], "kind": "revision", "title": "r%d %s" % [r["rev"], r["message"]], "ref": "r%d" % r["rev"], "author": r["author"], "actor": _actor(r)})
	timeline.set_events(ev)
	_sync_revert()

func timeline_detail(ref: String) -> String:
	if ref.begins_with("r") and ref.substr(1).is_valid_int(): return revision_bbcode(int(ref.substr(1)))
	var c := RepoTimeline.find(ref)
	return "[b]changeset %s[/b]\n%s\n[color=#9c98a8]%s · %s · read-only (git log at build time)[/color]" % [ref, str(c.get("subject", "")).replace("[", "[lb]"), c.get("author", ""), c.get("date", "")]

func revision_bbcode(n: int) -> String:
	var r := ViperAdminData.revisions().get_rev(n)
	if r.is_empty(): return "No revision r%d" % n
	var lines := PackedStringArray()
	for l in ViperAdminData.revisions().diff(n).split("\n"):
		var e := l.replace("[", "[lb]")
		lines.append("[color=#5ef0b0]%s[/color]" % e if l.begins_with("+ ") else ("[color=#ff4d6d]%s[/color]" % e if l.begins_with("- ") else e))
	return "[b]r%d[/b] %s\n[code]%s[/code]" % [n, r["message"].replace("[", "[lb]"), "\n".join(lines.slice(0, 80))]

func _sync_revert() -> void:
	var ref := timeline.expanded()
	revert_btn.visible = ref.begins_with("r") and ref.substr(1).is_valid_int()
	revert_btn.text = "Hold to revert %s" % ref

func show_revision(n: int) -> void:
	pages.go(TABS.find("Timeline"))
	var r := ViperAdminData.revisions().get_rev(n)
	if r.is_empty(): return
	var day := str(r["t"]).left(10)
	timeline.show_day(maxi(0, timeline.days.find(day)))
	if timeline.expanded() != "r%d" % n: timeline.toggle("r%d" % n)

func revert_selected() -> int:
	var ref := timeline.expanded()
	if not ref.begins_with("r"): return 0
	var nr := ViperAdminData.revisions().revert(int(ref.substr(1)), author)
	toast(("Reverted as r%d" % nr) if nr else "Can't revert", "ok" if nr else "err")
	if nr: refresh()
	return nr

func _on_link(meta: Variant) -> void:
	var l := WikiStore.parse_link(str(meta))
	match l.get("type", ""):
		"wiki": current_page = l["id"]; pages.go(TABS.find("Wiki")); _refresh_wiki()
		"ticket": current_ticket = int(l["id"]); pages.go(TABS.find("Tickets")); _refresh_tickets()
		"rev": show_revision(int(l["id"]))
		"changeset":
			pages.go(TABS.find("Timeline"))
			var c := RepoTimeline.find(l["id"])
			if not c.is_empty():
				timeline.show_day(maxi(0, timeline.days.find(str(c["date"]).left(10))))
				if timeline.expanded() != str(c["sha"]): timeline.toggle(str(c["sha"]))

# ---------- Profile / sign-up ----------
func _build_profile() -> void:
	profile_box = _page("Profile")

func _refresh_profile(force_stepper := false) -> void:
	if profile_box == null: return
	for c in profile_box.get_children(): profile_box.remove_child(c); c.queue_free()
	var saved := load_signup()
	if saved.is_empty() or force_stepper:
		stepper = SignupStepper.new(); stepper.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stepper.prefill(saved)
		stepper.completed.connect(func(d):
			var e := save_signup(d)
			toast("Welcome, " + str(d["name"]) if e == "" else e, "ember" if e == "" else "err"))
		profile_box.add_child(stepper)
		return
	stepper = null
	var cc := CenterContainer.new(); profile_box.add_child(cc)
	cc.add_child(ViperKit.ring(1.0, "member", str(saved["name"]).left(1).to_upper(), 240))
	var card := ViperKit.card(saved["name"]); profile_box.add_child(card)
	for k in [["@", "handle"], ["Look", "avatar"], ["Voice", "voice"], ["Realm", "realm"]]:
		var l := Label.new(); l.text = "%s  %s" % [k[0], str(saved.get(k[1], "")).replace("_", " ")]; card.body().add_child(l)
	var note := Label.new(); note.text = "Stored on this device only. No servers, no email, no phone."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.add_theme_color_override("font_color", PhoenixTokens.PLATINUM_DIM)
	card.body().add_child(note)
	profile_box.add_child(ViperKit.primary("Edit profile", func(): _refresh_profile(true)))

static func _signup_path() -> String: return ViperAdminData.root.path_join("signup.json")

static func load_signup() -> Dictionary:
	var d: Variant = SecureFile.read_json(_signup_path())
	return d if d is Dictionary else {}

## Validate + store the local profile card (one revision). Returns "" or an error.
func save_signup(d: Dictionary) -> String:
	var data := d.duplicate()
	data["handle"] = str(data.get("handle", "")).strip_edges().trim_prefix("@")
	data["name"] = str(data.get("name", "")).strip_edges()
	for step in ["name", "voice", "realm"]:
		var e := SignupStepper.validate(step, data)
		if e != "": return e
	var mem := BrainMemory.new(ViperAdminData.root.path_join("_tmp"), "signup")
	if mem.is_sensitive(data["name"] + " " + data["handle"]): return "Looks like private info. Use a nickname."
	var before := load_signup()
	var after := {"name": data["name"].left(32), "handle": data["handle"], "avatar": str(data.get("avatar", "wanderer")),
		"voice": str(data["voice"]), "realm": str(data["realm"]), "created": before.get("created", RevisionStore.local_iso())}
	SecureFile.write_json(_signup_path(), after, "\t")
	ViperAdminData.revisions().commit("profile", "profile/local", before if not before.is_empty() else null, after, "Profile saved", after["handle"])
	var pn := get_node_or_null("/root/Profile") if is_inside_tree() else null
	if write_profile and pn:
		var av: Dictionary = pn.preset_avatar(after["avatar"])
		pn.save_profile(after["name"], av if not av.is_empty() else pn.avatar())
	return ""
