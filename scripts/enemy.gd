extends CharacterBody3D

# Altura visible objetivo (mismo valor que el player → mismo tamaño aparente).
const SMALL_TARGET_HEIGHT := 1.6
const BOSS_TARGET_HEIGHT  := 2.4

const HP_BAR_WIDTH  := 1.2
const HP_BAR_HEIGHT := 0.1

const GRAVITY    := 15.0
const FALL_LIMIT := -10.0

@export var max_health:       int   = 60
@export var speed_fraction:   float = 0.6
@export var detection_range:  float = 8.0
@export var attack_range:     float = 1.3
@export var damage_per_hit:   int   = 12
@export var damage_interval:  float = 0.9
@export var has_territory:    bool  = false
@export var territory_radius: float = 4.0
@export var is_boss:          bool  = false

var health:            int    = 0
var damage_timer:      float  = 0.0
var is_lunging:        bool   = false
var phase_2_active:    bool   = false   # Boss fase 2 al llegar al 50% HP
var is_purifying:      bool   = false   # Boss en secuencia de purificación
var player:            Node3D = null
var territory_center:  Vector3
var move_speed:        float  = 1.0

var hp_bar_root: Node3D             = null
var hp_bar_fill: MeshInstance3D     = null
var hp_bar_mat:  StandardMaterial3D = null

var _mesh_scale: float = 1.0   # escala normalizada del mesh para usar en flash

# Telegraphing: tiempo antes del impacto en el que el enemigo "advierte" su ataque.
const TELEGRAPH_TIME := 0.4
var is_telegraphing: bool = false
var _flash_mat:    StandardMaterial3D = null
var _telegraph_tween: Tween = null

func _ready() -> void:
	add_to_group("enemies")
	health           = max_health
	move_speed       = GameState.BASE_SPEED * speed_fraction
	territory_center = global_position
	player           = get_tree().get_first_node_in_group("player")

	var mesh := find_child("MeshInstance3D") as MeshInstance3D
	if mesh:
		_normalize_mesh(mesh, BOSS_TARGET_HEIGHT if is_boss else SMALL_TARGET_HEIGHT)

	_setup_hp_bar()

func _normalize_mesh(m: MeshInstance3D, target_height: float) -> void:
	var aabb := m.get_aabb()
	var k: float = 1.0
	if aabb.size.y > 0.001:
		k = target_height / aabb.size.y
	m.scale = Vector3.ONE * k
	# Detecta los "pies" (parte inferior del capsule) desde la CollisionShape3D.
	var feet_local_y: float = -0.3   # default toadling
	var col := find_child("CollisionShape3D") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var caps: CapsuleShape3D = col.shape
		feet_local_y = col.position.y - caps.height * 0.5
	m.position.y = feet_local_y - aabb.position.y * k
	m.position.x = -(aabb.position.x + aabb.size.x * 0.5) * k
	m.position.z = -(aabb.position.z + aabb.size.z * 0.5) * k
	_mesh_scale = k

func _setup_hp_bar() -> void:
	var bar_y: float = 2.0 if is_boss else 1.5

	hp_bar_root            = Node3D.new()
	hp_bar_root.position.y = bar_y
	add_child(hp_bar_root)

	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(HP_BAR_WIDTH + 0.06, HP_BAR_HEIGHT + 0.04, 0.02)
	var bg_mat  := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.02, 0.02, 0.95)
	bg_mesh.material    = bg_mat
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	hp_bar_root.add_child(bg)

	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(HP_BAR_WIDTH, HP_BAR_HEIGHT, 0.035)
	hp_bar_mat = StandardMaterial3D.new()
	hp_bar_mat.albedo_color          = Color(0.1, 0.85, 0.15, 1.0)
	hp_bar_mat.emission_enabled      = true
	hp_bar_mat.emission               = Color(0.05, 0.4, 0.05, 1.0)
	hp_bar_mat.emission_energy_multiplier = 0.4
	fill_mesh.material = hp_bar_mat

	hp_bar_fill      = MeshInstance3D.new()
	hp_bar_fill.mesh = fill_mesh
	hp_bar_root.add_child(hp_bar_fill)

func _update_hp_bar() -> void:
	if hp_bar_fill == null: return
	var pct: float = clamp(float(health) / float(max_health), 0.0, 1.0)
	hp_bar_fill.scale.x    = max(pct, 0.001)
	hp_bar_fill.position.x = (pct - 1.0) * HP_BAR_WIDTH * 0.5
	var r: float = clamp(2.0 * (1.0 - pct), 0.0, 1.0)
	var g: float = clamp(2.0 * pct,         0.0, 1.0)
	hp_bar_mat.albedo_color = Color(r, g, 0.0, 1.0)
	hp_bar_mat.emission     = Color(r * 0.4, g * 0.4, 0.0, 1.0)

func _process(_delta: float) -> void:
	if hp_bar_root == null or player == null: return
	var dir := player.global_position - hp_bar_root.global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		hp_bar_root.look_at(hp_bar_root.global_position + dir, Vector3.UP)

func _physics_process(delta: float) -> void:
	if is_purifying: return   # Congelado durante la purificación

	if global_position.y < FALL_LIMIT:
		queue_free()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if player == null or is_lunging:
		move_and_slide()
		return

	var dist           := global_position.distance_to(player.global_position)
	var dist_to_center := global_position.distance_to(territory_center)

	if has_territory and dist_to_center > territory_radius:
		var back := (territory_center - global_position)
		back.y = 0.0
		if back.length() > 0.1:
			var bd := back.normalized()
			velocity.x = bd.x * move_speed
			velocity.z = bd.z * move_speed
		move_and_slide()
		return

	if dist < detection_range:
		var dir := (player.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			var dn := dir.normalized()
			velocity.x = dn.x * move_speed
			velocity.z = dn.z * move_speed
			look_at(global_position + dn, Vector3.UP)
		if dist < attack_range:
			damage_timer += delta
			# Aviso (squash + flash rojo) durante TELEGRAPH_TIME antes del golpe
			if damage_timer >= (damage_interval - TELEGRAPH_TIME) and not is_telegraphing:
				_start_telegraph()
			if damage_timer >= damage_interval:
				damage_timer = 0.0
				_end_telegraph()
				GameState.take_damage(damage_per_hit)
				_lunge()
		else:
			# Salimos del alcance: cancelar telegraph en curso
			if is_telegraphing:
				_cancel_telegraph()
	else:
		if is_telegraphing:
			_cancel_telegraph()
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

func _lunge() -> void:
	if is_lunging: return
	is_lunging      = true
	var origin      := global_position
	var forward     := -global_transform.basis.z * 0.8
	var tween       := create_tween()
	tween.tween_property(self, "global_position", origin + forward, 0.1)
	tween.tween_property(self, "global_position", origin,           0.18)
	tween.tween_callback(func(): is_lunging = false)

func _start_telegraph() -> void:
	is_telegraphing = true
	var mesh := find_child("MeshInstance3D") as MeshInstance3D
	if mesh == null: return
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color    = Color(1.0, 0.25, 0.18, 0.0)
		_flash_mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.emission_enabled = true
		_flash_mat.emission         = Color(1.0, 0.2, 0.1, 1)
		_flash_mat.emission_energy_multiplier = 0.0
	mesh.material_overlay = _flash_mat
	if _telegraph_tween: _telegraph_tween.kill()
	_telegraph_tween = create_tween()
	_telegraph_tween.set_parallel(true)
	_telegraph_tween.tween_property(_flash_mat, "emission_energy_multiplier", 1.6, TELEGRAPH_TIME * 0.55)
	_telegraph_tween.tween_property(_flash_mat, "albedo_color", Color(1.0, 0.25, 0.18, 0.45), TELEGRAPH_TIME * 0.55)
	# Squash → carga (compresión vertical, ensancha)
	var k: float = _mesh_scale
	_telegraph_tween.tween_property(mesh, "scale", Vector3(k*1.18, k*0.78, k*1.18), TELEGRAPH_TIME * 0.55)

func _end_telegraph() -> void:
	if not is_telegraphing: return
	is_telegraphing = false
	var mesh := find_child("MeshInstance3D") as MeshInstance3D
	if mesh == null: return
	# Stretch breve (decompresión hacia arriba) → comunica el golpe
	if _telegraph_tween: _telegraph_tween.kill()
	var k: float = _mesh_scale
	_telegraph_tween = create_tween()
	_telegraph_tween.set_parallel(true)
	_telegraph_tween.tween_property(mesh, "scale", Vector3(k*0.78, k*1.36, k*0.78), 0.07)
	if _flash_mat:
		_telegraph_tween.tween_property(_flash_mat, "emission_energy_multiplier", 0.0, 0.16)
		_telegraph_tween.tween_property(_flash_mat, "albedo_color", Color(1.0, 0.25, 0.18, 0.0), 0.16)
	# Vuelta a escala normal
	var settle := create_tween()
	settle.tween_interval(0.07)
	settle.tween_property(mesh, "scale", Vector3.ONE * k, 0.18)
	settle.tween_callback(func():
		if mesh: mesh.material_overlay = null
	)

func _cancel_telegraph() -> void:
	if not is_telegraphing: return
	is_telegraphing = false
	damage_timer = 0.0
	var mesh := find_child("MeshInstance3D") as MeshInstance3D
	if mesh == null: return
	if _telegraph_tween: _telegraph_tween.kill()
	var k: float = _mesh_scale
	_telegraph_tween = create_tween()
	_telegraph_tween.set_parallel(true)
	_telegraph_tween.tween_property(mesh, "scale", Vector3.ONE * k, 0.2)
	if _flash_mat:
		_telegraph_tween.tween_property(_flash_mat, "emission_energy_multiplier", 0.0, 0.2)
		_telegraph_tween.tween_property(_flash_mat, "albedo_color", Color(1.0, 0.25, 0.18, 0.0), 0.2)
	_telegraph_tween.chain().tween_callback(func():
		if mesh: mesh.material_overlay = null
	)

func take_damage(amount: int) -> void:
	if is_purifying: return
	health -= amount
	_update_hp_bar()

	# Flash de escala en el mesh
	var mesh := find_child("MeshInstance3D") as MeshInstance3D
	if mesh:
		var base_s: float = _mesh_scale
		var t      := create_tween()
		t.tween_property(mesh, "scale", Vector3.ONE * base_s * 1.18, 0.06)
		t.tween_property(mesh, "scale", Vector3.ONE * base_s,         0.12)

	# Boss Fase 2: al llegar al 50% HP se vuelve más rápido y agresivo
	if is_boss and not phase_2_active and float(health) <= float(max_health) * 0.5:
		phase_2_active  = true
		move_speed      *= 1.65
		damage_interval *= 0.75
		_enter_phase_2(mesh)

	if health <= 0:
		if is_boss:
			_boss_purification()
		else:
			queue_free()

func _enter_phase_2(mesh: MeshInstance3D) -> void:
	# Pausa breve teatral + flash dramático rojo
	is_lunging = true   # impide que persiga durante la transición
	var k: float = _mesh_scale
	# Aviso visual: flash rojo enorme y crecimiento
	if mesh:
		if _flash_mat == null:
			_flash_mat = StandardMaterial3D.new()
			_flash_mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
			_flash_mat.albedo_color    = Color(1.0, 0.18, 0.12, 0.0)
			_flash_mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
			_flash_mat.emission_enabled = true
			_flash_mat.emission         = Color(1.0, 0.15, 0.1, 1)
			_flash_mat.emission_energy_multiplier = 0.0
		mesh.material_overlay = _flash_mat
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_flash_mat, "emission_energy_multiplier", 3.5, 0.45)
		t.tween_property(_flash_mat, "albedo_color", Color(1.0, 0.18, 0.12, 0.55), 0.45)
		t.tween_property(mesh, "scale", Vector3.ONE * k * 1.45, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain()
		t.tween_property(mesh, "scale", Vector3.ONE * k * 1.08, 0.5)
		t.tween_property(_flash_mat, "emission_energy_multiplier", 1.2, 0.5)
		t.tween_property(_flash_mat, "albedo_color", Color(1.0, 0.18, 0.12, 0.18), 0.5)
	# Diálogo del boss + camera shake (player escucha boss_phase_2_started)
	GameState.boss_phase_2_started.emit()
	GameState.show_dialogue("Croak el Rey de Hierro",
		"¡Aún… puedo… aplastarte! ¡La savia hervirá con tu caída!")
	await get_tree().create_timer(2.4).timeout
	GameState.hide_dialogue()
	is_lunging = false

func _boss_purification() -> void:
	is_purifying = true
	if hp_bar_root:
		hp_bar_root.visible = false

	# Luz verde de purificación
	var light           := OmniLight3D.new()
	light.light_color    = Color(0.2, 1.0, 0.45, 1.0)
	light.omni_range     = 6.0
	light.light_energy   = 0.0
	light.shadow_enabled = false
	add_child(light)

	var mesh := find_child("MeshInstance3D") as MeshInstance3D

	# Secuencia: luz sube → diálogo → mesh encoge → cola de limpieza
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 5.0, 0.6)
	tween.tween_callback(func():
		GameState.show_dialogue("Croak el Guardián",
			"La savia… vuelve a fluir… La charca… te lo agradece…")
	)
	tween.tween_interval(2.8)
	if mesh:
		tween.tween_property(mesh, "scale", Vector3.ZERO, 1.2)
	tween.tween_property(light, "light_energy", 0.0, 0.8)
	tween.tween_callback(func():
		GameState.hide_dialogue()
		queue_free()
	)
