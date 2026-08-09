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
	# de cliente numa decisao em vez de um rotulo: da pra ver que o Colecionador
	# paga o dobro do Pao-duro pelo mesmo carro, e que uma gambiarra quebrada
	# derruba muito mais a oferta dele.
	return "Vender para o %s — R$ %d [E]  (%s)" % [
		nome, _offer(), client.get("dica", "")]

## Nome e dica do cliente, pra bussola/objetivo. Saber QUEM esta esperando antes
## de sair da oficina e o que transforma o tipo de cliente numa decisao: da pra
## caprichar nas gambiarras se for o Colecionador, ou entregar do jeito que
## esta se for o Apressado.
func client_label() -> String:
	return "%s (%s)" % [client.get("nome", "Cliente"), client.get("dica", "")]

## Oferta deste cliente pelo carro que esta na zona.
func _offer() -> int:
	if nearby_vehicle == null:
		return 0
	# Valor do CARRO (modelo + km + lataria + pintura), nao mais um preco fixo
	# igual pra qualquer carcaca.
	var market: int = Economy.market_value(nearby_vehicle.model_key,
		nearby_vehicle.condition, nearby_vehicle.intact_part_count(),
		nearby_vehicle.total_attach_points(), nearby_vehicle.parts)
	return Economy.offer(client, market)

func interact(player: Node) -> void:
	if nearby_vehicle == null or minigame_running:
		return
	active_player = player
	minigame_running = true
	persuasion.fill_rate = float(client.get("enche", 0.45))
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
	if nearby_vehicle:
		amount = _offer()
	GameManager.register_sale(amount)
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
