extends Node3D
## Cinturao de transicao entre a cidade e o campo.
##
## Sem ele a borda corta seco: quarteirao cheio de um lado da ultima rua e
## mato do outro. Aqui as construcoes vao ficando MENORES e MAIS ESPARSAS
## conforme se afastam da cidade, entao a silhueta desce de predio pra casa,
## de casa pra galpao solto, e so entao comeca o campo.
##
## A faixa e um anel QUADRADO (distancia Chebyshev), igual ao formato da
## grade de ruas — com anel circular a folga ficaria desigual entre os eixos
## retos e as diagonais, o mesmo motivo documentado no anel rural.
##
## RNG proprio, com semente fixa: nao mexe na aleatoriedade de trafego e
## pedestres, e o resultado e sempre o mesmo entre execucoes.

const CITY_BUILDING_SCENE := preload("res://scenes/world/CityBuilding.tscn")

@export var scenes: Array[PackedScene] = []
## Onde a cidade acaba e onde o campo comeca (Chebyshev, a partir do centro).
@export var inner_extent := 104.0
@export var outer_extent := 130.0
@export var attempts := 420
## Escala perto da cidade e na borda do campo. O degrade de tamanho e o que
## mais pesa na leitura — mais que a densidade.
@export var scale_near := 5.2
@export var scale_far := 3.0
## Chance de manter um sorteio na borda externa (perto da cidade e sempre 1.0).
@export var keep_chance_far := 0.22
## Folga minima entre vizinhos, somada ao raio medido dos dois.
@export var spacing := 2.5
@export var facade_colors: Array[Color] = []
@export var exclude_points: Array[Vector3] = []
@export var exclude_radius := 30.0
@export var rng_seed := 7

var _rng := RandomNumberGenerator.new()
var _placed: Array = []

func _ready() -> void:
	if scenes.is_empty():
		return
	_rng.seed = rng_seed
	for i in range(attempts):
		# `t` (0 = colado na cidade, 1 = ja no campo) e sorteado ANTES da
		# posicao: ele decide tamanho, densidade e so entao a profundidade.
		# Fazendo o contrario — sortear o ponto e depois descartar o que nao
		# coubesse — as construcoes grandes do lado de dentro eram justamente
		# as mais descartadas, e o degrade saia invertido.
		# Enviesado pro lado da cidade (expoente > 1 concentra perto de 0):
		# com sorteio uniforme a faixa externa, que e mais comprida, acabava
		# com a mesma densidade da interna e o degrade sumia.
		var t := pow(_rng.randf(), 1.6)
		if _rng.randf() > lerpf(1.0, keep_chance_far, t):
			continue
		var scene: PackedScene = scenes[_rng.randi() % scenes.size()]
		var prop_scale := lerpf(scale_near, scale_far, t) * _rng.randf_range(0.9, 1.1)
		var radius := _radius(scene, prop_scale)
		# A faixa vale pra CONSTRUCAO INTEIRA, nao so pro centro: e por isso
		# que o inicio da faixa util ja desconta o raio — senao uma casa larga
		# plantada no limite avancava por cima da ultima rua da cidade.
		var near_limit := inner_extent + radius
		if near_limit >= outer_extent:
			continue
		var pos := _point_at(lerpf(near_limit, outer_extent, t))
		if _is_excluded(pos) or _too_close(pos, radius):
			continue
		_place(scene, pos, prop_scale)
		_placed.append({"p": Vector2(pos.x, pos.z), "r": radius})

## Ponto sorteado sobre o quadrado de "raio" Chebyshev `depth`: sorteando o
## lado e a posicao ao longo dele dentro de [-depth, depth], a distancia
## Chebyshev do ponto e exatamente `depth`, inclusive nos cantos.
func _point_at(depth: float) -> Vector3:
	var along := _rng.randf_range(-depth, depth)
	match _rng.randi() % 4:
		0:
			return Vector3(along, 0.0, -depth)
		1:
			return Vector3(along, 0.0, depth)
		2:
			return Vector3(-depth, 0.0, along)
		_:
			return Vector3(depth, 0.0, along)

func _is_excluded(pos: Vector3) -> bool:
	for e in exclude_points:
		if Vector2(pos.x - e.x, pos.z - e.z).length() < exclude_radius:
			return true
	return false

func _too_close(pos: Vector3, radius: float) -> bool:
	var here := Vector2(pos.x, pos.z)
	for other in _placed:
		if here.distance_to(other["p"]) < radius + float(other["r"]) + spacing:
			return true
	return false

## Meia diagonal da planta, ja escalada: serve de raio pro teste de vizinhanca
## seja qual for a rotacao sorteada.
func _radius(scene: PackedScene, prop_scale: float) -> float:
	var inst := scene.instantiate()
	var aabb := _local_aabb(inst, Transform3D.IDENTITY)
	inst.free()
	return Vector2(aabb.size.x, aabb.size.z).length() * 0.5 * prop_scale

func _place(scene: PackedScene, pos: Vector3, prop_scale: float) -> void:
	var body := CITY_BUILDING_SCENE.instantiate()
	body.visual_scene = scene
	body.visual_scale = prop_scale
	# Fachada virada pro lado da cidade (com folga sorteada), pra ler como
	# subudrbio que cresceu voltado pro centro, nao como cenario espalhado.
	body.visual_rotation_y_degrees = _facing(pos) + _rng.randf_range(-12.0, 12.0)
	add_child(body)
	body.position = pos
	_tint(body)

func _facing(pos: Vector3) -> float:
	if absf(pos.x) > absf(pos.z):
		return 90.0 if pos.x > 0.0 else 270.0
	return 0.0 if pos.z > 0.0 else 180.0

func _tint(body: Node3D) -> void:
	if facade_colors.is_empty():
		return
	var color: Color = facade_colors[_rng.randi() % facade_colors.size()]
	for mesh_inst in _all_meshes(body):
		for surface in range(mesh_inst.get_surface_override_material_count()):
			var base: Material = mesh_inst.mesh.surface_get_material(surface)
			var mat: StandardMaterial3D = base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()
			mat.albedo_color = color
			mesh_inst.set_surface_override_material(surface, mat)

func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh:
		result.append(node)
	for child in node.get_children():
		result.append_array(_all_meshes(child))
	return result

func _local_aabb(node: Node, accum: Transform3D) -> AABB:
	var t := accum
	if node is Node3D:
		t = accum * node.transform
	var result := AABB()
	var has := false
	if node is MeshInstance3D and node.mesh:
		result = t * node.get_aabb()
		has = true
	for child in node.get_children():
		var c := _local_aabb(child, t)
		if c.size != Vector3.ZERO:
			if not has:
				result = c
				has = true
			else:
				result = result.merge(c)
	return result
