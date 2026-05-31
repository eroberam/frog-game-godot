extends Node3D

const NPC_MESH_OFFSET_Y := -1.0

@export var npc_mesh_scale: float = 1.0
@export var speaker_name:   String = "Thornwick el Sabio"
@export var dialogues: Array[String] = [
	"Soy Thornwick. Esta charca necesita tu ayuda.",
	"Ve con cuidado y salta con valentía. ¡Buena suerte!"
]
# Grupo de nodos de la barrera que se abre al terminar el diálogo.
# Dejar vacío si no hay barrera.
@export var gate_group: String = ""
# Si no está vacío, al terminar el diálogo la quest se actualiza a este texto.
@export var next_objective: String = ""

var dialogue_index: int  = 0
var player_nearby:  bool = false
var is_talking:     bool = false

@onready var prompt_label: Label3D = $PromptLabel

func _ready() -> void:
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)
	prompt_label.text = ""
	var mesh := find_child("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.scale      = Vector3.ONE * npc_mesh_scale
		mesh.position.y = NPC_MESH_OFFSET_Y

func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby: return
	if GameState.is_dialogue_open and not is_talking: return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if not is_talking: _start_dialogue()
		else:              _next_dialogue()

func _start_dialogue() -> void:
	is_talking     = true
	dialogue_index = 0
	prompt_label.text = ""
	GameState.show_dialogue(speaker_name, dialogues[dialogue_index])

func _next_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= dialogues.size(): _end_dialogue()
	else: GameState.show_dialogue(speaker_name, dialogues[dialogue_index])

func _end_dialogue() -> void:
	is_talking = false
	GameState.hide_dialogue()
	if player_nearby: prompt_label.text = "[E] Hablar"
	# Abrir la barrera si está configurada
	if gate_group != "":
		for node in get_tree().get_nodes_in_group(gate_group):
			node.queue_free()
	# Actualizar quest tras terminar el diálogo (sólo la primera vez)
	if next_objective != "":
		GameState.set_objective(next_objective)
		next_objective = ""

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_talking:
		player_nearby     = true
		prompt_label.text = "[E] Hablar"

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby     = false
		prompt_label.text = ""
		if is_talking: _end_dialogue()
