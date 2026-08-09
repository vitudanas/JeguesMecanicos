extends Area3D
## Ponto de fixacao no carro (capo, radiador, retrovisor, parachoque).
##
## E aqui que a premissa do jogo virou DECISAO. Antes cada ponto tinha uma peca
## fixa e de graca: montar era apertar E quatro vezes, sempre igual — o unico
## sistema do jogo sem nenhuma escolha, justo o que da nome a ele. Agora cada
## ponto oferece tres opcoes do catalogo (ver `Economy.GAMBIARRAS`), no mesmo
## idioma do resto do jogo: **Q troca o item, E instala** (pagando).
##
## O triangulo e honesto: a barata sai quase de graca e cai no primeiro buraco,
## a caprichada aguenta o test-drive e o cliente quase nao desconta — mas ela
## come um pedaco do lucro ANTES de o jogador saber se a venda vai ser boa.

const PART_SCENE := preload("res://scenes/vehicle/parts/GambiarraPart.tscn")

@export var point_name := "hood"
@export var display_name := "Capo"

@onready var marker: MeshInstance3D = $Marker

var vehicle: Node = null
## Qual das tres opcoes esta selecionada. Comeca na do meio, que e a peca que o
## jogo sempre teve — quem nao quiser escolher nada joga como antes.
var option_index := Economy.GAMBIARRA_DEFAULT

func _ready() -> void:
	add_to_group("interactable")
	var attach_points_node := get_parent()
	if attach_points_node:
		vehicle = attach_points_node.get_parent()

func option() -> Dictionary:
	return Economy.gambiarra_option(point_name, option_index)

## Quanto esta opcao custa NESTE carro. Fracao do valor, nunca reais fixos:
## gambiarra de esportivo custa mais que gambiarra de taxi.
func price() -> int:
	if vehicle == null:
		return 0
	return Economy.gambiarra_price(option(),
		Economy.repaired_value(vehicle.model_key, vehicle.condition))

func get_interact_prompt() -> String:
	if vehicle == null:
		return ""
	if vehicle.installed_parts.has(point_name):
		return ""
	var opt := option()
	if opt.is_empty():
		return ""
	var custo := price()
	var linha := "%s: %s — R$ %d (%s)" % [display_name, opt["nome"], custo,
		Economy.gambiarra_grade(opt)]
	if GameManager.money < custo:
		return linha + "\n[Q] trocar item  ·  sem dinheiro pra esta"
	return linha + "\n[E] instalar  ·  [Q] trocar item"

## Q passa pra proxima opcao. Mesma tecla contextual do ferro-velho e do quadro
## de melhorias.
func negotiate() -> void:
	if vehicle == null or vehicle.installed_parts.has(point_name):
		return
	var lista := Economy.gambiarra_options(point_name)
	if lista.size() <= 1:
		return
	option_index = (option_index + 1) % lista.size()
	AudioManager.play_ui("passar", -8.0)

func interact(_player: Node) -> void:
	if vehicle == null:
		return
	if vehicle.installed_parts.has(point_name):
		return
	var opt := option()
	if opt.is_empty():
		return
	var custo := price()
	if GameManager.money < custo:
		AudioManager.play_ui("erro", -4.0)
		return
	GameManager.add_money(-custo)
	var part := PART_SCENE.instantiate()
	get_tree().current_scene.add_child(part)
	part.setup(opt)
	vehicle.install_part(point_name, part, self, opt)
	if marker:
		marker.visible = false
	# Some tambem pro raycast de interacao. O marcador ficava invisivel mas a
	# Area3D continuava ali na frente da carroceria: mirando no carro o jogador
	# pegava um ponto ja usado, cujo prompt e vazio — parecia que o carro tinha
	# parado de responder ao E.
	collision_layer = 0
	monitorable = false
