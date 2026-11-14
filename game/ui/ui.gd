class_name Ui
extends RefCounted

const BG := Color(0.02, 0.03, 0.07)
const PANEL := Color(0.04, 0.07, 0.13, 0.94)
const PANEL_LIGHT := Color(0.08, 0.12, 0.2, 0.96)
const CYAN := Color(0.35, 0.9, 1.0)
const ORANGE := Color(1.0, 0.6, 0.2)
const RED := Color(1.0, 0.28, 0.25)
const GREEN := Color(0.4, 1.0, 0.55)
const GOLD := Color(1.0, 0.82, 0.3)
const PURPLE := Color(0.75, 0.45, 1.0)
const DIM := Color(0.55, 0.65, 0.75)
const TEXT := Color(0.9, 0.94, 1.0)
const RARITY: Array[Color] = [Color(0.6, 0.9, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.82, 0.3)]
const RARITY_NAMES: Array[String] = ["Comun", "Rara", "Legendaria"]

static var _theme: Theme
static var _mono: SystemFont


static func mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "JetBrains Mono", "DejaVu Sans Mono", "Courier New", "monospace"])
	return _mono


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


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = mono()
	_theme.default_font_size = 15
	_theme.set_stylebox("normal", "Button", box(Color(0.07, 0.11, 0.19), Color(0.25, 0.55, 0.7)))
	_theme.set_stylebox("hover", "Button", box(Color(0.12, 0.18, 0.3), ORANGE))
	_theme.set_stylebox("pressed", "Button", box(Color(0.2, 0.12, 0.05), ORANGE, 2))
	_theme.set_stylebox("disabled", "Button", box(Color(0.05, 0.06, 0.08), Color(0.2, 0.22, 0.25)))
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_hover_color", "Button", GOLD)
	_theme.set_color("font_disabled_color", "Button", Color(0.4, 0.45, 0.5))
	_theme.set_stylebox("panel", "PanelContainer", box(PANEL, Color(0.2, 0.4, 0.55), 1, 6))
	_theme.set_stylebox("panel", "Panel", box(PANEL, Color(0.2, 0.4, 0.55), 1, 6))
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_stylebox("panel", "TooltipPanel", box(Color(0.03, 0.05, 0.1, 0.97), CYAN))
	_theme.set_color("font_color", "TooltipLabel", TEXT)
	return _theme


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


static func label(parent: Node, text: String, size: int = 15, color: Color = TEXT) -> Label:
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
	parent.add_child(b)
	return b


static func panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
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


static var _board: StatusBoard


static func toggle_status(host: Node) -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
		_board = null
		return
	var board := StatusBoard.new()
	_board = board
	host.add_child(board)


static func money(amount: int) -> String:
	return "$%s" % _thousands(amount)


static func _thousands(amount: int) -> String:
	var text := str(absi(amount))
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if amount < 0 else "") + text + out
