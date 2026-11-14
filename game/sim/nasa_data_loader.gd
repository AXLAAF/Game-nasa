class_name NasaDataLoader
extends RefCounted

const PATH_PLANETS := "res://data/nasa/planetary_catalog.json"
const PATH_NEOS := "res://data/nasa/neo_curated_missions.json"
const PATH_SOLAR := "res://data/nasa/solar_events_scenarios.json"
const PATH_DEBRIS := "res://data/nasa/debris_leo_catalog.json"

var planetary_data: Dictionary = {}
var neo_data: Dictionary = {}
var solar_data: Dictionary = {}
var debris_data: Dictionary = {}


static func load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func load_all() -> bool:
	planetary_data = load_json_file(PATH_PLANETS)
	neo_data = load_json_file(PATH_NEOS)
	solar_data = load_json_file(PATH_SOLAR)
	debris_data = load_json_file(PATH_DEBRIS)
	return not planetary_data.is_empty() and not neo_data.is_empty() and not solar_data.is_empty() and not debris_data.is_empty()


func get_contracts() -> Array:
	var out: Array = []
	for item: Variant in planetary_data.get("bodies", []):
		if item is Dictionary and str(item.get("role", "")) == "contract":
			out.append(item)
	return out


func get_body(body_id: String) -> Dictionary:
	for item: Variant in planetary_data.get("bodies", []):
		if item is Dictionary and str(item.get("id", "")) == body_id:
			return item
	return {}


func get_asteroids() -> Array:
	return neo_data.get("asteroids", [])


func get_solar_events() -> Array:
	return solar_data.get("events", [])


func get_debris_regimes() -> Array:
	return debris_data.get("regimes", [])


func dsn_one_way_latency_s(body_id: String) -> float:
	var b := get_body(body_id)
	return float(b.get("dsn_rtlt_s", 0.0)) * 0.5


static func solar_factor(au: float) -> float:
	var r := maxf(au, 0.2)
	return 1.0 / (r * r)


func solar_irradiance_at_body(body_id: String) -> float:
	var b := get_body(body_id)
	var au := float(b.get("semi_major_axis_au", 1.0))
	return 1361.0 * solar_factor(au)


func source_citations() -> Array[Dictionary]:
	var citations: Array[Dictionary] = []
	for d: Dictionary in [planetary_data, neo_data, solar_data, debris_data]:
		if not d.is_empty():
			citations.append({
				"source": str(d.get("source", "")),
				"url": str(d.get("source_url", "")),
			})
	return citations
