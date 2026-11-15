class_name Planet
extends ColorRect

## Cuerpo celeste en pixel art procedural (game/shaders/pixel_planet_25d.gdshader).
## Cada planeta del sistema solar elige un tipo del generador y una paleta.

const SHADER: Shader = preload("res://game/shaders/pixel_planet_25d.gdshader")
const TEXEL := 3.0 ## pixeles de pantalla por texel del planeta
const HALO_SCALE := 1.28 ## margen extra del rectangulo para dibujar el halo atmosferico sin recortes
const RING_SCALE := 2.4 ## margen con anillos: su borde exterior llega a 2,27 radios en el shader

var _halo := HALO_SCALE


static func make(body: BodyDef, diameter: float) -> Planet:
	var p := Planet.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var look := _look(body)
	var kind: int = look[0]
	var palette: Array = look[1]
	mat.set_shader_parameter("planet_type", kind)
	mat.set_shader_parameter("seed", float(hash(body.id) % 97) * 0.1)
	mat.set_shader_parameter("col_a", palette[0])
	mat.set_shader_parameter("col_b", palette[1])
	mat.set_shader_parameter("col_c", palette[2])
	mat.set_shader_parameter("col_atmo", palette[3])
	mat.set_shader_parameter("col_night", palette[4])
	if body.id == &"saturno":
		p._halo = RING_SCALE
		mat.set_shader_parameter("ring", 1.0)
	mat.set_shader_parameter("halo_scale", p._halo)
	p.material = mat
	p.fit(diameter, diameter)
	return p


## tipo del generador y cinco colores: suelo oscuro, medio, claro, halo, noche.
static func _look(body: BodyDef) -> Array:
	match body.id:
		&"tierra":
			return [0, [Color("1d56a8"), Color("4ca852"), Color("f4f3eb"), Color(0.32, 0.78, 1.0, 0.62), Color("0a1428")]]
		&"venus":
			return [2, [Color("a6843e"), Color("e2c98a"), Color("f7efd2"), Color(0.95, 0.82, 0.45, 0.72), Color("3a2c14")]]
		&"marte":
			return [2, [Color("6b2217"), Color("d85a36"), Color("f2bf96"), Color(1.0, 0.58, 0.38, 0.48), Color("1f0b09")]]
		&"titan":
			return [2, [Color("8a4e22"), Color("d4894a"), Color("f3d2a4"), Color(0.95, 0.62, 0.28, 0.6), Color("2a160c")]]
		&"mercurio":
			return [1, [Color("5c5148"), Color("a09084"), Color("ddd0c2"), Color(0.0, 0.0, 0.0, 0.0), Color("1a1410")]]
		&"luna":
			return [1, [Color("52555c"), Color("8c9099"), Color("d6dae0"), Color(0.0, 0.0, 0.0, 0.0), Color("16181c")]]
		&"jupiter":
			return [3, [Color("c4a07a"), Color("f0e2c8"), Color("c45a32"), Color(0.92, 0.74, 0.46, 0.4), Color("2a1c10")]]
		&"saturno":
			return [3, [Color("d9c48a"), Color("f4e7c4"), Color("c4a56a"), Color(0.95, 0.86, 0.6, 0.35), Color("2c2414")]]
		&"urano":
			return [3, [Color("5eb0ac"), Color("d4f4f1"), Color("2f7f8c"), Color(0.55, 0.95, 0.95, 0.42), Color("0c2428")]]
		&"neptuno":
			return [3, [Color("163e86"), Color("3a78c2"), Color("d6e6ff"), Color(0.35, 0.55, 1.0, 0.48), Color("071226")]]
	var kind := 1
	if body.atmosphere >= 1.5:
		kind = 3
	elif body.is_home:
		kind = 0
	elif body.atmosphere > 0.0:
		kind = 2
	var atmo := Color(body.atmo_color, 0.55 if body.atmosphere > 0.0 else 0.0)
	return [kind, [
		body.color.darkened(0.35),
		body.color,
		body.color.lightened(0.45),
		atmo,
		body.color.darkened(0.86),
	]]


## diameter en unidades del padre; on_screen en pixeles reales, para fijar el grano del pixel art.
func fit(diameter: float, on_screen: float) -> void:
	size = Vector2(diameter, diameter) * _halo
	(material as ShaderMaterial).set_shader_parameter("pixels", clampf(roundf(on_screen * _halo / TEXEL), 8.0, 128.0 * _halo / HALO_SCALE))


func light_from(direction: Vector2) -> void:
	(material as ShaderMaterial).set_shader_parameter("light_dir", direction.normalized())
