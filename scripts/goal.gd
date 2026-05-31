extends Area3D

# ══════════════════════════════════════════════════════════════════════════════
# Portal final: rota lentamente, los anillos giran en direcciones opuestas,
# la luz late con dos senos desfasados.
# ══════════════════════════════════════════════════════════════════════════════

@onready var ring_a: MeshInstance3D = $RingA
@onready var ring_b: MeshInstance3D = $RingB
@onready var core:   MeshInstance3D = $Core
@onready var light:  OmniLight3D    = $Light

var _t: float = 0.0
var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	rotation.y       += delta * 0.6
	ring_a.rotation.y -= delta * 1.4
	ring_b.rotation.y += delta * 1.8
	# Latido en luz: dos senos desfasados
	light.light_energy = 2.0 + sin(_t * 2.0) * 0.6 + sin(_t * 0.7) * 0.4
	# Pulso suave en el core
	core.scale.x = 1.0 + sin(_t * 2.4) * 0.05
	core.scale.z = 1.0 + sin(_t * 2.4) * 0.05

func _on_body_entered(body: Node3D) -> void:
	if _triggered: return
	if body.is_in_group("player"):
		_triggered = true
		GameState.level_complete()
