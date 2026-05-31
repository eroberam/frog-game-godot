extends Node

# ══════════════════════════════════════════════════════════════════════════════
# STATS BASE — Nivel 1
# Daño base bajo → la Espada de Palmera se siente como un salto importante.
# Velocidad y Salto Alto quedan reservados para Nivel 2.
# ══════════════════════════════════════════════════════════════════════════════
const BASE_SPEED    := 1.1
const BOOST_SPEED   := 2.0    # Nivel 2
const BASE_JUMP     := 6.5
const HIGH_JUMP     := 8.5    # Nivel 2
const BASE_DMG      := 10     # sin arma: daño bajo intencionado
const SWORD_BONUS   := 15     # con espada total = 25
const MAX_HP        := 100

# ── Misión opcional: Pétalos de Savia ─────────────────────────────────────────
const PETALS_TOTAL  := 6
const PETAL_HP_BONUS := 10   # +10 HP máx. por cada pétalo recogido

# ── Poderes y upgrades ────────────────────────────────────────────────────────
var has_double_jump:  bool = false
var has_speed_boost:  bool = false   # Nivel 2
var has_high_jump:    bool = false   # Nivel 2
var has_sword:        bool = false
var is_dialogue_open: bool = false

# ── Salud ─────────────────────────────────────────────────────────────────────
var max_health:     int = MAX_HP
var current_health: int = MAX_HP

# ── Coleccionables ────────────────────────────────────────────────────────────
var items_collected:  int = 0
var petals_collected: int = 0

# ── Checkpoint ────────────────────────────────────────────────────────────────
var checkpoint_pos: Vector3 = Vector3(0.0, 1.0, 0.0)

# ── Quest activa ─────────────────────────────────────────────────────────────
var current_objective: String = "Habla con Thornwick el Sabio"

# ── Flags persistentes de tutorial ────────────────────────────────────────────
# Se ponen a true la primera vez que el jugador realiza la acción. Permiten
# al tutorial_guide saltar lecciones que ya cumplió, incluso si la lección
# todavía no estaba escuchando la señal en ese momento.
var did_move:           bool = false
var did_jump:           bool = false
var did_charged_jump:   bool = false
var did_double_jump:    bool = false
var did_attack:         bool = false

# ── Señales del mundo ─────────────────────────────────────────────────────────
signal item_collected(total: int)
signal power_acquired(power_name: String)
signal upgrade_acquired(upgrade_name: String)
signal level_completed
signal dialogue_show(speaker: String, text: String)
signal dialogue_hide
signal health_changed(current: int, maximum: int)
signal jump_charge_changed(pct: float)
signal player_died
signal checkpoint_reached(pos: Vector3)
signal checkpoint_activated(checkpoint_name: String)
signal water_splash

# ── Señales de acción del jugador (para tutorial) ─────────────────────────────
signal player_moved
signal player_jumped
signal player_charged_jumped
signal player_double_jumped
signal player_attacked

# ── Señales de recompensa / mundo ─────────────────────────────────────────────
signal petal_collected(total: int, target: int)
signal practice_dummy_defeated
signal boss_phase_2_started
signal damage_received(amount: int)
signal objective_changed(text: String)

# ── Consultas ─────────────────────────────────────────────────────────────────
func get_speed() -> float:
	return BOOST_SPEED if has_speed_boost else BASE_SPEED

func get_jump() -> float:
	return HIGH_JUMP if has_high_jump else BASE_JUMP

func get_attack_damage() -> int:
	return BASE_DMG + SWORD_BONUS if has_sword else BASE_DMG

# ── Checkpoint ────────────────────────────────────────────────────────────────
func set_checkpoint(pos: Vector3) -> void:
	checkpoint_pos = pos + Vector3(0.0, 0.1, 0.0)
	checkpoint_reached.emit(checkpoint_pos)

func activate_checkpoint(checkpoint_name: String) -> void:
	checkpoint_activated.emit(checkpoint_name)

# ── Items y poderes ───────────────────────────────────────────────────────────
func collect_item() -> void:
	items_collected += 1
	item_collected.emit(items_collected)

func acquire_power(power_name: String) -> void:
	match power_name:
		"double_jump": has_double_jump = true
		"speed_boost": has_speed_boost = true
		"high_jump":   has_high_jump   = true
	power_acquired.emit(power_name)

func acquire_upgrade(upgrade_name: String) -> void:
	match upgrade_name:
		"sword": has_sword = true
	upgrade_acquired.emit(upgrade_name)

# ── Acciones del jugador (con flag persistente + signal) ─────────────────────
func mark_action(action: String) -> void:
	match action:
		"moved":
			if did_move: return
			did_move = true; player_moved.emit()
		"jumped":
			if did_jump: return
			did_jump = true; player_jumped.emit()
		"charged_jumped":
			if did_charged_jump: return
			did_charged_jump = true; player_charged_jumped.emit()
		"double_jumped":
			if did_double_jump: return
			did_double_jump = true; player_double_jumped.emit()
		"attacked":
			if did_attack: return
			did_attack = true; player_attacked.emit()

# ── Pétalos de Savia ──────────────────────────────────────────────────────────
func collect_petal() -> void:
	petals_collected = min(petals_collected + 1, PETALS_TOTAL)
	# Bonus permanente de HP máximo
	max_health     += PETAL_HP_BONUS
	current_health  = min(current_health + PETAL_HP_BONUS, max_health)
	petal_collected.emit(petals_collected, PETALS_TOTAL)
	health_changed.emit(current_health, max_health)

# ── Quest ─────────────────────────────────────────────────────────────────────
func set_objective(text: String) -> void:
	if text == current_objective: return
	current_objective = text
	objective_changed.emit(text)

# ── Vida ──────────────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	damage_received.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		player_died.emit()

func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

# ── Nivel ─────────────────────────────────────────────────────────────────────
func level_complete() -> void:
	set_objective("¡La Primera Raíz ha despertado!")
	level_completed.emit()

func show_dialogue(speaker: String, text: String) -> void:
	is_dialogue_open = true
	dialogue_show.emit(speaker, text)

func hide_dialogue() -> void:
	is_dialogue_open = false
	dialogue_hide.emit()

# ── Reset ─────────────────────────────────────────────────────────────────────
func reset() -> void:
	items_collected   = 0
	petals_collected  = 0
	has_double_jump   = false
	has_speed_boost   = false
	has_high_jump     = false
	has_sword         = false
	is_dialogue_open  = false
	max_health        = MAX_HP
	current_health    = max_health
	checkpoint_pos    = Vector3(0.0, 1.0, 0.0)
	current_objective = "Habla con Thornwick el Sabio"
	did_move = false
	did_jump = false
	did_charged_jump = false
	did_double_jump = false
	did_attack = false
	health_changed.emit(current_health, max_health)
	objective_changed.emit(current_objective)
	petal_collected.emit(0, PETALS_TOTAL)
