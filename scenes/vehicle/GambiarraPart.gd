extends RigidBody3D
## Uma peca "gambiarra" (dobradica, mangueira, fita isolante...) que pode
## ser instalada num ponto de fixacao do carro. Enquanto instalada, fica
## congelada (kinematic) seguindo o marcador do carro; quando recebe
## estresse acima da resistencia, vira destroco fisico solto.

signal broke

@export var part_id := "generic"
@export var display_name := "Peca Misteriosa"
@export var resistance := 1.0 ## multiplicador: quanto maior, mais aguenta
@export var break_threshold := 6.0

var attach_point_name := ""
var vehicle: Node = null
var installed := false
## Ponto do carro que esta peca acompanha enquanto instalada.
var anchor: Node3D = null
var _layer := 1
var _mask := 1

func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = false

## Encaixa esta peca no ponto do carro.
##
## Ela NAO vira filha do carro, e isso e o conserto de um bug que so aparecia
## DIRIGINDO: um `RigidBody3D` e dono do proprio transform — o servidor de
## fisica reescreve o transform do no a cada passo — entao pendurar a peca na
## arvore do carro nao a faz andar junto. Parada no patio ficava perfeita, e
## bastava acelerar pra ela ficar boiando pra tras (medido: o carro andou 35,5 m
## e as pecas ficaram 20,8 m atras). Nenhum teste tinha pego porque todos
## mediam a peca com o carro PARADO.
##
## Aqui ela fica no mundo e o `_physics_process` copia o transform da ancora
## todo passo — que e o que o comentario da classe sempre disse que acontecia.
func install(target_vehicle: Node, point_name: String, marker: Node3D) -> void:
	vehicle = target_vehicle
	attach_point_name = point_name
	anchor = marker
	if get_parent() == null:
		var world := target_vehicle.get_tree().current_scene
		world.add_child(self)
	global_transform = anchor.global_transform
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	# Peca instalada NAO colide. Enquanto instalada ela e um RigidBody
	# cinematico grudado no carro, e corpo cinematico empurra quem encosta —
	# as 4 pecas ficavam brigando com a carroceria e o carro simplesmente NAO
	# SAIA DO LUGAR com o acelerador no fundo (medido no teste de loop:
	# throttle 1.0, 4 rodas no chao, 1 cm andado em 2 segundos).
	# A colisao volta quando a peca se solta e vira destroco de verdade.
	_layer = collision_layer
	_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	installed = true

func _physics_process(_delta: float) -> void:
	_follow()

## Tambem no quadro de DESENHO, e nao so no de fisica. O `_physics_process` de
## todo mundo roda ANTES do servidor integrar e reescrever o transform do carro,
## entao copiar so ali deixa a peca sempre um passo atras — medido, 22 cm a
## 26 km/h, e pior quanto mais rapido. Instalada, a peca nao colide com nada
## (ver install), entao quem manda nela e o que aparece na tela.
func _process(_delta: float) -> void:
	_follow()

func _follow() -> void:
	if not installed:
		return
	# Carro vendido/destruido leva as gambiarras junto. Como a peca nao e mais
	# filha do carro, ninguem mais faria isso por ela — e sobrariam 4 pecas
	# boiando no lugar onde o carro estava.
	if not is_instance_valid(vehicle) or not is_instance_valid(anchor):
		queue_free()
		return
	global_transform = anchor.global_transform

## Chamado pelo Vehicle quando o carro leva um impacto/buraco.
func receive_stress(force: float) -> void:
	if not installed:
		return
	if force > break_threshold * resistance:
		_detach(force)

func _detach(force: float) -> void:
	installed = false
	anchor = null
	# Ela ja vive no mundo (ver install), entao nao ha o que reparentar: basta
	# devolver a colisao e soltar.
	collision_layer = _layer
	collision_mask = _mask
	freeze = false
	apply_central_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.6), randf_range(-1.0, 1.0)) * force * 0.15)
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * force * 0.05)
	# Lataria fina se soltando: e o som que conta a piada do jogo, entao vem
	# alto e um tom acima, pra sobressair no meio da batida que o causou.
	AudioManager.play_at("lataria", global_position, -2.0, randf_range(1.05, 1.25), 65.0)
	broke.emit()
