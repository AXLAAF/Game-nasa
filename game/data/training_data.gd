class_name TrainingData
extends RefCounted

static func create_session() -> TrainingSession:
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/design/training.json"))
	_localize(design)
	var earth: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/nasa/training_earth.json"))
	var body := BodyDef.new()
	body.id = &"earth"
	body.display_name = earth.name
	body.surface_gravity = earth.gravity_m_s2
	body.radius = design.body_radius
	body.atmosphere = design.atmosphere
	var parts: Dictionary = {}
	for id: String in design.catalog:
		parts[id] = load("res://content/parts/%s.tres" % id)
	return TrainingSession.new(design, body, parts)


## Los textos del JSON estan en espanol (msgid de localization/en.po): se pasan al idioma activo al cargar
## la sesion. El idioma solo cambia en el titulo y el hangar, asi que no hace falta rehacerlo despues.
static func _localize(design: Dictionary) -> void:
	for step: Dictionary in design.get("recipe", []):
		for key: String in ["title", "why"]:
			if step.has(key):
				step[key] = Loc.t(str(step[key]))
	for lesson: Dictionary in design.get("lessons", {}).values():
		for key: String in ["title", "text"]:
			if lesson.has(key):
				lesson[key] = Loc.t(str(lesson[key]))
