extends CharacterBody3D
## Controlador do jogador. WASD anda, Shift corre, Space pula, E interage
## (olhando via raycast), **V troca entre 1a e 3a pessoa**, F sai do carro
## quando dirigindo ou tenta um blefe quando negocia com um comprador. Ao
## entrar num veiculo, some e cede o controle/camera para o Vehicle.gd.
##
## O corpo e a mulher de cabeca de jegue montada por `PlayerVisual.gd`.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.5
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.0025
## Quao rapido o boneco se alinha ao rumo do andar na camera LIVRE (rad/s).
const TURN_SPEED := 9.0

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

## As tres visoes que o V cicla, nesta ordem.
##
## A diferenca entre as duas de 3a pessoa nao e o enquadramento, e QUEM O MOUSE
## GIRA: em ATRAS o mouse gira o corpo (a camera fica sempre nas costas, que e o
## bom pra dirigir e pra andar), e em LIVRE o mouse gira so a camera em volta do
## boneco, que fica parado olhando pra onde estava — e o modo de olhar o proprio
## personagem e o cenario.
enum Cam {PRIMEIRA, TERCEIRA_ATRAS, TERCEIRA_LIVRE}
var camera_mode: Cam = Cam.PRIMEIRA
## Mantido por compatibilidade: varios lugares (e os testes) perguntam so se o
## corpo aparece na tela.
var third_person := false

## Angulos da camera LIVRE, acumulados a parte do corpo. Precisam ser proprios:
## se o mouse escrevesse na rotacao do jogador, o boneco viraria junto — que e
## exatamente o que este modo existe pra nao fazer.
var _free_yaw := 0.0
var _free_pitch := -0.15
var _free_pivot: Node3D = null
var _free_arm: SpringArm3D = null
var _free_camera: Camera3D = null
var _e_prev := false
var _v_prev := false
var _q_prev := false
var _f_prev := false
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
	_apply_height()
	visual = PlayerVisual.build(self)
	if visual:
		_anim = visual.get_node_or_null("AnimationPlayer")
	# A mola da 3a pessoa nao pode se apoiar no proprio jogador, senao a camera
	# gruda nas costas dele e nunca recua.
	third_person_arm.add_excluded_object(get_rid())
	_build_free_camera()
	_apply_camera_mode()

## Altura escolhida na tela de personagem (`Appearance.height`), aplicada ao
## CORPO — nao so ao desenho.
##
## O `PlayerVisual` ja escala a malha; se a capsula e a cabeca ficassem no
## tamanho do arquivo de cena, um jogador de 1,60 m andaria com a camera acima
## do proprio cranio e um de 1,95 m com os pes enterrados. Tudo sai de
## `BASE_HEIGHT`, que e a altura pra qual o `Player.tscn` foi desenhado.
##
## O RAIO da capsula fica como esta de proposito: engrossar o jogador junto com
## a altura mudaria por onde ele passa (vao de cerca, corredor do patio), e isso
## e geometria que o resto do jogo ja mede.
const BASE_HEIGHT := 1.80

func _apply_height() -> void:
	var factor := Appearance.height / BASE_HEIGHT
	var shape_node := $CollisionShape3D as CollisionShape3D
	var capsule := shape_node.shape as CapsuleShape3D
	if capsule:
		# Duplicar: o `SubResource` do `.tscn` e COMPARTILHADO entre instancias da
		# cena, entao escrever direto mudaria a capsula de qualquer outro Player
		# vivo (e o verificador instancia mais de um).
		capsule = capsule.duplicate() as CapsuleShape3D
		capsule.height = BASE_HEIGHT * factor
		shape_node.shape = capsule
		shape_node.position.y = capsule.height * 0.5
	head.position.y = 1.6 * factor

## Monta o braco da camera LIVRE em codigo.
##
## Fora da `$Head` de proposito: a cabeca carrega a inclinacao do olhar e o corpo
## carrega o giro, e esta camera nao pode herdar nenhum dos dois — ela e apontada
## por angulo proprio. Pendurada na cabeca, o boneco arrastaria a camera junto ao
## virar, que e o oposto do que o modo faz.
func _build_free_camera() -> void:
	_free_pivot = Node3D.new()
	_free_pivot.name = "FreePivot"
	_free_pivot.top_level = true   # ignora a transformada do pai
	add_child(_free_pivot)
	_free_arm = SpringArm3D.new()
	_free_arm.name = "FreeArm"
	_free_arm.spring_length = third_person_arm.spring_length
	_free_arm.collision_mask = third_person_arm.collision_mask
	_free_arm.add_excluded_object(get_rid())
	_free_pivot.add_child(_free_arm)
	_free_camera = Camera3D.new()
	_free_camera.name = "FreeCamera"
	_free_camera.fov = third_person_camera.fov
	_free_camera.far = third_person_camera.far
	_free_arm.add_child(_free_camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if camera_mode == Cam.TERCEIRA_LIVRE and not driving_vehicle:
			# So a camera orbita. O corpo fica como esta — e o unico modo em que
			# mexer o mouse NAO vira o boneco.
			_free_yaw -= event.relative.x * MOUSE_SENSITIVITY
			_free_pitch = clampf(_free_pitch - event.relative.y * MOUSE_SENSITIVITY,
				deg_to_rad(-70.0), deg_to_rad(70.0))
			return
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

	# Q negocia com o que estiver na mira (vistoriar/pechinchar uma carcaca).
	# Borda de subida, como o E e o V.
	var q_now := Input.is_key_pressed(KEY_Q)
	var q_just := q_now and not _q_prev
	_q_prev = q_now

	# F sai do carro ou blefa com o comprador. Tambem usa borda de subida: sem
	# ela um toque gastaria todas as rodadas da conversa em poucos frames.
	var f_now := Input.is_key_pressed(KEY_F)
	var f_just := f_now and not _f_prev
	_f_prev = f_now

	# V alterna 1a/3a pessoa, na borda de subida (mesmo padrao do E).
	var v_now := Input.is_key_pressed(KEY_V)
	if v_now and not _v_prev:
		toggle_camera_mode()
	_v_prev = v_now

	if driving_vehicle:
		if f_just:
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
	if camera_mode == Cam.TERCEIRA_LIVRE:
		# Na camera livre o corpo nao acompanha o mouse, entao andar pelo eixo do
		# CORPO daria a sensacao de controle invertido assim que a camera girasse
		# pro lado. O W anda pra onde a camera olha.
		direction = (Basis(Vector3.UP, _free_yaw) * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		# E o boneco vira pra onde ANDA — nunca pelo mouse. Parado, ele fica
		# exatamente como estava, que e o que este modo promete.
		if direction.length() > 0.01:
			var alvo := atan2(-direction.x, -direction.z)
			rotation.y = rotate_toward(rotation.y, alvo, TURN_SPEED * delta)
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
	if camera_mode == Cam.TERCEIRA_LIVRE:
		_update_free_camera()
	_update_animation()
	_update_interaction()
	if e_just:
		_try_interact()
	if q_just:
		_try_negotiate()
	if f_just:
		_try_bluff()

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

## Q no alvo da mira. Separado do E de proposito: comprar e negociar sao acoes
## diferentes, e juntar as duas na mesma tecla faria o jogador comprar sem
## querer no meio de uma pechincha.
func _try_negotiate() -> void:
	if current_interactable and current_interactable.has_method("negotiate"):
		current_interactable.negotiate()

## F no cliente durante a conversa. Fora dela (e fora de um carro), nao faz
## nada; assim a tecla continua livre no restante do loop.
func _try_bluff() -> void:
	if current_interactable and current_interactable.has_method("bluff"):
		current_interactable.bluff()

func _try_interact() -> void:
	if current_interactable and current_interactable.is_in_group("interactable") and current_interactable.has_method("interact"):
		current_interactable.interact(self)

## V. Guardado como estado proprio (e nao lido da camera) pra sobreviver a
## entrar e sair do carro: quem estava em 3a pessoa a pe volta em 3a pessoa.
func toggle_camera_mode() -> void:
	camera_mode = ((camera_mode + 1) % Cam.size()) as Cam
	# Entrando na LIVRE, a camera comeca ONDE A DE TRAS ESTAVA. Sem isso ela
	# saltava pro ultimo angulo livre usado (ou pro zero, no primeiro uso) e a
	# troca virava um corte seco pra outra direcao.
	if camera_mode == Cam.TERCEIRA_LIVRE:
		_free_yaw = rotation.y
		_free_pitch = head.rotation.x
	_apply_camera_mode()

func _apply_camera_mode() -> void:
	if driving_vehicle:
		return
	third_person = camera_mode != Cam.PRIMEIRA
	camera.current = camera_mode == Cam.PRIMEIRA
	third_person_camera.current = camera_mode == Cam.TERCEIRA_ATRAS
	if _free_camera:
		_free_camera.current = camera_mode == Cam.TERCEIRA_LIVRE
	if camera_mode == Cam.TERCEIRA_LIVRE:
		_update_free_camera()
	if visual == null:
		return
	# Em 1a pessoa o corpo nao some: ele passa a SO PROJETAR SOMBRA. Escondido
	# de vez, o jogador perde a propria sombra no chao — que e a unica pista de
	# onde ele esta parado. Visivel de vez, a camera fica dentro da cabeca de
	# jegue e o focinho toma a tela.
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if third_person \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_set_shadow_mode(visual, mode)

## Poe o pivo da camera livre na altura da cabeca do jogador e aponta pelos
## angulos proprios. Como o pivo e `top_level`, escrever a transformada GLOBAL
## aqui e o que mantem ele imune ao giro do corpo.
func _update_free_camera() -> void:
	if _free_pivot == null:
		return
	_free_pivot.global_position = head.global_position
	_free_pivot.global_rotation = Vector3(_free_pitch, _free_yaw, 0.0)

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
