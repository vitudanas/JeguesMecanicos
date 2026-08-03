extends Node3D
## Ferro-velho rural decorativo: pilha de destroços (caixas no mesmo formato
## blockout do carro em Vehicle.tscn, cores enferrujadas, tombados em ângulos
## aleatórios), caixotes e árvores mortas/arbustos ao redor. Só decoração —
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

@export var rng_seed := 1

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
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

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		body.add_child(shape)

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
		body.visual_scene = scene
		body.visual_scale = rng.randf_range(0.8, 1.3)
		body.visual_rotation_y_degrees = rng.randf_range(0.0, 360.0)
		add_child(body)
		body.position = pos

func _ring_point(rng: RandomNumberGenerator, min_r: float, max_r: float) -> Vector3:
	var ang := rng.randf_range(0.0, TAU)
	var r := rng.randf_range(min_r, max_r)
	return Vector3(cos(ang) * r, 0.0, sin(ang) * r)
