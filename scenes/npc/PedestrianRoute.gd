extends Path3D
## Rota fixa de pedestres nas calcadas: mesmo esquema de
## scenes/traffic/TrafficRoute.gd (curva simples montada em codigo,
## sem pathfinding), so que mais lenta e usando Pedestrian.tscn.

@export var route_points: Array[Vector3] = []
@export var pedestrian_count := 3
@export var speed_min := 1.0
@export var speed_max := 1.8
@export var character_models: Array[PackedScene] = []

const PEDESTRIAN_SCENE := preload("res://scenes/npc/Pedestrian.tscn")

func _ready() -> void:
	curve = Curve3D.new()
	for point in route_points:
		curve.add_point(point)
	curve.closed = true
	_spawn_pedestrians()

func _spawn_pedestrians() -> void:
	for i in range(pedestrian_count):
		var path_follow := PathFollow3D.new()
		path_follow.rotation_mode = PathFollow3D.ROTATION_Y
		path_follow.loop = true
		add_child(path_follow)
		path_follow.progress_ratio = float(i) / float(pedestrian_count)

		var pedestrian := PEDESTRIAN_SCENE.instantiate()
		pedestrian.speed = randf_range(speed_min, speed_max)
		if character_models.size() > 0:
			pedestrian.character_model = character_models[i % character_models.size()]
		path_follow.add_child(pedestrian)
