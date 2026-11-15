@tool
class_name MalfunctionDef
extends Resource

@export var id: StringName = &""
@export var title: String = "":
	get:
		return tr(title)
## %part% se reemplaza por el nombre de la pieza.
@export_multiline var text: String = "":
	get:
		return tr(text)
## Tipos de pieza a los que aplica; vacio = generica.
@export var kinds: Array[StringName] = []
@export var choices: Array[ChoiceDef] = []
