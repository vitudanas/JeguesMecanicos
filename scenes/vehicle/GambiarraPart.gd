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

func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = false

## Encaixa esta peca no marcador do carro (vira filha dele e some com a fisica).
func install(target_vehicle: Node, point_name: String, marker: Node3D) -> void:
	vehicle = target_vehicle
	attach_point_name = point_name
	var current_parent := get_parent()
	if current_parent:
		current_parent.remove_child(self)
	marker.add_child(self)
	transform = Transform3D.IDENTITY
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	installed = true

## Chamado pelo Vehicle quando o carro leva um impacto/buraco.
func receive_stress(force: float) -> void:
	if not installed:
		return
	if force > break_threshold * resistance:
		_detach(force)

func _detach(force: float) -> void:
	installed = false
	var world := get_tree().current_scene
	var global_t := global_transform
	var current_parent := get_parent()
	if current_parent:
		current_parent.remove_child(self)
	world.add_child(self)
	global_transform = global_t
	freeze = false
	apply_central_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.6), randf_range(-1.0, 1.0)) * force * 0.15)
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * force * 0.05)
	broke.emit()
