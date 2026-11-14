@tool
class_name PartDef
extends Resource

## kind: engine, tank, capsule, decoupler, heatshield, parachute, legs, radiator,
## insulation, solar, rtg, battery, antenna, computer, sensor, shielding, rcs, escape
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: StringName = &"tank"
@export var radial: bool = false
@export var cost: int = 100
@export var mass: float = 1.0 ## toneladas, en seco
@export var fuel: float = 0.0 ## toneladas de propelente
@export var thrust: float = 0.0 ## kN
@export var isp: float = 0.0 ## s
@export var size: Vector2 = Vector2(40, 30) ## px a escala 1 (1 px = 0.25 m)
@export var color: Color = Color(0.8, 0.82, 0.88)
@export var fragility: float = 1.0
@export var heat_resist: float = 0.0
@export var cold_resist: float = 0.0
@export var rad_resist: float = 0.0
@export var cooling: float = 0.0
@export var solar: float = 0.0
@export var power: float = 0.0
@export var battery: float = 0.0
@export var ablative: float = 0.0
@export var drag: float = 0.0 ## m2 de paracaidas principal
## Canales de sistema que esta pieza sostiene (map, vision, comms, mobility, light).
@export var channels: Array[StringName] = []
