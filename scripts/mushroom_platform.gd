extends StaticBody3D

@export var stem_height: float = 1.5
@export var cap_radius: float = 2.0

func _ready() -> void:
	var stem_mesh = CylinderMesh.new()
	stem_mesh.top_radius = 0.28
	stem_mesh.bottom_radius = 0.38
	stem_mesh.height = stem_height
	var stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.82, 0.74, 0.6, 1)
	stem_mat.roughness = 0.95
	stem_mesh.material = stem_mat
	$Stem.mesh = stem_mesh
	$Stem.position.y = stem_height / 2.0

	var cap_h: float = 0.45
	var cap_mesh = CylinderMesh.new()
	cap_mesh.top_radius = cap_radius * 0.55
	cap_mesh.bottom_radius = cap_radius
	cap_mesh.height = cap_h
	var cap_mat = StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.78, 0.1, 0.06, 1)
	cap_mat.roughness = 0.7
	# Brillo bioluminiscente suave: naranja-rojizo en los bordes del cap
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(1.0, 0.3, 0.05, 1)
	cap_mat.emission_energy_multiplier = 0.35
	cap_mesh.material = cap_mat
	$Cap.mesh = cap_mesh
	$Cap.position.y = stem_height + cap_h / 2.0

	var cap_shape = CylinderShape3D.new()
	cap_shape.radius = cap_radius
	cap_shape.height = cap_h
	$CollisionShape3D.shape = cap_shape
	$CollisionShape3D.position.y = stem_height + cap_h / 2.0
