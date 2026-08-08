extends CharacterBody3D
## Controlador do jogador. WASD anda, Shift corre, Space pula, E interage
## (olhando via raycast), **V troca entre 1a e 3a pessoa**, F sai do carro
## quando dirigindo. Ao entrar num veiculo, some e cede o controle/camera para
## o Vehicle.gd.
##
## O corpo e a mulher de cabeca de jegue montada por `PlayerVisual.gd`.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.5
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.0025

## Acima disso o corpo troca de parado pra andando; acima do segundo, pra
## correndo. Saem da velocidade real do corpo, nao da tecla: assim empurrado ou
## escorregando o boneco tambem se mexe.
const WALK_ANIM_SPEED := 0.6
const RUN_ANIM_SPEED := 5.6

## Passada, em metros. Correndo a passada ABRE (nao so acelera) — por isso duas
## medidas em vez de uma cadencia por tempo.
const STEP_STRIDE_WALK := 0.78
const STEP_STRIDE_RUN := 1.15

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var third_person_arm: SpringArm3D = $Head/ThirdPersonArm
@onready var third_person_camera: Camera3D = $Head/ThirdPersonArm/ThirdPersonCamera
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var tow_hook: Node3D = $TowHook

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var current_interactable: Node = null
var driving_vehicle: Node = null
var hud: Node = null
var visual: Node3D = null
var third_person := false
var _e_prev := false
var _v_prev := false
var _step_accum := 0.0
var _anim: AnimationPlayer = null

func _ready() -> void:
	add_to_group("player")
	# O raio de interacao nasce DENTRO da capsula do jogador (a camera fica na
	# cabeca). Olhando pra baixo — que e o caso de qualquer alvo baixo, tipo o
	# ponto do radiador do carro — ele saia atravessando o proprio corpo e
	# retornava o PROPRIO jogador como alvo, entao a interacao simplesmente nao
	# acontecia.
	interact_ray.add_exception(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud = get_tree().get_first_node_in_group("hud")
	visual = PlayerVisual.build(self)
	if visual:
		_anim = visual.get_node_or_null("AnimationPlayer")
	# A mola da 3a pessoa nao pode se apoiar no proprio jogador, senao a camera
	# gruda nas costas dele e nunca recua.
	third_person_arm.add_excluded_object(get_rid())
	_apply_camera_mode()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# A inclinacao vai na CABECA, nao na camera de 1a pessoa: a mola da 3a
		# pessoa e irma dela debaixo do mesmo no, entao assim as duas cameras
		# olham pra cima e pra baixo juntas. Aplicada so na camera (como era
		# antes), a de 3a pessoa ficava presa na horizontal.
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	var e_now := Input.is_key_pressed(KEY_E)
	var e_just := e_now and not _e_prev
	_e_prev = e_now

	# V alterna 1a/3a pessoa, na borda de subida (mesmo padrao do E).
	var v_now := Input.is_key_pressed(KEY_V)
	if v_now and not _v_prev:
		toggle_camera_mode()
	_v_prev = v_now

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

	var was_on_floor := is_on_floor()
	var fall_speed := -velocity.y
	move_and_slide()
	_update_steps(delta)
	if not was_on_floor and is_on_floor() and fall_speed > 3.0:
		AudioManager.play_at(_surface_sound(), global_position,
			lerpf(-14.0, -5.0, clampf(fall_speed / 12.0, 0.0, 1.0)), 0.85, 22.0)
	_update_animation()
	_update_interaction()
	if e_just:
		_try_interact()

## Passo a cada tanto de CHAO ANDADO, nao a cada tanto de tempo: assim a
## cadencia acompanha sozinha o andar e a corrida, sem um segundo temporizador
## pra manter em sincronia com a animacao.
func _update_steps(_delta: float) -> void:
	if not is_on_floor():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < WALK_ANIM_SPEED:
		_step_accum = STEP_STRIDE_WALK * 0.6   # o proximo passo sai quase de cara
		return
	_step_accum += speed * _delta
	var stride: float = lerpf(STEP_STRIDE_WALK, STEP_STRIDE_RUN,
		clampf((speed - WALK_SPEED) / maxf(SPRINT_SPEED - WALK_SPEED, 0.01), 0.0, 1.0))
	if _step_accum < stride:
		return
	_step_accum = 0.0
	AudioManager.play_at(_surface_sound(), global_position, -13.0,
		randf_range(0.92, 1.08), 18.0)

## Mato ou piso duro, decidido pelo que esta DEBAIXO do pe. Usa o mesmo criterio
## do `GrassField` (grupo `terreno_natural`), entao passo e grama concordam por
## construcao — asfalto, meio-fio, laje e predio nao estao no grupo e por isso
## soam duro sem precisar de lista de excecao.
func _surface_sound() -> String:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.4
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.6)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return "passo_duro"
	var body: Node = hit["collider"]
	return "passo_mato" if body.is_in_group("terreno_natural") else "passo_duro"

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

## V. Guardado como estado proprio (e nao lido da camera) pra sobreviver a
## entrar e sair do carro: quem estava em 3a pessoa a pe volta em 3a pessoa.
func toggle_camera_mode() -> void:
	third_person = not third_person
	_apply_camera_mode()

func _apply_camera_mode() -> void:
	if driving_vehicle:
		return
	camera.current = not third_person
	third_person_camera.current = third_person
	if visual == null:
		return
	# Em 1a pessoa o corpo nao some: ele passa a SO PROJETAR SOMBRA. Escondido
	# de vez, o jogador perde a propria sombra no chao — que e a unica pista de
	# onde ele esta parado. Visivel de vez, a camera fica dentro da cabeca de
	# jegue e o focinho toma a tela.
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if third_person \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_set_shadow_mode(visual, mode)

func _set_shadow_mode(node: Node, mode: int) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = mode
	for c in node.get_children():
		_set_shadow_mode(c, mode)

## Corpo parado, andando ou correndo, decidido pela velocidade REAL do corpo.
func _update_animation() -> void:
	if _anim == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var wanted := "idle"
	if speed > RUN_ANIM_SPEED:
		wanted = "run"
	elif speed > WALK_ANIM_SPEED:
		wanted = "walk"
	if not _anim.has_animation(wanted):
		return
	if _anim.current_animation != wanted:
		_anim.play(wanted, 0.15)

func enter_vehicle(vehicle: Node) -> void:
	driving_vehicle = vehicle
	visible = false
	camera.current = false
	third_person_camera.current = false
	# A capsula tem que SAIR do mundo, nao so ficar invisivel. CharacterBody3D e
	# cinematico: pra um RigidBody ele e uma parede que nao cede. Como o jogador
	# para de andar ao dirigir, o corpo ficava plantado exatamente onde ele
	# estava em pe — em geral do lado ou na frente do carro que ele acabou de
	# entrar — e segurava o carro no lugar. O verificador do patio flagrou isso
	# como "barrado por Main/Player a 2.1 m", com o carro andando 0.0 m.
	_set_body_solid(false)

func exit_vehicle() -> void:
	if driving_vehicle:
		var v: Node = driving_vehicle
		global_position = v.global_position + v.global_transform.basis.x * 2.0 + Vector3(0, 1, 0)
		v.exit_to_driver()
	driving_vehicle = null
	visible = true
	_set_body_solid(true)
	_apply_camera_mode()

## Liga/desliga a colisao do jogador. `set_deferred` porque isso e chamado de
## dentro do passo de fisica, e mexer em forma de colisao ali e erro no Godot.
func _set_body_solid(solid: bool) -> void:
	var shape := get_node_or_null("CollisionShape3D")
	if shape:
		shape.set_deferred("disabled", not solid)

func start_towing(vehicle: Node) -> void:
	tow_hook.attach(vehicle)
	var workshop := get_tree().get_first_node_in_group("workshop")
	if workshop and workshop.has_method("get_drop_position"):
		GameManager.set_objective(workshop.get_drop_position(), "Leve o carro ate a OFICINA (placa azul)")

func stop_towing() -> void:
	tow_hook.detach()
