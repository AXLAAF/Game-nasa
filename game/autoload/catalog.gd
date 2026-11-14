extends Node

const ROOT := "res://content"

var parts: Dictionary = {}
var bodies: Dictionary = {}
var encounters: Dictionary = {}
var malfunctions: Dictionary = {}


func _ready() -> void:
	_scan(ROOT)


func _scan(path: String) -> void:
	for dir_name: String in DirAccess.get_directories_at(path):
		_scan(path.path_join(dir_name))
	for file_name: String in DirAccess.get_files_at(path):
		var clean := file_name.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			_register(load(path.path_join(clean)))


func _register(res: Resource) -> void:
	if res is PartDef:
		parts[res.id] = res
	elif res is BodyDef:
		bodies[res.id] = res
	elif res is EncounterDef:
		encounters[res.id] = res
	elif res is MalfunctionDef:
		malfunctions[res.id] = res


func part(id: StringName) -> PartDef:
	return parts.get(id) as PartDef


func body(id: StringName) -> BodyDef:
	return bodies.get(id) as BodyDef


func part_list() -> Array[PartDef]:
	var list: Array[PartDef] = []
	for def: PartDef in parts.values():
		list.append(def)
	list.sort_custom(func(a: PartDef, b: PartDef) -> bool: return a.cost < b.cost)
	return list


func body_list() -> Array[BodyDef]:
	var list: Array[BodyDef] = []
	for def: BodyDef in bodies.values():
		list.append(def)
	return list


func star() -> BodyDef:
	for def: BodyDef in bodies.values():
		if def.is_star:
			return def
	return null


func home() -> BodyDef:
	for def: BodyDef in bodies.values():
		if def.is_home:
			return def
	return null


func encounters_for(poi: StringName, rarity: int) -> Array[EncounterDef]:
	var list: Array[EncounterDef] = []
	for def: EncounterDef in encounters.values():
		if def.poi == poi and def.rarity == rarity:
			list.append(def)
	if list.is_empty():
		for def: EncounterDef in encounters.values():
			if def.poi == poi:
				list.append(def)
	return list


func malfunctions_for(kind: StringName) -> Array[MalfunctionDef]:
	var list: Array[MalfunctionDef] = []
	var generic: Array[MalfunctionDef] = []
	for def: MalfunctionDef in malfunctions.values():
		if def.kinds.has(kind):
			list.append(def)
		elif def.kinds.is_empty():
			generic.append(def)
	return list if not list.is_empty() else generic
