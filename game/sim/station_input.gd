class_name StationInput
extends RefCounted

enum Mode { SOLO, COOP_LOCAL }

const STATIONS: Array[StringName] = [&"pilot", &"radar", &"engineer", &"mission"]

var mode: int = Mode.SOLO
var active_solo_station: StringName = &"pilot"


func set_mode(new_mode: int) -> void:
	mode = new_mode


func select_solo_station(station: StringName) -> void:
	if station in STATIONS:
		active_solo_station = station


func cycle_solo_station() -> StringName:
	var idx := STATIONS.find(active_solo_station)
	active_solo_station = STATIONS[(idx + 1) % STATIONS.size()]
	return active_solo_station


static func empty_intent(is_autopilot: bool = false) -> Dictionary:
	return {
		"steer": Vector2.ZERO,
		"thrust": 0.0,
		"action": false,
		"vent": false,
		"autopilot": is_autopilot,
	}


## En modo SOLO, los puestos sin jugador humano devuelven piloto automatico degradado.
func build_station_intents(player_intents: Dictionary, autopilot_steer: Vector2 = Vector2.ZERO) -> Dictionary:
	var out: Dictionary = {}
	for st: StringName in STATIONS:
		if mode == Mode.COOP_LOCAL:
			out[st] = player_intents.get(st, empty_intent(false))
		else:
			if st == active_solo_station:
				out[st] = player_intents.get(st, empty_intent(false))
			else:
				var auto := empty_intent(true)
				if st == &"pilot":
					auto["steer"] = autopilot_steer * 0.45
					auto["thrust"] = 0.5
				elif st == &"engineer":
					auto["action"] = true # reparacion lenta automatica (40% en vuelo)
				out[st] = auto
	return out
