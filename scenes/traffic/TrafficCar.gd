extends RigidBody3D
## Carro de trafego: anda sozinho ao longo de uma rota (e filho de um
## PathFollow3D dentro de TrafficRoute.tscn). Fica "congelado" (kinematic)
## — nao e afetado por forcas, mas ainda colide fisicamente e dispara o
## sistema de estresse de gambiarras do carro do jogador (ver
## Vehicle.gd:_on_body_entered, que ja reage a qualquer body_entered).
## Visual: um modelo do Kenney Car Kit (assets/kenney/car-kit), com
## fallback pra uma caixa colorida se nenhum modelo for atribuido.

@export var speed := 4.0
@export var car_model: PackedScene
@export var visual_rotation_y_degrees := 0.0

@onready var fallback_mesh: MeshInstance3D = $FallbackMesh

var _path_follow: PathFollow3D = null

func _ready() -> void:
	add_to_group("traffic_car")
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = false
	_path_follow = get_parent() as PathFollow3D
	_load_visual()

func _load_visual() -> void:
	if car_model == null:
		return
	var visual := car_model.instantiate()
	add_child(visual)
	if visual is Node3D:
		visual.rotation_degrees.y = visual_rotation_y_degrees
	if fallback_mesh:
		fallback_mesh.visible = false

func _physics_process(delta: float) -> void:
	if _path_follow:
		_path_follow.progress += speed * delta
