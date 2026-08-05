extends Node3D
## Gera uma malha viaria em grade (tipo Manhattan) por cima do chao
## fisico existente, a partir de duas listas de posicoes de rua (retas
## nos eixos X e Z). Cada cruzamento vira um tile de cruzamento, cada
## trecho entre cruzamentos e preenchido com tiles retos, e as pontas
## soltas das ruas (nas bordas do mapa) recebem uma peca de acabamento
## em vez de simplesmente cortar no meio do nada. Postes de luz nascem
## sozinhos ao lado de cada trecho reto, alternando os lados. O tile
## viario em si e so decoracao visual (colisao do chao continua sendo o
## Ground de Town.tscn); ja o meio-fio/calcada tem colisao propria, ver
## _place_curb_pair().

@export var streets_x: Array[float] = []  ## posicoes em Z das ruas que correm no eixo X (leste-oeste)
@export var streets_z: Array[float] = []  ## posicoes em X das ruas que correm no eixo Z (norte-sul)
@export var extent := 60.0                ## quanto as pontas das ruas se estendem alem da ultima rua perpendicular
@export var tile_size := 6.0
@export var crossroad_scene: PackedScene
@export var straight_scene: PackedScene
## Tile com faixa de pedestre. Usado nas aproximacoes de cada cruzamento (o
## trecho reto continua nos demais), entao a travessia nasce onde ela faria
## sentido numa cidade de verdade.
@export var crossing_scene: PackedScene
@export var end_scene: PackedScene
@export var end_rotation_offset_degrees := 180.0  ## ajuste se a ponta nascer virada pro lado errado
@export var light_scene: PackedScene
@export var light_every_n_tiles := 3
@export var light_offset := 2.6
@export var exclude_points: Array[Vector3] = []  ## nao coloca tile perto desses pontos (ex: oficina, comprador)
@export var exclude_radius := 10.0

## Mobiliario urbano (semaforo e ponto de onibus). O kit do Kenney nao tem
## nenhum dos dois, entao sao montados com primitivas — ver StreetFurniture.gd.
@export var traffic_lights_enabled := true
## Semaforo so nos cruzamentos "principais": um a cada N ruas em cada eixo.
## Em todos os cruzamentos vira poluicao visual (e muito no pra desenhar).
@export var traffic_light_street_step := 2
@export var bus_stops_enabled := true
@export var bus_stop_every_n_tiles := 9
## Distancia da linha de centro da rua ate o prop. Cai na calcada, que vai de
## road_half_width (2.4) ate a fachada (3.8).
@export var furniture_offset := 3.05

## Trechos de rua diagonal (fora da grade ortogonal acima), cada um definido por um
## par inicio/fim nas mesmas duas listas (indices correspondentes). Pensados pra
## caber dentro de um quarteirao vazio da grade, sem cruzar ruas existentes — nao ha
## peca de cruzamento diagonal-ortogonal, entao evitar sobrepor as duas malhas.
@export var diagonal_starts: Array[Vector3] = []
@export var diagonal_ends: Array[Vector3] = []

## O kit de rua do Kenney usado aqui e de rodovia (sem pecas de calcada/meio-fio
## de verdade), entao a calcada elevada e gerada por codigo: uma caixa rasa dos
## dois lados de cada trecho reto/ponta, com colisao propria (o carro sobe nela
## e sacode a gambiarra, igual um perfil de rua de verdade).
@export var curb_enabled := true
@export var curb_height := 0.18
@export var sidewalk_width := 1.2
@export var road_half_width := 2.4  ## distancia do centro da rua ate o meio-fio
## Concreto de calcada de verdade reflete ~40% da luz, nao 72%. Com o valor
## antigo a calcada estourava de branco ao lado do asfalto e virava o elemento
## mais claro da rua — que nao e o caso em cidade nenhuma.
@export var curb_color := Color(0.5, 0.49, 0.46)
## Asfalto e concreto com material PBR em vez da cor chapada do kit (ver
## CitySurface.gd). Chave pra dar pra comparar os dois lado a lado.
@export var use_pbr_surface := true
@export var asphalt_texture_size := 5.0
## Altura do TOPO do asfalto. O tile do kit e uma laje: com o no em y=0.03 e
## escala 7.5 o topo ficava em 0.18, ou seja 18cm ACIMA do chao fisico (o
## Ground vai ate y=0). Carro nenhum sobe nisso — eles apoiam no chao fisico e
## apareciam afundados na rua. Aqui o tile e baixado pelo proprio topo medido,
## entao o asfalto encosta no chao e a calcada (0.18) volta a ser um degrau de
## verdade, como o projeto sempre quis.
@export var road_surface_y := 0.02

## Altura da PISTA de cada tile em unidades locais, medida uma vez por modelo.
var _road_surface_local: Dictionary = {}

var _curb_mesh: BoxMesh
var _curb_corner_mesh: BoxMesh
# Material, nao StandardMaterial3D: com o acabamento PBR ligado a calcada
# usa ShaderMaterial (ver CitySurface.gd).
var _curb_material: Material

func _ready() -> void:
	_build()

func _build() -> void:
	if streets_x.is_empty() or streets_z.is_empty():
		return
	if curb_enabled:
		_ensure_curb_resources()
	for j in range(streets_x.size()):
		for i in range(streets_z.size()):
			var center := Vector3(streets_z[i], 0.03, streets_x[j])
			_place(crossroad_scene, center, 0.0)
			_place_intersection_curbs(center)
			var step: int = maxi(traffic_light_street_step, 1)
			if traffic_lights_enabled and i % step == 0 and j % step == 0:
				_place_traffic_lights(center)

	var min_x: float = streets_z[0] - extent
	var max_x: float = streets_z[streets_z.size() - 1] + extent
	for row_z in streets_x:
		_build_run(min_x, max_x, streets_z, func(p): return Vector3(p, 0.03, row_z), 0.0, func(p, side, dist): return Vector3(p, 0.03, row_z + side * dist))

	var min_z: float = streets_x[0] - extent
	var max_z: float = streets_x[streets_x.size() - 1] + extent
	for col_x in streets_z:
		_build_run(min_z, max_z, streets_x, func(p): return Vector3(col_x, 0.03, p), 90.0, func(p, side, dist): return Vector3(col_x + side * dist, 0.03, p))

	for i in range(min(diagonal_starts.size(), diagonal_ends.size())):
		_build_diagonal(diagonal_starts[i], diagonal_ends[i])

func _build_diagonal(start: Vector3, end: Vector3) -> void:
	var delta := end - start
	var length := Vector2(delta.x, delta.z).length()
	if length < tile_size * 2.0:
		return
	var dir := Vector3(delta.x, 0.0, delta.z).normalized()
	var rot_y_deg := rad_to_deg(atan2(-dir.z, dir.x))
	var tile_count := int(length / tile_size)
	var last_index := tile_count - 1
	var lights_placed := 0
	for i in range(tile_count):
		var dist := tile_size * 0.5 + i * tile_size
		var center: Vector3 = start + dir * dist
		center.y = 0.03
		if i == 0:
			_place(end_scene, center, rot_y_deg + end_rotation_offset_degrees)
		elif i == last_index:
			_place(end_scene, center, rot_y_deg)
		else:
			_place(straight_scene, center, rot_y_deg)
			lights_placed += 1
			if lights_placed % light_every_n_tiles == 0:
				_place(light_scene, center + _side_offset(rot_y_deg, 1.0, light_offset), rot_y_deg, tile_size * 0.5)
				_place(light_scene, center + _side_offset(rot_y_deg, -1.0, light_offset), rot_y_deg + 180.0, tile_size * 0.5)
		_place_curb_pair(center, rot_y_deg)

func _side_offset(rot_y_deg: float, side: float, dist: float) -> Vector3:
	return Vector3(0.0, 0.0, side * dist).rotated(Vector3.UP, deg_to_rad(rot_y_deg))

func _build_run(min_v: float, max_v: float, cross_values: Array[float], pos_fn: Callable, rot: float, light_pos_fn: Callable) -> void:
	# As pecas sao ancoradas NA GRADE (multiplos de tile_size a partir do
	# primeiro cruzamento), nao no comeco do trecho. Comecando em
	# min_v + tile/2 as pecas ficavam defasadas em relacao aos cruzamentos e
	# sobrava um vao de meia peca em CADA aproximacao de esquina — a rua
	# parecia cortada perto de toda intersecao. Por isso streets_x/streets_z
	# tambem precisam estar espacados num multiplo de tile_size.
	var anchor: float = cross_values[0]
	var positions: Array[float] = []
	var v := anchor - ceilf((anchor - min_v) / tile_size) * tile_size
	while v <= max_v + 0.01:
		positions.append(v)
		v += tile_size
	var first_cross: float = cross_values[0]
	var last_cross: float = cross_values[cross_values.size() - 1]
	var tile_count := 0
	var stop_side := 1.0
	for i in range(positions.size()):
		var p: float = positions[i]
		if _near_any(cross_values, p, tile_size * 0.6):
			continue
		# Ponta arredondada so no rabicho que sai da grade. Dentro dela toda
		# peca tem continuidade dos dois lados, e uma tampa ali seria um
		# buraco no meio da rua.
		var in_tail := p < first_cross - 0.01 or p > last_cross + 0.01
		var is_first_run_tile := in_tail and i == 0
		var is_last_run_tile := in_tail and i == positions.size() - 1
		if is_first_run_tile:
			_place(end_scene, pos_fn.call(p), rot + end_rotation_offset_degrees)
			_place_curb_pair(pos_fn.call(p), rot)
		elif is_last_run_tile:
			_place(end_scene, pos_fn.call(p), rot)
			_place_curb_pair(pos_fn.call(p), rot)
		else:
			# Aproximacao de cruzamento ganha faixa de pedestre; o resto do
			# trecho continua reto. O limiar tem que ser MAIOR que um tile: as
			# pecas sao ancoradas na grade, entao a vizinha do cruzamento fica a
			# exatamente tile_size dele — com o 0.95 que estava aqui a condicao
			# nunca era verdadeira e a faixa de pedestre NUNCA nascia (censo
			# acusou 0 tiles de road-crossing na cidade inteira).
			var tile_scene := straight_scene
			if crossing_scene != null and _near_any(cross_values, p, tile_size * 1.05):
				tile_scene = crossing_scene
			_place(tile_scene, pos_fn.call(p), rot)
			_place_curb_pair(pos_fn.call(p), rot)
			tile_count += 1
			if tile_count % light_every_n_tiles == 0:
				_place(light_scene, light_pos_fn.call(p, 1.0, light_offset), rot, tile_size * 0.5)
				_place(light_scene, light_pos_fn.call(p, -1.0, light_offset), rot + 180.0, tile_size * 0.5)
			if bus_stops_enabled and tile_scene == straight_scene \
					and tile_count % bus_stop_every_n_tiles == 0:
				_place_bus_stop(light_pos_fn.call(p, stop_side, furniture_offset), rot, stop_side)
				stop_side = -stop_side

func _near_any(values: Array[float], v: float, threshold: float) -> bool:
	for other in values:
		if absf(v - other) < threshold:
			return true
	return false

func _place(scene: PackedScene, pos: Vector3, rot_y_deg: float, custom_scale := -1.0) -> void:
	if scene == null:
		return
	if _is_excluded(pos):
		return
	var inst := scene.instantiate()
	add_child(inst)
	if inst is Node3D:
		var node_scale: float = custom_scale if custom_scale > 0.0 else tile_size
		# A MEDIDA VEM ANTES DA ESCALA: _local_aabb ja aplica a transformada do
		# proprio no, entao medir depois de escalar devolve o topo JA escalado —
		# multiplicar por node_scale de novo elevava o desconto ao quadrado e
		# enterrava a rua inteira 1,1m no chao (a cidade ficou sem asfalto).
		if scene.resource_path.contains("/road-"):
			pos.y = road_surface_y - _tile_surface_local(scene, inst) * node_scale
		inst.scale = Vector3.ONE * node_scale
		inst.position = pos
		inst.rotation_degrees.y = rot_y_deg
		# So o asfalto: o poste de luz e outra coisa e ficaria com grao de rua.
		if use_pbr_surface and scene.resource_path.contains("/road-"):
			# O triplanar amostra por POSICAO DE MUNDO, entao o tamanho da
			# textura independe da escala do no — nao ha o que compensar aqui.
			CitySurface.apply(inst, Color.WHITE, "asfalto", asphalt_texture_size, 0.7, 0.5)

## Altura da PISTA do tile, em unidades locais.
##
## NAO e o topo da caixa: o kit e de RODOVIA, e o ponto mais alto do tile e o
## acostamento levantado da borda (medido no road-straight: 24 vertices em
## y=0.020 contra 36 em y=0.010). Alinhar pelo topo enterrava a pista de
## verdade abaixo do chao e a cidade ficava com rua de grama, sobrando so as
## bordas aparecendo.
##
## A pista e o plano horizontal com MAIS vertices — o unico que cobre o tile
## inteiro.
func _tile_surface_local(scene: PackedScene, inst: Node3D) -> float:
	var key := scene.resource_path
	if _road_surface_local.has(key):
		return _road_surface_local[key]
	var histogram := {}
	_collect_heights(inst, Transform3D.IDENTITY, histogram)
	var best := 0.0
	var best_count := -1
	for y: float in histogram:
		if int(histogram[y]) > best_count:
			best_count = histogram[y]
			best = y
	_road_surface_local[key] = best
	return best

func _collect_heights(node: Node, accum: Transform3D, histogram: Dictionary) -> void:
	var t := accum
	if node is Node3D:
		t = accum * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s in range(mesh.get_surface_count()):
			var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var y := snappedf((t * v).y, 0.002)
				histogram[y] = int(histogram.get(y, 0)) + 1
	for child in node.get_children():
		_collect_heights(child, t, histogram)

func _local_aabb(node: Node, accum: Transform3D) -> AABB:
	var t := accum
	if node is Node3D:
		t = accum * (node as Node3D).transform
	var result := AABB()
	var has := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result = t * (node as MeshInstance3D).get_aabb()
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

func _is_excluded(pos: Vector3) -> bool:
	for excl in exclude_points:
		if Vector2(pos.x, pos.z).distance_to(Vector2(excl.x, excl.z)) < exclude_radius:
			return true
	return false

func _ensure_curb_resources() -> void:
	_curb_mesh = BoxMesh.new()
	_curb_mesh.size = Vector3(tile_size, curb_height, sidewalk_width)
	_curb_corner_mesh = BoxMesh.new()
	_curb_corner_mesh.size = Vector3(sidewalk_width, curb_height, sidewalk_width)
	if use_pbr_surface:
		# Calcada de concreto de verdade. Sem atlas: o shader cai pro branco e
		# a cor vem so do tint, que e o que a caixa ja usava.
		_curb_material = CitySurface.make(null, curb_color, "concreto", 1.6, 0.8, 0.5)
	else:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = curb_color
		flat.roughness = 0.9
		_curb_material = flat

func _place_curb_pair(center: Vector3, rot_y_deg: float) -> void:
	if not curb_enabled or _is_excluded(center):
		return
	var offset := road_half_width + sidewalk_width * 0.5
	for side in [1.0, -1.0]:
		var world_offset := _side_offset(rot_y_deg, side, offset)
		_spawn_curb_box(Vector3(center.x, 0.0, center.z) + world_offset, rot_y_deg, _curb_mesh)

## Preenche os 4 cantos de cada cruzamento com um bloco de calcada, fechando
## visualmente o "anel" que as guias das retas/diagonais deixam em aberto perto
## dos cruzamentos (_near_any em _build_run/_build_diagonal pula as guias bem
## perto do centro do cruzamento).
func _place_intersection_curbs(center: Vector3) -> void:
	if not curb_enabled or _is_excluded(center):
		return
	var offset := road_half_width + sidewalk_width * 0.5
	for side_x in [1.0, -1.0]:
		for side_z in [1.0, -1.0]:
			var corner := Vector3(center.x + side_x * offset, 0.0, center.z + side_z * offset)
			_spawn_curb_box(corner, 0.0, _curb_corner_mesh)

## Dois semaforos em cantos opostos do cruzamento, cada um virado pra pista que
## ele controla. Ficam sobre o bloco de calcada do canto (mesmo offset de
## _place_intersection_curbs), nao no meio da pista.
func _place_traffic_lights(center: Vector3) -> void:
	if _is_excluded(center):
		return
	var offset := road_half_width + sidewalk_width * 0.5
	for corner: Array in [[-1.0, -1.0, 0.0], [1.0, 1.0, 180.0]]:
		var light := StreetFurniture.traffic_light()
		add_child(light)
		light.position = Vector3(center.x + corner[0] * offset, 0.0, center.z + corner[1] * offset)
		light.rotation_degrees.y = corner[2]

## Ponto de onibus na calcada, de costas pra rua. `side` diz de que lado do
## trecho ele esta, e a rotacao sai dai — o fundo do abrigo tem que apontar pra
## fora da pista, senao o vidro fica entre o banco e o meio-fio.
func _place_bus_stop(pos: Vector3, rot_y_deg: float, side: float) -> void:
	if _is_excluded(pos):
		return
	var outward := _side_offset(rot_y_deg, side, 1.0)
	var stop := StreetFurniture.bus_stop()
	add_child(stop)
	stop.position = Vector3(pos.x, 0.0, pos.z)
	stop.rotation_degrees.y = rad_to_deg(atan2(outward.x, outward.z))

func _spawn_curb_box(pos: Vector3, rot_y_deg: float, mesh: BoxMesh) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = Vector3(pos.x, curb_height * 0.5, pos.z)
	body.rotation_degrees.y = rot_y_deg

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.set_surface_override_material(0, _curb_material)
	body.add_child(mesh_inst)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	body.add_child(shape)
