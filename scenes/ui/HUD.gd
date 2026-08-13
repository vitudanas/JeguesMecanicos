extends CanvasLayer
## HUD principal: dinheiro do jogador, prompt de interacao contextual,
## progresso da negociacao e uma bussola simples que aponta pro
## objetivo atual (ferro-velho -> oficina -> comprador). Fica no grupo
## "hud" para que Player.gd/Workshop.gd/Vehicle.gd/BuyerNPC.gd consigam
## atualizar sem referencia direta (ver GameManager.set_objective()).

@onready var money_label: Label = $Margin/VBox/MoneyLabel
@onready var prompt_label: Label = $CenterPrompt
@onready var persuasion_bar: ProgressBar = $Margin/VBox/PersuasionBar
@onready var objective_label: Label = $Margin/VBox/ObjectiveLabel
@onready var compass_arrow: Label = $CompassArrow
@onready var fps_label: Label = $FpsLabel

## O contador de FPS e atualizado 4x por segundo, nao a cada quadro: texto
## trocando 60 vezes por segundo e ilegivel (e cada troca remonta o Label).
const FPS_REFRESH := 0.25
var _fps_timer := 0.0

var objective_position: Vector3 = Vector3.ZERO
var has_objective := false
var player: Node = null

## Estado das gambiarras + valor estimado do carro.
##
## Ate agora o jogador dirigia CEGO em relacao ao que mais mexe no jogo: o preco
## de venda vai de 40%% a 100%% do valor base conforme as pecas intactas, e cada
## peca quebrada ainda reduz a chance de uma contraproposta — e nada disso
## aparecia na tela. Quebrar uma gambiarra num buraco era um evento invisivel.
##
## Criado em codigo, e nao adicionado ao HUD.tscn: mexer a mao num `.tscn` ja
## custou caro neste projeto.
var damage_label: Label = null
## Resumo da rodada de negociacao. A barra so mostra quanto a oferta subiu; sem
## o numero, ela seria decoracao e o jogador nao saberia quanto [E] aceita.
var negotiation_label: Label = null

func _build_damage_label() -> void:
	damage_label = Label.new()
	damage_label.add_theme_font_size_override("font_size", 18)
	damage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	damage_label.add_theme_constant_override("outline_size", 5)
	damage_label.visible = false
	money_label.get_parent().add_child(damage_label)
	money_label.get_parent().move_child(damage_label, money_label.get_index() + 1)

func _build_negotiation_label() -> void:
	negotiation_label = Label.new()
	negotiation_label.add_theme_font_size_override("font_size", 18)
	negotiation_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	negotiation_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	negotiation_label.add_theme_constant_override("outline_size", 5)
	negotiation_label.visible = false
	persuasion_bar.get_parent().add_child(negotiation_label)
	persuasion_bar.get_parent().move_child(negotiation_label, persuasion_bar.get_index())

## Cor do texto conta a historia antes da leitura: verde inteiro, amarelo
## arranhado, vermelho caindo aos pedacos.
func _update_damage() -> void:
	if damage_label == null:
		return
	var v: Node = GameManager.active_vehicle
	if v == null or not is_instance_valid(v):
		damage_label.visible = false
		return
	var total: int = v.total_attach_points()
	if total <= 0:
		damage_label.visible = false
		return
	var intact: int = v.intact_part_count()
	damage_label.visible = true
	if v.is_wrecked:
		damage_label.text = "Gambiarras %d/%d — carro incompleto" % [intact, total]
		damage_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		return
	var ratio := float(intact) / float(total)
	damage_label.text = "Gambiarras %d/%d · vale ~R$ %d" % [
		intact, total, Economy.market_value(v.model_key, v.condition, intact, total,
			v.parts, v.installed_options)]
	var color := Color(0.55, 0.92, 0.55)
	if ratio < 0.5:
		color = Color(0.95, 0.45, 0.40)
	elif ratio < 1.0:
		color = Color(0.98, 0.83, 0.35)
	damage_label.add_theme_color_override("font_color", color)

func _ready() -> void:
	add_to_group("hud")
	_build_damage_label()
	_build_negotiation_label()
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.reputation_changed.connect(_on_reputation_changed)
	GameManager.persuasion_updated.connect(_on_persuasion_updated)
	GameManager.negotiation_updated.connect(_on_negotiation_updated)
	GameManager.objective_changed.connect(_on_objective_changed)
	_on_money_changed(GameManager.money)
	prompt_label.text = ""
	persuasion_bar.visible = false
	compass_arrow.pivot_offset = compass_arrow.size / 2.0
	player = get_tree().get_first_node_in_group("player")
	_on_objective_changed(GameManager.objective_position, GameManager.objective_label)

func _on_money_changed(amount: int) -> void:
	money_label.text = "R$ %d  ·  reputação %d" % [amount, GameManager.reputation]

func _on_reputation_changed(_value: int) -> void:
	_on_money_changed(GameManager.money)

func _on_persuasion_updated(active: bool, progress: float) -> void:
	persuasion_bar.visible = active
	persuasion_bar.value = progress * 100.0

func _on_negotiation_updated(active: bool, summary: String) -> void:
	if negotiation_label == null:
		return
	negotiation_label.visible = active
	negotiation_label.text = summary

func _on_objective_changed(position: Vector3, label: String) -> void:
	objective_position = position
	has_objective = label != ""
	objective_label.text = label
	compass_arrow.visible = has_objective

func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""

func _process(delta: float) -> void:
	_update_fps(delta)
	_update_damage()
	if not has_objective:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var to_target: Vector3 = objective_position - player.global_position
	to_target.y = 0.0
	if to_target.length() < 1.0:
		return
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	var angle: float = forward.signed_angle_to(to_target, Vector3.UP)
	compass_arrow.rotation = -angle

## Contador de FPS no canto inferior esquerdo. Verde acima de 50, amarelo entre
## 30 e 50, vermelho abaixo — assim da pra ver de relance, jogando, ONDE o mapa
## fica pesado, sem precisar ler o numero.
func _update_fps(delta: float) -> void:
	# Respeita o menu de graficos, mas so mexe na visibilidade quando ela muda:
	# escrever `visible` todo quadro forca o Label a revalidar o layout.
	var want: bool = GraphicsSettings.show_fps
	if fps_label.visible != want:
		fps_label.visible = want
	if not want:
		return
	_fps_timer += delta
	if _fps_timer < FPS_REFRESH:
		return
	_fps_timer = 0.0
	var fps: int = int(round(Engine.get_frames_per_second()))
	fps_label.text = "%d FPS" % fps
	if fps >= 50:
		fps_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.72))
	elif fps >= 30:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	else:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
