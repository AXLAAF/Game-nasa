@tool
class_name BodyDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = "":
	get:
		return tr(display_name)
@export_multiline var description: String = "":
	get:
		return tr(description)
@export var color: Color = Color.WHITE
@export var atmo_color: Color = Color(0.5, 0.7, 1.0, 0.35)
@export var is_star: bool = false
@export var is_home: bool = false
@export var parent_id: StringName = &""
@export var orbit_radius: float = 0.0 ## unidades de juego
@export var orbit_phase: float = 0.0
@export var radius: float = 30.0
@export var mu: float = 40000.0
@export var surface_gravity: float = 9.81 ## m/s2 para despegue y descenso
@export var atmosphere: float = 1.0 ## densidad relativa, 0 = vacio
@export var landable: bool = true
## heat, cold, radiation, dust, storms
@export var hazards: Array[StringName] = []
@export var payout: float = 1.0
