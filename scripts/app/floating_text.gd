class_name FloatingText
extends RefCounted
## v0.9 floating-text declutter: every in-world Label3D (nameplates, titlers, signs,
## radio/helper labels) is hidden unless Settings ui/show_labels is on. Chat bubbles stay
## (they only appear while a companion is speaking).
const KEEP := ["ChatBubble"]

static func enabled() -> bool:
	return bool(Settings.get_value("ui", "show_labels", false))

static func set_enabled(on: bool, tree: SceneTree) -> void:
	Settings.set_value("ui", "show_labels", on)
	apply(tree)

static func apply(tree: SceneTree) -> int:
	var on := enabled()
	var n := 0
	for l in tree.root.find_children("*", "Label3D", true, false):
		if str(l.name) in KEEP: continue
		l.visible = on
		n += 1
	return n
