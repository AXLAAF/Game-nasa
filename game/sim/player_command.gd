class_name PlayerCommand
extends RefCounted

var action: StringName
var value: float
var part_id: StringName
var index: int

func _init(kind: StringName = &"", amount: float = 0.0, part: StringName = &"", slot: int = -1) -> void:
	action = kind
	value = amount
	part_id = part
	index = slot
