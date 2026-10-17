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
	return cfg().get_value("region:" + region, key, REGION_DEFAULTS.get(key))

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

static func reset_for_tests() -> void:
	_cfg = null  # reload from disk on next access
