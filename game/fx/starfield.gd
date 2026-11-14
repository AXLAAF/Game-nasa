class_name Starfield
extends CanvasLayer

## Fondo espacial en pixel art (game/shaders/pixel_space_bg.gdshader) con nebulosa en la gama del esmalte.

var _rect: ColorRect


func _init() -> void:
	layer = -10
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/pixel_space_bg.gdshader")
	mat.set_shader_parameter("pixel_size", 3.0)
	mat.set_shader_parameter("nebula_intensity", 0.6)
	mat.set_shader_parameter("nebula_col", Color("12343b"))
	mat.set_shader_parameter("nebula_accent", Color("1f5a63"))
	_rect.material = mat
	add_child(_rect)


func set_view(view: Vector2) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("scroll_offset", view)


func set_sky(color: Color, star_alpha: float) -> void:
	var mat := _rect.material as ShaderMaterial
	mat.set_shader_parameter("bg_void", color)
	mat.set_shader_parameter("stars", star_alpha)
