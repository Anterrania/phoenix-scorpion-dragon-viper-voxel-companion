class_name AvatarAppearance
extends RefCounted
## v0.9 avatar structure modelled on OpenSim / Aurora-Sim `AvatarAppearance`:
##   Serial, VisualParams (byte 0..255 sliders), Wearables (one slot per WearableType, each a
##   stack of layers), Texture/Bake faces, Attachments (attach point id -> items), AvatarHeight.
## Each SL-style piece maps onto a Star Citizen-style modular DNA blend slot so the same
## appearance drives the existing AvatarDNA morph/blend pipeline. See docs/AVATAR_STRUCTURE.md.
const SCHEMA := 1
## OpenSim WearableType order (0..15).
const WEARABLE_TYPES := ["shape", "skin", "hair", "eyes", "shirt", "pants", "shoes", "socks", "jacket", "gloves", "undershirt", "underpants", "skirt", "alpha", "tattoo", "physics"]
const BODY_PARTS := ["shape", "skin", "hair", "eyes"]  # required, one each (like SL)
const MAX_LAYERS := 5  # clothing layers per type
## OpenSim AttachmentPoint ids (subset) -> our AvatarDNA.POINTS key.
const ATTACH_POINTS := {
	1: ["Chest", "chest"], 2: ["Skull", "head"], 5: ["Left Hand", "hand_l"], 6: ["Right Hand", "hand_r"],
	7: ["Left Foot", "foot_l"], 8: ["Right Foot", "foot_r"], 9: ["Spine", "back"], 10: ["Pelvis", "hips"],
	11: ["Mouth", "face"], 17: ["Nose", "face"], 39: ["Neck", "chest"], 40: ["Avatar Center", "hips"],
	# HUD points 31-38 are screen attachments (future)
}
## VisualParam id (SL numbering where one exists) -> [name, dna slot, dna slider].
const VISUAL_PARAMS := {
	33: ["Height", "body", "height"],
	34: ["Body Thickness", "body", "build"],
	36: ["Shoulders", "body", "shoulders"],
	682: ["Head Size", "head", "head_size"],
	17: ["Jaw Shape", "face", "jaw"],
	692: ["Leg Length", "body", "leg_length"],
	693: ["Arm Length", "body", "arm_length"],
}
## Star Citizen-style DNA blend slots (each blends up to 3 parent heads/bodies).
const DNA_SLOTS := ["head", "eyes", "brows", "nose", "ears", "mouth", "jaw", "face", "body", "skin", "hair"]
## Which DNA slot each wearable/body part feeds.
const WEARABLE_TO_SLOT := {"shape": "body", "skin": "skin", "hair": "hair", "eyes": "eyes"}

var serial := 0
var visual_params := {}      # id -> 0..255
var wearables := {}          # type -> Array[{item_id, asset_id, name}]
var attachments := {}        # point id -> Array[{item_id, asset_id, name}]
var dna_blend := {}          # slot -> {parents:[ids], weights:[floats]}
var avatar_height := 1.9

func _init() -> void:
	for t in WEARABLE_TYPES: wearables[t] = []
	for id in VISUAL_PARAMS: visual_params[id] = 127
	for s in DNA_SLOTS: dna_blend[s] = {"parents": [], "weights": []}

func wear(type: String, item: Dictionary) -> bool:
	if type not in WEARABLE_TYPES: return false
	var stack: Array = wearables[type]
	if type in BODY_PARTS: stack.clear()  # body parts replace, clothing layers stack
	elif stack.size() >= MAX_LAYERS: return false
	stack.append(item)
	serial += 1
	return true

func take_off(type: String, item_id: String) -> void:
	wearables[type] = (wearables[type] as Array).filter(func(i): return i.get("item_id") != item_id)
	serial += 1

func attach(point: int, item: Dictionary, add := true) -> bool:
	if not ATTACH_POINTS.has(point): return false
	if not add or not attachments.has(point): attachments[point] = []
	attachments[point].append(item)
	serial += 1
	return true

func set_param(id: int, v: int) -> void:
	visual_params[id] = clampi(v, 0, 255)
	serial += 1

func set_dna(slot: String, parents: Array, weights: Array) -> void:
	if slot in DNA_SLOTS: dna_blend[slot] = {"parents": parents.slice(0, 3), "weights": weights.slice(0, 3)}

## Sliders in AvatarDNA's -1..1 range, from 0..255 visual params.
func to_dna_sliders() -> Dictionary:
	var out := {}
	for id in VISUAL_PARAMS:
		out[VISUAL_PARAMS[id][2]] = (float(visual_params[id]) - 127.5) / 127.5
	return out

## Attachments as AvatarDNA.attach_all() entries.
func to_dna_attachments() -> Array:
	var out := []
	for pt in attachments:
		for it in attachments[pt]:
			out.append({"point": ATTACH_POINTS[pt][1], "path": str(it.get("asset_id", "")), "name": str(it.get("name", ""))})
	return out

func to_dict() -> Dictionary:
	return {"schema": SCHEMA, "serial": serial, "visual_params": visual_params, "wearables": wearables, "attachments": attachments, "dna_blend": dna_blend, "avatar_height": avatar_height}

static func from_dict(d: Dictionary) -> AvatarAppearance:
	var a := AvatarAppearance.new()
	a.serial = int(d.get("serial", 0))
	for k in d.get("visual_params", {}): a.visual_params[int(k)] = int(d["visual_params"][k])
	for k in d.get("wearables", {}): a.wearables[str(k)] = d["wearables"][k]
	for k in d.get("attachments", {}): a.attachments[int(k)] = d["attachments"][k]
	for k in d.get("dna_blend", {}): a.dna_blend[str(k)] = d["dna_blend"][k]
	a.avatar_height = float(d.get("avatar_height", 1.9))
	return a
