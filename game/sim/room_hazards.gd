class_name RoomHazards
extends RefCounted

const CRITICAL_WINDOW_S := 5.0

const ROOM_TO_ZONE: Dictionary = {
	&"helm": &"top",
	&"sensors": &"top",
	&"reactor": &"middle",
	&"life_support": &"middle",
	&"engines": &"bottom",
	&"science_bay": &"radial",
}

var rooms: Dictionary = {}


func _init() -> void:
	for room_id: StringName in ROOM_TO_ZONE.keys():
		rooms[room_id] = {
			"id": room_id,
			"zone": ROOM_TO_ZONE[room_id],
			"hp": 1.0,
			"oxygen": 1.0,
			"fire": 0.0,
			"breach": 0.0,
			"airlock_open": false,
			"critical_active": false,
			"critical_timer_s": 0.0,
		}


func get_room(room_id: StringName) -> Dictionary:
	return rooms.get(room_id, {})


func rooms_in_zone(zone: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for room_id: StringName in ROOM_TO_ZONE.keys():
		if ROOM_TO_ZONE[room_id] == zone:
			out.append(room_id)
	return out


func set_airlock(room_id: StringName, open: bool) -> void:
	if rooms.has(room_id):
		rooms[room_id]["airlock_open"] = open


func trigger_hazard(room_id: StringName, hp_loss: float, fire_add: float, breach_add: float, start_crisis: bool = true) -> void:
	if not rooms.has(room_id):
		return
	var r: Dictionary = rooms[room_id]
	r["hp"] = clampf(float(r["hp"]) - maxf(hp_loss, 0.0), 0.0, 1.0)
	r["fire"] = clampf(float(r["fire"]) + maxf(fire_add, 0.0), 0.0, 1.0)
	r["breach"] = clampf(float(r["breach"]) + maxf(breach_add, 0.0), 0.0, 1.0)
	if start_crisis and (float(r["fire"]) > 0.1 or float(r["breach"]) > 0.1):
		r["critical_active"] = true
		r["critical_timer_s"] = CRITICAL_WINDOW_S


static func classify_impact_severity(energy_j: float) -> String:
	if energy_j < 2000.0:
		return "leve"
	if energy_j < 8000.0:
		return "grave"
	if energy_j < 20000.0:
		return "critica"
	return "catastrofica"


func apply_impact_zone(zone: StringName, impact_energy: float, rng: RandomNumberGenerator = null) -> Dictionary:
	var severity := classify_impact_severity(impact_energy)
	var candidates := rooms_in_zone(zone)
	var target_room: StringName = candidates[0] if not candidates.is_empty() else &"reactor"
	if candidates.size() > 1 and rng != null:
		target_room = candidates[rng.randi_range(0, candidates.size() - 1)]

	var hp_loss := 0.12
	var fire_chance := 0.20
	var breach_chance := 0.15
	match severity:
		"grave":
			hp_loss = 0.28
			fire_chance = 0.40
			breach_chance = 0.30
		"critica":
			hp_loss = 0.50
			fire_chance = 0.65
			breach_chance = 0.55
		"catastrofica":
			hp_loss = 0.85
			fire_chance = 0.85
			breach_chance = 0.80

	if zone == &"radial":
		breach_chance = clampf(breach_chance + 0.15, 0.0, 1.0)
	elif zone == &"bottom":
		fire_chance = clampf(fire_chance + 0.15, 0.0, 1.0)

	var roll_fire := rng.randf() if rng != null else 0.0
	var roll_breach := rng.randf() if rng != null else 0.0
	var fire_add := 0.45 if roll_fire <= fire_chance else 0.0
	var breach_add := 0.45 if roll_breach <= breach_chance else 0.0
	trigger_hazard(target_room, hp_loss, fire_add, breach_add, fire_add > 0.0 or breach_add > 0.0)

	return {
		"room_id": target_room,
		"zone": zone,
		"severity": severity,
		"fire_added": fire_add,
		"breach_added": breach_add,
	}


func repair_room(room_id: StringName, dt: float, rate: float = 0.45) -> bool:
	if not rooms.has(room_id) or dt <= 0.0:
		return false
	var r: Dictionary = rooms[room_id]
	var changed := false
	if float(r["fire"]) > 0.0:
		r["fire"] = maxf(float(r["fire"]) - rate * dt, 0.0)
		changed = true
	if float(r["breach"]) > 0.0:
		r["breach"] = maxf(float(r["breach"]) - rate * dt, 0.0)
		changed = true
	if float(r["hp"]) < 1.0 and float(r["fire"]) <= 0.05 and float(r["breach"]) <= 0.05:
		r["hp"] = minf(float(r["hp"]) + rate * 0.7 * dt, 1.0)
		changed = true
	if float(r["fire"]) <= 0.05 and float(r["breach"]) <= 0.05:
		r["critical_active"] = false
		r["critical_timer_s"] = 0.0
	return changed


func kick_repair(room_id: StringName, rng: RandomNumberGenerator) -> StringName:
	if not rooms.has(room_id):
		return &"none"
	var r: Dictionary = rooms[room_id]
	var needs_work := float(r["fire"]) > 0.05 or float(r["breach"]) > 0.05 or float(r["hp"]) < 0.99
	if not needs_work:
		return &"none"
	var roll := rng.randf()
	if roll < 0.55:
		r["fire"] = 0.0
		r["breach"] = 0.0
		r["hp"] = minf(float(r["hp"]) + 0.35, 1.0)
		r["critical_active"] = false
		r["critical_timer_s"] = 0.0
		return &"fixed"
	if roll < 0.80:
		r["hp"] = maxf(float(r["hp"]) - 0.25, 0.0)
		r["fire"] = minf(float(r["fire"]) + 0.25, 1.0)
		return &"worse"
	return &"nothing"


func damage_bars_for(room_id: StringName, max_bars: int) -> int:
	if not rooms.has(room_id):
		return 0
	var hp := float(rooms[room_id]["hp"])
	if hp >= 0.70:
		return 0
	if hp >= 0.35:
		return mini(1, max_bars)
	return max_bars


func step(dt: float, life_support_eff: float, crew_in_rooms: Dictionary = {}) -> Dictionary:
	var expired_crises: Array[StringName] = []
	var suffocating_rooms: Array[StringName] = []
	var vented_fires: Array[StringName] = []
	var fuel_leak_rate := 0.0

	for room_id: StringName in rooms.keys():
		var r: Dictionary = rooms[room_id]
		var fire := float(r["fire"])
		var breach := float(r["breach"])
		var o2 := float(r["oxygen"])
		var airlock := bool(r["airlock_open"])

		if airlock:
			o2 = maxf(o2 - 0.60 * dt, 0.0)
		else:
			if breach > 0.0:
				o2 = maxf(o2 - 0.32 * breach * dt, 0.0)
			if fire > 0.0:
				o2 = maxf(o2 - 0.14 * fire * dt, 0.0)
			if life_support_eff > 0.0 and breach <= 0.05:
				o2 = minf(o2 + 0.22 * life_support_eff * dt, 1.0)

		if fire > 0.0:
			if o2 < 0.15:
				fire = maxf(fire - 0.85 * dt, 0.0)
				if fire <= 0.01:
					vented_fires.append(room_id)
					if breach <= 0.05:
						r["critical_active"] = false
						r["critical_timer_s"] = 0.0
			else:
				r["hp"] = maxf(float(r["hp"]) - 0.08 * fire * dt, 0.0)

		if bool(r["critical_active"]):
			var rem := float(r["critical_timer_s"]) - dt
			if rem <= 0.0:
				r["critical_active"] = false
				r["critical_timer_s"] = 0.0
				expired_crises.append(room_id)
				r["hp"] = maxf(float(r["hp"]) - 0.25, 0.0)
			else:
				r["critical_timer_s"] = rem

		if room_id == &"engines" and (breach > 0.1 or float(r["hp"]) < 0.5):
			fuel_leak_rate += 0.25

		if bool(crew_in_rooms.get(room_id, false)) and o2 < 0.20:
			suffocating_rooms.append(room_id)

		r["oxygen"] = o2
		r["fire"] = fire

	return {
		"expired_crises": expired_crises,
		"suffocating_rooms": suffocating_rooms,
		"vented_fires": vented_fires,
		"fuel_leak_rate": fuel_leak_rate,
	}
