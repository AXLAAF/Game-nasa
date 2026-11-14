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
		"neo", "asteroid":
			_planet_mat.set_shader_parameter("planet_type", 4)
			_planet_mat.set_shader_parameter("col_a", Color("#334155"))
			_planet_mat.set_shader_parameter("col_b", Color("#64748b"))
			_planet_mat.set_shader_parameter("col_c", Color("#cbd5e1"))
			_planet_mat.set_shader_parameter("col_atmo", Color(0.0, 0.0, 0.0, 0.0))
		_:
			_planet_mat.set_shader_parameter("planet_type", 0)
			_planet_mat.set_shader_parameter("col_a", Color("#1e3a8a"))
			_planet_mat.set_shader_parameter("col_b", Color("#22c55e"))
			_planet_mat.set_shader_parameter("col_c", Color("#f8fafc"))
			_planet_mat.set_shader_parameter("col_atmo", Color(0.22, 0.74, 0.97, 0.45))


func _process(_delta: float) -> void:
	if _planet_rect != null and _draw_overlay != null:
		var min_dim := minf(size.x, size.y)
		var side := min_dim * 0.40
		_planet_rect.size = Vector2(side, side)
		_planet_rect.position = (size - _planet_rect.size) * 0.5
		if _planet_mat != null:
			_planet_mat.set_shader_parameter("pixels", 64.0 if min_dim < 200.0 else 96.0)
		_draw_overlay.size = size
		_draw_overlay.queue_redraw()


class _OrbitOverlay extends Control:
	var _owner: OrbitalMap25D

	func _init(owner_node: OrbitalMap25D) -> void:
		_owner = owner_node

	func _draw_pill_label(font: Font, pos: Vector2, text_str: String, text_col: Color) -> void:
		var text_sz := font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var pad := Vector2(5.0, 2.0)
		var box := Rect2(pos.x - pad.x, pos.y - text_sz.y, text_sz.x + pad.x * 2.0, text_sz.y + pad.y * 2.0)
		draw_rect(box, Color(0.024, 0.039, 0.071, 0.92), true)
		draw_rect(box, Color(0.14, 0.20, 0.30, 0.85), false, 1.0)
		draw_string(font, pos, text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_col)

	func _draw() -> void:
		if _owner._solver == null:
			return
		var s := _owner._solver
		var center := size * 0.5
		var min_dim := minf(size.x, size.y)
		var planet_px := min_dim * 0.38
		var compact := min_dim < 180.0
		var sans := SpaceTheme.sans_font()
		var mono := SpaceTheme.mono_font()

		# Regla vertical graduada izquierda estilo Rhine Lab (pin_18)
		if not compact:
			var rx := 10.0
			draw_line(Vector2(rx, 30.0), Vector2(rx, size.y - 16.0), Color(0.55, 0.61, 0.71, 0.45), 1.0)
			var ty := 30.0
			var tick_idx := 0
			while ty < size.y - 16.0:
				var tick_w := 7.0 if (tick_idx % 4) == 0 else 3.5
				draw_line(Vector2(rx, ty), Vector2(rx + tick_w, ty), Color(0.55, 0.61, 0.71, 0.55), 1.0)
				ty += 6.0
				tick_idx += 1

		# Anillos de escala Rhine Lab
		draw_arc(center, planet_px * 0.62, 0.0, TAU, 48, Color(0.22, 0.74, 0.97, 0.25), 1.0)
		draw_arc(center, planet_px * 1.12, 0.0, TAU, 64, Color(0.55, 0.61, 0.71, 0.20), 1.0)
		if not compact:
			draw_string(mono, center + Vector2(planet_px * 0.82, -planet_px * 0.80), "5000 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SpaceTheme.COL_MUTED)
			if s.surface_pressure_bar > 0.0:
				draw_arc(center, planet_px * 0.55, 0.0, TAU, 48, SpaceTheme.COL_TERRA, 1.5)
				# Corredor de reentrada atmosferico en arco terracota (pin_18 / mockup_2)
				draw_arc(center, planet_px * 0.59, -0.35, 0.75, 24, SpaceTheme.COL_TERRA, 3.0)
				_draw_pill_label(mono, center + Vector2(-46.0, planet_px * 0.68), "ATMO 100 km", SpaceTheme.COL_TERRA)

		# Enlace de linea de vista DSN hacia Tierra
		if s.dsn_window_open:
			var dsn_end := Vector2(size.x - 12.0, 26.0)
			var pts_dsn := 14
			for i: int in range(0, pts_dsn, 2):
				var t0 := float(i) / float(pts_dsn)
				var t1 := float(i + 1) / float(pts_dsn)
				draw_line(center.lerp(dsn_end, t0), center.lerp(dsn_end, t1), Color(0.22, 0.74, 0.97, 0.45), 1.0)
		var dsn_col := Color(0.13, 0.77, 0.37, 0.35 if s.dsn_window_open else 0.10)
		draw_arc(center, planet_px * 1.25, -PI * 0.15, PI * 1.15, 32, dsn_col, 1.8)

		# Orbita actual crema (#f4ebd9) + chevrones de direccion
		var pts := s.orbit_points(64, center, planet_px, 0.0)
		if pts.size() >= 2:
			draw_polyline(pts, SpaceTheme.COL_CREAM, 1.6)
			for ci: int in [12, 32, 52]:
				if ci + 1 < pts.size():
					var p0 := pts[ci]
					var dir := (pts[ci + 1] - p0).normalized()
					var perp := Vector2(-dir.y, dir.x)
					draw_colored_polygon(
						PackedVector2Array([p0 + dir * 5.0, p0 - dir * 3.0 + perp * 3.5, p0 - dir * 3.0 - perp * 3.5]),
						SpaceTheme.COL_CREAM
					)

		# Orbita prevista punteada si hay nodo de maniobra Delta-V
		if s.maneuver_planned:
			var pred := s.orbit_points(64, center, planet_px, s.maneuver_dv_prograde)
			for i: int in range(0, pred.size() - 1, 2):
				draw_line(pred[i], pred[i + 1], SpaceTheme.COL_AMBER, 1.5)
			var node_ang := s.maneuver_node_anomaly_rad + s.arg_periapsis_rad
			var node_p := center + Vector2(cos(node_ang), sin(node_ang)) * (planet_px * 0.78)
			draw_arc(node_p, 5.5, 0.0, TAU, 16, SpaceTheme.COL_AMBER, 1.8)
			draw_circle(node_p, 2.2, SpaceTheme.COL_CREAM)

		# Marcadores AP y PE con pildoras oscuras anti-cruce
		var ap_p := center + Vector2(cos(PI + s.arg_periapsis_rad), sin(PI + s.arg_periapsis_rad)) * clampf(planet_px * 0.5 * (1.0 + s.apoapsis_km / maxf(s.planet_radius_km, 1.0)), planet_px * 0.6, planet_px * 1.9)
		var pe_p := center + Vector2(cos(s.arg_periapsis_rad), sin(s.arg_periapsis_rad)) * clampf(planet_px * 0.5 * (1.0 + s.periapsis_km / maxf(s.planet_radius_km, 1.0)), planet_px * 0.56, planet_px * 1.5)
		draw_circle(ap_p, 3.5, SpaceTheme.COL_CREAM)
		var pe_danger := s.surface_pressure_bar > 0.0 and s.periapsis_km <= s.atmo_top_km
		var pe_col := SpaceTheme.COL_TERRA if pe_danger else SpaceTheme.COL_CYAN
		draw_circle(pe_p, 3.5, pe_col)

		# Posicion en tiempo real de la nave + estela tricolor retro-NASA (pin_18)
		var spos := s.ship_orbit_pos(center, planet_px)
		var fwd := Vector2.UP.rotated(s.ship_angle_rad)
		var right := Vector2(fwd.y, -fwd.x)
		var trail_cols: Array[Color] = [SpaceTheme.COL_TERRA, SpaceTheme.COL_AMBER, SpaceTheme.COL_CYAN]
		for ti: int in range(3):
			var lat_off := float(ti - 1) * 2.2
			var t_start := spos - fwd * 4.0 + right * lat_off
			var t_end := t_start - fwd * 14.0
			draw_line(t_start, t_end, trail_cols[ti], 1.5)
		draw_colored_polygon(
			PackedVector2Array([spos + fwd * 8.0, spos - fwd * 4.0 + right * 4.5, spos - fwd * 4.0 - right * 4.5]),
			SpaceTheme.COL_CYAN
		)

		if not compact:
			var ap_lbl_pos := Vector2(clampf(ap_p.x + 8.0, 22.0, size.x - 86.0), clampf(ap_p.y - 6.0, 34.0, size.y - 12.0))
			var pe_lbl_pos := Vector2(clampf(pe_p.x + 8.0, 22.0, size.x - 86.0), clampf(pe_p.y + 14.0, 34.0, size.y - 12.0))
			_draw_pill_label(mono, ap_lbl_pos, "AP %.0f km" % s.apoapsis_km, SpaceTheme.COL_CREAM)
			_draw_pill_label(mono, pe_lbl_pos, "PE %.0f km" % s.periapsis_km, pe_col)
			draw_string(sans, Vector2(22.0, 18.0), "ORBITA KSP 2.5D: %s" % s.body_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SpaceTheme.COL_MUTED)
		else:
			draw_string(sans, Vector2(8.0, 16.0), s.body_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SpaceTheme.COL_MUTED)
