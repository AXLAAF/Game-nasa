extends RefCounted

## Lint de maquetacion: recorre los Control visibles y devuelve una linea por problema.
##   fuera:   un rotulo, tecla, panel o imagen no cabe en la ventana.
##   cortado: un texto no cabe en su control.
##   solape:  dos piezas de primer nivel se pisan.
## Un solape buscado (modal, carta, tutorial, tarjeta flotante) se declara con el meta OVERLAY_META
## en la raiz de esa pieza. Las otras dos reglas se aplican tambien dentro de un solape buscado.

const OVERLAY_META := &"layout_overlay"
const FRAMES: Array[String] = ["Control", "MarginContainer", "CenterContainer", "HBoxContainer", "VBoxContainer", "GridContainer"]


## from limita el recorrido a una rama (las pruebas del propio lint); por defecto, todo el arbol.
static func check(tree: SceneTree, from: Node = null) -> Array[String]:
	var view := tree.root.get_visible_rect()
	var out: Dictionary = {}
	var pieces: Array[Control] = []
	_walk(from if from != null else tree.root, view, out, pieces, true)
	for i: int in pieces.size():
		for j: int in range(i + 1, pieces.size()):
			var hit := pieces[i].get_global_rect().intersection(pieces[j].get_global_rect())
			if hit.size.x > 2.0 and hit.size.y > 2.0:
				out["solape: %s con %s %s" % [_path(pieces[i]), _path(pieces[j]), _fmt(hit)]] = true
	var lines: Array[String] = []
	lines.assign(out.keys())
	lines.sort()
	return lines


## top = seguimos buscando piezas de primer nivel por esta rama.
static func _walk(node: Node, view: Rect2, out: Dictionary, pieces: Array[Control], top: bool) -> void:
	var next_top := top
	if node is Control:
		var c := node as Control
		if not c.is_visible_in_tree() or c.modulate.a <= 0.05:
			return
		var rect := c.get_global_rect()
		var full := rect.grow(2.0).encloses(view)
		if top:
			if c.has_meta(OVERLAY_META):
				next_top = false
			elif not (full and (c.get_class() in FRAMES or c is ColorRect or c is TextureRect)):
				next_top = false
				if rect.size.x > 1.0 and rect.size.y > 1.0 and not c is ColorRect:
					pieces.append(c)
			elif not c.get_class() in FRAMES:
				next_top = false
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			_check_bounds(c, rect, view, out)
			_check_text(c, out)
	elif node is CanvasItem and not (node as CanvasItem).visible:
		return
	elif node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	for child: Node in node.get_children():
		_walk(child, view, out, pieces, next_top)


static func _check_bounds(c: Control, rect: Rect2, view: Rect2, out: Dictionary) -> void:
	if not (c is Label or c is RichTextLabel or c is BaseButton or c is PanelContainer or c is Panel or c is TextureRect or c is Range):
		return
	var parent := c.get_parent()
	while parent != null:
		if parent is ScrollContainer or (parent is Control and (parent as Control).clip_contents):
			return
		parent = parent.get_parent()
	if not view.grow(1.0).encloses(rect):
		out["fuera: %s %s en ventana %dx%d" % [_path(c), _fmt(rect), int(view.size.x), int(view.size.y)]] = true


static func _check_text(c: Control, out: Dictionary) -> void:
	if c is Label:
		var l := c as Label
		if l.text.strip_edges() == "":
			return
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			if l.get_line_count() > l.get_visible_line_count():
				out["cortado: %s muestra %d de %d lineas" % [_path(c), l.get_visible_line_count(), l.get_line_count()]] = true
			return
		_check_width(c, l.text, l.get_theme_font("font"), l.get_theme_font_size("font_size"), l.get_theme_stylebox("normal"), out)
	elif c is Button:
		var b := c as Button
		if b.text.strip_edges() == "" or not (b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
			return
		_check_width(c, b.text, b.get_theme_font("font"), b.get_theme_font_size("font_size"), b.get_theme_stylebox("normal"), out)


static func _check_width(c: Control, text: String, font: Font, font_size: int, style: StyleBox, out: Dictionary) -> void:
	var need := 0.0
	for line: String in text.split("\n"):
		need = maxf(need, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if style != null:
		need += style.get_minimum_size().x
	if need > c.size.x + 0.5:
		out["cortado: %s \"%s\" pide %d px y tiene %d" % [_path(c), text.left(28), int(need), int(c.size.x)]] = true


## Ruta sin los nombres autogenerados (@Label@123), para que el mismo problema salga una sola vez.
static func _path(c: Control) -> String:
	var parts: PackedStringArray = []
	var node: Node = c
	while node != null and node.get_parent() != null:
		var n := String(node.name)
		if n.begins_with("@"):
			n = node.get_class()
			var script: Script = node.get_script()
			if script != null and script.get_global_name() != &"":
				n = String(script.get_global_name())
		parts.append(n)
		node = node.get_parent()
	parts.reverse()
	var text := ""
	if c is Label:
		text = " \"%s\"" % (c as Label).text.left(20)
	elif c is Button:
		text = " \"%s\"" % (c as Button).text.left(20)
	return "/".join(parts) + text


static func _fmt(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
