class_name SimGate
extends RefCounted
## INACTIVE FOR DEV (2026-10-22 fold): needs/moods, skills/perks, factions-as-teams and crafting are Foxy-owned
## client features (docs/specs/foxy/). This model was written before the split; it is kept, tested and
## unwired as a reference Foxy may adopt or replace. Nothing in the app calls it. Do not extend it here.
## SBX-SIM-0: one permission door for the sim systems in scripts/sim (needs + mood, skills + perks,
## factions + reputation, crafting + infusion). Every check goes through Tiers.can(); owner-only
## actions go through Tiers.owner_session(), which is Profile.is_owner() (owner device + unlocked
## OwnerVault). Quests, market delivery, on-demand worlds and rentals live in scripts/sandbox
## (SandboxGate, feature/sandbox-dev-parity); this file is kept separate so the two never collide.
##
## Tiers.ACTIONS is shared with Social/admin, so instead of adding new actions there (and changing
## the role-matrix editor) the game verbs map onto existing actions. If a verb ever needs its own
## matrix row, add it to Tiers.ACTIONS and point the map at it: nothing else changes. (SBX-SIM-10)
##
## E-stop: Tiers.can already blocks bots/companions (everything but browse) while AutonomyGuard is
## paused, so a paused companion can't craft or join factions.

const VERBS := {
	"play": "browse",            # track needs, earn XP, spend perk points. With a region -> "enter"
	"craft": "build",            # crafting at a station; with a parcel target the estate rules apply
	"join_faction": "group_join",
	"create_faction": "group_create",
	"manage_region": "land",     # estate manager: faction territory labels
}
## Owner-only verbs: never granted through the matrix.
const OWNER_VERBS := ["respec_any", "set_reputation", "reset_needs"]

static func action_for(verb: String, target: Variant = null) -> String:
	if verb == "play" and target != null and str(target) != "": return "enter"
	return str(VERBS.get(verb, ""))

## The single check every sim system uses.
static func can(actor: Variant, verb: String, target: Variant = null) -> bool:
	if verb in OWNER_VERBS: return owner()
	var a := action_for(verb, target)
	if a == "": return false
	return Tiers.can(actor, a, target if a in ["build", "land", "enter"] else null)

## Owner powers: Profile.is_owner() (role owner + unlocked vault), via Tiers so tests can override.
static func owner() -> bool: return Tiers.owner_session()

## Save root (SecureFile: encrypted once an OwnerVault exists).
static var root := "user://sim"
static func path(name: String) -> String: return root.path_join(name + ".json")
static func load_json(name: String, fallback: Variant) -> Variant: return SecureFile.read_json(path(name), fallback)
static func save_json(name: String, d: Variant) -> bool: return SecureFile.write_json(path(name), d)

static func data(file: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sim/%s.json" % file))
	return d if d is Dictionary else {}

static func reset_for_tests(p_root: String) -> void: root = p_root
