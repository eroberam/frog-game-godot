extends Area3D

# Bumblefrog: modelo ~20 cm × 3 ≈ 0.6 u — pequeño NPC volador
const MESH_SCALE    := 3.0
const WANDER_SPEED  := 1.4     # u/s de deambulación
const WANDER_RADIUS := 3.5     # radio de movimiento aleatorio
const HEAL_ON_TOUCH := 20      # HP restaurados al recoger

var _time:         float   = 0.0
var _wander_timer: float   = 0.0
var _start_pos:    Vector3
var _target_pos:   Vector3

func _ready() -> void:
	_start_pos  = global_position
	_target_pos = _random_target()
	body_entered.connect(_on_body_entered)
	var mesh := find_child("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.scale = Vector3.ONE * MESH_SCALE

func _process(delta: float) -> void:
	_time         += delta
	_wander_timer += delta
	if _wander_timer > randf_range(2.0, 4.0):
		_wander_timer = 0.0
		_target_pos   = _random_target()

	var flat_dir := _target_pos - global_position
	flat_dir.y = 0.0
	if flat_dir.length() > 0.3:
		global_position += flat_dir.normalized() * WANDER_SPEED * delta
		rotation.y       = lerp_angle(rotation.y, atan2(flat_dir.x, flat_dir.z), 5.0 * delta)

	# Bob vertical: 0.08 u de amplitud
	global_position.y = _start_pos.y + sin(_time * 3.5) * 0.08

func _random_target() -> Vector3:
	var angle := randf() * TAU
	var dist  := randf_range(0.5, WANDER_RADIUS)
	return Vector3(_start_pos.x + cos(angle) * dist, _start_pos.y, _start_pos.z + sin(angle) * dist)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameState.heal(HEAL_ON_TOUCH)
		queue_free()
