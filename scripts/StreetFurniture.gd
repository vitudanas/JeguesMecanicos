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
	root.add_to_group("semaforo")
	# Poste de 5,2 m com BRACO sobre a pista, e nao um postinho de 3,4 m na
	# calcada. A rua tem 11,4 m de pista desde que foi alargada (2026-08-09), e
	# em rua desse porte o cabecote fica pendurado sobre as faixas — na calcada
	# ele some atras do carro parado e a rua le como viela larga.
	_piece(root, _cylinder_mesh("tl_pole", 0.10, 5.2), _material("metal", METAL),
			Vector3(0.0, 2.6, 0.0))
	# Braco projetado: alcanca a primeira faixa de rolamento.
	_piece(root, _box_mesh("tl_arm", Vector3(3.2, 0.12, 0.12)), _material("metal", METAL),
			Vector3(1.6, 5.05, 0.0))
	# Cabecote principal, pendurado na ponta do braco.
	_piece(root, _box_mesh("tl_head", Vector3(0.34, 1.00, 0.30)), _material("dark", DARK),
			Vector3(3.0, 4.45, 0.0))
	var lamps := [
		["red", Color(0.95, 0.15, 0.12), 4.78],
		["yellow", Color(0.98, 0.78, 0.15), 4.45],
		["green", Color(0.25, 0.85, 0.35), 4.12],
	]
	for lamp: Array in lamps:
		_piece(root, _box_mesh("tl_lamp", Vector3(0.20, 0.20, 0.07)),
				_material(lamp[0], lamp[1], true), Vector3(3.0, lamp[2], 0.16))
	# Repetidor na altura do olho, no proprio poste: e o que o pedestre ve, e o
	# que o motorista parado na faixa de retencao ainda enxerga.
	_piece(root, _box_mesh("tl_head_low", Vector3(0.26, 0.76, 0.24)), _material("dark", DARK),
			Vector3(0.0, 2.95, 0.20))
	for lamp: Array in lamps:
		_piece(root, _box_mesh("tl_lamp_low", Vector3(0.15, 0.15, 0.06)),
				_material(lamp[0], lamp[1], true),
				Vector3(0.0, 2.95 + (float(lamp[2]) - 4.45) * 0.72, 0.33))
	return root


## Ponto de onibus: cobertura, fundo de vidro, banco e placa. O eixo X e a
## largura (fica paralelo a rua) e o -Z aponta pra pista.
static func bus_stop() -> Node3D:
	var root := Node3D.new()
	root.name = "PontoDeOnibus"
	root.add_to_group("street_furniture")
	root.add_to_group("ponto_onibus")
	var metal := _material("metal", METAL)
	# Abrigo de 4,8 x 1,9 m e 2,9 m de altura. O anterior tinha 3,2 x 1,3 m —
	# abrigo de verdade cobre a fila de quem espera, e numa calcada de 3,5 m um
	# abrigo estreito le como ponto de taxi.
	_piece(root, _box_mesh("bs_roof", Vector3(4.8, 0.14, 1.9)), metal,
			Vector3(0.0, 2.90, 0.0))
	for side in [-1.0, 1.0]:
		_piece(root, _box_mesh("bs_post", Vector3(0.12, 2.85, 0.12)), metal,
				Vector3(side * 2.3, 1.43, 0.82))
		_piece(root, _box_mesh("bs_post_front", Vector3(0.12, 2.85, 0.12)), metal,
				Vector3(side * 2.3, 1.43, -0.82))
	_piece(root, _box_mesh("bs_back", Vector3(4.7, 2.2, 0.07)), _material("glass", GLASS),
			Vector3(0.0, 1.60, 0.88))
	# Painel lateral de vidro: e o que fecha o abrigo contra o vento e o que dá
	# volume a ele visto de lado, que e como o motorista o ve.
	for side in [-1.0, 1.0]:
		_piece(root, _box_mesh("bs_side", Vector3(0.06, 2.2, 1.7)), _material("glass", GLASS),
				Vector3(side * 2.35, 1.60, 0.0))
	_piece(root, _box_mesh("bs_bench", Vector3(3.8, 0.10, 0.46)), _material("wood", WOOD),
			Vector3(0.0, 0.52, 0.55))
	_piece(root, _box_mesh("bs_bench_leg", Vector3(3.8, 0.42, 0.08)), metal,
			Vector3(0.0, 0.26, 0.76))
	# Placa na ponta, virada pra quem vem pela calcada.
	_piece(root, _cylinder_mesh("bs_sign_pole", 0.06, 3.2), metal,
			Vector3(2.75, 1.6, 0.0))
	_piece(root, _box_mesh("bs_sign", Vector3(0.62, 0.44, 0.06)),
			_material("sign", Color(0.20, 0.42, 0.72)), Vector3(2.75, 3.0, 0.0))
	return root


## Muro de lote: fecha o pedaco de quarteirao onde nao coube predio.
##
## Existe porque enfileirar predios sempre sobra um resto — nenhum modelo tem a
## largura exata do que ficou. Medido antes de existir: 73 vaos de 6 m ou mais,
## o maior com 17,6 m, e a quadra lia como dente faltando. Em cidade de verdade
## esse resto e muro de lote, terreno murado ou portao de garagem, e nao
## descampado.
##
## `comprimento` corre no eixo X; o -Z aponta pra rua.
static func lot_wall(comprimento: float) -> Node3D:
	var root := Node3D.new()
	root.name = "MuroDeLote"
	root.add_to_group("muro_lote")
	var altura := 2.6
	var reboco := _material("wall", Color(0.70, 0.68, 0.63))
	var pano := BoxMesh.new()
	pano.size = Vector3(comprimento, altura, 0.28)
	var mi := MeshInstance3D.new()
	mi.mesh = pano
	mi.set_surface_override_material(0, reboco)
	mi.position = Vector3(0.0, altura * 0.5, 0.0)
	root.add_child(mi)
	# Pilarete a cada ~4 m: sem eles o muro le como uma placa lisa comprida.
	var passo := 4.0
	var n: int = maxi(2, int(comprimento / passo))
	for i in range(n + 1):
		var x := -comprimento * 0.5 + comprimento * float(i) / float(n)
		var pilar := BoxMesh.new()
		pilar.size = Vector3(0.36, altura + 0.18, 0.40)
		var pm := MeshInstance3D.new()
		pm.mesh = pilar
		pm.set_surface_override_material(0, _material("wall_post", Color(0.62, 0.60, 0.56)))
		pm.position = Vector3(x, (altura + 0.18) * 0.5, 0.0)
		root.add_child(pm)
	# Portao de garagem quando ha largura pra isso: e o detalhe que faz o muro
	# ler como lote de alguem, e nao como tapume.
	if comprimento >= 6.0:
		var portao := BoxMesh.new()
		portao.size = Vector3(3.0, 2.2, 0.10)
		var pg := MeshInstance3D.new()
		pg.mesh = portao
		pg.set_surface_override_material(0, _material("gate", Color(0.34, 0.30, 0.27)))
		pg.position = Vector3(0.0, 1.1, -0.16)
		root.add_child(pg)
	return root


static func bench() -> Node3D:
	var root := Node3D.new()
	root.name = "Banco"
	root.add_to_group("banco")
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

# ---------------------------------------------------------------- VITRINE
# O terreo do kit e uma faixa CEGA de ~3,5 m em toda fachada (a regiao preta do
# atlas). Mesmo depois de virar plinto escuro de verdade em vez de buraco, ela
# continua sendo o pedaco mais morto da cidade — e e justamente o que o jogador
# ve o tempo todo, a pe ou dirigindo.
#
# Aqui ela ganha loja: vidro grande com montante, toldo listrado, letreiro aceso
# e porta. Montada com primitivas, como o resto deste arquivo, pra nao
# reintroduzir mistura de estilo.
#
# SEM COLISAO de proposito. A caixa do predio ja fecha a fachada, entao o vidro
# e inalcancavel de qualquer jeito; e um corpo a mais projetado sobre a calcada
# so criaria degrau e risco de parede invisivel — o defeito que a cordilheira ja
# teve (ver changelog 2026-08-04).

const AWNING_COLORS: Array[Color] = [
	Color(0.62, 0.16, 0.15), Color(0.16, 0.32, 0.52), Color(0.22, 0.42, 0.27),
	Color(0.70, 0.48, 0.14), Color(0.44, 0.20, 0.46), Color(0.20, 0.42, 0.46),
]
const SIGN_COLORS: Array[Color] = [
	Color(0.95, 0.72, 0.28), Color(0.90, 0.35, 0.30), Color(0.45, 0.80, 0.85),
	Color(0.85, 0.85, 0.90), Color(0.55, 0.85, 0.45),
]


## Uma loja de largura `width` encostada na fachada, escrita direto num
## `MeshBatch` em vez de virar nó.
##
## `base` leva do espaco do lote pro espaco onde o lote de malhas esta sendo
## montado, com o +Z apontando pra RUA. Quem chama junta varias lojas no mesmo
## batch e constroi UM nó no fim (ver CityBlocks._add_storefront): montada como
## arvore de nós, cada loja passava de 20 MeshInstance3D.
static func storefront_into(batch: MeshBatch, base: Transform3D, width: float,
		rng: RandomNumberGenerator) -> void:
	# Cabe dentro do lote com folga: vitrine que vaza pro lote do vizinho
	# aparece na hora numa fileira de predios encostados.
	var w: float = maxf(width - 0.9, 1.2)
	var glass_h := 2.35
	var sill := 0.35
	var frame := _material("shopfront_frame", Color(0.20, 0.21, 0.23))

	# Vidro: metalico e liso pra refletir o ceu, com um brilho fraco de luz
	# interna. Vitrine sem luz dentro le como loja fechada — e como buraco, que
	# e o problema que esta rodada veio resolver.
	var glass := _material("shopfront_glass", Color(0.20, 0.26, 0.31))
	glass.metallic = 0.75
	glass.roughness = 0.10
	glass.emission_enabled = true
	glass.emission = Color(0.35, 0.33, 0.26)
	glass.emission_energy_multiplier = 0.55

	batch.add(_box_mesh("shop_pane_%.2f" % w, Vector3(w, glass_h, 0.10)), glass,
		base * Transform3D(Basis.IDENTITY, Vector3(0.0, sill + glass_h * 0.5, 0.10)))

	# Peitoril e verga: e o que faz o vidro parecer embutido em vez de colado.
	for band: Array in [[sill, 0.30], [sill + glass_h, 0.34]]:
		var y: float = band[0]
		var t: float = band[1]
		batch.add(_box_mesh("shop_band_%.2f_%.2f" % [w, t], Vector3(w + 0.35, t, 0.22)),
			frame, base * Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.14)))

	# Montantes a cada ~1.6 m: vidro liso de 6 m de largura nao existe em loja
	# de rua, e o montante e o que da ESCALA a fachada de longe.
	var bays: int = maxi(int(round(w / 1.6)), 1)
	for i in range(1, bays):
		var x: float = -w * 0.5 + w * float(i) / float(bays)
		batch.add(_box_mesh("shop_mullion", Vector3(0.09, glass_h, 0.16)), frame,
			base * Transform3D(Basis.IDENTITY, Vector3(x, sill + glass_h * 0.5, 0.15)))

	# Porta numa das pontas, recuada e mais escura que o vidro.
	var door_x: float = (w * 0.5 - 0.65) * (1.0 if rng.randf() < 0.5 else -1.0)
	batch.add(_box_mesh("shop_door", Vector3(1.0, 2.15, 0.09)),
		_material("shopfront_door", Color(0.13, 0.15, 0.17)),
		base * Transform3D(Basis.IDENTITY, Vector3(door_x, 1.08, 0.13)))
	batch.add(_box_mesh("shop_handle", Vector3(0.05, 0.34, 0.05)),
		_material("shopfront_handle", Color(0.72, 0.70, 0.64)),
		base * Transform3D(Basis.IDENTITY, Vector3(door_x + 0.38, 1.05, 0.19)))

	# Toldo listrado, inclinado pra rua. Listra de duas cores em vez de uma so:
	# e o detalhe que le como comercio de rua ja a distancia.
	if rng.randf() < 0.72:
		var color: Color = AWNING_COLORS[rng.randi() % AWNING_COLORS.size()]
		var tilt := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-22.0)),
			Vector3(0.0, sill + glass_h + 0.34, 0.20))
		var stripes: int = maxi(int(round(w / 0.45)), 2)
		var sw: float = w / float(stripes)
		for i in range(stripes):
			var x: float = -w * 0.5 + sw * (float(i) + 0.5)
			var pale := i % 2 == 1
			var c: Color = color.lightened(0.55) if pale else color
			batch.add(_box_mesh("awning_slat_%.3f" % sw, Vector3(sw, 0.06, 1.25)),
				_material("awning_%d_%s" % [color.to_rgba32(), "b" if pale else "a"], c),
				base * tilt * Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.62)))
		# Babado da ponta: toldo cortado reto entrega que e uma caixa.
		batch.add(_box_mesh("awning_hem_%.2f" % w, Vector3(w, 0.16, 0.05)),
			_material("awning_hem_%d" % color.to_rgba32(), color.darkened(0.25)),
			base * tilt * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.06, 1.24)))

	# Letreiro aceso acima da verga.
	if rng.randf() < 0.65:
		var sign_color: Color = SIGN_COLORS[rng.randi() % SIGN_COLORS.size()]
		var board_w: float = minf(w * 0.72, 3.4)
		batch.add(_box_mesh("sign_board_%.2f" % board_w, Vector3(board_w, 0.52, 0.10)),
			_material("sign_back", Color(0.14, 0.14, 0.16)),
			base * Transform3D(Basis.IDENTITY, Vector3(0.0, sill + glass_h + 0.95, 0.16)))
		batch.add(_box_mesh("sign_face_%.2f" % board_w, Vector3(board_w - 0.16, 0.32, 0.06)),
			_material("sign_%d" % sign_color.to_rgba32(), sign_color, true),
			base * Transform3D(Basis.IDENTITY, Vector3(0.0, sill + glass_h + 0.95, 0.21)))
