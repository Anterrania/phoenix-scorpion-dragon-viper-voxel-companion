class_name FrontierScreen
extends Control
## Viper OS > Frontier (MENU > 🪐 Frontier). Admin-style hub for the space-sim systems
## (docs/modules/SPACESIM_PARITY.md). Five swipe tabs (kit max): Home (overview + orgs) · Trade (market +
## contracts) · Industry · Holdings (land + ships) · Comfort. Phoenix Glass kit, portrait, swipe tabs, compact phoenix_tokens sizes (TAP_MIN, TYPE).
## Read-mostly glance cards; the in-world flight HUD, wrist hub, star map and scanner are Foxy's
## (patches/foxy/FRONTIER_CLIENT_SPECS.md). Comfort is the only tab that edits (per device, no tier).
signal closed

const TABS := ["Home", "Trade", "Industry", "Holdings", "Comfort"]
## Section -> tab (SwipePages allows 5 tabs).
const SECTION := {"Overview": "Home", "Orgs": "Home", "Market": "Trade", "Contracts": "Trade", "Industry": "Industry",
	"Land": "Holdings", "Ships": "Holdings", "Comfort": "Comfort"}
var pages: SwipePages
var boxes := {}   # tab -> VBox
var sec := {}     # section -> VBox (the tab it lives in)

static func open(parent: Node) -> FrontierScreen:
	var existing := parent.get_node_or_null("FrontierScreen")
	if existing: return existing
	var s := FrontierScreen.new(); s.name = "FrontierScreen"
	parent.add_child(s)
	return s

func _px(kind := "body") -> int: return int(PhoenixTokens.TYPE[kind])

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
	var title := Label.new(); title.text = "Frontier"; title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var x := Button.new(); x.text = "✕"; x.name = "Close"; x.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN, PhoenixTokens.TAP_MIN)
	x.add_theme_font_size_override("font_size", _px("headline"))
	x.pressed.connect(func(): closed.emit(); queue_free()); head.add_child(x)
	v.add_child(head)
	pages = SwipePages.new(); pages.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(pages)
	for t in TABS:
		var sc := ScrollContainer.new(); sc.name = t
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var b := VBoxContainer.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_constant_override("separation", PhoenixTokens.SPACE[3])
		sc.add_child(b); pages.add_page(t, sc); boxes[t] = b
	for k in SECTION: sec[k] = boxes[SECTION[k]]
	pages.page_changed.connect(func(_i): refresh())
	refresh()

func _text(t: String, col := PhoenixTokens.PLATINUM, kind := "body") -> Label:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", _px(kind)); l.add_theme_color_override("font_color", col)
	return l

func _btn(t: String, f: Callable) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN * 2, PhoenixTokens.TAP_MIN)
	b.add_theme_font_size_override("font_size", _px("body")); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(f)
	return b

func _card(box: Node, t: String, lines: Array, note := "") -> GlassCard:
	var c := ViperKit.card(t)
	var body: Node = c.body()
	for line in lines: body.add_child(_text(str(line)))
	if note != "": body.add_child(_text(note, PhoenixTokens.WARN, "label"))
	box.add_child(c)
	return c

func _clear(b: Node) -> void:
	for c in b.get_children(): b.remove_child(c); c.queue_free()

func _me() -> String: return Tiers.actor_id("self")

func refresh() -> void:
	for t in TABS: _clear(boxes[t])
	var tier := Tiers.label(Tiers.tier_of("self"))
	# Overview
	var o: Node = sec["Overview"]
	o.add_child(_text("Space-sim systems for Viper OS. Concepts only: our own code, names and art.", PhoenixTokens.PLATINUM_DIM, "label"))
	var sh := ShardModel.stats()
	_card(o, "Universe", ["%d system · %d planets (%d built)" % [sh["systems"], sh["planets"], sh["built_planets"]], "%d shard · %d server (standalone on this phone)" % [sh["shards"], sh["servers"]]])
	_card(o, "Your tier", [tier, "Trade, contracts, industry, ships: Resident+", "Land claims: Creator+ · Missions: Staff+"])
	var ms := OrderBook.stats(); var cs := ContractsBoard.stats(); var ins := Industry.stats(); var ts := Territory.stats(); var ss := ShipRegistry.stats()
	_card(o, "Activity", ["Market: %d open orders" % ms["open_orders"], "Contracts: %d open" % cs["outstanding"], "Industry: %d jobs running" % ins["running"],
		"Land: %d active claims" % ts["active"], "Ships: %d registered" % ss["ships"]], OrderBook.LEGAL)
	# Market
	var mk: Node = sec["Market"]
	_card(mk, "Order book", ["%d open orders · %d items · %d fills" % [ms["open_orders"], ms["items"], ms["fills"]], "Fees: %.1f%% broker, %.1f%% sales tax (burned)" % [OrderBook.BROKER_BPS / 100.0, OrderBook.SALES_TAX_BPS / 100.0], "Settlement: " + str(ms["settlement"])], OrderBook.LEGAL)
	var fills := OrderBook.history("", 8)
	_card(mk, "Recent trades", fills.map(func(f): return "%s ×%d @ %d %s" % [f["item"], f["qty"], f["price"], f["currency"]]) if not fills.is_empty() else ["No trades yet."])
	# Contracts
	var cb: Node = sec["Contracts"]
	var open := ContractsBoard.board("self", "", 8)
	_card(cb, "Board", open.map(func(c): return "%s · %s · %d AEC" % [c["kind"].replace("_", " ").capitalize(), c["title"], c["reward"]]) if not open.is_empty() else ["No open contracts."], "Rewards are numbers only until legal review.")
	_card(cb, "Yours", ["%d in progress · %d completed" % [cs["in_progress"], cs["completed"]]])
	# Industry
	var ib: Node = sec["Industry"]
	var rl: Array = []
	for id in Industry.recipes():
		var r: Dictionary = Industry.recipes()[id]
		rl.append("T%d %s%s" % [int(r["tier"]), r["name"], " (blueprint)" if r.get("needs_blueprint", false) else ""])
	_card(ib, "Recipes", rl)
	var js := Industry.jobs(_me(), true)
	_card(ib, "Your jobs (%d / %d slots)" % [js.size(), Industry.slots_for("self")], js.map(func(j): return "%s %s ×%d" % [j["kind"].replace("_", " "), j["recipe"], j["runs"]]) if not js.is_empty() else ["No jobs running."])
	ib.add_child(_btn("Collect finished jobs", _collect))
	# Orgs
	var ob: Node = sec["Orgs"]
	var gs := Social.groups_of(_me())
	_card(ob, "Your organisations", gs.map(func(g): return "%s · %s · %d rights" % [g["name"], g["role"], OrgRights.rights_of(g["id"], _me()).size()]) if not gs.is_empty() else ["Not in an organisation. Groups are organisations: create one in Community."])
	var os := OrgRights.summary()
	_card(ob, "Totals", ["%d organisations · %d titles · %d policies · %d alliances" % [os["orgs"], os["titles"], os["policies"], os["alliances"]]])
	# Land
	var lb: Node = sec["Land"]
	_card(lb, "Claims", ["%d active · %d in grace · %d contested" % [ts["active"], ts["grace"], ts["contested"]], "Upkeep every %d days, %d days grace" % [Territory.UPKEEP_DAYS, Territory.GRACE_DAYS]], "Coin upkeep is off until legal review.")
	var mine := Territory.claims_by(_me())
	_card(lb, "Yours", mine.map(func(c): return "%s/%s · %s" % [c["region"], c["parcel"], c["state"]]) if not mine.is_empty() else ["No claims."])
	# Ships
	var sb: Node = sec["Ships"]
	var fl := ShipRegistry.fleet(_me())
	_card(sb, "Your fleet", fl.map(func(s): return "%s · %s · %s · %s" % [s["name"], s["size"], s["state"], s["insurance"]]) if not fl.is_empty() else ["No ships registered."])
	var plans: Array = []
	for p in ShipRegistry.INSURANCE: plans.append("%s · %s+" % [ShipRegistry.INSURANCE[p]["label"], Tiers.label(ShipRegistry.INSURANCE[p]["min_tier"])])
	_card(sb, "Insurance plans", plans, "Claims replace the hull. No coin premiums or payouts until legal review.")
	# Comfort
	_build_comfort(sec["Comfort"])

func _collect() -> void:
	var r := Industry.collect("self")
	Toast.show_toast(self, "%d delivered" % r.get("delivered", []).size(), "ok")
	refresh()

func _build_comfort(cf: Node) -> void:
	var p := ComfortPrefs.all()
	var fov := HBoxContainer.new(); fov.add_theme_constant_override("separation", PhoenixTokens.SPACE[2])
	var fl := _text("Field of view: %d°" % int(p["fov"])); fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; fov.add_child(fl)
	for d in [-5, 5]:
		var b := Button.new(); b.text = ("−" if d < 0 else "+"); b.custom_minimum_size = Vector2(PhoenixTokens.TAP_MIN, PhoenixTokens.TAP_MIN)
		b.add_theme_font_size_override("font_size", _px("headline"))
		b.pressed.connect(func(): ComfortPrefs.set_pref("fov", int(ComfortPrefs.get_pref("fov")) + d); refresh())
		fov.add_child(b)
	cf.add_child(fov)
	for k in ["vignette_on_turn", "snap_turn", "horizon_lock", "camera_shake", "head_bob", "motion_blur", "invert_look_y"]:
		var c := CheckButton.new(); c.name = k; c.text = k.replace("_", " ").capitalize(); c.button_pressed = bool(p[k])
		c.custom_minimum_size = Vector2(0, PhoenixTokens.TAP_MIN); c.add_theme_font_size_override("font_size", _px("body"))
		c.toggled.connect(func(on): ComfortPrefs.set_pref(k, on))
		cf.add_child(c)
	cf.add_child(_text("Controls: " + str(p["profile"]).replace("_", " "), PhoenixTokens.PLATINUM_DIM, "label"))
	for prof in ["touch_default", "touch_left_handed", "touch_one_thumb"]:
		cf.add_child(_btn(prof.replace("touch_", "").replace("_", " ").capitalize() + (" ✓" if prof == p["profile"] else ""), func(): ComfortPrefs.set_pref("profile", prof); refresh()))
	cf.add_child(_btn("Calm preset (easy on eyes and stomach)", func(): ComfortPrefs.calm_preset(); refresh()))
	cf.add_child(_btn("Reset comfort", func(): ComfortPrefs.reset(); refresh()))

func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children(): _walk(c, out)

func min_font_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if (n is Label or n is Button) and n.is_visible_in_tree() and (n as Control).get_theme_font_size("font_size") < px: return false
	return true

func min_tap_ok(px: int) -> bool:
	var all: Array = []; _walk(self, all)
	for n in all:
		if n is BaseButton and n.custom_minimum_size.y < px and not n.get_parent() is TabBar: return false
	return true
