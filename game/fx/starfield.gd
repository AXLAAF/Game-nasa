class_name Starfield
extends CanvasLayer

var _rect: ColorRect


func _init() -> void:
	layer = -10
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/fx/starfield.gdshader")
	_rect.material = mat
	add_child(_rect)


func set_view(view: Vector2) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("offset", view)


func set_sky(color: Color, star_alpha: float) -> void:
	var mat := _rect.material as ShaderMaterial
	mat.set_shader_parameter("sky", color)
	mat.set_shader_parameter("stars", star_alpha)
