extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
# Panel "Cómo Jugar" — modal con grid de controles e iconos.
# Aparece tras la intro narrativa. Se cierra con [Espacio], [Enter] o click.
# Mientras está abierto, pausa la entrada del jugador (process_mode ALWAYS).
# ══════════════════════════════════════════════════════════════════════════════

@export var auto_show_delay: float = 0.6   # tras la intro, pausa antes de aparecer
@export var fade_in_time:    float = 0.45
@export var fade_out_time:   float = 0.35

@onready var bg:    ColorRect = $BG
@onready var panel: Panel     = $Panel
@onready var hint:  Label     = $Panel/Footer/Hint

var _open: bool = false
var _ready_to_close: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	bg.modulate.a    = 0.0
	panel.modulate.a = 0.0
	panel.scale      = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	# Pausamos el juego desde el principio: el LevelIntro corre con
	# process_mode=ALWAYS y no se ve afectado, pero el Player y el resto
	# del mundo quedan congelados hasta que el panel se cierra.
	get_tree().paused = true
	# Esperamos a que la intro termine antes de aparecer.
	get_tree().create_timer(auto_show_delay).timeout.connect(_show)

func _show() -> void:
	# Si la intro aún está abierta, esperamos un poco más.
	if get_tree().get_first_node_in_group("intro_active"):
		await get_tree().create_timer(0.3).timeout
		_show()
		return
	visible = true
	_open = true
	panel.pivot_offset = panel.size * 0.5
	var t := create_tween()
	t.tween_property(bg,    "modulate:a", 1.0, fade_in_time)
	t.parallel().tween_property(panel, "modulate:a", 1.0, fade_in_time)
	t.parallel().tween_property(panel, "scale",      Vector2.ONE, fade_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _ready_to_close = true)

func _input(event: InputEvent) -> void:
	if not _open or not _ready_to_close: return
	var close := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_E]:
			close = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close = true
	if close:
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	_open = false
	_ready_to_close = false
	var t := create_tween()
	t.tween_property(bg,    "modulate:a", 0.0, fade_out_time)
	t.parallel().tween_property(panel, "modulate:a", 0.0, fade_out_time)
	t.parallel().tween_property(panel, "scale",      Vector2(0.94, 0.94), fade_out_time)
	t.tween_callback(func():
		get_tree().paused = false
		queue_free()
	)
