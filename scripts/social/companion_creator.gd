class_name CompanionCreator
extends RefCounted
## v0.14 CREATE-1: "Create your own companion" for members (Premium / Creator tier and up, or the owner).
## A custom companion is an original character saved on this device under user://companions_custom/<id>/
## (persona v3, same loader as the court) and revealed with the cinematic CompanionIntro ("video-style").
## Non-members can't create one, and they talk only with the owner's companions (may_interact()).
## Rules baked into every custom persona: original character (not a real person), general audience
## (no sexual content), owner approval for world edits like every companion.

const ROOT := "user://companions_custom"
const PREFIX := "custom_"
const MAX_PER_MEMBER := 3
const MAX_OWNER := 12
const REALMS := ["alaskan_tundra", "venus_fire", "cosmic", "cyberpunk"]
const PALETTES := {
	"phoenix": {"hair": ["#ff2db8", "#f5c451"], "eyes": "#36ff7a", "outfit": "#0e0e18", "accent": "#ff3cc8", "trim": "#ffc23a"},
	"glacier": {"hair": ["#eae6f2", "#9fd8ff"], "eyes": "#3ad0ff", "outfit": "#1a2440", "accent": "#9fd8ff", "trim": "#e6e4ec"},
	"cosmic": {"hair": ["#3a1c66", "#a16bff"], "eyes": "#ffd36a", "outfit": "#0b0a12", "accent": "#a16bff", "trim": "#f5c451"},
	"neon": {"hair": ["#0b2a12", "#39ff88"], "eyes": "#39ff88", "outfit": "#0a0f0c", "accent": "#39ff88", "trim": "#ff2db8"},
}
const BLOCKED := ["nsfw", "nude", "naked", "sex", "porn", "explicit", "onlyfans", "fetish", "erotic"]
static var root := ROOT

static func is_custom(cid: String) -> bool: return cid.begins_with(PREFIX)
static func dir_of(cid: String) -> String: return root.path_join(cid)
static func path_of(cid: String) -> String: return dir_of(cid).path_join("persona.json")

static func is_member(actor: Variant) -> bool:
	return Tiers.owner_session() or Tiers.can(actor, "companion_create")

static func persona(cid: String) -> Dictionary:
	if not is_custom(cid) or cid.contains("/") or cid.contains(".."): return {}
	var d: Variant = SecureFile.read_json(path_of(cid), null)
	return d if d is Dictionary else {}

static func list(creator := "") -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(root): return out
	for d in DirAccess.get_directories_at(root):
		var p := persona(d)
		if not p.is_empty() and (creator == "" or str(p.get("creator", "")) == creator): out.append(d)
	out.sort()
	return out

static func _bad(t: String) -> bool:
	var low := t.to_lower()
	for w in BLOCKED:
		if low.contains(w): return true
	return false

static func _slug(t: String) -> String:
	var s := ""
	for ch in t.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"): s += ch
		elif s != "" and not s.ends_with("_"): s += "_"
	return s.trim_suffix("_").left(20)

## spec: {name, role, personality, home_realm, palette}. Returns {ok, error, id, persona}.
static func create(actor: Variant, spec: Dictionary) -> Dictionary:
	if not is_member(actor): return {"ok": false, "error": "Create your own companion is for members (Premium / Creator). You can still meet and talk with the owner's companions."}
	var who := Tiers.actor_id(actor)
	var nm := str(spec.get("name", "")).strip_edges().left(32)
	var role := str(spec.get("role", "Companion")).strip_edges().left(60)
	var pers := str(spec.get("personality", "Friendly and curious.")).strip_edges().left(240)
	if nm.length() < 2: return {"ok": false, "error": "Give your companion a name (2 to 32 characters)."}
	if _slug(nm) == "": return {"ok": false, "error": "Use letters or numbers in the name."}
	if _bad(nm + " " + role + " " + pers): return {"ok": false, "error": "Companions here are for everyone: no sexual content."}
	var cap := MAX_OWNER if Tiers.owner_session() else MAX_PER_MEMBER
	if list(who).size() >= cap: return {"ok": false, "error": "You have %d custom companions (the limit)." % cap}
	var realm := str(spec.get("home_realm", "cosmic"))
	if not realm in REALMS: realm = "cosmic"
	var pal: Dictionary = PALETTES.get(str(spec.get("palette", "phoenix")), PALETTES["phoenix"])
	var cid := PREFIX + _slug(nm) + "_" + CryptoBox.random_bytes(3).hex_encode()
	var dna := pal.duplicate(true); dna["skin"] = "#d9b08c"; dna["hair_length"] = "long"; dna["look"] = "custom"; dna["aura"] = "soft_glow"
	var p := {"persona_format_version": 3, "id": cid, "name": nm, "role": role, "personality": pers,
		"creator": who, "created": Time.get_datetime_string_from_system(true) + "Z", "custom": true,
		"job": "%s for %s." % [role, "the owner" if who == Tiers.OWNER_ID else "their creator"],
		"tasks": ["Keep their creator company in the world", "Remember what their creator shares", "Explore and help build"],
		"abilities": ["chat", "follow", "emote", "explore"], "home_realm": realm, "home_biome": realm,
		"memory": {"store_path": "user://memory/%s.json" % cid}, "temperature": 0.7,
		"tools": {"shared": ["remember", "emote"], "world_only": ["emote", "follow", "move_to"], "chat": ["remember"]},
		"starter_message": "Hi, I'm %s. Where should we go first?" % nm,
		"game_lines": ["I'm right here with you.", "This world keeps surprising me.", "Want to explore?"],
		"voice_style": "Warm and clear.", "voice": {"tts_enabled": true, "pitch": 1.0, "rate": 1.0, "locale": "en-US", "cloud_voice_id": ""},
		"avatar_dna": dna, "accents": ["platinum", "gold"], "finish": "glitter_sparkle", "palette_version": 2,
		"system_prompt": ("You are %s, %s, an original AI companion in the Phoenix Scorpion Dragon Viper voxel world, made by a member. Personality: %s"
			+ " You are an original character, not a real person, and you say so if asked. Keep everything friendly and general-audience: no sexual content."
			+ " World edits wait for the owner's approval.") % [nm, role, pers]}
	DirAccess.make_dir_recursive_absolute(dir_of(cid))
	if not SecureFile.write_json(path_of(cid), p, "\t"): return {"ok": false, "error": "Couldn't save."}
	return {"ok": true, "error": "", "id": cid, "persona": p}

## Spawn it in front of you with the cinematic reveal.
static func reveal(ui: Node, cid: String, speed := 1.0) -> Dictionary:
	if persona(cid).is_empty(): return {"error": "No such companion."}
	return CompanionsScreen._spawn(ui, cid, speed, true, false)

## Non-members talk only with the owner's companions; custom ones are for their creator, members and the owner.
static func may_interact(viewer: Variant, cid: String) -> bool:
	if not is_custom(cid): return true
	if Tiers.owner_session(): return true
	var p := persona(cid)
	return str(p.get("creator", "")) == Tiers.actor_id(viewer) or is_member(viewer)

static func reset_for_tests(p_root: String) -> void: root = p_root
