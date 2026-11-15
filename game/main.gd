extends Node


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.02
	env.glow_hdr_scale = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.25)
	env.set_glow_level(1, 0.5)
	env.set_glow_level(2, 0.6)
	env.set_glow_level(3, 0.45)
	env.set_glow_level(4, 0.3)
	env.set_glow_level(5, 0.15)
	env.set_glow_level(6, 0.06)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	Router.mount(self)
	Router.go(&"hangar")
