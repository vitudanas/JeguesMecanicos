extends Path3D
## Rota fixa de pedestres nas calcadas: mesmo esquema de
## scenes/traffic/TrafficRoute.gd (curva simples montada em codigo,
## sem pathfinding), so que mais lenta e usando Pedestrian.tscn.

@export var route_points: Array[Vector3] = []
@export var pedestrian_count := 3
## Sorteia jeito de andar por pedestre (passeando / normal / apressado /
## atrasado), com a animacao e a velocidade vindo juntas. Desligado, todos usam
## `walk_anim_name` e a faixa `speed_min/max` abaixo.
@export var variar_andar := true
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
## Cabelo pra cada character_models[i] (mesmo indice). Ver Pedestrian.gd:hair_scene.
@export var hair_scenes: Array[PackedScene] = []
## Altura MEDIDA de cada `character_models[i]`, no arquivo (arrays paralelos,
## mesmo padrao de `diagonal_starts`/`_ends`). E ela que converte "quero 1,75 m"
## em escala — sem isso, um `visual_scale` unico serve pra um modelo so, e os 44
## do catalogo vao de 0,7 a 208 unidades de altura no arquivo.
@export var model_heights: Array[float] = []
## Altura ALVO do pedestre, em metros. Usada quando ha `model_heights`.
@export var target_height := 1.75
@export var visual_scale := 1.0
## Variacao de altura por pedestre (fracao de visual_scale). Os dois modelos
## tem 1.77m/1.81m, entao 0.07 da gente de ~1.65m a ~1.94m na rua.
@export var height_variation := 0.07
@export var visual_rotation_y_degrees := 180.0
@export var idle_anim_scene: PackedScene
@export var walk_anim_scene: PackedScene
@export var idle_anim_name := ""
@export var walk_anim_name := ""

## Semente do sorteio de modelo/velocidade. Fixa de proposito: a cidade inteira
## e gerada com semente fixa e tem que voltar IDENTICA (e disso que o save
## depende — ele guarda progresso, nao o estado do mundo). Com `randi()` global,
## cada carga da cidade sorteava outros modelos de pedestre, e como eles tem de
## 971 a 17 mil faces a geometria da cena mudava entre execucoes: o
## `settings_test`, que compara presets carregando a cidade uma vez por preset,
## passou a reprovar por diferenca de 2,7% que era so o sorteio.
@export var rng_seed := 20260811

const PEDESTRIAN_SCENE := preload("res://scenes/npc/Pedestrian.tscn")
const PEDESTRIAN_SCRIPT := preload("res://scenes/npc/Pedestrian.gd")

func _ready() -> void:
	curve = Curve3D.new()
	for point in route_points:
		curve.add_point(point)
	curve.closed = true
	_spawn_pedestrians()

func _spawn_pedestrians() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in range(pedestrian_count):
		var idx := -1
		var path_follow := PathFollow3D.new()
		path_follow.rotation_mode = PathFollow3D.ROTATION_Y
		path_follow.loop = true
		add_child(path_follow)
		path_follow.progress_ratio = float(i) / float(pedestrian_count)

		var pedestrian := PEDESTRIAN_SCENE.instantiate()
		pedestrian.speed = rng.randf_range(speed_min, speed_max)
		if character_models.size() > 0:
			# SORTEADO, e nao rodizio: com `i % tamanho` e 4 pedestres por rota,
			# todas as 18 rotas usavam os mesmos 4 primeiros modelos do pool — a
			# cidade tinha 31 modelos disponiveis e mostrava 6.
			idx = rng.randi() % character_models.size()
			pedestrian.character_model = character_models[idx]
			if outfit_scenes.size() > 0:
				pedestrian.outfit_scene = outfit_scenes[i % outfit_scenes.size()]
			if hair_scenes.size() > 0:
				pedestrian.hair_scene = hair_scenes[i % hair_scenes.size()]
		else:
			pedestrian.character_model = character_model
			if skin_textures.size() > 0:
				pedestrian.skin_texture = skin_textures[i % skin_textures.size()]
		# A escala sai da altura MEDIDA do modelo, e nao de um fator unico: e a
		# mesma licao da grama gigante de 2026-08-04 — configurar em metros e
		# derivar a escala, em vez de escrever escala crua.
		var base_scale := visual_scale
		if idx >= 0 and model_heights.size() == character_models.size():
			var alto: float = model_heights[idx]
			if alto > 0.0:
				base_scale = target_height / alto
		pedestrian.visual_scale = base_scale * rng.randf_range(
				1.0 - height_variation, 1.0 + height_variation)
		if idle_anim_scene:
			pedestrian.idle_anim_scene = idle_anim_scene
		if walk_anim_scene:
			pedestrian.walk_anim_scene = walk_anim_scene
		if idle_anim_name != "":
			pedestrian.idle_anim_name = idle_anim_name
		if walk_anim_name != "":
			pedestrian.walk_anim_name = walk_anim_name
		# DEPOIS do bloco acima de proposito: a rota manda o mesmo
		# `walk_anim_name` pra todos os seus pedestres, e sorteando antes o
		# valor era sobrescrito — todos saiam com `Walk` e so a velocidade
		# variava, o que faz o boneco patinar ou deslizar.
		#
		# O jeito de andar traz animacao E velocidade JUNTAS (ver
		# Pedestrian.ANDARES): e o par que mantem o pe no lugar.
		if variar_andar:
			var andar: Dictionary = PEDESTRIAN_SCRIPT.sortear_andar(rng)
			pedestrian.walk_anim_name = str(andar["anim"])
			var faixa: Vector2 = andar["vel"]
			pedestrian.speed = rng.randf_range(faixa.x, faixa.y)
		path_follow.add_child(pedestrian)
