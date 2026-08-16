extends Node3D
## Ferro-velho rural decorativo: pilha de destroços (caixas no mesmo formato
## com chassi, cabine e rodas, cores enferrujadas, tombados em ângulos
## aleatórios), caixotes e vegetação ao redor. Só decoração —
## sem física de veículo de verdade, sem Interactable, pra não virar um
## segundo "ferro-velho" jogável (esse continua sendo só o Junkyard.tscn
## principal). RNG próprio, semente fixa por instância.

const CITY_BUILDING_SCENE := preload("res://scenes/world/CityBuilding.tscn")

const WRECK_COLORS := [
	Color(0.55, 0.2, 0.12), Color(0.4, 0.32, 0.22), Color(0.35, 0.35, 0.38),
	Color(0.5, 0.4, 0.15), Color(0.3, 0.22, 0.18),
]

@export var wreck_count := 3
@export var wreck_min_radius := 0.0
@export var wreck_max_radius := 7.0

@export var crate_count := 3
@export var crate_min_radius := 3.0
@export var crate_max_radius := 8.0

@export var decor_scenes: Array[PackedScene] = []
@export var decor_count := 4
@export var decor_min_radius := 8.0
@export var decor_max_radius := 15.0

@export var ground_radius := 12.0

@export var rng_seed := 1

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_build_ground()
	_scatter_wrecks(rng)
	_scatter_crates(rng)
	_scatter_decor(rng)

func _scatter_wrecks(rng: RandomNumberGenerator) -> void:
	for i in range(wreck_count):
		var pos := _ring_point(rng, wreck_min_radius, wreck_max_radius)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.8, 1.0, 4.0) * rng.randf_range(0.85, 1.1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = WRECK_COLORS[rng.randi() % WRECK_COLORS.size()]
		mat.metallic = 0.15
		mat.roughness = 0.85

		var body := StaticBody3D.new()
		add_child(body)
		body.position = pos + Vector3(0.0, mesh.size.y * 0.5, 0.0)
		body.rotation_degrees = Vector3(
			rng.randf_range(-18.0, 18.0),
			rng.randf_range(0.0, 360.0),
			rng.randf_range(-14.0, 14.0)
		)

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = mesh
		mesh_inst.set_surface_override_material(0, mat)
		body.add_child(mesh_inst)

		# Cabine e rodas tiram o destroco da leitura de "caixa colorida". Ficam
		# filhos do mesmo corpo/rotacao, portanto o carro tombado continua coeso.
		var cabin := BoxMesh.new()
		cabin.size = Vector3(mesh.size.x * 0.82, mesh.size.y * 0.72, mesh.size.z * 0.44)
		var cabin_inst := MeshInstance3D.new()
		cabin_inst.mesh = cabin
		cabin_inst.position = Vector3(0.0, mesh.size.y * 0.72, -mesh.size.z * 0.08)
		var cabin_mat := mat.duplicate() as StandardMaterial3D
		cabin_mat.albedo_color = mat.albedo_color.darkened(0.13)
		cabin_inst.set_surface_override_material(0, cabin_mat)
		body.add_child(cabin_inst)
		var wheel_mat := StandardMaterial3D.new()
		wheel_mat.albedo_color = Color(0.055, 0.052, 0.048)
		wheel_mat.roughness = 0.96
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var wheel := CylinderMesh.new()
				wheel.top_radius = mesh.size.y * 0.31
				wheel.bottom_radius = wheel.top_radius
				wheel.height = mesh.size.x * 0.16
				wheel.radial_segments = 12
				var wheel_inst := MeshInstance3D.new()
				wheel_inst.mesh = wheel
				wheel_inst.rotation_degrees.z = 90.0
				wheel_inst.position = Vector3(x * mesh.size.x * 0.54,
					-mesh.size.y * 0.24, z * mesh.size.z * 0.31)
				wheel_inst.set_surface_override_material(0, wheel_mat)
				body.add_child(wheel_inst)

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		body.add_child(shape)

func _build_ground() -> void:
	# Mancha de cascalho/oleo delimita o lote no campo; sem ela os poucos props
	# pareciam largados no gramado, e nao um ferro-velho.
	var mesh := CylinderMesh.new()
	mesh.top_radius = ground_radius
	mesh.bottom_radius = ground_radius * 1.04
	mesh.height = 0.035
	mesh.radial_segments = 32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.23, 0.22, 0.19)
	mat.roughness = 0.98
	var ground := MeshInstance3D.new()
	ground.name = "ScrapyardGround"
	ground.mesh = mesh
	ground.position.y = 0.012
	ground.set_surface_override_material(0, mat)
	add_child(ground)

func _scatter_crates(rng: RandomNumberGenerator) -> void:
	for i in range(crate_count):
		var pos := _ring_point(rng, crate_min_radius, crate_max_radius)
		var mesh := BoxMesh.new()
		var side := rng.randf_range(0.8, 1.3)
		mesh.size = Vector3.ONE * side
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.35, 0.2).lerp(Color(0.4, 0.3, 0.22), rng.randf())

		var body := StaticBody3D.new()
		add_child(body)
		body.position = pos + Vector3(0.0, side * 0.5, 0.0)
		body.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = mesh
		mesh_inst.set_surface_override_material(0, mat)
		body.add_child(mesh_inst)

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		body.add_child(shape)

func _scatter_decor(rng: RandomNumberGenerator) -> void:
	if decor_scenes.is_empty():
		return
	for i in range(decor_count):
		var pos := _ring_point(rng, decor_min_radius, decor_max_radius)
		var scene: PackedScene = decor_scenes[rng.randi() % decor_scenes.size()]
		var body := CITY_BUILDING_SCENE.instantiate()
		# Arvore: colisao pelo TRONCO, nao pela copa (ver AutoCollisionBody).
		body.slim_collision = true
		body.visual_scene = scene
		body.visual_scale = rng.randf_range(0.8, 1.3)
		body.visual_rotation_y_degrees = rng.randf_range(0.0, 360.0)
		add_child(body)
		body.position = pos

func _ring_point(rng: RandomNumberGenerator, min_r: float, max_r: float) -> Vector3:
	var ang := rng.randf_range(0.0, TAU)
	var r := rng.randf_range(min_r, max_r)
	return Vector3(cos(ang) * r, 0.0, sin(ang) * r)
