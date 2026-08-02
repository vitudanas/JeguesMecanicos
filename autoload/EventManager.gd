extends Node
## Eventos aleatorios pelo mapa: de tempos em tempos spawna um carro
## sucateado extra (alem do Junkyard fixo) num dos pontos marcados no
## grupo "event_spawn_point" (ver Marker3D em Town.tscn), ate um limite
## maximo simultaneo. Autoload (singleton) — registrado em project.godot.

const VEHICLE_SCENE := preload("res://scenes/vehicle/Vehicle.tscn")

@export var spawn_interval_min := 45.0
@export var spawn_interval_max := 90.0
@export var max_concurrent_events := 3

var _active_event_cars: Array[Node] = []
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	_schedule_next()

func _schedule_next() -> void:
	_timer.start(randf_range(spawn_interval_min, spawn_interval_max))

func _on_timer_timeout() -> void:
	_try_spawn_event_car()
	_schedule_next()

func _try_spawn_event_car() -> void:
	_active_event_cars = _active_event_cars.filter(func(c): return is_instance_valid(c))
	if _active_event_cars.size() >= max_concurrent_events:
		return
	var points := get_tree().get_nodes_in_group("event_spawn_point")
	if points.is_empty():
		return
	var point: Node3D = points[randi() % points.size()]
	var car := VEHICLE_SCENE.instantiate()
	get_tree().current_scene.add_child(car)
	car.global_position = point.global_position
	_active_event_cars.append(car)
