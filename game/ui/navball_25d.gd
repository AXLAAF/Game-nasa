class_name NavBall25D
extends Control

var _solver: OrbitalSolver
var _manned: bool = true


func bind_solver(solver: OrbitalSolver) -> void:
	_solver = solver


func set_manned(manned: bool) -> void:
	_manned = manned


func _process(_delta: float) -> void:
	queue_redraw()


func _draw_semicircle(center: Vector2, radius: float, start_ang: float, end_ang: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var segs := 24
	for i: int in range(segs + 1):
		var a := lerpf(start_ang, end_ang, float(i) / float(segs))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.44
	draw_circle(c, r + 2.0, SpaceTheme.COL_SEAM)

	# Hemisferios artificiales completos cielo/tierra rotados segun la nave
	var ang := _solver.ship_angle_rad if _solver != null else 0.0
	var up_vec := Vector2.UP.rotated(ang)
	var right_vec := Vector2.RIGHT.rotated(ang)
	_draw_semicircle(c, r - 1.5, ang + PI, ang + TAU, Color("#1d4ed8"))
	_draw_semicircle(c, r - 1.5, ang, ang + PI, Color("#9a3412"))

	# Horizonte artificial crema + marcas de cabeceo
	draw_line(c - right_vec * (r - 1.5), c + right_vec * (r - 1.5), SpaceTheme.COL_CREAM, 1.5)
	draw_line(c - right_vec * (r * 0.35) + up_vec * (r * 0.25), c + right_vec * (r * 0.35) + up_vec * (r * 0.25), Color(0.96, 0.92, 0.85, 0.5), 1.0)
	draw_line(c - right_vec * (r * 0.35) - up_vec * (r * 0.25), c + right_vec * (r * 0.35) - up_vec * (r * 0.25), Color(0.96, 0.92, 0.85, 0.5), 1.0)

	# Pipa Prograde (verde) y vector Nodo (diamante cian)
	var pro_pos := c + Vector2(sin(-ang), -cos(-ang)) * (r * 0.52)
	draw_arc(pro_pos, 4.5, 0.0, TAU, 16, SpaceTheme.COL_OK, 1.8)
	var node_pos := c + up_vec * (r * 0.65)
	draw_colored_polygon(
		PackedVector2Array([
			node_pos + Vector2(0, -4.5),
			node_pos + Vector2(4.5, 0),
			node_pos + Vector2(0, 4.5),
			node_pos + Vector2(-4.5, 0),
		]),
		SpaceTheme.COL_CYAN
	)

	# Reticula central fija en W naranja KSP + anillo exterior de estado
	draw_polyline(
		PackedVector2Array([
			c + Vector2(-10.0, 0.0),
			c + Vector2(-4.0, 0.0),
			c + Vector2(0.0, 5.0),
			c + Vector2(4.0, 0.0),
			c + Vector2(10.0, 0.0),
		]),
		SpaceTheme.COL_AMBER,
		2.0
	)
	var ring_col := SpaceTheme.COL_OK if _manned else SpaceTheme.COL_MUTED
	draw_arc(c, r, 0.0, TAU, 36, ring_col, 2.0)

	if _solver != null and _solver.surface_pressure_bar > 0.0:
		var in_corr := _solver.reentry_pitch_deg >= -5.2 and _solver.reentry_pitch_deg <= -3.8
		var mono := SpaceTheme.mono_font()
		var txt_col := SpaceTheme.COL_OK if in_corr else SpaceTheme.COL_TERRA
		draw_string(mono, Vector2(4.0, size.y - 3.0), "%.1f deg" % _solver.reentry_pitch_deg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, txt_col)
