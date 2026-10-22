extends Node
## AutoConfig (autoload): maps DeviceProfile.caps() to defaults and applies them, never over a manual choice.
## Docs: docs/modules/DEVICE_COMPAT.md (mapping + override rules), docs/modules/POWER_AND_DATA.md (PowerData).
##  derive(caps, prefs, background) is PURE: every table below is tested with fake caps.
##  apply() performs the side effects: AutoQuality recommendation (Foxy, has_method-guarded), UI scale,
##  input scheme + InputMap profile, feature toggles, performance budgets, PowerData mode, Net data mode,
##  Dormancy background pause.
## Consumers read budget(key) / feature_on(id) and re-read on budgets_changed / applied. Never poll.
## Headless (CI, tests): derives the plan but applies nothing, so test runs never touch settings.
signal applied(plan: Dictionary)
signal budgets_changed(budgets: Dictionary)
signal power_changed(mode: String, reasons: Array)
signal input_scheme_changed(scheme: String)

const PREF_SECTION := "compat"
## User preferences (Settings > Device & compatibility). "auto" = follow the device.
const PREFS := {"tier": "auto", "ui_scale": "auto", "input_scheme": "auto", "perf_profile": "auto", "data_saver": "auto"}
const TIER_NAMES := ["auto", "low", "med", "high", "ultra"]
const SCHEMES := ["touch", "gamepad", "kbm", "xr"]
const PERF_PROFILES := ["battery_saver", "balanced", "performance"]
const DATA_SAVER := ["auto", "on", "off"]
const POWER_MODES := ["full", "balanced-saver", "saver", "background"]   # PowerData; default balanced-saver

# ---------- mapping tables (DEVICE_COMPAT.md §4) ----------
## UI scale (text = icon) by form factor. Phones stay compact (1.0, the smallest usable size).
const UI_SCALE := {"phone": 1.0, "tablet": 1.15, "desktop": 1.25, "tv": 1.6}
## Legacy Settings graphics quality (0 Low, 1 Med, 2 High) by class, used until AutoQuality lands.
const LEGACY_QUALITY := {"low": 0, "mid": 1, "high": 2, "ultra": 2}
## Balanced budgets by capability class [low, mid, high, ultra].
const BASE_BUDGETS := {
	"companion_ai_hz": [6, 10, 15, 20],
	"sim_tick_hz": [1, 2, 4, 4],          # survival / disease / needs / living-world sims
	"script_budget_ms": [1, 2, 3, 4],     # script VM time per frame
	"streaming_threads": [1, 2, 3, 4],
	"sync_send_hz": [5, 10, 15, 20],      # network state sends per second (batched, delta)
	"view_distance_hint": [256, 512, 768, 1024],
	"particle_budget": [200, 600, 1500, 3000],
}
## Multiplier per performance profile (results rounded, min 1).
const PROFILE_MULT := {"battery_saver": 0.5, "balanced": 1.0, "performance": 1.5}
## PowerData triggers.
const BATTERY_LOW_PCT := 30
const THERMAL_STEP_DOWN := 3      # Android THERMAL_STATUS_SEVERE
const KEEPALIVE_S := 60

var store: ConfigFile = null      # tests: in-memory settings; null = the Settings autoload
var background := false
var last_plan: Dictionary = {}
var last_caps: Dictionary = {}
var ui_scale_provider: Callable   # used when DisplaySettings (phone branch) is not on main
var apply_count := 0

func _ready() -> void:
	var dp := get_node_or_null("/root/DeviceProfile")
	if dp: dp.caps_changed.connect(func(_c): apply())
	apply()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED: set_background(true)
		NOTIFICATION_APPLICATION_RESUMED: set_background(false)

func set_background(on: bool) -> void:
	if on == background: return
	background = on
	Dormancy.set_background(on, Time.get_ticks_msec() / 1000.0)
	apply()

# ---------- prefs (user choices win) ----------
func _pget(sec: String, key: String, def: Variant) -> Variant:
	if store: return store.get_value(sec, key, def)
	var s := get_node_or_null("/root/Settings")
	return s.get_value(sec, key, def) if s else def

func _set_v(sec: String, key: String, v: Variant) -> void:
	if store: store.set_value(sec, key, v); return
	var s := get_node_or_null("/root/Settings")
	if s: s.set_value(sec, key, v)

func _has(sec: String, key: String) -> bool:
	if store: return store.has_section_key(sec, key)
	var s := get_node_or_null("/root/Settings")
	return s != null and s.cfg.has_section_key(sec, key)

func prefs() -> Dictionary:
	var p := {}
	for k in PREFS: p[k] = _pget(PREF_SECTION, k, PREFS[k])
	return p

## Manual choice from the Settings UI. "auto" hands the key back to the device.
func choose(key: String, value: Variant) -> void:
	if not PREFS.has(key): return
	_set_v(PREF_SECTION, key, value)
	apply()

func reset_to_auto() -> void:
	for k in PREFS: _set_v(PREF_SECTION, k, "auto")
	for ext in ["graphics/quality", "display/text_scale", "display/icon_scale"]:
		_set_v(PREF_SECTION, "auto_" + ext.replace("/", "_"), null)
	var aq := get_node_or_null("/root/AutoQuality")
	if aq and aq.has_method("set_tier"): aq.set_tier("auto")
	var dp := get_node_or_null("/root/DeviceProfile")
	if dp and dp.has_method("redetect"): dp.redetect()   # emits caps_changed -> apply()
	else: apply()

## Settings owned by other systems: we write only while the value is still the one we wrote last time
## (or the untouched default). A different value means the user changed it: kept forever, until Reset.
func is_overridden(sec: String, key: String, default: Variant) -> bool:
	var rec := "auto_%s_%s" % [sec, key]
	if not _has(sec, key): return false
	var cur: Variant = _pget(sec, key, default)
	if _has(PREF_SECTION, rec) and _pget(PREF_SECTION, rec, null) != null: return cur != _pget(PREF_SECTION, rec, null)
	return cur != default

func _auto_write(sec: String, key: String, default: Variant, v: Variant) -> bool:
	if is_overridden(sec, key, default): return false
	_set_v(sec, key, v)
	_set_v(PREF_SECTION, "auto_%s_%s" % [sec, key], v)
	return true

# ---------- pure derivation ----------
static func class_index(cls: String) -> int: return maxi(DeviceCaps.CLASSES.find(cls), 0)

static func input_scheme_of(c: Dictionary) -> String:
	if bool(c.get("xr", false)): return "xr"
	if int(c.get("gamepads", 0)) > 0 or str(c.get("form_factor", "")) == "tv": return "gamepad"
	if str(c.get("form_factor", "")) == "desktop" and not bool(c.get("touch", false)): return "kbm"
	if bool(c.get("keyboard", false)) and bool(c.get("mouse", false)) and str(c.get("form_factor", "")) == "desktop": return "kbm"
	return "touch"

## PowerData policy: {mode, reasons[]}. Default balanced-saver.
static func power_of(c: Dictionary, bg: bool) -> Dictionary:
	if bg: return {"mode": "background", "reasons": ["App in the background: sims, scripts and streaming paused"]}
	var r: Array = []
	var bat := int(c.get("battery_pct", -1))
	var charging := int(c.get("charging", -1)) == 1
	if bat >= 0 and bat < BATTERY_LOW_PCT and not charging: r.append("Battery %d%% (below %d%%)" % [bat, BATTERY_LOW_PCT])
	if int(c.get("power_save", -1)) == 1: r.append("Phone power saver is on")
	if int(c.get("thermal", -1)) >= THERMAL_STEP_DOWN: r.append("Phone is hot (thermal level %d)" % int(c["thermal"]))
	if str(c.get("network", "")) == "cell": r.append("On mobile data")
	if not r.is_empty(): return {"mode": "saver", "reasons": r}
	if charging and str(c.get("network", "")) == "wifi": return {"mode": "full", "reasons": ["Charging on Wi-Fi: full quality and prefetch"]}
	return {"mode": "balanced-saver", "reasons": ["Default: smooth, light on battery and data"]}

static func perf_profile_of(c: Dictionary, power_mode: String) -> String:
	match power_mode:
		"saver", "background": return "battery_saver"
		"full": return "performance" if class_index(str(c.get("capability_class", "mid"))) >= 2 else "balanced"
	if str(c.get("form_factor", "")) in ["desktop", "tv"] and class_index(str(c.get("capability_class", "mid"))) >= 2: return "performance"
	return "balanced"

static func data_mode_of(c: Dictionary, power_mode: String, pref: String) -> String:
	if pref == "on": return "saver"
	if pref == "off": return "full" if power_mode == "full" else "normal"
	if str(c.get("network", "")) == "cell" or power_mode == "saver": return "saver"
	return "full" if power_mode == "full" else "normal"

static func budgets_of(c: Dictionary, profile: String, power_mode: String, data_mode: String) -> Dictionary:
	var ci := class_index(str(c.get("capability_class", "mid")))
	var m: float = PROFILE_MULT.get(profile, 1.0)
	var b := {}
	for k in BASE_BUDGETS: b[k] = maxi(1, int(round(BASE_BUDGETS[k][ci] * m)))
	b["streaming_threads"] = mini(b["streaming_threads"], maxi(1, int(c.get("cpu_cores", 4)) - 1)) if int(c.get("cpu_cores", -1)) > 0 else b["streaming_threads"]
	var hz := float(c.get("refresh_hz", 60.0))
	b["fps_cap_hint"] = 30 if profile == "battery_saver" else (int(clampf(hz if hz > 0 else 60.0, 60.0, 120.0)) if profile == "performance" else (30 if ci == 0 else 60))
	b["media_audio_kbps"] = int(Net.MEDIA_KBPS[data_mode]["audio"])
	b["media_video_kbps"] = int(Net.MEDIA_KBPS[data_mode]["video"])
	b["image_px"] = int(Net.IMAGE_PX[data_mode]["image"])
	b["thumb_px"] = int(Net.IMAGE_PX[data_mode]["thumb"])
	b["autoplay"] = data_mode != "saver"
	b["thumbnails_only"] = data_mode == "saver"
	b["prefetch"] = power_mode == "full"
	b["defer_large_downloads"] = data_mode == "saver"
	b["keepalive_s"] = 0
	if power_mode == "background":
		for k in ["companion_ai_hz", "sim_tick_hz", "script_budget_ms", "streaming_threads", "sync_send_hz", "particle_budget"]: b[k] = 0
		b["fps_cap_hint"] = 1; b["autoplay"] = false; b["prefetch"] = false; b["keepalive_s"] = KEEPALIVE_S
	return b

## The whole plan for these caps + prefs. Pure.
static func derive(caps: Dictionary, p: Dictionary = {}, bg := false) -> Dictionary:
	var c := DeviceCaps.normalize(caps)
	var pr := PREFS.duplicate(); pr.merge(p, true)
	var cls := str(c["capability_class"])
	var pw := power_of(c, bg)
	var auto_profile := perf_profile_of(c, pw["mode"])
	var profile: String = auto_profile if str(pr["perf_profile"]) == "auto" or bg else str(pr["perf_profile"])
	var data_mode := data_mode_of(c, pw["mode"], str(pr["data_saver"]))
	var scheme := input_scheme_of(c) if str(pr["input_scheme"]) == "auto" else str(pr["input_scheme"])
	var scale: float = UI_SCALE.get(str(c["form_factor"]), 1.0) if str(pr["ui_scale"]) == "auto" else float(pr["ui_scale"])
	var tier: String = DeviceCaps.TIERS.get(cls, "med") if str(pr["tier"]) == "auto" else str(pr["tier"])
	return {
		"schema": c["schema"], "newer_schema": DeviceCaps.is_newer(caps),
		"capability_class": cls, "form_factor": c["form_factor"],
		"tier": tier, "tier_manual": str(pr["tier"]) != "auto",
		"legacy_quality": LEGACY_QUALITY.get(cls, 1),
		"ui_scale": scale, "ui_scale_manual": str(pr["ui_scale"]) != "auto",
		"input_scheme": scheme, "input_manual": str(pr["input_scheme"]) != "auto",
		"perf_profile": profile, "perf_manual": str(pr["perf_profile"]) != "auto",
		"power_mode": pw["mode"], "power_reasons": pw["reasons"],
		"data_mode": data_mode, "data_saver": str(pr["data_saver"]),
		"budgets": budgets_of(c, profile, pw["mode"], data_mode),
		"features": FeatureRegistry.evaluate(c),
		"input_profile": input_profile(scheme),
	}

## Input action remaps as DATA (Foxy's HUD consumes them). Events are descriptors, not live objects.
static func input_profile(scheme: String) -> Dictionary:
	match scheme:
		"gamepad": return {"move": "left_stick", "look": "right_stick", "jump": "button_a", "interact": "button_x", "menu": "button_start", "radial": "button_y", "fly": "button_b", "hud": "gamepad"}
		"kbm": return {"move": "wasd", "look": "mouse", "jump": "space", "interact": "e", "menu": "escape", "radial": "tab", "fly": "f", "hud": "desktop"}
		"xr": return {"move": "left_thumbstick", "look": "head", "jump": "right_a", "interact": "trigger", "menu": "menu", "radial": "grip", "fly": "right_b", "hud": "xr"}
	return {"move": "left_pad", "look": "drag", "jump": "jump_button", "interact": "tap", "menu": "menu_button", "radial": "long_press", "fly": "fly_button", "hud": "touch"}

## Gamepad events added to the existing InputMap actions (additive, idempotent; keyboard binds kept).
const PAD_EVENTS := {"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0], "move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "jump": JOY_BUTTON_A}
static func add_gamepad_events() -> int:
	var added := 0
	for a in PAD_EVENTS:
		if not InputMap.has_action(a): continue
		var ev: InputEvent
		if PAD_EVENTS[a] is Array:
			var m := InputEventJoypadMotion.new(); m.axis = PAD_EVENTS[a][0]; m.axis_value = PAD_EVENTS[a][1]; ev = m
		else:
			var bt := InputEventJoypadButton.new(); bt.button_index = PAD_EVENTS[a]; ev = bt
		if not InputMap.action_has_event(a, ev): InputMap.action_add_event(a, ev); added += 1
	return added

# ---------- apply ----------
func current_caps() -> Dictionary:
	var dp := get_node_or_null("/root/DeviceProfile")
	return DeviceCaps.normalize(dp.caps() if dp and dp.has_method("caps") else {})

## force=true applies even headless (tests with an in-memory store).
func apply(force := false) -> Dictionary:
	apply_count += 1
	last_caps = current_caps()
	var before := last_plan
	var plan := derive(last_caps, prefs(), background)
	plan["applied"] = []; plan["kept"] = []
	last_plan = plan
	if DisplayServer.get_name() == "headless" and not force:
		plan["dry_run"] = true
		return plan
	Net.set_data_mode(plan["data_mode"]); plan["applied"].append("data_mode")
	_apply_quality(plan)
	_apply_ui_scale(plan)
	if plan["input_scheme"] == "gamepad" and add_gamepad_events() > 0: plan["applied"].append("gamepad_events")
	if before.get("input_scheme", "") != plan["input_scheme"]: input_scheme_changed.emit(plan["input_scheme"])
	if before.get("budgets", {}) != plan["budgets"]: budgets_changed.emit(plan["budgets"])
	if before.get("power_mode", "") != plan["power_mode"]: power_changed.emit(plan["power_mode"], plan["power_reasons"])
	applied.emit(plan)
	return plan

func _apply_quality(plan: Dictionary) -> void:
	var aq := get_node_or_null("/root/AutoQuality")
	if aq:
		if aq.has_method("set_power_profile"): aq.set_power_profile(plan["perf_profile"])
		if aq.has_method("set_fps_cap_hint"): aq.set_fps_cap_hint(int(plan["budgets"]["fps_cap_hint"]))
		var manual_aq: bool = aq.has_method("get_mode") and str(aq.get_mode()) != "auto"
		if plan["tier_manual"] and aq.has_method("set_tier"): aq.set_tier(plan["tier"]); plan["applied"].append("tier")
		elif manual_aq: plan["kept"].append("tier")
		elif aq.has_method("recommend_tier"): aq.recommend_tier(plan["tier"]); plan["applied"].append("tier")
		return
	# Until Foxy's AutoQuality is on main: the legacy 3-level Settings quality, override-respecting.
	# INACTIVE once AutoQuality exists (the branch above returns first).
	if _auto_write("graphics", "quality", 1, plan["legacy_quality"]):
		plan["applied"].append("legacy_quality")
		var s := get_node_or_null("/root/Settings")
		if s and not store: s.quality_changed.emit(int(plan["legacy_quality"]))
	else: plan["kept"].append("legacy_quality")

const DISPLAY_SETTINGS := "res://scripts/ui/display_settings.gd"
func _apply_ui_scale(plan: Dictionary) -> void:
	var v: float = plan["ui_scale"]
	if ResourceLoader.exists(DISPLAY_SETTINGS):   # phone branch: PhoenixTokens scale through DisplaySettings
		var a := _auto_write("display", "text_scale", 1.0, v)
		var b := _auto_write("display", "icon_scale", 1.0, v)
		if a or b:
			plan["applied"].append("ui_scale")
			var ds: Script = load(DISPLAY_SETTINGS)
			if not store and ds.has_method("apply"): ds.call("apply")
		else: plan["kept"].append("ui_scale")
	elif ui_scale_provider.is_valid():
		ui_scale_provider.call(v); plan["applied"].append("ui_scale")

# ---------- reads for systems ----------
func budget(key: String, fallback: Variant = 0) -> Variant:
	if last_plan.is_empty(): apply()
	return last_plan.get("budgets", {}).get(key, fallback)

func feature_on(id: String) -> bool:
	if last_plan.is_empty(): apply()
	return bool(last_plan.get("features", {}).get(id, {}).get("on", true))

func feature_reason(id: String) -> String:
	return str(last_plan.get("features", {}).get(id, {}).get("reason", ""))

## Battery & data summary for Settings: {mode, why, data_mb, data_saver}.
func power_summary() -> Dictionary:
	if last_plan.is_empty(): apply()
	var names := {"full": "Full quality", "balanced-saver": "Balanced saver", "saver": "Saver", "background": "Paused (background)"}
	return {"mode": names.get(last_plan["power_mode"], last_plan["power_mode"]), "why": ", ".join(last_plan["power_reasons"]),
		"data_mb": Net.session_mb(), "data_saver": last_plan["data_saver"], "data_mode": last_plan["data_mode"]}
