extends RigidBody3D
## Carro com fisica caotica: suspensao por raycast (4 rodas), pontos de
## fixacao para gambiarras e um "chase camera" para o test-drive em
## terceira pessoa. Controles (quando ha motorista): W/S acelera/re,
## A/D vira, Space freio de mao, F sai do carro.

signal part_broken(point_name: String)
signal part_attached(point_name: String)

@export var is_wrecked := true
@export var max_engine_force := 2600.0
@export var max_steer_angle := 0.55
@export var suspension_rest_length := 0.55
@export var suspension_strength := 140.0
@export var suspension_damping := 9.0

@onready var wheels: Array[RayCast3D] = [$WheelFL, $WheelFR, $WheelRL, $WheelRR]
@onready var attach_points_node: Node3D = $AttachPoints
@onready var chase_camera: Camera3D = $ChaseCameraRig/ChaseCamera
@onready var smoke_fx: GPUParticles3D = $SmokeFX

var attach_points: Dictionary = {}
var installed_parts: Dictionary = {}
var driver: Node = null
var steer_input := 0.0
var throttle_input := 0.0
var handbrake := false
var mud_zones_overlapping := 0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("vehicle")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	for spot in attach_points_node.get_children():
		if spot.has_method("get_interact_prompt"):
			attach_points[spot.point_name] = spot

func get_interact_prompt() -> String:
	if driver:
		return ""
	if is_wrecked:
		return "Rebocar [E]"
	return "Entrar no carro [E]"

func interact(player: Node) -> void:
	if driver == player:
		return
	if is_wrecked:
		if player.has_method("start_towing"):
			player.start_towing(self)
	else:
		if player.has_method("enter_vehicle"):
			driver = player
			player.enter_vehicle(self)
			chase_camera.current = true

func exit_to_driver() -> void:
	chase_camera.current = false
	driver = null

func install_part(point_name: String, part: Node, marker: Node3D) -> bool:
	if not attach_points.has(point_name):
		return false
	if installed_parts.has(point_name):
		return false
	installed_parts[point_name] = part
	part.install(self, point_name, marker)
	part.broke.connect(_on_part_broke.bind(point_name))
	part_attached.emit(point_name)
	if installed_parts.size() >= attach_points.size():
		is_wrecked = false
		var buyer := get_tree().get_first_node_in_group("buyer")
		if buyer:
			GameManager.set_objective(buyer.global_position, "Entregue o carro na CASA marcada (placa verde), na cidade")
	return true

func _on_part_broke(point_name: String) -> void:
	installed_parts.erase(point_name)
	part_broken.emit(point_name)

func intact_part_count() -> int:
	return installed_parts.size()

func total_attach_points() -> int:
	return attach_points.size()

## Chamado por MudZone.gd quando o carro entra/sai de uma poca. So reduz
## a tracao de verdade se tambem estiver chovendo (ver _current_traction()).
func enter_mud() -> void:
	mud_zones_overlapping += 1

func exit_mud() -> void:
	mud_zones_overlapping = max(0, mud_zones_overlapping - 1)

func _current_traction() -> float:
	if mud_zones_overlapping > 0 and WeatherManager.is_raining:
		return WeatherManager.mud_traction_factor
	return 1.0

func hit_pothole(force: float) -> void:
	apply_central_impulse(Vector3.UP * force * 0.35)
	_stress_all_parts(force)

func _on_body_entered(_body: Node) -> void:
	var impact: float = linear_velocity.length()
	if impact > 3.0:
		_stress_all_parts(impact * 1.5)

func _stress_all_parts(force: float) -> void:
	for point_name in installed_parts.keys().duplicate():
		var part = installed_parts.get(point_name)
		if part and is_instance_valid(part):
			part.receive_stress(force)

func _physics_process(delta: float) -> void:
	if driver:
		throttle_input = 0.0
		if Input.is_key_pressed(KEY_W):
			throttle_input += 1.0
		if Input.is_key_pressed(KEY_S):
			throttle_input -= 1.0
		steer_input = 0.0
		if Input.is_key_pressed(KEY_A):
			steer_input += 1.0
		if Input.is_key_pressed(KEY_D):
			steer_input -= 1.0
		handbrake = Input.is_key_pressed(KEY_SPACE)
	else:
		throttle_input = 0.0
		steer_input = 0.0
		handbrake = false
	_apply_suspension_and_drive(delta)
	if smoke_fx:
		smoke_fx.emitting = (attach_points.size() - installed_parts.size()) > 0

func _apply_suspension_and_drive(_delta: float) -> void:
	var traction: float = _current_traction()
	for wheel in wheels:
		if not wheel.is_colliding():
			continue
		var contact: Vector3 = wheel.get_collision_point()
		var wheel_world: Vector3 = wheel.global_transform.origin
		var ray_end: Vector3 = wheel.to_global(wheel.target_position)
		var ray_dir: Vector3 = (ray_end - wheel_world).normalized()
		var distance: float = wheel_world.distance_to(contact)
		var compression: float = suspension_rest_length - distance
		if compression < 0.0:
			continue
		var offset: Vector3 = contact - global_transform.origin
		var world_vel: Vector3 = linear_velocity + angular_velocity.cross(offset)
		var relative_vel: float = world_vel.dot(ray_dir)
		var spring_force: float = (compression * suspension_strength) - (relative_vel * suspension_damping)
		apply_force(-ray_dir * spring_force, offset)

		var forward: Vector3 = -global_transform.basis.z
		var right: Vector3 = global_transform.basis.x
		if wheel.name.begins_with("WheelF"):
			forward = forward.rotated(Vector3.UP, steer_input * max_steer_angle)
		if not handbrake:
			var engine_force: float = max_engine_force * lerp(0.5, 1.0, traction)
			apply_force(forward * throttle_input * engine_force, offset)

		var side_vel: float = world_vel.dot(right)
		var grip_mult: float = (2.0 if handbrake else 10.0) * traction
		var grip: Vector3 = -right * side_vel * mass * grip_mult
		apply_force(grip, offset)
