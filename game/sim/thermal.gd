class_name Thermal
extends RefCounted

const HOME_R := 2000.0
const HOT := 0.85
const COLD := 0.15


static func flux(distance: float) -> float:
	var r := maxf(distance, 60.0)
	return (HOME_R / r) * (HOME_R / r)


## Temperatura de equilibrio normalizada: 0.5 comodo, >0.85 sobrecalentado, <0.15 congelado.
static func equilibrium(f: float, ship: ShipModel) -> float:
	var heat_resist := clampf(ship.sum_stat(&"heat_resist"), 0.0, 0.9)
	var cold_resist := clampf(ship.sum_stat(&"cold_resist"), 0.0, 0.95)
	var cooling := ship.sum_stat(&"cooling")
	var hot := maxf(f - 1.0, 0.0)
	var cold := clampf(1.0 - f, 0.0, 1.0)
	var hot_term := hot * 0.14 / (1.0 + cooling) * (1.0 - heat_resist * 0.7)
	var cold_term := cold * 0.5 * (1.0 - cold_resist)
	return clampf(0.5 + hot_term - cold_term, 0.0, 1.2)


static func power_gen(f: float, ship: ShipModel) -> float:
	return ship.sum_stat(&"solar") * minf(f, 2.5) + ship.sum_stat(&"power")


static func power_use(ship: ShipModel) -> float:
	var use := 0.35
	for part: ShipPart in ship.parts:
		if not part.broken and part.def.kind in [&"computer", &"sensor", &"antenna", &"capsule"]:
			use += 0.15
	return use


static func battery_capacity(ship: ShipModel) -> float:
	return maxf(ship.sum_stat(&"battery"), 0.2)


## Lista de requisitos del entorno para un destino: [texto, cumple].
static func requirements(ship: ShipModel, target: BodyDef) -> Array:
	var out: Array = []
	if target == null:
		return out
	var r := target.orbit_radius
	if target.parent_id != &"" and Catalog.body(target.parent_id) != null and not Catalog.body(target.parent_id).is_star:
		r = Catalog.body(target.parent_id).orbit_radius
	var f_target := flux(r)
	var f_min := minf(f_target, 1.0)
	var f_max := maxf(f_target, 1.0)
	var t_hot := equilibrium(f_max, ship)
	var t_cold := equilibrium(f_min, ship)
	out.append(["Calor en ruta (%d %%)" % int(t_hot * 100.0), t_hot < HOT])
	out.append(["Frío en ruta (%d %%)" % int(t_cold * 100.0), t_cold > COLD])
	var gen := power_gen(f_min, ship)
	out.append(["Energía %.1f / %.1f" % [gen, power_use(ship)], gen >= power_use(ship)])
	if target.atmosphere > 0.0:
		out.append(["Escudo térmico", ship.has_kind(&"heatshield")])
		out.append(["Paracaídas", ship.has_kind(&"parachute")])
	else:
		out.append(["Motor en la ultima etapa (sin aire)", ship.stage_thrust(ship.stages().back()) > 0.0])
	out.append(["Cápsula", ship.has_kind(&"capsule")])
	if target.hazards.has(&"radiation"):
		out.append(["Blindaje antirradiación", ship.sum_stat(&"rad_resist") >= 0.5])
	return out
