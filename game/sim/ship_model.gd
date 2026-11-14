class_name ShipModel
extends RefCounted

## Piezas ordenadas de abajo hacia arriba. Un desacoplador cierra la etapa de abajo
## y se suelta con ella. Los motores solo beben de los tanques de su etapa.

const G0 := 9.81

var parts: Array[ShipPart] = []


func stages() -> Array:
	var out: Array = []
	var current: Array = []
	for part: ShipPart in parts:
		current.append(part)
		if part.def.kind == &"decoupler":
			out.append(current)
			current = []
	out.append(current)
	return out


func active_stage() -> Array:
	return stages()[0]


func mass() -> float:
	var total := 0.0
	for part: ShipPart in parts:
		total += part.def.mass + part.fuel
	return total


func dry_mass() -> float:
	var total := 0.0
	for part: ShipPart in parts:
		total += part.def.mass
	return total


func stage_thrust(stage: Array) -> float:
	var total := 0.0
	for part: ShipPart in stage:
		if part.def.kind == &"engine":
			total += part.thrust()
	return total


func stage_isp(stage: Array) -> float:
	var weighted := 0.0
	var total := 0.0
	for part: ShipPart in stage:
		if part.def.kind == &"engine" and not part.broken:
			weighted += part.thrust() * part.def.isp
			total += part.thrust()
	return weighted / total if total > 0.0 else 0.0


func stage_fuel(stage: Array) -> float:
	var total := 0.0
	for part: ShipPart in stage:
		total += part.fuel
	return total


func thrust() -> float:
	return stage_thrust(active_stage())


func fuel_total() -> float:
	var total := 0.0
	for part: ShipPart in parts:
		total += part.fuel
	return total


func fuel_capacity() -> float:
	var total := 0.0
	for part: ShipPart in parts:
		total += part.def.fuel * part.boost
	return total


## Quema la etapa activa durante dt segundos. Devuelve la aceleracion en m/s2.
func burn(throttle: float, dt: float, isp_mult: float = 1.0) -> float:
	var stage := active_stage()
	var force := stage_thrust(stage) * throttle
	var isp := stage_isp(stage) * isp_mult
	var fuel := stage_fuel(stage)
	if force <= 0.0 or isp <= 0.0 or fuel <= 0.0:
		return 0.0
	var want := force / (isp * G0) * dt
	var used := minf(want, fuel)
	var m := mass()
	for part: ShipPart in stage:
		if part.fuel > 0.0:
			part.fuel = maxf(part.fuel - used * part.fuel / fuel, 0.0)
	return force / m * (used / want)


func leak(fraction: float) -> void:
	for part: ShipPart in parts:
		part.fuel *= clampf(1.0 - fraction, 0.0, 1.0)


func refuel(fraction: float) -> void:
	for part: ShipPart in parts:
		var cap := part.def.fuel * part.boost
		part.fuel = minf(part.fuel + cap * fraction, cap)


func stage_dvs() -> Array[float]:
	var list := stages()
	var out: Array[float] = []
	for i: int in list.size():
		var above := 0.0
		for j: int in range(i, list.size()):
			for part: ShipPart in list[j]:
				above += part.def.mass + part.fuel
		var fuel := stage_fuel(list[i])
		var isp := stage_isp(list[i])
		if isp <= 0.0 or fuel <= 0.0 or above <= fuel:
			out.append(0.0)
			continue
		out.append(isp * G0 * log(above / (above - fuel)))
	return out


func delta_v() -> float:
	var total := 0.0
	for dv: float in stage_dvs():
		total += dv
	return total


func twr(gravity: float) -> float:
	var m := mass()
	return thrust() / (m * gravity) if m > 0.0 else 0.0


func stage_twr(index: int, gravity: float) -> float:
	var list := stages()
	if index >= list.size():
		return 0.0
	var above := 0.0
	for j: int in range(index, list.size()):
		for part: ShipPart in list[j]:
			above += part.def.mass + part.fuel
	return stage_thrust(list[index]) / (above * gravity) if above > 0.0 else 0.0


func can_stage() -> bool:
	return stages().size() > 1


func drop_stage() -> Array:
	if not can_stage():
		return []
	var dropped: Array = active_stage()
	for part: ShipPart in dropped:
		parts.erase(part)
	return dropped


## Suelta etapas secas para que la de arriba tome el control.
func auto_stage() -> bool:
	var stage := active_stage()
	if can_stage() and (stage_fuel(stage) <= 0.001 or stage_thrust(stage) <= 0.0):
		var upper_has_engine := false
		for i: int in range(1, stages().size()):
			if stage_thrust(stages()[i]) > 0.0:
				upper_has_engine = true
		if upper_has_engine:
			drop_stage()
			return true
	return false


func has_kind(kind: StringName) -> bool:
	for part: ShipPart in parts:
		if part.def.kind == kind and not part.broken:
			return true
	return false


func of_kind(kind: StringName) -> Array[ShipPart]:
	var list: Array[ShipPart] = []
	for part: ShipPart in parts:
		if part.def.kind == kind:
			list.append(part)
	return list


func sum_stat(name: StringName) -> float:
	var total := 0.0
	for part: ShipPart in parts:
		total += part.stat(name)
	return total


func kind_channel(channel: StringName) -> float:
	var best := 0.0
	for part: ShipPart in parts:
		if part.def.channels.has(channel):
			best = maxf(best, part.output())
	return best


func kind_output(kind: StringName) -> float:
	var best := 0.0
	for part: ShipPart in parts:
		if part.def.kind == kind:
			best = maxf(best, part.output())
	return best


func capsule() -> ShipPart:
	for part: ShipPart in parts:
		if part.def.kind == &"capsule":
			return part
	return null


func zone_of(part: ShipPart) -> StringName:
	var index := parts.find(part)
	if index < 0 or parts.size() <= 1:
		return &"middle"
	var frac := float(index) / float(parts.size() - 1)
	if frac < 0.34:
		return &"bottom"
	if frac < 0.67:
		return &"middle"
	return &"top"


func parts_in_zone(zone: StringName) -> Array[ShipPart]:
	var list: Array[ShipPart] = []
	for part: ShipPart in parts:
		if zone_of(part) == zone:
			list.append(part)
	return list


## Deja solo la capsula, lo que va encima y su equipo de descenso.
func eject_capsule() -> bool:
	var pod := capsule()
	if pod == null:
		return false
	var keep: Array[ShipPart] = []
	var above := false
	for part: ShipPart in parts:
		if part == pod:
			above = true
		if above or part.def.kind == &"parachute" or part.def.kind == &"heatshield":
			keep.append(part)
	parts = keep
	return true


func width_px() -> float:
	var widest := 20.0
	for part: ShipPart in parts:
		if not part.def.radial:
			widest = maxf(widest, part.def.size.x)
	return widest


func height_px() -> float:
	var total := 0.0
	for part: ShipPart in parts:
		if not part.def.radial:
			total += part.def.size.y
	return total


## Area frontal en m2 (el dibujo exagera el tamano; 40 px ~ 2.4 m de diametro).
func area() -> float:
	var diameter := width_px() * 0.06
	return PI * diameter * diameter * 0.25


func value() -> int:
	var total := 0
	for part: ShipPart in parts:
		total += part.price()
	return total


func broken_parts() -> Array[ShipPart]:
	var list: Array[ShipPart] = []
	for part: ShipPart in parts:
		if part.broken:
			list.append(part)
	return list
