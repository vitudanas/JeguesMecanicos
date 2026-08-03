extends Node
## Entregas: em vez de um comprador fixo num canto do mapa, cada venda
## acontece na frente de uma casa sorteada da cidade, com um NPC esperando
## na calcada. As casas sao registradas no grupo "delivery_house" por
## scripts/CityBlocks.gd, que guarda em cada uma o ponto exato da calcada
## ("front_position") e pra que lado a fachada olha ("front_facing").
## Autoload (singleton) — registrado em project.godot.

const BUYER_SCENE := preload("res://scenes/npc/BuyerNPC.tscn")

## Espera entre fechar uma venda e o proximo cliente aparecer.
@export var next_delivery_delay := 3.0

var _world: Node = null
var _current_buyer: Node3D = null
var _last_house: Node = null
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(spawn_delivery)
	add_child(_timer)

## Chamado por Town.gd depois que a cidade ja foi gerada (os filhos de uma
## cena rodam _ready() antes do pai, entao as casas ja estao no grupo aqui).
func start(world: Node) -> void:
	_world = world
	_last_house = null
	spawn_delivery()

func spawn_delivery() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	if is_instance_valid(_current_buyer):
		return
	var houses := get_tree().get_nodes_in_group("delivery_house")
	if houses.is_empty():
		push_warning("DeliveryManager: nenhuma casa no grupo 'delivery_house'")
		return

	# Nao repete a casa da venda anterior, pra entrega nao cair sempre no
	# mesmo lugar quando so ha poucas casas.
	var candidates := houses.filter(func(h): return h != _last_house)
	if candidates.is_empty():
		candidates = houses
	var house: Node3D = candidates[randi() % candidates.size()]
	_last_house = house

	var front: Vector3 = house.get_meta("front_position", house.global_position)
	var facing: Vector3 = house.get_meta("front_facing", Vector3.FORWARD)

	var buyer := BUYER_SCENE.instantiate()
	_world.add_child(buyer)
	buyer.global_position = front
	# look_at aponta o -Z do no pro alvo; a CarZone do BuyerNPC fica no +Z
	# local, entao miramos o oposto da rua pra zona do carro cair na pista.
	if facing.length_squared() > 0.001:
		buyer.look_at(front - facing, Vector3.UP)
	buyer.sale_completed.connect(_on_sale_completed)
	_current_buyer = buyer

func _on_sale_completed(_amount: int) -> void:
	if is_instance_valid(_current_buyer):
		_current_buyer.queue_free()
	_current_buyer = null
	_timer.start(next_delivery_delay)

## Posicao da entrega atual (usada pela bussola do HUD via Vehicle.gd).
func get_delivery_position() -> Vector3:
	if is_instance_valid(_current_buyer):
		return _current_buyer.global_position
	return Vector3.ZERO

func has_active_delivery() -> bool:
	return is_instance_valid(_current_buyer)
