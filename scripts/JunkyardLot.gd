extends Node3D
## O ferro-velho como LOTE: varias carcacas a venda ao mesmo tempo, e o lote se
## repoe sozinho.
##
## Antes havia UMA carcaca, posta a mao dentro do `Junkyard.tscn`, e ela nunca
## voltava: quem vendesse o primeiro carro achava o ferro-velho vazio pra
## sempre — o unico outro carro do mapa vinha do `EventManager`, largado ao
## acaso pela cidade. Ou seja, o jogo tinha exatamente um ciclo de garimpo.
##
## Com lote, garimpar vira o que e nas duas inspiracoes (ver "Referencia de
## design" no CLAUDE.md): varias ofertas lado a lado, cada uma com o proprio
## modelo, estado e preco, e a escolha e do jogador. Como `Vehicle.gd` ja
## sorteia modelo, quilometragem, lataria, pintura e defeito mecanico por
## carcaca, o lote sai variado de graca — o unico trabalho aqui e manter as
## vagas cheias.

## Onde cada carcaca fica, em coordenadas locais (x, z) e o angulo em que ela
## esta largada. Posicoes escolhidas pra nao encostar nos caixotes que ja
## existem no `Junkyard.tscn` (em (-3,-2), (3,2.2) e (-2.5,2.5)).
const SPOTS: Array = [
	{"pos": Vector2(0.0, 0.0), "yaw": 0.0},
	{"pos": Vector2(5.2, -1.2), "yaw": 12.0},
	{"pos": Vector2(-5.6, 1.2), "yaw": -9.0},
]
const VEHICLE_SCENE := preload("res://scenes/vehicle/Vehicle.tscn")

## Quanto tempo o dono leva pra arrastar outra carcaca pra vaga vazia. Longo o
## bastante pra o lote nao ser infinito na hora, curto o bastante pra quem
## voltar de uma entrega ja achar carro novo.
@export var restock_seconds := 25.0
## Raio em que a vaga conta como ocupada. Maior que meio carro (2.1 m) de
## proposito: carcaca comprada e ainda nao rebocada continua ali, e o dono nao
## empilharia outra por cima.
@export var clear_radius := 3.4
## Modelo fixo (deixe vazio pra sortear). Serve pro verificador, que precisa de
## um carro de tamanho conhecido pra medir mira e reboque.
@export var forced_model: PackedScene = null

var _timer: Timer

func _ready() -> void:
	add_to_group("junkyard")
	_timer = Timer.new()
	_timer.wait_time = restock_seconds
	_timer.timeout.connect(restock_now)
	add_child(_timer)
	_timer.start()
	restock_now()

## Enche toda vaga que estiver livre. Publico porque tambem e o que o
## verificador usa pra montar um lote conhecido.
func restock_now() -> void:
	for spot: Dictionary in SPOTS:
		var local: Vector2 = spot["pos"]
		if _occupied(local):
			continue
		_spawn(local, float(spot["yaw"]))

## Vaga ocupada = tem QUALQUER veiculo por perto, e nao "o carro que eu spawnei
## ainda existe". A diferenca importa: a carcaca comprada continua parada ali
## ate ser rebocada, e o dono nao poria outra em cima dela.
func _occupied(local: Vector2) -> bool:
	var center := to_global(Vector3(local.x, 0.0, local.y))
	for v in get_tree().get_nodes_in_group("vehicle"):
		var p: Vector3 = (v as Node3D).global_position
		if Vector2(p.x - center.x, p.z - center.z).length() < clear_radius:
			return true
	return false

func _spawn(local: Vector2, yaw: float) -> void:
	var wreck := VEHICLE_SCENE.instantiate()
	wreck.is_wrecked = true
	if forced_model:
		wreck.car_model = forced_model
	add_child(wreck)
	(wreck as Node3D).position = Vector3(local.x, 1.0, local.y)
	(wreck as Node3D).rotation.y = deg_to_rad(yaw)
