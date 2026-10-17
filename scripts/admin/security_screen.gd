class_name SecurityScreen
extends Control
## Viper OS Security panel (radial menu, 2 o'clock, shield): lock state, auto-lock time, PIN change,
## old-code retirement, e-stop, lattice audit-chain verify, encrypted backup export, biometric status.
## High-contrast type. Sizes come from PhoenixTokens (Settings > Display): compact by default, one tap to Large.
signal closed

var body: VBoxContainer
var overlay: Control
var last_backup := ""
var last_verify := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ViperKit.theme()
	var bg := ColorRect.new(); bg.color = Color(0, 0, 0); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "bottom"]: m.add_theme_constant_override("margin_" + s, 24)
	m.add_theme_constant_override("margin_top", 32)
	add_child(m)
	DisplaySettings.attach_responsive(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", PhoenixTokens.space(4)); m.add_child(v)
	var head := HBoxContainer.new()
	var t := Label.new(); t.text = "Security"; t.theme_type_variation = &"TitleLabel"; t.add_theme_font_size_override("font_size", PhoenixTokens.fs("title"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	var x := Button.new(); x.text = "✕"; x.custom_minimum_size = Vector2(PhoenixTokens.tap(), PhoenixTokens.tap()); x.add_theme_font_size_override("font_size", PhoenixTokens.fs("headline"))
	x.pressed.connect(func(): closed.emit(); queue_free()); head.add_child(x)
	v.add_child(head)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18); sc.add_child(body)
	var tm := Timer.new(); tm.wait_time = 5.0; tm.autostart = true; add_child(tm)
	tm.timeout.connect(func(): if overlay == null: refresh())
	refresh()

func _text(t: String, px := -1, col := Color(1, 1, 1)) -> Label:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px if px > 0 else PhoenixTokens.fs("body")); l.add_theme_color_override("font_color", col)
	return l

func _big(t: String, f: Callable, h := -1) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(0, h if h > 0 else PhoenixTokens.tap())
	b.add_theme_font_size_override("font_size", PhoenixTokens.fs("headline")); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(f)
	return b

func _hold(t: String, f: Callable) -> HoldButton:
	var b := HoldButton.new(); b.text = t; b.custom_minimum_size = Vector2(0, PhoenixTokens.tap())
	b.add_theme_font_size_override("font_size", PhoenixTokens.fs("headline")); b.confirmed.connect(f)
	return b

func refresh() -> void:
	if body == null: return
	for c in body.get_children(): body.remove_child(c); c.queue_free()
	var owner := OwnerVault.is_unlocked()
	# --- lock state ---
	var lc := ViperKit.card("Lock"); body.add_child(lc)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 20); lc.body().add_child(row)
	var left := OwnerVault.seconds_left()
	var ring := ViperKit.ring(float(left) / maxf(1.0, OwnerVault.lock_minutes() * 60.0), "min left" if owner else "locked",
		("%d" % ceili(left / 60.0)) if owner else "—", 160)
	row.add_child(ring)
	var st := VBoxContainer.new(); st.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(st)
	st.add_child(_text(state_text(), PhoenixTokens.fs("headline")))
	st.add_child(_text("Saves: " + ("encrypted, open" if OwnerVault.storage_ready() else ("encrypted, sealed" if OwnerVault.has_vault() else "not encrypted yet")), -1, PhoenixTokens.PLATINUM_DIM))
	if owner:
		lc.body().add_child(_big("Lock now", func(): OwnerVault.lock(); refresh()))
		lc.body().add_child(_big("Lock & seal saves", func(): OwnerVault.lock_all(); refresh()))
	else:
		lc.body().add_child(_big("Unlock" if OwnerVault.has_vault() else "Enter owner code", func(): open_pad("unlock")))
	if OwnerVault.needs_pin_setup():
		lc.body().add_child(_big("Set a PIN now", func(): open_pad("setup")))
	# --- e-stop ---
	var ec := ViperKit.card("Emergency stop"); body.add_child(ec)
	var es := AutonomyGuard.state()
	ec.body().add_child(_text("Companions: " + ("PAUSED since %s" % es["since"] if es["paused"] else "running"), PhoenixTokens.fs("headline"), PhoenixTokens.ERR if es["paused"] else PhoenixTokens.OK))
	if not es["paused"]:
		var stop := _big("■  STOP ALL COMPANIONS", func(): AutonomyGuard.engage("security panel"); toast("Companions paused", "warn"); refresh(), 104)
		stop.name = "EStop"
		var sb := StyleBoxFlat.new(); sb.bg_color = Color("#7a0018"); sb.border_color = Color(1, 1, 1); sb.set_border_width_all(4); sb.set_corner_radius_all(52)
		stop.add_theme_stylebox_override("normal", sb); stop.add_theme_color_override("font_color", Color(1, 1, 1))
		ec.body().add_child(stop)
		ec.body().add_child(_text("Pauses free roam, self-learning, proposals and tools. Chat keeps working. Anyone can press it.", PhoenixTokens.fs("label"), PhoenixTokens.PLATINUM_DIM))
	elif owner:
		ec.body().add_child(_hold("Hold to resume companions", func(): AutonomyGuard.release(); toast("Companions resumed"); refresh()))
	else:
		ec.body().add_child(_text("Only the owner can resume. Unlock first.", PhoenixTokens.fs("label"), PhoenixTokens.PLATINUM_DIM))
	# --- audit ---
	var ac := ViperKit.card("Audit chain"); body.add_child(ac)
	last_verify = ViperAdminData.revisions().verify_chain()
	var arow := HBoxContainer.new(); arow.add_theme_constant_override("separation", 20); ac.body().add_child(arow)
	arow.add_child(ViperKit.ring(1.0 if last_verify["ok"] else 0.0, "verified" if last_verify["ok"] else "BROKEN", "✓" if last_verify["ok"] else "✗", 120))
	var at := _text(audit_text(last_verify)); at.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(at)
	ac.body().add_child(_big("Verify again", func(): refresh()))
	# --- owner-only settings ---
	var oc := ViperKit.card("Owner settings"); body.add_child(oc)
	if not owner:
		oc.body().add_child(_text("Unlock to change the PIN, auto-lock time or make a backup.", -1, PhoenixTokens.PLATINUM_DIM))
	else:
		oc.body().add_child(_text("Auto-lock after (minutes)"))
		var seg := SegmentedPills.new().setup([["5", "5"], ["15", "15"], ["30", "30"], ["60", "60"], ["120", "120"]], str(OwnerVault.lock_minutes()))
		for b in seg.get_children(): b.custom_minimum_size.y = PhoenixTokens.tap(); b.add_theme_font_size_override("font_size", PhoenixTokens.fs("headline"))
		seg.changed.connect(func(id): OwnerVault.set_lock_minutes(int(id)); toast("Auto-lock %s min" % id); refresh())
		oc.body().add_child(seg)
		if OwnerVault.has_vault(): oc.body().add_child(_big("Change PIN", func(): open_pad("change")))
		if OwnerVault.has_legacy_slot():
			oc.body().add_child(_hold("Hold to retire the old owner code", func(): OwnerVault.retire_legacy(); toast("Old code retired"); refresh()))
		if OwnerVault.storage_ready():
			oc.body().add_child(_big("Export encrypted backup", func(): export_backup()))
			if last_backup != "": oc.body().add_child(_text("Saved: " + ProjectSettings.globalize_path(last_backup), PhoenixTokens.fs("label"), PhoenixTokens.PLATINUM_DIM))
	oc.body().add_child(_text("Fingerprint unlock: " + ("available" if BiometricHook.available() else "not available yet (no plugin installed)"), PhoenixTokens.fs("label"), PhoenixTokens.PLATINUM_DIM))
	var dc := ViperKit.card("Display & device"); body.add_child(dc)
	dc.body().add_child(_big("Display & text size", func(): SettingsScreen.open_in(self, "Display")))
	dc.body().add_child(_big("Device check", func(): SettingsScreen.open_in(self, "Device")))

static func state_text() -> String:
	if OwnerVault.is_unlocked(): return "Owner unlocked · auto-lock in %d min" % ceili(OwnerVault.seconds_left() / 60.0)
	if not OwnerVault.has_vault(): return "No PIN set yet"
	return "Locked"

static func audit_text(v: Dictionary) -> String:
	if v.get("ok", false):
		return "%d revisions chained%s.\nHead %s…" % [v["count"] - v["legacy"], (" (+%d older, unchained)" % v["legacy"]) if v["legacy"] > 0 else "", str(v.get("head_hash", "")).left(12)]
	return "Chain broken at r%d: %s" % [v.get("broken_at", 0), v.get("reason", "")]

func export_backup() -> String:
	last_backup = SaveMigration.backup("export")
	toast("Backup saved" if last_backup != "" else "Backup failed", "ok" if last_backup != "" else "err")
	refresh()
	return last_backup

func toast(t: String, variant := "ok") -> void: Toast.show_toast(self, t, variant)

func open_pad(mode: String) -> PinPad:
	if overlay: overlay.queue_free()
	overlay = Control.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(overlay)
	var bg := ColorRect.new(); bg.color = Color(0, 0, 0); bg.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + s, 32)
	overlay.add_child(m)
	var v := VBoxContainer.new(); m.add_child(v)
	var pad := PinPad.new(mode); pad.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(pad)
	var cancel := _big("Cancel", func(): overlay.queue_free(); overlay = null; refresh()); v.add_child(cancel)
	pad.finished.connect(func(ok):
		if ok:
			toast("Done")
			overlay.queue_free(); overlay = null
			refresh())
	return pad
