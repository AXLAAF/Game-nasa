@tool
class_name MalfunctionDef
extends Resource

@export var id: StringName = &""
@export var title: String = ""
## %part% se reemplaza por el nombre de la pieza.
@export_multiline var text: String = ""
## Tipos de pieza a los que aplica; vacio = generica.
@export var kinds: Array[StringName] = []
@export var choices: Array[ChoiceDef] = []
