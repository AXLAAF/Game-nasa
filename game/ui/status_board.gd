class_name StatusBoard
extends CanvasLayer

var body: RichTextLabel


func _ready() -> void:
	layer = 30
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Ui.theme()
	add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(300, 36)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.CYAN, 1, 6))
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var title := Label.new()
	title.text = "ESTADO DE COMPONENTES    C cerrar"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Ui.CYAN)
	col.add_child(title)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(540, 0)
	body.add_theme_font_size_override("normal_font_size", 15)
	col.add_child(body)


func _process(_delta: float) -> void:
	var lines: PackedStringArray = PackedStringArray()
	for part: ShipPart in Run.ship.parts:
		lines.append(part.status_bbcode())
	body.text = "\n".join(lines) if not lines.is_empty() else "Sin piezas."
