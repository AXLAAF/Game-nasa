extends Node2D

var host: Node


func _draw() -> void:
	if host != null and host.has_method("paint_map"):
		host.paint_map(self)
