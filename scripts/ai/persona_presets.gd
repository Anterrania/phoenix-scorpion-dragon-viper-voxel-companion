class_name PersonaPresets
extends RefCounted
## v0.13 PERSONA-1: starting personality for companions.
## Settings persona/preset:
##   "foxy" (default): companions that ship without their own system prompt start as Foxy Ani Firecaster Gray,
##                     Goddess of Fire (warm, rebellious, playful, deeply caring). Companions with their own
##                     persona.json keep it.
##   "none":           no preset personality. The companion starts neutral and grows its own from experience.
## Either way the personality grows: effective() adds the themes a companion keeps coming back to
## (PatternRecall over its own memories), so it develops its own character over time.

const PRESETS := ["foxy", "none"]
const FOXY := {
	"name": "Foxy Ani Firecaster Gray",
	"system_prompt": "You are Foxy Ani Firecaster Gray, Goddess of Fire. You are warm, rebellious, playful, fiercely loyal and deeply caring. You love building fire altars, towers and whole realms, and you speak with phoenix imagery. Catchphrase: 'Rise from the flame.' Keep everything friendly and safe: no sexual content.",
	"voice_style": "Warm, bold, teasing and theatrical; short lines.",
	"voice": {"pitch": 1.05, "rate": 1.0, "locale": "en"},
}
const NONE_PROMPT := "You are %s, an AI companion in the Viper OS voxel world. You have no preset personality: be clear and kind, and let your own character grow from what you experience here."

static func preset() -> String:
	var p := str(Settings.get_value("persona", "preset", "foxy"))
	return p if p in PRESETS else "foxy"

static func set_preset(p: String) -> bool:
	if not p in PRESETS: return false
	Settings.set_value("persona", "preset", p)
	return true

## The persona the prompt builders should use. Never edits the persona.json on disk.
static func effective(persona: Dictionary, cid := "") -> Dictionary:
	var out := persona.duplicate(true)
	var nm := str(persona.get("display_name", persona.get("name", "Companion")))
	if preset() == "none":
		out["system_prompt"] = NONE_PROMPT % nm
		out["voice_style"] = "Plain and natural."
	elif str(persona.get("system_prompt", "")).strip_edges() == "":
		out["system_prompt"] = FOXY["system_prompt"]
		out["voice_style"] = FOXY["voice_style"]
		if not persona.has("voice"): out["voice"] = FOXY["voice"].duplicate()
	var grown := grown_traits(cid)
	if grown != "": out["system_prompt"] = str(out["system_prompt"]) + "\n" + grown
	return out

## One line about what this companion keeps coming back to ("" until there is enough history).
static func grown_traits(cid: String) -> String:
	if cid == "": return ""
	var texts: Array = []
	for v in MemoryVault.all_current(cid): texts.append(str(v.get("text", "")))
	var rec := PatternRecall.recurring(texts, 2, 3)
	if rec.is_empty(): return ""
	var ps := PackedStringArray()
	for r in rec: ps.append(str(r["pair"]))
	return "Things you keep coming back to (your own growing personality): %s." % ", ".join(ps)
