extends RefCounted

## Comprueba que el lint de maquetacion detecta cada regla y respeta el meta de solape buscado.

const LINT: Script = preload("res://tests/layout_lint.gd")

var passed := 0
var failed := 0
var _tree: SceneTree
var _layer: CanvasLayer


func run(tree: SceneTree) -> int:
	_tree = tree
	var layer := CanvasLayer.new()
	tree.root.add_child(layer)
	_layer = layer
	var view := tree.root.get_visible_rect().size

	var panel := PanelContainer.new()
	panel.position = Vector2(40, 40)
	panel.size = Vector2(200, 100) # tamanos a mano: el ajuste de contenedores llega un frame despues
	var inside := Label.new()
	inside.text = "Dentro"
	panel.add_child(inside)
	layer.add_child(panel)
	check(_new().is_empty(), "un panel dentro de la ventana no da hallazgos")

	var out := Label.new()
	out.text = "Rotulo que se sale por la derecha"
	out.position = Vector2(view.x - 10.0, 300)
	out.size = Vector2(260, 24)
	layer.add_child(out)
	check(_has("fuera:"), "detecta un rotulo fuera de la ventana")
	out.free()

	var clipped := Button.new()
	clipped.text = "Rumores de peligro"
	clipped.clip_text = true
	clipped.position = Vector2(40, 200)
	clipped.size = Vector2(40, 30)
	layer.add_child(clipped)
	check(_has("cortado:"), "detecta un texto cortado")
	clipped.free()

	var other := PanelContainer.new()
	other.position = Vector2(60, 50)
	other.size = Vector2(200, 100)
	layer.add_child(other)
	check(_has("solape:"), "detecta dos piezas que se pisan")
	other.set_meta(LINT.OVERLAY_META, true)
	check(not _has("solape:"), "un solape declarado no cuenta")

	layer.free()
	print("Layout: %d passed, %d failed" % [passed, failed])
	return failed


func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)


## Solo la rama del caso: los autoloads y las otras suites ya traen interfaz propia.
func _new() -> Array[String]:
	return LINT.check(_tree, _layer)


func _has(rule: String) -> bool:
	for line: String in _new():
		if line.begins_with(rule):
			return true
	return false
