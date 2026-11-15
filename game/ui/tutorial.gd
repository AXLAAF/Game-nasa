class_name Tutorial
extends CanvasLayer

## Capitulos por fase. La primera visita los muestra; el hangar puede repetirlos todos.

const CHAPTER := {&"hangar": "Hangar", &"assembly": "Taller", &"launch": "Despegue", &"space": "Espacio", &"descent": "Descenso", &"debrief": "Pago"}
const ORDER: Array[StringName] = [&"hangar", &"assembly", &"launch", &"space", &"descent", &"debrief"]
const STEPS: Dictionary = {
	&"hangar": [
		["Contratos", "Elige un contrato y pulsa Aceptar contrato. El adelanto se suma a tu presupuesto y el plazo marca los días límite para cobrar completo."],
		["Seguro y modo asistido", "El seguro devuelve parte del costo si pierdes la nave. En Ajustes (arriba a la izquierda o Esc) puedes activar Modo asistido: menos averías y ayuda al pilotar."],
	],
	&"assembly": [
		["Sigue la lista de despegue", "A la derecha, Siguiente paso te dice qué le falta a la nave y por qué. Cuando la lista queda en verde, pulsa Despegar."],
		["Construye por etapas", "Para tu primer cohete, de abajo hacia arriba: H-1, núcleo ancho, pernos de etapa, RL10, tanque Al-Li largo, escudo PICA, cápsula Apolo y extras. Cada motor usa solo el tanque de su etapa. El hangar ofrece una práctica guiada. El clic del catálogo coloca piezas automáticamente."],
		["Calidad y presupuesto", "Chatarra y Usada cuestan menos, pero fallan más. Arrastra una pieza para moverla y usa clic derecho para quitarla y recuperar su precio."],
	],
	&"launch": [
		["Ignición", "Pulsa Espacio cuando la aguja entre en el verde del reloj. Antes de tiempo no enciende. Retroceso aborta el lanzamiento y te devuelve el presupuesto."],
		["Inclínala hacia el verde", "W da potencia y A/D giran. Lleva la marca al arco verde. Ese giro pone velocidad de lado: sin ella el cohete sube y vuelve a caer."],
		["Separa al acabarse el combustible", "Mira el combustible de la etapa que está encendida. Cuando llegue a cero, pulsa Espacio para soltar lo de abajo. Separar antes tira combustible que todavía servía. La etapa de arriba usa su propio motor y su propio tanque."],
	],
	&"space": [
		["Órbita", "En el modo realista la nave no se frena sola. Cae todo el tiempo; si vas bastante de lado, el planeta se curva debajo y no lo tocas: eso es una órbita. W empuja hacia la nariz. A favor del movimiento sube el lado opuesto; en contra lo baja y puedes volver a caer. A/D giran, N muestra la guía, Tab cambia el objetivo y 1-6 adelantan el tiempo mientras costas."],
		["Energía y emergencias", "Vigila batería y temperatura. Si aparece una llamarada solar, escóndete tras un planeta. R repara piezas rotas y L inicia el descenso al llegar."],
	],
	&"descent": [
		["Corredor de entrada", "Ajusta el ángulo con W/S dentro de la franja verde y pulsa Espacio: muy plano rebotas al espacio y muy empinado te quemas."],
		["Paracaídas y aterrizaje", "Pulsa P para abrir paracaídas cuando baje la velocidad, frena con W/S y posa la nave suave sobre la plataforma iluminada."],
	],
	&"debrief": [
		["Liquidación", "Aquí cobras el contrato según puntualidad, ciencia extra y seguro. Las piezas recuperadas quedan guardadas gratis en tu inventario."],
		["Aprender y mejorar", "Si una misión falla, desbloqueas una lección permanente. Vuelve al hangar para elegir un contrato nuevo."],
	],
}

static var _open: Tutorial

var _all: bool = false
var _froze: bool = false
var _phase: StringName = &""
var _pages: Array[Dictionary] = []
var _index: int = 0
var _title: Label
var _body: Label
var _count: Label
var _hints: Label
var _prev: Button
var _next: Button
var _tabs: HBoxContainer
var _chapter_buttons: Dictionary = {}
var _panel: PanelContainer
var _root: Control
var _backdrop: ColorRect


static func busy() -> bool:
	return _open != null and is_instance_valid(_open)


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
	_pages = _collect()
	if _pages.is_empty():
		queue_free()
		return
	_froze = Run.crew < 2 and not get_tree().paused
	if _froze:
		get_tree().paused = true
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = Ui.theme()
	add_child(_root)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.03, 0.05, 0.58 if Kinetic.is_reduced() else 0.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_backdrop)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700, 0)
	_root.add_child(_panel)
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
	skip.text = tr("Saltar (Esc)")
	skip.pressed.connect(_skip)
	Kinetic.bind_button(skip)
	head.add_child(skip)
	if _all:
		_tabs = HBoxContainer.new()
		_tabs.add_theme_constant_override("separation", 4)
		col.add_child(_tabs)
		for phase_id: StringName in ORDER:
			var tab := Button.new()
			tab.text = tr(CHAPTER[phase_id])
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.add_theme_font_size_override("font_size", Ui.SIZE_LEGEND)
			tab.pressed.connect(_jump_to.bind(phase_id))
			Kinetic.bind_button(tab, 0.8, 1.03)
			_tabs.add_child(tab)
			_chapter_buttons[phase_id] = tab
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_font_override("font", Ui.bold())
	col.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(660, 0)
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_constant_override("line_spacing", 6)
	_body.add_theme_color_override("font_color", Ui.IVORY)
	col.add_child(_body)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	col.add_child(nav)
	_prev = Button.new()
	_prev.text = tr("Anterior")
	_prev.custom_minimum_size = Vector2(130, 44)
	_prev.pressed.connect(_back)
	Kinetic.bind_button(_prev)
	nav.add_child(_prev)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(0, 44)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.primary(_next)
	_next.pressed.connect(_advance)
	Kinetic.bind_button(_next)
	nav.add_child(_next)
	_hints = Label.new()
	_hints.text = tr("Enter / Espacio / Flecha derecha: Siguiente   •   Flecha izquierda: Anterior   •   Esc: Saltar")
	_hints.add_theme_font_size_override("font_size", Ui.SIZE_LEGEND)
	_hints.add_theme_color_override("font_color", Ui.IVORY_DIM)
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hints)
	_paint(false)
	_animate_open.call_deferred()
	_next.grab_focus.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).physical_keycode:
		KEY_ESCAPE:
			_skip()
		KEY_LEFT:
			_back()
		KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_advance()
	get_viewport().set_input_as_handled()


func _animate_open() -> void:
	_place()
	if Kinetic.is_reduced() or _panel == null:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_backdrop, "color:a", 0.58, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Kinetic.enter(_panel, 0.0, {
		"slide": true,
		"slide_offset": Vector2(-26.0, 12.0),
		"scale": Vector2(0.90, 0.86),
		"tilt": -0.028,
		"elastic": true,
		"duration": 0.30,
		"beam": true,
	})


func _place() -> void:
	if _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var h := _panel.get_combined_minimum_size().y
	var rest := Vector2((vp.x - 700.0) * 0.5, maxf(16.0, vp.y - h - 28.0))
	_panel.set_meta("_kinetic_rest_pos", rest)
	_panel.position = rest


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
			var title := String(step[0])
			var text := String(step[1])
			if phase == &"space" and title == "Órbita" and Profile.arcade:
				title = tr("Sin gravedad")
				text = tr("Este modo no orbita: WASD empuja con inercia y no hay gravedad. Mayús sobrecarga, Ctrl afina, 1-6 adelantan el tiempo, Tab cambia el objetivo, F escanea y L entra al llegar.")
			pages.append({"phase": phase, "title": tr(title), "text": tr(text)})
	return pages


func _paint(animate: bool = true) -> void:
	var page := _pages[_index]
	_count.text = (tr("Guía rápida: %s   %d / %d") % [tr(CHAPTER[page.phase]), _index + 1, _pages.size()]).to_upper()
	_title.text = String(page.title)
	_body.text = String(page.text)
	_prev.disabled = _index == 0
	_next.text = tr("Listo") if _index >= _pages.size() - 1 else tr("Siguiente")
	for phase_id: StringName in _chapter_buttons:
		Ui.mark_selected(_chapter_buttons[phase_id], phase_id == page.phase)
	_place.call_deferred()
	if animate and not Kinetic.is_reduced():
		Kinetic.enter(_title, 0.0, {"scale": Vector2(0.96, 0.90), "tilt": -0.015, "duration": 0.22})
		Kinetic.enter(_body, 0.03, {"scale": Vector2(0.97, 0.92), "tilt": 0.01, "duration": 0.24})
		Kinetic.sweep(_panel, Color(0.75, 0.90, 1.0, 0.14), 0.30)


func _jump_to(phase_id: StringName) -> void:
	for i: int in _pages.size():
		if _pages[i].phase == phase_id:
			_index = i
			_paint()
			Synth.play(&"tick", -8.0)
			return


func _back() -> void:
	if _index <= 0:
		return
	_index -= 1
	_paint()
	Synth.play(&"tick", -8.0)


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
	if _froze:
		get_tree().paused = false
	Synth.play(&"click")
	if Kinetic.is_reduced() or DisplayServer.get_name() == "headless" or _panel == null:
		queue_free()
		return
	set_process_unhandled_key_input(false)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kinetic.sync_pivot(_panel)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(_backdrop, "color:a", 0.0, 0.15)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "scale", Vector2(0.88, 0.84), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "rotation", 0.028, 0.16)
	tw.chain().tween_callback(queue_free)
