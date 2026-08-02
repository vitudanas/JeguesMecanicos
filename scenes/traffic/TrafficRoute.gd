extends Path3D
## Rota fixa de trafego: monta a curva em codigo a partir de
## route_points (retas simples, cantos de 90 graus — sem curva suave,
## sem pathfinding) e distribui car_count TrafficCar ao longo dela,
## cada um dentro do seu proprio PathFollow3D com progresso inicial
## escalonado (pra nao nascerem empilhados) e velocidade levemente
## randomizada.

@export var route_points: Array[Vector3] = []
@export var car_count := 3
@export var car_speed_min := 3.0
@export var car_speed_max := 5.0
@export var car_models: Array[PackedScene] = []

const TRAFFIC_CAR_SCENE := preload("res://scenes/traffic/TrafficCar.tscn")

func _ready() -> void:
	curve = Curve3D.new()
	for point in route_points:
		curve.add_point(point)
	curve.closed = true
	_spawn_cars()

func _spawn_cars() -> void:
	for i in range(car_count):
		var path_follow := PathFollow3D.new()
		path_follow.rotation_mode = PathFollow3D.ROTATION_Y
		path_follow.loop = true
		add_child(path_follow)
		path_follow.progress_ratio = float(i) / float(car_count)

		var car := TRAFFIC_CAR_SCENE.instantiate()
		car.speed = randf_range(car_speed_min, car_speed_max)
		if car_models.size() > 0:
			car.car_model = car_models[i % car_models.size()]
		path_follow.add_child(car)
