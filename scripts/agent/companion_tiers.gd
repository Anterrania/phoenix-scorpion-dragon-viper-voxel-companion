class_name CompanionTiers
extends RefCounted
## v0.12: the owner's own companions get the Builder/Staff tier through the Tiers API, so they can
## build. Seeding needs an unlocked owner session (Tiers.set_tier enforces that) and only fills
## companions that have no tier yet, so an owner's later change is never overwritten.
## Every other companion (bot:* ids, other users' companions) keeps Tiers' default: Resident.

const OWNER_COMPANIONS := ["foxy_ani", "aaliyah", "circuit_nova"]
const TIER := "staff"

## Returns how many companions were seeded this call.
static func seed() -> int:
	if not Tiers.owner_session(): return 0
	var n := 0
	for id in OWNER_COMPANIONS:
		if Tiers.roles()["assign"].has(id): continue
		if Tiers.set_tier(id, TIER) == "": n += 1
	return n
