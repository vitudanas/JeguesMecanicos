extends Node3D
## Gera as ROTAS de trânsito e de pedestres a partir da grade de ruas.
##
## Até aqui as 18 rotas eram nós escritos à mão no `Town.tscn`, cada uma com
## quatro cantos digitados. Isso já custou caro duas vezes (changelog
## 2026-08-03): duas rotas nunca estiveram sobre rua nenhuma — usavam x = 29,
## que cai no meio do quarteirão — e passaram despercebidas enquanto os
## quarteirões eram vazios. Com a cidade 5x maior seriam ~90 retângulos
## digitados à mão, ou seja ~90 chances de errar o mesmo jeito.
##
## Aqui a rota SAI da grade: sorteia um quarteirão e dá a volta nele pelos
## quatro eixos de rua que o cercam. Por construção ela está sobre asfalto — o
## carro na pista, o pedestre na calçada — e continua certa se a cidade mudar de
## tamanho.

## Os mesmos eixos que o `CityStreets` usa. Vêm do `Town.tscn` pra ninguém ter
## duas listas de ruas que podem divergir.
@export var streets_x: Array[float] = []
@export var streets_z: Array[float] = []

@export_group("Trânsito")
@export var traffic_scene: PackedScene
## Quantos circuitos de carro. Cada um dá a volta num quarteirão.
@export var traffic_routes := 14
@export var cars_per_route := 3
@export var car_models: Array[PackedScene] = []
## Distância do eixo da rua até a faixa. A pista tem 3.0 de meia-largura, então
## 1.5 é o meio da mão da direita.
## AMARRADO AO PERFIL DA RUA (CityStreets): pista de +-5.7 e calcada
## de 3.5 -> faixa de rolamento no meio de cada meia-pista (2.85) e
## pedestre no meio da calcada (5.7 + 3.5/2 = 7.45). Mexeu na largura
## da rua, mexe aqui.
@export var lane_offset := 2.85
@export var car_speed_min := 4.0
@export var car_speed_max := 7.0

@export_group("Pedestres")
@export var pedestrian_scene: PackedScene
@export var pedestrian_routes := 12
@export var peds_per_route := 4
## Reserva: usado só se o catálogo de personagens não trouxer nada. O pool de
## verdade sai de `Appearance.npc_models()` (ver `_pool_modelos`), que já inclui
## os dois nativos.
@export var character_models: Array[PackedScene] = []
@export var anim_scene: PackedScene
## A calçada fica entre o meio-fio (3.0) e a fachada (3.8+): 3.75 é o meio dela.
@export var sidewalk_offset := 7.45
@export var walk_y := 0.18

## Quarteirões que NÃO recebem rota: o miolo da cidade fica mais movimentado que
## a periferia se as rotas forem sorteadas uniformemente, então sorteio com peso
## pro centro — que é onde o jogador passa mais tempo.
## Peso do centro contra o sorteio (0 = uniforme). Em 1.5, o miolo da cidade
## fica bem mais movimentado que a periferia, mas a periferia nao fica vazia.
@export var center_bias := 1.5

@export var rng_seed := 20260809

var _rng := RandomNumberGenerator.new()

## Cache do pool de pedestres: `Appearance.npc_models()` le o catalogo do disco,
## e sao 18 rotas pedindo a mesma lista.
static var _pool: Array[Dictionary] = []

## Os modelos que os pedestres usam: os dois nativos configurados na cena MAIS os
## personagens baixados que cabem no orcamento de faces (ver
## `Appearance.npc_models`). Sem isso a cidade inteira anda com dois bonecos, que
## era a limitacao "todo pedestre tem a mesma cara".
##
## O catalogo entra por CODIGO e nao pela cena porque a lista cresce a cada
## personagem baixado — escrever os 31 a mao no `Town.tscn` seriam 31 chances de
## errar a altura, que e o erro que nao acusa em lugar nenhum.
func _pool_modelos() -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for e: Dictionary in _entradas():
		var cena := load(str(e["caminho"])) as PackedScene
		if cena:
			out.append(cena)
	return out

func _pool_alturas() -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in _entradas():
		if load(str(e["caminho"])) != null:
			out.append(float(e["altura_modelo"]))
	return out

func _entradas() -> Array[Dictionary]:
	if _pool.is_empty():
		_pool = Appearance.npc_models()
	if _pool.is_empty():
		for cena: PackedScene in character_models:
			_pool.append({"caminho": cena.resource_path, "altura_modelo": 1.79})
	return _pool

func _ready() -> void:
	_rng.seed = rng_seed
	if streets_x.size() < 2 or streets_z.size() < 2:
		push_warning("CityLife: sem grade de ruas, nenhuma rota gerada")
		return
	_build(traffic_routes, true)
	_build(pedestrian_routes, false)

## Os quarteirões em ordem de preferência: os centrais primeiro, com um empurrão
## aleatório pra a escolha não ficar sempre a mesma.
##
## A primeira versão sorteava "o mais central de N amostras" e recusava
## quarteirão repetido. Com 196 quarteirões e um viés forte, ela caía sempre nos
## mesmos poucos do miolo e desistia por esgotar as tentativas: pedi 14 rotas de
## carro e a cidade nasceu com 5 (15 carros em vez de 42). Ordenar a lista
## inteira uma vez entrega exatamente o número pedido, sem colisão.
func _ranked_blocks() -> Array:
	var bx := streets_x.size() - 1
	var bz := streets_z.size() - 1
	var lista: Array = []
	for x in range(bx):
		for z in range(bz):
			var dx: float = absf(float(x) - float(bx - 1) * 0.5) / maxf(float(bx), 1.0)
			var dz: float = absf(float(z) - float(bz - 1) * 0.5) / maxf(float(bz), 1.0)
			# Chebyshev: a cidade é um quadrado, então "longe do centro" é o
			# maior dos dois eixos, não a distância reta.
			var score: float = maxf(dx, dz) * center_bias + _rng.randf()
			lista.append([score, Vector2i(x, z)])
	lista.sort_custom(func(a, b): return a[0] < b[0])
	return lista

func _build(count: int, is_traffic: bool) -> void:
	var cena := traffic_scene if is_traffic else pedestrian_scene
	if cena == null:
		return
	var ordem := _ranked_blocks()
	var feitas := 0
	for entrada: Array in ordem:
		if feitas >= count:
			break
		var b: Vector2i = entrada[1]
		var rota := cena.instantiate()
		# CONFIGURA ANTES DE ENTRAR NA ARVORE. `add_child` dispara o `_ready` da
		# rota na hora, e e ele que monta a curva a partir de `route_points` —
		# com a lista ainda vazia, a curva nasce com comprimento ZERO e os
		# pedestres apareceram todos empilhados na origem, 18 cm abaixo da
		# calcada ("Can't set progress ratio on a PathFollow3D that has a 0
		# length curve" no log, que nao reprova nada sozinho).
		rota.route_points = _loop(b, is_traffic)
		if is_traffic:
			rota.car_count = cars_per_route
			rota.car_models = car_models
			rota.car_speed_min = car_speed_min
			rota.car_speed_max = car_speed_max
		else:
			rota.pedestrian_count = peds_per_route
			rota.character_models = _pool_modelos()
			rota.model_heights = _pool_alturas()
			# Semente propria por rota, tirada do RNG semeado da cidade: assim
			# cada rota sorteia gente diferente e a cidade inteira continua
			# reproduzivel.
			rota.rng_seed = _rng.randi()
			rota.idle_anim_scene = anim_scene
			rota.walk_anim_scene = anim_scene
			rota.idle_anim_name = "Idle"
			rota.walk_anim_name = "Walk"
		add_child(rota)
		feitas += 1

## O circuito em volta do quarteirão `b`, deslocado pra dentro (pista da direita
## / calçada do lado de dentro). O sentido alterna por quarteirão pra a cidade
## não ter todo mundo girando pro mesmo lado.
func _loop(b: Vector2i, is_traffic: bool) -> Array[Vector3]:
	var off: float = lane_offset if is_traffic else sidewalk_offset
	var y: float = 0.02 if is_traffic else walk_y
	var x0: float = streets_x[b.x] + off
	var x1: float = streets_x[b.x + 1] - off
	var z0: float = streets_z[b.y] + off
	var z1: float = streets_z[b.y + 1] - off
	var pts: Array[Vector3] = [
		Vector3(x0, y, z0), Vector3(x1, y, z0),
		Vector3(x1, y, z1), Vector3(x0, y, z1),
	]
	if (b.x + b.y) % 2 == 1:
		pts.reverse()
	return pts
