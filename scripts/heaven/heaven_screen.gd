class_name HeavenScreen
extends Control
## Heaven panel (Glass, ViperKit). Pages: Transit · Shop · Casino · Weather · Access · Direct a change.
## Opened by HeavenWorld prompts (shop door, transit kiosk, casino hall) and the ☁ Heaven menu tile.
## Rules shown here are enforced underneath (HeavenAccess, HeavenEdits, LegalReview, FreePlay):
## the screen never decides anything on its own.
signal closed

const PAGES := ["transit", "shop", "casino", "weather", "access", "direct"]
const PAGE_TITLES := {"transit": "🚝 Transit", "shop": "🛍 Shop", "casino": "🎡 Free play", "weather": "🌤 Weather", "access": "🔑 Access", "direct": "🛠 Direct a change"}

var hw: Node          # HeavenWorld (may be null in tests)
var page := "transit"
var info := {}
var body: VBoxContainer
var last_msg := ""
var direct := {"companion": "", "spot": Vector3.ZERO, "has_spot": false, "piece": {}}

static func open(parent: Node, heaven_world: Node = null, p := "transit", i := {}) -> HeavenScreen:
	var s: HeavenScreen = parent.get_node_or_null("HeavenScreen")
	if s == null:
		s = HeavenScreen.new(); s.name = "HeavenScreen"
		s.hw = heaven_world; s.page = p; s.info = i
		parent.add_child(s)
	else:
		s.info = i; s.go(p)
	return s

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = Color(PhoenixTokens.VOID, 0.92); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "bottom"]: m.add_theme_constant_override("margin_" + s, PhoenixTokens.SPACE[4])
	m.add_theme_constant_override("margin_top", PhoenixTokens.SPACE[5])
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.SPACE[3]); m.add_child(v)
	var head := HBoxContainer.new()
	var t := Label.new(); t.text = "☁ Heaven"; t.theme_type_variation = &"TitleLabel"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN, PhoenixTokens.TAP_MIN)
	x.pressed.connect(close); head.add_child(x)
	v.add_child(head)
	var tabs := HFlowContainer.new(); tabs.name = "Tabs"
	for p in PAGES:
		var b := Button.new(); b.text = PAGE_TITLES[p]; b.name = "Tab_" + p
		b.custom_minimum_size = Vector2(0, PhoenixTokens.TAP_MIN)
		b.pressed.connect(go.bind(p)); tabs.add_child(b)
	v.add_child(tabs)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", PhoenixTokens.SPACE[3]); sc.add_child(body)
	refresh()

func close() -> void:
	closed.emit(); queue_free()

func go(p: String) -> void:
	page = p if p in PAGES else "transit"
	if body: refresh()

func refresh() -> void:
	for ch in body.get_children(): body.remove_child(ch); ch.queue_free()
	if last_msg != "": _text(body, last_msg, PhoenixTokens.WARN)
	match page:
		"transit": _transit()
		"shop": _shop()
		"casino": _casino()
		"weather": _weather()
		"access": _access()
		"direct": _direct()

func _say(msg: String, ok := true) -> void:
	last_msg = msg
	Toast.show_toast(get_parent() if get_parent() else self, msg, "ok" if ok else "warn")
	refresh()

# ---------- helpers ----------
func _card(title: String) -> VBoxContainer:
	var c := ViperKit.card(title)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(c)
	return c.body()

static func _text(box: Control, s: String, col := PhoenixTokens.PLATINUM) -> Label:
	var l := Label.new(); l.text = s; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", PhoenixTokens.TYPE["label"]); l.add_theme_color_override("font_color", col)
	box.add_child(l)
	return l

static func _btn(box: Control, text: String, f: Callable, nm := "") -> Button:
	var b := DeviceCompatScreen._btn(text, f, nm)
	box.add_child(b)
	return b

# ---------- pages ----------
func _transit() -> void:
	var c := _card("Travel between districts")
	_text(c, "Free for everyone. Flying here is by the owner's grant; transit always works.")
	for i in HeavenLayout.islands():
		var row := HBoxContainer.new()
		_text(row, "%s — %s" % [i["name"], str(i.get("about", "")).left(80)])
		var b := DeviceCompatScreen._btn("Go", func(): _travel(str(i["id"])), "Go_" + str(i["id"]))
		b.size_flags_horizontal = Control.SIZE_SHRINK_END; b.custom_minimum_size.x = 96
		row.add_child(b); c.add_child(row)

func _travel(id: String) -> void:
	if hw and hw.has_method("travel_to"): hw.travel_to(id)
	close()

func _shop() -> void:
	var sid := str(info.get("shop", ""))
	if sid == "":
		var c0 := _card("Shops")
		for s in HeavenShops.shops():
			_btn(c0, "%s · %s (%s)" % [s["name"], s["category"], HeavenLayout.island(str(s["island"])).get("name", "")], func(): info = {"shop": s["id"]}; refresh())
		return
	var s := HeavenShops.shop(sid)
	var inv := get_node_or_null("/root/Inventory")
	var c := _card(str(s.get("name", "Shop")))
	_text(c, str(s.get("about", "")))
	var stock := HeavenShops.stock(sid, inv)
	if stock.is_empty() and s.get("category", "") != "info": _text(c, "House rails are empty here — creator listings below.", PhoenixTokens.PLATINUM_DIM)
	for it in stock:
		var worn: bool = inv != null and inv.is_equipped("player", str(it["id"]))
		_btn(c, ("✓ Wearing " if worn else "Try on · ") + str(it.get("name", it["id"])), func(): _wear(str(it["id"])), "Wear_" + str(it["id"]))
	var lc := _card("Creator listings")
	var ls := HeavenShops.creator_listings(sid)
	if ls.is_empty(): _text(lc, "No creator listings in this category yet.", PhoenixTokens.PLATINUM_DIM)
	for l in ls:
		var price := int(l.get("price_aethel", 0))
		_btn(lc, "%s · %s" % [l["title"], ("%d Aethel" % price) if price > 0 else "free"], func(): _buy(str(l["id"]), price))
	_text(lc, "Priced items need a confirmed age and country (legal review); purchases are fixed-price only.", PhoenixTokens.PLATINUM_DIM)

func _wear(id: String) -> void:
	var err := HeavenShops.wear(get_node_or_null("/root/Inventory"), id)
	_say("Updated your look." if err == "" else err, err == "")

func _buy(id: String, shown_price: int) -> void:
	var r := HeavenShops.buy(id, int(Time.get_unix_time_from_system()), {"shown_price": shown_price})
	_say(str(r.get("error", "Delivered to your inventory.")), not r.has("error"))

func _casino() -> void:
	var c := _card("Free-play games")
	_text(c, "Play tokens only. No Aethel Coin wagers or payouts, ever.")
	for g in FreePlay.GAMES:
		var gd: Dictionary = FreePlay.GAMES[g]
		var lines: Array = FreePlay.odds(g).map(func(o): return "%s %.0f%%" % [o["prize"], o["percent"]])
		_text(c, "%s (%d tokens): %s" % [gd["title"], gd["cost"], ", ".join(lines)])
		_btn(c, "Play " + str(gd["title"]), func(): _spin(str(g)), "Spin_" + str(g))

func _spin(game: String) -> void:
	var r := FreePlay.spin(Tiers.SELF, game, {}, int(Time.get_unix_time_from_system()))
	if r.has("error"): _say(str(r["error"]), false)
	else: _say("Won: " + (str(r["cosmetic"]) if r.has("cosmetic") else "%d play tokens" % int(r.get("tokens", 0))))

func _weather() -> void:
	var hour := 12.0
	if hw and hw.get("world") and hw.world.get("hour") != null: hour = float(hw.world.hour)
	for i in HeavenLayout.islands():
		var w := HeavenWeather.report(str(i["id"]), HeavenWeather.today(), hour)
		_text(body, "%s · %s · %s" % [i["name"], w["text"], w["label"]])
	_text(body, "Heaven weather is gentle by design (no storms). Temperatures are in kelvin.", PhoenixTokens.PLATINUM_DIM)

func _access() -> void:
	var c := _card("Who can fly, build and auto-build in Heaven")
	var owner := HeavenAccess.is_owner(Tiers.SELF)
	_text(c, "You are the owner (unlocked)." if owner else "Only the owner (unlocked) can change grants. Everyone walks or uses transit.")
	for kind in HeavenAccess.KINDS:
		var ms: Array = HeavenAccess.members(kind)
		_text(c, "%s: %s" % [kind, ", ".join(ms) if not ms.is_empty() else "owner only"])
	if not owner: return
	var comp := _companion_ids()
	if not comp.is_empty():
		_btn(c, "Let my companions fly with me", func(): _grant_all("fly", comp))
		_btn(c, "Standing build grant for my companions (edits apply without asking)", func(): _grant_all("build", comp), "GrantBuild")
		_btn(c, "Revoke companions' build grant", func(): _revoke_all("build", comp))
	var row := HBoxContainer.new()
	var le := LineEdit.new(); le.placeholder_text = "member id"; le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size.y = PhoenixTokens.TAP_MIN; row.add_child(le)
	for kind in HeavenAccess.KINDS:
		var b := DeviceCompatScreen._btn("+" + kind, func(): _grant_one(kind, le.text.strip_edges()))
		b.size_flags_horizontal = Control.SIZE_SHRINK_END; row.add_child(b)
	c.add_child(row)

func _grant_all(kind: String, ids: Array) -> void:
	var err := HeavenAccess.grant_many(Tiers.SELF, kind, ids, int(Time.get_unix_time_from_system()))
	_say(err if err != "" else "Granted %s to %d companions." % [kind, ids.size()], err == "")

func _revoke_all(kind: String, ids: Array) -> void:
	var err := ""
	for id in ids:
		var e := HeavenAccess.revoke(Tiers.SELF, kind, id, int(Time.get_unix_time_from_system()))
		if e != "": err = e
	_say(err if err != "" else "Revoked.", err == "")

func _grant_one(kind: String, id: String) -> void:
	var err := HeavenAccess.grant(Tiers.SELF, kind, id, int(Time.get_unix_time_from_system()))
	_say(err if err != "" else "Granted %s to %s." % [kind, id], err == "")

func _companions() -> Array:
	return get_tree().get_nodes_in_group("companions") if is_inside_tree() else []

func _companion_ids() -> Array:
	return _companions().map(func(c): return str(c.get("companion_id")) if c.get("companion_id") != null else str(c.name))

# ---------- Direct a change ----------
func _direct() -> void:
	var c := _card("Direct a change")
	_text(c, "1 · pick a companion   2 · point at the spot   3 · say what to change. Owner (unlocked) changes apply live; otherwise they wait for the owner's approval.")
	var ids := _companion_ids()
	if ids.is_empty(): ids = ["eve"]
	if direct["companion"] == "" or not direct["companion"] in ids: direct["companion"] = ids[0]
	var row := HFlowContainer.new()
	for id in ids:
		var b := Button.new(); b.text = ("● " if id == direct["companion"] else "") + id
		b.custom_minimum_size = Vector2(0, PhoenixTokens.TAP_MIN)
		b.pressed.connect(func(): direct["companion"] = id; refresh())
		row.add_child(b)
	c.add_child(row)
	if direct["has_spot"]:
		var isl := HeavenLayout.island_at(direct["spot"])
		var pc: Dictionary = direct["piece"]
		_text(c, "Spot: %s%s" % [isl.get("name", "off-island"), (" · near " + str(pc.get("name", pc.get("type", "")))) if not pc.is_empty() else ""])
	_btn(c, "🎯 Point at a spot" if not direct["has_spot"] else "🎯 Point again", _point, "Point")
	var le := LineEdit.new(); le.name = "Ask"; le.placeholder_text = "e.g. put a fountain here · make it taller · paint it gold · remove this"
	le.custom_minimum_size.y = PhoenixTokens.TAP_MIN
	c.add_child(le)
	_btn(c, "Ask " + str(direct["companion"]), func(): ask(le.text), "AskBtn")
	var pend := HeavenEdits.edits("pending")
	if not pend.is_empty():
		var pc2 := _card("Waiting for approval (%d)" % pend.size())
		for e in pend.slice(-8):
			_text(pc2, "%s · %s" % [e["by"], HeavenEdits.describe(e)])
		if HeavenAccess.is_owner(Tiers.SELF):
			_btn(pc2, "Approve all", func(): _decide_all(true))
			_btn(pc2, "Reject all", func(): _decide_all(false))
	var done := HeavenEdits.edits("applied")
	if not done.is_empty():
		var dc := _card("Recent live edits")
		for e in done.slice(-6):
			var row2 := HBoxContainer.new()
			_text(row2, "%s · %s" % [e["by"], HeavenEdits.describe(e)])
			if HeavenAccess.is_owner(Tiers.SELF):
				var u := DeviceCompatScreen._btn("Undo", func(): _undo(str(e["id"])))
				u.size_flags_horizontal = Control.SIZE_SHRINK_END; u.custom_minimum_size.x = 96; row2.add_child(u)
			dc.add_child(row2)

func _point() -> void:
	if hw and hw.has_method("begin_point"):
		visible = false
		hw.begin_point(func(spot: Vector3):
			set_spot(spot)
			visible = true)
	else:
		set_spot(HeavenLayout.spawn_point())

func set_spot(spot: Vector3) -> void:
	direct["spot"] = spot; direct["has_spot"] = true
	var isl := HeavenLayout.island_at(spot)
	direct["piece"] = {}
	if not isl.is_empty():
		var l := HeavenLayout.frame(isl).affine_inverse() * spot
		direct["piece"] = HeavenEdits.nearest_piece(str(isl["id"]), Vector2(l.x, l.z), 20.0)
	if body: refresh()

## The owner's words -> companion proposal -> applied live (unlocked owner) or pending.
func ask(text: String) -> Dictionary:
	if not direct["has_spot"]: _say("Point at a spot first.", false); return {"error": "no spot"}
	var args := HeavenDirector.parse(text, direct["spot"], direct["piece"])
	if args.has("error"): _say(str(args["error"]), false); return args
	var who := str(direct["companion"])
	# owner present + unlocked: the instruction is the approval; otherwise it waits for approval
	var r := HeavenEdits.tool_call(who, args, int(Time.get_unix_time_from_system()), true)
	if r.has("error"): _say(str(r["error"]), false); return r
	var line := ("On it — building now." if r["state"] == "applied" else "I've asked the owner to approve that.")
	_companion_say(who, line)
	if hw and hw.has_method("poll_edits"): hw.poll_edits()
	_say("%s: %s" % [who, line])
	return r

func _companion_say(id: String, text: String) -> void:
	for c in _companions():
		var cid = c.get("companion_id")
		if (str(cid) if cid != null else str(c.name)) == id and c.has_method("show_bubble"): c.show_bubble(text)

func _decide_all(ok: bool) -> void:
	for e in HeavenEdits.edits("pending"): EveCore.decide(str(e["proposal"]), ok)
	var ch := HeavenEdits.sync()
	if hw and hw.has_method("poll_edits"): hw.poll_edits()
	_say(("Approved: %d districts rebuilding." % ch.size()) if ok else "Rejected.")

func _undo(id: String) -> void:
	var err := HeavenEdits.revert(Tiers.SELF, id)
	if hw and hw.has_method("poll_edits"): hw.poll_edits()
	_say(err if err != "" else "Undone.", err == "")
