extends Node
## Entregas: em vez de um comprador fixo num canto do mapa, cada venda
## acontece na frente de uma casa sorteada da cidade, com um NPC esperando
## na calcada. As casas sao registradas no grupo "delivery_house" por
## scripts/CityBlocks.gd, que guarda em cada uma o ponto exato da calcada
## ("front_position") e pra que lado a fachada olha ("front_facing").
## Autoload (singleton) — registrado em project.godot.
##
## Com a RECEPCIONISTA contratada (ver Staff.gd) o mapa passa a ter DOIS
## clientes esperando ao mesmo tempo, e o jogador escolhe pra qual dirigir. E o
## que o nivel 3 do escritorio ja prometia em texto ("recepção: fila de
## clientes") e nao entregava: como cada cliente tem personalidade e preco
## proprios desde 2026-08-09, poder escolher entre dois muda a decisao de
## verdade — cair num Abutre deixa de ser azar sem saida.

const BUYER_SCENE := preload("res://scenes/npc/BuyerNPC.tscn")

## Espera entre fechar uma venda e o proximo cliente aparecer.
@export var next_delivery_delay := 3.0

var _world: Node = null
var _buyers: Array[Node3D] = []
var _last_house: Node = null
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(spawn_delivery)
	add_child(_timer)
	Staff.changed.connect(spawn_delivery)

## Quantos clientes ficam esperando ao mesmo tempo.
func wanted_buyers() -> int:
	return 2 if Staff.has("recepcionista") else 1

## Chamado por Town.gd depois que a cidade ja foi gerada (os filhos de uma
## cena rodam _ready() antes do pai, entao as casas ja estao no grupo aqui).
func start(world: Node) -> void:
	_world = world
	_last_house = null
	_buyers.clear()
	spawn_delivery()

func active_buyers() -> Array[Node3D]:
	var vivos: Array[Node3D] = []
	for b in _buyers:
		if is_instance_valid(b):
			vivos.append(b)
	_buyers = vivos
	return _buyers

func spawn_delivery() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	while active_buyers().size() < wanted_buyers():
		if not _spawn_one():
			return

func _spawn_one() -> bool:
	var houses := get_tree().get_nodes_in_group("delivery_house")
	if houses.is_empty():
		push_warning("DeliveryManager: nenhuma casa no grupo 'delivery_house'")
		return false

	# Nao repete a casa da venda anterior nem a do cliente que ja esta na rua,
	# pra as duas entregas nao cairem na mesma calcada.
	var ocupadas: Array = [_last_house]
	for b in active_buyers():
		ocupadas.append(b.get_meta("delivery_house", null))
	var candidates := houses.filter(func(h: Node) -> bool: return not (h in ocupadas))
	if candidates.is_empty():
		candidates = houses
	var house: Node3D = candidates[randi() % candidates.size()]
	_last_house = house

	var front: Vector3 = house.get_meta("front_position", house.global_position)
	var facing: Vector3 = house.get_meta("front_facing", Vector3.FORWARD)

	var buyer := BUYER_SCENE.instantiate()
	_world.add_child(buyer)
	buyer.global_position = front
	buyer.set_meta("delivery_house", house)
	# look_at aponta o -Z do no pro alvo; a CarZone do BuyerNPC fica no +Z
	# local, entao miramos o oposto da rua pra zona do carro cair na pista.
	if facing.length_squared() > 0.001:
		buyer.look_at(front - facing, Vector3.UP)
	buyer.sale_completed.connect(_on_sale_completed.bind(buyer))
	_buyers.append(buyer)
	return true

func _on_sale_completed(_amount: int, buyer: Node3D) -> void:
	if is_instance_valid(buyer):
		_buyers.erase(buyer)
		buyer.queue_free()
	_timer.start(next_delivery_delay)

## Posicao da entrega (usada pela bussola do HUD via Vehicle.gd). Com dois
## clientes na rua, aponta pro MAIS PERTO de quem esta perguntando — apontar
## sempre pro primeiro faria a bussola mandar atravessar a cidade com um
## cliente na esquina.
func get_delivery_position(from: Vector3 = Vector3.INF) -> Vector3:
	var vivos := active_buyers()
	if vivos.is_empty():
		return Vector3.ZERO
	if from == Vector3.INF:
		var player := get_tree().get_first_node_in_group("player")
		from = (player as Node3D).global_position if player else vivos[0].global_position
	var melhor: Node3D = vivos[0]
	for b in vivos:
		if b.global_position.distance_to(from) < melhor.global_position.distance_to(from):
			melhor = b
	return melhor.global_position

func has_active_delivery() -> bool:
	return not active_buyers().is_empty()
