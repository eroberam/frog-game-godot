extends CanvasLayer

@onready var items_label:   Label        = $StatsPanel/VBox/ItemsLabel
@onready var hp_bar:        ProgressBar  = $HPBar
@onready var hp_label:      Label        = $HPBar/HPLabel
@onready var charge_bar:    ProgressBar  = $ChargeBar
@onready var stats_label:   Label        = $StatsLine
@onready var power_flash:   Label        = $PowerFlash
@onready var goal_hint:     Label        = $GoalHint
@onready var dialogue_box:  Panel        = $DialogueBox
@onready var speaker_label: Label        = $DialogueBox/VBox/SpeakerLabel
@onready var dialogue_text: Label        = $DialogueBox/VBox/DialogueText
@onready var toast:         Panel        = $CheckpointToast
@onready var toast_title:   Label        = $CheckpointToast/HBox/VBox/Title
@onready var toast_sub:     Label        = $CheckpointToast/HBox/VBox/Subtitle
@onready var splash:        ColorRect    = $WaterSplashOverlay
@onready var quest_text:    Label        = $QuestTracker/HBox/VBox/Text
@onready var petal_count:   Label        = $PetalsBox/HBox/Count
@onready var damage_vig:    ColorRect    = $DamageVignette

const TOAST_OFFSET_LEFT_HIDDEN: float = 0.0
const TOAST_OFFSET_LEFT_SHOWN:  float = -380.0
const TOAST_OFFSET_RIGHT_HIDDEN: float = 380.0
const TOAST_OFFSET_RIGHT_SHOWN:  float = -16.0

var _toast_tween: Tween = null

func _ready() -> void:
	GameState.power_acquired.connect(_on_power_acquired)
	GameState.upgrade_acquired.connect(_on_upgrade_acquired)
	GameState.level_completed.connect(_on_level_completed)
	GameState.dialogue_show.connect(_on_dialogue_show)
	GameState.dialogue_hide.connect(_on_dialogue_hide)
	GameState.health_changed.connect(_on_health_changed)
	GameState.jump_charge_changed.connect(_on_charge_changed)
	GameState.checkpoint_activated.connect(_on_checkpoint_activated)
	GameState.water_splash.connect(_on_water_splash)
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.petal_collected.connect(_on_petal_collected)
	GameState.damage_received.connect(_on_damage_received)
	# Inicializa textos
	quest_text.text  = GameState.current_objective
	petal_count.text = "%d  /  %d" % [GameState.petals_collected, GameState.PETALS_TOTAL]
	power_flash.modulate.a = 0.0
	goal_hint.modulate.a   = 0.0
	dialogue_box.visible   = false
	charge_bar.visible     = false
	toast.visible          = false
	toast.modulate.a       = 0.0
	toast.offset_left      = TOAST_OFFSET_LEFT_HIDDEN
	toast.offset_right     = TOAST_OFFSET_RIGHT_HIDDEN
	items_label.text       = "Elixir: —"
	_on_health_changed(GameState.current_health, GameState.max_health)
	_refresh_stats()

func _on_power_acquired(power_name: String) -> void:
	_refresh_stats()
	match power_name:
		"double_jump":
			items_label.text = "Elixir: Doble Salto ✓"
			_show_flash("¡DOBLE SALTO DESBLOQUEADO!")
		"speed_boost":
			_show_flash("¡VELOCIDAD DESBLOQUEADA!")
		"high_jump":
			_show_flash("¡SALTO ALTO DESBLOQUEADO!")

func _on_upgrade_acquired(upgrade_name: String) -> void:
	_refresh_stats()
	match upgrade_name:
		"sword":
			_show_flash("Daño aumentado. Ahora puedes romper corazas espinosas.")

func _on_health_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value     = current
	hp_label.text    = "%d / %d" % [current, maximum]
	var pct  := float(current) / float(maximum)
	var fill := hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		if   pct > 0.5:  fill.bg_color = Color(0.15, 0.78, 0.2, 1)
		elif pct > 0.25: fill.bg_color = Color(0.9,  0.7,  0.1, 1)
		else:            fill.bg_color = Color(0.85, 0.15, 0.1, 1)
	_refresh_stats()

func _on_charge_changed(pct: float) -> void:
	if pct < 0:
		charge_bar.visible = false
	else:
		charge_bar.visible = true
		charge_bar.value   = pct * 100.0

func _refresh_stats() -> void:
	var jump_str := "Alto" if GameState.has_high_jump else ("Doble" if GameState.has_double_jump else "Simple")
	var atk      := GameState.get_attack_damage()
	var arma     := "Espada de Palmera" if GameState.has_sword else "Puños"
	stats_label.text = "↑ %s  ⚔ %d  🗡 %s" % [jump_str, atk, arma]

func _on_level_completed() -> void:
	_show_flash("¡La Primera Raíz ha despertado!")
	await get_tree().create_timer(3.5).timeout
	GameState.reset()
	get_tree().reload_current_scene()

func _on_dialogue_show(speaker: String, text: String) -> void:
	dialogue_box.visible = true
	speaker_label.text   = speaker
	dialogue_text.text   = text

func _on_dialogue_hide() -> void:
	dialogue_box.visible = false

func _show_flash(msg: String) -> void:
	power_flash.text       = msg
	power_flash.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(2.5)
	t.tween_property(power_flash, "modulate:a", 0.0, 1.2)

func _show_hint(msg: String) -> void:
	goal_hint.text       = msg
	goal_hint.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(3.0)
	t.tween_property(goal_hint, "modulate:a", 0.0, 1.5)

func _on_water_splash() -> void:
	splash.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(splash, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _on_damage_received(_amount: int) -> void:
	# Flash rojo periférico
	damage_vig.modulate.a = 0.65
	var t := create_tween()
	t.tween_property(damage_vig, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _on_objective_changed(text: String) -> void:
	quest_text.text = text
	# Pulse en el texto
	var t := create_tween()
	t.tween_property(quest_text, "modulate", Color(1.6, 1.4, 0.7, 1), 0.18)
	t.tween_property(quest_text, "modulate", Color(1, 1, 1, 1),       0.45)

func _on_petal_collected(total: int, target: int) -> void:
	petal_count.text = "%d  /  %d" % [total, target]
	var t := create_tween()
	t.tween_property(petal_count, "modulate", Color(1.6, 1.0, 1.4, 1), 0.18)
	t.tween_property(petal_count, "modulate", Color(1, 1, 1, 1),       0.45)
	if total == target:
		_show_flash("✦  Ramillete completo: +%d HP máximo  ✦" % (target * GameState.PETAL_HP_BONUS))
	else:
		_show_flash("Pétalo de Savia recogido (+%d HP máx.)" % GameState.PETAL_HP_BONUS)

func _on_checkpoint_activated(checkpoint_name: String) -> void:
	toast_title.text = "PUNTO DE SAVIA ACTIVADO"
	toast_sub.text   = "%s · La charca recuerda este lugar." % checkpoint_name
	toast.visible    = true
	# Reset al estado oculto antes de animar
	toast.offset_left  = TOAST_OFFSET_LEFT_HIDDEN
	toast.offset_right = TOAST_OFFSET_RIGHT_HIDDEN
	toast.modulate.a   = 0.0
	if _toast_tween: _toast_tween.kill()
	_toast_tween = create_tween()
	# Fase 1: slide-in (paralelo) — el toast entra en escena con bounce desde la derecha
	_toast_tween.tween_property(toast, "offset_left",  TOAST_OFFSET_LEFT_SHOWN,  0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.parallel().tween_property(toast, "offset_right", TOAST_OFFSET_RIGHT_SHOWN, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.parallel().tween_property(toast, "modulate:a",   1.0,                       0.25)
	# Fase 2: el toast permanece visible 2.6s
	_toast_tween.tween_interval(2.6)
	# Fase 3: slide-out (paralelo) — el toast sale a la derecha con fade
	_toast_tween.tween_property(toast, "offset_left",  TOAST_OFFSET_LEFT_HIDDEN,  0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_toast_tween.parallel().tween_property(toast, "offset_right", TOAST_OFFSET_RIGHT_HIDDEN, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_toast_tween.parallel().tween_property(toast, "modulate:a",   0.0,                        0.45)
	# Fase 4: ocultar
	_toast_tween.tween_callback(func(): toast.visible = false)
