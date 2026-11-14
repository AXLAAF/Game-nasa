class_name MissionEvaluator
extends RefCounted

var good_items: Array[Dictionary] = []
var bad_items: Array[Dictionary] = []
var nasa_sources: Array[Dictionary] = []


func clear() -> void:
	good_items.clear()
	bad_items.clear()
	nasa_sources.clear()


func record_good(code: String, summary: String) -> void:
	good_items.append({"code": code, "summary": summary})


func record_bad(code: String, summary: String) -> void:
	bad_items.append({"code": code, "summary": summary})


func set_sources(sources: Array[Dictionary]) -> void:
	nasa_sources = sources.duplicate(true)


func audit_preflight(body: Dictionary, config: Dictionary) -> void:
	var au := float(body.get("semi_major_axis_au", 1.0))
	var solar_w := float(config.get("solar_power", 0.0))
	var rtg_w := float(config.get("rtg_power", 0.0))
	var factor := NasaDataLoader.solar_factor(au)
	var total_power_at_dest := maxf(solar_w, 0.0) * minf(factor, 2.5) + maxf(rtg_w, 0.0)
	var required_power := float(config.get("required_power", 1.0))

	if au >= 3.0 and rtg_w <= 0.0 and solar_w > 0.0:
		record_bad("SOLAR_AT_JUPITER", "Usaste solo paneles solares a %.2f AU (flujo cae a %.1f%%): energia insuficiente en destino." % [au, factor * 100.0])
	elif total_power_at_dest >= required_power:
		record_good("POWER_BUDGET_OK", "Balance energetico adecuado en destino (%.1f W/eq vs %.1f requeridos)." % [total_power_at_dest, required_power])

	if bool(body.get("requires_heatshield", false)):
		if bool(config.get("has_heatshield", false)):
			record_good("EDL_SHIELD_OK", "Escudo termico equipado para reentrada atmosferica en %s." % str(body.get("name", "destino")))
		else:
			record_bad("NO_HEATSHIELD", "Falto escudo termico para entrada atmosferica en %s (%.4f bar)." % [str(body.get("name", "destino")), float(body.get("surface_pressure_bar", 0.0))])

	if bool(body.get("requires_parachute", false)) and not bool(config.get("has_parachute", false)):
		record_bad("NO_PARACHUTE", "Sin paracaidas para frenado atmosferico en %s." % str(body.get("name", "destino")))

	if bool(body.get("radiation_hazard", false)):
		if bool(config.get("has_rad_shield", false)):
			record_good("RAD_SHIELD_OK", "Blindaje contra radiacion equipado para cinturones hostiles.")
		else:
			record_bad("NO_RAD_SHIELD", "Sin proteccion anti-radiacion en entorno hostil.")

	var overload := float(config.get("overload", 0.0))
	if overload > 0.15:
		record_bad("RAMP_OVERLOAD", "Sobrecarga de masa en rampa (+%d%% sobre M_rated), elevando riesgo de explosion." % int(round(overload * 100.0)))
	elif overload <= 0.01:
		record_good("RAMP_MASS_SAFE", "Masa total dentro de margen estructural seguro (Omega <= 1%).")

	if int(config.get("scrap_count", 0)) >= 2:
		record_bad("CHEAP_SCRAP_RISK", "Multiples piezas Chatarra elevan tasa de incendios y fugas en vuelo.")


func build_report(outcome: StringName, science_collected: int, science_transmitted: int, base_payout: int, repair_cost: int) -> Dictionary:
	var good_score := good_items.size() * 20
	var bad_penalty := bad_items.size() * 18
	var transmitted_ratio := float(science_transmitted) / float(maxi(science_collected, 1)) if science_collected > 0 else 0.0
	var raw_score := clampi(50 + good_score - bad_penalty + int(round(transmitted_ratio * 30.0)), 0, 100)

	var grade := "F"
	if outcome == &"success":
		if raw_score >= 88:
			grade = "S"
		elif raw_score >= 72:
			grade = "A"
		elif raw_score >= 55:
			grade = "B"
		else:
			grade = "C"
	elif outcome == &"partial":
		grade = "C"

	var net_credits := base_payout + science_transmitted * 5 - repair_cost
	if outcome != &"success" and outcome != &"partial":
		net_credits = -repair_cost

	return {
		"outcome": outcome,
		"grade": grade,
		"score": raw_score,
		"science_collected": science_collected,
		"science_transmitted": science_transmitted,
		"net_credits": net_credits,
		"good_items": good_items.duplicate(true),
		"bad_items": bad_items.duplicate(true),
		"nasa_sources": nasa_sources.duplicate(true),
	}
