extends CharacterBody3D
## Controlador do jogador em 1a pessoa. WASD anda, Shift corre, Space
## pula, E interage (olhando via raycast), F sai do carro quando dirigindo.
## Ao entrar num veiculo, some (visible=false) e cede o controle/camera
## para o Vehicle.gd (terceira pessoa).

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.5
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.0025

@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var tow_hook: Node3D = $TowHook

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var current_interactable: Node = null
var driving_vehicle: Node = null
var hud: Node = null
var _e_prev := false

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	hud = get_tree().get_first_node_in_group("hud")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	var e_now := Input.is_key_pressed(KEY_E)
	var e_just := e_now and not _e_prev
	_e_prev = e_now

	if driving_vehicle:
		if Input.is_key_pressed(KEY_F):
			exit_vehicle()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	if direction.length() > 0.01:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_interaction()
	if e_just:
		_try_interact()

func _update_interaction() -> void:
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud")
	var collider: Node = null
	if interact_ray.is_colliding():
		collider = interact_ray.get_collider()
	current_interactable = collider
	if hud:
		if collider and collider.has_method("get_interact_prompt"):
			hud.set_prompt(collider.get_interact_prompt())
		else:
			hud.set_prompt("")

func _try_interact() -> void:
	if current_interactable and current_interactable.is_in_group("interactable") and current_interactable.has_method("interact"):
		current_interactable.interact(self)

func enter_vehicle(vehicle: Node) -> void:
	driving_vehicle = vehicle
	visible = false
	camera.current = false

func exit_vehicle() -> void:
	if driving_vehicle:
		var v: Node = driving_vehicle
		global_position = v.global_position + v.global_transform.basis.x * 2.0 + Vector3(0, 1, 0)
		v.exit_to_driver()
	driving_vehicle = null
	visible = true
	camera.current = true

func start_towing(vehicle: Node) -> void:
	tow_hook.attach(vehicle)
	var workshop := get_tree().get_first_node_in_group("workshop")
	if workshop and workshop.has_method("get_drop_position"):
		GameManager.set_objective(workshop.get_drop_position(), "Leve o carro ate a OFICINA (placa azul)")

func stop_towing() -> void:
	tow_hook.detach()
