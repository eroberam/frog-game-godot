extends Node3D

# Pequeño grupo de luciérnagas: GPUParticles3D + OmniLight pulsante.
# Pensado para colgarse cerca de árboles, montañas o el cofre seguro.

@export var area_size: Vector3 = Vector3(3.5, 2.0, 3.5)
@export var amount:    int     = 28
@export var pulse_color: Color = Color(0.9, 1.0, 0.45, 1.0)

@onready var light: OmniLight3D = $Light

var _t: float = 0.0

func _ready() -> void:
	var p: GPUParticles3D = $Particles
	p.amount = amount
	var pm := p.process_material as ParticleProcessMaterial
	if pm:
		pm.emission_box_extents = area_size * 0.5
	light.light_color = pulse_color

func _process(delta: float) -> void:
	_t += delta
	# Latido orgánico: dos senos desfasados → energía variable 0.4 .. 1.6
	var pulse: float = 1.0 + sin(_t * 1.8) * 0.3 + sin(_t * 0.7) * 0.3
	light.light_energy = clamp(pulse, 0.3, 1.8)
