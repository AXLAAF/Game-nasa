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
	draw_rect(Rect2(Vector2.ZERO, size), SpaceTheme.COL_CRT, true)
	draw_rect(Rect2(Vector2.ZERO, size), SpaceTheme.COL_SEAM, false, 1.5)

	var sans := SpaceTheme.sans_font()
	var mono := SpaceTheme.mono_font()

	if not sensors_online or emp_glitch_s > 0.0:
		for gy: float in range(16, int(size.y) - 8, 12):
			draw_line(Vector2(6, gy), Vector2(size.x - 6, gy), Color(0.78, 0.24, 0.17, 0.14), 1.0)
		draw_string(sans, Vector2(12, size.y * 0.44), "RADAR SIN SENAL / SEU", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpaceTheme.COL_TERRA)
		draw_string(sans, Vector2(12, size.y * 0.58), "Asigna barras a Sensores o activa Storm Safe", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 11, SpaceTheme.COL_MUTED)
		return

	var t := float(Time.get_ticks_msec()) * 0.001
	var origin := Vector2(size.x * 0.50, size.y * 0.48)
	var rows := 7
	var cols := 7
	var span_x := size.x * 0.44
	var span_y := size.y * 0.19

	# Construir grilla topografica 3D isometrica (ref. pin_26)
	var pts: Array = []
	for r: int in range(rows + 1):
		var row_arr: Array[Vector2] = []
		var v := float(r) / float(rows) - 0.5
		for c: int in range(cols + 1):
			var u := float(c) / float(cols) - 0.5
			var wave := sin(u * 6.5 + t * 0.9) * cos(v * 6.5 - t * 0.5)
			var ridge := 0.55 * sin((u - v) * 8.0 + t * 0.4)
			var elev := (wave + ridge) * 10.0
			var sx := origin.x + (u - v) * span_x
			var sy := origin.y + (u + v) * span_y - elev
			row_arr.append(Vector2(sx, sy))
		pts.append(row_arr)

	# Cortina LIDAR vertical azul/cian sobre zona central de la malla (pin_26)
	for r: int in range(1, rows):
		for c: int in range(1, cols):
			var p: Vector2 = pts[r][c]
			var dist_center := absf(float(r) / float(rows) - 0.5) + absf(float(c) / float(cols) - 0.5)
			if dist_center < 0.58:
				var col_h := (1.0 - dist_center * 1.45) * (size.y * 0.24) + 6.0 * sin(t * 2.1 + float(r + c))
				if col_h > 4.0:
					draw_line(p, p - Vector2(0.0, col_h), Color(0.0, 0.55, 1.0, 0.38), 1.5)
					draw_line(p - Vector2(0.0, col_h * 0.55), p - Vector2(0.0, col_h), Color(0.0, 0.85, 1.0, 0.65), 1.0)

	# Malla wireframe naranja (#ff6a00 / #a94a28)
	for r: int in range(rows + 1):
		for c: int in range(cols):
			draw_line(pts[r][c], pts[r][c + 1], Color(1.0, 0.416, 0.0, 0.82), 1.0)
	for c: int in range(cols + 1):
		for r: int in range(rows):
			draw_line(pts[r][c], pts[r + 1][c], Color(0.663, 0.290, 0.157, 0.72), 1.0)

	# Contactos entrantes con agujas verticales cian y esfera naranja (CelesTrak / DONKI / NEO)
	for idx: int in range(hazards_queue.size()):
		var hz: Dictionary = hazards_queue[idx]
		var rem := float(hz.get("eta_s", 10.0))
		var norm_d := clampf(rem / maxf(warn_lead_s, 1.0), 0.0, 1.0)
		var lane := clampf(float(hz.get("lane_x", 0.0)), -1.0, 1.0)
		var u := lane * 0.42
		var v := 0.42 - norm_d * 0.84
		var base_p := Vector2(origin.x + (u - v) * span_x, origin.y + (u + v) * span_y)
		var needle_h := 28.0 + norm_d * 26.0
		var top_p := base_p - Vector2(0.0, needle_h)
		var kind := str(hz.get("kind", "debris"))
		var head_col := Color("#c83e2b") if kind == "debris" else (Color("#ff8c00") if kind == "solar" else Color("#22c55e"))

		draw_line(base_p, top_p, Color("#00d2ff"), 1.5)
		draw_circle(base_p, 2.0, Color("#00d2ff"))
		draw_circle(top_p, 4.5, head_col)
		draw_arc(top_p, 4.5, 0.0, TAU, 16, Color("#fff1c2"), 1.0)
		draw_string(mono, top_p + Vector2(7.0, 4.0), "%s %.1fs" % [str(hz.get("short", "OBJ")), rem], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#00d2ff"))

	# Encabezado superior y bloque tabular tecnico inferior izquierdo (pin_26)
	draw_string(sans, Vector2(10.0, 17.0), "RADAR TOPOGRAFICO 3D", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SpaceTheme.COL_CYAN)
	var first_eta := float(hazards_queue[0].get("eta_s", warn_lead_s)) if not hazards_queue.is_empty() else warn_lead_s
	var first_dist := first_eta * 1.45
	var v_rel := 7.8 if not hazards_queue.is_empty() else 0.0
	draw_string(mono, Vector2(10.0, size.y - 22.0), "dist %.1f km | v_rel %.1f km/s" % [first_dist, v_rel], HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 11, Color("#ff8c00"))
	draw_string(mono, Vector2(10.0, size.y - 8.0), "contacts %d | warn %.0fs" % [hazards_queue.size(), warn_lead_s], HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 11, Color("#ff8c00"))
