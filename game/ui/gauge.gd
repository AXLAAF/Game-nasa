class_name Gauge
extends Control

## Cinta de medida: leyenda, cifra en mono y barra hundida con marcas cada 10 %.
## En peligro la barra parpadea en rojo y la cifra lleva "!" delante (no solo color).

var title: String = ""
var value: float = 0.0
var shown: float = 0.0
var _vel: float = 0.0
var text: String = ""
var color: Color = Ui.INFO
var band: Vector2 = Vector2(-1, -1)
var danger: bool = false
var on_enamel: bool = false ## sobre chapa: leyenda y cifra en baquelita


func _init(gauge_title: String = "", gauge_color: Color = Ui.INFO) -> void:
	title = gauge_title.to_upper()
	color = gauge_color
	custom_minimum_size = Vector2(200, 38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float, label_text: String = "", is_danger: bool = false) -> void:
	value = clampf(v, 0.0, 1.0)
	text = label_text
	danger = is_danger


func _process(delta: float) -> void:
	var step := Kinetic.spring_step(shown, _vel, value, delta)
	shown = clampf(step.x, 0.0, 1.05)
	_vel = step.y
	queue_redraw()


func _draw() -> void:
	var bar := Rect2(0, 19, size.x, size.y - 21)
	var ink := Ui.BAKELITE if on_enamel else Ui.IVORY
	draw_string(Ui.legend_font(), Vector2(0, 13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_LEGEND, Ui.BAKELITE if on_enamel else Ui.IVORY_DIM)
	draw_string(Ui.mono(), Vector2(0, 13), ("! " if danger else "") + text, HORIZONTAL_ALIGNMENT_RIGHT, size.x, Ui.SIZE_LEGEND, ink)
	draw_rect(bar, Color("0b0c0d"))
	draw_rect(bar, Ui.BAKELITE_EDGE, false, 1.0)
	var c := color
	if danger and (Profile.reduced_motion or int(Time.get_ticks_msec() / 180.0) % 2 == 0):
		c = Ui.LAMP_WARNING
	var inner := bar.grow(-3)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * shown, inner.size.y)), c)
	for k: int in range(1, 10):
		var x := inner.position.x + inner.size.x * k / 10.0
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Ui.BAKELITE, 1.0)
	if band.x >= 0.0:
		var x0 := inner.position.x + inner.size.x * clampf(band.x, 0.0, 1.0)
		var x1 := inner.position.x + inner.size.x * clampf(band.y, 0.0, 1.0)
		draw_rect(Rect2(x0, bar.position.y, maxf(x1 - x0, 2.0), bar.size.y), Color(Ui.IVORY, 0.9), false, 2.0)
