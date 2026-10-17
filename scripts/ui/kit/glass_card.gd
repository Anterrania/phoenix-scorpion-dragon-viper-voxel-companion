@tool
class_name GlassCard
extends PanelContainer
## Frosted glass card: shader backdrop + title. Put content in body() (Pad/VBox/Body).
@export var title := "Card": set = set_title
func set_title(t: String) -> void:
	title = t
	var l := get_node_or_null("Pad/VBox/Title")
	if l: l.text = t.to_upper()
func body() -> VBoxContainer: return $Pad/VBox/Body
func _ready() -> void:
	set_title(title)
	resized.connect(_sync); _sync()
func _sync() -> void:
	var m: ShaderMaterial = $Glass.material
	if m: m.set_shader_parameter("rect_size", size)
