extends Area3D

var _time: float = 0.0
var _start_y: float = 0.0

func _ready() -> void:
	_start_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time      += delta
	rotation.y += delta * 2.5
	position.y  = _start_y + sin(_time * 2.2) * 0.1

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameState.acquire_upgrade("sword")
		GameState.set_objective("Derrota a Croak, el Rey de Hierro")
		queue_free()
