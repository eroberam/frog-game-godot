extends Area3D

const WATER_SURFACE_Y := -0.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.global_position.y > WATER_SURFACE_Y:
		return

	if body.is_in_group("player"):
		# Flash + diálogo, luego respawn
		GameState.water_splash.emit()
		GameState.show_dialogue("La Charca",
			"Las aguas frías te abrazan… y te devuelven al último Punto de Savia.")
		if body.has_method("enter_water"):
			body.enter_water()
	elif body.is_in_group("enemies"):
		body.queue_free()
