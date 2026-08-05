extends CanvasLayer
## Menu de pause: Esc abre/fecha de qualquer lugar do jogo (a pe ou dirigindo),
## pausa a arvore inteira (get_tree().paused) e solta o mouse pra clicar nos
## botoes. Fica em process_mode ALWAYS pra continuar recebendo o Esc mesmo com
## o jogo pausado.

## Script, nao cena: ver o comentario em SettingsMenu._ready().
const SETTINGS_SCRIPT := preload("res://scenes/ui/SettingsMenu.gd")

@onready var panel: Control = $Panel

var _settings: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	$Panel/VBox/ResumeButton.pressed.connect(_resume)
	$Panel/VBox/SettingsButton.pressed.connect(_open_settings)
	$Panel/VBox/MainMenuButton.pressed.connect(_go_to_main_menu)
	$Panel/VBox/QuitButton.pressed.connect(_quit)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Com a tela de graficos aberta, Esc fecha ELA e volta pro pause, em vez
		# de despausar o jogo por baixo dela.
		if _settings != null:
			_close_settings()
			return
		if get_tree().paused:
			_resume()
		else:
			_pause()

## Ajustar grafico com o jogo pausado e o caso util: da pra ver o efeito no
## cenario atras e comparar sem ter que sair pro menu principal.
func _open_settings() -> void:
	if _settings != null:
		return
	_settings = Control.new()
	_settings.set_script(SETTINGS_SCRIPT)
	_settings.back_pressed.connect(_close_settings)
	add_child(_settings)
	panel.visible = false

func _close_settings() -> void:
	if _settings == null:
		return
	_settings.queue_free()
	_settings = null
	panel.visible = true

func _pause() -> void:
	get_tree().paused = true
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	get_tree().paused = false
	panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _quit() -> void:
	get_tree().quit()
