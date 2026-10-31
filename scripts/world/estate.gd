class_name Estate
extends RefCounted
## v0.9 Estate / Region / Parcel controls (Second Life / OpenSim "About Land" + "Region/Estate").
## Saved per region in user://estate.cfg. Parcel values override region values.
## Fields mirror OpenSim: terrain textures (4 corner textures -> here per-biome land texture),
## water height, sun (fixed or day cycle), access lists, terraform rights, parcel media/music.
const PATH := "user://estate.cfg"
const LAND_TEXTURES := ["default", "snow_granite", "basalt_obsidian", "crystal_glitter", "meadow_moss", "desert_sand", "volcanic_ash"]
const ACCESS := ["public", "group_only", "allowed_list", "owner_only"]
const TERRAFORM := ["owner_only", "group", "everyone"]
const REGION_DEFAULTS := {
	"land_texture": "default",
	"water_height": -3.0,
	"sun_fixed": false,
	"sun_hour": 10.0,
	"day_length_h": 4.0,
	"access": "public",
	"allowed": [],
	"banned": [],
	"terraform": "owner_only",
	"allow_fly": true,
	"allow_damage": false,
	"allow_build": true,
	"media_url": "",
	"music_url": "",
	# v0.13 optional SL / OpenSim-compatible flags (docs/VIRTUAL_WORLD_FEATURE_GAP.md). Older
	# estate.cfg files have none of these keys and simply read the defaults below (= SL defaults).
	"allow_push": true,          # SL PARCEL_FLAG_RESTRICT_PUSHOBJECT (inverted) / OpenSim RestrictPushing
	"allow_scripts": true,       # SL PARCEL_FLAG_ALLOW_SCRIPTS / OpenSim DisableScripts (inverted)
	"allow_group_scripts": true, # SL PARCEL_FLAG_ALLOW_GROUP_SCRIPTS
	"allow_landmark": true,      # SL PARCEL_FLAG_ALLOW_LANDMARK (Landmarks.save_here checks it)
	"allow_set_home": true,      # SL "Allow Set Home" (Landmarks.set_home checks it)
	"allow_object_entry": true,  # SL PARCEL_FLAG_ALLOW_ALL_OBJECT_ENTRY
	"allow_voice": true,         # SL parcel "Allow voice chat"
	"local_sound_only": false,   # SL PARCEL_FLAG_LOCAL_SOUND_ONLY
	"show_in_search": true,      # SL "Show place in search" / OpenSim BlockShowInSearch (inverted)
	"allow_land_resell": false,  # OpenSim/SL estate AllowLandResell
	"allow_join_divide": false,  # OpenSim/SL estate AllowLandJoinDivide
	"sandbox": false,            # OpenSim Sandbox (objects auto-return)
	"physics_enabled": true,     # OpenSim DisablePhysics (inverted)
	"maturity": "general",       # SL General / Moderate / Adult
	"agent_limit": 40,           # SL/OpenSim AgentLimit
	"covenant": "",              # estate covenant text (SL/OpenSim Covenant notecard), see set_covenant()
	"covenant_changed": 0,       # unix time, like OpenSim CovenantChangedDateTime
}
const MATURITY := ["general", "moderate", "adult"]
const COVENANT_MAX := 4000
## Our flag -> [SL PARCEL_FLAG_* bit, inverted?]. Values from wiki.secondlife.com/wiki/LlGetParcelFlags.
## Only used for import/export summaries (OAR landdata Flags), never sent to SL.
const SL_PARCEL_BITS := {
	"allow_fly": [0x1, false], "allow_scripts": [0x2, false], "allow_landmark": [0x8, false],
	"allow_damage": [0x20, false], "allow_build": [0x40, false], "local_sound_only": [0x8000, false],
	"allow_push": [0x200000, true], "allow_group_scripts": [0x2000000, false],
	"allow_object_entry": [0x8000000, false],
}
static var _cfg: ConfigFile

static func cfg() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.parse(SecureFile.read_text(PATH))   # encrypted once an OwnerVault exists
	return _cfg

## Drop the cached config so the next cfg() re-reads (and decrypts) user://estate.cfg.
## Renamed from reload() (2026-10-17 audit): `Estate.reload()` on a class_name runs Godot's built-in
## Script.reload() instead of this function (it re-compiles estate.gd and wipes every static var).
static func reload_data() -> void: _cfg = null

static func region_get(region: String, key: String) -> Variant:
	# return cfg().get_value("region:" + region, key, REGION_DEFAULTS.get(key))
	# A null default makes ConfigFile log "no default was given" for keys without a REGION_DEFAULTS entry.
	if not cfg().has_section_key("region:" + region, key): return REGION_DEFAULTS.get(key)
	return cfg().get_value("region:" + region, key)

static func region_set(region: String, key: String, v: Variant) -> void:
	cfg().set_value("region:" + region, key, v)
	SecureFile.write_text(PATH, cfg().encode_to_text())

static func parcel_get(region: String, parcel: String, key: String) -> Variant:
	var sec := "parcel:%s/%s" % [region, parcel]
	if cfg().has_section_key(sec, key): return cfg().get_value(sec, key)
	return region_get(region, key)

static func parcel_set(region: String, parcel: String, key: String, v: Variant) -> void:
	cfg().set_value("parcel:%s/%s" % [region, parcel], key, v)
	SecureFile.write_text(PATH, cfg().encode_to_text())

## Parcels are a 64 m grid inside each region (like SL's 4 m land grid, but bigger).
static func parcel_id(pos: Vector3) -> String:
	return "%d_%d" % [floori(pos.x / 64.0), floori(pos.z / 64.0)]

static func land_texture_index(region: String, parcel := "") -> int:
	var t := str(parcel_get(region, parcel, "land_texture") if parcel != "" else region_get(region, "land_texture"))
	return maxi(0, LAND_TEXTURES.find(t))

static func can_terraform(region: String, who_is_owner: bool) -> bool:
	var r := str(region_get(region, "terraform"))
	return who_is_owner or r == "everyone"

static func can_enter(region: String, avatar: String, is_owner: bool) -> bool:
	if is_owner: return true
	if avatar in region_get(region, "banned"): return false
	match str(region_get(region, "access")):
		"owner_only": return false
		"allowed_list", "group_only": return avatar in region_get(region, "allowed")
	return true

## SL-style PARCEL_FLAG_* bit field for a region/parcel (export summaries, LSL-like llGetParcelFlags).
static func sl_parcel_flags(region: String, parcel := "") -> int:
	var f := 0
	for k in SL_PARCEL_BITS:
		var on := bool(parcel_get(region, parcel, k) if parcel != "" else region_get(region, k))
		if on != bool(SL_PARCEL_BITS[k][1]): f |= int(SL_PARCEL_BITS[k][0])
	return f

## Inverse of sl_parcel_flags: OAR landdata Flags -> our flag dict (for import previews).
static func flags_from_sl(bits: int) -> Dictionary:
	var out := {}
	for k in SL_PARCEL_BITS:
		var set_ := (bits & int(SL_PARCEL_BITS[k][0])) != 0
		out[k] = set_ != bool(SL_PARCEL_BITS[k][1])
	return out

static func covenant(region: String) -> String: return str(region_get(region, "covenant"))

## Estate covenant (rules text shown before buying/renting land). Estate managers + unlocked owner.
## Returns "" on success or an error.
static func set_covenant(region: String, text: String, actor: Variant = "self") -> String:
	if not Tiers.can(actor, "land", region): return "Only estate managers or the owner can edit the covenant."
	var sec := "region:" + region
	var prev := {}
	for k in ["covenant", "covenant_changed"]:
		if cfg().has_section_key(sec, k): prev[k] = cfg().get_value(sec, k)
	cfg().set_value(sec, "covenant", text.strip_edges().left(COVENANT_MAX))
	cfg().set_value(sec, "covenant_changed", int(Time.get_unix_time_from_system()))
	if SecureFile.write_text(PATH, cfg().encode_to_text()): return ""
	for k in ["covenant", "covenant_changed"]:   # roll back the in-memory change
		if prev.has(k): cfg().set_value(sec, k, prev[k])
		else: cfg().erase_section_key(sec, k)
	return "Saves are sealed. Unlock first."

static func reset_for_tests() -> void:
	_cfg = null  # reload from disk on next access
