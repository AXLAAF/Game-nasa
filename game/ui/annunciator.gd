class_name Annunciator
extends PanelContainer

## Matriz de lamparas: una por pieza de la nave. Sano = apagada, gastado = ambar,
## defectuoso = ambar intermitente, roto = rojo. C despliega el detalle en texto.

const LAMP_TEST := 0.5

static var current: Annunciator

var _grid: GridContainer
var _detail: Label
var _lamps: Array[Lamp] = []
var _parts: Array = []
var _test_left: float = LAMP_TEST


static func toggle_detail() -> void:
	if current != null and is_instance_valid(current):
		current._detail.visible = not current._detail.visible


func _ready() -> void:
	current = self
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS # las cartas pausan el arbol; las lamparas siguen informando
	var col := Ui.vbox(self, 6)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	col.add_child(_grid)
	_detail = Ui.label(col, "", Ui.SIZE_LEGEND, Ui.IVORY)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(268, 0)
	_detail.visible = false
	if Profile.reduced_motion:
		_test_left = 0.0


func _process(delta: float) -> void:
	var parts: Array = Run.ship.parts
	if parts != _parts:
		_rebuild(parts)
	_test_left -= delta
	var notes := PackedStringArray()
	for i: int in _lamps.size():
		var part: ShipPart = parts[i]
		var h := part.health()
		var lamp := _lamps[i]
		if _test_left > 0.0:
			lamp.state = Lamp.CAUTION
			lamp.blink = false
			continue
		lamp.state = Lamp.WARNING if h == ShipPart.Health.BROKEN else (Lamp.OFF if h == ShipPart.Health.SOUND else Lamp.CAUTION)
		lamp.blink = h == ShipPart.Health.FAULTY
		if h != ShipPart.Health.SOUND:
			notes.append("%s: %s, %s." % [part.def.display_name, ShipPart.HEALTH_NAME[h].to_lower(), ShipPart.HEALTH_NOTE[h]])
	if _detail.visible:
		_detail.text = "\n".join(notes) if not notes.is_empty() else "Todas las piezas en orden."


func _rebuild(parts: Array) -> void:
	_parts = parts.duplicate()
	for lamp: Lamp in _lamps:
		lamp.queue_free()
	_lamps.clear()
	for part: ShipPart in parts:
		var lamp := Lamp.new(part.def.display_name)
		_grid.add_child(lamp)
		_lamps.append(lamp)
