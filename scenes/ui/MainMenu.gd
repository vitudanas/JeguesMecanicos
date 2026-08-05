extends Control
## Tela inicial do jogo (cena de entrada em project.godot). So troca de cena —
## nao ha estado global pra resetar aqui ainda (GameManager comeca com os
## valores padrao dele sempre que Main.tscn e carregada do zero).

## Script, nao cena: ver o comentario em SettingsMenu._ready().
const SETTINGS_SCRIPT := preload("res://scenes/ui/SettingsMenu.gd")

var _settings: Control = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/QuitButton.pressed.connect(_on_quit)
	$VBox/PlayButton.grab_focus()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

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
