class_name TrainingAssembly
extends RefCounted

## Solo consulta la nave. El orden se lee desde la base, no desde el dibujo.
static func evaluate(ship: ShipModel, design: Dictionary, gravity: float) -> Dictionary:
	var recipe: Array = design.recipe
	for i: int in recipe.size():
		var step: Dictionary = recipe[i]
		if ship.parts.size() <= i or String(ship.parts[i].def.id) != step.id:
			return {"ready": false, "index": i, "part": step.id, "title": step.title,
				"why": step.why, "error": "" if ship.parts.size() <= i else "La posición %d necesita %s. Mueve o retira la pieza que ocupa ese lugar." % [i + 1, step.title]}
	var error := ""
	if ship.stages().size() != 2:
		error = "Esta práctica necesita exactamente dos etapas; retira los desacopladores extra."
	for stage: Array in ship.stages():
		if ship.stage_thrust(stage) <= 0.0 or ship.stage_fuel(stage) <= 0.0:
			error = "Cada etapa necesita un motor operativo y combustible en su propio tanque."
	if ship.twr(gravity) < float(design.min_twr):
		error = "Falta empuje para esta masa. Retira extras para recuperar margen de despegue."
	elif ship.delta_v() < float(design.min_dv):
		error = "Falta reserva de delta-v para regresar. Retira masa adicional."
	elif Thermal.power_gen(1.0, ship) < Thermal.power_use(ship) or ship.sum_stat(&"battery") <= 0.0:
		error = "La electrónica necesita generación y una batería operativa."
	elif ship.sum_stat(&"ablative") <= 0.0 or ship.sum_stat(&"drag") <= 0.0 or not ship.has_kind(&"capsule"):
		error = "Revisa cabina, escudo y paracaídas antes de regresar."
	return {"ready": error.is_empty(), "index": recipe.size(), "part": "", "title": "Revisión de lanzamiento",
		"why": "Dos etapas completas. Los extras añaden capacidad, masa y coste. Comprueba empuje, reserva de combustible y energía.", "error": error}
