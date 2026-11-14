class_name Planet
extends ColorRect

## Cuerpo celeste en pixel art procedural (game/shaders/pixel_planet_25d.gdshader).
## Los cuerpos del juego son ficticios: el tipo y la paleta salen de BodyDef, no de sprites de planetas reales.

const SHADER: Shader = preload("res://game/shaders/pixel_planet_25d.gdshader")
const TEXEL := 3.0 ## pixeles de pantalla por texel del planeta


static func make(body: BodyDef, diameter: float) -> Planet:
	var p := Planet.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var kind := 1
	if body.atmosphere >= 1.5:
		kind = 3
	elif body.is_home:
		kind = 0
	elif body.atmosphere > 0.0:
		kind = 2
	mat.set_shader_parameter("planet_type", kind)
	mat.set_shader_parameter("seed", float(hash(body.id) % 97) * 0.1)
	mat.set_shader_parameter("col_a", body.color if kind == 0 else body.color.darkened(0.3))
	mat.set_shader_parameter("col_b", Color("4f9a4a") if kind == 0 else body.color)
	mat.set_shader_parameter("col_c", Color("f2f2ec") if kind == 0 else body.color.lightened(0.4))
	mat.set_shader_parameter("col_atmo", Color(body.atmo_color, 0.45 if body.atmosphere > 0.0 else 0.0))
	mat.set_shader_parameter("col_night", body.color.darkened(0.88))
	p.material = mat
	p.fit(diameter, diameter)
	return p


## diameter en unidades del padre; on_screen en pixeles reales, para fijar el grano del pixel art.
func fit(diameter: float, on_screen: float) -> void:
	size = Vector2(diameter, diameter)
	(material as ShaderMaterial).set_shader_parameter("pixels", clampf(roundf(on_screen / TEXEL), 8.0, 96.0))


func light_from(direction: Vector2) -> void:
	(material as ShaderMaterial).set_shader_parameter("light_dir", direction.normalized())
