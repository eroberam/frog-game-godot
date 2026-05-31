extends Node3D

const CHEST_SCALE    := 2.5
const CHEST_OFFSET_Y := 0.0

@export_enum("health", "enemy") var chest_type: String = "health"
@export var heal_amount:  int         = 35
@export var enemy_scene:  PackedScene = null
@export var boss_scene:   PackedScene = null
# Grupo de bambús que se abrirán cuando todos los enemigos de este cofre mueran
@export var gate_group:   String      = ""

var player_nearby:     bool   = false
var opened:            bool   = false
var _spawned_enemies:  Array  = []
var _check_timer:      Timer  = null

@onready var prompt: Label3D = $PromptLabel

func _ready() -> void:
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)
	prompt.text = ""
	$ChestMesh.scale      = Vector3.ONE * CHEST_SCALE
	$ChestMesh.position.y = CHEST_OFFSET_Y

func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby or opened or GameState.is_dialogue_open: return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_open()

func _open() -> void:
	opened      = true
	prompt.text = ""
	var tween   := create_tween()
	tween.tween_property($ChestMesh, "position", Vector3(0, 0.35, 0), 0.15)
	tween.tween_property($ChestMesh, "scale",    Vector3(1.2, 0.4, 1.2), 0.1)
	tween.tween_property($ChestMesh, "scale",    Vector3.ZERO, 0.18)
	await tween.finished

	match chest_type:
		"health":
			GameState.heal(heal_amount)
		"enemy":
			if enemy_scene:
				var e := enemy_scene.instantiate()
				e.position = global_position + Vector3(1.5, 2.5, 1.5)
				get_parent().add_child(e)
				_spawned_enemies.append(e)
			if boss_scene:
				var b := boss_scene.instantiate()
				b.position = global_position + Vector3(-1.5, 2.5, 1.5)
				get_parent().add_child(b)
				_spawned_enemies.append(b)
			# Vigilar si todos los enemigos mueren para abrir la jaula
			if gate_group != "" and not _spawned_enemies.is_empty():
				_check_timer = Timer.new()
				_check_timer.wait_time = 0.5
				_check_timer.autostart = true
				_check_timer.timeout.connect(_check_gate)
				add_child(_check_timer)

func _check_gate() -> void:
	var any_alive := false
	for e in _spawned_enemies:
		if is_instance_valid(e):
			any_alive = true
			break

	if not any_alive:
		# Detener y liberar el timer de forma diferida (seguro desde su propio callback)
		if _check_timer:
			_check_timer.stop()
			_check_timer.call_deferred("queue_free")
			_check_timer = null

		# Abrir la jaula
		for node in get_tree().get_nodes_in_group(gate_group):
			node.queue_free()

		# Thornwick comenta la victoria desde lejos
		GameState.show_dialogue("Thornwick el Sabio",
			"La charca recompensa a quien sobrevive a sus trampas.")
		await get_tree().create_timer(3.0).timeout
		GameState.hide_dialogue()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not opened:
		player_nearby = true
		prompt.text   = "[E] Abrir"

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		if not opened: prompt.text = ""
