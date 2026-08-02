extends CanvasLayer
## Menu de pause: Esc abre/fecha de qualquer lugar do jogo (a pe ou dirigindo),
## pausa a arvore inteira (get_tree().paused) e solta o mouse pra clicar nos
## botoes. Fica em process_mode ALWAYS pra continuar recebendo o Esc mesmo com
## o jogo pausado.

@onready var panel: Control = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	$Panel/VBox/ResumeButton.pressed.connect(_resume)
	$Panel/VBox/MainMenuButton.pressed.connect(_go_to_main_menu)
	$Panel/VBox/QuitButton.pressed.connect(_quit)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if get_tree().paused:
			_resume()
		else:
			_pause()

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
