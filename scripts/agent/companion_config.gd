class_name CompanionConfig
extends Resource
## Per-character resource. Points at the portable persona.json shared with the
## standalone chat bot; adds Godot-only presentation settings.

@export var persona_path: String = "res://companions/foxy_ani/persona.json"
@export var body_color: Color = Color(0.6, 0.2, 0.8)
@export var accent_color: Color = Color(0.2, 1.0, 0.4)
@export var emissive: float = 0.0
@export var move_speed: float = 4.5
@export var follow_distance: float = 3.0
