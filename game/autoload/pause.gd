extends Node

## Pausa con Esc y tecla de ajustes fija arriba a la izquierda, en todas las fases tras el titulo.

## Esquina reservada al engranaje: las pantallas no ponen nada debajo.
const GEAR_RECT := Rect2(8, 8, 28, 28)

var _gear: Button
var _froze: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Ui.root(self, 85)
	_gear = Ui.button(root, "", open_settings)
	_gear.custom_minimum_size = GEAR_RECT.size
	_gear.position = GEAR_RECT.position
	_gear.focus_mode = Control.FOCUS_NONE
	_gear.tooltip_text = "Ajustes"
	_gear.visible = false
	_gear.draw.connect(_draw_gear)
	Events.phase_changed.connect(_on_phase)


func _on_phase(id: StringName) -> void:
	Modal.close_all()
	_froze = false
	_gear.visible = id != &"title"


func can_open() -> bool:
	return Router.current != &"" and Router.current != &"title" and not Card.busy() and not Tutorial.busy() and not Modal.busy()


## Solo teclado: el boton B del mando tambien es ui_cancel, pero ya es crew_leave / cmd_abort.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed(&"ui_cancel") and can_open():
		get_viewport().set_input_as_handled()
		open()


func open() -> void:
	if not can_open():
		return
	_freeze()
	var modal := Modal.new("Pausa")
	Ui.primary(Ui.button(modal.col, "Continuar", modal.close))
	Ui.button(modal.col, "Ajustes", func() -> void: SettingsPanel.show_panel())
	Ui.button(modal.col, "Volver al menú principal", func() -> void:
		Modal.confirm("¿Volver al menú principal? Se pierde el contrato en curso.", "Volver al menú", func() -> void: Router.go(&"title")))
	if not OS.has_feature("web"):
		Ui.button(modal.col, "Salir", func() -> void:
			Modal.confirm("¿Salir del juego?", "Salir", func() -> void: get_tree().quit()))
	modal.closed.connect(_thaw)
	modal.open()


func open_settings() -> void:
	if Modal.busy():
		return
	_freeze()
	SettingsPanel.show_panel().closed.connect(_thaw)


func _freeze() -> void:
	# shortcut: coop pause no congela el arbol; ver docs/multijugador.md
	_froze = Run.crew < 2 and not get_tree().paused
	if _froze:
		get_tree().paused = true


func _thaw() -> void:
	if _froze:
		get_tree().paused = false
	_froze = false


func _draw_gear() -> void:
	var center := _gear.size * 0.5
	_gear.draw_arc(center, 6.0, 0.0, TAU, 24, Ui.IVORY, 2.5)
	for i: int in 8:
		var angle := TAU * float(i) / 8.0
		_gear.draw_line(center + Vector2.from_angle(angle) * 7.0, center + Vector2.from_angle(angle) * 10.0, Ui.IVORY, 2.5)
