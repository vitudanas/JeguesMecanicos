extends CanvasLayer
## HUD principal: dinheiro do jogador, prompt de interacao contextual,
## barra de persuasao (labia) e uma bussola simples que aponta pro
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

func _ready() -> void:
	add_to_group("hud")
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.persuasion_updated.connect(_on_persuasion_updated)
	GameManager.objective_changed.connect(_on_objective_changed)
	_on_money_changed(GameManager.money)
	prompt_label.text = ""
	persuasion_bar.visible = false
	compass_arrow.pivot_offset = compass_arrow.size / 2.0
	player = get_tree().get_first_node_in_group("player")
	_on_objective_changed(GameManager.objective_position, GameManager.objective_label)

func _on_money_changed(amount: int) -> void:
	money_label.text = "R$ %d" % amount

func _on_persuasion_updated(active: bool, progress: float) -> void:
	persuasion_bar.visible = active
	persuasion_bar.value = progress * 100.0

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
