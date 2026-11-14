class_name CrewController
extends RefCounted

const CREW_IDS: Array[StringName] = [&"pilot", &"radar", &"engineer", &"mission"]

# Coordenadas locales exactas dentro del sprite 160x224 de interior_floor_6rooms.png
const ROOM_CENTERS: Dictionary = {
	&"sensors": Vector2(48.0, 38.0),
	&"helm": Vector2(96.0, 38.0),
	&"life_support": Vector2(28.0, 95.0),
	&"reactor": Vector2(72.0, 95.0),
	&"science_bay": Vector2(122.0, 95.0),
	&"engines": Vector2(80.0, 156.0),
}

const ROOM_NEIGHBORS: Dictionary = {
	&"sensors": [&"helm", &"reactor"],
	&"helm": [&"sensors", &"reactor"],
	&"life_support": [&"reactor"],
	&"reactor": [&"sensors", &"helm", &"life_support", &"science_bay", &"engines"],
	&"science_bay": [&"reactor"],
	&"engines": [&"reactor"],
}

const CREW_STATION_SYSTEM: Dictionary = {
	&"pilot": {"room": &"helm", "system": &"helm"},
	&"radar": {"room": &"sensors", "system": &"sensors"},
	&"engineer": {"room": &"engines", "system": &"engines"},
	&"mission": {"room": &"science_bay", "system": &"science_bay"},
}

var crew: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	var starts := {
		&"pilot": &"helm",
		&"radar": &"sensors",
		&"engineer": &"reactor",
		&"mission": &"science_bay",
	}
	for cid: StringName in CREW_IDS:
		var r: StringName = starts[cid]
		crew[cid] = {
			"id": cid,
			"room": r,
			"pos": ROOM_CENTERS[r],
			"path": [] as Array[StringName],
			"hp": 1.0,
			"hypoxia": false,
			"repairing": false,
		}


func find_path(from_room: StringName, to_room: StringName) -> Array[StringName]:
	if from_room == to_room or not ROOM_NEIGHBORS.has(from_room):
		return []
	var queue: Array[Array] = [[from_room]]
	var visited: Dictionary = {from_room: true}
	while not queue.is_empty():
		var cur_path: Array = queue.pop_front()
		var node: StringName = cur_path[cur_path.size() - 1]
		for nxt: StringName in ROOM_NEIGHBORS.get(node, []):
			if nxt == to_room:
				var out: Array[StringName] = []
				for idx: int in range(1, cur_path.size()):
					out.append(cur_path[idx])
				out.append(nxt)
				return out
			if not visited.has(nxt):
				visited[nxt] = true
				var next_path := cur_path.duplicate()
				next_path.append(nxt)
				queue.append(next_path)
	return []


func command_move(crew_id: StringName, target_room: StringName) -> bool:
	if not crew.has(crew_id) or not ROOM_CENTERS.has(target_room):
		return false
	var c: Dictionary = crew[crew_id]
	if c["room"] == target_room and (c["path"] as Array).is_empty():
		return false
	var path := find_path(c["room"], target_room)
	if path.is_empty() and c["room"] != target_room:
		return false
	c["path"] = path
	return true


func station_crew_map() -> Dictionary:
	var rooms_occupied: Dictionary = {}
	for cid: StringName in CREW_IDS:
		var c: Dictionary = crew[cid]
		if (c["path"] as Array).is_empty():
			rooms_occupied[c["room"]] = true
	return rooms_occupied


func step(dt: float, hazards: RoomHazards, reactor: ReactorPower, active_station: StringName, solo_mode: bool) -> void:
	# En modo SOLO, el ingeniero automatico acude lento a salas con peligro
	if solo_mode and active_station != &"engineer":
		var eng: Dictionary = crew[&"engineer"]
		if (eng["path"] as Array).is_empty():
			var cur_room: StringName = eng["room"]
			var cur_data := hazards.get_room(cur_room)
			if float(cur_data.get("fire", 0.0)) <= 0.05 and float(cur_data.get("breach", 0.0)) <= 0.05:
				for rid: StringName in hazards.rooms.keys():
					var rd := hazards.get_room(rid)
					if float(rd["fire"]) > 0.1 or float(rd["breach"]) > 0.1:
						command_move(&"engineer", rid)
						break

	var move_speed := 84.0
	for cid: StringName in CREW_IDS:
		var c: Dictionary = crew[cid]
		var path: Array = c["path"]
		c["repairing"] = false
		if not path.is_empty():
			var next_room: StringName = path[0]
			var target_pos: Vector2 = ROOM_CENTERS[next_room]
			var pos: Vector2 = c["pos"]
			var to_target := target_pos - pos
			var dist := to_target.length()
			var step_len := move_speed * dt
			if dist <= step_len:
				c["pos"] = target_pos
				c["room"] = next_room
				path.pop_front()
			else:
				c["pos"] = pos + to_target.normalized() * step_len
		else:
			var r_id: StringName = c["room"]
			var rd := hazards.get_room(r_id)
			if not rd.is_empty():
				var has_damage := float(rd["fire"]) > 0.02 or float(rd["breach"]) > 0.02 or float(rd["hp"]) < 0.99
				if has_damage:
					var is_human := (not solo_mode) or (cid == active_station)
					var rep_rate := 0.55 if is_human else 0.22 # 40% efectivo para bot automatico
					if cid == &"engineer":
						rep_rate *= 1.35
					hazards.repair_room(r_id, dt, rep_rate)
					c["repairing"] = true

				if float(rd["oxygen"]) < 0.20:
					c["hypoxia"] = true
					c["hp"] = maxf(float(c["hp"]) - 0.10 * dt, 0.1)
				else:
					c["hypoxia"] = false
					c["hp"] = minf(float(c["hp"]) + 0.06 * dt, 1.0)

	# Actualizar Manning Bonus en ReactorPower segun quien esta en consola sin fuego activo
	var occ := station_crew_map()
	for sys_id: StringName in ReactorPower.SYSTEMS:
		reactor.set_manned(sys_id, false)
	for room_id: StringName in [&"helm", &"sensors", &"engines", &"science_bay", &"life_support"]:
		if bool(occ.get(room_id, false)):
			var rd := hazards.get_room(room_id)
			if float(rd.get("fire", 0.0)) < 0.15 and float(rd.get("oxygen", 1.0)) >= 0.25:
				if room_id == &"life_support":
					reactor.set_manned(&"life_support", true)
					reactor.set_manned(&"shields_thermal", true)
				else:
					reactor.set_manned(room_id, true)
