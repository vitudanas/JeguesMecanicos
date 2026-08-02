extends Control
## Tela inicial do jogo (cena de entrada em project.godot). So troca de cena —
## nao ha estado global pra resetar aqui ainda (GameManager comeca com os
## valores padrao dele sempre que Main.tscn e carregada do zero).

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/QuitButton.pressed.connect(_on_quit)
	$VBox/PlayButton.grab_focus()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_quit() -> void:
	get_tree().quit()
