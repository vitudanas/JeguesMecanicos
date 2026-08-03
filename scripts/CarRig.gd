class_name CarRig
extends Node3D
## Visual de um carro de verdade (Quaternius) montado para ser DIRIGIDO:
## acha as rodas no modelo, cria um pivo no centro de cada uma e deixa elas
## esterçarem e girarem.
##
## Por que um pivo em vez de girar o proprio no da malha: no GLB as rodas sao
## MeshInstance3D com transform identidade e a malha deslocada (a roda
## dianteira esquerda do car-a tem AABB em x=+0.60). Girar o no giraria a roda
## em torno da origem do CARRO, e ela sairia orbitando. O pivo fica no centro
## medido da roda e a malha entra nele com `reparent`, que preserva a posicao.
##
## O rig tambem PUBLICA as medidas do modelo (eixos, bitola, raio da roda,
## caixa da carroceria). Quem usa nao chuta nenhuma coordenada: Vehicle.gd
## posiciona raycast de suspensao, colisao e pontos de gambiarra a partir
## daqui, entao trocar o modelo do carro nao exige reposicionar nada na mao.
##
## Convencao: os modelos olham para o +Z (medido, ver changelog 2026-08-03) e
## a frente do Vehicle e o -Z, entao o modelo entra girado 180 graus e todas
## as medidas publicadas ja saem no espaco do Vehicle.

## Nomes que o kit usa. Os 7 modelos do pacote seguem o mesmo padrao
## (conferido um por um), entao basta casar por trecho do nome.
const FRONT_LEFT := "frontleftwheel"
const FRONT_RIGHT := "frontrightwheel"
const REAR := "backwheels"

var body_aabb := AABB()      ## caixa da carroceria (sem rodas), no espaco do Vehicle
var wheel_radius := 0.3
var front_axle_z := -1.2     ## Z do eixo dianteiro (negativo = frente)
var rear_axle_z := 1.2
var half_track := 0.7        ## metade da distancia entre as rodas de um eixo
var axle_y := 0.3            ## altura do centro das rodas com a suspensao em repouso

var _model: Node3D
var _front_pivots: Array[Node3D] = []
var _rear_pivot: Node3D = null
var _roll := 0.0
var _steer := 0.0
var _body_meshes: Array[MeshInstance3D] = []

## Monta o visual. Retorna false se o modelo nao veio (o chamador decide o
## fallback).
func build(model_scene: PackedScene) -> bool:
	if model_scene == null:
		return false
	_model = model_scene.instantiate() as Node3D
	if _model == null:
		return false
	add_child(_model)
	# A frente do modelo e o +Z; a do Vehicle e o -Z.
	_model.rotation_degrees.y = 180.0

	var front_left: MeshInstance3D = null
	var front_right: MeshInstance3D = null
	var rear: MeshInstance3D = null
	for mesh_inst in _meshes(_model):
		var lower := mesh_inst.name.to_lower()
		if lower.contains(FRONT_LEFT):
			front_left = mesh_inst
		elif lower.contains(FRONT_RIGHT):
			front_right = mesh_inst
		elif lower.contains(REAR):
			rear = mesh_inst
		else:
			_body_meshes.append(mesh_inst)

	_measure_body()
	if front_left and front_right and rear:
		_build_wheels(front_left, front_right, rear)
	return true

## Angulo de esterco das rodas dianteiras, em radianos.
func set_steer(angle: float) -> void:
	_steer = angle
	_apply()

## Roda os pneus de acordo com a distancia percorrida (m). Sinal positivo = pra
## frente.
func roll(distance: float) -> void:
	if wheel_radius > 0.001:
		_roll += distance / wheel_radius
	_apply()

## Malhas da carroceria (sem as rodas): quem pinta o carro usa isso pra nao
## pintar pneu de vermelho.
func body_meshes() -> Array[MeshInstance3D]:
	return _body_meshes

func _apply() -> void:
	for pivot in _front_pivots:
		# Esterco em Y e giro em X compostos nessa ordem: girar primeiro e
		# esterçar depois inclinaria o eixo de rotacao do pneu.
		pivot.basis = Basis(Vector3.UP, _steer) * Basis(Vector3.RIGHT, _roll)
	if _rear_pivot:
		_rear_pivot.basis = Basis(Vector3.RIGHT, _roll)

func _build_wheels(front_left: MeshInstance3D, front_right: MeshInstance3D,
		rear: MeshInstance3D) -> void:
	var fl := _pivot_for(front_left)
	var fr := _pivot_for(front_right)
	_rear_pivot = _pivot_for(rear)
	_front_pivots = [fl, fr]

	# Medidas publicadas ja no espaco do Vehicle (o modelo esta girado 180, e
	# giro de 180 em Y troca o sinal de X e de Z).
	var fl_aabb := front_left.get_aabb()
	wheel_radius = fl_aabb.size.y * 0.5
	axle_y = fl_aabb.position.y + wheel_radius
	front_axle_z = -(fl.position.z)
	rear_axle_z = -(_rear_pivot.position.z)
	half_track = absf(fl.position.x)

## Cria um no no centro medido da roda e move a malha pra dentro dele.
func _pivot_for(mesh_inst: MeshInstance3D) -> Node3D:
	var aabb := mesh_inst.get_aabb()
	var center := aabb.position + aabb.size * 0.5
	var pivot := Node3D.new()
	pivot.name = mesh_inst.name + "Pivot"
	_model.add_child(pivot)
	pivot.position = center
	# reparent preserva a transformada global, entao a roda continua no lugar e
	# passa a girar em torno do proprio centro.
	mesh_inst.reparent(pivot)
	return pivot

func _measure_body() -> void:
	var aabb := AABB()
	var has := false
	for mesh_inst in _body_meshes:
		var box := mesh_inst.get_aabb()
		if not has:
			aabb = box
			has = true
		else:
			aabb = aabb.merge(box)
	if not has:
		return
	# 180 graus em Y: X e Z trocam de sinal, entao o canto minimo vira o maximo.
	body_aabb = AABB(
		Vector3(-(aabb.position.x + aabb.size.x), aabb.position.y,
			-(aabb.position.z + aabb.size.z)),
		aabb.size)

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out
