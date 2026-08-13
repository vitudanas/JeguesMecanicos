extends StaticBody3D
## NPC comprador. Fica numa area de entrega e negocia o carro que estiver na
## CarZone.
##
## A conversa agora e feita em rodadas: o cliente abre abaixo do teto, e o
## jogador pode aceitar [E], fazer uma contraproposta [Q] ou blefar [F]. As
## probabilidades sao mostradas antes da escolha e mudam com personalidade,
## reputacao, preco pedido e estado das gambiarras.

signal sale_completed(amount: int)

## Visual do cliente: mesmo personagem dos pedestres (ver CharacterVisual.gd),
## sorteando entre homem e mulher pra cada entrega nao ser sempre igual.
const MODELS: Array[String] = [
	"res://assets/quaternius/characters-dressed/Male_Dressed.glb",
	"res://assets/quaternius/characters-dressed/Female_Dressed.glb",
]
const IDLE_ANIM := "res://assets/quaternius/universal-animation-library-1/Animations/UAL1_Standard.glb"

## Cada rodada ja usada torna a proxima contraproposta um pouco mais dificil:
## insistir ate o fim nao pode ser uma sequencia automatica de Q.
const ROUND_PRESSURE := 0.08
## Reputacao 0/100 tira/acrescenta esta chance em torno do ponto neutro 50.
const REPUTATION_CHANCE_SWING := 0.12
## Pedir acima do teto e gambiarra quebrada reduzem a chance, mas nunca a zero;
## o valor exato sempre aparece no prompt.
const EXAGGERATION_CHANCE_WEIGHT := 0.42
const DAMAGE_CHANCE_WEIGHT := 0.18

@onready var car_zone: Area3D = $CarZone

var negotiation := PersuasionMinigame.new()
## Tipo deste cliente (ver Economy.CLIENTS). Sorteado uma vez quando ele nasce,
## nao a cada frame, senao oferta e prompt trocariam na cara do jogador.
var client: Dictionary = {}
## Quanto o jogador esta PEDINDO, como fracao do valor de mercado.
##
## A faixa comeca abaixo do cliente mais pao-duro (0.62 do Abutre): assim pedir
## barato pode fechar perto do pedido, enquanto pedir alto abre espaco para uma
## negociacao mais lucrativa e arriscada.
const ASK_STEPS: Array[float] = [0.58, 0.85, 1.15, 1.45]
const ASK_LABELS: Array[String] = ["de graça", "camarada", "puxado", "cara de pau"]
var ask_step := 1
var nearby_vehicle: Node = null
var active_player: Node = null
## Nome preservado porque verificadores e integracoes antigas o leem. Agora
## significa "conversa em rodadas aberta", nao barra baseada em tempo.
var minigame_running := false
var last_action := ""

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("buyer")
	car_zone.body_entered.connect(_on_car_entered)
	car_zone.body_exited.connect(_on_car_exited)
	client = Economy.random_client()
	_load_visual()

func _exit_tree() -> void:
	if minigame_running:
		_hide_negotiation_ui()

## Troca a capsula placeholder por um personagem de verdade, parado em Idle.
func _load_visual() -> void:
	var i := randi() % MODELS.size()
	var visual := CharacterVisual.build(self, load(MODELS[i]) as PackedScene,
			randf_range(0.94, 1.06))
	if visual == null:
		return
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
		var line := "%s oferece R$ %d · você pediu R$ %d" % [
			nome, negotiation.current_offer, asking()]
		var controls := "[E] aceitar"
		if negotiation.rounds_left > 0 and negotiation.current_offer < negotiation.ceiling:
			controls += " · [Q] contrapropor (%d%%)" % int(round(_counter_chance() * 100.0))
			if negotiation.can_bluff():
				controls += " · [F] blefar (%d%%)" % int(round(_bluff_chance() * 100.0))
			controls += " · %d rodada(s)" % negotiation.rounds_left
		else:
			controls += " · oferta final"
		return "%s\n%s\n%s" % [line, last_action, controls]
	if nearby_vehicle == null:
		return "%s (%s) — traga um carro consertado ate aqui" % [nome, client.get("dica", "")]
	# Com o carro na zona da pra dizer o valor EXATO. E o que transforma o tipo
	# de cliente numa decisao em vez de um rotulo.
	var aviso := ""
	if asking() > _client_max():
		aviso = "  ·  acima do que ele costuma pagar"
	return "%s (%s)\nPedindo %s: R$ %d  ·  [Q] mudar preço%s\n[E] ouvir a oferta" % [
		nome, client.get("dica", ""), ASK_LABELS[ask_step], asking(), aviso]

## Q muda o preco antes da conversa; dentro dela, faz a contraproposta segura.
func negotiate() -> void:
	if nearby_vehicle == null:
		return
	if minigame_running:
		_attempt_counter()
		return
	ask_step = (ask_step + 1) % ASK_STEPS.size()
	AudioManager.play_ui("passar", -8.0)

## F durante a conversa arrisca um salto grande na oferta. O Player chama este
## metodo somente quando o comprador esta na mira.
func bluff() -> void:
	if not minigame_running or not negotiation.can_bluff():
		return
	_resolve_bluff(randf() <= _bluff_chance())

## Nome e dica do cliente, pra bussola/objetivo.
func client_label() -> String:
	return "%s (%s)" % [client.get("nome", "Cliente"), client.get("dica", "")]

## Valor de mercado do carro que esta na zona.
func _market() -> int:
	if nearby_vehicle == null:
		return 0
	return Economy.market_value(nearby_vehicle.model_key, nearby_vehicle.condition,
		nearby_vehicle.intact_part_count(), nearby_vehicle.total_attach_points(),
		nearby_vehicle.parts, nearby_vehicle.installed_options)

func asking() -> int:
	return int(round(float(_market()) * ASK_STEPS[ask_step]))

## Teto da conversa: o menor entre o pedido e o maximo deste cliente.
func _ceiling() -> int:
	return mini(asking(), _client_max())

func _client_max() -> int:
	return int(round(Economy.offer(client, _market())
		* Dealership.office_bonus() * Economy.reputation_bonus()))

func _opening_offer() -> int:
	return maxi(1, int(round(float(_ceiling()) * float(client.get("abre", 0.70)))))

## Oferta que seria aceita agora.
func _offer() -> int:
	if nearby_vehicle == null:
		return 0
	return negotiation.current_offer if minigame_running else _opening_offer()

## Penalidade compartilhada pelas duas jogadas de risco.
func _chance_penalty() -> float:
	var teto := maxi(_client_max(), 1)
	var exagero := maxf(float(asking()) / float(teto) - 1.0, 0.0)
	var damage := 0.0
	if nearby_vehicle:
		damage = Economy.damage_penalty(nearby_vehicle.intact_part_count(),
			nearby_vehicle.total_attach_points()) * float(client.get("implica", 1.0))
	return exagero * EXAGGERATION_CHANCE_WEIGHT + damage * DAMAGE_CHANCE_WEIGHT

func _reputation_chance() -> float:
	return ((float(GameManager.reputation) - 50.0) / 50.0) * REPUTATION_CHANCE_SWING

func _counter_chance() -> float:
	var used := negotiation.max_rounds - negotiation.rounds_left
	return clampf(float(client.get("cede", 0.60)) + _reputation_chance()
		- _chance_penalty() - float(used) * ROUND_PRESSURE, 0.10, 0.95)

func _bluff_chance() -> float:
	return clampf(float(client.get("blefe", 0.25)) + _reputation_chance()
		- _chance_penalty() * 1.25, 0.05, 0.85)

## Primeiro E: abre a conversa. E seguinte: aceita a contraproposta atual.
func interact(player: Node) -> void:
	if nearby_vehicle == null:
		return
	active_player = player
	if minigame_running:
		_complete_sale(negotiation.current_offer)
		return
	minigame_running = true
	negotiation.start(_opening_offer(), _ceiling(), int(client.get("rodadas", 3)))
	last_action = "Oferta inicial — aceite ou tente subir."
	AudioManager.play_ui("abre", -6.0)
	_update_negotiation_ui()

func _attempt_counter() -> void:
	if not negotiation.can_counter():
		return
	_resolve_counter(randf() <= _counter_chance())

## Separados do sorteio para o teste provar os dois resultados sem depender de
## uma semente ou tornar a mecanica previsivel no jogo.
func _resolve_counter(succeeded: bool) -> void:
	var before := negotiation.current_offer
	negotiation.counter(succeeded)
	if succeeded:
		last_action = "Ele cedeu: R$ %d → R$ %d." % [before, negotiation.current_offer]
		AudioManager.play_ui("confirma", -8.0)
	else:
		last_action = "Ele não cedeu; uma rodada foi embora."
		AudioManager.play_ui("erro", -8.0)
	_update_negotiation_ui()

func _resolve_bluff(succeeded: bool) -> void:
	var before := negotiation.current_offer
	negotiation.bluff(succeeded)
	if succeeded:
		last_action = "Caiu no blefe: R$ %d → R$ %d!" % [before, negotiation.current_offer]
		AudioManager.play_ui("confirma", -2.0)
	else:
		last_action = "Pegou o blefe: R$ %d → R$ %d." % [before, negotiation.current_offer]
		AudioManager.play_ui("erro", -2.0)
	_update_negotiation_ui()

func _update_negotiation_ui() -> void:
	GameManager.persuasion_updated.emit(true, negotiation.progress())
	GameManager.negotiation_updated.emit(true,
		"Oferta R$ %d / pedido R$ %d · %d rodada(s)" % [
			negotiation.current_offer, asking(), negotiation.rounds_left])

func _hide_negotiation_ui() -> void:
	GameManager.persuasion_updated.emit(false, 0.0)
	GameManager.negotiation_updated.emit(false, "")

func _cancel_negotiation() -> void:
	if not minigame_running:
		return
	minigame_running = false
	negotiation.stop()
	last_action = ""
	_hide_negotiation_ui()

func _complete_sale(amount: int) -> void:
	minigame_running = false
	negotiation.stop()
	AudioManager.play_ui("confirma", 0.0)
	var escondido := 0
	if nearby_vehicle:
		# O cliente leva o carro e so depois descobre defeito escondido.
		escondido = Economy.reputation_hit(nearby_vehicle.parts)
	GameManager.register_sale(maxi(amount, 1))
	if escondido > 0:
		GameManager.add_reputation(-escondido)
	else:
		GameManager.add_reputation(3)
	_hide_negotiation_ui()
	GameManager.clear_objective()
	sale_completed.emit(maxi(amount, 1))
	if active_player and active_player.has_method("exit_vehicle"):
		active_player.exit_vehicle()
	if nearby_vehicle and is_instance_valid(nearby_vehicle):
		nearby_vehicle.queue_free()
	nearby_vehicle = null

func _on_car_entered(body: Node) -> void:
	if body.is_in_group("vehicle"):
		nearby_vehicle = body

func _on_car_exited(body: Node) -> void:
	if body == nearby_vehicle:
		# O carro pode rolar para fora enquanto o jogador conversa. Manter a
		# oferta aberta nesse estado deixaria E sem efeito (nao ha mais carro) e o
		# HUD preso para sempre. Voltando a estacionar, a conversa comeca de novo.
		_cancel_negotiation()
		nearby_vehicle = null
