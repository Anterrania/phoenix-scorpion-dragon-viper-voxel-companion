class_name LivingGate
extends RefCounted
## LIFE-4: one door for every living-world rule (survival, disease, laws, mining).
## - exempt(actor): Phoenix as god skips survival, disease and law rules. True ONLY when the actor's
##   effective tier is "owner", i.e. Profile.is_owner() (owner role AND unlocked OwnerVault) through
##   Tiers.tier_of(). A locked owner is a guest under Tiers and is NOT exempt.
## - Per-estate survival mode: Estate region key "survival" = on | off | softcore. Unset regions use
##   the realm default (data/living/realms.json): survival realms on, softcore realms softcore, social
##   / club / home / welcome / SL-style regions off. Only the unlocked owner or an estate manager edits it.
## - E-stop: while AutonomyGuard is paused, bots and companions are frozen: no drain, no autonomous
##   actions, no infection rolls. Their vitals are held exactly where they were.

const MODES := ["on", "off", "softcore"]
const REALMS_PATH := "res://data/living/realms.json"
static var _realms = null

static func realms_data() -> Dictionary:
	if _realms == null:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(REALMS_PATH))
		_realms = d if d is Dictionary else {}
	return _realms

static func exempt(actor: Variant) -> bool:
	return Tiers.tier_of(actor) == "owner"

static func frozen(actor: Variant) -> bool:
	return Tiers.is_bot(Tiers.actor_id(actor)) and AutonomyGuard.paused()

## Realm of a region: Estate key "realm" if set, else the region id when it names a realm, else "social".
static func realm_of(region: String) -> String:
	if Estate.cfg().has_section_key("region:" + region, "realm"): return str(Estate.cfg().get_value("region:" + region, "realm"))
	if realms_data().get("realms", {}).has(region): return region
	return "social"

static func realm_default_mode(realm: String) -> String:
	var d := realms_data()
	if realm in d.get("survival_realms", []): return "on"
	if realm in d.get("softcore_realms", []): return "softcore"
	return "off"

static func mode(region: String) -> String:
	var sec := "region:" + region
	if Estate.cfg().has_section_key(sec, "survival"):
		var m := str(Estate.cfg().get_value(sec, "survival"))
		if m in MODES: return m
	return realm_default_mode(realm_of(region))

static func can_manage(actor: Variant, region: String) -> bool:
	if Tiers.can(actor, "land", region): return true
	return Tiers.tier_of(actor) != "guest" and ParcelTools.is_manager(region, Tiers.actor_id(actor))

## Returns "" on success or an error.
static func set_mode(actor: Variant, region: String, m: String) -> String:
	if not m in MODES: return "Pick on, off or softcore."
	if not can_manage(actor, region): return "Only the owner or an estate manager can change survival rules."
	Estate.region_set(region, "survival", m)
	return ""

static func set_realm(actor: Variant, region: String, realm: String) -> String:
	if not realms_data().get("realms", {}).has(realm): return "Unknown realm."
	if not can_manage(actor, region): return "Only the owner or an estate manager can change the realm."
	Estate.region_set(region, "realm", realm)
	return ""

## True when survival/disease rules apply to this actor in this region.
static func applies(actor: Variant, region: String) -> bool:
	return not exempt(actor) and mode(region) != "off"

static func reset_cache() -> void: _realms = null
