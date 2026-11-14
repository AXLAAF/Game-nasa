class_name ReactorPower
extends RefCounted

const SYSTEMS: Array[StringName] = [
	&"helm",
	&"engines",
	&"sensors",
	&"shields_thermal",
	&"life_support",
	&"science_bay",
]

var total_bars: int = 7
var _systems: Dictionary = {}


func _init(initial_total_bars: int = 7) -> void:
	total_bars = maxi(initial_total_bars, 1)
	for sys_id: StringName in SYSTEMS:
		_systems[sys_id] = {
			"max_bars": 3 if sys_id in [&"engines", &"shields_thermal"] else 2,
			"allocated": 1,
			"damage_bars": 0,
			"manned": false,
		}
	# Ajuste inicial para no exceder total_bars
	_systems[&"science_bay"]["allocated"] = 0
	if used_bars() > total_bars:
		rebalance_excess()


func used_bars() -> int:
	var sum := 0
	for sys_id: StringName in SYSTEMS:
		sum += int(_systems[sys_id]["allocated"])
	return sum


func available_bars() -> int:
	return maxi(total_bars - used_bars(), 0)


func max_usable_bars(sys_id: StringName) -> int:
	if not _systems.has(sys_id):
		return 0
	var s: Dictionary = _systems[sys_id]
	return maxi(int(s["max_bars"]) - int(s["damage_bars"]), 0)


func allocate(sys_id: StringName, delta: int) -> bool:
	if not _systems.has(sys_id) or delta == 0:
		return false
	var s: Dictionary = _systems[sys_id]
	var cur := int(s["allocated"])
	if delta > 0:
		var room := mini(available_bars(), max_usable_bars(sys_id) - cur)
		if room <= 0:
			return false
		s["allocated"] = cur + mini(delta, room)
		return true
	var sub := mini(cur, -delta)
	if sub <= 0:
		return false
	s["allocated"] = cur - sub
	return true


func set_damage_bars(sys_id: StringName, dmg: int) -> void:
	if not _systems.has(sys_id):
		return
	var s: Dictionary = _systems[sys_id]
	s["damage_bars"] = clampi(dmg, 0, int(s["max_bars"]))
	var cap := max_usable_bars(sys_id)
	if int(s["allocated"]) > cap:
		s["allocated"] = cap


func set_total_bars(new_total: int) -> void:
	total_bars = maxi(new_total, 0)
	rebalance_excess()


func rebalance_excess() -> void:
	var idx := SYSTEMS.size() - 1
	while used_bars() > total_bars and idx >= 0:
		var sys_id := SYSTEMS[idx]
		var cur := int(_systems[sys_id]["allocated"])
		if cur > 0:
			_systems[sys_id]["allocated"] = cur - 1
		else:
			idx -= 1


func set_manned(sys_id: StringName, is_manned: bool) -> void:
	if _systems.has(sys_id):
		_systems[sys_id]["manned"] = is_manned


func is_manned(sys_id: StringName) -> bool:
	if not _systems.has(sys_id):
		return false
	return bool(_systems[sys_id]["manned"])


func effective_bars(sys_id: StringName) -> int:
	if not _systems.has(sys_id):
		return 0
	return mini(int(_systems[sys_id]["allocated"]), max_usable_bars(sys_id))


func manning_bonus(sys_id: StringName) -> float:
	if effective_bars(sys_id) <= 0:
		return 0.0
	return 0.25 if is_manned(sys_id) else 0.0


func efficiency(sys_id: StringName) -> float:
	if not _systems.has(sys_id):
		return 0.0
	var max_b := float(int(_systems[sys_id]["max_bars"]))
	if max_b <= 0.0:
		return 0.0
	var base := float(effective_bars(sys_id)) / max_b
	if base <= 0.0:
		return 0.0
	return clampf(base + manning_bonus(sys_id), 0.0, 1.25)


func snapshot() -> Dictionary:
	return {
		"total_bars": total_bars,
		"used_bars": used_bars(),
		"available_bars": available_bars(),
		"systems": _systems.duplicate(true),
	}
