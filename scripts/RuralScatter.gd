extends Node3D
## Espalha props rurais (natureza/montanhas) numa faixa em anel ao redor de um
## centro, por codigo, mesma ideia de CityStreets.gd (gerar em vez de
## instanciar cada prop na mao). RNG proprio (nao usa as funcoes globais
## randf/randi) pra nao interferir na aleatoriedade de outros sistemas
## (trafego, pedestres etc) e pra ficar sempre igual entre execucoes.
##
## Duas categorias de prop:
## - decor_scenes: pequenos, sem colisao (grama, flor, cogumelo, seixo...)
## - solid_scenes: ganham colisao automatica via CityBuilding/AutoCollisionBody
##   (arvore, rocha...) — a mesma tecnica ja usada pelos predios da cidade.
##
## A zona valida e um aro: fora do quadrado `inner_extent` (distancia
## Chebyshev — usado pra ficar fora da area quadrada da cidade) e/ou fora do
## circulo `inner_radius` (distancia euclidiana — usado pro aro de montanhas),
## ate `outer_radius`. `exclude_points`/`exclude_radius` evita nascer em cima
## de fazendas, ferros-velhos ou outros pontos marcados.

@export var decor_scenes: Array[PackedScene] = []
@export var decor_count := 0
@export var decor_scale_min := 0.8
@export var decor_scale_max := 1.4

@export var solid_scenes: Array[PackedScene] = []
@export var solid_count := 0
@export var solid_scale_min := 0.8
@export var solid_scale_max := 1.5

@export var center := Vector3.ZERO
@export var inner_extent := 0.0
@export var inner_radius := 0.0
@export var outer_radius := 100.0

@export var exclude_points: Array[Vector3] = []
@export var exclude_radius := 20.0

@export var rng_seed := 1

const CITY_BUILDING_SCENE := preload("res://scenes/world/CityBuilding.tscn")

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_scatter(rng, decor_scenes, decor_count, decor_scale_min, decor_scale_max, false)
	_scatter(rng, solid_scenes, solid_count, solid_scale_min, solid_scale_max, true)

func _scatter(rng: RandomNumberGenerator, pool: Array[PackedScene], count: int, smin: float, smax: float, solid: bool) -> void:
	if pool.is_empty() or count <= 0:
		return
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 25:
		attempts += 1
		var pos := _random_point(rng)
		if not _is_valid(pos):
			continue
		var scene: PackedScene = pool[rng.randi() % pool.size()]
		var s := rng.randf_range(smin, smax)
		var rot := rng.randf_range(0.0, 360.0)
		if solid:
			_place_solid(scene, pos, rot, s)
		else:
			_place_decor(scene, pos, rot, s)
		placed += 1

func _random_point(rng: RandomNumberGenerator) -> Vector3:
	var ang := rng.randf_range(0.0, TAU)
	var r: float
	if inner_radius > 0.0:
		r = sqrt(rng.randf_range(inner_radius * inner_radius, outer_radius * outer_radius))
	else:
		r = sqrt(rng.randf_range(0.0, 1.0)) * outer_radius
	return center + Vector3(cos(ang) * r, 0.0, sin(ang) * r)

func _is_valid(pos: Vector3) -> bool:
	var local := pos - center
	if inner_extent > 0.0 and maxf(absf(local.x), absf(local.z)) < inner_extent:
		return false
	if inner_radius > 0.0 and Vector2(local.x, local.z).length() < inner_radius:
		return false
	if Vector2(local.x, local.z).length() > outer_radius:
		return false
	for e in exclude_points:
		if Vector2(pos.x - e.x, pos.z - e.z).length() < exclude_radius:
			return false
	return true

func _place_decor(scene: PackedScene, pos: Vector3, rot_deg: float, s: float) -> void:
	var inst := scene.instantiate()
	add_child(inst)
	if inst is Node3D:
		inst.position = pos
		inst.rotation_degrees.y = rot_deg
		inst.scale = Vector3.ONE * s

func _place_solid(scene: PackedScene, pos: Vector3, rot_deg: float, s: float) -> void:
	var body := CITY_BUILDING_SCENE.instantiate()
	body.visual_scene = scene
	body.visual_scale = s
	body.visual_rotation_y_degrees = rot_deg
	add_child(body)
	body.position = pos
