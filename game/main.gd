extends Node2D

var _loader := NasaDataLoader.new()


func _ready() -> void:
	_loader.load_all()
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#080e1a")
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Space: Deuda Orbital — Hito 0 Listo"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f8fafc"))
	vbox.add_child(title)

	var contracts := _loader.get_contracts()
	var info := Label.new()
	info.text = "Misiones NASA cargadas: %d | Renderer: gl_compatibility" % contracts.size()
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox.add_child(info)
