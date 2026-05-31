extends StaticBody3D

# Cabaña: modelo 40 cm × 4 = 1.6 u — escala de vivienda pequeña de rana
const MESH_SCALE := 4.0

func _ready() -> void:
	var mesh := find_child("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.scale = Vector3.ONE * MESH_SCALE
