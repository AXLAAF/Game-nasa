class_name Tutorial
extends CanvasLayer

## Capitulos por fase. La primera visita los muestra; el hangar puede repetirlos todos.

const CHAPTER := {&"hangar": "hangar", &"assembly": "ensamblaje", &"launch": "despegue", &"space": "espacio", &"descent": "descenso", &"debrief": "liquidación"}
const ORDER: Array[StringName] = [&"hangar", &"assembly", &"launch", &"space", &"descent", &"debrief"]
const STEPS: Dictionary = {
	&"hangar": [
		["Contratos", "Elige un contrato y pulsa ACEPTAR. El adelanto entra en tu presupuesto. El plazo se cuenta en dias de vuelo: llegar tarde baja el pago. Un rumor de peligro paga mas y aparece al aterrizar."],
		["Seguro", "Sin seguro no recuperas nada si la nave se pierde. Basico y Premium cobran una prima al despegar y devuelven parte de lo gastado si fracasas."],
		["Modo asistido", "Activalo si quieres menos averias, un kit extra, el corredor de entrada mas ancho y la navegacion encendida. El contrato paga un 15% menos."],
		["Lo que se queda", "Creditos, piezas del inventario y lecciones se guardan entre partidas. Reiniciar perfil borra todo eso."],
	],
	&"assembly": [
		["La pila", "Arrastra piezas al centro. El motor va abajo y la capsula arriba. El presupuesto de arriba a la derecha es todo lo que puedes gastar, adelanto incluido."],
		["Montaje lateral", "Paneles, antenas, sensores y radiadores se sueltan a la izquierda, a la derecha o a ambos lados de un bloque. La altura la marca donde sueltas el raton."],
		["Calidad", "Chatarra falla mas y rinde peor. Nueva aguanta. Las cajas misteriosas ocultan la calidad hasta que pagas Inspeccionar."],
		["Despegar", "Hace falta capsula y motor con empuje. Si el destino tiene aire, lleva escudo termico y paracaidas. DESPEGAR pasa a la cuenta atras."],
	],
	&"launch": [
		["Ignicion", "Pulsa ESPACIO cuando el contador llega a T-0. Muy pronto o muy tarde estresa el motor. BACKSPACE aborta y devuelve el dinero."],
		["Cabeceo", "W sube el acelerador, S lo baja. A y D inclinan la nave. Sigue el pitch objetivo: asistido lo acerca solo si no tocas A/D. En Max-Q baja el acelerador."],
		["Etapas", "ESPACIO suelta la etapa de abajo cuando se queda sin combustible o sin motor. Un desacoplador trabado se reintenta con ESPACIO."],
		["Tiempo", "1 a 4 cambian la velocidad: x0.5, x1, x2 y x4. Sirve para mirar el ascenso con calma."],
	],
	&"space": [
		["Pilotaje", "A y D giran. W empuja; CTRL es empuje fino y SHIFT sobrecarga el motor (puede romperse). T mantiene progrado y G retrogrado. La rayita verde es tu velocidad."],
		["Objetivo", "TAB o un clic elige el objetivo. La linea cian es la trayectoria prevista. F escanea un punto cercano y gasta bateria."],
		["Navegacion", "N enciende el guiado. La flecha cian dice acelera; la naranja, frena. Vobj es la velocidad a llevar y falta el empuje que te queda. Con NAV el morro se alinea solo: tu pulsas W."],
		["Tiempo y averias", "1 a 6 van de x0.5 a x50, tambien cerca de un planeta. Con el motor encendido o en una llamarada el tiempo no pasa de x0.5. R repara, C muestra el estado de cada pieza. Solo se rompe una cosa a la vez."],
		["Entrar", "Cuando estes cerca y lento, L (o chocar con el planeta) empieza el descenso. Quedarte sin combustible abre el rescate."],
	],
	&"descent": [
		["Angulo", "W y S mueven el angulo de entrada. El cono verde es el corredor: mas plano rebotas al espacio, mas empinado quemas la nave. ESPACIO confirma."],
		["Calor", "El escudo absorbe calor y gasta ablativo. Si se agota, el casco se funde. El modo asistido ensancha el corredor y tolera mas G."],
		["Paracaidas", "P suelta el freno por debajo de 450 m/s y el principal por debajo de 120 m/s y de 6 km. Abrirlo demasiado rapido lo desgarra. E eyecta la capsula."],
		["Tocar suelo", "W y S son el acelerador, A y D la inclinacion, T mantiene el retroceso. 1 a 4 cambian el tiempo. Mas suave y sobre la plataforma, mejor nota."],
	],
	&"debrief": [
		["La cuenta", "Aqui se suma el pago, el plazo, la nota de aterrizaje y la racha. El modo asistido resta un 15%. El botin de las cartas entra en la misma cuenta."],
		["Despues", "Si pierdes la nave, el seguro cubre una parte y aprendes una leccion. La chatarra va al inventario. Volver al hangar abre contratos nuevos."],
	],
}

static var _open: Tutorial

var _all: bool = false
var _phase: StringName = &""
var _pages: Array[Dictionary] = []
var _index: int = 0
var _title: Label
var _body: Label
var _count: Label
var _next: Button
var _panel: PanelContainer


static func offer(phase: StringName) -> void:
	if Profile.saw_tutorial(String(phase)):
		return
	_show(phase, false)


static func replay() -> void:
	_show(&"", true)


static func _show(phase: StringName, all_chapters: bool) -> void:
	if _open != null and is_instance_valid(_open):
		_open.queue_free()
	var node := Tutorial.new()
	node._all = all_chapters
	node._phase = phase
	_open = node
	(Engine.get_main_loop() as SceneTree).root.add_child(node)


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_pages = _collect()
	if _pages.is_empty():
		get_tree().paused = false
		queue_free()
		return
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Ui.theme()
	add_child(root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680, 0)
	root.add_child(_panel)
	var panel := _panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", Ui.SIZE_LEGEND)
	_count.add_theme_font_override("font", Ui.legend_font())
	_count.add_theme_color_override("font_color", Ui.IVORY_DIM)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var skip := Button.new()
	skip.text = "Saltar tutorial"
	skip.pressed.connect(_skip)
	head.add_child(skip)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_font_override("font", Ui.bold())
	col.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(640, 0)
	_body.add_theme_font_size_override("font_size", Ui.SIZE_TEXT)
	_body.add_theme_constant_override("line_spacing", 5)
	_body.add_theme_color_override("font_color", Ui.IVORY)
	col.add_child(_body)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(0, 44)
	Ui.primary(_next)
	_next.pressed.connect(_advance)
	col.add_child(_next)
	_paint()
	_place.call_deferred()


func _place() -> void:
	if _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var h := _panel.get_combined_minimum_size().y
	_panel.position = Vector2((vp.x - 680.0) * 0.5, maxf(16.0, vp.y - h - 28.0))


func _collect() -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var phases: Array[StringName] = []
	if _all:
		phases = ORDER
	else:
		phases.append(_phase)
	for phase: StringName in phases:
		var chapter: Array = STEPS.get(phase, [])
		for step: Array in chapter:
			pages.append({"phase": phase, "title": String(step[0]), "text": String(step[1])})
	return pages


func _paint() -> void:
	var page := _pages[_index]
	_count.text = ("Manual de vuelo: %s   %d / %d" % [CHAPTER[page.phase], _index + 1, _pages.size()]).to_upper()
	_title.text = String(page.title)
	_body.text = String(page.text)
	_next.text = "Listo" if _index >= _pages.size() - 1 else "Siguiente"


func _advance() -> void:
	if _index >= _pages.size() - 1:
		_finish(false)
		return
	_index += 1
	_paint()
	Synth.play(&"tick", -8.0)


func _skip() -> void:
	_finish(true)


func _finish(skipped: bool) -> void:
	if _all or skipped:
		Profile.mark_tutorial_all()
	else:
		Profile.mark_tutorial(String(_phase))
	if _open == self:
		_open = null
	get_tree().paused = false
	queue_free()
	Synth.play(&"click")
