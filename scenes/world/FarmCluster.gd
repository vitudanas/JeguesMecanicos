extends Node3D
## Gera uma fazenda por codigo: predio principal (celeiro/silo/moinho) no
## centro, cerca retangular ao redor do "quintal", plantacao em fileiras do
## lado de fora da cerca, e algumas arvores/arbustos espalhados. Mesmo padrao
## de "gerar em vez de instanciar na mao" de CityStreets.gd/RuralScatter.gd.
## RNG proprio, semente fixa por instancia (rng_seed) — cada fazenda fica
## sempre igual entre execucoes, so muda entre fazendas diferentes.

const CITY_BUILDING_SCENE := preload("res://scenes/world/CityBuilding.tscn")
const FENCE_SEGMENT_LENGTH := 5.89

@export var main_building: PackedScene
@export var main_building_scale := 1.0
@export var main_building_rotation_degrees := 0.0

@export var coop_scene: PackedScene
@export var include_coop := false
@export var coop_offset := Vector2(9.0, 6.0)
@export var coop_scale := 1.0

@export var fence_scenes: Array[PackedScene] = []
@export var fence_half_size := Vector2(9.0, 8.0)

@export var crop_scene: PackedScene
@export var crop_rows := 4
@export var crop_cols := 6
@export var crop_spacing := 1.9
@export var crop_offset := Vector2(0.0, -17.0)
@export var crop_scale_min := 0.8
@export var crop_scale_max := 1.2

@export var tree_scenes: Array[PackedScene] = []
@export var tree_count := 6
@export var tree_min_radius := 13.0
@export var tree_max_radius := 21.0
@export var tree_scale_min := 0.8
@export var tree_scale_max := 1.4

@export var rng_seed := 1

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	if main_building != null:
		_place_solid(main_building, Vector3.ZERO, main_building_rotation_degrees, main_building_scale)
	if include_coop and coop_scene != null:
		_place_solid(coop_scene, Vector3(coop_offset.x, 0.0, coop_offset.y), rng.randf_range(0.0, 360.0), coop_scale)

	_build_fence(rng)
	_build_crop_field(rng)
	_build_rural_details(rng)
	_scatter_trees(rng)

func _build_fence(rng: RandomNumberGenerator) -> void:
	if fence_scenes.is_empty():
		return
	var hx := fence_half_size.x
	var hz := fence_half_size.y
	_fence_side(Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz), rng)
	_fence_side(Vector3(hx, 0.0, -hz), Vector3(hx, 0.0, hz), rng)
	_fence_side(Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz), rng)
	_fence_side(Vector3(-hx, 0.0, hz), Vector3(-hx, 0.0, -hz), rng)

func _fence_side(a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.1:
		return
	var dir := delta / length
	var rot_deg := rad_to_deg(atan2(-dir.z, dir.x)) + 90.0
	var count: int = maxi(1, int(round(length / FENCE_SEGMENT_LENGTH)))
	var step := length / float(count)
	for i in range(count):
		var pos := a + dir * (step * (i + 0.5))
		var scene: PackedScene = fence_scenes[rng.randi() % fence_scenes.size()]
		_place_solid(scene, pos, rot_deg, 1.0)

func _build_crop_field(rng: RandomNumberGenerator) -> void:
	if crop_scene == null or crop_rows <= 0 or crop_cols <= 0:
		return
	# Terra arada sob a plantacao: antes as mudas pareciam vasos largados no
	# gramado. O retangulo e maior que as fileiras e usa o mesmo acabamento PBR
	# do resto do mundo.
	var field_size := Vector2(crop_cols * crop_spacing + 3.0,
		crop_rows * crop_spacing + 3.0)
	var patch := StreetFurniture.ground_patch(field_size, Color(0.33, 0.25, 0.17), "farm_soil")
	CitySurface.apply(patch, Color(0.38, 0.29, 0.20), "terra", 2.2, 0.78, 0.75)
	add_child(patch)
	patch.position = Vector3(crop_offset.x, 0.025, crop_offset.y)
	var origin := Vector2(
		crop_offset.x - (crop_cols - 1) * crop_spacing * 0.5,
		crop_offset.y - (crop_rows - 1) * crop_spacing * 0.5
	)
	for row in range(crop_rows):
		for col in range(crop_cols):
			var jitter := Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
			var p := origin + Vector2(col * crop_spacing, row * crop_spacing) + jitter
			var inst := crop_scene.instantiate()
			add_child(inst)
			if inst is Node3D:
				inst.position = Vector3(p.x, 0.0, p.y)
				inst.rotation_degrees.y = rng.randf_range(0.0, 360.0)
				inst.scale = Vector3.ONE * rng.randf_range(crop_scale_min, crop_scale_max)

func _build_rural_details(rng: RandomNumberGenerator) -> void:
	# Fardos, cocho e marcas de uso contam que alguem trabalha aqui; so predio,
	# cerca e arvore deixavam a fazenda parecendo um diorama abandonado.
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.55, 0.43, 0.22)
	straw.roughness = 0.96
	for i in range(7):
		var bale := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.62
		mesh.bottom_radius = 0.62
		mesh.height = 1.15
		mesh.radial_segments = 14
		bale.mesh = mesh
		bale.material_override = straw
		add_child(bale)
		bale.position = Vector3(fence_half_size.x + 3.0 + float(i % 3) * 1.45,
			0.65, -fence_half_size.y + 2.0 + float(i / 3) * 1.5)
		bale.rotation_degrees = Vector3(0.0, rng.randf_range(0.0, 360.0), 90.0)
	var trough := MeshInstance3D.new()
	var trough_mesh := BoxMesh.new()
	trough_mesh.size = Vector3(2.8, 0.55, 0.9)
	trough.mesh = trough_mesh
	var trough_mat := StandardMaterial3D.new()
	trough_mat.albedo_color = Color(0.27, 0.31, 0.32)
	trough_mat.metallic = 0.65
	trough_mat.roughness = 0.48
	trough.material_override = trough_mat
	add_child(trough)
	trough.position = Vector3(-fence_half_size.x + 2.2, 0.3, 1.5)

func _scatter_trees(rng: RandomNumberGenerator) -> void:
	if tree_scenes.is_empty() or tree_count <= 0:
		return
	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < tree_count * 25:
		attempts += 1
		var ang := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(tree_min_radius, tree_max_radius)
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if _inside_rect(pos, fence_half_size, Vector3.ZERO) or _inside_rect(pos, Vector2(crop_cols * crop_spacing * 0.5 + 1.5, crop_rows * crop_spacing * 0.5 + 1.5), Vector3(crop_offset.x, 0.0, crop_offset.y)):
			continue
		var scene: PackedScene = tree_scenes[rng.randi() % tree_scenes.size()]
		_place_solid(scene, pos, rng.randf_range(0.0, 360.0), rng.randf_range(tree_scale_min, tree_scale_max))
		placed += 1

func _inside_rect(pos: Vector3, half_size: Vector2, rect_center: Vector3) -> bool:
	return absf(pos.x - rect_center.x) < half_size.x + 2.0 and absf(pos.z - rect_center.z) < half_size.y + 2.0

func _place_solid(scene: PackedScene, pos: Vector3, rot_deg: float, s: float) -> void:
	var body := CITY_BUILDING_SCENE.instantiate()
	# Arvore: colisao pelo TRONCO, nao pela copa (ver AutoCollisionBody).
	body.slim_collision = true
	body.visual_scene = scene
	body.visual_scale = s
	body.visual_rotation_y_degrees = rot_deg
	add_child(body)
	body.position = pos
