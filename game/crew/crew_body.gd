extends CharacterBody2D
## Camina por las salas. El mando 1 y las flechas son de este jugador.

var host: Node


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	if host == null or host.busy:
		velocity = Vector2.ZERO
		if host == null or not host.on_hull:
			move_and_slide()
		return
	var wish := Controls.crew_vector() * 150.0
	if host.on_hull:
		position = host.stick_to_hull(position + wish * delta)
		velocity = Vector2.ZERO
	else:
		velocity = wish
		move_and_slide()
	if Controls.crew_interact_just():
		host.interact(position)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 8, Ui.IVORY)
	draw_circle(Vector2(3, -2), 2, Color(0.1, 0.1, 0.12))
