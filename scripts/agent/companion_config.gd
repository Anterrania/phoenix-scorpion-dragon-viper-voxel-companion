class_name CompanionConfig
extends Resource
## Per-character resource. Points at the portable persona.json shared with the
## standalone chat bot; adds Godot-only presentation settings.

@export var persona_path: String = "res://companions/foxy_ani/persona.json"
@export var body_color: Color = Color(0.6, 0.2, 0.8)   ## outfit color
@export var accent_color: Color = Color(0.2, 1.0, 0.4)
@export var emissive: float = 0.0
@export var move_speed: float = 4.5
@export var follow_distance: float = 3.0
@export_group("Model (v0.2)")
@export var look: String = "classic"   ## fire | classic | chrome | royal
@export var skin_color: Color = Color(0.96, 0.8, 0.7)
@export var hair_color: Color = Color(0.5, 0.2, 0.7)
@export var eye_color: Color = Color(0.2, 1.0, 0.4)
@export var trim_color: Color = Color(1.0, 0.76, 0.23)
@export var pants_color: Color = Color(0, 0, 0, 0)   ## alpha 0 = same as outfit
@export var pants_glow: float = 0.0
@export var skin_metal: float = 0.0
@export var horns := false
@export var curly := false
@export var chains := false
## Formation slot relative to the player's facing (-Z = in front of the player).
@export var slot_offset: Vector3 = Vector3(2.5, 0, -3)

func style() -> Dictionary:
	return {"skin": skin_color, "hair": hair_color, "eyes": eye_color, "outfit": body_color,
		"accent": accent_color, "trim": trim_color, "look": look, "glow": maxf(emissive, 0.8),
		"pants": pants_color if pants_color.a > 0.0 else body_color, "pants_glow": pants_glow,
		"skin_metal": skin_metal, "horns": horns, "curly": curly, "chains": chains}
