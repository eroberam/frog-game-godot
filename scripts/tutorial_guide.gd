extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
# Tutorial Guide — secuencia de lecciones detectables.
#
# Para cada lección:
#   1. Conectamos la señal (one-shot) AL INICIO del paso, antes del delay.
#   2. Esperamos `delay` segundos.
#   3. Si la lección no se completó durante la espera, mostramos el prompt.
#   4. Cuando la señal llega, animamos un tick verde y avanzamos.
#
# Este orden permite saltar lecciones que el jugador ya cumplió antes de que
# el tutorial le advirtiera (por ejemplo, alguien que ya conoce los controles).
# ══════════════════════════════════════════════════════════════════════════════

@onready var box:    Panel = $Box
@onready var label:  Label = $Box/Label
@onready var arrow:  Label = $Box/Arrow

const HIDE_AFTER_COMPLETION := 1.4

var _current_idx: int = -1
var _showing:     bool = false

const LESSONS: Array = [
	{
		"id":      "move",
		"signal":  "player_moved",
		"prompt":  "Pulsa  [ W ]  [ A ]  [ S ]  [ D ]    para moverte",
		"delay":   1.6,
	},
	{
		"id":      "jump",
		"signal":  "player_jumped",
		"prompt":  "Pulsa  [ Espacio ]  para saltar",
		"delay":   6.5,
	},
	{
		"id":      "attack",
		"signal":  "player_attacked",
		"prompt":  "Click izquierdo sobre el muñeco de paja para atacar",
		"delay":   6.0,
	},
	{
		"id":      "charged",
		"signal":  "player_charged_jumped",
		"prompt":  "Mantén  [ Espacio ]  pulsado  →  carga un salto largo",
		"delay":   4.0,
	},
	{
		"id":      "double",
		"signal":  "player_double_jumped",
		"prompt":  "Salta otra vez en el aire  →  ✦ Doble Salto ✦",
		"delay":   0.6,
		"wait_for_power": "double_jump",
	},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	box.modulate.a = 0.0
	box.visible    = false
	_advance()

func _process(_delta: float) -> void:
	if not _showing: return
	# Pulse del símbolo de flecha mientras el prompt está visible
	arrow.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)

func _advance() -> void:
	_current_idx += 1
	if _current_idx >= LESSONS.size():
		await _hide_box()
		queue_free()
		return
	var lesson: Dictionary = LESSONS[_current_idx]
	var idx_local: int = _current_idx
	# Si el jugador ya completó esta acción antes de que la lección llegara
	# a estar activa, saltamos sin mostrar prompt.
	if _action_already_done(String(lesson.id)):
		await get_tree().create_timer(0.3, false).timeout
		if idx_local == _current_idx:
			_advance()
		return
	# Si la lección requiere un poder específico, esperamos a que el jugador
	# lo desbloquee antes de mostrar el prompt.
	if lesson.has("wait_for_power"):
		await _wait_for_power(String(lesson.wait_for_power))
		if idx_local != _current_idx: return
	# Conectar la señal one-shot ANTES del delay
	var cb := func(): _on_lesson_completed(idx_local)
	GameState.connect(StringName(lesson.signal), cb, CONNECT_ONE_SHOT)
	# Esperar delay (respetando la pausa del SceneTree)
	await get_tree().create_timer(lesson.delay, false).timeout
	# Si la lección ya avanzó por completarse durante el delay, salir.
	if idx_local != _current_idx: return
	_show_prompt(String(lesson.prompt))

func _action_already_done(lesson_id: String) -> bool:
	match lesson_id:
		"move":    return GameState.did_move
		"jump":    return GameState.did_jump
		"attack":  return GameState.did_attack
		"charged": return GameState.did_charged_jump
		"double":  return GameState.did_double_jump
	return false

func _wait_for_power(target_power: String) -> void:
	# Caso ya desbloqueado (re-spawn / recarga)
	match target_power:
		"double_jump":
			if GameState.has_double_jump: return
		"speed_boost":
			if GameState.has_speed_boost: return
		"high_jump":
			if GameState.has_high_jump:   return
	# Esperar al signal correspondiente
	while true:
		var p: String = await GameState.power_acquired
		if p == target_power:
			return

func _on_lesson_completed(idx: int) -> void:
	if idx != _current_idx: return
	if _showing:
		# Tick verde de feedback y luego cierre
		var t := create_tween()
		t.tween_property(label, "modulate", Color(0.55, 1.0, 0.55, 1), 0.18)
		t.tween_interval(HIDE_AFTER_COMPLETION)
		t.tween_callback(_continue_after_visible_completion)
	else:
		# Pasó tan rápido que ni se mostró: avanzamos sin animación.
		await get_tree().create_timer(0.4, false).timeout
		_advance()

func _continue_after_visible_completion() -> void:
	await _hide_box()
	_advance()

func _show_prompt(text: String) -> void:
	label.text     = text
	label.modulate = Color(1, 1, 1, 1)
	box.modulate.a = 0.0
	box.visible    = true
	_showing       = true
	var t := create_tween()
	t.tween_property(box, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _hide_box() -> void:
	if not _showing: return
	var t := create_tween()
	t.tween_property(box, "modulate:a", 0.0, 0.4)
	await t.finished
	box.visible = false
	_showing    = false
