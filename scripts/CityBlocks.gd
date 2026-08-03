extends Node3D
## Preenche os quarteiroes da grade de CityStreets.gd com fileiras de predios
## encostados na calcada, virados pra rua — como uma quadra urbana de verdade,
## em vez de um predio solitario no meio do terreno (o que deixava a cidade
## com cara de vazia, ver changelog 2026-08-03).
##
## Para cada quarteirao, percorre as 4 bordas colocando predios um ao lado do
## outro (mesma tecnica de "andar ao longo de um trecho" de
## CityStreets.gd:_build_run), avancando pela largura real medida de cada
## modelo. As bordas norte/sul ocupam a largura toda; leste/oeste entram
## recuadas pela profundidade ja ocupada nos cantos, pra nao sobrepor.
##
## O zoneamento sai da distancia ate o centro: arranha-ceus no miolo,
## comercio no anel do meio, casas e galpoes na periferia — da leitura de
## "centro x bairro" sem precisar marcar zona na mao.

const CITY_BUILDING_SCENE := preload("res://scenes/world/CityBuilding.tscn")

## Quantos modelos sortear tentando achar um que caiba no espaco restante da
## borda antes de desistir e deixar o resto vazio.
const FIT_ATTEMPTS := 12

## Cache de AABB por cena: medir instanciando e descartando e caro, entao
## cada modelo so e medido uma vez (mesmo padrao do cache estatico de
## animacoes em Pedestrian.gd).
static var _footprint_cache: Dictionary = {}

@export var streets_x: Array[float] = []  ## posicoes em Z das ruas leste-oeste
@export var streets_z: Array[float] = []  ## posicoes em X das ruas norte-sul

## Distancia da linha de centro da rua ate a fachada. Tem que ser >= a
## road_half_width + sidewalk_width de CityStreets.gd, senao o predio nasce
## em cima da calcada.
@export var road_clearance := 4.0
@export var building_scale := 6.0  ## modulo nativo do kit (= tile_size das ruas)
@export var lot_gap := 0.3         ## folga entre predios vizinhos
@export var facing_offset_degrees := 0.0  ## ajuste se as fachadas nascerem viradas pro lado errado

@export var skyscraper_scenes: Array[PackedScene] = []
@export var commercial_scenes: Array[PackedScene] = []
@export var house_scenes: Array[PackedScene] = []
@export var industrial_scenes: Array[PackedScene] = []

@export var exclude_points: Array[Vector3] = []
@export var exclude_radius := 12.0

@export var rng_seed := 1

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = rng_seed
	if streets_x.size() < 2 or streets_z.size() < 2:
		return
	for j in range(streets_x.size() - 1):
		for i in range(streets_z.size() - 1):
			_build_block(streets_z[i], streets_z[i + 1], streets_x[j], streets_x[j + 1])

func _build_block(x_street_a: float, x_street_b: float, z_street_a: float, z_street_b: float) -> void:
	var x_min := x_street_a + road_clearance
	var x_max := x_street_b - road_clearance
	var z_min := z_street_a + road_clearance
	var z_max := z_street_b - road_clearance
	if x_max - x_min < 2.0 or z_max - z_min < 2.0:
		return

	var center := Vector2((x_street_a + x_street_b) * 0.5, (z_street_a + z_street_b) * 0.5)
	var pool := _pool_for(center)
	if pool.is_empty():
		return

	# Nenhum predio pode passar da metade do quarteirao: assim as duas bordas
	# opostas nunca se encontram no meio, por construcao (sem essa trava, um
	# modelo fundo na borda oeste alcancava o da borda leste num quarteirao
	# estreito).
	var depth_budget_z := (z_max - z_min) * 0.5 - lot_gap
	var depth_budget_x := (x_max - x_min) * 0.5 - lot_gap

	# Norte/sul ocupam a largura toda; guardamos a profundidade usada pra
	# recuar as laterais e nao sobrepor nos cantos.
	var depth_south := _fill_edge(pool, x_min, x_max, z_min, true, false, depth_budget_z)
	var depth_north := _fill_edge(pool, x_min, x_max, z_max, true, true, depth_budget_z)

	var z_side_min := z_min + depth_south + lot_gap
	var z_side_max := z_max - depth_north - lot_gap
	if z_side_max - z_side_min > 2.0:
		_fill_edge(pool, z_side_min, z_side_max, x_min, false, false, depth_budget_x)
		_fill_edge(pool, z_side_min, z_side_max, x_max, false, true, depth_budget_x)

## Percorre uma borda colocando predios lado a lado, todos virados pra fora
## (pra rua). Retorna a maior profundidade usada, pra quem chamou saber o
## quanto recuar as bordas perpendiculares.
## - horizontal=true: anda no eixo X, a borda esta em Z=edge_coord
## - far_side=true: a borda e a de maior coordenada (norte/leste), entao o
##   predio cresce pra dentro no sentido negativo e vira 180 graus.
func _fill_edge(pool: Array, run_min: float, run_max: float, edge_coord: float, horizontal: bool, far_side: bool, depth_budget: float) -> float:
	var cursor := run_min
	var max_depth := 0.0
	var guard := 0
	var rot_deg := _facing_rotation(horizontal, far_side)
	while cursor < run_max and guard < 64:
		guard += 1
		# Sorteia ate achar um modelo que caiba no espaco que sobrou. Sem isso,
		# um unico sorteio largo demais abandonava a borda inteira e deixava
		# buracos grandes na quadra.
		var scene: PackedScene = null
		var width := 0.0
		var depth := 0.0
		for _try in range(FIT_ATTEMPTS):
			var candidate: PackedScene = pool[_rng.randi() % pool.size()]
			var fp := _footprint(candidate, rot_deg)
			if fp == Vector2.ZERO:
				continue
			var w: float = fp.x if horizontal else fp.y
			var d: float = fp.y if horizontal else fp.x
			if cursor + w <= run_max and d <= depth_budget:
				scene = candidate
				width = w
				depth = d
				break
		if scene == null:
			break

		var along := cursor + width * 0.5
		var inward: float = -depth * 0.5 if far_side else depth * 0.5
		var pos: Vector3
		if horizontal:
			pos = Vector3(along, 0.0, edge_coord + inward)
		else:
			pos = Vector3(edge_coord + inward, 0.0, along)

		# Desconta o deslocamento da malha, pra caixa real cair onde foi planejado.
		var off := _center_offset(scene, rot_deg)
		pos -= Vector3(off.x, 0.0, off.y)

		if not _is_excluded(pos):
			_place(scene, pos, rot_deg)
			max_depth = maxf(max_depth, depth)
		cursor += width + lot_gap
	return max_depth

## Rotacao pra fachada olhar pra rua. As fachadas do kit olham pro -Z quando
## nao rotacionadas, entao a borda "sul" (menor Z) e a referencia de 0 grau.
func _facing_rotation(horizontal: bool, far_side: bool) -> float:
	var base: float
	if horizontal:
		base = 180.0 if far_side else 0.0
	else:
		base = 270.0 if far_side else 90.0
	return base + facing_offset_degrees

## Largura/profundidade ocupadas no mundo, ja com a escala e a rotacao
## aplicadas (rotacao multipla de 90 graus so troca X por Z).
func _footprint(scene: PackedScene, rot_deg: float) -> Vector2:
	var base := _base_footprint(scene)
	if base == Vector2.ZERO:
		return Vector2.ZERO
	var swapped := int(round(absf(rot_deg) / 90.0)) % 2 == 1
	var fp := Vector2(base.y, base.x) if swapped else base
	return fp * building_scale

func _base_footprint(scene: PackedScene) -> Vector2:
	return _measure(scene)["size"]

## Deslocamento do centro da malha em relacao a origem do no, ja escalado e
## girado. Varios modelos do kit nao sao centrados na propria origem; sem
## descontar isso, a caixa de colisao real nasce deslocada do lugar planejado
## e os predios acabam se sobrepondo ou invadindo a rua.
func _center_offset(scene: PackedScene, rot_deg: float) -> Vector2:
	var c: Vector2 = _measure(scene)["center"]
	return c.rotated(-deg_to_rad(rot_deg)) * building_scale

func _measure(scene: PackedScene) -> Dictionary:
	var key := scene.resource_path
	if _footprint_cache.has(key):
		return _footprint_cache[key]
	var inst := scene.instantiate()
	var aabb := _compute_local_aabb(inst, Transform3D.IDENTITY)
	inst.free()
	var data := {
		"size": Vector2(aabb.size.x, aabb.size.z),
		"center": Vector2(aabb.position.x + aabb.size.x * 0.5, aabb.position.z + aabb.size.z * 0.5),
	}
	_footprint_cache[key] = data
	return data

## Zoneamento por distancia (Chebyshev, casando com o formato quadrado da
## grade): miolo = arranha-ceu/comercio, meio = comercio/casa, borda =
## casa/galpao industrial.
func _pool_for(center: Vector2) -> Array:
	var ring: float = maxf(absf(center.x), absf(center.y))
	var pool: Array = []
	if ring < 20.0:
		pool.append_array(skyscraper_scenes)
		pool.append_array(commercial_scenes)
	elif ring < 58.0:
		pool.append_array(commercial_scenes)
		pool.append_array(house_scenes)
	else:
		pool.append_array(house_scenes)
		pool.append_array(industrial_scenes)
	return pool

func _is_excluded(pos: Vector3) -> bool:
	for e in exclude_points:
		if Vector2(pos.x - e.x, pos.z - e.z).length() < exclude_radius:
			return true
	return false

func _place(scene: PackedScene, pos: Vector3, rot_deg: float) -> void:
	var body := CITY_BUILDING_SCENE.instantiate()
	body.visual_scene = scene
	body.visual_scale = building_scale
	body.visual_rotation_y_degrees = rot_deg
	add_child(body)
	body.position = pos

func _compute_local_aabb(node: Node, accum: Transform3D) -> AABB:
	var t := accum
	if node is Node3D:
		t = accum * node.transform
	var result := AABB()
	var has_result := false
	if node is MeshInstance3D and node.mesh:
		result = t * node.get_aabb()
		has_result = true
	for child in node.get_children():
		var caabb := _compute_local_aabb(child, t)
		if caabb.size != Vector3.ZERO or (caabb.position != Vector3.ZERO and not has_result):
			if not has_result:
				result = caabb
				has_result = true
			else:
				result = result.merge(caabb)
	return result
