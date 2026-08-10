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

## Distancia da fachada ate o ponto de entrega. Cai na calcada (que vai de
## 2.4 a 3.6 da linha de centro da rua, com a fachada em road_clearance),
## entao o NPC fica na frente da casa e o carro encosta na pista.
const FRONT_YARD_OFFSET := 1.1

## Quanto precisa sobrar no meio do quarteirao, depois das quatro fileiras de
## fachada, pra valer a pena construir um anel interno. Abaixo disso o que sobra
## e patio de fundo, que e o que uma quadra de verdade tem mesmo.
const MIOLO_MINIMO := 42.0

## Miolo maximo pra um lote virar praca/posto/estacionamento/feira.
##
## Esses lotes foram calibrados quando todo quarteirao tinha 28 m de miolo. Numa
## quadra de 90 m eles viram um descampado de 80 m: a foto da rua no anel do meio
## saiu com metade da tela ocupada por um estacionamento vazio ate o horizonte.
## Quadra grande sempre recebe predio; lote especial so nas curtas e medias.
const MIOLO_MAX_LOTE_ESPECIAL := 62.0

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

## A cidade e construida com os PREDIOS REALISTAS de assets/realistas_prontos/
## (modelos CC-BY baixados, fatiados e normalizados por tools/fatiar_realistas.gd).
## Desligando, a cidade volta pro kit do Kenney + o gerador de geometria.
@export var usar_realistas := true

## Zoneamento: que pacotes entram em cada zona. Os pacotes tem carater bem
## diferente entre si, e e isso que faz a cidade ter bairros em vez de uma
## mistura uniforme — brownstone de tijolo com escada de incendio le como bairro
## antigo, e torre de vidro le como centro.
## Toda zona precisa de opcao RASA, e nao so por estilo: o orcamento de
## profundidade e metade do miolo do quarteirao, entao numa quadra de 45 m ele e
## 17.6 m — e TODO modelo do pacote downtown tem de 19 a 40 m de profundidade.
## Sem uma opcao que caiba, a quadra inteira nascia vazia (aconteceu com 2).
## Predio baixo e antigo espremido entre torres tambem e o que downtown de
## verdade tem.
const ZONAS := {
	"centro": ["downtown_buildings", "new_york_buildings",
		"old_building_pack_lowpoly", "bordeaux_flat_1_corner_france"],
	"meio": ["brownstone_building_set", "new_york_buildings", "tenement_house",
		"bordeaux_flat_2_corner_france", "bordeaux_flat_1_corner_france",
		"old_building_pack_lowpoly"],
	"borda": ["old_building_pack_lowpoly", "brownstone_building_set",
		"bordeaux_flat_1_corner_france", "tenement_house"],
	"industrial": ["industrial_buildings_sets", "old_building_pack_lowpoly"],
}

## Pacotes cuja construcao serve de CASA de entrega. Galpao industrial e torre
## de escritorio nao servem: o cliente espera na calcada em frente de casa.
const RESIDENCIAIS := ["brownstone_building_set", "tenement_house",
	"bordeaux_flat_1_corner_france", "bordeaux_flat_2_corner_france",
	"old_building_pack_lowpoly"]

## Bolsoes industriais, em coordenada de mundo. "Industrial a parte" e por
## POSICAO, e nao por anel de distancia: zona industrial de cidade de verdade e
## um pedaco continuo do mapa (perto da ferrovia, do porto, da saida), nao uma
## casca em volta do centro.
@export var industrial_centers: Array[Vector3] = []
@export var industrial_radius := 90.0

## Props de praca (arvore, banco, coreto, ponte) que vieram no pacote
## `european_buildings_pack3` — que apesar do nome NAO tem predio nenhum.
@export var usar_props_realistas := true

## Fracao dos lotes construidos com geometria GERADA (ver BuildingFactory.gd) em
## vez de um modelo do kit. 0 = so kit, 1 = so gerado. Ignorado quando
## `usar_realistas` esta ligado.
##
## POR QUE MISTURAR, e nao trocar tudo. A medicao de 2026-08-03 apontou que o
## aspecto de desenho vem da GEOMETRIA (caixa lisa com a janela pintada na
## textura), e o gerador resolve isso — janela e vao de verdade, e cada predio e
## unico. Mas o kit tem silhuetas que o gerador nao faz (recuo de andar, terreo
## saliente, torre com base larga), e uma cidade 100% gerada fica com um ritmo
## de fachada regular demais. Misturado, um cobre a fraqueza do outro.
@export_range(0.0, 1.0) var generated_ratio := 0.62

## Tons de fachada sorteados por predio. Ficam perto do branco de proposito:
## sao multiplicados por cima da textura do kit, entao valores muito saturados
## deixariam a cidade com cara de desenho de novo.
@export var facade_colors: Array[Color] = [
	Color(1.0, 0.97, 0.92),    # creme
	Color(0.93, 0.88, 0.80),   # areia
	Color(0.87, 0.80, 0.74),   # bege escuro
	Color(0.80, 0.66, 0.58),   # terracota claro
	Color(0.72, 0.55, 0.48),   # tijolo desbotado
	Color(0.82, 0.84, 0.86),   # cinza claro
	Color(0.68, 0.72, 0.76),   # cinza azulado
	Color(0.74, 0.79, 0.74),   # verde acinzentado
	Color(0.86, 0.83, 0.70),   # amarelo palha
	Color(0.62, 0.64, 0.70),   # chumbo
]

## Lotes especiais. Sem eles a cidade vira uma grade infinita de predio: o que
## faz ler como cidade de verdade e ter quarteiroes com FUNCAO diferente —
## praca, posto de gasolina, estacionamento e feira no meio das quadras
## construidas. Todos cabem dentro do miolo do quarteirao (que ja desconta
## road_clearance), entao nenhum encosta na pista.
@export var tree_scenes: Array[PackedScene] = []
## Arvore tem escala propria: os modelos de natureza do Quaternius ja vem em
## metros de verdade, ao contrario do kit de predio (modulo 6.0).
@export var tree_scale := 1.3
@export var parasol_scenes: Array[PackedScene] = []
@export var parked_car_scenes: Array[PackedScene] = []
## Loja de conveniencia do posto: um predio pequeno do kit.
@export var kiosk_scenes: Array[PackedScene] = []
@export var park_weight := 0.12
@export var gas_station_weight := 0.07
@export var parking_weight := 0.08
@export var market_weight := 0.09

## Acabamento das fachadas: com PBR (grao/normal/roughness triplanar sobre o
## atlas do kit) ou a cor chapada antiga. Deixado como chave pra dar pra
## comparar os dois lado a lado.
@export var use_pbr_surface := true
@export var facade_texture_size := 2.4
@export var facade_saturation := 0.62
## Fuligem/respingo no pe da parede (ver shaders/city_surface.gdshader). E o que
## tira o aspecto de maquete recem-pintada da fachada vista da calcada.
@export var facade_grime := 0.38
## Entulho de cobertura (ver _add_rooftop_props).
@export var rooftop_props_enabled := true
@export var rooftop_prop_chance := 0.55
## Loja no terreo (ver _add_storefront). Nem todo predio tem loja — quarteirao
## inteiro com vitrine em fileira le como shopping, nao como cidade.
@export var storefronts_enabled := true
@export var storefront_chance := 0.72
## Distancia em que a vitrine some. Nao e economia de detalhe: a essa distancia
## a loja inteira ocupa poucos pixels, e o que sobra e so custo de desenho.
@export var storefront_visible_range := 180.0

## Raio (Chebyshev, a partir do centro) de cada anel de zoneamento. Eram
## numeros magicos casados com o espacamento de rua antigo (25); virando
## export, mudar a grade nao exige mais mexer no script.
@export var downtown_extent := 30.0
@export var midtown_extent := 75.0

@export var exclude_points: Array[Vector3] = []
@export var exclude_radius := 12.0

@export var rng_seed := 1

var _rng := RandomNumberGenerator.new()
## Lote de malhas das vitrines do quarteirao em construcao (ver _build_block).
var _shop_batch: MeshBatch = MeshBatch.new()

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
	if _is_excluded(Vector3(center.x, 0.0, center.y)):
		return

	# Lote especial so cabe em quarteirao curto ou medio (ver
	# MIOLO_MAX_LOTE_ESPECIAL). O sorteio acontece SEMPRE, mesmo quando o
	# resultado e descartado: ele consome o RNG, e pular o sorteio nas quadras
	# grandes mudaria o layout de toda a cidade depois delas — a mesma armadilha
	# do sorteio de material em 2026-08-03.
	var especial := _lot_kind()
	var miolo: float = minf(x_max - x_min, z_max - z_min)
	if miolo > MIOLO_MAX_LOTE_ESPECIAL:
		especial = "buildings"
	match especial:
		"park":
			_build_park(x_min, x_max, z_min, z_max)
			return
		"gas":
			_build_gas_station(x_min, x_max, z_min, z_max)
			return
		"parking":
			_build_parking(x_min, x_max, z_min, z_max)
			return
		"market":
			_build_market(x_min, x_max, z_min, z_max)
			return

	var pool := _pool_for(center)
	var kinds := _kinds_for(center)
	if pool.is_empty() and kinds.is_empty():
		return

	# Nenhum predio pode passar da metade do quarteirao: assim as duas bordas
	# opostas nunca se encontram no meio, por construcao (sem essa trava, um
	# modelo fundo na borda oeste alcancava o da borda leste num quarteirao
	# estreito).
	var depth_budget_z := (z_max - z_min) * 0.5 - lot_gap
	var depth_budget_x := (x_max - x_min) * 0.5 - lot_gap

	# Um lote de malhas POR QUARTEIRAO pras vitrines: elas sao dezenas de pecas
	# pequenas cada, e viraram o maior custo de chamada de desenho da cidade
	# (ver MeshBatch.gd). Por quarteirao, e nao pela cidade toda, pra o descarte
	# por frustum continuar valendo.
	_shop_batch = MeshBatch.new()

	# Norte/sul ocupam a largura toda; guardamos a profundidade usada pra
	# recuar as laterais e nao sobrepor nos cantos.
	var depth_south := _fill_edge(pool, kinds, x_min, x_max, z_min, true, false, depth_budget_z)
	var depth_north := _fill_edge(pool, kinds, x_min, x_max, z_max, true, true, depth_budget_z)

	var z_side_min := z_min + depth_south + lot_gap
	var z_side_max := z_max - depth_north - lot_gap
	var depth_west := 0.0
	var depth_east := 0.0
	if z_side_max - z_side_min > 2.0:
		depth_west = _fill_edge(pool, kinds, z_side_min, z_side_max, x_min, false, false, depth_budget_x)
		depth_east = _fill_edge(pool, kinds, z_side_min, z_side_max, x_max, false, true, depth_budget_x)

	# MIOLO: um segundo anel de predios, quando ainda sobra patio depois do
	# primeiro.
	#
	# Com a grade uniforme antiga (miolo de 28 m) nunca sobrava nada. Com
	# quarteirao de 90 m o miolo tem 80 m, e as quatro fileiras de fachada
	# deixavam um vazio de 20 a 40 m no meio — que na foto aerea aparece como uma
	# clareira pavimentada dentro de cada quadra, e da rua aparece como um descampado
	# entre dois predios. Quadra grande de cidade de verdade e construida por
	# dentro tambem.
	#
	# O anel interno e recuado pela profundidade JA USADA em cada borda, entao ele
	# nao pode sobrepor o externo por construcao — mesma garantia que ja protege
	# as bordas opostas de se encontrarem no meio.
	var ix_min := x_min + depth_west + lot_gap
	var ix_max := x_max - depth_east - lot_gap
	var iz_min := z_side_min + depth_south + lot_gap
	var iz_max := z_side_max - depth_north - lot_gap
	if ix_max - ix_min > MIOLO_MINIMO and iz_max - iz_min > MIOLO_MINIMO:
		var ib_z := (iz_max - iz_min) * 0.5 - lot_gap
		var ib_x := (ix_max - ix_min) * 0.5 - lot_gap
		var id_s := _fill_edge(pool, kinds, ix_min, ix_max, iz_min, true, false, ib_z)
		var id_n := _fill_edge(pool, kinds, ix_min, ix_max, iz_max, true, true, ib_z)
		var iz2_min := iz_min + id_s + lot_gap
		var iz2_max := iz_max - id_n - lot_gap
		if iz2_max - iz2_min > 2.0:
			_fill_edge(pool, kinds, iz2_min, iz2_max, ix_min, false, false, ib_x)
			_fill_edge(pool, kinds, iz2_min, iz2_max, ix_max, false, true, ib_x)

	var shops := _shop_batch.build("Vitrines")
	if shops != null:
		shops.add_to_group("storefront")
		# Detalhe de calcada: alem de ~180 m ele ocupa poucos pixels e so custa.
		shops.visibility_range_end = storefront_visible_range
		shops.visibility_range_end_margin = 20.0
		add_child(shops)

const GRASS := Color(0.44, 0.58, 0.36)
const PATH := Color(0.78, 0.75, 0.68)
const ASPHALT := Color(0.30, 0.31, 0.34)
const CONCRETE := Color(0.70, 0.69, 0.66)
const STRIPE := Color(0.88, 0.88, 0.84)

func _lot_kind() -> String:
	var roll := _rng.randf()
	var acc := park_weight
	if roll < acc:
		return "park"
	acc += gas_station_weight
	if roll < acc:
		return "gas"
	acc += parking_weight
	if roll < acc:
		return "parking"
	acc += market_weight
	if roll < acc:
		return "market"
	return "buildings"

## Praca: grama, caminho em cruz, arvores nos quatro quadrantes e bancos
## virados pro meio.
func _build_park(x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	var center := Vector3((x_min + x_max) * 0.5, 0.0, (z_min + z_max) * 0.5)
	var size := Vector2(x_max - x_min, z_max - z_min)
	_patch(center, size, GRASS, "grass", 0.04, "lote_praca", "grama")
	_patch(center, Vector2(size.x, 2.4), PATH, "path", 0.05, "", "concreto")
	_patch(center, Vector2(2.4, size.y), PATH, "path", 0.05, "", "concreto")

	# Arvores numa grade com sacudida, nao em posicao puramente sorteada: com
	# sorteio livre duas caem uma dentro da outra (a verificacao pegou 8 pares
	# assim). O passo sai da largura real do maior modelo do pool.
	# Arvore realista quando ha (ver _arvores_realistas). A do kit e estilizada e
	# ficava gritando ao lado de uma fachada fotografada — e exatamente a mistura
	# de estilos que este projeto ja corrigiu duas vezes.
	var pool_arv: Array = tree_scenes
	var esc_arv := tree_scale
	var reais := _arvores_realistas()
	if usar_props_realistas and not reais.is_empty():
		pool_arv = reais
		esc_arv = 1.0   # o fatiador ja normaliza pra metros

	if not pool_arv.is_empty():
		# Maior lado, nao diagonal: copa de arvore e aproximadamente redonda,
		# entao o AABB quase nao cresce ao girar. Com a diagonal (como estava),
		# a arvore maior estourava meio quarteirao, o numero de colunas virava
		# ZERO e a praca ficava sem arvore nenhuma.
		var step := 0.0
		for scene: PackedScene in pool_arv:
			var fp := _footprint(scene, 0.0, esc_arv)
			step = maxf(step, maxf(fp.x, fp.y))
		# Copa pode se tocar um pouco (arvore nao e caixa), entao o passo da
		# grade e menor que a largura medida — senao cabe uma arvore por
		# quadrante e a praca fica pelada.
		step = maxf(step * 0.75 + lot_gap, 3.0)
		var cols: int = maxi(int((size.x * 0.5 - 1.5) / step), 1)
		var rows: int = maxi(int((size.y * 0.5 - 1.5) / step), 1)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				for cx in range(cols):
					for cz in range(rows):
						if _rng.randf() < 0.15:
							continue
						var scene: PackedScene = pool_arv[_rng.randi() % pool_arv.size()]
						var jitter := step * 0.18
						var pos := Vector3(
							center.x + sx * (2.2 + cx * step + _rng.randf_range(-jitter, jitter)),
							0.0,
							center.z + sz * (2.2 + cz * step + _rng.randf_range(-jitter, jitter)))
						_place_prop(scene, pos, _rng.randf_range(0.0, 360.0), esc_arv)

	# Bancos de frente pro caminho central (o -Z do banco e o encosto).
	for side in [-1.0, 1.0]:
		var seat := StreetFurniture.bench()
		add_child(seat)
		seat.position = Vector3(center.x + side * 2.1, 0.0, center.z + side * 3.4)
		seat.rotation_degrees.y = 90.0 if side > 0.0 else 270.0

## Posto de gasolina: cobertura sobre as bombas, loja de conveniencia ao fundo
## e placa de preco na esquina.
func _build_gas_station(x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	var center := Vector3((x_min + x_max) * 0.5, 0.0, (z_min + z_max) * 0.5)
	var size := Vector2(x_max - x_min, z_max - z_min)
	_patch(center, size, CONCRETE, "concrete", 0.04, "lote_posto", "concreto")

	var canopy_w: float = minf(size.x * 0.8, 11.0)
	var canopy_d: float = minf(size.y * 0.5, 7.0)
	var canopy_z := center.z - size.y * 0.18
	var metal := StreetFurniture._material("canopy", Color(0.93, 0.93, 0.90))
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(canopy_w, 0.5, canopy_d)
	top.mesh = top_mesh
	top.set_surface_override_material(0, metal)
	add_child(top)
	# Fica no ar DE PROPOSITO, apoiada nos 4 pilares abaixo. Sem marcar, o
	# verificador de flutuacao (`tools/verify/scale_test.gd`) a acusa como
	# construcao boiando — e afrouxar o limiar pra calar isso esconderia
	# flutuacao de verdade.
	top.add_to_group("suspenso")
	top.position = Vector3(center.x, 4.4, canopy_z)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pillar := MeshInstance3D.new()
			var pillar_mesh := BoxMesh.new()
			pillar_mesh.size = Vector3(0.4, 4.2, 0.4)
			pillar.mesh = pillar_mesh
			pillar.set_surface_override_material(0, metal)
			add_child(pillar)
			pillar.position = Vector3(
				center.x + sx * (canopy_w * 0.5 - 0.5), 2.1,
				canopy_z + sz * (canopy_d * 0.5 - 0.5))
	for sx in [-1.0, 1.0]:
		var pump := StreetFurniture.fuel_pump()
		add_child(pump)
		pump.position = Vector3(center.x + sx * canopy_w * 0.22, 0.0, canopy_z)

	# Faixa vermelha na borda da cobertura: sem ela a estrutura branca sobre
	# pilares nao le como posto, le como marquise generica.
	for sz in [-1.0, 1.0]:
		var band := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(canopy_w + 0.1, 0.28, 0.12)
		band.mesh = band_mesh
		band.set_surface_override_material(0, StreetFurniture._material(
				"canopy_band", Color(0.80, 0.22, 0.18)))
		add_child(band)
		band.add_to_group("suspenso")
		band.position = Vector3(center.x, 4.4, canopy_z + sz * (canopy_d * 0.5 + 0.05))

	# Totem de preco na esquina do lote, virado pra rua.
	var totem_pole := MeshInstance3D.new()
	var totem_pole_mesh := BoxMesh.new()
	totem_pole_mesh.size = Vector3(0.22, 4.0, 0.22)
	totem_pole.mesh = totem_pole_mesh
	totem_pole.set_surface_override_material(0, StreetFurniture._material("metal", Color(0.28, 0.30, 0.33)))
	add_child(totem_pole)
	totem_pole.position = Vector3(x_min + 1.2, 2.0, z_min + 1.2)
	var totem := MeshInstance3D.new()
	var totem_mesh := BoxMesh.new()
	totem_mesh.size = Vector3(1.7, 2.0, 0.25)
	totem.mesh = totem_mesh
	totem.set_surface_override_material(0, StreetFurniture._material(
			"canopy_band", Color(0.80, 0.22, 0.18)))
	add_child(totem)
	# A placa fica no alto do mastro, como todo totem de posto — suspensa de
	# proposito, igual a cobertura.
	totem.add_to_group("suspenso")
	totem.position = Vector3(x_min + 1.2, 4.6, z_min + 1.2)

	# Loja de conveniencia: predio pequeno, encostado no fundo do lote. Numa
	# escala menor que a dos predios da quadra, senao vira um shopping e o
	# posto some atras dele.
	if not kiosk_scenes.is_empty():
		var kiosk: PackedScene = kiosk_scenes[_rng.randi() % kiosk_scenes.size()]
		var kiosk_scale := building_scale * 0.62
		var depth := _footprint(kiosk, 180.0, kiosk_scale).y
		_place_prop(kiosk, Vector3(center.x, 0.0, z_max - depth * 0.5 - 0.4), 180.0, kiosk_scale,
			"reboco")

## Estacionamento: asfalto, faixas e duas fileiras de carros parados.
func _build_parking(x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	var center := Vector3((x_min + x_max) * 0.5, 0.0, (z_min + z_max) * 0.5)
	var size := Vector2(x_max - x_min, z_max - z_min)
	_patch(center, size, ASPHALT, "asphalt", 0.04, "lote_estacionamento", "asfalto")
	if parked_car_scenes.is_empty():
		return
	# Vaga medida a partir do carro mais largo do pool, na escala em que ele e
	# usado (1.0 — os carros do Quaternius ja vem em metros). Com passo fixo
	# chutado, carro vizinho entra dentro do outro.
	var slot := 0.0
	for scene: PackedScene in parked_car_scenes:
		slot = maxf(slot, _footprint(scene, 0.0, 1.0).x)
	slot += 0.7
	var columns := int((size.x - 1.0) / slot)
	for row in range(2):
		var z := center.z + (-1.0 if row == 0 else 1.0) * size.y * 0.24
		for c in range(columns):
			var x := center.x - (columns - 1) * slot * 0.5 + c * slot
			_patch(Vector3(x - slot * 0.5, 0.0, z), Vector2(0.14, 5.0), STRIPE, "stripe", 0.06)
			if _rng.randf() < 0.5:
				continue
			var car: PackedScene = parked_car_scenes[_rng.randi() % parked_car_scenes.size()]
			_place_prop(car, Vector3(x, 0.0, z), 0.0 if row == 0 else 180.0, 1.0)

## Feira: barracas cobertas por guarda-sois, em duas fileiras, com corredor no
## meio — usa as pecas de parasol/awning do proprio kit comercial.
func _build_market(x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	var center := Vector3((x_min + x_max) * 0.5, 0.0, (z_min + z_max) * 0.5)
	var size := Vector2(x_max - x_min, z_max - z_min)
	_patch(center, size, PATH, "path", 0.04, "lote_feira", "cascalho")
	if parasol_scenes.is_empty():
		return
	# Passo tirado da largura real do guarda-sol, senao duas barracas vizinhas
	# se atravessam.
	var slot := 0.0
	for scene: PackedScene in parasol_scenes:
		slot = maxf(slot, _footprint(scene, 0.0).x)
	slot += 0.8
	var columns: int = maxi(int((size.x - 2.0) / slot), 1)
	for row in range(2):
		var z := center.z + (-1.0 if row == 0 else 1.0) * size.y * 0.22
		for c in range(columns):
			var x := center.x - (columns - 1) * slot * 0.5 + c * slot
			var parasol: PackedScene = parasol_scenes[_rng.randi() % parasol_scenes.size()]
			# Alinhadas de proposito: barraca de feira em fileira le como feira,
			# e rotacao sorteada aqui so faria a caixa crescer e as barracas se
			# atravessarem.
			_place_prop(parasol, Vector3(x, 0.0, z), 180.0 if row == 1 else 0.0, building_scale)
			# Balcao da barraca por baixo do guarda-sol.
			var stall := MeshInstance3D.new()
			var stall_mesh := BoxMesh.new()
			stall_mesh.size = Vector3(1.9, 0.9, 0.9)
			stall.mesh = stall_mesh
			stall.set_surface_override_material(0, StreetFurniture._material(
					"stall", Color(0.62, 0.46, 0.32)))
			add_child(stall)
			stall.position = Vector3(x, 0.45, z)

## `kind` e o acabamento PBR do piso (ver CitySurface.SETS). Vazio = cor
## chapada, que so serve pra faixa de demarcacao — um lote inteiro de cor
## chapada le como feltro no meio de uma cidade texturizada.
func _patch(center: Vector3, size: Vector2, color: Color, key: String, y: float,
		group := "", kind := "") -> void:
	var patch := StreetFurniture.ground_patch(size, color, key)
	if kind != "":
		# Textura grande e grao forte: o piso e visto de cima e de perto, entao
		# repeticao curta vira xadrez e grao fraco nao aparece.
		CitySurface.apply(patch, color, kind, 3.2, 0.85, 0.8)
	if group != "":
		# Marca o lote pelo tipo: serve pra achar praca/posto/feira depois, sem
		# depender do nome do no (irmaos repetidos viram "@Node3D@N").
		patch.add_to_group(group)
	add_child(patch)
	patch.position = Vector3(center.x, y, center.z)

## Igual a _place(), mas sem o tint de fachada: arvore, carro e guarda-sol tem
## cor propria e nao podem entrar na paleta de predio.
func _place_prop(scene: PackedScene, pos: Vector3, rot_deg: float, prop_scale: float,
		surface_kind := "") -> Node3D:
	var body := CITY_BUILDING_SCENE.instantiate()
	# Colisao pela silhueta na altura de trafego: arvore barra pelo TRONCO e
	# guarda-sol pela HASTE, em vez de pela copa (ver AutoCollisionBody). Carro
	# e quiosque sao macicos e ficam abaixo do limiar sozinhos, sem excecao.
	body.slim_collision = true
	body.visual_scene = scene
	body.visual_scale = prop_scale
	body.visual_rotation_y_degrees = rot_deg
	# Grupo, nao nome: arvore/carro/guarda-sol PODEM se tocar (copa encosta em
	# copa), predio nao. Sem separar os dois, uma verificacao de sobreposicao
	# acusa 125 "predios se atravessando" que na verdade sao copas de arvore.
	body.add_to_group("city_prop")
	add_child(body)
	# Mesmo desconto de _fill_edge: varios modelos do kit tem a malha deslocada
	# da origem do no, e sem isso o prop nasce fora do lugar planejado.
	var off := _center_offset(scene, rot_deg, prop_scale)
	body.position = pos - Vector3(off.x, 0.0, off.y)
	# Prop que por acaso E um predio do kit (a loja do posto) precisa do mesmo
	# acabamento das fachadas, senao fica de cor chapada e com quina redonda no
	# meio de uma cidade toda facetada.
	if surface_kind != "" and use_pbr_surface:
		CitySurface.apply(body, Color(0.92, 0.9, 0.86), surface_kind, facade_texture_size,
			facade_saturation, 0.45, facade_grime)
	return body

## Percorre uma borda colocando predios lado a lado, todos virados pra fora
## (pra rua). Retorna a maior profundidade usada, pra quem chamou saber o
## quanto recuar as bordas perpendiculares.
## - horizontal=true: anda no eixo X, a borda esta em Z=edge_coord
## - far_side=true: a borda e a de maior coordenada (norte/leste), entao o
##   predio cresce pra dentro no sentido negativo e vira 180 graus.
func _fill_edge(pool: Array, kinds: Array, run_min: float, run_max: float, edge_coord: float, horizontal: bool, far_side: bool, depth_budget: float) -> float:
	var cursor := run_min
	var max_depth := 0.0
	var guard := 0
	var rot_deg := _facing_rotation(horizontal, far_side)
	while cursor < run_max and guard < 64:
		guard += 1
		# Sorteia ate achar um modelo que caiba no espaco que sobrou. Sem isso,
		# um unico sorteio largo demais abandonava a borda inteira e deixava
		# buracos grandes na quadra.
		#
		# O lote pode sair GERADO (geometria propria, ver BuildingFactory) ou do
		# kit. A decisao e por LOTE, e nao por quarteirao, pra os dois se
		# misturarem na mesma fileira — quarteirao inteiro de um so tipo faria a
		# diferenca de estilo virar uma emenda visivel na esquina.
		var use_gen := not kinds.is_empty() \
			and (pool.is_empty() or _rng.randf() < generated_ratio)
		var scene: PackedScene = null
		var recipe: Dictionary = {}
		var width := 0.0
		var depth := 0.0
		for _try in range(FIT_ATTEMPTS):
			if use_gen:
				# O gerador ja produz em METROS e com a fachada no -Z, entao a
				# largura corre sempre ao longo da borda e a profundidade sempre
				# entra no quarteirao — nao ha o swap de eixo do kit.
				var d := BuildingFactory.roll(_rng, kinds[_rng.randi() % kinds.size()])
				if cursor + float(d["width"]) <= run_max and float(d["depth"]) <= depth_budget:
					recipe = d
					width = d["width"]
					depth = d["depth"]
					break
				continue
			# Sorteia entre os que CABEM, em vez de sortear e torcer.
			#
			# Antes eram 12 tentativas ao acaso e, falhando as 12, a borda inteira
			# era abandonada. Com o pool realista a maioria dos modelos e funda
			# (10 a 40 m), entao numa quadra estreita quase todo sorteio falhava:
			# 2 quarteiroes da cidade nasceram COMPLETAMENTE vazios, e o resto
			# ficou mais ralo do que precisava. Como a pegada de cada modelo e
			# medida uma vez e fica em cache, varrer o pool aqui e barato.
			var cabem: Array = []
			for candidate: PackedScene in pool:
				var fp := _footprint(candidate, rot_deg)
				if fp == Vector2.ZERO:
					continue
				var w: float = fp.x if horizontal else fp.y
				var dd: float = fp.y if horizontal else fp.x
				if cursor + w <= run_max and dd <= depth_budget:
					cabem.append([candidate, w, dd])
			if cabem.is_empty():
				break
			var escolha: Array = cabem[_rng.randi() % cabem.size()]
			scene = escolha[0]
			width = escolha[1]
			depth = escolha[2]
			break
		if scene == null and recipe.is_empty():
			break

		var along := cursor + width * 0.5
		var inward: float = -depth * 0.5 if far_side else depth * 0.5
		var pos: Vector3
		if horizontal:
			pos = Vector3(along, 0.0, edge_coord + inward)
		else:
			pos = Vector3(edge_coord + inward, 0.0, along)

		# Centro geometrico do lote, antes de descontar o offset da malha: e
		# dele que sai o ponto de entrega na calcada (ver _register_house).
		var slot_pos := pos
		if scene != null:
			# Desconta o deslocamento da malha, pra caixa real cair onde foi
			# planejado. O gerado ja nasce centrado na propria origem.
			var off := _center_offset(scene, rot_deg)
			pos -= Vector3(off.x, 0.0, off.y)

		if not _is_excluded(pos):
			var casa: bool = recipe["kind"] == BuildingFactory.Kind.CASA \
				if not recipe.is_empty() else _e_casa(scene)
			# A vitrine em relevo (StreetFurniture) e a vitrine do gerador
			# ocupam o MESMO terreo. Decidir antes de construir deixa o gerador
			# fechar aquele pano com parede lisa, senao ficam dois vidros a 26 cm
			# um do outro e a fachada le como janela dupla.
			var shop := _wants_storefront(casa)
			if not recipe.is_empty():
				recipe["storefront"] = shop
			var body: Node3D = _place_generated(recipe, pos, rot_deg) \
				if not recipe.is_empty() else _place(scene, pos, rot_deg)
			if body != null and casa:
				_register_house(body, slot_pos, rot_deg, depth)
			if body != null and shop:
				_add_storefront(slot_pos, rot_deg, width, depth)
			max_depth = maxf(max_depth, depth)
		cursor += width + lot_gap
	return max_depth

## Loja no terreo, encostada na fachada que da pra rua (ver
## StreetFurniture.storefront). So em predio de comercio/torre/galpao: casa de
## bairro nao tem vitrine, e o kit suburbano ja desenha porta e janela terrea.
##
## O ponto sai do MESMO calculo do ponto de entrega (`_register_house`) — o
## plano da fachada e o centro do lote deslocado meia profundidade pra rua —
## entao os dois nao podem divergir quando alguem mexer na geracao.
## Sorteia se este lote leva vitrine. Separado do desenho de proposito: o predio
## GERADO precisa saber disso ANTES de ser construido (ver _fill_edge), e o
## sorteio tem que acontecer uma vez so — rolar duas vezes consumiria o RNG em
## dobro e mudaria o layout da cidade inteira.
func _wants_storefront(casa: bool) -> bool:
	# Predio realista ja vem com o terreo comercial modelado (vitrine, toldo,
	# porta). Colar a vitrine de primitivas por cima poria duas lojas no mesmo
	# pano de parede.
	if usar_realistas:
		return false
	if casa or not storefronts_enabled:
		return false
	return _rng.randf() <= storefront_chance

func _add_storefront(slot_pos: Vector3, rot_deg: float, width: float, depth: float) -> void:
	var dir := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(rot_deg))
	var origin := Vector3(slot_pos.x, 0.0, slot_pos.z) + dir * (depth * 0.5)
	# O +Z da vitrine olha pra rua; `dir` ja e a direcao da rua.
	var base := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), origin)
	StreetFurniture.storefront_into(_shop_batch, base, width, _rng)

## Marca a casa como destino possivel de entrega e guarda, no proprio no, o
## ponto da calcada bem na frente dela e pra que lado ela olha. O
## DeliveryManager sorteia uma dessas casas a cada venda.
func _register_house(body: Node3D, slot_pos: Vector3, rot_deg: float, depth: float) -> void:
	var dir := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(rot_deg))
	var front := slot_pos + dir * (depth * 0.5 + FRONT_YARD_OFFSET)
	front.y = 0.0
	body.add_to_group("delivery_house")
	body.set_meta("front_position", front)
	body.set_meta("front_facing", dir)

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
func _footprint(scene: PackedScene, rot_deg: float, scale := -1.0) -> Vector2:
	var base := _base_footprint(scene)
	if base == Vector2.ZERO:
		return Vector2.ZERO
	var swapped := int(round(absf(rot_deg) / 90.0)) % 2 == 1
	var fp := Vector2(base.y, base.x) if swapped else base
	return fp * (scale if scale > 0.0 else _scale_of(scene))

func _base_footprint(scene: PackedScene) -> Vector2:
	return _measure(scene)["size"]

## Deslocamento do centro da malha em relacao a origem do no, ja escalado e
## girado. Varios modelos do kit nao sao centrados na propria origem; sem
## descontar isso, a caixa de colisao real nasce deslocada do lugar planejado
## e os predios acabam se sobrepondo ou invadindo a rua.
func _center_offset(scene: PackedScene, rot_deg: float, scale := -1.0) -> Vector2:
	var c: Vector2 = _measure(scene)["center"]
	return c.rotated(-deg_to_rad(rot_deg)) * (scale if scale > 0.0 else _scale_of(scene))

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
		# Topo em unidades locais: e daqui que sai a altura do telhado onde os
		# props de cobertura sao plantados.
		"top": aabb.position.y + aabb.size.y,
	}
	_footprint_cache[key] = data
	return data

## Zoneamento por distancia (Chebyshev, casando com o formato quadrado da
## grade): miolo = arranha-ceu/comercio, meio = comercio/casa, borda =
## casa/galpao industrial.
func _pool_for(center: Vector2) -> Array:
	if usar_realistas:
		return _pool_realista(_zona_de(center))
	var ring: float = maxf(absf(center.x), absf(center.y))
	var pool: Array = []
	if ring < downtown_extent:
		# Torre entra em DOBRO no miolo: com uma copia so ela se perde no meio
		# das 23 fachadas comerciais e o centro nao ganha silhueta alta.
		pool.append_array(skyscraper_scenes)
		pool.append_array(skyscraper_scenes)
		pool.append_array(commercial_scenes)
	elif ring < midtown_extent:
		pool.append_array(commercial_scenes)
		pool.append_array(house_scenes)
	else:
		pool.append_array(house_scenes)
		pool.append_array(industrial_scenes)
	return pool

## O mesmo zoneamento do `_pool_for`, do lado do gerador. Anda junto com ele de
## proposito: se as duas listas discordarem, o miolo ganha casa gerada ao lado de
## arranha-ceu do kit e o zoneamento perde sentido.
func _kinds_for(center: Vector2) -> Array:
	# Cidade realista nao usa o gerador de geometria: os dois resolvem o mesmo
	# problema, e misturar geometria gerada com fotogrametria e a mistura de
	# estilos que este projeto ja corrigiu duas vezes.
	if usar_realistas:
		return []
	var ring: float = maxf(absf(center.x), absf(center.y))
	if ring < downtown_extent:
		# Torre em dobro, mesma razao do pool do kit: com uma copia so ela se
		# perde no meio do comercio e o centro nao ganha silhueta alta.
		return [BuildingFactory.Kind.TORRE, BuildingFactory.Kind.TORRE,
			BuildingFactory.Kind.COMERCIO]
	if ring < midtown_extent:
		return [BuildingFactory.Kind.COMERCIO, BuildingFactory.Kind.CASA]
	return [BuildingFactory.Kind.CASA, BuildingFactory.Kind.GALPAO]

## Em que zona cai um quarteirao. O bolsao industrial e testado ANTES do anel,
## porque ele e uma regiao do mapa e nao um degrau de distancia — um bolsao pode
## encostar no meio da cidade.
func _zona_de(center: Vector2) -> String:
	for c in industrial_centers:
		if Vector2(center.x - c.x, center.y - c.z).length() < industrial_radius:
			return "industrial"
	var ring: float = maxf(absf(center.x), absf(center.y))
	if ring < downtown_extent:
		return "centro"
	if ring < midtown_extent:
		return "meio"
	return "borda"

## Cenas de uma zona, carregadas do catálogo gerado pelo fatiador.
##
## Cache estatico: sao 93 cenas, cada quarteirao pede a lista da sua zona, e
## carregar de novo a cada um dos ~200 quarteiroes multiplicaria o tempo de
## carga da cidade por nada.
static var _cache_zona: Dictionary = {}

func _pool_realista(zona: String) -> Array:
	if _cache_zona.has(zona):
		return _cache_zona[zona]
	var pool: Array = []
	for pacote: String in ZONAS.get(zona, []):
		for caminho: String in CatalogoRealistas.POR_PACOTE.get(pacote, []):
			var cena := load(caminho) as PackedScene
			if cena != null:
				pool.append(cena)
	_cache_zona[zona] = pool
	return pool

## Escala de um modelo. Os predios realistas ja vem em METROS (o fatiador
## normaliza), enquanto o kit do Kenney usa o modulo 7.5 — e a mesma cena de
## quiosque/guarda-sol do kit continua sendo usada nos lotes especiais, entao
## nao da pra ter um numero so.
func _scale_of(scene: PackedScene) -> float:
	if scene != null and scene.resource_path.begins_with("res://assets/realistas_prontos/"):
		return 1.0
	return building_scale

## As ARVORES do pacote `european_buildings_pack3`, que apesar do nome nao tem
## predio nenhum: sao arvore, banco, poste, coreto e ponte de praca.
##
## Classificadas pela MEDIDA, e nao por indice no catalogo. Indice fixo quebraria
## calado toda vez que o fatiador mudasse de criterio e renumerasse as pecas — e
## ele ja renumerou tres vezes nesta sessao. Arvore aqui e o que e alto o
## bastante pra dar sombra e estreito o bastante pra caber numa praca.
static var _arvores_cache: Array = []
static var _arvores_prontas := false

func _arvores_realistas() -> Array:
	if _arvores_prontas:
		return _arvores_cache
	_arvores_prontas = true
	for caminho: String in CatalogoRealistas.POR_PACOTE.get("european_buildings_pack3", []):
		var cena := load(caminho) as PackedScene
		if cena == null:
			continue
		var d := _measure(cena)
		var tam: Vector2 = d["size"]
		var alt: float = float(d["top"])
		if alt >= 5.0 and alt <= 22.0 and maxf(tam.x, tam.y) <= 12.0:
			_arvores_cache.append(cena)
	return _arvores_cache

## Serve de casa de entrega? Nos realistas, sai do PACOTE de origem; no kit
## antigo, da lista de cenas de casa.
func _e_casa(scene: PackedScene) -> bool:
	if scene == null:
		return false
	if not usar_realistas:
		return scene in house_scenes
	var arq := scene.resource_path.get_file()
	for p: String in RESIDENCIAIS:
		if arq.begins_with(p):
			return true
	return false

func _is_excluded(pos: Vector3) -> bool:
	for e in exclude_points:
		if Vector2(pos.x - e.x, pos.z - e.z).length() < exclude_radius:
			return true
	return false

func _place(scene: PackedScene, pos: Vector3, rot_deg: float) -> Node3D:
	var body := CITY_BUILDING_SCENE.instantiate()
	body.visual_scene = scene
	body.visual_scale = _scale_of(scene)
	body.visual_rotation_y_degrees = rot_deg
	body.add_to_group("city_building")
	add_child(body)
	body.position = pos
	_tint(body)
	_add_rooftop_props(scene, pos, rot_deg)
	return body

## Um predio construido em geometria (ver BuildingFactory.gd).
##
## Nao passa pelo `CityBuilding.tscn`/`AutoCollisionBody`: aquilo existe pra
## MEDIR a caixa de um modelo de kit que ninguem sabe o tamanho. Aqui as medidas
## sao a entrada da receita, entao a colisao sai delas direto — mais barato e
## exato, sem varrer vertice no carregamento.
func _place_generated(d: Dictionary, pos: Vector3, rot_deg: float) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "PredioGerado"
	body.add_to_group("city_building")
	# Grupo, e nao o nome: irmaos de nome repetido viram `@PredioGerado@N`, e
	# contar por nome ja fez um verificador achar 2 semaforos de 50 (changelog
	# 2026-08-03) — e me fez achar 1 predio gerado de 780 na primeira medicao.
	body.add_to_group("predio_gerado")
	add_child(body)
	body.position = pos
	body.rotation_degrees.y = rot_deg
	# O gerador ja escolhe a propria cor e o proprio material (a fachada nao tem
	# atlas de kit pra tingir por cima), entao aqui nao ha `_tint`.
	body.add_child(BuildingFactory.build(d, facade_texture_size, facade_saturation,
		facade_grime))

	var h := BuildingFactory.height_of(d)
	var shape := BoxShape3D.new()
	shape.size = Vector3(d["width"], h, d["depth"])
	var coll := CollisionShape3D.new()
	coll.shape = shape
	coll.position = Vector3(0.0, h * 0.5, 0.0)
	body.add_child(coll)

	_add_generated_rooftop_props(d, pos, rot_deg)
	return body

## Entulho de cobertura no predio gerado. Mesma ideia do `_add_rooftop_props`, mas
## sem a parte dificil: la a laje precisa ser MEDIDA nos vertices porque o topo da
## caixa e o ponto mais alto do modelo inteiro (mastro, casa de maquinas) e o prop
## saia boiando. Aqui a altura da laje e um dado da receita.
func _add_generated_rooftop_props(d: Dictionary, pos: Vector3, rot_deg: float) -> void:
	if not rooftop_props_enabled or not bool(d["parapet"]):
		return
	if _rng.randf() > rooftop_prop_chance:
		return
	var w: float = d["width"]
	var dp: float = d["depth"]
	var slab := BuildingFactory.slab_y(d)
	var inset := 1.4
	var rot := deg_to_rad(rot_deg)
	for i in range(_rng.randi_range(1, 3)):
		var maker: Callable
		match _rng.randi() % 3:
			0:
				maker = StreetFurniture.water_tank
			1:
				maker = StreetFurniture.antenna
			_:
				maker = StreetFurniture.ac_unit
		var prop: Node3D = maker.call()
		add_child(prop)
		# Sorteado no espaco do PREDIO e girado depois: o lote e retangular e a
		# fileira pode estar virada pra qualquer um dos 4 lados, entao sortear
		# direto em X/Z do mundo jogaria prop pra fora da laje nas bordas
		# leste/oeste, onde largura e profundidade trocam de eixo.
		var lx: float = _rng.randf_range(-1.0, 1.0) * maxf(w * 0.5 - inset, 0.2)
		var lz: float = _rng.randf_range(-1.0, 1.0) * maxf(dp * 0.5 - inset, 0.2)
		# `-rot`, e nao `rot`: a convencao de sinal do Vector2.rotated e a
		# CONTRARIA da rotacao em Y de um Node3D. Errar isso ja tinha mandado
		# prop de telhado pra 27 m de altura (changelog 2026-08-04); aqui, com
		# rotacao multipla de 90 numa laje simetrica, sairia calado.
		var off := Vector2(lx, lz).rotated(-rot)
		prop.position = Vector3(pos.x + off.x, slab, pos.z + off.y)
		prop.rotation_degrees.y = _rng.randf_range(0.0, 360.0)

## Entulho de cobertura (caixa d'agua, ar condicionado, antena). E o que quebra
## a silhueta de caixa que ainda fazia a cidade ler como maquete de longe,
## mesmo com as fachadas ja texturizadas — e nenhum modelo do kit tem isso.
## So em telhado plano: casa do kit suburbano tem telhado inclinado e o prop
## ficaria flutuando.
func _add_rooftop_props(scene: PackedScene, pos: Vector3, rot_deg: float) -> void:
	# Os modelos realistas ja trazem o proprio entulho de cobertura (caixa
	# d'agua, casa de maquinas, antena) modelado.
	if usar_realistas:
		return
	if not rooftop_props_enabled or scene in house_scenes:
		return
	if _rng.randf() > rooftop_prop_chance:
		return
	var footprint := _footprint(scene, rot_deg)
	var top: float = float(_measure(scene)["top"]) * _scale_of(scene)
	if footprint.x < 3.0 or footprint.y < 3.0:
		return
	# Recuo generoso: prop encostado na borda fica meio pra fora do telhado nos
	# modelos cuja malha nao preenche o AABB todo.
	var inset := 1.6
	# O TELHADO nao fica sobre `pos`. Varios modelos do kit tem a malha deslocada
	# da origem do no, e quem planta o predio ja desconta esse offset (`pos -=
	# off`) — entao a construcao aparece em `pos + off`. Plantando o entulho em
	# `pos`, ele caia ao lado do predio, sobre o vazio: o verificador achou 15
	# props boiando, o pior a 14,3 m do chao.
	var roof_off := _center_offset(scene, rot_deg)
	var roof_x: float = pos.x + roof_off.x
	var roof_z: float = pos.z + roof_off.y
	for i in range(_rng.randi_range(1, 3)):
		var maker: Callable
		match _rng.randi() % 3:
			0:
				maker = StreetFurniture.water_tank
			1:
				maker = StreetFurniture.antenna
			_:
				maker = StreetFurniture.ac_unit
		var prop: Node3D = maker.call()
		add_child(prop)
		var px: float = roof_x + _rng.randf_range(-1.0, 1.0) * maxf(footprint.x * 0.5 - inset, 0.2)
		var pz: float = roof_z + _rng.randf_range(-1.0, 1.0) * maxf(footprint.y * 0.5 - inset, 0.2)
		# Pousa na LAJE medida naquele ponto, nao no topo da caixa. O topo da caixa
		# e o ponto mais alto do modelo INTEIRO — numa torre com casa de maquinas,
		# num telhado recuado ou num predio com mastro, ele fica bem acima da laje
		# e a caixa d'agua aparece boiando sobre a construcao. Mesmo erro que ja
		# tinha posto a gambiarra do capo dentro da lataria: caixa nao e superficie.
		var surf: float = _roof_world_y(scene, pos, rot_deg, px, pz)
		var y: float = surf if surf != -INF else top
		prop.position = Vector3(px, y, pz)
		prop.rotation_degrees.y = _rng.randf_range(0.0, 360.0)

## Todos os predios do kit dividem um unico atlas de textura, entao sem isso a
## cidade inteira fica da mesma cor. albedo_color multiplica a textura, entao
## um tom por predio da variedade de fachada sem perder o desenho das janelas.
func _tint(body: Node3D) -> void:
	# Predio realista mantem a propria textura. O `CitySurface` foi feito pra
	# salvar o atlas de 64x64 do kit; jogado por cima de uma fachada
	# fotografada, so apaga o que ela tem de bom.
	if usar_realistas:
		return
	if facade_colors.is_empty():
		return
	var color: Color = facade_colors[_rng.randi() % facade_colors.size()]
	# Sorteado sempre, mesmo sem PBR: o sorteio consome o RNG, e so consumir
	# num dos dois modos faria a cidade INTEIRA mudar de layout ao ligar a
	# chave — a comparacao lado a lado deixaria de ser da mesma cidade.
	var kind := _surface_kind(body)
	if use_pbr_surface:
		# Acabamento PBR por cima do atlas do kit (ver CitySurface.gd). O
		# material combina com o TIPO de construcao: tijolo em arranha-ceu
		# ficou errado no primeiro teste — torre e concreto, casa e que pode
		# ser tijolo ou reboco.
		CitySurface.apply(body, color, kind, facade_texture_size, facade_saturation,
			0.45, facade_grime)
		return
	for mesh_inst in _all_mesh_instances(body):
		for surface in range(mesh_inst.get_surface_override_material_count()):
			var base: Material = mesh_inst.mesh.surface_get_material(surface)
			var mat: StandardMaterial3D = base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()
			mat.albedo_color = color
			mesh_inst.set_surface_override_material(surface, mat)

## Material de acabamento combinando com o tipo de construcao: torre e galpao
## em concreto, casa em tijolo ou reboco, comercio no meio do caminho.
func _surface_kind(body: Node3D) -> String:
	var scene: PackedScene = body.visual_scene
	if scene in skyscraper_scenes or scene in industrial_scenes:
		return "concreto"
	if scene in house_scenes:
		return "tijolo" if _rng.randf() < 0.35 else "reboco"
	return "reboco" if _rng.randf() < 0.6 else "concreto"

func _all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh:
		result.append(node)
	for child in node.get_children():
		result.append_array(_all_mesh_instances(child))
	return result

## Vertices da malha do modelo, em unidades locais, guardados por cena.
var _verts_cache: Dictionary = {}

func _model_verts(scene: PackedScene) -> PackedVector3Array:
	var key := scene.resource_path
	if _verts_cache.has(key):
		return _verts_cache[key]
	var inst := scene.instantiate()
	var out := PackedVector3Array()
	_collect_verts(inst, Transform3D.IDENTITY, out)
	inst.free()
	_verts_cache[key] = out
	return out

func _collect_verts(node: Node, accum: Transform3D, out: PackedVector3Array) -> void:
	var t := accum
	if node is Node3D:
		t = accum * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		for v: Vector3 in (node as MeshInstance3D).mesh.get_faces():
			out.append(t * v)
	for child in node.get_children():
		_collect_verts(child, t, out)

## Altura do TELHADO num ponto do MUNDO, medida nos vertices — nao o topo da
## caixa. O topo da caixa e o ponto mais alto do modelo INTEIRO: numa torre com
## casa de maquinas ou num telhado recuado ele fica bem acima da laje, e a caixa
## d'agua aparece boiando sobre a construcao. Mesmo erro que ja tinha posto a
## gambiarra do capo dentro da lataria — caixa nao e superficie.
##
## Os vertices sao levados PRA FRENTE (modelo -> mundo), de proposito. A
## primeira versao fazia o contrario, convertendo o ponto do mundo pro espaco do
## modelo com `Vector2.rotated`, e a convencao de sinal do rotated 2D nao bate
## com a rotacao em Y — o ponto amostrado saia errado, pegava a parte alta do
## predio e os props subiam ate 27 m no ar.
func _roof_world_y(scene: PackedScene, base: Vector3, rot_deg: float,
		px: float, pz: float, radius := 1.2) -> float:
	var basis := Basis(Vector3.UP, deg_to_rad(rot_deg)).scaled(
		Vector3(building_scale, building_scale, building_scale))
	var best := -INF
	for v: Vector3 in _model_verts(scene):
		var w: Vector3 = basis * v
		if absf(base.x + w.x - px) <= radius and absf(base.z + w.z - pz) <= radius:
			best = maxf(best, base.y + w.y)
	return best

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
