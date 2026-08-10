extends RigidBody3D
## Pedestre caminhando numa calcada: mesmo truque de TrafficCar.gd (filho
## de um PathFollow3D, congelado/kinematic enquanto anda). Ao levar um
## impacto forte (carro do jogador, destroco de gambiarra voando etc.)
## vira ragdoll de verdade (RigidBody3D solto) por alguns segundos e
## depois volta sozinho pra rota. Visual: modelo configuravel (character_model)
## com fallback pra uma capsula colorida se nao carregar. A animacao de
## andar/parado vem de duas cenas externas (idle_anim_scene/walk_anim_scene)
## que compartilham o MESMO esqueleto do character_model — a gente extrai o
## Animation de cada uma e monta um AnimationPlayer na hora, em vez de
## depender de retargeting (so funciona quando mesh+animacao vem do mesmo
## esqueleto; ver CLAUDE.md sobre os personagens Quaternius x Kenney).
## skin_texture e opcional: só usado pelo Kenney (mesh sem textura propria,
## separada pra poder trocar de personagem) — os personagens Quaternius ja
## vem texturizados, entao ficam sem skin_texture.

signal ragdolled

@export var speed := 1.4
@export var character_model: PackedScene
@export var skin_texture: Texture2D
@export var visual_scale := 1.0
## Sorteia corpo (shape keys) e cor de pele/roupa/cabelo ao instanciar.
@export var randomize_appearance := true
## Mesma correcao dos carros: o modelo olha pro +Z e o PathFollow3D anda pro
## -Z, entao sem 180 graus o pedestre anda de costas.
@export var visual_rotation_y_degrees := 180.0
@export var ragdoll_impact_threshold := 4.0
@export var ragdoll_recover_time := 4.0
## Animacoes. O padrao e a UAL1 do Quaternius, que e o que o jogo usa hoje —
## antes era o boneco do Kenney, e o `preload` daquele FBX era uma dependencia
## DURA: todo `PedestrianRoute` da cidade ja sobrescrevia estes dois campos, mas
## o pacote inteiro continuava entrando no build por causa desta linha.
@export var idle_anim_scene: PackedScene = preload("res://assets/quaternius/universal-animation-library-1/Animations/UAL1_Standard.glb")
@export var walk_anim_scene: PackedScene = preload("res://assets/quaternius/universal-animation-library-1/Animations/UAL1_Standard.glb")
@export var idle_anim_name := "Idle"
@export var walk_anim_name := "Walk"

## JEITOS DE ANDAR. A UAL1 tem `Walk`, `Jog_Fwd` e `Sprint` (medido no arquivo),
## e usar so o `Walk` fazia os 84 pedestres andarem no mesmo passo — de longe,
## uma rua inteira em cadencia unica le como fila de clones.
##
## A velocidade vem JUNTO com a animacao, e nao sorteada a parte: um boneco em
## `Jog_Fwd` a 1,2 m/s patina no chao, e um em `Walk` a 3 m/s desliza. O par
## (animacao, faixa de velocidade) e o que mantem o pe no lugar.
##
## `peso` e a chance relativa: quase todo mundo na rua anda, poucos troteiam e
## quase ninguem corre.
const ANDARES: Array[Dictionary] = [
	{"anim": "Walk", "vel": Vector2(0.85, 1.15), "peso": 3.0},   # passeando
	{"anim": "Walk", "vel": Vector2(1.25, 1.75), "peso": 5.0},   # ritmo normal
	{"anim": "Jog_Fwd", "vel": Vector2(2.4, 3.0), "peso": 1.6},  # apressado
	{"anim": "Sprint", "vel": Vector2(3.6, 4.4), "peso": 0.4},   # atrasado
]

## Sorteia um jeito de andar (usado pelo PedestrianRoute ao criar cada NPC).
static func sortear_andar(rng: RandomNumberGenerator = null) -> Dictionary:
	var total := 0.0
	for a: Dictionary in ANDARES:
		total += float(a["peso"])
	var alvo: float = (rng.randf() if rng != null else randf()) * total
	for a: Dictionary in ANDARES:
		alvo -= float(a["peso"])
		if alvo <= 0.0:
			return a
	return ANDARES[1]
## Cena de roupa (ex: Quaternius Modular Character Outfits) que compartilha o
## MESMO esqueleto do character_model — as malhas de roupa sao transplantadas
## pro Skeleton3D do personagem (troca de "skeleton" de cada MeshInstance3D)
## e o corpo nu original some, deixando so cabeca/olhos/sobrancelhas a mostra.
@export var outfit_scene: PackedScene
## Cena de cabelo (Quaternius Hairstyles, "Rigged to Head Bone") — mesma tecnica
## de anexacao do outfit_scene (malha ja skinada no mesmo esqueleto de 65 ossos).
@export var hair_scene: PackedScene

static var _anim_cache: Dictionary = {}

@onready var fallback_mesh: MeshInstance3D = $FallbackMesh

var _path_follow: PathFollow3D = null
var _is_ragdolled := false
var _anim_player: AnimationPlayer = null

func _ready() -> void:
	add_to_group("pedestrian")
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)
	_path_follow = get_parent() as PathFollow3D
	_freeze_to_path()
	_load_visual()

func _load_visual() -> void:
	if character_model == null:
		return
	# Corpo + roupa + cabelo sao montados por CharacterVisual (compartilhado com
	# BuyerNPC.gd, pra pedestre e cliente terem a mesma aparencia).
	var visual := CharacterVisual.build(self, character_model, visual_scale, visual_rotation_y_degrees)
	if visual == null:
		return
	# Tipo fisico e cores sorteados por pedestre — sem isso a cidade inteira
	# anda com dois bonecos identicos (ver CharacterVisual.gd).
	if randomize_appearance:
		CharacterVisual.randomize_appearance(visual)
	# So o personagem do Kenney precisa de skin externa (mesh sem textura propria).
	if skin_texture:
		var mesh_instance := _find_mesh_instance(visual)
		if mesh_instance:
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = skin_texture
			mesh_instance.set_surface_override_material(0, mat)
	if fallback_mesh:
		fallback_mesh.visible = false
	_setup_animation(visual)

func _setup_animation(visual: Node) -> void:
	var idle_anim := _get_cached_animation(idle_anim_scene, idle_anim_name)
	var walk_anim := _get_cached_animation(walk_anim_scene, walk_anim_name)
	if idle_anim == null and walk_anim == null:
		return
	var lib := AnimationLibrary.new()
	if idle_anim:
		lib.add_animation("idle", idle_anim)
	if walk_anim:
		lib.add_animation("run", walk_anim)
	_anim_player = AnimationPlayer.new()
	visual.add_child(_anim_player)
	_anim_player.add_animation_library("", lib)
	if walk_anim:
		_anim_player.play("run")
	elif idle_anim:
		_anim_player.play("idle")

static func _get_cached_animation(scene: PackedScene, anim_name: String) -> Animation:
	if scene == null:
		return null
	var key := scene.resource_path + "|" + anim_name
	if not _anim_cache.has(key):
		_anim_cache[key] = CharacterVisual.extract_animation(scene, anim_name)
	return _anim_cache[key]


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null

func _freeze_to_path() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_is_ragdolled = false

func _physics_process(delta: float) -> void:
	if _is_ragdolled:
		return
	if _path_follow:
		_path_follow.progress += speed * delta

func _on_body_entered(body: Node) -> void:
	if _is_ragdolled:
		return
	var impact := 0.0
	if body is RigidBody3D:
		impact = body.linear_velocity.length()
	if impact > ragdoll_impact_threshold:
		_go_ragdoll(body)

func _go_ragdoll(body: Node) -> void:
	_is_ragdolled = true
	AudioManager.play_at("corpo", global_position, -2.0, randf_range(0.9, 1.1), 60.0)
	freeze = false
	if _anim_player:
		_anim_player.stop()
	var push_dir := Vector3.UP * 0.5
	if body is RigidBody3D:
		push_dir += (global_position - body.global_position).normalized()
	apply_central_impulse(push_dir.normalized() * 6.0)
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 3.0)
	ragdolled.emit()
	await get_tree().create_timer(ragdoll_recover_time).timeout
	_recover()

func _recover() -> void:
	if not is_instance_valid(self):
		return
	if _path_follow:
		global_transform = _path_follow.global_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_freeze_to_path()
	if _anim_player and _anim_player.has_animation("run"):
		_anim_player.play("run")
