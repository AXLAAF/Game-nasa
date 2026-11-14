class_name Gauge
extends Control

## Barra animada con titulo, texto, banda opcional y parpadeo en zona de peligro.

var title: String = ""
var value: float = 0.0
var shown: float = 0.0
var text: String = ""
var color: Color = Ui.CYAN
var band: Vector2 = Vector2(-1, -1)
var danger: bool = false


func _init(gauge_title: String = "", gauge_color: Color = Ui.CYAN) -> void:
	title = gauge_title
	color = gauge_color
	custom_minimum_size = Vector2(220, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float, label_text: String = "", is_danger: bool = false) -> void:
	value = clampf(v, 0.0, 1.0)
	text = label_text
	danger = is_danger


func _process(delta: float) -> void:
	shown = lerpf(shown, value, minf(delta * 8.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var font := Ui.mono()
	var bar := Rect2(0, 16, size.x, size.y - 18)
	draw_string(font, Vector2(0, 12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.DIM)
	draw_string(font, Vector2(0, 12), text, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 12, Ui.TEXT)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	var c := color
	if danger and int(Time.get_ticks_msec() / 180.0) % 2 == 0:
		c = Ui.RED
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown, bar.size.y)), c)
	if band.x >= 0.0:
		var x0 := bar.position.x + bar.size.x * clampf(band.x, 0.0, 1.0)
		var x1 := bar.position.x + bar.size.x * clampf(band.y, 0.0, 1.0)
		draw_rect(Rect2(x0, bar.position.y - 3, maxf(x1 - x0, 2.0), bar.size.y + 6), Color(1, 1, 1, 0.22))
		draw_line(Vector2(x0, bar.position.y - 3), Vector2(x0, bar.end.y + 3), Ui.GOLD, 1.5)
		draw_line(Vector2(x1, bar.position.y - 3), Vector2(x1, bar.end.y + 3), Ui.GOLD, 1.5)
	draw_rect(bar, Color(color.r, color.g, color.b, 0.5), false, 1.0)
