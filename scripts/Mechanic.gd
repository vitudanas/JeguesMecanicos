extends StaticBody3D
## O MECANICO contratado: conserta as pecas dos carros parados no patio
## enquanto o jogador esta na rua.
##
## `StaticBody3D` porque e assim que o raycast de interacao do jogador acha as
## coisas (mesmo motivo do `BuyerNPC` e do `UpgradeBoard`). Mirar nele diz o que
## ele esta fazendo agora e quanto vai custar — sem isso o dinheiro sairia da
## conta sem explicacao nenhuma na tela.
##
## Ele NAO monta gambiarra: gambiarra e a piada do jogo e o unico trabalho que
## o jogador faz com as proprias maos. O mecanico cuida da parte chata, que e
## trocar peca de verdade uma a uma pagando cada uma.
##
## Ordem do servico, a mesma do jogador: primeiro diagnostica (senao nao da pra
## consertar o que nao se viu), depois troca peca por peca — e so o que o nivel
## da oficina alcanca, pela mesma regra do `Vehicle._next_repairable()`.

const MODEL := "res://assets/quaternius/characters-dressed/Male_Dressed.glb"
const IDLE_ANIM := "res://assets/quaternius/universal-animation-library-1/Animations/UAL1_Standard.glb"

## Onde ele espera quando nao ha carro pra mexer: encostado no barracao, fora
## das vagas (ver Workshop.clear_rect()).
const HOME := Vector3(-4.6, 0.0, -4.2)
## A que distancia do carro ele fica, e de que LADO.
##
## Ele e um corpo solido (precisa ser, senao o raio de interacao do jogador nao
## acha ele e nao ha prompt), entao onde ele para importa: parado ao lado do
## carro, ele viraria uma parede exatamente onde o jogador contorna a lataria
## pra mirar nos marcadores, e o carro esbarraria nele ao sair. Aqui ele fica ao
## NORTE do carro (o -Z da oficina, o lado do barracao) — o portao e ao sul,
## entao ele nunca esta no caminho de saida.
const WORK_OFFSET := 3.4

var _yard: Node = null
var _target: Node = null
var _progress := 0.0
var _job := ""
var _job_part := ""
var _job_cost := 0
var _blocked_reason := ""

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("mecanico")
	_build_body()
	_load_visual()
	position = HOME
	Staff.changed.connect(_refresh)
	_refresh()

func setup(yard: Node) -> void:
	_yard = yard

func _refresh() -> void:
	var contratado := Staff.has("mecanico")
	visible = contratado
	set_physics_process(contratado)
	# Corpo solido e alvo de mira so existem depois de contratado, senao ele
	# ficaria invisivel barrando o caminho no meio do patio.
	collision_layer = 1 if contratado else 0
	if not contratado:
		_clear_job()

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(shape)

func _load_visual() -> void:
	var visual := CharacterVisual.build(self, load(MODEL) as PackedScene, 1.0)
	if visual == null:
		return
	CharacterVisual.randomize_appearance(visual)
	var idle := CharacterVisual.extract_animation(load(IDLE_ANIM) as PackedScene, "Idle")
	if idle == null:
		return
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", idle)
	var player := AnimationPlayer.new()
	visual.add_child(player)
	player.add_animation_library("", lib)
	player.play("idle")

# ------------------------------------------------------------------ o servico

func _physics_process(delta: float) -> void:
	if _yard == null or not is_instance_valid(_yard):
		return
	if not is_instance_valid(_target) or not _still_useful(_target):
		_pick_target()
	if _target == null:
		position = HOME
		return
	_stand_next_to(_target)
	# Sem dinheiro ele PARA e espera, em vez de trabalhar fiado: o prompt diz o
	# motivo, senao o carro simplesmente nunca ficaria pronto sem explicacao.
	if _job_cost > GameManager.money:
		_blocked_reason = "faltam R$ %d" % (_job_cost - GameManager.money)
		return
	_blocked_reason = ""
	_progress += delta
	var duracao: float = Staff.SECONDS_TO_DIAGNOSE if _job == "diagnostico" \
		else Staff.SECONDS_PER_PART
	if _progress >= duracao:
		_finish_job()

## Ainda ha o que fazer neste carro?
func _still_useful(car: Node) -> bool:
	if not car.at_workshop:
		return false
	if not car.diagnosed:
		return true
	return _next_part(car) != ""

func _pick_target() -> void:
	_clear_job()
	if _yard == null or not _yard.has_method("parked_vehicles"):
		return
	for car in _yard.parked_vehicles():
		if _still_useful(car):
			_target = car
			_start_job(car)
			return

func _start_job(car: Node) -> void:
	_progress = 0.0
	if not car.diagnosed:
		_job = "diagnostico"
		_job_part = ""
		_job_cost = 0
		return
	_job = "troca"
	_job_part = _next_part(car)
	var cheio: int = Economy.repaired_value(car.model_key, car.condition)
	_job_cost = int(round(float(Economy.part_price(_job_part, cheio))
		* (1.0 + Staff.LABOR_MARKUP)))

func _finish_job() -> void:
	var car := _target
	if _job == "diagnostico":
		car.diagnosed = true
	else:
		GameManager.add_money(-_job_cost)
		car.parts[_job_part] = 1.0
		AudioManager.play_at("encaixa", global_position, -4.0, 0.85, 25.0)
	_progress = 0.0
	if _still_useful(car):
		_start_job(car)
	else:
		_clear_job()

func _clear_job() -> void:
	_target = null
	_job = ""
	_job_part = ""
	_job_cost = 0
	_progress = 0.0
	_blocked_reason = ""

## Primeira peca quebrada que o nivel da oficina alcanca. Mesma regra do
## `Vehicle._next_repairable()`; contratar nao pula upgrade de oficina.
func _next_part(car: Node) -> String:
	for k in Economy.broken_parts(car.parts):
		if Dealership.can_repair(k):
			return str(k)
	return ""

## Fica de pe na frente do carro em que esta mexendo, virado pra ele. Mudar de
## posicao e o unico sinal na tela de que ele saiu de um carro pro outro.
##
## O lado sai da OFICINA, nao do carro: o carro chega rebocado em qualquer
## angulo, entao "o lado direito do carro" cairia ora no corredor de saida, ora
## em cima do carro vizinho.
func _stand_next_to(car: Node) -> void:
	var alvo: Vector3 = (car as Node3D).global_position
	var norte: Vector3 = -get_parent().global_transform.basis.z.normalized()
	var pos := alvo + norte * WORK_OFFSET
	pos.y = global_position.y
	global_position = global_position.lerp(pos, 0.08)
	look_at(Vector3(alvo.x, global_position.y, alvo.z), Vector3.UP)

# -------------------------------------------------------------------- na tela

func get_interact_prompt() -> String:
	var nome: String = str(Staff.ROLES["mecanico"]["nome"])
	if _target == null or not is_instance_valid(_target):
		return "%s — sem carro no pátio pra mexer" % nome
	if _blocked_reason != "":
		return "%s — parado: %s" % [nome, _blocked_reason]
	var duracao: float = Staff.SECONDS_TO_DIAGNOSE if _job == "diagnostico" \
		else Staff.SECONDS_PER_PART
	var pct := int(clampf(_progress / duracao, 0.0, 1.0) * 100.0)
	if _job == "diagnostico":
		return "%s — diagnosticando (%d%%)" % [nome, pct]
	var info: Dictionary = Economy.PARTS[_job_part]
	return "%s — trocando %s (%d%%) · R$ %d com a mão de obra" % [
		nome, info["nome"], pct, _job_cost]
