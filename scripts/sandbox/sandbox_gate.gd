class_name SandboxGate
extends RefCounted
## SBX-1: one permission door for the dev-side sandbox systems: quests/missions (SBX-2), on-demand
## worlds + region bundles (SBX-3), inventory migration (SBX-4), market delivery + magic-box vendors
## (SBX-5) and region rental (SBX-6). Needs/moods, household/build mode, vehicles, skill trees,
## crafting, teams/pets/mounts are Foxy's client features (docs/specs/foxy/), not built here.
## Every check goes through Tiers.can(); owner-only verbs need Tiers.owner_session(), which is
## Profile.is_owner() (owner device + unlocked OwnerVault), AND the actor to be the owner.
## Money and chance rules live in LegalReview (scripts/economy/legal_review.gd), deny by default.
##
## Tiers.ACTIONS is shared with Social/admin, so instead of adding new actions there (and changing
## the role-matrix editor) the game verbs map onto existing actions. If a verb ever needs its own
## matrix row, add it to Tiers.ACTIONS and point the map at it: nothing else changes.
##
## E-stop: Tiers.can already blocks bots/companions (everything but browse) while AutonomyGuard is
## paused, so a paused companion can't trade, sell or rent.

const VERBS := {
	"play": "browse",            # quest journal, accept/progress quests. With a region target -> "enter"
	"trade": "message",          # receive deliveries, buy from a vendor, rent land (residents and up)
	"sell": "marketplace",       # list items, stock a magic box (creator tier and up)
	"author": "event_create",    # write quests/missions for others (creator tier and up)
	"import": "upload",          # migrate your own inventory from another grid (creator tier and up)
	"place": "build",            # rez a vendor box; needs a parcel target, estate build rules apply
	"manage_region": "land",     # estate manager: on-demand schedule, export bundle, rental terms
}
## Owner-only verbs: never granted through the matrix.
const OWNER_VERBS := ["grant", "approve_listing", "publish_quest", "import_bundle", "migrate_for", "grant_lease"]

static func action_for(verb: String, target: Variant = null) -> String:
	if verb == "play" and target != null and str(target) != "": return "enter"
	return str(VERBS.get(verb, ""))

## The single check every sandbox system uses.
static func can(actor: Variant, verb: String, target: Variant = null) -> bool:
	if verb in OWNER_VERBS: return owner() and Tiers.tier_of(actor) == "owner"
	var a := action_for(verb, target)
	if a == "": return false
	return Tiers.can(actor, a, target if a in ["build", "land", "enter"] else null)

## Actor id as stored in sandbox saves ("self" -> "phoenix" on the owner device, else "local").
static func id_of(actor: Variant) -> String: return Tiers.actor_id(actor)

## Owner powers: Profile.is_owner() (role owner + unlocked vault), via Tiers so tests can override.
static func owner() -> bool: return Tiers.owner_session()

## Shared save root (SecureFile: encrypted once an OwnerVault exists).
static var root := "user://sandbox"
static func path(name: String) -> String: return root.path_join(name + ".json")
static func load_json(name: String, fallback: Variant) -> Variant: return SecureFile.read_json(path(name), fallback)
static func save_json(name: String, d: Variant) -> bool: return SecureFile.write_json(path(name), d)

static func data(file: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sandbox/%s.json" % file))
	return d if d is Dictionary else {}

static func reset_for_tests(p_root: String) -> void: root = p_root
