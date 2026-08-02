extends GPUParticles3D
## Chuva: segue o jogador (fica sempre "no ceu" acima dele, view-independente
## de onde ele anda) e liga/desliga sozinha conforme
## WeatherManager.weather_changed. Ver autoload/WeatherManager.gd.

@export var height_offset := 8.0

var player: Node3D = null

func _ready() -> void:
	emitting = WeatherManager.is_raining
	WeatherManager.weather_changed.connect(_on_weather_changed)
	player = get_tree().get_first_node_in_group("player")

func _on_weather_changed(is_raining: bool) -> void:
	emitting = is_raining

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return
	global_position = player.global_position + Vector3(0, height_offset, 0)
