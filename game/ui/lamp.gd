class_name Lamp
extends Label

## Lampara de aviso con leyenda grabada. Apagada = nada que decir.
## Nunca solo color: la leyenda dice a que pieza o condicion se refiere.

enum { OFF, GO, CAUTION, WARNING }

var state: int = OFF
var blink: bool = false
var tint: Color = Color.TRANSPARENT ## color propio (rareza) en vez del de estado
var _shown: Color = Color.TRANSPARENT


func _init(legend: String = "", lamp_state: int = OFF) -> void:
	text = legend.to_upper()
	state = lamp_state
	custom_minimum_size = Vector2(132, 26)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_theme_font_override("font", Ui.legend_font())
	add_theme_font_size_override("font_size", Ui.SIZE_LEGEND)


static func color_of(lamp_state: int) -> Color:
	match lamp_state:
		GO: return Ui.LAMP_GO
		CAUTION: return Ui.LAMP_CAUTION
		WARNING: return Ui.LAMP_WARNING
	return Ui.LAMP_OFF


func _process(_delta: float) -> void:
	var lit := state != OFF and (not blink or Profile.reduced_motion or int(Time.get_ticks_msec() / 350.0) % 2 == 0)
	var color := Ui.LAMP_OFF
	if lit:
		color = tint if tint.a > 0.0 else color_of(state)
	if color == _shown:
		return
	_shown = color
	var style := Ui.box(color, color.darkened(0.35), 0, 3)
	style.border_width_bottom = 2
	style.set_content_margin_all(3)
	add_theme_stylebox_override("normal", style)
	add_theme_color_override("font_color", Ui.BAKELITE if lit else Ui.IVORY_DIM)
