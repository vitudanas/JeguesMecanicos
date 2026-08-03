class_name StreetFurniture
extends RefCounted
## Mobiliario urbano que o kit do Kenney nao tem: semaforo, ponto de onibus e
## banco de praca.
##
## Sao montados com primitivas em codigo, de proposito, em vez de baixar outro
## pacote: a cidade e 100% Kenney por decisao de projeto (ver changelog
## 2026-08-02), e misturar dois estilos lado a lado foi exatamente o problema
## que aquele redesenho corrigiu. Mesma tecnica ja usada pro meio-fio em
## CityStreets.gd e pra sucata em ScrapyardCluster.gd.
##
## Escala do mundo: o jogador tem 1.8 de altura e a pista tem 4.8 de largura
## (road_half_width 2.4 dos dois lados), entao as medidas abaixo estao em
## metros de verdade.

## Malhas e materiais sao criados uma vez e compartilhados por todas as
## instancias — sao centenas de props na cidade, e um material novo por prop
## seria desperdicio de memoria e de estado de render.
static var _cache: Dictionary = {}

const METAL := Color(0.28, 0.30, 0.33)
const DARK := Color(0.16, 0.17, 0.19)
const GLASS := Color(0.62, 0.74, 0.80, 0.55)
const CONCRETE := Color(0.72, 0.70, 0.65)
const WOOD := Color(0.45, 0.32, 0.20)

static func _material(key: String, color: Color, emissive := false) -> StandardMaterial3D:
	var cache_key := "mat_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.6
	_cache[cache_key] = mat
	return mat

static func _box_mesh(key: String, size: Vector3) -> BoxMesh:
	var cache_key := "box_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var mesh := BoxMesh.new()
	mesh.size = size
	_cache[cache_key] = mesh
	return mesh

static func _cylinder_mesh(key: String, radius: float, height: float) -> CylinderMesh:
	var cache_key := "cyl_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	_cache[cache_key] = mesh
	return mesh

static func _piece(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.set_surface_override_material(0, material)
	inst.position = pos
	parent.add_child(inst)
	return inst

## Semaforo: poste com o cabecote virado pra rua. `facing_degrees` gira o
## conjunto, entao quem chama aponta ele pra pista que ele controla.
static func traffic_light() -> Node3D:
	var root := Node3D.new()
	root.name = "Semaforo"
	# Grupo em vez de nome: irmaos de nome repetido viram "@Node3D@N" quando o
	# pai ja tem um filho com aquele nome, entao filtrar por nome nao acha os
	# props depois (foi assim que uma verificacao minha "achou" so 2 semaforos).
	root.add_to_group("street_furniture")
	_piece(root, _cylinder_mesh("tl_pole", 0.07, 3.4), _material("metal", METAL),
			Vector3(0.0, 1.7, 0.0))
	# Braco curto pro cabecote ficar sobre a calcada, nao colado no poste.
	_piece(root, _box_mesh("tl_arm", Vector3(0.5, 0.09, 0.09)), _material("metal", METAL),
			Vector3(0.25, 3.3, 0.0))
	_piece(root, _box_mesh("tl_head", Vector3(0.30, 0.80, 0.26)), _material("dark", DARK),
			Vector3(0.5, 2.95, 0.0))
	var lamps := [
		["red", Color(0.95, 0.15, 0.12), 3.20],
		["yellow", Color(0.98, 0.78, 0.15), 2.95],
		["green", Color(0.25, 0.85, 0.35), 2.70],
	]
	for lamp: Array in lamps:
		_piece(root, _box_mesh("tl_lamp", Vector3(0.16, 0.16, 0.06)),
				_material(lamp[0], lamp[1], true), Vector3(0.5, lamp[2], 0.14))
	return root


## Ponto de onibus: cobertura, fundo de vidro, banco e placa. O eixo X e a
## largura (fica paralelo a rua) e o -Z aponta pra pista.
static func bus_stop() -> Node3D:
	var root := Node3D.new()
	root.name = "PontoDeOnibus"
	root.add_to_group("street_furniture")
	var metal := _material("metal", METAL)
	_piece(root, _box_mesh("bs_roof", Vector3(3.2, 0.12, 1.3)), metal,
			Vector3(0.0, 2.45, 0.0))
	for side in [-1.0, 1.0]:
		_piece(root, _box_mesh("bs_post", Vector3(0.10, 2.4, 0.10)), metal,
				Vector3(side * 1.5, 1.2, 0.55))
	_piece(root, _box_mesh("bs_back", Vector3(3.1, 1.9, 0.06)), _material("glass", GLASS),
			Vector3(0.0, 1.35, 0.60))
	_piece(root, _box_mesh("bs_bench", Vector3(2.6, 0.10, 0.42)), _material("wood", WOOD),
			Vector3(0.0, 0.52, 0.42))
	_piece(root, _box_mesh("bs_bench_leg", Vector3(2.6, 0.42, 0.08)), metal,
			Vector3(0.0, 0.26, 0.60))
	# Placa na ponta, virada pra quem vem pela calcada.
	_piece(root, _cylinder_mesh("bs_sign_pole", 0.05, 2.6), metal,
			Vector3(1.85, 1.3, 0.0))
	_piece(root, _box_mesh("bs_sign", Vector3(0.5, 0.36, 0.05)),
			_material("sign", Color(0.20, 0.42, 0.72)), Vector3(1.85, 2.45, 0.0))
	return root


static func bench() -> Node3D:
	var root := Node3D.new()
	root.name = "Banco"
	_piece(root, _box_mesh("bench_seat", Vector3(1.6, 0.08, 0.45)), _material("wood", WOOD),
			Vector3(0.0, 0.45, 0.0))
	_piece(root, _box_mesh("bench_back", Vector3(1.6, 0.40, 0.07)), _material("wood", WOOD),
			Vector3(0.0, 0.70, -0.20))
	for side in [-1.0, 1.0]:
		_piece(root, _box_mesh("bench_leg", Vector3(0.08, 0.45, 0.42)),
				_material("metal", METAL), Vector3(side * 0.7, 0.22, 0.0))
	return root


## Bomba de combustivel do posto.
static func fuel_pump() -> Node3D:
	var root := Node3D.new()
	root.name = "Bomba"
	_piece(root, _box_mesh("pump_base", Vector3(1.1, 0.20, 0.7)), _material("concrete", CONCRETE),
			Vector3(0.0, 0.10, 0.0))
	_piece(root, _box_mesh("pump_body", Vector3(0.55, 1.5, 0.45)),
			_material("pump", Color(0.86, 0.30, 0.22)), Vector3(0.0, 0.95, 0.0))
	_piece(root, _box_mesh("pump_screen", Vector3(0.36, 0.30, 0.06)), _material("dark", DARK),
			Vector3(0.0, 1.35, 0.24))
	return root


## Caixa d'agua sobre pes — o prop de telhado que mais quebra a silhueta de
## caixa vista de longe (que e o que ainda faz a cidade ler como maquete,
## mesmo com as fachadas ja texturizadas).
static func water_tank() -> Node3D:
	var root := Node3D.new()
	root.name = "CaixaDagua"
	root.add_to_group("rooftop_prop")
	var metal := _material("metal", METAL)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_piece(root, _box_mesh("tank_leg", Vector3(0.12, 1.5, 0.12)), metal,
					Vector3(sx * 0.55, 0.75, sz * 0.55))
	_piece(root, _cylinder_mesh("tank_body", 0.85, 1.5), _material("concrete", CONCRETE),
			Vector3(0.0, 2.25, 0.0))
	_piece(root, _cylinder_mesh("tank_lid", 0.35, 0.2), metal, Vector3(0.0, 3.1, 0.0))
	return root

## Condensadora de ar condicionado.
static func ac_unit() -> Node3D:
	var root := Node3D.new()
	root.name = "ArCondicionado"
	root.add_to_group("rooftop_prop")
	var metal := _material("metal", METAL)
	_piece(root, _box_mesh("ac_body", Vector3(1.3, 0.9, 0.9)), metal, Vector3(0.0, 0.45, 0.0))
	_piece(root, _box_mesh("ac_grille", Vector3(1.0, 0.6, 0.05)), _material("dark", DARK),
			Vector3(0.0, 0.5, 0.47))
	_piece(root, _box_mesh("ac_base", Vector3(1.5, 0.12, 1.1)), _material("dark", DARK),
			Vector3(0.0, 0.06, 0.0))
	return root

## Antena/mastro: da verticalidade fina no topo, que nenhum modelo do kit tem.
static func antenna() -> Node3D:
	var root := Node3D.new()
	root.name = "Antena"
	root.add_to_group("rooftop_prop")
	var metal := _material("metal", METAL)
	_piece(root, _cylinder_mesh("ant_mast", 0.06, 3.6), metal, Vector3(0.0, 1.8, 0.0))
	for h in [2.4, 2.9, 3.3]:
		_piece(root, _box_mesh("ant_bar", Vector3(0.9, 0.05, 0.05)), metal, Vector3(0.0, h, 0.0))
	_piece(root, _box_mesh("ant_base", Vector3(0.5, 0.14, 0.5)), _material("dark", DARK),
			Vector3(0.0, 0.07, 0.0))
	return root

## Chao plano (asfalto de estacionamento, grama de praca, concreto do posto).
## Fica 1cm acima do chao do mundo pra nao brigar com ele por z-fighting.
static func ground_patch(size: Vector2, color: Color, key: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.08, size.y)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.set_surface_override_material(0, _material(key, color))
	inst.position.y = 0.04
	return inst
