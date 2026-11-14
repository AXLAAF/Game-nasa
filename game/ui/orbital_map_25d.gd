class_name OrbitalMap25D
extends Control

var _planet_rect: ColorRect
var _planet_mat: ShaderMaterial
var _solver: OrbitalSolver
var _draw_overlay: _OrbitOverlay


func _ready() -> void:
	clip_contents = true
	_planet_rect = ColorRect.new()
	_planet_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := load("res://game/shaders/pixel_planet_25d.gdshader") as Shader
	if sh != null:
		_planet_mat = ShaderMaterial.new()
		_planet_mat.shader = sh
		_planet_rect.material = _planet_mat
	add_child(_planet_rect)

	_draw_overlay = _OrbitOverlay.new(self)
	_draw_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_overlay)


func bind_solver(solver: OrbitalSolver) -> void:
	_solver = solver
	if _planet_mat == null or _solver == null:
		return
	match _solver.body_id:
		"moon":
			_planet_mat.set_shader_parameter("planet_type", 1)
			_planet_mat.set_shader_parameter("col_a", Color("#334155"))
			_planet_mat.set_shader_parameter("col_b", Color("#94a3b8"))
			_planet_mat.set_shader_parameter("col_c", Color("#e2e8f0"))
			_planet_mat.set_shader_parameter("col_atmo", Color(0.8, 0.85, 0.95, 0.08))
		"mars":
			_planet_mat.set_shader_parameter("planet_type", 2)
			_planet_mat.set_shader_parameter("col_a", Color("#7c2d12"))
			_planet_mat.set_shader_parameter("col_b", Color("#c2410c"))
			_planet_mat.set_shader_parameter("col_c", Color("#fed7aa"))
			_planet_mat.set_shader_parameter("col_atmo", Color(0.95, 0.55, 0.30, 0.35))
		"jupiter":
			_planet_mat.set_shader_parameter("planet_type", 3)
			_planet_mat.set_shader_parameter("col_a", Color("#78350f"))
			_planet_mat.set_shader_parameter("col_b", Color("#d97706"))
			_planet_mat.set_shader_parameter("col_c", Color("#fef3c7"))
			_planet_mat.set_shader_parameter("col_atmo", Color(0.96, 0.72, 0.35, 0.32))
		_:
			_planet_mat.set_shader_parameter("planet_type", 0)
			_planet_mat.set_shader_parameter("col_a", Color("#1e3a8a"))
			_planet_mat.set_shader_parameter("col_b", Color("#22c55e"))
			_planet_mat.set_shader_parameter("col_c", Color("#f8fafc"))
			_planet_mat.set_shader_parameter("col_atmo", Color(0.22, 0.74, 0.97, 0.45))


func _process(_delta: float) -> void:
	if _planet_rect != null and _draw_overlay != null:
		var side := minf(size.x, size.y) * 0.40
		_planet_rect.size = Vector2(side, side)
		_planet_rect.position = (size - _planet_rect.size) * 0.5
		_draw_overlay.size = size
		_draw_overlay.queue_redraw()


class _OrbitOverlay extends Control:
	var _owner: OrbitalMap25D

	func _init(owner_node: OrbitalMap25D) -> void:
		_owner = owner_node

	func _draw() -> void:
		if _owner._solver == null:
			return
		var s := _owner._solver
		var center := size * 0.5
		var planet_px := minf(size.x, size.y) * 0.38

		# Anillos de escala Rhine Lab
		draw_arc(center, planet_px * 0.62, 0.0, TAU, 48, Color(0.22, 0.74, 0.97, 0.28), 1.0)
		draw_arc(center, planet_px * 1.10, 0.0, TAU, 64, Color(0.55, 0.61, 0.71, 0.22), 1.0)
		if s.surface_pressure_bar > 0.0:
			draw_arc(center, planet_px * 0.56, 0.0, TAU, 48, Color("#c83e2b"), 1.5)

		# Cono de linea de vista DSN en arco superior
		var dsn_col := Color(0.13, 0.77, 0.37, 0.35 if s.dsn_window_open else 0.08)
		draw_arc(center, planet_px * 1.25, -PI * 0.15, PI * 1.15, 32, dsn_col, 2.0)

		# Orbita actual crema (#f4ebd9)
		var pts := s.orbit_points(64, center, planet_px, 0.0)
		if pts.size() >= 2:
			draw_polyline(pts, Color("#f4ebd9"), 1.6)

		# Orbita prevista punteada si hay nodo de maniobra Delta-V
		if s.maneuver_planned:
			var pred := s.orbit_points(64, center, planet_px, s.maneuver_dv_prograde)
			for i: int in range(0, pred.size() - 1, 2):
				draw_line(pred[i], pred[i + 1], Color("#f09c14"), 1.5)
			var node_ang := s.maneuver_node_anomaly_rad + s.arg_periapsis_rad
			var node_p := center + Vector2(cos(node_ang), sin(node_ang)) * (planet_px * 0.78)
			draw_circle(node_p, 4.5, Color("#38bdf8"))

		# Marcadores AP y PE
		var ap_p := center + Vector2(cos(PI + s.arg_periapsis_rad), sin(PI + s.arg_periapsis_rad)) * clampf(planet_px * 0.5 * (1.0 + s.apoapsis_km / maxf(s.planet_radius_km, 1.0)), planet_px * 0.6, planet_px * 1.9)
		var pe_p := center + Vector2(cos(s.arg_periapsis_rad), sin(s.arg_periapsis_rad)) * clampf(planet_px * 0.5 * (1.0 + s.periapsis_km / maxf(s.planet_radius_km, 1.0)), planet_px * 0.56, planet_px * 1.5)
		draw_circle(ap_p, 3.5, Color("#f4ebd9"))
		var pe_danger := s.surface_pressure_bar > 0.0 and s.periapsis_km <= s.atmo_top_km
		draw_circle(pe_p, 3.5, Color("#c83e2b") if pe_danger else Color("#f09c14"))

		# Posicion en tiempo real de la nave + rumbo
		var spos := s.ship_orbit_pos(center, planet_px)
		draw_circle(spos, 4.5, Color("#22c55e"))
		var head := Vector2.UP.rotated(s.ship_angle_rad) * 11.0
		draw_line(spos, spos + head, Color("#38bdf8"), 2.0)

		var font := ThemeDB.fallback_font
		draw_string(font, ap_p + Vector2(6, -4), "AP %.0f" % s.apoapsis_km, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f4ebd9"))
		draw_string(font, pe_p + Vector2(6, 10), "PE %.0f" % s.periapsis_km, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#c83e2b") if pe_danger else Color("#f09c14"))
		draw_string(font, Vector2(8, 16), "KSP 2.5D ORBITA: %s" % s.body_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8b9bb4"))
