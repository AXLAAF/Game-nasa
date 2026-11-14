@tool
class_name EncounterDef
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var text: String = ""
## asteroid, derelict, signal, comet, moon
@export var poi: StringName = &"signal"
## 0 comun, 1 rara, 2 legendaria
@export var rarity: int = 0
@export var choices: Array[ChoiceDef] = []
