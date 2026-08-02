extends Node3D
## Gera uma malha viaria em grade (tipo Manhattan) por cima do chao
## fisico existente, a partir de duas listas de posicoes de rua (retas
## nos eixos X e Z). Cada cruzamento vira um tile de cruzamento; cada
## trecho entre cruzamentos e preenchido com tiles retos. So decoracao
## visual — a colisao continua sendo o Ground de Town.tscn.

@export var streets_x: Array[float] = []  ## posicoes em Z das ruas que correm no eixo X (leste-oeste)
@export var streets_z: Array[float] = []  ## posicoes em X das ruas que correm no eixo Z (norte-sul)
@export var extent := 60.0                ## quanto as pontas das ruas se estendem alem da ultima rua perpendicular
@export var tile_size := 6.0
@export var crossroad_scene: PackedScene
@export var straight_scene: PackedScene
@export var exclude_points: Array[Vector3] = []  ## nao coloca tile perto desses pontos (ex: oficina, comprador)
@export var exclude_radius := 10.0

func _ready() -> void:
	_build()

func _build() -> void:
	if streets_x.is_empty() or streets_z.is_empty():
		return
	for row_z in streets_x:
		for col_x in streets_z:
			_place(crossroad_scene, Vector3(col_x, 0.03, row_z), 0.0)

	var min_x: float = streets_z[0] - extent
	var max_x: float = streets_z[streets_z.size() - 1] + extent
	for row_z in streets_x:
		var x := min_x + tile_size / 2.0
		while x < max_x:
			if not _near_any(streets_z, x, tile_size * 0.6):
				_place(straight_scene, Vector3(x, 0.03, row_z), 0.0)
			x += tile_size

	var min_z: float = streets_x[0] - extent
	var max_z: float = streets_x[streets_x.size() - 1] + extent
	for col_x in streets_z:
		var z := min_z + tile_size / 2.0
		while z < max_z:
			if not _near_any(streets_x, z, tile_size * 0.6):
				_place(straight_scene, Vector3(col_x, 0.03, z), 90.0)
			z += tile_size

func _near_any(values: Array[float], v: float, threshold: float) -> bool:
	for other in values:
		if absf(v - other) < threshold:
			return true
	return false

func _place(scene: PackedScene, pos: Vector3, rot_y_deg: float) -> void:
	if scene == null:
		return
	for excl in exclude_points:
		if Vector2(pos.x, pos.z).distance_to(Vector2(excl.x, excl.z)) < exclude_radius:
			return
	var inst := scene.instantiate()
	add_child(inst)
	if inst is Node3D:
		inst.scale = Vector3.ONE * tile_size
		inst.position = pos
		inst.rotation_degrees.y = rot_y_deg
