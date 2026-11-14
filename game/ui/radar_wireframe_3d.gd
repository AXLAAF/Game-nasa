class_name RadarWireframe3D
extends Control

var hazards_queue: Array[Dictionary] = []
var sensors_online: bool = true
var emp_glitch_s: float = 0.0
var warn_lead_s: float = 12.0


func _process(delta: float) -> void:
	emp_glitch_s = maxf(emp_glitch_s - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#080c16"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1e2d47"), false, 1.5)

	var font := ThemeDB.fallback_font
	if not sensors_online or emp_glitch_s > 0.0:
		draw_string(font, Vector2(12, size.y * 0.45), "RADAR SIN SENAL / SEU", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#c83e2b"))
		draw_string(font, Vector2(12, size.y * 0.58), "Asigna barras o activa Storm Safe", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8b9bb4"))
		return

	var t := float(Time.get_ticks_msec()) * 0.001
	var origin := Vector2(size.x * 0.5, size.y * 0.62)
	var rows := 5
	var cols := 6
	var w := size.x * 0.78
	var h := size.y * 0.48

	# Malla isometrica wireframe giratoria estilo pin_26
	for r: int in range(rows + 1):
		var z_f := float(r) / float(rows)
		var y_r := origin.y - z_f * h + 18.0
		var half_w := w * 0.5 * (1.0 - z_f * 0.35)
		var x_shift := sin(t * 0.6 + r * 0.3) * 4.0
		draw_line(Vector2(origin.x - half_w + x_shift, y_r), Vector2(origin.x + half_w + x_shift, y_r), Color(0.22, 0.74, 0.97, 0.32), 1.0)
	for c_idx: int in range(cols + 1):
		var x_f := (float(c_idx) / float(cols)) * 2.0 - 1.0
		var p_bot := Vector2(origin.x + x_f * (w * 0.5), origin.y + 18.0)
		var p_top := Vector2(origin.x + x_f * (w * 0.325), origin.y - h + 18.0)
		draw_line(p_bot, p_top, Color(0.22, 0.74, 0.97, 0.25), 1.0)

	# Cono de deteccion central
	draw_line(origin + Vector2(0, 18), origin + Vector2(-46, -h + 18), Color(0.94, 0.61, 0.08, 0.55), 1.2)
	draw_line(origin + Vector2(0, 18), origin + Vector2(46, -h + 18), Color(0.94, 0.61, 0.08, 0.55), 1.2)

	# Dibujar contactos entrantes (CelesTrak debris, DONKI CME, NEO)
	for idx: int in range(hazards_queue.size()):
		var hz: Dictionary = hazards_queue[idx]
		var rem := float(hz.get("eta_s", 10.0))
		var norm_d := clampf(rem / maxf(warn_lead_s, 1.0), 0.0, 1.0)
		var lane := clampf(float(hz.get("lane_x", 0.0)), -1.0, 1.0)
		var px := origin.x + lane * (w * 0.36 * (0.4 + 0.6 * norm_d))
		var py := (origin.y + 12.0) - norm_d * (h * 0.9)
		var kind := str(hz.get("kind", "debris"))
		var dot_col := Color("#c83e2b") if kind == "debris" else (Color("#f09c14") if kind == "solar" else Color("#22c55e"))
		draw_circle(Vector2(px, py), 5.0, dot_col)
		draw_string(font, Vector2(px + 8, py + 4), "%s %.1fs" % [str(hz.get("short", "OBJ")), rem], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dot_col)

	draw_string(font, Vector2(10, 18), "RADAR 3D WIREFRAME | AVISO %.0fs" % warn_lead_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#38bdf8"))
