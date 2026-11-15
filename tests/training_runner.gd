extends SceneTree

## Usa el handler de test_run del addon aun sin conexión MCP al editor.
class RuntimeTestHandler extends "res://addons/godot_ai/handlers/test_handler.gd":
	func _annotate_edited_scene(_results: Dictionary) -> void:
		pass # El runtime no tiene EditorInterface ni escena editada.

func _initialize() -> void:
	await process_frame
	root.get_node("Profile").persistence_enabled = false
	var handler := RuntimeTestHandler.new(null, null)
	var result: Dictionary = handler.run_tests({"suite": "training", "verbose": true})
	print(JSON.stringify(result, "  "))
	var data: Dictionary = result.get("data", {})
	quit(0 if not result.has("error") and int(data.get("failed", 1)) == 0 and int(data.get("total", 0)) > 0 else 1)
