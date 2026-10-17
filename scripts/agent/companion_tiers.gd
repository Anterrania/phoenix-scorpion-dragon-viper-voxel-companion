class_name CompanionTiers
extends RefCounted
## v0.12: on the first owner unlock, give the owner's own companions the Builder role through the
## audited, owner-gated Tiers.set_role(). Runs once (flag in Settings), logs errors, retries next
## unlock only if something failed. Everyone else's companions keep the Tiers default (Resident).

const OWNER_COMPANIONS := ["foxy_ani", "aaliyah", "circuit_nova"]
const FLAG_SECTION := "tiers"
const FLAG_KEY := "owner_companions_seeded"

static func seeded() -> bool:
	return bool(Settings.get_value(FLAG_SECTION, FLAG_KEY, false))

## Returns the list of errors ("" entries are not included). Empty list = done.
static func seed_once(is_owner: bool) -> Array:
	if not is_owner or seeded(): return []
	var errors: Array = []
	for id in OWNER_COMPANIONS:
		var e := Tiers.set_role(id, "builder")
		if e != "":
			errors.append("%s: %s" % [id, e])
			push_warning("CompanionTiers: set_role(%s, builder) failed: %s" % [id, e])
	if errors.is_empty(): Settings.set_value(FLAG_SECTION, FLAG_KEY, true)
	return errors
