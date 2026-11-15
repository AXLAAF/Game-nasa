class_name Ui
extends RefCounted

## Tablero de la identidad Margin Zero: bastidores azul noche, tinta crema, ambar para la accion,
## cian para el dato y terracota para la deuda. Reglas en docs/DISENO-CABINA.md.
## Los nombres de los tokens vienen del tablero de cabina anterior; el papel de cada uno no cambia.

const ENAMEL := Color("172236") ## consola y placas (surface_raised)
const ENAMEL_LIGHT := Color("38bdf8") ## filo de la consola y relleno de deslizadores
const ENAMEL_SHADE := Color("0b0e17") ## contorno y huecos hundidos (outline_pixel)
const BAKELITE := Color("0f1726") ## panel (surface_chassis)
const BAKELITE_RAISED := Color("172236") ## tecla y fila elevada (surface_raised)
const BAKELITE_EDGE := Color("1e2d47") ## borde y banda de seleccion
const IVORY := Color("f4ebd9") ## texto (ink_cream)
const IVORY_DIM := Color("8b9bb4") ## texto secundario (ink_muted)
const INFO := Color("38bdf8") ## dato real y telemetria nominal (accent_cyan)
const ACCENT := Color("f09c14") ## tecla principal (accent_amber)
const TERRACOTTA := Color("c83e2b") ## marca de deuda: solo rellenos y bordes, no llega a 4.5:1 como texto
const LAMP_GO := Color("22c55e")
const LAMP_CAUTION := Color("f09c14")
const LAMP_WARNING := Color("e8604a") ## terracota encendido: pasa 4.5:1 como texto sobre el panel
const LAMP_OFF := Color("1e2d47")
const MYSTERY := Color("b48cf2")
const BG := Color("080c16")
## Vidrio: opacidad del tinte de un panel (el resto es fondo desenfocado) y filo de luz.
const GLASS_TINT := 0.6
const KEY_TINT := 0.62 ## teclas translucidas sobre el vidrio
const RIM := Color(0.957, 0.922, 0.851, 0.22) ## IVORY al 22 %
const GLASS_SHADER: Shader = preload("res://game/shaders/glass.gdshader")
const RARITY: Array[Color] = [IVORY, MYSTERY, LAMP_CAUTION]
const RARITY_NAMES: Array[String] = ["Común", "Rara", "Legendaria"]

## Caja de los avisos de vuelo (Ticker), a la derecha del engranaje de Pause.
const TICKER_RECT := Rect2(44, 12, 380, 200)
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
static var _glass: ShaderMaterial


static func sans() -> Font:
	return load("res://assets/fonts/Exo2-Regular.ttf")


static func bold() -> Font:
	return load("res://assets/fonts/Exo2-SemiBold.ttf")


static func title_font() -> Font:
	return load("res://assets/fonts/Pixelta.ttf")


## Solo para cifras en ventanas de lectura.
## FontVariation: un FontFile crudo sale como bloques con draw_string en este motor.
static func mono() -> Font:
	if _mono == null:
		_mono = FontVariation.new()
		_mono.base_font = load("res://assets/fonts/SpaceMono-Regular.ttf")
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


## Panel de vidrio por defecto: tinte translucido y filo de luz, mas marcado arriba.
## accent lo recalca (tarjetas flotantes). Sin sombra: en el vidrio la sombra se veria como fondo.
static func bezel(accent: Color = RIM) -> StyleBoxFlat:
	var style := box(Color(BAKELITE, GLASS_TINT), accent, 1, 12)
	style.border_width_top = 2
	style.set_content_margin_all(14)
	return style


## Vidrio liquido: el control desenfoca lo que tiene detras y lo tine con su estilo.
## Solo en paneles de primer nivel; los anidados ya quedan translucidos sobre el vidrio del padre.
static func glass(c: Control) -> Control:
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = GLASS_SHADER
	c.material = _glass
	return c


## Banda elevada (consola, placas) con filo cian a la izquierda.
static func enamel() -> StyleBoxFlat:
	var style := box(Color(ENAMEL, 0.55), ENAMEL_LIGHT, 0, 8)
	style.border_width_left = 3
	style.set_content_margin_all(10)
	return style


## Hueco de lectura hundido en la chapa.
static func well_box() -> StyleBoxFlat:
	var style := box(Color(BG, 0.55), ENAMEL_SHADE, 0, 6)
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
	_theme.set_stylebox("normal", "Button", _key(Color(BAKELITE_RAISED, KEY_TINT), RIM))
	_theme.set_stylebox("hover", "Button", _key(Color(BAKELITE_EDGE, 0.8), IVORY_DIM))
	_theme.set_stylebox("pressed", "Button", _key(Color(ENAMEL_SHADE, 0.8), IVORY_DIM, true))
	_theme.set_stylebox("disabled", "Button", _key(Color(BAKELITE, 0.45), Color(BAKELITE_RAISED, 0.6)))
	var focus := box(Color.TRANSPARENT, IVORY, 2, 6)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	_theme.set_stylebox("focus", "Button", focus)
	_theme.set_color("font_color", "Button", IVORY)
	_theme.set_color("font_hover_color", "Button", IVORY)
	_theme.set_color("font_pressed_color", "Button", IVORY)
	_theme.set_color("font_focus_color", "Button", IVORY)
	_theme.set_color("font_disabled_color", "Button", Color(IVORY_DIM, 0.6))
	_theme.set_stylebox("panel", "PanelContainer", bezel())
	_theme.set_stylebox("panel", "Panel", bezel())
	_theme.set_color("font_color", "Label", IVORY)
	_theme.set_color("default_color", "RichTextLabel", IVORY)
	_theme.set_stylebox("panel", "TooltipPanel", box(BAKELITE, IVORY_DIM))
	_theme.set_stylebox("panel", "ItemList", well_box())
	_theme.set_stylebox("selected", "ItemList", box(BAKELITE_EDGE, INFO, 0, 3))
	_theme.set_stylebox("selected_focus", "ItemList", box(BAKELITE_EDGE, INFO, 0, 3))
	_theme.set_color("font_color", "ItemList", IVORY_DIM)
	_theme.set_color("font_selected_color", "ItemList", IVORY)
	_theme.set_color("font_color", "TooltipLabel", IVORY)
	var grabber := box(BAKELITE_EDGE, BAKELITE_EDGE, 0, 3)
	grabber.set_content_margin_all(3)
	_theme.set_stylebox("grabber", "VScrollBar", grabber)
	_theme.set_stylebox("grabber_highlight", "VScrollBar", box(IVORY_DIM, IVORY_DIM, 0, 3))
	_theme.set_stylebox("grabber_pressed", "VScrollBar", box(IVORY, IVORY, 0, 3))
	_theme.set_stylebox("scroll", "VScrollBar", box(ENAMEL_SHADE, BAKELITE, 0, 3))
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


## Tecla principal de la pantalla: ambar con texto oscuro.
static func primary(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", _key(ACCENT, ACCENT.darkened(0.3)))
	b.add_theme_stylebox_override("hover", _key(ACCENT.lightened(0.2), ACCENT.darkened(0.3)))
	b.add_theme_stylebox_override("pressed", _key(ACCENT.darkened(0.2), ACCENT.darkened(0.3), true))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, BG)
	b.add_theme_font_override("font", bold())
	return b


## Tecla baja para la consola de vuelo: caben tres filas en CONSOLE_H.
static func compact(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", _key(Color(BAKELITE_RAISED, KEY_TINT), RIM, false, 3))
	b.add_theme_stylebox_override("hover", _key(Color(BAKELITE_EDGE, 0.8), IVORY_DIM, false, 3))
	b.add_theme_stylebox_override("pressed", _key(Color(ENAMEL_SHADE, 0.8), IVORY_DIM, true, 3))
	b.add_theme_stylebox_override("disabled", _key(Color(BAKELITE, 0.45), Color(BAKELITE_RAISED, 0.6), false, 3))
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
	l.add_theme_stylebox_override("normal", box(Color(BAKELITE, 0.75), BAKELITE_EDGE, 0, 6))
	l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_left = 12
	l.offset_bottom = -CONSOLE_H - 10
	l.offset_top = l.offset_bottom
	return l


## Rotulo grande centrado arriba (cuenta atras, avisos de fase).
## between_corners: ocupa solo el hueco entre los avisos (Ticker, a la izquierda) y la matriz de
## lamparas (a la derecha) y parte el texto en lineas, para no escribir encima de ninguno.
static func banner(root: Control, size: int, y: float, between_corners: bool = true) -> Label:
	var l := label(root, "", size, IVORY)
	l.add_theme_font_override("font", bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = y
	if between_corners:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.offset_left = TICKER_RECT.end.x + 16.0
		var board := Annunciator.current
		if board != null and is_instance_valid(board):
			var fit := func() -> void:
				l.offset_right = board.position.x - 16.0 - root.size.x
				# Con dos jugadores el hueco es estrecho: letra menor para no bajar hasta el vuelo.
				var room := root.size.x + l.offset_right - l.offset_left
				l.add_theme_font_size_override("font_size", size if room >= 480.0 else mini(size, SIZE_HEAD))
			board.item_rect_changed.connect(fit)
			root.resized.connect(fit)
			fit.call_deferred()
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
		var style := _key(Color(BAKELITE_RAISED, KEY_TINT), IVORY)
		style.set_border_width_all(2)
		style.border_width_bottom = 4
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_font_override("font", bold())
	else:
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_font_override("font")
	b.add_theme_color_override("font_color", IVORY if on else IVORY_DIM)
	return b


## Leyenda grabada en mayusculas. on_enamel = sobre banda elevada (crema); si no, dentro de panel.
static func legend(parent: Node, text: String, on_enamel: bool = false) -> Label:
	var l := label(parent, text.to_upper(), SIZE_LEGEND, IVORY if on_enamel else IVORY_DIM)
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
	style.bg_color = Color(ENAMEL, 0.72) # mas tinte que un panel: va sobre el cielo claro del despegue
	style.border_width_left = 0
	style.border_width_top = 2
	style.set_corner_radius_all(0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	p.add_theme_stylebox_override("panel", style)
	glass(p)
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
	glass(p)
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
