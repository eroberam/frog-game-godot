extends Area3D

# Pétalo de Savia: coleccionable opcional, brilla cálido, gira y oscila.
# Al recogerlo, llama a GameState.collect_petal() (que da +HP máx).

@onready var visual: Node3D = $Visual
@onready var light:  OmniLight3D = $Light

var _t:        float = 0.0
var _start_y:  float = 0.0

func _ready() -> void:
	_start_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	visual.rotation.y += delta * 1.6
	visual.position.y = sin(_t * 1.7) * 0.18
	# Latido en luz para destacar a distancia
	light.light_energy = 1.4 + sin(_t * 2.0) * 0.45

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	GameState.collect_petal()
	# Burst breve antes de desaparecer
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(visual, "scale", Vector3.ONE * 1.8, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual, "modulate", Color(1.4, 1.4, 0.9, 0), 0.3)
	t.tween_property(light,  "light_energy", 5.0, 0.18)
	t.chain().tween_callback(queue_free)
