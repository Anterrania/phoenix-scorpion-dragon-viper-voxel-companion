# INACTIVE (2026-10-17): v0.2 minimal CanvasLayer chat. No scene uses it; chat lives in scripts/ui/ui_root.gd (Chat panel) since v0.5. Re-enable if a standalone debug chat overlay is wanted (needs a scene with $Panel/VBox/Log + Input).
# Kept as comments (not deleted) per Phoenix's cleanup rule; see docs/AUDIT_2026-10-17.md §2.
# Only the `extends` line stays live so the file still parses in the script-load test.

extends CanvasLayer
# ## Minimal text chat with the nearest companion.
#
# @export var companion_path: NodePath
# @onready var log_label: RichTextLabel = $Panel/VBox/Log
# @onready var input: LineEdit = $Panel/VBox/Input
# var companion: Node
#
# func _ready() -> void:
# 	companion = get_node_or_null(companion_path)
# 	input.text_submitted.connect(_send)
# 	if companion:
# 		companion.said.connect(func(t): log_label.append_text("[color=#ff8de8]%s:[/color] %s\n" % [companion.persona.get("name", "Companion"), t]))
# 	AgentBrain.request_failed.connect(func(_id, e): log_label.append_text("[color=red]%s[/color]\n" % e))
#
# func _send(t: String) -> void:
# 	if t.strip_edges() == "" or companion == null:
# 		return
# 	log_label.append_text("[b]You:[/b] %s\n" % t)
# 	input.clear()
# 	companion.talk(t)
