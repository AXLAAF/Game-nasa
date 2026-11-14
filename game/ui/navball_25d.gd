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


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.44
	draw_circle(c, r, Color("#0f1726"))

	# Hemisferios artificiales segun angulo de la nave
	var ang := _solver.ship_angle_rad if _solver != null else 0.0
	var up_vec := Vector2.UP.rotated(ang)
	var right_vec := Vector2.RIGHT.rotated(ang)
	draw_arc(c, r - 2.0, ang + PI, ang + TAU, 24, Color("#1e3a5f"), r * 0.45)
	draw_arc(c, r - 2.0, ang, ang + PI, 24, Color("#5c3317"), r * 0.45)
	draw_line(c - right_vec * (r - 2.0), c + right_vec * (r - 2.0), Color("#f4ebd9"), 1.5)

	# Pipa Prograde (verde) y Retrograde (verde claro)
	var pro_pos := c + Vector2(sin(-ang), -cos(-ang)) * (r * 0.52)
	draw_circle(pro_pos, 4.0, Color("#22c55e"))
	# Pipa de Nodo (diamante cian)
	var node_pos := c + up_vec * (r * 0.65)
	draw_circle(node_pos, 3.5, Color("#38bdf8"))

	# Reticula central fija + contorno
	draw_circle(c, 3.0, Color("#f09c14"))
	var ring_col := Color("#22c55e") if _manned else Color("#8b9bb4")
	draw_arc(c, r, 0.0, TAU, 36, ring_col, 2.0)

	if _solver != null and _solver.surface_pressure_bar > 0.0:
		var in_corr := _solver.reentry_pitch_deg >= -5.2 and _solver.reentry_pitch_deg <= -3.8
		var font := ThemeDB.fallback_font
		var txt_col := Color("#22c55e") if in_corr else Color("#c83e2b")
		draw_string(font, Vector2(4, size.y - 3), "%.1f deg" % _solver.reentry_pitch_deg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, txt_col)
