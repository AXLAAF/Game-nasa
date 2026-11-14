class_name OrbitalSolver
extends RefCounted

var body_id: String = "moon"
var body_name: String = "Luna"
var planet_radius_km: float = 1737.4
var atmo_top_km: float = 0.0
var surface_pressure_bar: float = 0.0
var scale_height_km: float = 0.0
var au: float = 1.0

var apoapsis_km: float = 620.0
var periapsis_km: float = 190.0
var arg_periapsis_rad: float = 0.0
var true_anomaly_rad: float = 0.35
var orbital_dir: float = 1.0

var ship_angle_rad: float = 0.0
var ship_ang_vel: float = 0.0
var reentry_pitch_deg: float = -4.5
var temp_norm: float = 0.50

var fuel_remaining_t: float = 6.0
var max_fuel_t: float = 6.0
var progress_to_capture: float = 0.0
var distance_to_node_s: float = 28.0

var maneuver_planned: bool = false
var maneuver_dv_prograde: float = 0.0
var maneuver_dv_radial: float = 0.0
var maneuver_node_anomaly_rad: float = 3.14159

var dsn_window_open: bool = true
var science_collected: float = 0.0
var science_transmitted: float = 0.0
var science_target: float = 120.0
var telemetry_latency_s: float = 2.56


func configure_for_body(body: Dictionary, metrics: Dictionary) -> void:
	body_id = str(body.get("id", "moon"))
	body_name = str(body.get("name", "Luna"))
	surface_pressure_bar = float(body.get("surface_pressure_bar", 0.0))
	scale_height_km = float(body.get("scale_height_km", 0.0))
	au = float(body.get("semi_major_axis_au", 1.0))
	science_target = float(body.get("science_target", 120.0))
	telemetry_latency_s = float(body.get("dsn_rtlt_s", 2.56))

	match body_id:
		"moon":
			planet_radius_km = 1737.4
			atmo_top_km = 0.0
			apoapsis_km = 520.0
			periapsis_km = 160.0
		"mars":
			planet_radius_km = 3389.5
			atmo_top_km = 110.0
			apoapsis_km = 880.0
			periapsis_km = 210.0
		"jupiter":
			planet_radius_km = 69911.0
			atmo_top_km = 2200.0
			apoapsis_km = 28000.0
			periapsis_km = 6500.0
		_:
			planet_radius_km = 6371.0
			atmo_top_km = 100.0
			apoapsis_km = 740.0
			periapsis_km = 240.0

	max_fuel_t = maxf(float(metrics.get("fuel_mass_t", 6.0)), 1.0)
	fuel_remaining_t = max_fuel_t
	true_anomaly_rad = 0.4
	arg_periapsis_rad = 0.25
	ship_angle_rad = 0.0
	ship_ang_vel = 0.0
	reentry_pitch_deg = -4.5
	temp_norm = 0.50
	progress_to_capture = 0.0
	science_collected = 0.0
	science_transmitted = 0.0
	plan_maneuver(140.0, 0.0, 3.14159)


func plan_maneuver(dv_pro: float, dv_rad: float, node_anomaly: float = 3.14159) -> void:
	maneuver_planned = absf(dv_pro) > 1.0 or absf(dv_rad) > 1.0
	maneuver_dv_prograde = clampf(dv_pro, -600.0, 600.0)
	maneuver_dv_radial = clampf(dv_rad, -300.0, 300.0)
	maneuver_node_anomaly_rad = fposmod(node_anomaly, TAU)


func eccentricity() -> float:
	var ra := planet_radius_km + apoapsis_km
	var rp := planet_radius_km + periapsis_km
	return clampf((ra - rp) / maxf(ra + rp, 1.0), 0.0, 0.92)


func current_altitude_km() -> float:
	var ra := planet_radius_km + apoapsis_km
	var rp := planet_radius_km + periapsis_km
	var a := 0.5 * (ra + rp)
	var e := eccentricity()
	var denom := maxf(1.0 + e * cos(true_anomaly_rad), 0.1)
	var r := a * (1.0 - e * e) / denom
	return maxf(r - planet_radius_km, 0.0)


func step(
	dt: float,
	steer_x: float,
	throttle: float,
	engines_eff: float,
	sensors_eff: float,
	science_eff: float,
	shields_eff: float,
	metrics: Dictionary,
	fuel_leak_rate: float
) -> Dictionary:
	# Movimiento orbital kepleriano simplificado (mas rapido en periapsis por vis-viva)
	var alt := current_altitude_km()
	var speed_factor := clampf((planet_radius_km + periapsis_km) / maxf(planet_radius_km + alt, 1.0), 0.35, 1.8)
	true_anomaly_rad = fposmod(true_anomaly_rad + 0.32 * speed_factor * dt, TAU)

	# Ventana DSN abierta en arco superior de la orbita (evita ocultacion planetaria)
	dsn_window_open = sin(true_anomaly_rad + arg_periapsis_rad) > -0.35 and sensors_eff > 0.1

	# Giro de la nave y NavBall
	var turn_rate := 1.65 * (0.5 + 0.5 * clampf(float(metrics.get("twr_space", 0.5)), 0.2, 2.0))
	ship_ang_vel = lerpf(ship_ang_vel, steer_x * turn_rate, clampf(dt * 6.0, 0.0, 1.0))
	ship_angle_rad = wrapf(ship_angle_rad + ship_ang_vel * dt, -PI, PI)
	reentry_pitch_deg = clampf(reentry_pitch_deg + steer_x * 4.5 * dt, -12.0, 4.0)

	# Consumo por fuga en sala engines
	if fuel_leak_rate > 0.0:
		fuel_remaining_t = maxf(fuel_remaining_t - fuel_leak_rate * 0.25 * dt, 0.0)

	# Quema orbital acoplada a motores del reactor
	var effective_throttle := clampf(throttle, 0.0, 1.0) * clampf(engines_eff, 0.0, 1.25)
	if effective_throttle > 0.02 and fuel_remaining_t > 0.0:
		var isp := maxf(float(metrics.get("isp_s", 315.0)), 100.0)
		var burn_mass := effective_throttle * (240.0 / isp) * 0.16 * dt
		fuel_remaining_t = maxf(fuel_remaining_t - burn_mass, 0.0)

		# Segun orientacion relativa (prograde = 0, retrograde = PI) cambia AP o PE
		var dir_cos := cos(ship_angle_rad)
		var dir_sin := sin(ship_angle_rad)
		var scale_alt := 120.0 if body_id != "jupiter" else 2800.0
		apoapsis_km = maxf(apoapsis_km + dir_cos * effective_throttle * scale_alt * dt, periapsis_km)
		periapsis_km = maxf(periapsis_km - dir_cos * 0.35 * effective_throttle * scale_alt * dt, 5.0)
		arg_periapsis_rad = wrapf(arg_periapsis_rad + dir_sin * effective_throttle * 0.45 * dt, -PI, PI)

		if maneuver_planned:
			var dv_step := effective_throttle * 95.0 * dt
			if maneuver_dv_prograde > 0.0:
				maneuver_dv_prograde = maxf(maneuver_dv_prograde - dv_step, 0.0)
			elif maneuver_dv_prograde < 0.0:
				maneuver_dv_prograde = minf(maneuver_dv_prograde + dv_step, 0.0)
			if absf(maneuver_dv_prograde) < 2.0 and absf(maneuver_dv_radial) < 2.0:
				maneuver_planned = false

		progress_to_capture = clampf(progress_to_capture + effective_throttle * 0.14 * dt, 0.0, 1.0)

	# Balance termico basado en MECANICAS-REFERENCIA.md
	var f_solar := NasaDataLoader.solar_factor(au)
	var cooling := float(metrics.get("cooling", 0.15)) + shields_eff * 0.25
	var heat_res := float(metrics.get("heat_resist", 0.25))
	var cold_res := float(metrics.get("cold_resist", 0.25))
	var in_atmo := surface_pressure_bar > 0.0 and alt < atmo_top_km
	var atmo_heat := 0.25 if in_atmo else 0.0
	var hot_term := maxf(f_solar - 1.0, 0.0) * (0.14 / (1.0 + cooling)) * (1.0 - 0.7 * heat_res) + atmo_heat * (1.0 - 0.65 * heat_res)
	var cold_term := clampf(1.0 - f_solar, 0.0, 1.0) * 0.35 * (1.0 - cold_res)
	var target_temp := clampf(0.5 + hot_term - cold_term + effective_throttle * 0.08, 0.0, 1.2)
	temp_norm = lerpf(temp_norm, target_temp, clampf(dt * 1.4, 0.0, 1.0))

	# Recoleccion cientifica (mejor cerca de periapsis) y transmision DSN
	if science_eff > 0.05:
		var pe_bonus := 1.6 if alt < periapsis_km + 0.3 * (apoapsis_km - periapsis_km + 10.0) else 0.85
		science_collected = minf(science_collected + 16.0 * science_eff * pe_bonus * dt, science_target * 1.2)

	if dsn_window_open and sensors_eff > 0.05 and science_transmitted < science_collected:
		var tx_rate := float(metrics.get("dsn_kbps", 45.0)) * 0.35 * sensors_eff
		science_transmitted = minf(science_transmitted + tx_rate * dt, science_collected)

	var diff_node := absf(wrapf(maneuver_node_anomaly_rad - true_anomaly_rad, -PI, PI))
	distance_to_node_s = diff_node * 12.0

	return {
		"altitude_km": alt,
		"apoapsis_km": apoapsis_km,
		"periapsis_km": periapsis_km,
		"eccentricity": eccentricity(),
		"temp_norm": temp_norm,
		"overheated": temp_norm >= 0.85,
		"frozen": temp_norm <= 0.15,
		"in_reentry_corridor": reentry_pitch_deg >= -5.2 and reentry_pitch_deg <= -3.8,
		"dsn_window_open": dsn_window_open,
		"fuel_ratio": fuel_remaining_t / max_fuel_t,
		"science_collected": science_collected,
		"science_transmitted": science_transmitted,
	}


func orbit_points(num_pts: int, center: Vector2, planet_px: float, extra_prograde: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ra := planet_radius_km + apoapsis_km + extra_prograde * 1.8
	var rp := maxf(planet_radius_km + periapsis_km, planet_radius_km + 4.0)
	var a := 0.5 * (ra + rp)
	var e := clampf((ra - rp) / maxf(ra + rp, 1.0), 0.0, 0.88)
	var base_scale := (planet_px * 0.5) / maxf(planet_radius_km, 1.0)
	for i: int in range(num_pts + 1):
		var th := float(i) / float(num_pts) * TAU
		var r_km := a * (1.0 - e * e) / maxf(1.0 + e * cos(th), 0.15)
		var r_px := clampf(r_km * base_scale, planet_px * 0.56, planet_px * 2.15)
		var ang := th + arg_periapsis_rad
		pts.append(center + Vector2(cos(ang), sin(ang)) * r_px)
	return pts


func ship_orbit_pos(center: Vector2, planet_px: float) -> Vector2:
	var ra := planet_radius_km + apoapsis_km
	var rp := maxf(planet_radius_km + periapsis_km, planet_radius_km + 4.0)
	var a := 0.5 * (ra + rp)
	var e := eccentricity()
	var base_scale := (planet_px * 0.5) / maxf(planet_radius_km, 1.0)
	var r_km := a * (1.0 - e * e) / maxf(1.0 + e * cos(true_anomaly_rad), 0.15)
	var r_px := clampf(r_km * base_scale, planet_px * 0.56, planet_px * 2.15)
	var ang := true_anomaly_rad + arg_periapsis_rad
	return center + Vector2(cos(ang), sin(ang)) * r_px
