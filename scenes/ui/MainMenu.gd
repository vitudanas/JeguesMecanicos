extends Control
## Tela inicial do jogo (cena de entrada em project.godot).
##
## O botao "Continuar" e criado EM CODIGO, e nao adicionado ao `.tscn`: mexer a
## mao num `.tscn` ja custou caro aqui (o `script` que faltava neste mesmo
## arquivo em 2026-08-02 deixava o menu inteiro sem funcionar). Criar o botao no
## script tambem resolve sozinho o caso de nao existir save nenhum.

## Script, nao cena: ver o comentario em SettingsMenu._ready().
const SETTINGS_SCRIPT := preload("res://scenes/ui/SettingsMenu.gd")
const LOADING_SCRIPT := preload("res://scenes/ui/LoadingScreen.gd")

var _settings: Control = null
var _loading: Control = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/QuitButton.pressed.connect(_on_quit)
	if SaveGame.has_save:
		_add_continue_button()
		$VBox/PlayButton.text = "Novo jogo"
		$VBox/PlayButton.tooltip_text = "Apaga o progresso salvo e comeca do zero"
	else:
		$VBox/PlayButton.grab_focus()

func _add_continue_button() -> void:
	var button := Button.new()
	button.text = "Continuar  (%s)" % SaveGame.summary()
	button.custom_minimum_size = $VBox/PlayButton.custom_minimum_size
	# Tipo explicito: o projeto trata warning como erro, e `get_theme_font_size`
	# devolve Variant.
	var font_size: int = $VBox/PlayButton.get_theme_font_size("font_size")
	if font_size > 0:
		button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(_on_continue)
	$VBox.add_child(button)
	$VBox.move_child(button, $VBox/PlayButton.get_index())
	button.grab_focus()

func _on_continue() -> void:
	# Os autoloads sobrevivem a troca de cena, entao da pra encher o GameManager
	# ANTES de carregar o mundo — quando o HUD aparecer, o valor ja esta certo.
	SaveGame.apply_to_game()
	_start_game()

## "Novo jogo" apaga o save. Sem isso o jogador comecaria do zero na tela e
## voltaria pro progresso antigo no proximo "Continuar".
func _on_play() -> void:
	SaveGame.clear()
	GameManager.reset()
	Dealership.reset()
	_start_game()

## Entrar no jogo passa pela tela de carregamento: o `Main.tscn` carrega a
## cidade e ainda gera ~175 predios e 44 montanhas em codigo, e sem esta tela o
## botao ficava afundado com a janela parada, sem sinal de vida.
func _start_game() -> void:
	if _loading != null:
		return
	_loading = Control.new()
	_loading.set_script(LOADING_SCRIPT)
	add_child(_loading)

## A tela de graficos e criada na hora e destruida ao voltar: mantida viva por
## tras do menu ela continuaria recebendo clique atraves do painel.
func _on_settings() -> void:
	if _settings != null:
		return
	_settings = Control.new()
	_settings.set_script(SETTINGS_SCRIPT)
	_settings.back_pressed.connect(_on_settings_closed)
	add_child(_settings)

func _on_settings_closed() -> void:
	if _settings == null:
		return
	_settings.queue_free()
	_settings = null
	$VBox/SettingsButton.grab_focus()

func _on_quit() -> void:
	get_tree().quit()
