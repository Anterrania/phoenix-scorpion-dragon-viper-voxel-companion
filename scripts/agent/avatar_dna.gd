class_name AvatarDNA
extends RefCounted
## v0.5 original "DNA blend" avatar system + Second Life-style attachments.
## DNA: pick 2-3 parent heads/bodies (data/avatar_dna.json) and blend their morph
## values with weights, then fine-tune sliders. Morphs are applied as scale/offset
## weights on our base HumanoidModel parts (future: real blend shapes on a skinned glTF).
## Attachments: items attached to named points; .glb meshes load at runtime.
## Alpha masks hide body regions under clothing.

const DNA_PATH := "res://data/avatar_dna.json"
const SLIDERS := ["height", "build", "shoulders", "head_size", "jaw", "leg_length", "arm_length"]
## point -> [node path under Model, local offset]
const POINTS := {
	"head": ["Hips/Torso/Head", Vector3(0, 0.26, 0)],
	"hair": ["Hips/Torso/Head", Vector3(0, 0.18, 0.02)],
	"face": ["Hips/Torso/Head", Vector3(0, 0.1, -0.12)],
	"chest": ["Hips/Torso", Vector3(0, 0.42, -0.14)],
	"back": ["Hips/Torso", Vector3(0, 0.42, 0.14)],
	"hips": ["Hips", Vector3.ZERO],
	"hand_l": ["Hips/Torso/ArmL/Fore", Vector3(0, -0.32, 0)],
	"hand_r": ["Hips/Torso/ArmR/Fore", Vector3(0, -0.32, 0)],
	"foot_l": ["Hips/LegL/Shin", Vector3(0, -0.42, 0)],
	"foot_r": ["Hips/LegR/Shin", Vector3(0, -0.42, 0)],
}
## alpha mask -> parts hidden (so mesh clothing/body parts can replace them)
const MASKS := {
	"head": ["Hips/Torso/Head"],
	"arms": ["Hips/Torso/ArmL", "Hips/Torso/ArmR"],
	"legs": ["Hips/LegL", "Hips/LegR"],
	"feet": ["Hips/LegL/Shin/End", "Hips/LegR/Shin/End"],
	"hands": ["Hips/Torso/ArmL/Fore/End", "Hips/Torso/ArmR/Fore/End"],
}

static func parents() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DNA_PATH))
	return d.get("parents", {}) if d is Dictionary else {}

## Weighted blend of 2-3 parent morph sets (weights auto-normalized).
static func blend(parent_ids: Array, weights: Array) -> Dictionary:
	var P := parents()
	var out := {}
	for s in SLIDERS: out[s] = 0.0
	var total := 0.0
	for i in parent_ids.size():
		var w := float(weights[i]) if i < weights.size() else 0.0
		var m: Dictionary = P.get(str(parent_ids[i]), {}).get("morphs", {})
		total += w
		for s in SLIDERS: out[s] += float(m.get(s, 0.0)) * w
	if total > 0.0:
		for s in SLIDERS: out[s] /= total
	return out

## Final morphs = blend + user slider offsets, clamped -1..1.
static func resolve(dna: Dictionary) -> Dictionary:
	var m := blend(dna.get("parents", []), dna.get("weights", []))
	var adj: Dictionary = dna.get("sliders", {})
	for s in SLIDERS: m[s] = clampf(float(m[s]) + float(adj.get(s, 0.0)), -1.0, 1.0)
	return m

static func apply_morphs(model: Node3D, m: Dictionary) -> void:
	var h := 1.0 + 0.12 * float(m.get("height", 0.0))
	var b := 1.0 + 0.18 * float(m.get("build", 0.0))
	model.scale = Vector3(b, h, b)
	var torso := model.get_node_or_null("Hips/Torso") as Node3D
	if torso: torso.scale = Vector3(1.0 + 0.15 * float(m.get("shoulders", 0.0)), 1, 1)
	var head := model.get_node_or_null("Hips/Torso/Head") as Node3D
	if head:
		var hs := 1.0 + 0.15 * float(m.get("head_size", 0.0))
		head.scale = Vector3(hs * (1.0 + 0.08 * float(m.get("jaw", 0.0))), hs, hs)
	for leg in ["Hips/LegL", "Hips/LegR"]:
		var n := model.get_node_or_null(leg) as Node3D
		if n: n.scale.y = 1.0 + 0.12 * float(m.get("leg_length", 0.0))
	for arm in ["Hips/Torso/ArmL", "Hips/Torso/ArmR"]:
		var n := model.get_node_or_null(arm) as Node3D
		if n: n.scale.y = 1.0 + 0.1 * float(m.get("arm_length", 0.0))

static func apply_masks(model: Node3D, masks: Array) -> void:
	for mk in masks:
		for p in MASKS.get(str(mk), []):
			var n := model.get_node_or_null(p) as Node3D
			if n: n.visible = false

## Built-in procedural attachments (original designs).
static func builtin(id: String) -> Node3D:
	var K = PropKit
	var n := Node3D.new()
	match id:
		"halo":
			K.part(n, K.torus(0.12, 0.14), K.mat("#f2bd3a", 3.0, 1.0, 0.2), Vector3(0, 0.08, 0))
		"platinum_crown":
			for i in 7:
				var a := TAU * i / 7.0
				K.part(n, K.cone(0.0, 0.025, 0.12, 4), K.mat("#e8e4f0", 0.6, 1.0, 0.15), Vector3(cos(a) * 0.1, 0.05, sin(a) * 0.1))
			K.part(n, K.torus(0.095, 0.11), K.mat("#e8e4f0", 0.4, 1.0, 0.15), Vector3.ZERO)
		"dragon_wings":
			for s in [-1.0, 1.0]:
				K.part(n, K.cone(0.0, 0.35, 1.1, 3), K.mat("#2a0a24", 0.6, 0.4, 0.3), Vector3(s * 0.45, 0.15, 0.05), Vector3(1, 1, 0.08), Vector3(0, 0, -s * 1.0))
		"magenta_cape":
			K.part(n, K.cone(0.22, 0.4, 1.0, 12), K.mat("#b0177f", 0.2, 0.2, 0.5), Vector3(0, -0.45, 0.05), Vector3(1, 1, 0.15))
		"scepter":
			K.part(n, K.cone(0.015, 0.015, 0.7, 8), K.mat("#f2bd3a", 0.3, 1.0, 0.2), Vector3(0, 0, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
			K.part(n, K.sphere(0.05, 10), K.mat("#ff2fd0", 3.0), Vector3(0, 0, -0.36))
		_:
			return null
	n.name = id
	return n

## Runtime glTF/.glb import (works on Android for files in user://).
static func load_glb(path: String) -> Node3D:
	if not FileAccess.file_exists(path): return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK: return null
	var scene := doc.generate_scene(state)
	return scene as Node3D

## Attach list: [{"id": "...", "point": "head", "source": "builtin"|"glb", "path": "...", "scale": 1.0}]
static func attach_all(model: Node3D, attachments: Array) -> int:
	var count := 0
	for a in attachments:
		var pt: Array = POINTS.get(str(a.get("point", "")), [])
		if pt.is_empty(): continue
		var host := model.get_node_or_null(pt[0]) as Node3D
		if host == null: continue
		var node: Node3D = load_glb(str(a.get("path", ""))) if str(a.get("source", "builtin")) == "glb" else builtin(str(a.get("id", "")))
		if node == null: continue
		node.position = pt[1]
		node.scale *= float(a.get("scale", 1.0))
		node.set_meta("attachment", a)
		host.add_child(node)
		count += 1
	return count

## Apply DNA morphs, alpha masks and attachments from an avatar dict.
static func apply_all(model: Node3D, av: Dictionary) -> void:
	if av.has("dna"): apply_morphs(model, resolve(av["dna"]))
	apply_masks(model, av.get("alpha_masks", []))
	attach_all(model, av.get("attachments", []))

## Portable "avatar DNA + attachments" file.
static func export_avatar(av: Dictionary, name: String) -> Dictionary:
	return {"format": "anterrania.avatar.v1", "name": name, "appearance": av,
		"note": "Portable avatar: base colors, DNA blend, sliders, alpha masks, attachments."}

static func import_avatar(d: Dictionary) -> Dictionary:
	return d.get("appearance", {}) if str(d.get("format", "")) == "anterrania.avatar.v1" else {}
