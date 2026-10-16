class_name RoleplayProfile
extends RefCounted
## v0.6 roleplay: character sheet + titler stored in Profile.data["rp"], IC/OOC chat
## formatting and /me emotes.

const FIELDS := ["title", "species", "faction", "status", "bio"]

static func sheet() -> Dictionary:
	var d: Dictionary = Profile.data.get("rp", {})
	for f in FIELDS:
		if not d.has(f): d[f] = ""
	if d["status"] == "": d["status"] = "IC"
	return d

static func save_sheet(d: Dictionary) -> void:
	Profile.data["rp"] = d
	Profile.save()

static func titler_text() -> String:
	var d := sheet()
	var lines := [Profile.display_name()]
	if str(d["title"]) != "": lines.append(str(d["title"]))
	if str(d["faction"]) != "": lines.append("⟡ " + str(d["faction"]))
	lines.append("[%s]" % d["status"])
	return "\n".join(PackedStringArray(lines))

## Returns {"text": formatted line, "to_companion": bool}
static func format_chat(name: String, raw: String, ic: bool) -> Dictionary:
	var t := raw.strip_edges()
	if t.begins_with("/me "):
		return {"text": "[i]* %s %s[/i]" % [name, t.substr(4)], "to_companion": false, "emote": true}
	if not ic:
		return {"text": "[color=#9aa0b8]((%s: %s))[/color]" % [name, t], "to_companion": false, "emote": false}
	return {"text": "[b]%s:[/b] %s" % [name, t], "to_companion": true, "emote": false}
