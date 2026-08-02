extends Node3D
## Componente de reboque: puxa um RigidBody3D (o carro sucateado) atras
## do jogador usando uma forca de mola/amortecimento, sem juntas fisicas
## rigidas (fica mais estavel para arrastar em terreno irregular).

@export var pull_distance := 2.2
@export var spring_strength := 14.0
@export var damping := 7.0
@export var max_speed := 3.2

var towed_body: RigidBody3D = null

func attach(body: RigidBody3D) -> void:
	towed_body = body

func detach() -> void:
	towed_body = null

func is_towing() -> bool:
	return towed_body != null

func _physics_process(_delta: float) -> void:
	if towed_body == null or not is_instance_valid(towed_body):
		towed_body = null
		return
	var target_pos: Vector3 = global_transform.origin - global_transform.basis.z * pull_distance
	var to_target: Vector3 = target_pos - towed_body.global_transform.origin
	var force: Vector3 = to_target * spring_strength - towed_body.linear_velocity * damping
	towed_body.apply_central_force(force * towed_body.mass)
	if towed_body.linear_velocity.length() > max_speed:
		towed_body.linear_velocity = towed_body.linear_velocity.normalized() * max_speed
