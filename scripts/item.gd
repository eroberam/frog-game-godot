extends Area3D

# Elixir: recogible que puede otorgar un poder y/o curar.
# El mesh se normaliza por AABB para encajar a TARGET_HEIGHT.
const TARGET_HEIGHT := 0.55

@export var power_name:  String = ""
@export var heal_amount: int    = 0

var _time:    float = 0.0
var _start_y: float = 0.0
var _mesh:    MeshInstance3D

func _ready() -> void:
	_start_y = position.y
	body_entered.connect(_on_body_entered)
	_mesh = find_child("MeshInstance3D") as MeshInstance3D
	if _mesh:
		var aabb := _mesh.get_aabb()
		if aabb.size.y > 0.001:
			var k: float = TARGET_HEIGHT / aabb.size.y
			_mesh.scale      = Vector3.ONE * k
			_mesh.position.y = -aabb.position.y * k
			_mesh.position.x = -(aabb.position.x + aabb.size.x * 0.5) * k
			_mesh.position.z = -(aabb.position.z + aabb.size.z * 0.5) * k

func _process(delta: float) -> void:
	_time      += delta
	rotation.y += delta * 2.0
	# Bob suave: 0.12 u de amplitud
	position.y  = _start_y + sin(_time * 2.0) * 0.12

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	GameState.collect_item()
	if heal_amount > 0:
		GameState.heal(heal_amount)
	if power_name != "":
		GameState.acquire_power(power_name)
	queue_free()
