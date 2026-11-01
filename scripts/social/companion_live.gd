class_name CompanionLive
extends RefCounted
## v0.13.1 LIVE-1: companion live feeds — each companion's creative space, shown in the social feed.
## Social.feed(viewer, "live") returns one card per companion: what they've been making and where
## (Heaven edits, builds, realm / weather / time changes they were part of), how active they are, and
## a "LIVE" flag when they did something in the last LIVE_WINDOW seconds.
## Source: the local InteractionLedger (in-world events only). Chat transcripts are NEVER shown, only a count.
## Who sees it: this device's player and the owner (the cards describe this phone's world). Sharing a card
## with others goes through Social.post as the companion, so it waits in the owner approval queue like
## every companion post.

const LIVE_WINDOW := 600
const MAX_CARDS := 40
const SCENE_TEXT := {
	"heaven_edit": "shaping Heaven", "realm_change": "exploring a new realm", "district_change": "touring a district",
	"weather_change": "playing with the weather", "time_of_day": "watching the sky turn", "companion_join": "just arrived",
	"companion_leave": "stepped away", "player_teleport": "travelling with you", "light_change": "painting with light",
}

static var now_override := -1
static func _now() -> int: return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())

static func may_view(viewer: Variant) -> bool:
	var id := Tiers.actor_id(viewer)
	return id == "local" or id == Tiers.OWNER_ID

static func _unix(iso: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(iso.trim_suffix("Z"))) if iso != "" else 0

## Companions that have any ledger activity, plus any in `extra` (e.g. those standing in the world).
static func companions(extra: Array = []) -> Array:
	var seen := {}
	for r in InteractionLedger.records("", "", 2000):
		var c := str(r.get("companion", ""))
		if c != "": seen[c] = true
	for c in extra: seen[str(c)] = true
	var out := seen.keys()
	out.sort()
	return out.slice(0, MAX_CARDS)

static func card(cid: String) -> Dictionary:
	var made: Array = []
	var chats := 0
	var last := 0
	for r in InteractionLedger.records(cid, "", 500):
		last = maxi(last, _unix(str(r.get("t", ""))))
		match str(r.get("kind", "")):
			"interaction": chats += 1
			"scene":
				var sc := str(r.get("data", {}).get("scene", ""))
				if SCENE_TEXT.has(sc): made.append({"what": sc, "text": SCENE_TEXT[sc], "t": str(r.get("t", ""))})
	var persona := CompanionsScreen.persona_of(cid)
	var nm := str(persona.get("display_name", persona.get("name", cid.replace("_", " ").capitalize())))
	var live := last > 0 and _now() - last <= LIVE_WINDOW
	var latest: String = made[-1]["text"] if not made.is_empty() else "settling into their space"
	return {"id": "live:" + cid, "kind": "live", "author": cid, "author_name": nm, "live": live,
		"text": "%s is %s." % [nm, latest], "activity": made.slice(-6), "creations": made.size(),
		"chats": chats, "last_active": last, "thumb_url": "", "badges": ["companion"] + (["live"] if live else [])}

## Feed page for mode "live": live companions first, then most recently active.
static func page(viewer: Variant, extra: Array = []) -> Dictionary:
	if not may_view(viewer): return {"ok": false, "error": "Companion live feeds show on your own device.", "items": [], "next_cursor": "", "mode": "live"}
	var items: Array = companions(extra).map(func(c): return card(c))
	items.sort_custom(func(a, b): return (a["live"] and not b["live"]) or (a["live"] == b["live"] and int(a["last_active"]) > int(b["last_active"])))
	return {"ok": true, "error": "", "items": items, "next_cursor": "", "mode": "live"}

## Share a companion's card publicly: posted AS the companion, so it waits for owner approval.
static func share(cid: String) -> Dictionary:
	if not Tiers.is_bot(cid): return {"ok": false, "error": "Not a companion."}
	var c := card(cid)
	return Social.post(cid, str(c["text"]) + " ✨", {"kind": "build"})
