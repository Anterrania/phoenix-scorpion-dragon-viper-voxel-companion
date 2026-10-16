extends Node
## v0.5 wardrobe + satchel inventory. Items come from data/wardrobe/sample_items.json;
## equipped looks persist to user://wardrobe.json. Mature items are filtered out
## unless Settings.mature_enabled() (age-gated, off by default).

signal equipped_changed(target: String)
const ITEMS_PATH := "res://data/wardrobe/sample_items.json"
const SAVE_PATH := "user://wardrobe.json"
var items: Array = []
var satchel: Array = []
var equipped := {}   # target -> {slot: item_id}

func _ready() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if d is Dictionary:
		items = d.get("items", [])
		satchel = d.get("satchel", [])
	var s: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else null
	if s is Dictionary: equipped = s

func item(id: String) -> Dictionary:
	for it in items:
		if it["id"] == id: return it
	return {}

func visible_items_for(target: String, mature_ok := false, owner_override := false) -> Array:
	var out: Array = []
	for it in items:
		if bool(it.get("mature", false)) and not mature_ok: continue
		var f := str(it.get("for", "any"))
		var owner_ok := f == "owner" and target == "player" and (owner_override or Profile.is_owner())
		if f == "any" or f == target or owner_ok:
			out.append(it)
	return out

func items_for(target: String) -> Array:
	return visible_items_for(target, Settings.mature_enabled())

func equip(target: String, id: String) -> void:
	var it := item(id)
	if it.is_empty(): return
	if bool(it.get("mature", false)) and not Settings.mature_enabled(): return
	var slots: Dictionary = equipped.get(target, {})
	if slots.get(it["slot"], "") == id: slots.erase(it["slot"])  # tap again = unequip
	else: slots[it["slot"]] = id
	equipped[target] = slots
	_save()
	equipped_changed.emit(target)

func is_equipped(target: String, id: String) -> bool:
	return equipped.get(target, {}).values().has(id)

## Merge equipped items' style colors over a base HumanoidModel style.
func styled(target: String, base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	var slots: Dictionary = equipped.get(target, {})
	for slot in ["outfit", "accent"]:
		var it := item(str(slots.get(slot, "")))
		if it.is_empty(): continue
		if bool(it.get("mature", false)) and not Settings.mature_enabled(): continue
		for k in it.get("style", {}):
			out[k] = Color(str(it["style"][k]))
	return out

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(equipped))
