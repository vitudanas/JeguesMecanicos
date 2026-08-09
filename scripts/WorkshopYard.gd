extends Node3D
## Enche o patio da oficina com tranqueira de oficina de verdade.
##
## O patio era uma laje de concreto nua na grama com cerca de um lado so — o
## cenario mais pobre do mapa, e justamente aquele pra onde o jogador mais
## volta. Aqui entram pilha de pneu, tambor de oleo, bancada, carrinho de
## ferramenta, cavalete, cone e luminaria de trabalho.
##
## Tudo montado com primitivas em codigo, como o mobiliario urbano
## (`StreetFurniture.gd`): mantem um estilo so e nao traz pacote novo.
##
## DUAS AREAS FICAM LIVRES, e o `tools/verify/yard_test.gd` cobra isso:
##   - o anel de trabalho em volta das vagas, senao o jogador nao alcanca os 4
##     pontos de gambiarra;
##   - o corredor de saida ao sul, senao o carro consertado nao sai do patio.
##
## O anel de trabalho nao e mais um retangulo escrito aqui: ele vem do
## `Workshop.clear_rect()`, que e a UNIAO das vagas de todos os niveis do patio.
## Escrito na mao, ele descrevia a vaga unica de antes — e prop plantado hoje no
## lugar de uma vaga futura viraria obstaculo assim que o jogador comprasse o
## upgrade, porque o cenario e montado uma vez so, no inicio da partida.

const WorkshopScript := preload("res://scenes/world/Workshop.gd")

## Corredor de saida: do fundo das vagas ate o vao da cerca.
const GATE_HALF := 6.0
const GATE_Z_MIN := 4.0

@export var rng_seed := 20260804

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = rng_seed
	_build()

func _mat(color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D,
		rot_y := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cyl(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _torus(inner: float, outer: float, pos: Vector3, mat: Material, parent: Node3D,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 14
	mesh.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## Impede que um prop caia na vaga ou no caminho de saida. Erra pro lado de
## deixar livre: prop no lugar errado aqui nao e enfeite feio, e o jogador sem
## conseguir montar ou sem conseguir sair.
func _blocked(pos: Vector3) -> bool:
	var vagas: Rect2 = WorkshopScript.clear_rect()
	if vagas.has_point(Vector2(pos.x, pos.z)):
		return true
	if absf(pos.x) < GATE_HALF and pos.z >= GATE_Z_MIN:
		return true
	return false

func _spawn(pos: Vector3, builder: Callable) -> void:
	if _blocked(pos):
		push_warning("WorkshopYard: prop em %s cairia na vaga ou na saida, pulado" % pos)
		return
	var holder := Node3D.new()
	add_child(holder)
	holder.position = pos
	holder.rotation.y = _rng.randf_range(0.0, TAU)
	builder.call(holder)

func _build() -> void:
	# Pneus velhos empilhados — o objeto que mais diz "oficina" de longe.
	for p: Vector3 in [Vector3(-6.8, 0, -2.5), Vector3(-8.5, 0, -5.0),
			Vector3(7.4, 0, -6.5), Vector3(-6.2, 0, -5.4)]:
		_spawn(p, _tire_stack)
	# Tambores de oleo.
	for p: Vector3 in [Vector3(5.8, 0, -6.8), Vector3(6.9, 0, -5.6),
			Vector3(-8.4, 0, -6.6)]:
		_spawn(p, _oil_drum)
	# Bancada e carrinho encostados no barracao.
	_spawn(Vector3(-3.2, 0, -7.4), _workbench)
	_spawn(Vector3(2.8, 0, -7.2), _tool_cart)
	# Cavaletes de apoio ATRAS da fileira de vagas (ficavam nas laterais, que e
	# justamente onde a terceira e a quarta vaga aparecem no patio nivel 3).
	for p: Vector3 in [Vector3(-7.9, 0, -3.4), Vector3(6.0, 0, -2.2)]:
		_spawn(p, _jack_stand)
	# Cones marcando o vao da cerca, FORA do corredor.
	for p: Vector3 in [Vector3(-6.9, 0, 8.4), Vector3(6.9, 0, 8.4)]:
		_spawn(p, _cone)
	# Luminarias nos CANTOS do patio, na linha da cerca. Ficavam em x = +-7.4,
	# que virou vaga; a primeira tentativa de mudanca (x = +-8.5, z = 6.4) so
	# trocou de defeito — a foto mostrou um poste plantado no meio da laje,
	# bem no arco que o carro faz do portao ate a vaga da ponta.
	for p: Vector3 in [Vector3(-9.8, 0, 7.8), Vector3(9.8, 0, 7.8)]:
		_spawn(p, _work_lamp)

	# Quadro de melhorias. Posicao escolhida a mao (e nao pelo `_spawn`, que
	# recusa qualquer coisa perto da vaga): fica FORA do anel de trabalho e do
	# corredor de saida, mas de frente pra quem chega rebocando — o jogador
	# precisa esbarrar nele pra descobrir que existe progressao.
	var board := StaticBody3D.new()
	board.name = "QuadroDeMelhorias"
	board.set_script(load("res://scripts/UpgradeBoard.gd"))
	board.position = Vector3(-9.6, 0.0, 4.8)
	board.rotation_degrees.y = 58.0
	add_child(board)

# ---------------------------------------------------------------- os objetos

func _tire_stack(root: Node3D) -> void:
	var rubber := _mat(Color(0.09, 0.09, 0.10), 0.95)
	var n := _rng.randi_range(3, 5)
	for i in range(n):
		# Cada pneu levemente torto: pilha perfeita nao existe em oficina.
		_torus(0.16, 0.36, Vector3(_rng.randf_range(-0.04, 0.04), 0.10 + float(i) * 0.17,
			_rng.randf_range(-0.04, 0.04)), rubber, root,
			Vector3(0.0, _rng.randf_range(0.0, TAU), _rng.randf_range(-0.05, 0.05)))

func _oil_drum(root: Node3D) -> void:
	var body := _mat(Color(0.20, 0.32, 0.24), 0.55, 0.5)
	if _rng.randf() < 0.4:
		body = _mat(Color(0.45, 0.24, 0.14), 0.85, 0.3)
	_cyl(0.29, 0.88, Vector3(0, 0.44, 0), body, root)
	for y: float in [0.26, 0.62]:
		_torus(0.28, 0.32, Vector3(0, y, 0), body, root)

func _workbench(root: Node3D) -> void:
	var wood := _mat(Color(0.42, 0.30, 0.19), 0.9)
	var steel := _mat(Color(0.42, 0.44, 0.47), 0.5, 0.7)
	_box(Vector3(2.4, 0.09, 0.8), Vector3(0, 0.92, 0), wood, root)
	for sx: float in [-1.05, 1.05]:
		for sz: float in [-0.3, 0.3]:
			_box(Vector3(0.09, 0.9, 0.09), Vector3(sx, 0.45, sz), steel, root)
	# Prateleira embaixo e tranqueira em cima.
	_box(Vector3(2.2, 0.06, 0.62), Vector3(0, 0.32, 0), wood, root)
	_box(Vector3(0.34, 0.22, 0.26), Vector3(-0.7, 1.07, 0.05),
		_mat(Color(0.75, 0.16, 0.14), 0.6), root)
	_cyl(0.06, 0.30, Vector3(0.5, 1.11, -0.1), steel, root,
		Vector3(0.0, 0.0, deg_to_rad(90.0)))

func _tool_cart(root: Node3D) -> void:
	var red := _mat(Color(0.66, 0.16, 0.13), 0.55, 0.3)
	var dark := _mat(Color(0.14, 0.14, 0.16), 0.7)
	_box(Vector3(0.8, 0.85, 0.55), Vector3(0, 0.52, 0), red, root)
	for y: float in [0.32, 0.55, 0.78]:
		_box(Vector3(0.82, 0.03, 0.02), Vector3(0, y, 0.28), dark, root)
	for sx: float in [-0.3, 0.3]:
		for sz: float in [-0.2, 0.2]:
			_torus(0.03, 0.08, Vector3(sx, 0.08, sz), dark, root,
				Vector3(0.0, 0.0, deg_to_rad(90.0)))

func _jack_stand(root: Node3D) -> void:
	var steel := _mat(Color(0.52, 0.42, 0.16), 0.6, 0.6)
	for sx: float in [-0.16, 0.16]:
		for sz: float in [-0.16, 0.16]:
			_box(Vector3(0.05, 0.5, 0.05), Vector3(sx, 0.25, sz), steel, root,
				0.0)
	_box(Vector3(0.42, 0.05, 0.42), Vector3(0, 0.05, 0), steel, root)
	_cyl(0.05, 0.34, Vector3(0, 0.62, 0), steel, root)

func _cone(root: Node3D) -> void:
	var orange := _mat(Color(0.85, 0.34, 0.08), 0.75)
	var white := _mat(Color(0.92, 0.92, 0.90), 0.75)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.20
	cone.height = 0.55
	cone.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.position = Vector3(0, 0.30, 0)
	mi.material_override = orange
	root.add_child(mi)
	_box(Vector3(0.34, 0.04, 0.34), Vector3(0, 0.02, 0), orange, root)
	_torus(0.11, 0.15, Vector3(0, 0.33, 0), white, root)

func _work_lamp(root: Node3D) -> void:
	var steel := _mat(Color(0.35, 0.36, 0.38), 0.5, 0.7)
	var glass := _mat(Color(0.95, 0.92, 0.72), 0.2)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.93, 0.70)
	glass.emission_energy_multiplier = 1.6
	_cyl(0.07, 3.2, Vector3(0, 1.6, 0), steel, root)
	_box(Vector3(0.5, 0.10, 0.30), Vector3(0.18, 3.22, 0), steel, root)
	_box(Vector3(0.34, 0.12, 0.24), Vector3(0.34, 3.12, 0), glass, root)
