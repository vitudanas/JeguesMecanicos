extends Node
## Clima dinamico e imprevisivel: alterna chuva/sol sozinho num timer com
## intervalo aleatorio. Durante a chuva, MudZone.gd (poças perto dos
## buracos) reduz a tracao do Vehicle.gd — ver enter_mud()/exit_mud() la.
## Autoload (singleton) — registrado em project.godot [autoload].

signal weather_changed(is_raining: bool)

@export var mud_traction_factor := 0.35 ## 35% da aderencia normal na lama
@export var rain_min_duration := 25.0
@export var rain_max_duration := 60.0
@export var dry_min_duration := 40.0
@export var dry_max_duration := 90.0

var is_raining := false

@onready var _timer: Timer = Timer.new()

func _ready() -> void:
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	_schedule_next(false)

func _schedule_next(start_raining: bool) -> void:
	is_raining = start_raining
	weather_changed.emit(is_raining)
	var duration: float
	if is_raining:
		duration = randf_range(rain_min_duration, rain_max_duration)
	else:
		duration = randf_range(dry_min_duration, dry_max_duration)
	_timer.start(duration)

func _on_timer_timeout() -> void:
	_schedule_next(not is_raining)

## Forca uma troca imediata de clima — util pra debug/teste.
func toggle_rain() -> void:
	_timer.stop()
	_schedule_next(not is_raining)
