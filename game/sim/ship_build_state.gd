class_name ShipBuildState
extends RefCounted

const LAUNCHERS: Dictionary = {
	&"light_falcon": {
		"id": &"light_falcon",
		"name": "Vector-9 Ligero",
		"cost": 400,
		"max_payload_t": 11.5,
		"ramp_thrust_kn": 210.0,
		"dv_boost_m_s": 1400.0,
	},
	&"medium_vulcan": {
		"id": &"medium_vulcan",
		"name": "Centauro-M Medio",
		"cost": 850,
		"max_payload_t": 18.5,
		"ramp_thrust_kn": 360.0,
		"dv_boost_m_s": 2800.0,
	},
	&"heavy_sls": {
		"id": &"heavy_sls",
		"name": "Saturn-H Pesado",
		"cost": 1550,
		"max_payload_t": 32.0,
		"ramp_thrust_kn": 640.0,
		"dv_boost_m_s": 5000.0,
	},
}

const INSTRUMENTS: Dictionary = {
	&"cam_multispectral": {
		"id": &"cam_multispectral",
		"name": "Camara Multiespectral HiRISE",
		"mass_t": 0.45,
		"power_eq": 1.0,
		"kbps": 45.0,
		"cost": 220,
		"science_value": 80,
	},
	&"mass_spectrometer": {
		"id": &"mass_spectrometer",
		"name": "Espectrometro de Masas SAM",
		"mass_t": 0.85,
		"power_eq": 1.2,
		"kbps": 30.0,
		"cost": 360,
		"science_value": 120,
	},
	&"ice_radar_reason": {
		"id": &"ice_radar_reason",
		"name": "Radar Subsuperficial Hielo",
		"mass_t": 1.25,
		"power_eq": 1.8,
		"kbps": 85.0,
		"cost": 520,
		"science_value": 180,
	},
	&"magnetometer_plasma": {
		"id": &"magnetometer_plasma",
		"name": "Magnetometro de Plasma",
		"mass_t": 0.60,
		"power_eq": 0.9,
		"kbps": 40.0,
		"cost": 300,
		"science_value": 100,
	},
}

const SOCKET_ORDER: Array[StringName] = [
	&"bow",
	&"port_nacelle",
	&"stbd_nacelle",
	&"wing_port",
	&"wing_stbd",
	&"dorsal_turret",
	&"aft_engines",
]

const MODULE_CATALOG: Dictionary = {
	&"bow_shield": {"socket": &"bow", "name": "Escudo PICA / HRSI", "mass_t": 1.2, "cost": 280, "heat_resist": 0.90, "heatshield": true, "parachute": true, "rad_shield": false, "sprite": "bow_shield"},
	&"bow_radar": {"socket": &"bow", "name": "Domo Radar Doppler Ku", "mass_t": 0.6, "cost": 310, "radar_warn": 14.0, "heatshield": false, "parachute": false, "rad_shield": false, "sprite": "bow_radar"},
	&"bow_les": {"socket": &"bow", "name": "Torre de Escape LES", "mass_t": 0.8, "cost": 240, "les_save": 0.65, "heatshield": false, "parachute": true, "rad_shield": false, "sprite": "bow_les"},
	&"nacelle_tank": {"socket": &"nacelle", "name": "Gondola Tanque LH2/LOX", "mass_t": 0.5, "fuel_t": 2.4, "cost": 220, "sprite": "nacelle_tank"},
	&"nacelle_rtg": {"socket": &"nacelle", "name": "Banco Nuclear MMRTG PuO2", "mass_t": 1.2, "rtg_eq": 2.8, "bars": 2, "cost": 520, "heat_gen": 0.16, "sprite": "nacelle_rtg"},
	&"nacelle_armor": {"socket": &"nacelle", "name": "Gondola Whipple / Plomo", "mass_t": 1.4, "cost": 340, "rad_shield": true, "mmod_red": 0.40, "sprite": "nacelle_armor"},
	&"wing_solar": {"socket": &"wing", "name": "Paneles Solares GaAs", "mass_t": 0.6, "solar_eq": 2.4, "bars": 2, "cost": 180, "sprite": "wing_solar"},
	&"wing_radiator": {"socket": &"wing", "name": "Radiador Plegable NH3", "mass_t": 0.9, "cooling": 0.22, "cost": 290, "sprite": "wing_radiator"},
	&"dorsal_dsn": {"socket": &"dorsal", "name": "Antena Parabolica DSN Ka", "mass_t": 0.5, "kbps": 60.0, "cost": 260, "sprite": "dorsal_dsn"},
	&"dorsal_arm": {"socket": &"dorsal", "name": "Brazo Canadarm / Red NEO", "mass_t": 0.8, "science_mult": 1.25, "cost": 310, "sprite": "dorsal_arm"},
	&"dorsal_cmg": {"socket": &"dorsal", "name": "Giroscopio CMG Inercial", "mass_t": 1.1, "turn_bonus": 0.45, "cost": 350, "sprite": "dorsal_cmg"},
	&"aft_hypergolic": {"socket": &"aft", "name": "Motor Hipergolico MMH", "mass_t": 1.1, "thrust_kn": 74.0, "isp_s": 320.0, "cost": 260, "sprite": "aft_hypergolic"},
	&"aft_cryo": {"socket": &"aft", "name": "Motor Criogenico RS/C-103", "mass_t": 1.5, "thrust_kn": 135.0, "isp_s": 448.0, "cost": 480, "sprite": "aft_cryo"},
	&"aft_ion": {"socket": &"aft", "name": "Propulsor Hall / Ionico Xe", "mass_t": 1.0, "thrust_kn": 38.0, "isp_s": 1800.0, "cost": 560, "sprite": "aft_ion"},
}

const PERKS: Dictionary = {
	&"shield_hrsi": {"name": "Losetas Ceramicas HRSI", "mass_t": 1.8, "cost": 320, "heatshield": true, "heat_resist": 0.85, "fragility": 1.35},
	&"shield_pica": {"name": "Escudo Ablativo PICA-X", "mass_t": 1.2, "cost": 280, "heatshield": true, "heat_resist": 0.95, "fragility": 0.90},
	&"nozzle_niobium": {"name": "Tobera Niobio C-103", "mass_t": 0.9, "cost": 450, "isp_bonus": 38.0, "thrust_mult": 1.18},
	&"staged_preburner": {"name": "Turbobomba Escalonada", "mass_t": 2.4, "cost": 600, "thrust_mult": 1.28, "ign_risk_add": 0.08},
	&"telemetry_strain": {"name": "Telemetria Analogica Galgas", "mass_t": 0.5, "cost": 140, "emp_immune": true},
	&"damper_cryo_he": {"name": "Amortiguador Criogenico Pogo", "mass_t": 1.6, "cost": 260, "maxq_red": 0.70, "power_eq": 0.4},
	&"insulation_mli": {"name": "Manta Multicapa Kapton", "mass_t": 0.2, "cost": 180, "cold_resist": 0.90},
	&"winch_uhmwpe": {"name": "Cabrestante UHMWPE", "mass_t": 0.7, "cost": 290, "science_mult": 1.15},
	&"net_supercond": {"name": "Red Superconductora", "mass_t": 1.4, "cost": 480, "science_mult": 1.20, "power_eq": 0.6},
	&"radar_doppler": {"name": "Radar Doppler Pulso Ku", "mass_t": 0.6, "cost": 310, "radar_warn": 14.0, "power_eq": 0.4},
	&"cmg_stabilizer": {"name": "Giroscopio CMG Extra", "mass_t": 1.5, "cost": 390, "turn_bonus": 0.45},
	&"radiator_ammonia": {"name": "Radiador Amoniaco Auxiliar", "mass_t": 1.1, "cost": 340, "cooling": 0.18},
}

const QUALITY_MULT: Dictionary = {
	&"SCRAP": {"cost": 0.70, "cond": 0.55, "label": "Chatarra"},
	&"USED": {"cost": 1.00, "cond": 0.78, "label": "Usada"},
	&"NEW": {"cost": 1.20, "cond": 0.94, "label": "Nueva"},
	&"LEGENDARY": {"cost": 1.55, "cond": 0.99, "label": "Anomala"},
}

var launcher_id: StringName = &"medium_vulcan"
var hull_level: int = 1
var sockets: Dictionary = {}
var selected_instruments: Array[StringName] = [&"cam_multispectral"]
var selected_perks: Array[StringName] = []
var auxiliary_cargo_attached: bool = true
var jettisoned: bool = false
var insured: bool = false

const CRATE_COST: int = 160


func _init() -> void:
	reset_default_mule()


func reset_default_mule() -> void:
	hull_level = 1
	launcher_id = &"medium_vulcan"
	sockets = {
		&"bow": {"module": &"bow_shield", "level": 1, "quality": &"USED"},
		&"port_nacelle": {"module": &"nacelle_tank", "level": 1, "quality": &"USED"},
		&"stbd_nacelle": {"module": &"nacelle_tank", "level": 1, "quality": &"SCRAP"},
		&"wing_port": {"module": &"wing_solar", "level": 1, "quality": &"USED"},
		&"wing_stbd": {"module": &"wing_solar", "level": 1, "quality": &"USED"},
		&"dorsal_turret": {"module": &"dorsal_dsn", "level": 1, "quality": &"USED"},
		&"aft_engines": {"module": &"aft_hypergolic", "level": 1, "quality": &"USED"},
	}
	selected_instruments = [&"cam_multispectral"]
	selected_perks = []
	auxiliary_cargo_attached = true
	jettisoned = false
	insured = false


func roll_scrapyard_crate(rng: RandomNumberGenerator, available_credits: int) -> Dictionary:
	if available_credits < CRATE_COST:
		return {"ok": false, "cost": CRATE_COST, "reason": "Creditos insuficientes"}
	var socket_id: StringName = SOCKET_ORDER[rng.randi_range(0, SOCKET_ORDER.size() - 1)]
	var roll := rng.randf()
	var qual: StringName = &"USED"
	if roll < 0.15:
		qual = &"LEGENDARY"
	elif roll < 0.55:
		qual = &"NEW"
	elif roll >= 0.85:
		qual = &"SCRAP"

	var s: Dictionary = sockets[socket_id]
	s["quality"] = qual
	if qual in [&"NEW", &"LEGENDARY"] and int(s["level"]) < 5:
		s["level"] = int(s["level"]) + 1
	hull_level = maxi(hull_level, _avg_hull_level())

	var bonus_perk: StringName = &""
	if qual == &"LEGENDARY":
		var missing: Array[StringName] = []
		for pid: StringName in PERKS.keys():
			if not selected_perks.has(pid):
				missing.append(pid)
		if not missing.is_empty():
			bonus_perk = missing[rng.randi_range(0, missing.size() - 1)]
			selected_perks.append(bonus_perk)

	return {
		"ok": true,
		"cost": CRATE_COST,
		"socket": socket_id,
		"quality": qual,
		"level": int(s["level"]),
		"bonus_perk": bonus_perk,
	}


func upgrade_socket(socket_id: StringName, available_credits: int) -> Dictionary:
	if not sockets.has(socket_id):
		return {"ok": false, "cost": 0, "reason": "Socket invalido"}
	var s: Dictionary = sockets[socket_id]
	var cur_lvl := int(s["level"])
	if cur_lvl >= 5:
		return {"ok": false, "cost": 0, "reason": "Ya esta en LVL 5 MAX"}
	var next_lvl := cur_lvl + 1
	var cost := 180 * next_lvl
	if available_credits < cost:
		return {"ok": false, "cost": cost, "reason": "Creditos insuficientes"}
	s["level"] = next_lvl
	if next_lvl >= 3 and s["quality"] == &"SCRAP":
		s["quality"] = &"USED"
	elif next_lvl >= 4:
		s["quality"] = &"NEW"
	hull_level = maxi(hull_level, _avg_hull_level())
	return {"ok": true, "cost": cost, "new_level": next_lvl}


func _avg_hull_level() -> int:
	var sum := 0
	for k: StringName in SOCKET_ORDER:
		sum += int(sockets[k]["level"])
	return clampi(int(round(float(sum) / float(SOCKET_ORDER.size()))), 1, 5)


func set_socket_module(socket_id: StringName, mod_id: StringName, quality: StringName = &"USED") -> bool:
	if not sockets.has(socket_id) or not MODULE_CATALOG.has(mod_id):
		return false
	sockets[socket_id]["module"] = mod_id
	if QUALITY_MULT.has(quality):
		sockets[socket_id]["quality"] = quality
	return true


func toggle_instrument(inst_id: StringName) -> bool:
	if not INSTRUMENTS.has(inst_id):
		return false
	var idx := selected_instruments.find(inst_id)
	if idx >= 0:
		if selected_instruments.size() <= 1:
			return false
		selected_instruments.remove_at(idx)
	else:
		selected_instruments.append(inst_id)
	return true


func toggle_perk(perk_id: StringName) -> bool:
	if not PERKS.has(perk_id):
		return false
	var idx := selected_perks.find(perk_id)
	if idx >= 0:
		selected_perks.remove_at(idx)
	else:
		selected_perks.append(perk_id)
	return true


func set_launcher(new_id: StringName) -> bool:
	if not LAUNCHERS.has(new_id):
		return false
	launcher_id = new_id
	return true


func jettison_aux_cargo() -> void:
	auxiliary_cargo_attached = false
	jettisoned = true


func compute_metrics(body: Dictionary) -> Dictionary:
	var launcher: Dictionary = LAUNCHERS.get(launcher_id, LAUNCHERS[&"medium_vulcan"])
	var base_hull_t := 2.4
	var dry_mass := base_hull_t
	var fuel_mass := 3.2
	var total_cost := int(launcher["cost"])
	var solar_eq := 0.0
	var rtg_eq := 0.0
	var cooling := 0.12
	var heat_resist := 0.25
	var cold_resist := 0.25
	var thrust_kn := 30.0
	var isp_s := 300.0
	var dsn_kbps := 35.0
	var science_mult := 1.0
	var has_heatshield := false
	var has_parachute := false
	var has_rad_shield := false
	var emp_immune := false
	var radar_warn := 10.0
	var extra_bars := 0
	var scrap_count := 0
	var cond_sum := 0.0
	var maxq_red := 0.0
	var ign_risk_add := 0.0
	var required_power := 2.4

	if auxiliary_cargo_attached and not jettisoned:
		dry_mass += 2.2

	for k: StringName in SOCKET_ORDER:
		var slot: Dictionary = sockets[k]
		var mod_id: StringName = slot["module"]
		var lvl := int(slot["level"])
		var qual: StringName = slot["quality"]
		var m: Dictionary = MODULE_CATALOG.get(mod_id, {})
		var qinfo: Dictionary = QUALITY_MULT.get(qual, QUALITY_MULT[&"USED"])
		if qual == &"SCRAP":
			scrap_count += 1
		cond_sum += clampf(float(qinfo["cond"]) + (lvl - 1) * 0.03, 0.25, 1.0)
		var lvl_scale := 1.0 + float(lvl - 1) * 0.18

		dry_mass += float(m.get("mass_t", 0.5)) * (1.0 - float(lvl - 1) * 0.03)
		fuel_mass += float(m.get("fuel_t", 0.0)) * lvl_scale
		total_cost += int(round(float(m.get("cost", 150)) * float(qinfo["cost"]) * (1.0 + (lvl - 1) * 0.25)))
		solar_eq += float(m.get("solar_eq", 0.0)) * lvl_scale
		rtg_eq += float(m.get("rtg_eq", 0.0)) * lvl_scale
		cooling += float(m.get("cooling", 0.0)) * lvl_scale
		extra_bars += int(m.get("bars", 0)) + (1 if lvl >= 4 and int(m.get("bars", 0)) > 0 else 0)
		dsn_kbps += float(m.get("kbps", 0.0)) * lvl_scale
		science_mult *= float(m.get("science_mult", 1.0))
		heat_resist = maxf(heat_resist, float(m.get("heat_resist", 0.0)))
		if bool(m.get("heatshield", false)):
			has_heatshield = true
		if bool(m.get("parachute", false)):
			has_parachute = true
		if bool(m.get("rad_shield", false)):
			has_rad_shield = true
		if m.has("radar_warn"):
			radar_warn = maxf(radar_warn, float(m["radar_warn"]) + float(lvl - 1))
		if k == &"aft_engines":
			thrust_kn = float(m.get("thrust_kn", 70.0)) * lvl_scale
			isp_s = float(m.get("isp_s", 315.0)) + float(lvl - 1) * 12.0

	for inst_id: StringName in selected_instruments:
		var inst: Dictionary = INSTRUMENTS[inst_id]
		dry_mass += float(inst["mass_t"])
		required_power += float(inst["power_eq"])
		total_cost += int(inst["cost"])
		dsn_kbps = maxf(dsn_kbps, float(inst["kbps"]))

	for perk_id: StringName in selected_perks:
		var pk: Dictionary = PERKS[perk_id]
		dry_mass += float(pk["mass_t"])
		total_cost += int(pk["cost"])
		required_power += float(pk.get("power_eq", 0.0))
		isp_s += float(pk.get("isp_bonus", 0.0))
		thrust_kn *= float(pk.get("thrust_mult", 1.0))
		cooling += float(pk.get("cooling", 0.0))
		heat_resist = maxf(heat_resist, float(pk.get("heat_resist", 0.0)))
		cold_resist = maxf(cold_resist, float(pk.get("cold_resist", 0.0)))
		maxq_red = maxf(maxq_red, float(pk.get("maxq_red", 0.0)))
		ign_risk_add += float(pk.get("ign_risk_add", 0.0))
		science_mult *= float(pk.get("science_mult", 1.0))
		if bool(pk.get("heatshield", false)):
			has_heatshield = true
		if bool(pk.get("emp_immune", false)):
			emp_immune = true
		if pk.has("radar_warn"):
			radar_warn = maxf(radar_warn, float(pk["radar_warn"]))

	var wet_mass := dry_mass + fuel_mass
	var spacecraft_dv := 0.0
	if isp_s > 0.0 and dry_mass > 0.0 and wet_mass > dry_mass:
		spacecraft_dv = isp_s * 9.80665 * log(wet_mass / dry_mass)
	var total_dv := spacecraft_dv + float(launcher["dv_boost_m_s"])

	var max_payload := float(launcher["max_payload_t"])
	var ramp_thrust_kn := float(launcher["ramp_thrust_kn"])
	var m_rated := ramp_thrust_kn / (1.25 * 9.80665)
	var effective_rated := minf(m_rated, max_payload)
	var overload := maxf(0.0, (wet_mass - effective_rated) / maxf(effective_rated, 0.1))

	var h_struct := clampf(cond_sum / float(SOCKET_ORDER.size()), 0.15, 1.0)
	var p_ign := clampf(0.005 + 0.18 * pow(1.0 - h_struct, 2.0) + ign_risk_add, 0.005, 0.90)
	var sigma_q := 0.12 * (1.0 - maxq_red)
	var p_ascent := clampf(0.42 * overload * overload + 0.35 * sigma_q * (1.0 - h_struct), 0.0, 0.90)
	var p_explosion := clampf(1.0 - (1.0 - p_ign) * (1.0 - p_ascent), 0.005, 0.95)

	var au := float(body.get("semi_major_axis_au", 1.0))
	var f_solar := NasaDataLoader.solar_factor(au)
	var power_at_dest := solar_eq * minf(f_solar, 2.5) + rtg_eq
	var req_dv := float(body.get("mission_dv_m_s", 4100.0))

	var science_potential := 0
	for inst_id: StringName in selected_instruments:
		science_potential += int(round(float(INSTRUMENTS[inst_id]["science_value"]) * science_mult))

	var reactor_bars := clampi(6 + int(round((solar_eq * minf(f_solar, 1.2) + rtg_eq) * 0.7)), 5, 11)

	return {
		"dry_mass_t": dry_mass,
		"fuel_mass_t": fuel_mass,
		"wet_mass_t": wet_mass,
		"m_rated_t": effective_rated,
		"overload": overload,
		"p_explosion": p_explosion,
		"thrust_kn": thrust_kn,
		"isp_s": isp_s,
		"delta_v_m_s": total_dv,
		"required_dv_m_s": req_dv,
		"solar_power": solar_eq,
		"rtg_power": rtg_eq,
		"solar_factor": f_solar,
		"power_at_dest": power_at_dest,
		"required_power": required_power,
		"reactor_bars": reactor_bars,
		"cooling": cooling,
		"heat_resist": heat_resist,
		"cold_resist": cold_resist,
		"dsn_kbps": dsn_kbps,
		"radar_warn_s": radar_warn,
		"has_heatshield": has_heatshield,
		"has_parachute": has_parachute,
		"has_rad_shield": has_rad_shield,
		"emp_immune": emp_immune,
		"scrap_count": scrap_count,
		"total_cost": total_cost,
		"science_potential": science_potential,
		"twr_space": thrust_kn / maxf(wet_mass * 9.80665, 0.1),
		"hull_level": hull_level,
	}


func to_evaluator_config(metrics: Dictionary) -> Dictionary:
	return {
		"solar_power": metrics["solar_power"],
		"rtg_power": metrics["rtg_power"],
		"required_power": metrics["required_power"],
		"has_heatshield": metrics["has_heatshield"],
		"has_parachute": metrics["has_parachute"],
		"has_rad_shield": metrics["has_rad_shield"],
		"overload": metrics["overload"],
		"scrap_count": metrics["scrap_count"],
	}
