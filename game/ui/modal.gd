class_name Modal
extends CanvasLayer

## Ventana de menu: atenua el fondo, Esc o su tecla de volver la cierran y devuelve el foco.

signal closed

static var _stack: Array[Modal] = []

var col: VBoxContainer
var _panel: PanelContainer
var _dim: ColorRect
var _focus_back: Control


static func busy() -> bool:
	return not _stack.is_empty()


static func close_all() -> void:
	var copy := _stack.duplicate()
	copy.reverse()
	for modal: Modal in copy:
		if is_instance_valid(modal):
			modal.close()


func _init(title: String) -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = Ui.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_dim = ColorRect.new()
	_dim.color = Color(Ui.BG, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 440
	center.add_child(_panel)
	col = Ui.vbox(_panel, 10)
	Ui.plate(col, title)


func open() -> Modal:
	var root := (Engine.get_main_loop() as SceneTree).root
	_focus_back = root.gui_get_focus_owner()
	root.add_child(self)
	_dim.visible = _stack.is_empty() # una ventana sobre otra no oscurece dos veces
	_stack.append(self)
	Kinetic.enter_deferred(_panel, 0.0, {"scale": Vector2(0.90, 0.86), "elastic": true, "duration": 0.30, "beam": true})
	_focus_first.call_deferred()
	return self


func add_back(text: String = "Volver") -> Button:
	return Ui.button(col, text, close)


func close() -> void:
	if not _stack.has(self):
		return
	_stack.erase(self)
	closed.emit()
	if is_instance_valid(_focus_back) and _focus_back.is_inside_tree() and _focus_back.is_visible_in_tree():
		_focus_back.grab_focus.call_deferred()
	queue_free()


func _exit_tree() -> void:
	_stack.erase(self)


## En _input y no en _unhandled: asi gana al Esc de Tutorial si la ventana esta encima.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _stack.is_empty() and _stack.back() == self:
		get_viewport().set_input_as_handled()
		close()


func _focus_first() -> void:
	var button := _find_button(col)
	if button != null:
		button.grab_focus()


func _find_button(node: Node) -> Button:
	for child: Node in node.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
		var found := _find_button(child)
		if found != null:
			return found
	return null


static func confirm(question: String, yes_text: String, on_yes: Callable) -> Modal:
	var modal := Modal.new("Confirmar")
	var label := Ui.label(modal.col, question, Ui.SIZE_TEXT, Ui.IVORY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 400
	Ui.button(modal.col, yes_text, func() -> void:
		modal.close()
		on_yes.call())
	var cancel := modal.add_back("Cancelar")
	modal.open()
	cancel.grab_focus.call_deferred()
	return modal
