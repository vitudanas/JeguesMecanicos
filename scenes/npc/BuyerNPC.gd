extends StaticBody3D
## NPC comprador (StaticBody3D para ser detectado direto pelo raycast
## de interacao do jogador, sem precisar de um corpo filho separado). Fica parado numa area de entrega; quando o jogador
## encosta o carro (recem-montado) na CarZone e interage com o NPC,
## comeca o minigame de labia: segure E para "convencer" antes que o
## tempo acabe (gambiarras quebradas drenam a barra mais rapido).

signal sale_completed(amount: int)

## Visual do cliente: mesmo personagem dos pedestres (ver CharacterVisual.gd),
## sorteando entre homem e mulher pra cada entrega nao ser sempre igual.
const MODELS: Array[String] = [
	"res://assets/quaternius/characters-dressed/Male_Dressed.glb",
	"res://assets/quaternius/characters-dressed/Female_Dressed.glb",
]
const IDLE_ANIM := "res://assets/quaternius/universal-animation-library-1/Animations/UAL1_Standard.glb"

@onready var car_zone: Area3D = $CarZone

var persuasion := PersuasionMinigame.new()
## Tipo deste cliente (ver Economy.CLIENTS). Sorteado uma vez, na hora em que
## ele aparece — nao a cada frame, senao o prompt ficaria trocando de nome na
## cara do jogador.
var client: Dictionary = {}
## Quanto o jogador está PEDINDO, como fração do valor de mercado.
##
## É a mecânica das duas inspirações: o cliente nunca paga acima do que você
## pediu, então pedir alto é a única forma de tirar o máximo dele — mas cobra o
## preço em dificuldade (ver `_difficulty()`). Pedir barato fecha fácil e deixa
## dinheiro na mesa. Essa é a escolha; antes não havia nenhuma.
## A faixa PRECISA começar abaixo do cliente mais pão-duro (0.62 do Abutre),
## senão o degrau mais baixo já fica acima do que ele topa: aí o teto é sempre o
## dele, pedir caro só atrapalha, e não existe decisão nenhuma — foi exatamente
## o que o teste flagrou com [0.85 … 1.35].
const ASK_STEPS: Array[float] = [0.58, 0.85, 1.15, 1.45]
const ASK_LABELS: Array[String] = ["de graça", "camarada", "puxado", "cara de pau"]
var ask_step := 1
var nearby_vehicle: Node = null
var active_player: Node = null
var minigame_running := false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("buyer")
	car_zone.body_entered.connect(_on_car_entered)
	car_zone.body_exited.connect(_on_car_exited)
	persuasion.succeeded.connect(_on_success)
	persuasion.failed.connect(_on_failed)
	client = Economy.random_client()
	_load_visual()

## Troca a capsula placeholder por um personagem de verdade, parado em "Idle"
## esperando a entrega.
func _load_visual() -> void:
	var i := randi() % MODELS.size()
	var visual := CharacterVisual.build(self, load(MODELS[i]) as PackedScene,
			randf_range(0.94, 1.06))
	if visual == null:
		return
	# Cada entrega e um cliente diferente: corpo e cores sorteados igual aos
	# pedestres (ver CharacterVisual.gd).
	CharacterVisual.randomize_appearance(visual)
	var idle := CharacterVisual.extract_animation(load(IDLE_ANIM) as PackedScene, "Idle")
	if idle:
		var lib := AnimationLibrary.new()
		lib.add_animation("idle", idle)
		var player := AnimationPlayer.new()
		visual.add_child(player)
		player.add_animation_library("", lib)
		player.play("idle")
	var placeholder: MeshInstance3D = get_node_or_null("MeshVisual")
	if placeholder:
		placeholder.visible = false

func get_interact_prompt() -> String:
	var nome: String = client.get("nome", "Cliente")
	if minigame_running:
		return "Segure [E] para convencer o %s!" % nome
	if nearby_vehicle == null:
		return "%s (%s) — traga um carro consertado ate aqui" % [nome, client.get("dica", "")]
	# Com o carro na zona da pra dizer o valor EXATO. E o que transforma o tipo
	# de cliente numa decisao em vez de um rotulo.
	var aviso := ""
	if asking() > _client_max():
		aviso = "  ·  acima do que ele topa — vai custar lábia"
	return "%s (%s)\nPedindo %s: R$ %d  ·  [Q] mudar preço%s\n[E] começar a conversa" % [
		nome, client.get("dica", ""), ASK_LABELS[ask_step], asking(), aviso]

## Q no cliente: muda o preço pedido, antes de começar a conversa.
func negotiate() -> void:
	if minigame_running or nearby_vehicle == null:
		return
	ask_step = (ask_step + 1) % ASK_STEPS.size()
	AudioManager.play_ui("passar", -8.0)

## Nome e dica do cliente, pra bussola/objetivo. Saber QUEM esta esperando antes
## de sair da oficina e o que transforma o tipo de cliente numa decisao: da pra
## caprichar nas gambiarras se for o Colecionador, ou entregar do jeito que
## esta se for o Apressado.
func client_label() -> String:
	return "%s (%s)" % [client.get("nome", "Cliente"), client.get("dica", "")]

## Valor de mercado do carro que está na zona.
func _market() -> int:
	if nearby_vehicle == null:
		return 0
	return Economy.market_value(nearby_vehicle.model_key, nearby_vehicle.condition,
		nearby_vehicle.intact_part_count(), nearby_vehicle.total_attach_points(),
		nearby_vehicle.parts, nearby_vehicle.installed_options)

## Quanto o jogador está pedindo.
func asking() -> int:
	return int(round(float(_market()) * ASK_STEPS[ask_step]))

## O TETO da negociação é o menor entre o que o cliente toparia e o que foi
## pedido — pedir barato é dinheiro jogado fora, exatamente como nos jogos de
## referência.
func _ceiling() -> int:
	return mini(asking(), _client_max())

func _client_max() -> int:
	return int(round(Economy.offer(client, _market())
		* Dealership.office_bonus() * Economy.reputation_bonus()))

## Pedir acima do que o cliente aceitaria torna a lábia mais difícil: a barra
## enche mais devagar quanto maior o exagero. É o custo de pedir caro — sem ele,
## pedir o máximo seria sempre certo.
func _difficulty() -> float:
	var teto := _client_max()
	if teto <= 0:
		return 1.0
	var exagero := float(asking()) / float(teto)
	return clampf(1.0 / maxf(exagero, 1.0), 0.45, 1.0)

## Oferta deste cliente pelo carro que esta na zona.
func _offer() -> int:
	if nearby_vehicle == null:
		return 0
	return _ceiling()

func interact(player: Node) -> void:
	if nearby_vehicle == null or minigame_running:
		return
	active_player = player
	minigame_running = true
	persuasion.fill_rate = float(client.get("enche", 0.45)) * _difficulty()
	persuasion.drain_rate = float(client.get("esvazia", 0.15))
	persuasion.start(float(client.get("paciencia", 8.0)))

func _process(delta: float) -> void:
	if not minigame_running:
		return
	var holding := Input.is_key_pressed(KEY_E)
	var penalty := 0.0
	if nearby_vehicle:
		var intact: int = nearby_vehicle.intact_part_count()
		var total: int = nearby_vehicle.total_attach_points()
		penalty = Economy.damage_penalty(intact, total) * float(client.get("implica", 1.0))
	persuasion.update(delta, holding, penalty)
	GameManager.persuasion_updated.emit(true, persuasion.progress)

func _on_success() -> void:
	minigame_running = false
	# Fechar a venda e o unico momento em que o loop inteiro se paga — e o som
	# que confirma isso, entao vem mais alto que o resto da interface.
	AudioManager.play_ui("confirma", 0.0)
	var amount := 200
	var escondido := 0
	if nearby_vehicle:
		amount = _offer()
		# O cliente leva o carro e SÓ DEPOIS descobre o defeito. É aqui que
		# esconder problema cobra o preço — sem isso, não diagnosticar seria
		# sempre a jogada certa.
		escondido = Economy.reputation_hit(nearby_vehicle.parts)
	GameManager.register_sale(amount)
	if escondido > 0:
		GameManager.add_reputation(-escondido)
	else:
		GameManager.add_reputation(3)
	GameManager.persuasion_updated.emit(false, 0.0)
	GameManager.clear_objective()
	sale_completed.emit(amount)
	if active_player and active_player.has_method("exit_vehicle"):
		active_player.exit_vehicle()
	if nearby_vehicle and is_instance_valid(nearby_vehicle):
		nearby_vehicle.queue_free()
	nearby_vehicle = null

func _on_failed() -> void:
	minigame_running = false
	AudioManager.play_ui("erro", -4.0)
	GameManager.persuasion_updated.emit(false, 0.0)

func _on_car_entered(body: Node) -> void:
	if body.is_in_group("vehicle"):
		nearby_vehicle = body

func _on_car_exited(body: Node) -> void:
	if body == nearby_vehicle:
		nearby_vehicle = null
