class_name PinPad
extends VBoxContainer
## Accessible owner PIN screen: huge keypad (3x4, 128 px keys, 60 px digits), pure black / white
## high-contrast, 4 px gold focus rims, big masked dots, big error text, and an "ABC" switch to a
## large text field for passphrases or the old owner code ("phoenix-..."). No tiny targets anywhere.
## Modes: "unlock" (PIN, passphrase or old code; the old code then offers set-PIN), "setup"
## (new + confirm, then migrates saves), "change" (current -> new -> confirm).
signal finished(ok: bool)

const HC_BG := Color(0, 0, 0)
const HC_FG := Color(1, 1, 1)
const KEY_PX := 128
const DIGIT_FONT := 60
const TEXT_FONT := 40

var mode := "unlock"
var stage := 0          # setup: 0 new, 1 confirm / change: 0 current, 1 new, 2 confirm
var entry := ""
var _first := ""
var _old := ""
var text_mode := false
var prompt: Label
var dots: Label
var error: Label
var field: LineEdit
var keypad: GridContainer
var last_report := {}

func _init(p_mode := "unlock") -> void:
	mode = p_mode
	if mode == "unlock" and not OwnerVault.has_vault() and Profile.first_run_allowed(): mode = "first_run"   # SEC-FIX-5
	add_theme_constant_override("separation", 20)
	text_mode = mode == "unlock" and not OwnerVault.has_vault()   # the old code has letters
	prompt = _label("", 44); add_child(prompt)
	dots = _label("", 72); dots.custom_minimum_size.y = 96; add_child(dots)
	field = LineEdit.new(); field.secret = true; field.custom_minimum_size = Vector2(0, 104)
	field.add_theme_font_size_override("font_size", TEXT_FONT)
	field.add_theme_color_override("font_color", HC_FG)
	field.add_theme_stylebox_override("normal", _box(Color(0.08, 0.08, 0.08), HC_FG, 3))
	field.add_theme_stylebox_override("focus", _box(Color(0.08, 0.08, 0.08), PhoenixTokens.GOLD, 5))
	field.text_submitted.connect(func(_t): submit())
	add_child(field)
	keypad = GridContainer.new(); keypad.columns = 3
	keypad.add_theme_constant_override("h_separation", 18); keypad.add_theme_constant_override("v_separation", 18)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]: keypad.add_child(_key(k))
	var kc := CenterContainer.new(); kc.add_child(keypad); add_child(kc)
	error = _label("", 34); error.add_theme_color_override("font_color", Color("#ffd166")); add_child(error)
	var sw := _key("ABC" if not text_mode else "123"); sw.custom_minimum_size = Vector2(0, 96); sw.name = "Switch"
	sw.pressed.connect(func(): set_text_mode(not text_mode); sw.text = "123" if text_mode else "ABC")
	add_child(sw)
	if mode == "unlock" and BiometricHook.available():
		var bio := _key("Use fingerprint"); bio.custom_minimum_size = Vector2(0, 96)
		bio.pressed.connect(func(): BiometricHook.request(func(ok, why): if not ok: error.text = why))
		add_child(bio)
	set_text_mode(text_mode)
	_update_prompt()

func _label(t: String, px: int) -> Label:
	var l := Label.new(); l.text = t; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px); l.add_theme_color_override("font_color", HC_FG)
	return l

static func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(bw)
	s.set_corner_radius_all(KEY_PX / 2); s.set_content_margin_all(12); s.anti_aliasing = true
	return s

func _key(k: String) -> Button:
	var b := Button.new(); b.text = k; b.custom_minimum_size = Vector2(KEY_PX + 32, KEY_PX)
	b.add_theme_font_size_override("font_size", DIGIT_FONT if k.length() <= 2 else TEXT_FONT)
	for st in ["normal", "hover"]: b.add_theme_stylebox_override(st, _box(Color(0.06, 0.06, 0.06), HC_FG, 3))
	b.add_theme_stylebox_override("pressed", _box(HC_FG, HC_FG, 3))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), PhoenixTokens.GOLD, 6))
	for c in ["font_color", "font_hover_color", "font_focus_color"]: b.add_theme_color_override(c, HC_FG)
	b.add_theme_color_override("font_pressed_color", HC_BG)
	if k.length() <= 3 and k != "ABC" and k != "123": b.pressed.connect(func(): press(k))
	return b

func set_text_mode(on: bool) -> void:
	text_mode = on
	field.visible = on; keypad.get_parent().visible = not on; dots.visible = not on
	if on and field.is_inside_tree(): field.grab_focus()

func press(k: String) -> void:
	error.text = ""
	if k == "⌫": entry = entry.left(entry.length() - 1)
	elif k == "OK": submit(); return
	elif entry.length() < 32: entry += k
	dots.text = "●".repeat(entry.length()) if entry != "" else "—"

func _value() -> String: return field.text if text_mode else entry

func _clear() -> void:
	entry = ""; field.text = ""; dots.text = "—"

func _update_prompt() -> void:
	match mode:
		"unlock": prompt.text = "Enter owner PIN" if OwnerVault.has_vault() else "Enter your owner code"
		"first_run": prompt.text = ["Create owner PIN or passphrase (6+ digits or 8+ characters)", "Type it again to confirm"][stage]
		"setup": prompt.text = ["Choose a new PIN (6+ digits)", "Type the same PIN again"][stage]
		"change": prompt.text = ["Current PIN", "New PIN (6+ digits)", "New PIN again"][stage]
	dots.text = "—"

func submit() -> void:
	var v := _value().strip_edges()
	_clear()
	match mode:
		"unlock":
			if Profile.try_owner_unlock(v):
				if OwnerVault.needs_pin_setup():
					mode = "setup"; stage = 0; set_text_mode(false)
					error.text = "Owner code accepted. Now set a PIN."
					_update_prompt()
					return
				finished.emit(true)
			else:
				var w := OwnerVault.retry_in_s()
				error.text = ("Too many tries. Wait %d seconds." % w) if w > 0 else "Not right. Try again."
		"first_run":
			if stage == 0:
				var ef := OwnerVault.validate_secret(v)
				if ef != "": error.text = ef; return
				_first = v; stage = 1; _update_prompt()
			else:
				if v != _first: error.text = "They did not match. Start again."; stage = 0; _first = ""; _update_prompt(); return
				var e0 := Profile.first_run_setup(_first)
				_first = ""
				if e0 != "": error.text = e0; stage = 0; _update_prompt(); return
				last_report = SaveMigration.migrate()
				error.text = "Owner PIN created. %d saves encrypted." % last_report.get("migrated", []).size()
				finished.emit(true)
		"setup":
			if stage == 0:
				var e := OwnerVault.validate_secret(v)
				if e != "": error.text = e; return
				_first = v; stage = 1; _update_prompt()
			else:
				if v != _first: error.text = "PINs did not match. Start again."; stage = 0; _update_prompt(); return
				var e2 := OwnerVault.setup(_first)
				if e2 != "": error.text = e2; return
				last_report = SaveMigration.migrate()
				error.text = "PIN set. %d saves encrypted." % last_report.get("migrated", []).size()
				finished.emit(true)
		"change":
			if stage == 0: _old = v; stage = 1; _update_prompt()
			elif stage == 1:
				var e3 := OwnerVault.validate_secret(v)
				if e3 != "": error.text = e3; return
				_first = v; stage = 2; _update_prompt()
			else:
				if v != _first: error.text = "PINs did not match."; stage = 1; _update_prompt(); return
				var e4 := OwnerVault.change_secret(_old, _first)
				if e4 != "": error.text = e4; stage = 0; _update_prompt(); return
				finished.emit(true)
