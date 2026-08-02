extends Path3D
## Rota fixa de pedestres nas calcadas: mesmo esquema de
## scenes/traffic/TrafficRoute.gd (curva simples montada em codigo,
## sem pathfinding), so que mais lenta e usando Pedestrian.tscn.

@export var route_points: Array[Vector3] = []
@export var pedestrian_count := 3
@export var speed_min := 1.0
@export var speed_max := 1.8
@export var character_model: PackedScene
@export var skin_textures: Array[Texture2D] = []
## Alternativa a character_model+skin_textures: varios modelos ja texturizados
## (personagens Quaternius, por exemplo), um por indice de pedestre. Se
## preenchido, tem prioridade sobre character_model/skin_textures.
@export var character_models: Array[PackedScene] = []
## Roupa pra cada character_models[i] (mesmo indice). Ver Pedestrian.gd:_attach_outfit().
@export var outfit_scenes: Array[PackedScene] = []
@export var visual_scale := 1.0
@export var idle_anim_scene: PackedScene
@export var walk_anim_scene: PackedScene
@export var idle_anim_name := ""
@export var walk_anim_name := ""

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
			if outfit_scenes.size() > 0:
				pedestrian.outfit_scene = outfit_scenes[i % outfit_scenes.size()]
		else:
			pedestrian.character_model = character_model
			if skin_textures.size() > 0:
				pedestrian.skin_texture = skin_textures[i % skin_textures.size()]
		pedestrian.visual_scale = visual_scale
		if idle_anim_scene:
			pedestrian.idle_anim_scene = idle_anim_scene
		if walk_anim_scene:
			pedestrian.walk_anim_scene = walk_anim_scene
		if idle_anim_name != "":
			pedestrian.idle_anim_name = idle_anim_name
		if walk_anim_name != "":
			pedestrian.walk_anim_name = walk_anim_name
		path_follow.add_child(pedestrian)
