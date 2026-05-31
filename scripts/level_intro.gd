extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
# Intro narrativa multi-acto. Se puede saltar con [Espacio] o [Enter].
# Cada acto es {title, subtitle, hold_time}. Las transiciones cruzan en fade.
# ══════════════════════════════════════════════════════════════════════════════

const ACTS := [
	{
		"title":    "LA CHARCA DEL DESPERTAR",
		"subtitle": "Hace mil mareas, la Primera Raíz alimentó cada hoja del bosque.",
		"hold":     2.6,
	},
	{
		"title":    "EL SILENCIO DE LA SAVIA",
		"subtitle": "Hoy las raíces duermen.\nLas ranas-abeja ya no polinizan los nenúfares.",
		"hold":     2.6,
	},
	{
		"title":    "CROAK, EL REY DE HIERRO",
		"subtitle": "Un sapo coronado de espinas reina sobre las copas húmedas\ny convierte la magia del musgo en óxido.",
		"hold":     2.8,
	},
	{
		"title":    "EMERALD",
		"subtitle": "Una pequeña rana abre los ojos junto a la cabaña de Thornwick.\nLa savia recuerda su nombre.",
		"hold":     2.8,
	},
]

const FADE_TIME := 1.2

var _act_index: int = 0
var _skipped:   bool = false
var _tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("intro_active")
	$BG.color = Color(0, 0, 0, 0.92)
	$VBox/Title.text    = ""
	$VBox/Subtitle.text = ""
	$SkipHint.modulate.a = 0.0
	_set_alpha(0.0)
	_play_act()
	# El hint de skip aparece tras 1.2s
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property($SkipHint, "modulate:a", 0.7, 0.6)

func _input(event: InputEvent) -> void:
	if _skipped: return
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			skip = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_skip()

func _skip() -> void:
	_skipped = true
	if _tween: _tween.kill()
	var t := create_tween()
	t.tween_property($BG,           "modulate:a", 0.0, 0.4)
	t.parallel().tween_property($VBox/Title,    "modulate:a", 0.0, 0.4)
	t.parallel().tween_property($VBox/Subtitle, "modulate:a", 0.0, 0.4)
	t.parallel().tween_property($SkipHint,      "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)

func _play_act() -> void:
	if _skipped: return
	if _act_index >= ACTS.size():
		_skip()
		return
	var act = ACTS[_act_index]
	_act_index += 1
	$VBox/Title.text    = String(act.title)
	$VBox/Subtitle.text = String(act.subtitle)
	_tween = create_tween()
	_tween.tween_method(_set_text_alpha, 0.0, 1.0, FADE_TIME)
	_tween.tween_interval(act.hold)
	_tween.tween_method(_set_text_alpha, 1.0, 0.0, FADE_TIME * 0.8)
	_tween.tween_callback(_play_act)
	# El BG sólo se hace fade-in al primer acto y fade-out al último
	if _act_index == 1:
		var bg_t := create_tween()
		bg_t.tween_method(_set_bg_alpha, 0.0, 1.0, FADE_TIME)

func _set_alpha(a: float) -> void:
	$BG.modulate.a            = a
	$VBox/Title.modulate.a    = a
	$VBox/Subtitle.modulate.a = a

func _set_text_alpha(a: float) -> void:
	$VBox/Title.modulate.a    = a
	$VBox/Subtitle.modulate.a = a

func _set_bg_alpha(a: float) -> void:
	$BG.modulate.a = a
