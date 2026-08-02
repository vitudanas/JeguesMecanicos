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
@export var end_scene: PackedScene
@export var end_rotation_offset_degrees := 180.0  ## ajuste se a ponta nascer virada pro lado errado
@export var light_scene: PackedScene
@export var light_every_n_tiles := 3
@export var light_offset := 2.6
@export var exclude_points: Array[Vector3] = []  ## nao coloca tile perto desses pontos (ex: oficina, comprador)
@export var exclude_radius := 10.0

## O kit de rua do Kenney usado aqui e de rodovia (sem pecas de calcada/meio-fio
## de verdade), entao a calcada elevada e gerada por codigo: uma caixa rasa dos
## dois lados de cada trecho reto/ponta, com colisao propria (o carro sobe nela
## e sacode a gambiarra, igual um perfil de rua de verdade).
@export var curb_enabled := true
@export var curb_height := 0.18
@export var sidewalk_width := 1.2
@export var road_half_width := 2.4  ## distancia do centro da rua ate o meio-fio
@export var curb_color := Color(0.72, 0.7, 0.65)

var _curb_mesh: BoxMesh
var _curb_material: StandardMaterial3D

func _ready() -> void:
	_build()

func _build() -> void:
	if streets_x.is_empty() or streets_z.is_empty():
		return
	if curb_enabled:
		_ensure_curb_resources()
	for row_z in streets_x:
		for col_x in streets_z:
			_place(crossroad_scene, Vector3(col_x, 0.03, row_z), 0.0)

	var min_x: float = streets_z[0] - extent
	var max_x: float = streets_z[streets_z.size() - 1] + extent
	for row_z in streets_x:
		_build_run(min_x, max_x, streets_z, func(p): return Vector3(p, 0.03, row_z), 0.0, func(p, side): return Vector3(p, 0.03, row_z + side * light_offset))

	var min_z: float = streets_x[0] - extent
	var max_z: float = streets_x[streets_x.size() - 1] + extent
	for col_x in streets_z:
		_build_run(min_z, max_z, streets_x, func(p): return Vector3(col_x, 0.03, p), 90.0, func(p, side): return Vector3(col_x + side * light_offset, 0.03, p))

func _build_run(min_v: float, max_v: float, cross_values: Array[float], pos_fn: Callable, rot: float, light_pos_fn: Callable) -> void:
	var positions: Array[float] = []
	var v := min_v + tile_size / 2.0
	while v < max_v:
		positions.append(v)
		v += tile_size
	var tile_count := 0
	for i in range(positions.size()):
		var p: float = positions[i]
		if _near_any(cross_values, p, tile_size * 0.6):
			continue
		var is_first_run_tile := i == 0
		var is_last_run_tile := i == positions.size() - 1
		if is_first_run_tile:
			_place(end_scene, pos_fn.call(p), rot + end_rotation_offset_degrees)
			_place_curb_pair(pos_fn.call(p), rot)
		elif is_last_run_tile:
			_place(end_scene, pos_fn.call(p), rot)
			_place_curb_pair(pos_fn.call(p), rot)
		else:
			_place(straight_scene, pos_fn.call(p), rot)
			_place_curb_pair(pos_fn.call(p), rot)
			tile_count += 1
			if tile_count % light_every_n_tiles == 0:
				_place(light_scene, light_pos_fn.call(p, 1.0), rot, tile_size * 0.5)
				_place(light_scene, light_pos_fn.call(p, -1.0), rot + 180.0, tile_size * 0.5)

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
		inst.scale = Vector3.ONE * (custom_scale if custom_scale > 0.0 else tile_size)
		inst.position = pos
		inst.rotation_degrees.y = rot_y_deg

func _is_excluded(pos: Vector3) -> bool:
	for excl in exclude_points:
		if Vector2(pos.x, pos.z).distance_to(Vector2(excl.x, excl.z)) < exclude_radius:
			return true
	return false

func _ensure_curb_resources() -> void:
	_curb_mesh = BoxMesh.new()
	_curb_mesh.size = Vector3(tile_size, curb_height, sidewalk_width)
	_curb_material = StandardMaterial3D.new()
	_curb_material.albedo_color = curb_color
	_curb_material.roughness = 0.9

func _place_curb_pair(center: Vector3, rot_y_deg: float) -> void:
	if not curb_enabled or _is_excluded(center):
		return
	var offset := road_half_width + sidewalk_width * 0.5
	for side in [1.0, -1.0]:
		var local_offset := Vector3(0.0, curb_height * 0.5, side * offset)
		var world_offset: Vector3 = local_offset.rotated(Vector3.UP, deg_to_rad(rot_y_deg))
		var body := StaticBody3D.new()
		add_child(body)
		body.position = Vector3(center.x, 0.0, center.z) + world_offset
		body.rotation_degrees.y = rot_y_deg

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = _curb_mesh
		mesh_inst.set_surface_override_material(0, _curb_material)
		body.add_child(mesh_inst)

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = _curb_mesh.size
		shape.shape = box
		body.add_child(shape)
