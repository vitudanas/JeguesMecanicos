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
@export var ragdoll_impact_threshold := 4.0
@export var ragdoll_recover_time := 4.0
@export var idle_anim_scene: PackedScene = preload("res://assets/kenney/animated-characters-protagonists/Animations/idle.fbx")
@export var walk_anim_scene: PackedScene = preload("res://assets/kenney/animated-characters-protagonists/Animations/run.fbx")
@export var idle_anim_name := "Root|Idle"
@export var walk_anim_name := "Root|Run"

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
		_anim_cache[key] = _extract_animation(scene, anim_name)
	return _anim_cache[key]

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
