class_name SimRng
extends RefCounted

## La semilla y el estado forman parte de cada punto de control.
var generator := RandomNumberGenerator.new()

func _init(seed_value: int = 1) -> void:
	generator.seed = seed_value

func between(low: float, high: float) -> float:
	return generator.randf_range(low, high)
