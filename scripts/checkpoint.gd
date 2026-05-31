extends Area3D

# ══════════════════════════════════════════════════════════════════════════════
# Checkpoint: piedra rúnica con pilar pasivo de luz ambiental.
# Al activarse: el pilar destella, anillos de partículas suben, suena ⟂.
# Notifica al GameState (que reenvía a HUD) para mostrar el toast en pantalla.
# ══════════════════════════════════════════════════════════════════════════════

@export var checkpoint_name: String = "Punto de Savia"

var activated := false

@onready var pillar:    MeshInstance3D = $Pillar
@onready var ring:      MeshInstance3D = $Ring
@onready var rune:      MeshInstance3D = $Rune
@onready var light:     OmniLight3D    = $Light
@onready var spotlight: SpotLight3D    = $Spotlight
@onready var particles: GPUParticles3D = $ActivateParticles
@onready var pillar_mat: StandardMaterial3D
@onready var ring_mat:   StandardMaterial3D
@onready var rune_mat:   StandardMaterial3D

var _t: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Materiales se duplican para poder modular emisión sin afectar a otras instancias
	pillar_mat = pillar.get_active_material(0).duplicate() if pillar.get_active_material(0) else null
	ring_mat   = ring.get_active_material(0).duplicate()   if ring.get_active_material(0)   else null
	rune_mat   = rune.get_active_material(0).duplicate()   if rune.get_active_material(0)   else null
	if pillar_mat: pillar.material_override = pillar_mat
	if ring_mat:   ring.material_override   = ring_mat
	if rune_mat:   rune.material_override   = rune_mat
	particles.emitting = false
	light.light_energy    = 0.4
	spotlight.light_energy = 0.0

func _process(delta: float) -> void:
	_t += delta
	# Idle: rune y ring giran lentamente; ya activado giran más rápido
	var spin_speed: float = 2.4 if activated else 0.6
	rune.rotation.y += delta * spin_speed
	ring.rotation.y -= delta * spin_speed * 0.7
	# Bobbing del rune
	rune.position.y = 0.55 + sin(_t * 1.5) * 0.05
	# Latido sutil
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.0)
	if pillar_mat:
		pillar_mat.emission_energy_multiplier = (2.5 + pulse * 1.5) if activated else (0.5 + pulse * 0.3)
	if rune_mat:
		rune_mat.emission_energy_multiplier = (3.5 + pulse * 1.5) if activated else (1.0 + pulse * 0.4)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or activated: return
	activated = true
	GameState.set_checkpoint(body.global_position)
	GameState.activate_checkpoint(checkpoint_name)
	_play_activation_anim()

func _play_activation_anim() -> void:
	# Spotlight de columna y partículas
	particles.restart()
	particles.emitting = true
	if rune_mat:
		rune_mat.albedo_color = Color(1.0, 1.0, 0.6, 1)
		rune_mat.emission     = Color(1.0, 1.0, 0.5, 1)
	if ring_mat:
		ring_mat.albedo_color = Color(0.6, 1.0, 0.7, 1)
		ring_mat.emission     = Color(0.5, 1.0, 0.6, 1)
	# Animaciones simultáneas (escala del rune y luz)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(spotlight, "light_energy",  6.0, 0.25)
	t.tween_property(light,     "light_energy",  2.4, 0.25)
	t.tween_property(rune,      "scale",         Vector3(1.7, 1.7, 1.7), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain()
	t.tween_property(rune,      "scale",         Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(spotlight, "light_energy",  2.5, 0.6)
	t.chain()
	t.tween_callback(func(): particles.emitting = false)
