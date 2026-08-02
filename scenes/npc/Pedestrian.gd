extends RigidBody3D
## Pedestre caminhando numa calcada: mesmo truque de TrafficCar.gd (filho
## de um PathFollow3D, congelado/kinematic enquanto anda). Ao levar um
## impacto forte (carro do jogador, destroco de gambiarra voando etc.)
## vira ragdoll de verdade (RigidBody3D solto) por alguns segundos e
## depois volta sozinho pra rota. Visual: modelo do Kenney Animated
## Characters Protagonists (proporcao humana normal, nao chibi), com a
## textura de skin aplicada por cima (o FBX vem sem textura propria —
## Kenney separa a malha da skin pra poder trocar de personagem) e
## fallback pra uma capsula colorida se o modelo nao carregar. A
## animacao de andar/parado vem de idle.fbx/run.fbx (arquivos separados
## do modelo — Kenney exporta a malha e as animacoes em FBX distintos
## que compartilham o mesmo esqueleto "Root/Skeleton3D", entao a gente
## extrai o Animation de cada um e monta um AnimationPlayer na hora.

signal ragdolled

const IDLE_ANIM_SCENE := preload("res://assets/kenney/animated-characters-protagonists/Animations/idle.fbx")
const RUN_ANIM_SCENE := preload("res://assets/kenney/animated-characters-protagonists/Animations/run.fbx")

static var _cached_idle_anim: Animation = null
static var _cached_run_anim: Animation = null

@export var speed := 1.4
@export var character_model: PackedScene
@export var skin_texture: Texture2D
@export var visual_scale := 1.0
@export var ragdoll_impact_threshold := 4.0
@export var ragdoll_recover_time := 4.0

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
	var visual := character_model.instantiate()
	add_child(visual)
	if visual is Node3D:
		visual.scale = Vector3.ONE * visual_scale
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
	if _cached_idle_anim == null:
		_cached_idle_anim = _extract_animation(IDLE_ANIM_SCENE, "Root|Idle")
	if _cached_run_anim == null:
		_cached_run_anim = _extract_animation(RUN_ANIM_SCENE, "Root|Run")
	if _cached_idle_anim == null and _cached_run_anim == null:
		return
	var lib := AnimationLibrary.new()
	if _cached_idle_anim:
		lib.add_animation("idle", _cached_idle_anim)
	if _cached_run_anim:
		lib.add_animation("run", _cached_run_anim)
	_anim_player = AnimationPlayer.new()
	visual.add_child(_anim_player)
	_anim_player.add_animation_library("", lib)
	if _cached_run_anim:
		_anim_player.play("run")
	elif _cached_idle_anim:
		_anim_player.play("idle")

static func _extract_animation(scene: PackedScene, anim_name: String) -> Animation:
	var temp := scene.instantiate()
	var anim: Animation = null
	var player := temp.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for lib_name in player.get_animation_library_list():
			var lib := player.get_animation_library(lib_name)
			if lib.has_animation(anim_name):
				anim = lib.get_animation(anim_name)
				break
	temp.free()
	return anim

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
