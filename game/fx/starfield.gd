class_name Starfield
extends CanvasLayer

## Fondo espacial en pixel art (game/shaders/pixel_space_bg.gdshader) con paletas de nebulosa por mision.

const PALETTES := [
	{"col": Color("173063"), "accent": Color("268c9e"), "warm": Color("6b297d")},
	{"col": Color("261b5e"), "accent": Color("9c2f74"), "warm": Color("b86228")},
	{"col": Color("123c42"), "accent": Color("28a684"), "warm": Color("2e4cb8")},
	{"col": Color("2b1854"), "accent": Color("94409c"), "warm": Color("317eb8")},
	{"col": Color("4a1728"), "accent": Color("ab3c42"), "warm": Color("bd7a2c")},
	{"col": Color("13316e"), "accent": Color("2a9fd6"), "warm": Color("6e52c2")},
	{"col": Color("14364a"), "accent": Color("3ca868"), "warm": Color("9c3876")},
]

var _rect: ColorRect


func _init() -> void:
	layer = -10
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/pixel_space_bg.gdshader")
	mat.set_shader_parameter("pixel_size", 3.0)
	mat.set_shader_parameter("nebula_intensity", 0.8)
	_rect.material = mat
	add_child(_rect)
	var base: Dictionary = PALETTES[0]
	set_palette(base.col, base.accent, base.warm)


func _ready() -> void:
	apply_mission()


static func palette_for(contract: Contract, run_seed := 0) -> Dictionary:
	var h := absi(run_seed * 37)
	if contract != null:
		h = absi(hash("%s_%s_%d_%d" % [contract.cargo, String(contract.target), contract.payout, run_seed]))
	var idx := h % PALETTES.size()
	var base: Dictionary = PALETTES[idx]
	var shift := Vector2(float(h % 59) * 0.73, float((h / 7) % 53) * 0.61)
	return {
		"index": idx,
		"col": base.col,
		"accent": base.accent,
		"warm": base.warm,
		"shift": shift,
	}


func apply_mission() -> void:
	var p := palette_for(Run.contract, Profile.runs)
	set_palette(p.col, p.accent, p.warm, p.shift)


func set_palette(col: Color, accent: Color, warm: Color, shift := Vector2.ZERO) -> void:
	var mat := _rect.material as ShaderMaterial
	mat.set_shader_parameter("nebula_col", col)
	mat.set_shader_parameter("nebula_accent", accent)
	mat.set_shader_parameter("nebula_warm", warm)
	mat.set_shader_parameter("nebula_shift", shift)


func set_view(view: Vector2) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("scroll_offset", view)


func set_sky(color: Color, star_alpha: float) -> void:
	var mat := _rect.material as ShaderMaterial
	mat.set_shader_parameter("bg_void", color)
	mat.set_shader_parameter("stars", star_alpha)
