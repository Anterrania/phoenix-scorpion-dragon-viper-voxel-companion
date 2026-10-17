class_name CompanionDNA
extends RefCounted
## v0.10 modular avatar DNA (Aurora/SC-style slots) read from persona.json "avatar_dna".
## Slots: skin, skin_metal, hair (gradient array), hair_length, curly, eyes, outfit, top, pants,
## accent, trim, look, aura (phoenix_fire | circuit_glow | ""), freckles, chains, horns.
## Companions without avatar_dna get a deterministic sensible default from their id.

const SLOTS := ["skin", "skin_metal", "hair", "hair_length", "curly", "eyes", "outfit", "top", "pants",
	"accent", "trim", "look", "aura", "freckles", "chains", "horns"]

static func _col(v: Variant, fallback: Color) -> Color:
	if v is Color: return v
	if v is String and v != "": return Color.from_string(v, fallback)
	return fallback

static func default_dna(id: String) -> Dictionary:
	var h := absi(hash(id))
	var hue := float(h % 360) / 360.0
	var skins := ["#f1c9a5", "#d9a37c", "#a8714f", "#7a4b32", "#e8b48f"]
	return {"skin": skins[h % skins.size()], "hair": [Color.from_hsv(hue, 0.7, 0.55).to_html(false), Color.from_hsv(fmod(hue + 0.06, 1.0), 0.75, 0.7).to_html(false)],
		"hair_length": "long" if h % 2 == 0 else "short", "eyes": Color.from_hsv(fmod(hue + 0.4, 1.0), 0.7, 0.9).to_html(false),
		"outfit": "#121018", "accent": Color.from_hsv(fmod(hue + 0.5, 1.0), 0.8, 0.95).to_html(false), "trim": "#ffc23a", "look": "classic"}

static func dna_for(persona: Dictionary) -> Dictionary:
	var d: Variant = persona.get("avatar_dna")
	return d if d is Dictionary and not d.is_empty() else default_dna(str(persona.get("id", "x")))

## Merge DNA over a base style dictionary (CompanionConfig.style()). DNA wins.
static func apply(persona: Dictionary, base := {}) -> Dictionary:
	var s := base.duplicate()
	var d := dna_for(persona)
	for k in ["skin", "eyes", "outfit", "top", "pants", "accent", "trim"]:
		if d.has(k): s[k] = _col(d[k], s.get(k, Color.WHITE))
	if d.has("hair") and d["hair"] is Array and not d["hair"].is_empty():
		var hs: Array = []
		for c in d["hair"]: hs.append(_col(c, Color.PURPLE))
		s["hair"] = hs[0]
		s["hair_gradient"] = hs
	for k in ["skin_metal", "look", "aura", "freckles", "chains", "horns", "curly", "hair_length"]:
		if d.has(k): s[k] = d[k]
	if d.has("outfit_look"): s["outfit_look"] = d["outfit_look"]
	s["body_id"] = str(persona.get("id", ""))
	s["dna"] = true
	return s
