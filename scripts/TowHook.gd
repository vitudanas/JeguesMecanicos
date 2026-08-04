extends Node3D
## Componente de reboque: puxa um RigidBody3D (o carro sucateado) atras
## do jogador usando uma forca de mola/amortecimento, sem juntas fisicas
## rigidas (fica mais estavel para arrastar em terreno irregular).

## Distancia MINIMA do gancho ate o centro do carro. O valor efetivo e
## calculado no attach() a partir do tamanho real do carro: com 2.2 fixo e um
## carro de 4.22m, a carroceria alcancava o proprio jogador — o carro subia em
## cima da capsula dele e, quando o jogador saia de baixo, o solver ejetava o
## corpo rigido a mais de 300 m/s (medido pelo teste de loop).
@export var pull_distance := 2.2
## Folga entre a carroceria e o jogador.
@export var body_clearance := 1.0
@export var spring_strength := 14.0
@export var damping := 7.0
## Tem que ser MAIOR que a velocidade de caminhada do jogador (4.0), senao o
## carro fica pra tras pra sempre e o jogador chega na oficina sozinho — o
## teste de loop mediu a carcaca 13.8m atras. Correr (7.5) ainda ganha do
## reboque, o que faz sentido: nao da pra sair correndo arrastando um carro.
@export var max_speed := 4.6

var towed_body: RigidBody3D = null
var _effective_distance := 2.2

func attach(body: RigidBody3D) -> void:
	towed_body = body
	if body.has_method("set_towed"):
		body.set_towed(true)
	_effective_distance = pull_distance
	# Meio comprimento real do carro + folga: assim a traseira nunca alcanca o
	# jogador, seja qual for o modelo.
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var box: BoxShape3D = (child as CollisionShape3D).shape
			_effective_distance = maxf(_effective_distance,
				maxf(box.size.z, box.size.x) * 0.5 + body_clearance)
			break

func detach() -> void:
	if towed_body != null and is_instance_valid(towed_body) and towed_body.has_method("set_towed"):
		towed_body.set_towed(false)
	towed_body = null

func is_towing() -> bool:
	return towed_body != null

func _physics_process(_delta: float) -> void:
	if towed_body == null or not is_instance_valid(towed_body):
		towed_body = null
		return
	# ATRAS do jogador (+Z local), nao na frente. O codigo antigo usava -Z, ou
	# seja punha o alvo na FRENTE de quem puxa: o jogador andava empurrando o
	# carro e a carroceria vivia dentro da capsula dele. Alem de bater com o
	# que este arquivo sempre disse ("puxa o carro atras do jogador"), arrastar
	# atras e o que faz sentido — ninguem reboca empurrando de re.
	var target_pos: Vector3 = global_transform.origin + global_transform.basis.z * _effective_distance
	var to_target: Vector3 = target_pos - towed_body.global_transform.origin
	var force: Vector3 = to_target * spring_strength - towed_body.linear_velocity * damping
	towed_body.apply_central_force(force * towed_body.mass)
	if towed_body.linear_velocity.length() > max_speed:
		towed_body.linear_velocity = towed_body.linear_velocity.normalized() * max_speed
