class_name SocialBridge
extends RefCounted
## v0.14 BRIDGE-1: the bridge to the Scorpion Viper social app (Android package os.viper.scorpion).
## - "Open Social" (☰ menu): opens Scorpion Viper through the ViperDevice plugin (v2). With a link when we
##   have one (SOCIAL_URI, contract in docs/modules/V014_COMPANIONS.md); if the app is not installed, the
##   SkorpionViper releases page opens in the browser instead.
## - "Enter World" links INTO this app: phoenixvoxel://enter?realm=<grid id>&companion=<persona id>
##   (manifest activity-alias in the plugin). Every value is validated against the world picker and the
##   shipped court before we travel; unknown values are refused. A link can only travel, never unlock,
##   summon permanently or change anything.

const SOCIAL_PKG := "os.viper.scorpion"
const SOCIAL_URI := "scorpionviper://open?from=phoenixvoxel"
const FALLBACK_URL := "https://github.com/Anterrania/SkorpionViper/releases/latest"
const SCHEME := "phoenixvoxel"
const HOST := "enter"
const PLUGIN := "ViperDevice"
const MAX_LEN := 200

static var plugin_override: Object = null   # tests: fake plugin
static var open_url_override := Callable()  # tests: capture the browser fallback

static func _plugin() -> Object:
	if plugin_override != null: return plugin_override
	return Engine.get_singleton(PLUGIN) if Engine.has_singleton(PLUGIN) else null

static func _bridge_ok(p: Object) -> bool:
	return p != null and p.has_method("open_app") and p.has_method("get_plugin_version") and int(p.call("get_plugin_version")) >= 2

## Returns "app" (Scorpion Viper opened), "web" (release page) or "" (nothing could open).
static func open_social() -> String:
	var p := _plugin()
	if _bridge_ok(p) and bool(p.call("is_app_installed", SOCIAL_PKG)) and bool(p.call("open_app", SOCIAL_PKG, SOCIAL_URI)): return "app"
	if open_url_override.is_valid(): open_url_override.call(FALLBACK_URL); return "web"
	return "web" if OS.shell_open(FALLBACK_URL) == OK else ""

static func _ident(s: String) -> bool:
	if s == "" or s.length() > 40: return false
	for ch in s:
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"): return false
	return true

## Build the Enter World link the social app should use.
static func enter_link(realm: String, companion := "") -> String:
	var q := "realm=" + realm.uri_encode()
	if companion != "": q += "&companion=" + companion.uri_encode()
	return "%s://%s?%s" % [SCHEME, HOST, q]

## {ok, error, realm, companion}. realm defaults to the companion's home realm, else Heaven.
static func parse_enter(uri: String) -> Dictionary:
	var bad := func(e: String) -> Dictionary: return {"ok": false, "error": e, "realm": "", "companion": ""}
	var u := uri.strip_edges()
	if u.length() > MAX_LEN: return bad.call("Link too long.")
	var head := SCHEME + "://" + HOST
	if not u.to_lower().begins_with(head): return bad.call("Not an Enter World link.")
	var rest := u.substr(head.length())
	if rest.begins_with("/"): rest = rest.substr(1)
	if rest != "" and not rest.begins_with("?"): return bad.call("Not an Enter World link.")
	var realm := ""; var comp := ""
	for kv in rest.trim_prefix("?").split("&", false):
		var i := kv.find("=")
		if i < 0: continue
		var k := kv.left(i); var v := kv.substr(i + 1).uri_decode().strip_edges().to_lower()
		if k == "realm": realm = v
		elif k == "companion": comp = v
	if comp != "":
		if not _ident(comp) or CompanionCreator.is_custom(comp) or not FileAccess.file_exists("res://companions/%s/persona.json" % comp):
			return bad.call("Unknown companion.")
	if realm == "": realm = ("home_" + comp) if comp != "" and not WorldPicker.grid("home_" + comp).is_empty() else WorldPicker.default_id()
	if not _ident(realm) or WorldPicker.grid(realm).is_empty(): return bad.call("Unknown world.")
	return {"ok": true, "error": "", "realm": realm, "companion": comp}

## Travel for a validated link. "" or an error.
static func handle_enter(ui: Node, uri: String) -> String:
	var r := parse_enter(uri)
	if not r["ok"]: return str(r["error"])
	return WorldPicker.enter(ui, str(r["realm"]))

## On launch / resume: follow the link the app was opened with (once).
static func check_launch(ui: Node) -> String:
	var p := _plugin()
	if p == null or not p.has_method("get_launch_uri"): return ""
	var uri := str(p.call("get_launch_uri"))
	if uri == "": return ""
	if p.has_method("consume_launch_uri"): p.call("consume_launch_uri")
	var e := handle_enter(ui, uri)
	return e if e != "" else "ok"
