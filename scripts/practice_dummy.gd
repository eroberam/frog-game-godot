extends StaticBody3D

# ══════════════════════════════════════════════════════════════════════════════
# Muñeco de prácticas. Recibe daño, oscila, no se mueve, no inflige daño.
# Al caer: explota en partículas y emite GameState.practice_dummy_defeated.
# Pertenece al grupo "enemies" para que el ray del player lo detecte como
# objetivo válido del click de ataque.
# ══════════════════════════════════════════════════════════════════════════════

const TARGET_HEIGHT := 1.6

@export var max_health: int = 30

var health: int = 0
var _t: float = 0.0
var _hit_t: float = 0.0
var _mesh_scale: float = 1.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var hit_light: OmniLight3D = $HitLight

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("practice_dummies")
	health = max_health
	_normalize_mesh()
	hit_light.light_energy = 0.0

func _normalize_mesh() -> void:
	if mesh == null: return
	var aabb := mesh.get_aabb()
	var k: float = 1.0
	if aabb.size.y > 0.001:
		k = TARGET_HEIGHT / aabb.size.y
	mesh.scale = Vector3.ONE * k
	# Pies del mesh en y=0 (anclado al suelo del StaticBody)
	mesh.position.y = -aabb.position.y * k
	mesh.position.x = -(aabb.position.x + aabb.size.x * 0.5) * k
	mesh.position.z = -(aabb.position.z + aabb.size.z * 0.5) * k
	_mesh_scale = k

func _process(delta: float) -> void:
	_t += delta
	# Oscilación suave (como un muñeco mal anclado al palo)
	mesh.rotation.z = sin(_t * 1.4) * 0.08
	# Hit-flash decae
	if _hit_t > 0.0:
		_hit_t = max(0.0, _hit_t - delta)
		hit_light.light_energy = (_hit_t / 0.35) * 4.0

func take_damage(amount: int) -> void:
	if health <= 0: return
	health -= amount
	# Flash
	_hit_t = 0.35
	var k: float = _mesh_scale
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(k*1.18, k*0.85, k*1.18), 0.07)
	t.tween_property(mesh, "scale", Vector3.ONE * k,                  0.13)
	if health <= 0:
		_die()

func _die() -> void:
	GameState.practice_dummy_defeated.emit()
	# Pequeña secuencia de muerte: shrink + queue_free
	var k: float = _mesh_scale
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(k*1.6, k*0.4, k*1.6), 0.12)
	t.tween_property(mesh, "scale", Vector3.ZERO, 0.25)
	t.tween_callback(queue_free)
