class_name Ui
extends RefCounted

## Tablero de cabina de segunda mano: chapa esmaltada, ventanas de lectura oscuras,
## teclas de baquelita y lamparas. Reglas en docs/DISENO-CABINA.md.
## El texto largo vive en ventanas oscuras; sobre el esmalte solo leyendas en BAKELITE.

const ENAMEL := Color("3e8f8a")
const ENAMEL_LIGHT := Color("6fb5af")
const ENAMEL_SHADE := Color("2c6b67")
const BAKELITE := Color("16181a")
const BAKELITE_RAISED := Color("24272a")
const BAKELITE_EDGE := Color("3a3f44")
const IVORY := Color("efe6cf")
const IVORY_DIM := Color("a9a493")
const INFO := Color("8fd6ce")
const LAMP_GO := Color("58c96b")
const LAMP_CAUTION := Color("ffb000")
const LAMP_WARNING := Color("f46452")
const LAMP_OFF := Color("2a2d30")
const MYSTERY := Color("b48cf2")
const BG := Color("070a10")
const RARITY: Array[Color] = [IVORY, MYSTERY, LAMP_CAUTION]
const RARITY_NAMES: Array[String] = ["Común", "Rara", "Legendaria"]

## Alto de la consola inferior de vuelo; Juice desplaza la camara la mitad.
const CONSOLE_H := 132.0
const SIZE_LEGEND := 13
const SIZE_TEXT := 15
const SIZE_HEAD := 18
const SIZE_READOUT := 24
const SIZE_HERO := 36

static var _theme: Theme
static var _legend: FontVariation
static var _mono: FontVariation
static var _space_mono: FontVariation


static func sans() -> Font:
	return load("res://assets/fonts/B612-Regular.ttf")


static func bold() -> Font:
	return load("res://assets/fonts/B612-Bold.ttf")


static func title_font() -> Font:
	return load("res://assets/fonts/Pixelta.ttf")


## Alternativas de docs/art/fonts para rotulos tecnicos; el tema sigue en B612.
static func exo_bold() -> Font:
	return load("res://assets/fonts/Exo2-Bold.ttf")


## Monospace alternativa para telemetria. FontVariation por el mismo motivo que mono().
static func space_mono() -> Font:
	if _space_mono == null:
		_space_mono = FontVariation.new()
		_space_mono.base_font = load("res://assets/fonts/SpaceMono-Regular.ttf")
	return _space_mono


## Solo para cifras en ventanas de lectura.
## FontVariation: un FontFile crudo sale como bloques con draw_string en este motor.
static func mono() -> Font:
	if _mono == null:
		_mono = FontVariation.new()
		_mono.base_font = load("res://assets/fonts/B612Mono-Regular.ttf")
	return _mono


## Leyenda grabada: negrita con un punto de espaciado. Unico uso de mayusculas.
static func legend_font() -> Font:
	if _legend == null:
		_legend = FontVariation.new()
		_legend.base_font = bold()
		_legend.spacing_glyph = 1
	return _legend


static func box(bg: Color, border: Color, width: int = 1, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## Ventana oscura con bisel de esmalte: el panel por defecto.
static func bezel(accent: Color = ENAMEL) -> StyleBoxFlat:
	var style := box(BAKELITE, accent, 4, 6)
	style.border_width_bottom = 7
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


## Chapa esmaltada lisa (consola, placas). Solo admite leyendas en BAKELITE.
static func enamel() -> StyleBoxFlat:
	var style := box(ENAMEL, ENAMEL_SHADE, 0, 3)
	style.border_width_bottom = 4
	style.set_content_margin_all(10)
	return style


## Hueco de lectura hundido en la chapa.
static func well_box() -> StyleBoxFlat:
	var style := box(BAKELITE, Color("0b0c0d"), 0, 3)
	style.border_width_top = 3
	style.content_margin_top = 5
	return style


static func _key(bg: Color, edge: Color, pressed: bool = false, pad: int = 7) -> StyleBoxFlat:
	var style := box(bg, edge, 1, 4)
	style.border_width_bottom = 1 if pressed else 4
	style.content_margin_top = pad + 3 if pressed else pad
	style.content_margin_bottom = pad
	style.content_margin_left = pad * 2
	style.content_margin_right = pad * 2
	return style


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = sans()
	_theme.default_font_size = SIZE_TEXT
	_theme.set_stylebox("normal", "Button", _key(BAKELITE_RAISED, BAKELITE_EDGE))
	_theme.set_stylebox("hover", "Button", _key(Color("30353a"), IVORY_DIM))
	_theme.set_stylebox("pressed", "Button", _key(Color("101113"), IVORY_DIM, true))
	_theme.set_stylebox("disabled", "Button", _key(Color("1b1d1f"), Color("26292c")))
	var focus := box(Color.TRANSPARENT, IVORY, 2, 6)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	_theme.set_stylebox("focus", "Button", focus)
	_theme.set_color("font_color", "Button", IVORY)
	_theme.set_color("font_hover_color", "Button", IVORY)
	_theme.set_color("font_pressed_color", "Button", IVORY)
	_theme.set_color("font_focus_color", "Button", IVORY)
	_theme.set_color("font_disabled_color", "Button", Color("8a887d"))
	_theme.set_stylebox("panel", "PanelContainer", bezel())
	_theme.set_stylebox("panel", "Panel", bezel())
	_theme.set_color("font_color", "Label", IVORY)
	_theme.set_color("default_color", "RichTextLabel", IVORY)
	_theme.set_stylebox("panel", "TooltipPanel", box(BAKELITE, IVORY_DIM))
	_theme.set_color("font_color", "TooltipLabel", IVORY)
	var grabber := box(BAKELITE_EDGE, BAKELITE_EDGE, 0, 3)
	grabber.set_content_margin_all(3)
	_theme.set_stylebox("grabber", "VScrollBar", grabber)
	_theme.set_stylebox("grabber_highlight", "VScrollBar", box(IVORY_DIM, IVORY_DIM, 0, 3))
	_theme.set_stylebox("grabber_pressed", "VScrollBar", box(IVORY, IVORY, 0, 3))
	_theme.set_stylebox("scroll", "VScrollBar", box(Color("0b0c0d"), BAKELITE, 0, 3))
	var track := box(BAKELITE_EDGE, BAKELITE_EDGE, 0, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	_theme.set_stylebox("slider", "HSlider", track)
	var fill := box(ENAMEL_LIGHT, ENAMEL_LIGHT, 0, 3)
	_theme.set_stylebox("grabber_area", "HSlider", fill)
	_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := Image.create(12, 22, false, Image.FORMAT_RGBA8)
	knob.fill(IVORY)
	var knob_tex := ImageTexture.create_from_image(knob)
	for state: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		_theme.set_icon(state, "HSlider", knob_tex)
	return _theme


## Tecla principal de la pantalla: marfil sobre baquelita. Una por pantalla.
static func primary(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", _key(IVORY, IVORY_DIM))
	b.add_theme_stylebox_override("hover", _key(Color("fff6dc"), IVORY_DIM))
	b.add_theme_stylebox_override("pressed", _key(IVORY_DIM, IVORY_DIM, true))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, BAKELITE)
	b.add_theme_font_override("font", bold())
	return b


## Tecla baja para la consola de vuelo: caben tres filas en CONSOLE_H.
static func compact(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", _key(BAKELITE_RAISED, BAKELITE_EDGE, false, 3))
	b.add_theme_stylebox_override("hover", _key(Color("30353a"), IVORY_DIM, false, 3))
	b.add_theme_stylebox_override("pressed", _key(Color("101113"), IVORY_DIM, true, 3))
	b.add_theme_stylebox_override("disabled", _key(Color("1b1d1f"), Color("26292c"), false, 3))
	b.add_theme_font_size_override("font_size", SIZE_LEGEND)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## Rejilla de teclas compactas al final de la consola.
static func console_keys(row: HBoxContainer, columns: int = 2) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(grid)
	return grid


## Rejilla de cintas de medida sobre la consola. Las cintas se anaden con console_gauge.
static func console_gauges(row: HBoxContainer, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(grid)
	return grid


static func console_gauge(grid: GridContainer, title: String, color: Color) -> Gauge:
	var g := Gauge.new(title, color)
	g.on_enamel = true
	g.custom_minimum_size.x = 150
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(g)
	return g


## Linea de teclas justo encima de la consola, abajo a la izquierda.
static func keys(root: Control, text: String) -> Label:
	var l := label(root, text, SIZE_LEGEND, IVORY)
	l.add_theme_stylebox_override("normal", box(Color(BAKELITE, 0.9), BAKELITE_EDGE, 0, 3))
	l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_left = 12
	l.offset_bottom = -CONSOLE_H - 10
	l.offset_top = l.offset_bottom
	return l


## Rotulo grande centrado arriba (cuenta atras, avisos de fase).
static func banner(root: Control, size: int, y: float) -> Label:
	var l := label(root, "", size, IVORY)
	l.add_theme_font_override("font", bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = y
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l


## Matriz de lamparas de la nave, arriba a la derecha.
static func annunciator(root: Control) -> Annunciator:
	var board := Annunciator.new()
	board.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	board.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	board.offset_right = -12
	board.offset_left = -12
	board.offset_top = 12
	root.add_child(board)
	return board


## Opcion elegida en un selector (seguro, calidad): borde marfil y negrita.
static func mark_selected(b: Button, on: bool) -> Button:
	if on:
		var style := _key(BAKELITE_RAISED, IVORY)
		style.set_border_width_all(2)
		style.border_width_bottom = 4
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_font_override("font", bold())
	else:
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_font_override("font")
	b.add_theme_color_override("font_color", IVORY if on else IVORY_DIM)
	return b


## Leyenda grabada en mayusculas. on_enamel = sobre chapa (negro); si no, dentro de ventana.
static func legend(parent: Node, text: String, on_enamel: bool = false) -> Label:
	var l := label(parent, text.to_upper(), SIZE_LEGEND, BAKELITE if on_enamel else IVORY_DIM)
	l.add_theme_font_override("font", legend_font())
	return l


## Placa esmaltada con leyenda: cabecera de un panel.
static func plate(parent: Node, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var style := enamel()
	style.set_content_margin_all(5)
	style.content_margin_left = 10
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	legend(p, text, true)
	return p


static func well(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", well_box())
	parent.add_child(p)
	return p


## Instrumento de lectura sobre chapa: leyenda, cifra en mono y unidad. Devuelve la cifra.
static func readout(parent: Node, legend_text: String, unit: String = "", min_width: float = 110.0) -> Label:
	var col := vbox(parent, 3)
	legend(col, legend_text, true)
	var w := well(col)
	w.custom_minimum_size = Vector2(min_width, 0)
	var row := hbox(w, 6)
	var value := label(row, "", SIZE_READOUT, IVORY)
	value.add_theme_font_override("font", mono())
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if unit != "":
		var u := label(row, unit, SIZE_LEGEND, IVORY_DIM)
		u.size_flags_vertical = Control.SIZE_SHRINK_END
	return value


## Consola inferior de las fases de vuelo. Devuelve la fila donde van los instrumentos.
static func console(root: Control) -> HBoxContainer:
	var p := PanelContainer.new()
	var style := enamel()
	style.border_width_bottom = 0
	style.border_width_top = 3
	style.border_color = ENAMEL_LIGHT
	style.set_corner_radius_all(0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	p.add_theme_stylebox_override("panel", style)
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_top = -CONSOLE_H
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(p)
	Kinetic.enter_deferred(p, 0.02, {"slide": true, "slide_offset": Vector2(-18.0, 36.0), "scale": Vector2(0.98, 0.94), "tilt": 0.0, "beam": true, "duration": 0.32})
	return hbox(p, 14)


## Capa de UI con un Control raiz a pantalla completa que hereda el tema.
static func root(parent: Node, layer_index: int = 10) -> Control:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	parent.add_child(layer)
	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.theme = theme()
	layer.add_child(control)
	return control


static func label(parent: Node, text: String, size: int = 15, color: Color = IVORY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Synth.play(&"click"))
	b.pressed.connect(callback)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Synth.play(&"tick", -16.0))
	Kinetic.bind_button(b)
	parent.add_child(b)
	return b


static func panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p


static func vbox(parent: Node, separation: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	parent.add_child(v)
	return v


static func hbox(parent: Node, separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	parent.add_child(h)
	return h


static func place(control: Control, rect: Rect2) -> Control:
	control.position = rect.position
	control.size = rect.size
	return control


## Despliega el detalle de la matriz de lamparas. Si la fase no tiene una, la crea arriba a la derecha.
static func toggle_status(host: Node) -> void:
	if Annunciator.current == null or not is_instance_valid(Annunciator.current):
		annunciator(root(host, 30))
	Annunciator.toggle_detail()


static var _mist_tex: GradientTexture2D


static func mist_texture() -> GradientTexture2D:
	if _mist_tex != null:
		return _mist_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_mist_tex = tex
	return _mist_tex


static func money(amount: int) -> String:
	return "$%s" % _thousands(amount)


static func _thousands(amount: int) -> String:
	var text := str(absi(amount))
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if amount < 0 else "") + text + out
