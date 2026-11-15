class_name Planet
extends ColorRect

## Cuerpo celeste en pixel art procedural (game/shaders/pixel_planet_25d.gdshader).
## Los cuerpos del juego son ficticios: el tipo y la paleta salen de BodyDef, no de sprites de planetas reales.

const SHADER: Shader = preload("res://game/shaders/pixel_planet_25d.gdshader")
const TEXEL := 3.0 ## pixeles de pantalla por texel del planeta
const HALO_SCALE := 1.28 ## margen extra del rectangulo para dibujar el halo atmosferico sin recortes


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
	var palette := _palette_for(body, kind)
	mat.set_shader_parameter("col_a", palette[0])
	mat.set_shader_parameter("col_b", palette[1])
	mat.set_shader_parameter("col_c", palette[2])
	mat.set_shader_parameter("col_atmo", palette[3])
	mat.set_shader_parameter("col_night", palette[4])
	mat.set_shader_parameter("halo_scale", HALO_SCALE)
	p.material = mat
	p.fit(diameter, diameter)
	return p


static func _palette_for(body: BodyDef, kind: int) -> Array[Color]:
	match body.id:
		&"terra":
			return [Color("1d56a8"), Color("4ca852"), Color("f4f3eb"), Color(0.32, 0.78, 1.0, 0.62), Color("0a1428")]
		&"ignea":
			return [Color("4b140d"), Color("e8581c"), Color(1.45, 0.85, 0.32), Color(1.0, 0.45, 0.14, 0.55), Color("240905")]
		&"rubra":
			return [Color("6b2217"), Color("d85a36"), Color("f2bf96"), Color(1.0, 0.58, 0.38, 0.48), Color("1f0b09")]
		&"glacia":
			return [Color("1d4a7a"), Color("47b4d9"), Color("d2f5ff"), Color(0.45, 0.92, 1.0, 0.65), Color("0a182b")]
		&"hielo":
			return [Color("4b6c88"), Color("98cde8"), Color("eefaff"), Color(0.65, 0.9, 1.0, 0.25), Color("14202e")]
		&"ceniza":
			return [Color("4a3128"), Color("8e6150"), Color("c99b86"), Color(0.0, 0.0, 0.0, 0.0), Color("160e0c")]
		&"luna":
			return [Color("52555c"), Color("8c9099"), Color("d6dae0"), Color(0.0, 0.0, 0.0, 0.0), Color("16181c")]
	var atmo := Color(body.atmo_color, 0.55 if body.atmosphere > 0.0 else 0.0)
	return [
		body.color if kind == 0 else body.color.darkened(0.35),
		Color("4f9a4a") if kind == 0 else body.color,
		Color("f2f2ec") if kind == 0 else body.color.lightened(0.45),
		atmo,
		body.color.darkened(0.86),
	]


## diameter en unidades del padre; on_screen en pixeles reales, para fijar el grano del pixel art.
func fit(diameter: float, on_screen: float) -> void:
	size = Vector2(diameter, diameter) * HALO_SCALE
	(material as ShaderMaterial).set_shader_parameter("pixels", clampf(roundf(on_screen * HALO_SCALE / TEXEL), 8.0, 128.0))


func light_from(direction: Vector2) -> void:
	(material as ShaderMaterial).set_shader_parameter("light_dir", direction.normalized())
