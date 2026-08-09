extends RigidBody3D
## Carro com fisica caotica: modelo de carro de verdade (ver CarRig.gd),
## suspensao por raycast nas 4 rodas, tracao traseira, pontos de fixacao para
## gambiarras e "chase camera" para o test-drive em terceira pessoa.
## Controles (quando ha motorista): W/S acelera/freia-re, A/D vira,
## Space freio de mao, F sai do carro.
##
## A suspensao segura o carro DE VERDADE. Antes `suspension_strength` era 140,
## o que da 14 N por 10cm de compressao contra 17100 N de peso (950 kg com a
## gravidade 18 do projeto): o carro na pratica deslizava apoiado na caixa de
## colisao e a mola era enfeite. Agora a rigidez sai da conta de equilibrio
## (peso / compressao desejada), entao continua certa se a massa mudar.

signal part_broken(point_name: String)
signal part_attached(point_name: String)

@export var is_wrecked := true

## Modelo do carro. Se ficar vazio, sorteia um de `car_pool` — assim cada
## carcaca que aparece no mapa e um carro diferente. As medidas (eixos, bitola,
## raio de roda, caixa da carroceria) sao lidas do proprio modelo em _ready(),
## entao qualquer um deles funciona sem reposicionar nada.
@export var car_model: PackedScene
@export var car_pool: Array[PackedScene] = [
	preload("res://assets/quaternius/cars/car-a.glb"),
	preload("res://assets/quaternius/cars/car-b.glb"),
	preload("res://assets/quaternius/cars/sports-car-a.glb"),
	preload("res://assets/quaternius/cars/sports-car-b.glb"),
	preload("res://assets/quaternius/cars/suv.glb"),
	preload("res://assets/quaternius/cars/taxi.glb"),
]
## Cores de calhambeque: foscas e desbotadas de proposito. Carro de ferro-velho
## nao sai da tinta de fabrica, e cor saturada brigaria com a cidade.
@export var paint_colors: Array[Color] = [
	Color(0.62, 0.20, 0.16),   # vermelho desbotado
	Color(0.26, 0.34, 0.48),   # azul fosco
	Color(0.72, 0.68, 0.58),   # bege sujo
	Color(0.34, 0.40, 0.32),   # verde militar
	Color(0.78, 0.62, 0.22),   # mostarda
	Color(0.45, 0.45, 0.47),   # cinza chumbo
	Color(0.68, 0.40, 0.22),   # laranja ferrugem
	Color(0.20, 0.20, 0.22),   # preto fosco
]

@export_group("Motor")
## Forca por roda de tracao (o carro e tracao traseira: 2 rodas).
@export var max_engine_force := 4200.0
@export var max_reverse_force := 2200.0
@export var brake_force := 6000.0
## Arrasto: e ele que define a velocidade final, nao um limite artificial.
@export var air_drag := 6.0        ## N por (m/s)^2
@export var rolling_drag := 120.0  ## N por (m/s)

@export_group("Direcao")
@export var max_steer_angle := 0.55
## Esterco util cai com a velocidade — sem isso o carro capota ao virar a 60km/h.
@export var steer_speed_falloff := 0.62
@export var steer_response := 6.0  ## quao rapido a roda acompanha a tecla
## Aderencia lateral, em multiplos do peso da roda. Acima disso a roda desliza,
## que e o que deixa o carro derrapar em vez de andar sobre trilhos.
@export var lateral_grip := 1.6
@export var handbrake_grip := 0.35
## Aderencia lateral enquanto o carro esta sendo REBOCADO. Bem baixa de
## proposito: uma carcaca puxada de lado com pneu agarrando trava a lateral e
## CAPOTA nos proprios pneus — o teste de loop viu o carro chegar de cabeca pra
## baixo na oficina em 2 de 3 rodadas, e assim nao da pra montar nem dirigir.
## Carcaca morta desliza, nao faz curva.
@export var tow_grip := 0.12
## Amortecimento angular no reboque, pra ele nao sair rodopiando atras.
@export var tow_angular_damp := 6.0

@export_group("Suspensao")
@export var suspension_travel := 0.42   ## curso total do amortecedor
@export var rest_compression := 0.16    ## quanto a mola afunda parada
@export var damping_ratio := 0.45       ## 1.0 = criticamente amortecido

@onready var attach_points_node: Node3D = $AttachPoints
## Criado em runtime por `_place_part_anchors`: um ponto por gambiarra, no lugar
## que o nome dela diz. Separado dos marcadores de mira de proposito.
var part_anchors_node: Node3D = null
@onready var chase_camera: Camera3D = $ChaseCameraRig/ChaseCamera
@onready var chase_rig: SpringArm3D = $ChaseCameraRig
@onready var smoke_fx: GPUParticles3D = $SmokeFX
@onready var body_shape: CollisionShape3D = $CollisionShape3D

var attach_points: Dictionary = {}
var installed_parts: Dictionary = {}
## Opcao do catalogo usada em cada ponto (ver Economy.GAMBIARRAS).
var installed_options: Dictionary = {}
var driver: Node = null
var steer_input := 0.0
var throttle_input := 0.0
var handbrake := false
var mud_zones_overlapping := 0
var being_towed := false
## Ligado pela DropZone da oficina. Enquanto o carro esta la, mirar na
## carroceria NAO oferece mais "Rebocar": era a armadilha que travava o jogo.
## A carroceria e o alvo obvio (ocupa a tela inteira ao lado dos 4 marcadores
## pequenos), entao o jogador mirava nela, apertava E achando que montava a
## gambiarra, e o que acontecia era o reboque reengatar — o carro voltava a
## seguir o jogador pelo patio e a montagem parecia simplesmente nao funcionar.
var at_workshop := false

var rig: CarRig
var wheels: Array[RayCast3D] = []
var _steer_angle := 0.0
var audio: VehicleAudio = null

# ------------------------------------------------------- negocio da carcaca
## Estado permanente deste carro (km, lataria, pintura) e o modelo — e deles que
## sai o valor. Ate agora todo carro valia os mesmos R$ 220 e vinha DE GRACA:
## o dinheiro so subia, entao nao havia decisao nenhuma no ferro-velho.
var model_key := ""
var condition: Dictionary = {}
## Estado de cada peca mecanica (ver Economy.PARTS). Fica ESCONDIDO ate o
## diagnostico: comprar sem saber o que esta quebrado e o risco do negocio.
var parts: Dictionary = {}
var diagnosed := false
## Preco pedido pela carcaca e se ela ja e do jogador.
var asking_price := 0
var owned := false
## A vistoria revela o estado. Sem ela o jogador so ve o preco, e nao sabe se
## esta fazendo uma barganha ou levando um abacaxi.
var inspected := false
var haggles_left := 0
var _haggle_locked := false

var _r_prev := false
## Velocidade do passo anterior, pra medir o tranco de uma batida.
var _prev_velocity := Vector3.ZERO
var _spring_k := 0.0
var _spring_c := 0.0
var _rest_length := 0.0
var _max_spring_force := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("vehicle")
	contact_monitor = true
	max_contacts_reported = 4
	# Corpo movido por forca continua NAO pode dormir: o Godot adormece o
	# RigidBody quando a velocidade cai, e apply_force nao acorda ele — o carro
	# parava de responder ao acelerador depois de qualquer paradinha.
	can_sleep = false
	body_entered.connect(_on_body_entered)

	audio = VehicleAudio.new()
	audio.name = "VehicleAudio"
	add_child(audio)

	rig = CarRig.new()
	rig.name = "CarRig"
	add_child(rig)
	# Sorteio proprio: usar randi() global faria o carro consumir a mesma
	# sequencia de trafego e pedestres e mudaria a cidade inteira de layout.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var model := car_model
	if model == null and not car_pool.is_empty():
		model = car_pool[rng.randi() % car_pool.size()]
	if model:
		model_key = model.resource_path.get_file().get_basename()
	condition = Economy.roll_condition(rng)
	parts = Economy.roll_parts(rng)
	# Carro que ja nasce pronto (nao e carcaca) nao tem defeito escondido.
	if not is_wrecked:
		for key: String in parts:
			parts[key] = 1.0
		diagnosed = true
	asking_price = Economy.wreck_asking_price(model_key, condition, rng)
	haggles_left = Economy.HAGGLE_TRIES
	# Carro que nasce ja consertado (nao e carcaca) e do jogador por definicao.
	owned = not is_wrecked
	if not rig.build(model):
		push_warning("Vehicle: sem modelo de carro, usando so a colisao")
	elif not paint_colors.is_empty():
		rig.paint(paint_colors[rng.randi() % paint_colors.size()])
	_fit_to_model()
	_tune_suspension()

	for spot in attach_points_node.get_children():
		if spot.has_method("get_interact_prompt"):
			attach_points[spot.point_name] = spot

## Encaixa colisao, raycasts de suspensao, pontos de gambiarra e camera nas
## medidas REAIS do modelo carregado.
func _fit_to_model() -> void:
	var box: AABB = rig.body_aabb
	if box.size == Vector3.ZERO:
		return
	var shape := BoxShape3D.new()
	shape.size = box.size
	body_shape.shape = shape
	body_shape.position = box.position + box.size * 0.5

	# CENTRO DE MASSA BAIXO, na altura do eixo. Por padrao o Godot usa o centro
	# da caixa de colisao, ou seja a meia-altura da carroceria — com isso o
	# carro faz curva apoiado num ponto alto e CAPOTA (o banco de provas viu o
	# SUV deitar, up=0.03). Num carro de verdade a massa (motor, chassi,
	# tanque) fica embaixo, entao isso e mais correto e nao um truque.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, rig.axle_y, 0.0)

	# Geometria da suspensao, na ordem certa (errar isso zerava a mola):
	#  - a origem do raio fica meio curso ACIMA do centro da roda em repouso;
	#  - o comprimento LIVRE da mola e essa altura MAIS o afundamento desejado,
	#    entao parado a mola ja esta comprimida em `rest_compression` e empurra
	#    exatamente o peso do carro.
	# Antes eu usava `rig.axle_y + rest_compression` como origem E como
	# comprimento livre: a compressao dava ZERO parado, a mola nao sustentava
	# nada e o carro arrastava a barriga na caixa de colisao (o atrito da
	# barriga era maior que a forca do motor, entao ele nem saia do lugar).
	var origin_y: float = rig.axle_y + suspension_travel * 0.5
	_rest_length = origin_y + rest_compression
	for spec: Array in [["WheelFL", -rig.half_track, rig.front_axle_z],
			["WheelFR", rig.half_track, rig.front_axle_z],
			["WheelRL", -rig.half_track, rig.rear_axle_z],
			["WheelRR", rig.half_track, rig.rear_axle_z]]:
		var ray := get_node_or_null(NodePath(spec[0])) as RayCast3D
		if ray == null:
			continue
		ray.position = Vector3(spec[1], origin_y, spec[2])
		# Alcance ate a mola totalmente estendida, com folga pra achar o chao
		# quando a roda fica no ar.
		ray.target_position = Vector3(0.0, -(_rest_length + 0.15), 0.0)
		wheels.append(ray)

	_place_attach_points(box)

	# Camera atras e acima do teto, olhando por cima do carro.
	chase_rig.position = Vector3(0.0, box.position.y + box.size.y + 0.9, box.size.z * 0.42)
	chase_rig.spring_length = box.size.z * 1.7
	if smoke_fx:
		# Na grade, baixo e no centro. Descentralizar (tentativa anterior) so
		# trocava de vitima: a coluna saia de cima do marcador do capo e passava
		# a cobrir o do radiador. O que resolve e o penacho ser BAIXO (ver o
		# SmokePPM no .tscn), ai ele morre antes da altura dos marcadores.
		smoke_fx.position = Vector3(0.0, box.position.y + box.size.y * 0.25,
			box.position.z + 0.10)

## Os 4 pontos de gambiarra saem da caixa da carroceria, nao de coordenadas
## escritas na mao: capo e radiador na frente, retrovisor na porta do
## motorista, parachoque atras.
##
## Todos ficam PRA FORA da caixa de colisao, cada um na sua face. Isso nao e
## enfeite: a colisao do carro e uma caixa unica, entao marcador pousado na
## superficie (em cima do capo, por exemplo) fica DENTRO dela e o raycast de
## interacao acerta a carroceria antes da esfera — o jogador simplesmente nao
## consegue mirar na gambiarra. Foi o que o teste de loop pegou: 3 dos 4
## pontos eram inalcancaveis.
func _place_attach_points(box: AABB) -> void:
	var hw: float = box.size.x * 0.5
	var hl: float = box.size.z * 0.5
	var y0: float = box.position.y
	var h: float = box.size.y
	# Folga entre a caixa de colisao e o CENTRO do marcador. O valor antigo (0.5)
	# vinha de uma conta errada — dizia "a esfera do marcador tem raio 0.3",
	# quando a esfera VISIVEL tem 0.16 e o hitbox tem 0.45. Meio metro deixava as
	# bolinhas boiando soltas longe da lataria, parecendo enfeite aleatorio em
	# vez de "encaixe aqui" (visto na foto do ponto de vista do jogador).
	#
	# Encostar nao custa mira: quem decide a facilidade e o HITBOX (raio 0.45),
	# que continua saindo 0.45 pra fora da caixa a partir do centro do marcador —
	# ou seja o raio de interacao ainda acerta a esfera antes da carroceria.
	# Aqui a folga e so a da esfera visivel, pra ela nao afundar na lataria.
	var out := 0.20
	# UMA FACE PRA CADA: capo por CIMA, retrovisor na lateral ESQUERDA, radiador
	# na lateral DIREITA (capo do lado do motor), parachoque atras.
	# Antes capo e radiador dividiam a face dianteira, um acima do outro: quem
	# mirava no radiador acertava a esfera do capo. Depois o radiador foi pra
	# baixo do bico e virou o ponto mais dificil do jogo — o unico que exigia
	# olhar quase a pino. Cada marcador com a sua face resolve os dois casos e
	# deixa os 4 na linha do olhar de quem esta de pe ao lado do carro.
	var spots := {
		"hood": Vector3(0.0, y0 + h + out, -hl * 0.70),
		"radiator": Vector3(hw + out, y0 + h * 0.55, -hl * 0.30),
		"mirror": Vector3(-hw - out, y0 + h * 0.78, -hl * 0.18),
		"bumper": Vector3(0.0, y0 + h * 0.28, hl + out),
	}
	for spot in attach_points_node.get_children():
		if spot is Node3D and spots.has(spot.point_name):
			(spot as Node3D).position = spots[spot.point_name]
	_place_part_anchors(box)

## ONDE A PECA FICA e outra coisa de ONDE SE MIRA.
##
## Os marcadores acima estao espalhados em faces separadas por causa da MIRA (um
## na frente do outro, o raio pega o errado). Enquanto a peca instalada nascia
## no proprio marcador, ela herdava esse espalhamento: a "mangueira do radiador"
## acabava na porta, a "dobradica do capo" pairando acima do teto e o "plastico
## do parachoque" solto atras, todos com folga visivel — na tela lia como cubo
## colorido orbitando o carro, nao como gambiarra. (Visto na foto do ponto de
## vista do jogador; nenhum teste numerico pega isso, porque pra eles basta a
## peca existir e estar presa.)
##
## Aqui cada peca ganha um ponto proprio: no lugar que o NOME dela diz e
## ENCOSTADO na carroceria. A mira continua onde e alcancavel.
func _place_part_anchors(box: AABB) -> void:
	# Limites REAIS da caixa, nao metade do tamanho. A carroceria nao e centrada
	# na origem do modelo: usar `-size.z*0.5` como "a frente" errava por 15 cm e
	# punha a mangueira do radiador atras do bico, dentro da lataria.
	var x_left: float = box.position.x
	var x_right: float = box.position.x + box.size.x
	var z_front: float = box.position.z
	var z_rear: float = box.position.z + box.size.z
	var z_mid: float = (z_front + z_rear) * 0.5
	var y0: float = box.position.y
	var h: float = box.size.y
	# Encosta na lataria em vez de pairar: so o suficiente pra peca nao afundar.
	var skin := 0.06
	# Altura do capo MEDIDA na malha, nao estimada. Uma fracao da caixa nao
	# serve: a caixa e do carro inteiro (o topo dela e o teto), e cada um dos 6
	# modelos tem um capo de altura diferente. Com estimativa, a peca ficava
	# dentro da lataria e o jogador nao via.
	var hood_z: float = z_mid + (z_front - z_mid) * 0.62
	var hood_y: float = rig.surface_y_at(0.0, hood_z) if rig else -INF
	if hood_y == -INF:
		hood_y = y0 + h * 0.62
	var anchors := {
		# Dobradica DEITADA em cima do capo, na frente do para-brisa.
		"hood": Vector3(0.0, hood_y + skin, hood_z),
		# Mangueira saindo da GRADE: na frente do bico, embaixo.
		"radiator": Vector3(x_right * 0.30, y0 + h * 0.34, z_front - skin),
		# Fita no RETROVISOR do motorista: na lateral, na altura da janela.
		"mirror": Vector3(x_left - skin, y0 + h * 0.66,
			z_mid + (z_front - z_mid) * 0.28),
		# Plastico amassado no PARACHOQUE traseiro, embaixo.
		"bumper": Vector3(0.0, y0 + h * 0.22, z_rear + skin),
	}
	if part_anchors_node == null:
		part_anchors_node = Node3D.new()
		part_anchors_node.name = "PartAnchors"
		add_child(part_anchors_node)
	for point_name: String in anchors:
		var a: Node3D = part_anchors_node.get_node_or_null(point_name)
		if a == null:
			a = Node3D.new()
			a.name = point_name
			part_anchors_node.add_child(a)
		a.position = anchors[point_name]

## Rigidez e amortecimento saem da fisica, nao de tentativa e erro: no
## equilibrio a mola de cada roda sustenta 1/4 do peso com `rest_compression`
## de afundamento.
func _tune_suspension() -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var corner_mass: float = mass * 0.25
	_spring_k = corner_mass * gravity / maxf(rest_compression, 0.01)
	# c = 2 * ratio * sqrt(k * m) — a formula do amortecedor de um quarto de carro.
	_spring_c = 2.0 * damping_ratio * sqrt(_spring_k * corner_mass)
	# Teto da forca por roda: 3.5x o peso que ela sustenta parada. Segura um
	# pouso forte sem virar catapulta.
	_max_spring_force = corner_mass * gravity * 3.5

func get_interact_prompt() -> String:
	if driver:
		return ""
	if is_wrecked:
		if at_workshop:
			# Sem "[E]" de proposito: aqui a carroceria nao e um alvo de acao, e
			# a dica de onde a acao esta.
			var missing: int = attach_points.size() - installed_parts.size()
			var linha := "Faltam %d gambiarra(s) — mire nos pontos coloridos" % missing \
				if missing > 0 else "Gambiarras prontas"
			return linha + "\n" + _service_prompt()
		if not owned:
			return _deal_prompt()
		return "Rebocar [E]"
	return "Entrar no carro [E]"

## O que aparece enquanto a carcaca ainda e do ferro-velho.
func _deal_prompt() -> String:
	var linha := "%s — pedem R$ %d  [E] comprar" % [_model_name(), asking_price]
	if not inspected:
		return linha + "  ·  [Q] vistoriar"
	# Depois da vistoria o jogador ve o que esta comprando E o teto do negocio.
	var vale: int = Economy.repaired_value(model_key, condition)
	linha += "\n%s  ·  vale ~R$ %d consertado" % [condition_text(), vale]
	# A vistoria de rua diz QUANTOS problemas tem, nao QUAIS: saber o custo exato
	# exige o diagnostico na oficina. E o risco que faz garimpar ter graca.
	var quebradas: int = Economy.broken_parts(parts).size()
	linha += "\nmotor/freio/suspensão: %s" % ("nada aparente" if quebradas == 0
		else "%d problema(s) mecânico(s)" % quebradas)
	if _haggle_locked:
		return linha + "  ·  o dono nao desce mais"
	if haggles_left > 0:
		return linha + "  ·  [Q] pechinchar (%d)" % haggles_left
	return linha

func _model_name() -> String:
	return model_key.capitalize() if model_key != "" else "Carcaça"

## Estado em texto, do jeito que um anuncio de carro velho descreve.
func condition_text() -> String:
	var km: float = float(condition.get("km", 0.0))
	return "%.0f mil km · lataria %s · pintura %s" % [
		km, _grade(float(condition.get("lataria", 0.0))),
		_grade(float(condition.get("pintura", 0.0)))]

func _grade(v: float) -> String:
	if v < 0.25:
		return "boa"
	if v < 0.55:
		return "ok"
	if v < 0.8:
		return "ruim"
	return "detonada"

## Linha de servico da oficina: diagnosticar e consertar peca.
func _service_prompt() -> String:
	if not diagnosed:
		return "[Q] diagnosticar o carro (não dá pra consertar o que não se viu)"
	var quebradas := Economy.broken_parts(parts)
	if quebradas.is_empty():
		return "mecânica em ordem"
	var full: int = Economy.repaired_value(model_key, condition)
	var lista: Array[String] = []
	for k in quebradas:
		lista.append(str(Economy.PARTS[k]["nome"]))
	# So aparece pra trocar o que a OFICINA aguenta: o resto fica listado como
	# quebrado e sem opcao, que e o que faz o upgrade ser desejado.
	var proxima := _next_repairable()
	if proxima == "":
		return "quebrado: %s  ·  a oficina não dá conta — melhore a oficina" % ", ".join(lista)
	var info: Dictionary = Economy.PARTS[proxima]
	return "quebrado: %s  ·  [Q] trocar %s — R$ %d" % [
		", ".join(lista), info["nome"], Economy.part_price(proxima, full)]

## Primeira peca quebrada que o nivel atual da oficina consegue trocar.
func _next_repairable() -> String:
	for k in Economy.broken_parts(parts):
		if Dealership.can_repair(k):
			return k
	return ""

## [Q] na oficina: diagnostica e depois troca peca por peca, pagando.
func service() -> void:
	GameManager.set_active_vehicle(self)
	if not diagnosed:
		diagnosed = true
		AudioManager.play_ui("confirma", -6.0)
		return
	var key := _next_repairable()
	if key == "":
		AudioManager.play_ui("erro", -12.0)
		return
	var custo := Economy.part_price(key, Economy.repaired_value(model_key, condition))
	if GameManager.money < custo:
		AudioManager.play_ui("erro", -4.0)
		return
	GameManager.add_money(-custo)
	# Peca de verdade e PERMANENTE — o oposto da gambiarra, que volta a quebrar.
	parts[key] = 1.0
	AudioManager.play_at("encaixa", global_position, -2.0, 0.9, 25.0)

## [Q] em cima da carcaca: primeiro vistoria, depois pechincha. Uma tecla so,
## contextual — o prompt sempre diz o que ela faz agora.
func negotiate() -> void:
	# Na oficina o Q deixa de ser negociacao e vira SERVICO (diagnostico e
	# troca de peca): e a mesma tecla contextual, e o prompt sempre diz o que
	# ela faz agora.
	if at_workshop:
		service()
		return
	if owned or not is_wrecked:
		return
	if not inspected:
		inspected = true
		AudioManager.play_ui("passar", -6.0)
		return
	if _haggle_locked or haggles_left <= 0:
		AudioManager.play_ui("erro", -10.0)
		return
	haggles_left -= 1
	# Pechinchar tem RISCO: sem risco a decisao certa seria sempre pechinchar
	# ate o fundo, e o botao viraria burocracia.
	if randf() < Economy.HAGGLE_RISK:
		_haggle_locked = true
		AudioManager.play_ui("erro", -6.0)
		return
	var floor_price: int = Economy.haggle_floor(asking_price)
	asking_price = maxi(floor_price,
		int(round(float(asking_price) * (1.0 - Economy.HAGGLE_STEP))))
	AudioManager.play_ui("confirma", -8.0)

func interact(player: Node) -> void:
	if driver == player:
		return
	if is_wrecked:
		# Na oficina o carro ja chegou: reengatar o reboque so o arrastaria pra
		# longe dos marcadores que o jogador esta tentando acertar.
		if at_workshop:
			return
		# Carcaca do ferro-velho tem dono: primeiro compra, depois reboca.
		if not owned:
			_try_buy()
			return
		if player.has_method("start_towing"):
			player.start_towing(self)
			GameManager.set_active_vehicle(self)
	else:
		if player.has_method("enter_vehicle"):
			driver = player
			GameManager.set_active_vehicle(self)
			player.enter_vehicle(self)
			chase_camera.current = true

## Fecha a compra da carcaca. O dinheiro sai do bolso do jogador — e a primeira
## vez no jogo em que ele pode DIMINUIR, e e isso que faz garimpar valer algo.
func _try_buy() -> void:
	if GameManager.money < asking_price:
		AudioManager.play_ui("erro", -4.0)
		GameManager.set_objective(global_position,
			"Sem dinheiro para esta carcaça (R$ %d)" % asking_price)
		return
	GameManager.add_money(-asking_price)
	owned = true
	GameManager.set_active_vehicle(self)
	AudioManager.play_ui("confirma", -2.0)

## Chamado pelo TowHook ao engatar/soltar.
func set_towed(towed: bool) -> void:
	being_towed = towed
	angular_damp = tow_angular_damp if towed else 0.0

func exit_to_driver() -> void:
	chase_camera.current = false
	driver = null

func install_part(point_name: String, part: Node, marker: Node3D,
		option: Dictionary = {}) -> bool:
	if not attach_points.has(point_name):
		return false
	if installed_parts.has(point_name):
		return false
	# Com varios carros no patio (ver Workshop.gd), o carro "da vez" e aquele em
	# que o jogador esta MEXENDO — senao o HUD continuaria mostrando as
	# gambiarras do carro anterior enquanto ele monta este.
	GameManager.set_active_vehicle(self)
	installed_parts[point_name] = part
	# Guarda QUAL gambiarra foi posta aqui: e o que o cliente olha na hora de
	# descontar (papelao no parachoque nao vale o mesmo que compensado, mesmo os
	# dois estando no lugar). Some junto com a peca quando ela se solta.
	if not option.is_empty():
		installed_options[point_name] = option
	# A peca vai pro ANCORA (lugar que o nome dela diz, encostado na lataria),
	# nao pro marcador de mira que o jogador acertou — os dois so coincidiam por
	# falta de separacao, e era isso que deixava a mangueira na porta.
	var anchor: Node3D = marker
	if part_anchors_node:
		var a: Node3D = part_anchors_node.get_node_or_null(point_name)
		if a:
			anchor = a
	part.install(self, point_name, anchor)
	part.broke.connect(_on_part_broke.bind(point_name))
	part_attached.emit(point_name)
	AudioManager.play_at("encaixa", anchor.global_position, -3.0, 1.0, 25.0)
	if installed_parts.size() >= attach_points.size():
		is_wrecked = false
		# Carro pronto: um toque de confirmacao, porque terminar as 4 gambiarras
		# e o unico momento do loop sem nenhum outro retorno na tela.
		AudioManager.play_ui("confirma", -3.0)
		_point_to_buyer()
	return true

## Aponta a bussola pro cliente MAIS PERTO deste carro. Com a recepcionista
## contratada ha dois clientes na rua ao mesmo tempo (ver DeliveryManager) e
## pegar "o primeiro do grupo" mandaria atravessar a cidade com um deles na
## esquina — e o jogador nem saberia que havia escolha.
func _point_to_buyer() -> void:
	var buyers := get_tree().get_nodes_in_group("buyer")
	if buyers.is_empty():
		return
	var perto: Node3D = buyers[0]
	for b: Node3D in buyers:
		if b.global_position.distance_to(global_position) \
				< perto.global_position.distance_to(global_position):
			perto = b
	var quem: String = perto.client_label() if perto.has_method("client_label") else ""
	var texto := "Entregue o carro na CASA marcada (placa verde), na cidade"
	if quem != "":
		texto = "Entregue na CASA marcada (placa verde) — %s" % quem
	if buyers.size() > 1:
		texto += "  ·  %d clientes esperando" % buyers.size()
	GameManager.set_objective(perto.global_position, texto)

func _on_part_broke(point_name: String) -> void:
	installed_parts.erase(point_name)
	installed_options.erase(point_name)
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

## Quanto o carro pode inclinar antes de contar como capotado (cosseno do
## angulo entre o teto e o ceu). 0.35 e ~70 graus: deitado de lado ja conta.
const UPRIGHT_LIMIT := 0.35
## Espera entre dois resgates, pra R segurado nao virar voo.
const RECOVER_COOLDOWN := 1.5

var _recover_wait := 0.0

## Desvira e reassenta o carro onde ele esta. Chamado pelo R.
##
## Existe porque ate agora NAO HAVIA COMO SE RECUPERAR de nada: capotou num
## buraco, bateu de lado num poste ou encravou entre duas construcoes, e a
## partida acabava ali — sem tecla, sem menu, sem nada. Num jogo cuja premissa e
## dirigir um calhambeque de gambiarra por uma pista esburacada, capotar nao e
## acidente raro, e o caminho normal.
##
## Mantem X e Z: reposicionar pra longe seria teleporte, e o preco de capotar
## deve ser perder tempo, nao perder o lugar.
func recover() -> void:
	if _recover_wait > 0.0:
		return
	_recover_wait = RECOVER_COOLDOWN
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 3.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0)
	# Sem excluir o proprio carro, o raio bate na barriga dele e devolve a
	# altura da lataria — a mesma armadilha que enterrou a rua inteira em
	# 2026-08-03.
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var ground_y: float = float(hit["position"].y) if hit.has("position") else global_position.y

	# So a direcao (guinada) sobrevive: inclinacao e rolagem sao justamente o
	# que se quer desfazer.
	var yaw := global_transform.basis.get_euler().y
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(
		global_position.x, ground_y + rig.wheel_radius + 0.35, global_position.z))
	# `set_deferred`: isto e chamado de dentro do passo de fisica, e mexer na
	# transformada de um RigidBody ali e erro no Godot.
	set_deferred("freeze", false)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = t
	_stress_all_parts(2.0)   # sacode as gambiarras: resgate nao sai de graca
	AudioManager.play_at("batida_media", global_position, -6.0, 0.8, 45.0)

## O teto ainda aponta pro ceu?
func is_upright() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) > UPRIGHT_LIMIT

func hit_pothole(force: float) -> void:
	apply_central_impulse(Vector3.UP * force * 0.35)
	_stress_all_parts(force)
	if audio:
		audio.pothole()

## Quanto a velocidade precisa CAIR num toque pra aquilo contar como batida.
## Abaixo disso e raspao (a barriga encostando no asfalto, a roda subindo a
## guia), e raspao nao arranca gambiarra.
const IMPACT_MIN := 1.2

func _on_body_entered(_body: Node) -> void:
	# O que arranca a gambiarra e a BATIDA, nao a velocidade.
	#
	# Antes isto usava `linear_velocity.length()`, ou seja o quanto o carro
	# estava andando — e `body_entered` dispara com QUALQUER contato, inclusive
	# o chao do mundo. Resultado medido: a 39 km/h a barriga encostou no
	# `Ground` e as QUATRO gambiarras se soltaram de uma vez, sem o jogador ter
	# batido em nada. Era o "as gambiarras descolam quando começo a dirigir".
	#
	# A conta certa e quanto a velocidade CAIU no toque: raspar dá ~0, bater
	# num poste dá o tranco inteiro.
	var impact: float = (_prev_velocity - linear_velocity).length()
	if audio:
		audio.impact(impact)
	if impact > IMPACT_MIN:
		_stress_all_parts(impact * 1.5)

func _stress_all_parts(force: float) -> void:
	for point_name in installed_parts.keys().duplicate():
		var part = installed_parts.get(point_name)
		if part and is_instance_valid(part):
			part.receive_stress(force)

## Velocidade no eixo do carro (positiva = pra frente).
func forward_speed() -> float:
	return linear_velocity.dot(-global_transform.basis.z)

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
	# R desvira/reassenta. Vale DIRIGINDO ou REBOCANDO: a carcaca puxada a pe
	# tambem capota (foi o que fez ela chegar de cabeca pra baixo na oficina em
	# 2 de 3 rodadas antes do `tow_grip`), e ali o jogador tambem nao tinha
	# saida. Borda de subida, como o E e o V — segurado, seria um resgate por
	# quadro.
	if driver or being_towed:
		var r_now := Input.is_key_pressed(KEY_R)
		if r_now and not _r_prev:
			recover()
		_r_prev = r_now
	else:
		_r_prev = false
	_recover_wait = maxf(_recover_wait - delta, 0.0)
	_apply_suspension_and_drive(delta)
	_update_visual(delta)
	if smoke_fx:
		smoke_fx.emitting = (attach_points.size() - installed_parts.size()) > 0

## Roda vira e gira junto com o que a fisica esta fazendo.
func _update_visual(delta: float) -> void:
	if rig == null:
		return
	rig.set_steer(_steer_angle)
	rig.roll(forward_speed() * delta)

## Multiplicador de uma peca: 1.0 com ela em ordem, `pior` com ela quebrada.
## E o que faz o diagnostico valer alguma coisa — carro com defeito ANDA
## diferente, em vez de so valer menos numa planilha.
func part_factor(key: String, pior: float) -> float:
	if not Economy.part_broken(parts, key):
		return 1.0
	return pior

func _apply_suspension_and_drive(delta: float) -> void:
	# Velocidade no COMECO do passo, antes do solver. E a referencia de
	# `_on_body_entered`, que roda depois da colisao ja resolvida. Fica aqui, e
	# nao no `_physics_process`, porque o banco de provas desliga o
	# `_physics_process` e chama esta funcao direto — se ficasse la, o teste
	# mediria uma coisa e o jogo faria outra.
	_prev_velocity = linear_velocity
	var traction: float = _current_traction()
	var speed: float = forward_speed()

	# Esterco util cai com a velocidade e a roda persegue a tecla em vez de
	# saltar pro angulo maximo num frame.
	var falloff: float = 1.0 - steer_speed_falloff * clampf(absf(speed) / 22.0, 0.0, 1.0)
	var target_steer: float = steer_input * max_steer_angle * falloff
	_steer_angle = lerpf(_steer_angle, target_steer, clampf(steer_response * delta, 0.0, 1.0))

	var grounded := 0
	for wheel in wheels:
		if not wheel.is_colliding():
			continue
		grounded += 1
		var contact: Vector3 = wheel.get_collision_point()
		var wheel_world: Vector3 = wheel.global_transform.origin
		var ray_dir: Vector3 = (wheel.to_global(wheel.target_position) - wheel_world).normalized()
		var distance: float = wheel_world.distance_to(contact)
		var compression: float = _rest_length - distance
		if compression < 0.0:
			continue
		# BATENTE. Sem esse teto, qualquer interpenetracao (cair de um salto,
		# subir no meio-fio, ser arrastado por cima de uma laje) vira uma
		# compressao enorme e a mola CATAPULTA o carro — o teste de loop viu a
		# carcaca sair voando a mais de 100 m/s e subir a 9m de altura. Na
		# realidade a suspensao bate no fim do curso e para de crescer.
		compression = minf(compression, rest_compression + suspension_travel * 0.5)
		var offset: Vector3 = contact - global_transform.origin
		var world_vel: Vector3 = linear_velocity + angular_velocity.cross(offset)
		# Tudo no eixo da suspensao (pra cima). O amortecedor tem que OPOR a
		# velocidade: subindo ele puxa, descendo ele empurra. Com o sinal
		# trocado — que era o caso — ele vira amortecedor NEGATIVO, bombeia
		# energia a cada quique e o carro se atira sozinho pro ar (medido:
		# a compressao ia de 0.04 pra 0.34 em 1s e as 4 rodas saiam do chao).
		var susp_up: Vector3 = -ray_dir
		var vel_up: float = world_vel.dot(susp_up)
		# Suspensao quebrada amortece menos: o carro fica pulando em vez de
		# assentar, e cada buraco sacode mais a gambiarra.
		var spring_force: float = compression * _spring_k \
			- vel_up * _spring_c * part_factor("suspensao", 0.45)
		# Mola so empurra, e no maximo algumas vezes o peso que ela sustenta:
		# o amortecedor sozinho tambem consegue estourar a forca num impacto
		# forte, e o batente acima nao limita ele.
		spring_force = clampf(spring_force, 0.0, _max_spring_force)
		apply_force(susp_up * spring_force, offset)

		var is_front: bool = wheel.name.begins_with("WheelF")
		var forward: Vector3 = -global_transform.basis.z
		var right: Vector3 = global_transform.basis.x
		if is_front:
			forward = forward.rotated(Vector3.UP, _steer_angle)
			right = right.rotated(Vector3.UP, _steer_angle)

		# Tracao traseira: forca so nas rodas de tras.
		if not is_front and not handbrake:
			var drive := 0.0
			if throttle_input > 0.0:
				drive = throttle_input * max_engine_force * part_factor("motor", 0.55)
			elif throttle_input < 0.0:
				# S e freio enquanto anda pra frente, re so depois de parar.
				drive = throttle_input * (brake_force * part_factor("freio", 0.40) \
					if speed > 0.5 else max_reverse_force * part_factor("motor", 0.55))
			apply_force(forward * drive * lerpf(0.45, 1.0, traction), offset)

		# Aderencia lateral com TETO: acima da carga da roda vezes o
		# coeficiente, a roda escorrega. E o que permite derrapar.
		var side_vel: float = world_vel.dot(right)
		# Pneu careca derrapa: o carro escapa nas curvas mesmo no seco.
		var grip_coef: float = lateral_grip * part_factor("pneus", 0.55)
		if being_towed:
			grip_coef = tow_grip
		elif handbrake:
			grip_coef = handbrake_grip
		var grip_limit: float = spring_force * grip_coef * traction
		var side_force: float = clampf(-side_vel * mass * 4.0, -grip_limit, grip_limit)
		apply_force(right * side_force, offset)

	# Carro parado tem que FICAR parado. Sem isso ele fica deslizando a ~26 cm/s
	# indefinidamente (o modelo de aderencia so resiste ao movimento LATERAL, e
	# nada segura o rolamento pra frente com o acelerador solto). Na oficina
	# isso faz o alvo da gambiarra fugir da mira enquanto o jogador aperta E.
	if grounded > 0 and is_zero_approx(throttle_input) and not handbrake and not being_towed:
		var creep := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		if creep.length() < 1.5:
			apply_central_force(-creep * mass * 4.0)

	# ATRITO ESTATICO: carro parado tem que FICAR parado. Sem isso sobrava uma
	# deriva de ~0.28 m/s pra sempre (o arrasto e proporcional a velocidade,
	# entao perto de zero ele nao segura nada) — o carro escorregava sozinho
	# pela oficina e o jogador mirava numa gambiarra que se mexia.
	if grounded > 0 and not being_towed and absf(throttle_input) < 0.01:
		var flat_vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		var v_flat: float = flat_vel.length()
		if v_flat > 0.001 and v_flat < 0.6:
			# Forca pra zerar a velocidade neste passo, limitada a 0.6g — o
			# mesmo teto que um pneu parado aguenta antes de deslizar.
			var stop_force: float = minf(mass * v_flat / maxf(delta, 0.0001),
				mass * 18.0 * 0.6)
			apply_central_force(-flat_vel.normalized() * stop_force)

	if grounded > 0:
		# Arrasto: define a velocidade final sem trava artificial.
		var vel := linear_velocity
		var flat := Vector3(vel.x, 0.0, vel.z)
		var v: float = flat.length()
		if v > 0.05:
			apply_central_force(-flat.normalized() * (air_drag * v * v + rolling_drag * v))
		# Carga aerodinamica leve: segura o carro no chao em velocidade.
		apply_central_force(Vector3.DOWN * absf(speed) * mass * 0.12)
