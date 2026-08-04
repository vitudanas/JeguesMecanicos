extends Area3D
## Ponto de fixacao no carro (capo, radiador, retrovisor, parachoque).
## E filho de AttachPoints, que e filho do Vehicle. Ao interagir, instancia
## a peca de gambiarra padrao daquele ponto e manda o Vehicle instalar.

@export var point_name := "hood"
@export var display_name := "Capo"
@export var part_scene: PackedScene

@onready var marker: MeshInstance3D = $Marker

var vehicle: Node = null

func _ready() -> void:
	add_to_group("interactable")
	var attach_points_node := get_parent()
	if attach_points_node:
		vehicle = attach_points_node.get_parent()

func get_interact_prompt() -> String:
	if vehicle == null:
		return ""
	if vehicle.installed_parts.has(point_name):
		return ""
	return "Fixar gambiarra: %s [E]" % display_name

func interact(_player: Node) -> void:
	if vehicle == null or part_scene == null:
		return
	if vehicle.installed_parts.has(point_name):
		return
	var part := part_scene.instantiate()
	get_tree().current_scene.add_child(part)
	vehicle.install_part(point_name, part, self)
	if marker:
		marker.visible = false
	# Some tambem pro raycast de interacao. O marcador ficava invisivel mas a
	# Area3D continuava ali na frente da carroceria: mirando no carro o jogador
	# pegava um ponto ja usado, cujo prompt e vazio — parecia que o carro tinha
	# parado de responder ao E.
	collision_layer = 0
	monitorable = false
