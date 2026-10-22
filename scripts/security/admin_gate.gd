class_name AdminGate
extends RefCounted
## AUDIT-2 (2026-10-17): one gate for every Viper Admin write.
## Writes (ticket create / transition / update / comment, wiki save, revision revert, role saves and
## Region/Estate setting saves) need Tiers.can(actor, "admin"): the owner device with an unlocked
## owner session (Profile.is_owner()). A locked owner is a guest, so whoever holds a locked phone
## can still READ the tracker, wiki and timeline but cannot change them.
## Seeding from res:// (author "system") and the append-only logs written by other systems (brain
## commits, world-edit summaries, profile card) are not admin writes and are not gated here.

const DENIED := "Owner unlock needed."

static func ok(actor: Variant = Tiers.SELF) -> bool:
	return Tiers.can(actor, "admin")

## Region / parcel settings: owner, or an estate manager on land they can enter (Tiers "land").
static func land_ok(region: String, parcel := "", actor: Variant = Tiers.SELF) -> bool:
	return region != "" and Tiers.can(actor, "land", {"region": region, "parcel": parcel})

## Gated Estate write for the Region/Estate panel. Returns "" or an error. Estate.gd stays unchanged.
static func estate_set(region: String, parcel: String, key: String, v: Variant, actor: Variant = Tiers.SELF) -> String:
	if not land_ok(region, parcel, actor): return DENIED
	if parcel != "": Estate.parcel_set(region, parcel, key, v)
	else: Estate.region_set(region, key, v)
	return ""
