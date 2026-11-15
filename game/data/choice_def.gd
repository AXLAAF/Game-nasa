@tool
class_name ChoiceDef
extends Resource

## Efectos: explode, break, fix, wear, thrust, leak, fuel, credits, science, kits,
## battery, heat, salvage, boxes, rand_break, y canales (vision, map, comms, light, mobility, audio).
@export var label: String = "":
	get:
		return tr(label)
@export var odds: float = 1.0
@export var cost: Dictionary = {}
@export var win: Dictionary = {}
@export var lose: Dictionary = {}
@export var win_text: String = "":
	get:
		return tr(win_text)
@export var lose_text: String = "":
	get:
		return tr(lose_text)
## asteroids, drill, dock: el resultado lo decide el minijuego en lugar de la tirada.
@export var minigame: StringName = &""
