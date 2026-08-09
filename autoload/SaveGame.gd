extends Node
## Progresso do jogador, salvo em disco.
##
## Ate agora o jogo nao guardava NADA do que acontecia na partida: so grafico
## (`graphics.cfg`) e som (`audio.cfg`). Quem vendia cinco carros e fechava o
## jogo voltava com os R$ 150 iniciais.
##
## O que e salvo e so o PROGRESSO (dinheiro, carros vendidos), nao o estado do
## mundo. E deliberado: a cidade inteira e gerada por codigo com semente fixa
## (ver CityBlocks/RuralScatter), entao ela ja volta identica sozinha; e a
## posicao exata de cada carcaca e da entrega da vez e justamente o que o jogo
## sorteia de novo a cada partida. Salvar isso seria guardar o que o proprio
## desenho do jogo quer variavel.

signal saved
signal loaded

const PATH := "user://progresso.cfg"
## Sobe quando o formato mudar de um jeito que nao da pra ler o antigo.
const FORMAT := 1

var has_save := false
var money := 0
var cars_sold := 0
var saved_at := 0
## Niveis de cada area da loja (ver Dealership).
var areas: Dictionary = {}
var reputation := GameManager.REPUTATION_START

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_read()
	# Autosave no fim de cada venda: e o unico ponto do loop em que o jogador
	# GANHA algo, entao e onde doi perder. Salvar por tempo pegaria o jogador no
	# meio de um reboque e guardaria um progresso que ele nem sabe que tem.
	GameManager.car_sold.connect(_on_car_sold)

func _on_car_sold(_amount: int) -> void:
	save()

## Grava o estado atual do GameManager.
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("jogo", "formato", FORMAT)
	cfg.set_value("jogo", "dinheiro", GameManager.money)
	cfg.set_value("jogo", "carros_vendidos", GameManager.cars_sold)
	cfg.set_value("jogo", "salvo_em", int(Time.get_unix_time_from_system()))
	cfg.set_value("jogo", "loja", Dealership.to_dict())
	cfg.set_value("jogo", "reputacao", GameManager.reputation)
	if cfg.save(PATH) != OK:
		push_warning("SaveGame: nao consegui gravar em %s" % PATH)
		return
	has_save = true
	money = GameManager.money
	cars_sold = GameManager.cars_sold
	saved_at = int(Time.get_unix_time_from_system())
	areas = Dealership.to_dict()
	reputation = GameManager.reputation
	saved.emit()

## Joga o progresso salvo dentro do GameManager. Chamado ao entrar no jogo por
## "Continuar".
func apply_to_game() -> void:
	if not has_save:
		return
	GameManager.money = money
	GameManager.cars_sold = cars_sold
	GameManager.reputation = reputation
	GameManager.reputation_changed.emit(reputation)
	Dealership.from_dict(areas)
	# Emitir o sinal e o que faz o HUD mostrar o valor certo: ele nao le o campo,
	# ele escuta a mudanca.
	GameManager.money_changed.emit(GameManager.money)
	loaded.emit()

## Zera o progresso (botao "Novo jogo").
func clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	has_save = false
	money = 0
	cars_sold = 0
	saved_at = 0
	areas = {}
	reputation = GameManager.REPUTATION_START

func _read() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	# Formato de outra versao: melhor comecar limpo que carregar meia coisa.
	if int(cfg.get_value("jogo", "formato", 0)) != FORMAT:
		return
	money = int(cfg.get_value("jogo", "dinheiro", 0))
	cars_sold = int(cfg.get_value("jogo", "carros_vendidos", 0))
	saved_at = int(cfg.get_value("jogo", "salvo_em", 0))
	areas = cfg.get_value("jogo", "loja", {})
	reputation = int(cfg.get_value("jogo", "reputacao", GameManager.REPUTATION_START))
	has_save = true

## Texto curto pro botao Continuar ("R$ 480 · 3 carros").
func summary() -> String:
	if not has_save:
		return ""
	return "R$ %d · %d carro%s vendido%s" % [money, cars_sold,
		"" if cars_sold == 1 else "s", "" if cars_sold == 1 else "s"]
