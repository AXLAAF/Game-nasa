class_name TrainingData
extends RefCounted

static func create_session() -> TrainingSession:
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/design/training.json"))
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
