extends Node3D
## O PÁTIO da oficina: quantos carros cabem, onde eles ficam e quando o
## reboque solta.
##
## Ate agora era UMA vaga. O `Dealership` ja vendia "2 carros por vez" e "4
## carros por vez" desde 2026-08-09, mas o mundo tinha um ponto de largada so e
## nada no jogo lia `yard_slots()`: o nivel do patio era um numero que nao fazia
## nada. Aqui ele passa a valer — o patio conta os carros na laje e RECUSA
## soltar o reboque quando lota.
##
## O GATILHO E A LAJE INTEIRA, e nao uma Area3D por vaga. Vaga com trigger
## proprio foi considerada e descartada por medicao: o barracao avanca ate
## z = -5.44, o tanque toma x < -9.3 e a sucata toma x > 7.8, entao as quatro
## vagas nao cabem sem esbarrar em alguma coisa; e carro parado meio torto
## deixaria de contar, o que e pior que contar demais. Contando pela laje o
## jogador estaciona onde quiser e a regra continua sendo "quantos carros
## cabem ao mesmo tempo".
##
## As faixas pintadas no chao sao ORIENTACAO, nao regra: dizem quantas vagas o
## nivel atual da e onde os carros cabem sem se atrapalhar. Elas nao tem
## colisao — prop ou carro por cima nao quebra nada, so fica feio.

## Onde ficam as vagas em cada nivel do patio, em coordenadas locais (x, z).
##
## O layout MUDA de nivel pra nivel em vez de so acender vagas novas: com uma
## vaga so, ela fica no meio da laje (que e onde o reboque chega naturalmente);
## com duas, elas se abrem pros lados; com quatro, viram uma fileira. Assim
## comprar o upgrade REPINTA o patio, que e o unico jeito de a melhoria
## aparecer na tela.
##
## O espacamento sai da medida do carro (4.22 m x 1.81 m): 4.8 m entre centros
## deixa ~2.9 m de corredor entre dois carros parados, que e o que o jogador
## precisa pra andar em volta e mirar nos marcadores das laterais.
const BAY_LAYOUTS: Array = [
	[Vector2(0.0, 2.2)],
	[Vector2(-3.6, 2.2), Vector2(3.6, 2.2)],
	[Vector2(-7.2, 2.2), Vector2(-2.4, 2.2), Vector2(2.4, 2.2), Vector2(7.2, 2.2)],
]
## Tamanho da faixa pintada (largura, profundidade).
const BAY_PAINT := Vector2(3.2, 5.4)
## Meia-extensao que precisa ficar LIVRE de tranqueira em volta de cada vaga:
## o carro mais um passo de gente de cada lado.
const BAY_CLEARANCE := Vector2(1.9, 3.1)
## Altura da pintura. O topo da laje fica em y = 0.02 (medido), entao isto
## encosta nela sem afundar (z-fighting) nem boiar.
const PAINT_Y := 0.05
const PAINT_WIDTH := 0.14

signal yard_changed

@onready var drop_zone: Area3D = $DropZone

## Todo veiculo que esta com o corpo dentro da laje, aceito ou nao.
var _inside: Array[Node] = []
var _paint_root: Node3D = null

func _ready() -> void:
	add_to_group("workshop")
	drop_zone.body_entered.connect(_on_body_entered)
	drop_zone.body_exited.connect(_on_body_exited)
	Dealership.changed.connect(_on_dealership_changed)
	_repaint()
	_spawn_mechanic()

func _on_dealership_changed() -> void:
	_repaint()
	# Comprar a vaga tem que valer AGORA: o carro que estava recusado por
	# lotacao passa a contar sem o jogador ter que reboca-lo pra fora e pra
	# dentro de novo.
	_absorb_waiting()

## O mecanico contratado vive no patio (ele so aparece depois de contratado —
## ver Mechanic._refresh). Fica aqui e nao no `WorkshopYard` porque quem sabe
## que carros estao na laje e este no.
func _spawn_mechanic() -> void:
	var mech := StaticBody3D.new()
	mech.name = "Mecanico"
	mech.set_script(load("res://scripts/Mechanic.gd"))
	add_child(mech)
	mech.setup(self)

# ------------------------------------------------------------------- as vagas

## As vagas do nivel atual.
func bays() -> Array:
	return BAY_LAYOUTS[clampi(Dealership.level("patio"), 0, BAY_LAYOUTS.size() - 1)]

func slots() -> int:
	return bays().size()

## Retangulo (local, no plano XZ) que precisa ficar livre de tranqueira. E a
## UNIAO das vagas de TODOS os niveis, e nao so as do nivel atual: prop plantado
## hoje no lugar de uma vaga futura viraria obstaculo quando o patio subisse, e
## o `WorkshopYard` monta o cenario uma vez so, no inicio da partida.
##
## `static` porque quem precisa disto e o `WorkshopYard`, que roda o proprio
## _ready() ANTES do pai (filhos primeiro) e portanto nao pode contar com este
## no ja estar pronto.
static func clear_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for layout: Array in BAY_LAYOUTS:
		for bay: Vector2 in layout:
			var b := Rect2(bay - BAY_CLEARANCE, BAY_CLEARANCE * 2.0)
			r = b if first else r.merge(b)
			first = false
	return r

## Para onde a bussola aponta: a primeira vaga LIVRE, pra o jogador chegar
## rebocando ja sabendo onde encostar. Sem vaga livre, o centro da laje.
##
## O y (1.2 acima do piso) e o mesmo de sempre: os verificadores tratam este
## ponto como "um metro acima do chao da vaga".
func get_drop_position() -> Vector3:
	var here: Array = bays()
	for bay: Vector2 in here:
		if _bay_free(bay):
			return to_global(Vector3(bay.x, 1.2, bay.y))
	# Nenhuma livre: aponta pro meio da fileira, que e onde o portao da.
	var mid := Vector2.ZERO
	for bay: Vector2 in here:
		mid += bay
	mid /= float(here.size())
	return to_global(Vector3(mid.x, 1.2, mid.y))

func _bay_free(bay: Vector2) -> bool:
	var center := to_global(Vector3(bay.x, 0.0, bay.y))
	for v in parked_vehicles():
		var p: Vector3 = (v as Node3D).global_position
		if Vector2(p.x - center.x, p.z - center.z).length() < 2.4:
			return false
	return true

# --------------------------------------------------------------- os carros la

## Os carros que estao na laje agora (descartando os que ja foram vendidos).
func parked_vehicles() -> Array[Node]:
	var vivos: Array[Node] = []
	for v in _inside:
		if is_instance_valid(v):
			vivos.append(v)
	_inside = vivos
	return _inside

func is_full() -> bool:
	return parked_vehicles().size() >= slots()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("vehicle"):
		return
	if body in _inside:
		return
	_inside.append(body)
	if parked_vehicles().size() > slots():
		# Patio cheio: o reboque NAO solta. Sem isso o quinto carro entraria
		# igual ao primeiro e o nivel do patio nao significaria nada.
		GameManager.set_objective(global_position,
			"Pátio cheio (%d/%d) — venda um carro ou melhore o pátio" % [slots(), slots()])
		AudioManager.play_ui("erro", -6.0)
		yard_changed.emit()
		return
	_accept(body)
	yard_changed.emit()

func _accept(body: Node) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("stop_towing"):
		player.stop_towing()
	body.at_workshop = true
	GameManager.set_objective(body.global_position,
		"Monte as 4 gambiarras no carro (capo, radiador, retrovisor, parachoque)")

func _on_body_exited(body: Node) -> void:
	# Saiu do patio (empurrado, ou ja consertado e saindo dirigindo): volta a
	# poder ser rebocado, senao um carro que escapou ficaria preso pra sempre.
	if not body.is_in_group("vehicle"):
		return
	_inside.erase(body)
	body.at_workshop = false
	_absorb_waiting()
	yard_changed.emit()

## Aceita os carros que estao na laje mas foram recusados por lotacao, ate
## acabar a vaga. Chamado quando um carro sai e quando o patio sobe de nivel.
func _absorb_waiting() -> void:
	var aceitos := 0
	for v in parked_vehicles():
		if v.at_workshop:
			aceitos += 1
	for v in parked_vehicles():
		if aceitos >= slots():
			return
		if not v.at_workshop:
			_accept(v)
			aceitos += 1

# ------------------------------------------------------------------- pintura

func _repaint() -> void:
	if _paint_root and is_instance_valid(_paint_root):
		_paint_root.queue_free()
	_paint_root = Node3D.new()
	_paint_root.name = "BayPaint"
	add_child(_paint_root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.78, 0.32)
	mat.roughness = 0.9
	for bay: Vector2 in bays():
		_paint_bay(bay, mat)

## Faixa em U (dois lados e o fundo), como vaga de estacionamento de verdade —
## a boca fica aberta pro carro entrar.
func _paint_bay(bay: Vector2, mat: Material) -> void:
	var hw: float = BAY_PAINT.x * 0.5
	var hd: float = BAY_PAINT.y * 0.5
	var stripes := [
		[Vector3(bay.x - hw, PAINT_Y, bay.y), Vector3(PAINT_WIDTH, 0.02, BAY_PAINT.y)],
		[Vector3(bay.x + hw, PAINT_Y, bay.y), Vector3(PAINT_WIDTH, 0.02, BAY_PAINT.y)],
		[Vector3(bay.x, PAINT_Y, bay.y - hd), Vector3(BAY_PAINT.x, 0.02, PAINT_WIDTH)],
	]
	for s: Array in stripes:
		var mesh := BoxMesh.new()
		mesh.size = s[1]
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = s[0]
		_paint_root.add_child(mi)
