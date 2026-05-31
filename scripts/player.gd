extends CharacterBody3D

# ══════════════════════════════════════════════════════════════════════════════
# SISTEMA DE COORDENADAS
# CharacterBody3D en world y = 1.0 cuando está sobre el suelo (y = 0).
# Cada mesh se normaliza a TARGET_HEIGHT (1.6 u) usando su AABB en _ready,
# y se ancla con sus pies a world y = 0 (mesh local y = -1.0 desde el centro
# del player, que está en world y = 1.0).
# ══════════════════════════════════════════════════════════════════════════════

const GRAVITY        := 15.0
const ACCELERATION   := 11.0
const DECELERATION   := 70.0
const FALL_LIMIT     := -10.0

const MAX_CHARGE_SEC  := 1.4
const MIN_JUMP_FRAC   := 0.3

const CAM_ANGLE_DEG    := -18.0
const CAM_DEFAULT_DIST := 2.5
const CAM_ZOOM_MIN    := 1.5
const CAM_ZOOM_MAX    := 9.0
const CAM_ZOOM_SMOOTH := 7.0
const CAM_LOOK_HEIGHT := 0.0
const CAM_FOLLOW_SMOOTH := 9.5

const ATTACK_COOLDOWN := 0.45
const ATTACK_RAY_DIST := 50.0

# Altura visible objetivo en unidades de mundo (todas las mallas se escalan a esto).
const TARGET_HEIGHT := 1.0
# Histéresis para entrar / salir del estado "andando" — evita flicker en el límite.
const WALK_ENTER_SPEED := 0.55
const WALK_EXIT_SPEED  := 0.20

# ── Estado ────────────────────────────────────────────────────────────────────
var jump_count:      int   = 0
var cam_target_dist: float = CAM_DEFAULT_DIST
var cam_curr_dist:   float = CAM_DEFAULT_DIST
var walk_time:       float = 0.0
var idle_time:       float = 0.0
var was_on_floor:    bool  = true
var attack_timer:    float = 0.0
var is_jump_charging: bool  = false
var jump_charge_time: float = 0.0

# Flags one-shot para señalizar acciones de tutorial al GameState
var _flag_moved:          bool = false
var _flag_jumped:         bool = false
var _flag_charged:        bool = false
var _flag_double_jumped:  bool = false
var _flag_attacked:       bool = false
var _spawn_pos: Vector3
# Camera shake
var _shake_t:    float = 0.0
var _shake_amp:  float = 0.0

# Cada mesh guarda su escala normalizada y su posición Y de "pies en suelo".
var _mesh_scale: Dictionary = {}
var _mesh_y:     Dictionary = {}
var _active_mesh_ref: MeshInstance3D = null

@onready var cam:               Camera3D       = get_node("../Camera3D")
@onready var frog_mesh:         MeshInstance3D = $FrogMesh
@onready var frog_walk_mesh:    MeshInstance3D = $FrogWalkMesh
@onready var frog_hop_mesh:     MeshInstance3D = $FrogHopMesh
@onready var warrior_mesh:      MeshInstance3D = $WarriorMesh
@onready var warrior_walk_mesh: MeshInstance3D = $WarriorWalkMesh

func _ready() -> void:
	add_to_group("player")
	GameState.player_died.connect(_on_died)
	GameState.upgrade_acquired.connect(func(_n): _update_mesh_visibility(false))
	GameState.damage_received.connect(_on_damage_received)
	GameState.boss_phase_2_started.connect(func(): _camera_shake(0.45, 1.2))
	for m: MeshInstance3D in [frog_mesh, frog_walk_mesh, frog_hop_mesh, warrior_mesh, warrior_walk_mesh]:
		_normalize_mesh(m)
	# Comenzamos en idle frog
	_set_active_mesh(frog_mesh, false)
	_spawn_pos = global_position

# Normaliza un mesh a TARGET_HEIGHT usando su AABB y ancla su base a world y=0.
func _normalize_mesh(m: MeshInstance3D) -> void:
	if m == null: return
	var aabb := m.get_aabb()
	var k: float = 1.0
	if aabb.size.y > 0.001:
		k = TARGET_HEIGHT / aabb.size.y
	m.scale = Vector3.ONE * k
	# Pies del mesh = world y=0 → mesh.position.y tal que aabb.position.y * k
	# (extremo inferior tras escalar) caiga en local y=-1.0 (Player está en y=1.0).
	m.position.y = -1.0 - aabb.position.y * k
	# Centrar X/Z para evitar deriva entre meshes con orígenes distintos
	m.position.x = -(aabb.position.x + aabb.size.x * 0.5) * k
	m.position.z = -(aabb.position.z + aabb.size.z * 0.5) * k
	_mesh_scale[m] = k
	_mesh_y[m]     = m.position.y
	m.visible = false

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				cam_target_dist = clamp(cam_target_dist - 0.5, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam_target_dist = clamp(cam_target_dist + 0.5, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_attack_click()

# ── Física principal ──────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT:
		_do_respawn()
		return

	attack_timer = max(0.0, attack_timer - delta)
	var on_floor := is_on_floor()

	if on_floor and not was_on_floor:
		_land_anim()
		if is_jump_charging:
			is_jump_charging = false
			jump_charge_time = 0.0
			GameState.jump_charge_changed.emit(-1.0)
	was_on_floor = on_floor
	if on_floor: jump_count = 0
	if not on_floor: velocity.y -= GRAVITY * delta

	_handle_jump(delta, on_floor)

	var dir    := _input_dir()
	var speed  := GameState.get_speed()
	var moving := dir.length() > 0.01

	if moving and not is_jump_charging:
		dir        = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, ACCELERATION * delta)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 7.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)

	move_and_slide()
	# Decisión idle/walk con histéresis para no parpadear en el límite.
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var was_walking := _active_mesh_ref == frog_walk_mesh or _active_mesh_ref == warrior_walk_mesh
	var threshold: float = WALK_EXIT_SPEED if was_walking else WALK_ENTER_SPEED
	var is_walking := horiz_speed > threshold and on_floor and not is_jump_charging
	_update_mesh_visibility(is_walking)

	# Tutorial: detectar primer movimiento real
	if not _flag_moved and global_position.distance_to(_spawn_pos) > 1.2:
		_flag_moved = true
		GameState.mark_action("moved")
	_walk_anim(delta, is_walking, speed)
	_update_camera(delta)

func _do_respawn() -> void:
	global_position  = GameState.checkpoint_pos
	velocity         = Vector3.ZERO
	jump_count       = 0
	is_jump_charging = false
	jump_charge_time = 0.0
	for m: MeshInstance3D in [frog_mesh, frog_walk_mesh, frog_hop_mesh, warrior_mesh, warrior_walk_mesh]:
		var k: float = _mesh_scale.get(m, 1.0)
		m.scale      = Vector3.ONE * k
		m.position.y = _mesh_y.get(m, -1.0)
	GameState.jump_charge_changed.emit(-1.0)
	_update_mesh_visibility(false)

# ── Salto cargado ─────────────────────────────────────────────────────────────
func _handle_jump(delta: float, on_floor: bool) -> void:
	var max_jumps  := 2 if GameState.has_double_jump else 1
	var jump_force := GameState.get_jump()

	if Input.is_action_just_pressed("ui_accept"):
		if on_floor and not is_jump_charging:
			is_jump_charging = true
			jump_charge_time = 0.0
		elif not on_floor and jump_count < max_jumps:
			velocity.y  = jump_force
			jump_count += 1
			_jump_anim()
			if jump_count == 2 and not _flag_double_jumped:
				_flag_double_jumped = true
				GameState.mark_action("double_jumped")

	if is_jump_charging and on_floor:
		jump_charge_time = min(jump_charge_time + delta, MAX_CHARGE_SEC)
		GameState.jump_charge_changed.emit(jump_charge_time / MAX_CHARGE_SEC)
		if Input.is_action_just_released("ui_accept") or jump_charge_time >= MAX_CHARGE_SEC:
			var pct:   float = jump_charge_time / MAX_CHARGE_SEC
			var min_j: float = jump_force * MIN_JUMP_FRAC
			velocity.y       = lerp(min_j, jump_force, pct)
			jump_count       = 1
			is_jump_charging = false
			jump_charge_time = 0.0
			GameState.jump_charge_changed.emit(-1.0)
			_jump_anim()
			if not _flag_jumped:
				_flag_jumped = true
				GameState.mark_action("jumped")
			# Salto cargado se considera completado si retuviste >40% de la barra
			if pct > 0.4 and not _flag_charged:
				_flag_charged = true
				GameState.mark_action("charged_jumped")

func _input_dir() -> Vector3:
	var d := Vector3.ZERO
	if Input.is_action_pressed("ui_right"): d.x += 1
	if Input.is_action_pressed("ui_left"):  d.x -= 1
	if Input.is_action_pressed("ui_down"):  d.z += 1
	if Input.is_action_pressed("ui_up"):    d.z -= 1
	return d

# ── Cámara con seguimiento suave ──────────────────────────────────────────────
var _cam_target_pos: Vector3 = Vector3.ZERO
var _cam_init: bool = false

func _update_camera(delta: float) -> void:
	cam_curr_dist = lerp(cam_curr_dist, cam_target_dist, CAM_ZOOM_SMOOTH * delta)
	var angle_rad := deg_to_rad(CAM_ANGLE_DEG)
	var ideal := global_position + Vector3(
		0.0,
		-sin(angle_rad) * cam_curr_dist,
		 cos(angle_rad) * cam_curr_dist
	)
	if not _cam_init:
		_cam_target_pos = ideal
		cam.global_position = ideal
		_cam_init = true
	else:
		_cam_target_pos = _cam_target_pos.lerp(ideal, CAM_FOLLOW_SMOOTH * delta)
		cam.global_position = _cam_target_pos
	# Camera shake aditivo, decae exponencialmente
	if _shake_t > 0.0:
		_shake_t = max(0.0, _shake_t - delta)
		var k: float = _shake_t / max(_shake_amp, 0.0001)
		var shake := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.6, 0.6),
			randf_range(-1.0, 1.0)
		) * (_shake_amp * 0.18 * k)
		cam.global_position += shake
	cam.look_at(global_position + Vector3(0.0, CAM_LOOK_HEIGHT, 0.0), Vector3.UP)

func _camera_shake(amp: float, dur: float) -> void:
	_shake_amp = max(_shake_amp, amp)
	_shake_t   = max(_shake_t, dur)

func _on_damage_received(_amount: int) -> void:
	_camera_shake(0.18, 0.25)

# ── Visibilidad de meshes (idle/walk/hop, con/sin espada) ─────────────────────
func _update_mesh_visibility(is_walking: bool) -> void:
	var target: MeshInstance3D
	if is_jump_charging:
		target = frog_hop_mesh
	elif GameState.has_sword:
		target = warrior_walk_mesh if is_walking else warrior_mesh
	else:
		target = frog_walk_mesh if is_walking else frog_mesh
	if target == _active_mesh_ref: return
	_set_active_mesh(target, is_walking)

func _set_active_mesh(target: MeshInstance3D, _walking: bool) -> void:
	for m: MeshInstance3D in [frog_mesh, frog_walk_mesh, frog_hop_mesh, warrior_mesh, warrior_walk_mesh]:
		if m == null: continue
		m.visible = (m == target)
	# Reset de la pose visual al cambiar de mesh para evitar saltos
	if target != null:
		var k: float = _mesh_scale.get(target, 1.0)
		target.scale      = Vector3.ONE * k
		target.position.y = _mesh_y.get(target, -1.0)
		target.rotation.z = 0.0
	_active_mesh_ref = target

# ── Ataque ────────────────────────────────────────────────────────────────────
func _attack_click() -> void:
	if attack_timer > 0: return
	attack_timer = ATTACK_COOLDOWN

	var mouse_pos  := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mouse_pos)
	var ray_end    := ray_origin + cam.project_ray_normal(mouse_pos) * ATTACK_RAY_DIST

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := space_state.intersect_ray(query)

	if result:
		var hit: Node3D = result.collider as Node3D
		if hit and hit.is_in_group("enemies"):
			hit.take_damage(GameState.get_attack_damage())
			if not _flag_attacked:
				_flag_attacked = true
				GameState.mark_action("attacked")
			# Feedback visual: pequeño squash en el personaje activo
			var m := _active_mesh()
			if m:
				var k: float = _mesh_scale.get(m, 1.0)
				var t := create_tween()
				t.tween_property(m, "scale", Vector3(k*1.15, k*0.82, k*1.15), 0.07)
				t.tween_property(m, "scale", Vector3.ONE * k,                  0.13)

func enter_water() -> void:
	if global_position.y < -0.3:
		velocity = Vector3.ZERO
		await get_tree().create_timer(1.2).timeout
		GameState.hide_dialogue()
		_do_respawn()

func _on_died() -> void:
	await get_tree().create_timer(1.2).timeout
	GameState.reset()
	get_tree().reload_current_scene()

# ── Animación procedural superpuesta al modelo seleccionado ───────────────────
func _walk_anim(delta: float, walking: bool, speed: float) -> void:
	var m := _active_mesh()
	if m == null: return
	var k: float = _mesh_scale.get(m, 1.0)
	var base_y: float = _mesh_y.get(m, -1.0)
	var base_scale := Vector3.ONE * k
	if walking:
		idle_time  = 0.0
		walk_time += delta * speed * 4.2
		# Hop pronunciado: abs(sin) sólo sube
		var hop:   float = abs(sin(walk_time)) * 0.13
		var sway:  float = sin(walk_time * 0.5) * 0.028
		var phase: float = sin(walk_time)
		var sx:    float = k * (1.0 - phase * 0.05)
		var sy:    float = k * (1.0 + phase * 0.07)
		m.position.y = lerp(m.position.y, base_y + hop, 16.0 * delta)
		m.rotation.z = lerp(m.rotation.z, sway,         9.0 * delta)
		m.scale      = m.scale.lerp(Vector3(sx, sy, sx), 11.0 * delta)
	else:
		walk_time  = 0.0
		idle_time += delta
		var breathe: float = sin(idle_time * 1.6) * 0.009
		var bscale:  float = 1.0 + sin(idle_time * 0.9) * 0.008
		m.position.y = lerp(m.position.y, base_y + breathe, 5.0 * delta)
		m.rotation.z = lerp(m.rotation.z, 0.0,              5.0 * delta)
		m.scale      = m.scale.lerp(base_scale * bscale,    5.0 * delta)

func _active_mesh() -> MeshInstance3D:
	return _active_mesh_ref

func _jump_anim() -> void:
	var m := _active_mesh()
	if m == null: return
	var k: float = _mesh_scale.get(m, 1.0)
	var t := create_tween()
	t.tween_property(m, "scale", Vector3(k*0.75, k*1.4, k*0.75), 0.1)
	t.tween_property(m, "scale", Vector3.ONE * k,                 0.2)

func _land_anim() -> void:
	var m := _active_mesh()
	if m == null: return
	var k: float = _mesh_scale.get(m, 1.0)
	var t := create_tween()
	t.tween_property(m, "scale", Vector3(k*1.4, k*0.62, k*1.4), 0.07)
	t.tween_property(m, "scale", Vector3.ONE * k,                0.22)
