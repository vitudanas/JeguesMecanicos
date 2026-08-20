extends CanvasLayer
## HUD principal: dinheiro do jogador, prompt de interacao contextual,
## progresso da negociacao e uma bussola simples que aponta pro
## objetivo atual (ferro-velho -> oficina -> comprador). Fica no grupo
## "hud" para que Player.gd/Workshop.gd/Vehicle.gd/BuyerNPC.gd consigam
## atualizar sem referencia direta (ver GameManager.set_objective()).

const MINIMAP_SCRIPT := preload("res://scenes/ui/Minimap.gd")

@onready var money_label: Label = $Margin/VBox/MoneyLabel
@onready var status_panel: Panel = $StatusPanel
@onready var prompt_label: Label = $CenterPrompt
@onready var persuasion_bar: ProgressBar = $Margin/VBox/PersuasionBar
@onready var objective_label: Label = $Margin/VBox/ObjectiveLabel
@onready var compass_arrow: Label = $CompassArrow
@onready var compass_distance: Label = $CompassDistance
@onready var fps_label: Label = $FpsLabel
@onready var prompt_panel: Panel = $PromptPanel
@onready var world_status_label: Label = $WorldStatusPanel/WorldStatusVBox/WorldStatusLabel
@onready var stage_label: Label = $WorldStatusPanel/WorldStatusVBox/StageLabel
@onready var speed_panel: Panel = $SpeedPanel
@onready var speed_label: Label = $SpeedPanel/SpeedVBox/SpeedLabel
@onready var vehicle_state_label: Label = $SpeedPanel/SpeedVBox/VehicleStateLabel

## O contador de FPS e atualizado 4x por segundo, nao a cada quadro: texto
## trocando 60 vezes por segundo e ilegivel (e cada troca remonta o Label).
const FPS_REFRESH := 0.25
var _fps_timer := 0.0
var _vehicle_hud_timer := 0.0

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
## Radar local leve: desenhado em Canvas, sem segunda camera renderizando o
## mundo. Fica publico para os testes de fluxo cobrarem navegacao de verdade.
var minimap = null

func _build_minimap() -> void:
	minimap = Control.new()
	minimap.name = "Minimap"
	minimap.set_script(MINIMAP_SCRIPT)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -198.0
	minimap.offset_top = 95.0
	minimap.offset_right = -18.0
	minimap.offset_bottom = 275.0
	add_child(minimap)

func _build_damage_label() -> void:
	damage_label = Label.new()
	damage_label.add_theme_font_size_override("font_size", 13)
	damage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	damage_label.add_theme_constant_override("outline_size", 5)
	damage_label.visible = false
	money_label.get_parent().add_child(damage_label)
	money_label.get_parent().move_child(damage_label, money_label.get_index() + 1)

func _build_negotiation_label() -> void:
	negotiation_label = Label.new()
	negotiation_label.add_theme_font_size_override("font_size", 13)
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
	_build_minimap()
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.reputation_changed.connect(_on_reputation_changed)
	GameManager.persuasion_updated.connect(_on_persuasion_updated)
	GameManager.negotiation_updated.connect(_on_negotiation_updated)
	GameManager.objective_changed.connect(_on_objective_changed)
	GameManager.car_sold.connect(_on_car_sold)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	_on_money_changed(GameManager.money)
	_update_world_status()
	prompt_label.text = ""
	persuasion_bar.visible = false
	compass_arrow.pivot_offset = compass_arrow.size / 2.0
	player = get_tree().get_first_node_in_group("player")
	minimap.set_player(player)
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
	compass_distance.visible = has_objective
	if minimap != null:
		minimap.set_objective(position, has_objective)
	_update_stage(label)

func _on_car_sold(_amount: int) -> void:
	_update_world_status()

func _on_weather_changed(_raining: bool) -> void:
	_update_world_status()

func _update_world_status() -> void:
	var weather := "CHUVA / PISO LISO" if WeatherManager.is_raining else "TEMPO SECO"
	var sales := "%d VENDA" % GameManager.cars_sold
	if GameManager.cars_sold != 1:
		sales += "S"
	world_status_label.text = "%s  •  %s" % [weather, sales]

func _update_stage(label: String) -> void:
	var upper := label.to_upper()
	var stage := "GARIMPO"
	if upper.contains("OFICINA") or upper.contains("CONSERT") or upper.contains("REBOC"):
		stage = "OFICINA"
	elif upper.contains("ENTREG") or upper.contains("CASA") or upper.contains("COMPRADOR"):
		stage = "ENTREGA"
	stage_label.text = "ETAPA  ·  " + stage

func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""
	prompt_panel.visible = text != ""
	# Negociacao usa tres linhas; interacoes comuns usam uma. O fundo acompanha
	# o conteudo para nenhuma instrucao ficar solta sobre a imagem.
	var extra := maxi(text.count("\n"), 0) * 20.0
	prompt_panel.offset_top = 24.0 - extra * 0.5
	prompt_panel.offset_bottom = 76.0 + extra * 0.5
	prompt_label.offset_top = 29.0 - extra * 0.5
	prompt_label.offset_bottom = 71.0 + extra * 0.5

func _process(delta: float) -> void:
	_update_fps(delta)
	_update_damage()
	_update_vehicle_hud(delta)
	# O painel acompanha o conteudo real: objetivo curto deixa o mundo visivel;
	# negociacao e texto em duas linhas ganham altura sem vazar para fora.
	var wanted_bottom := 158.0
	if damage_label and damage_label.visible:
		wanted_bottom += 21.0
	if negotiation_label and negotiation_label.visible:
		wanted_bottom += 34.0
	if objective_label.text.count("\n") > 0:
		wanted_bottom += 20.0
	status_panel.offset_bottom = move_toward(status_panel.offset_bottom, wanted_bottom,
		delta * 420.0)
	if not has_objective:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var to_target: Vector3 = objective_position - player.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance >= 1000.0:
		compass_distance.text = "%.1f km" % (distance / 1000.0)
	else:
		compass_distance.text = "%d m" % int(round(distance))
	if to_target.length() < 1.0:
		return
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	var angle: float = forward.signed_angle_to(to_target, Vector3.UP)
	compass_arrow.rotation = -angle

## Velocimetro aparece apenas quando realmente existe alguem dirigindo o carro
## ativo. Fora dele o canto inferior direito fica livre, em vez de mostrar um
## zero permanente que nao ajuda durante compra, oficina ou negociacao.
func _update_vehicle_hud(delta: float) -> void:
	_vehicle_hud_timer += delta
	if _vehicle_hud_timer < 0.10:
		return
	_vehicle_hud_timer = 0.0
	var v: Node = GameManager.active_vehicle
	var driving := v != null and is_instance_valid(v) and v.driver != null
	speed_panel.visible = driving
	if not driving:
		return
	var meters_per_second: float = absf(float(v.forward_speed()))
	var signed_speed: float = float(v.forward_speed())
	speed_label.text = "%03d km/h" % int(round(meters_per_second * 3.6))
	var gear := "R" if signed_speed < -0.5 else "D"
	var health := "AVARIADO" if v.is_wrecked else "RODANDO"
	vehicle_state_label.text = "MARCHA %s  •  %s" % [gear, health]

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
