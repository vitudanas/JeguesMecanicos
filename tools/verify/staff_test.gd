extends Node
## O PATIO, o LOTE e a EQUIPE — as tres pecas que fazem o loop deixar de ser
## estritamente serial.
##
## Elas nao valem separadas, e por isso estao no mesmo teste: o lote da mais de
## uma carcaca pra escolher, o patio deixa mais de um carro esperando, e o
## mecanico e quem mexe neles enquanto o jogador esta na rua. Tirando qualquer
## uma, as outras duas viram numero na tela.
##
## Nada e conferido contra a propria tabela: o `Main.tscn` de verdade e
## carregado, os carros entram na laje pelo gatilho do jogo e o mecanico
## trabalha pelo `_physics_process` dele.
##
##   godot --headless --path . tools/verify/staff_test.tscn

const WorkshopScript := preload("res://scenes/world/Workshop.gd")

var problems: Array[String] = []
var main: Node
var workshop: Node

func check(ok: bool, label: String, detail := "") -> void:
	if ok:
		print("    ok: %s%s" % [label, "" if detail == "" else "  (%s)" % detail])
	else:
		print("    FALHOU: %s%s" % [label, "" if detail == "" else "  (%s)" % detail])
		problems.append(label)

func _ready() -> void:
	Dealership.reset()
	Staff.reset()
	GameManager.reset()
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	workshop = get_tree().get_first_node_in_group("workshop")
	if workshop == null:
		check(false, "achei a oficina na cena")
		_finish()
		return
	await _lote()
	await _patio()
	await _equipe()
	await _mecanico()
	await _recepcionista()
	_finish()

func _finish() -> void:
	print("")
	if problems.is_empty():
		print("=== RESULTADO ===")
		print("o lote se repoe, o patio limita e o funcionario trabalha")
		get_tree().quit(0)
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
		get_tree().quit(1)

# ---------------------------------------------------------------------- lote

func _lot() -> Node:
	return get_tree().get_first_node_in_group("junkyard")

func _lot_cars() -> Array[Node]:
	var out: Array[Node] = []
	var lot := _lot()
	if lot == null:
		return out
	for c in lot.get_children():
		if c.is_in_group("vehicle"):
			out.append(c)
	return out

func _lote() -> void:
	print("[1] o ferro-velho e um LOTE, e ele se repoe")
	var lot := _lot()
	if lot == null:
		check(false, "achei o ferro-velho na cena")
		return
	var carros := _lot_cars()
	check(carros.size() == lot.SPOTS.size(), "o lote nasce cheio",
		"%d carcacas" % carros.size())
	# O que faz o lote valer e ter DO QUE escolher: dois carros iguais em preco
	# e estado seriam a mesma carcaca duplicada.
	var precos: Array[int] = []
	for c in carros:
		precos.append(int(c.asking_price))
		print("    %-14s pedem R$ %3d  ·  %s" % [c.model_key, c.asking_price,
			c.condition_text()])
	precos.sort()
	check(precos.size() > 1 and precos[0] != precos[-1], "as ofertas sao diferentes",
		"de R$ %d a R$ %d" % [precos[0], precos[-1]])

	# Antes desta rodada havia UMA carcaca posta a mao na cena: rebocada, o
	# ferro-velho ficava vazio pra sempre e o jogo tinha um ciclo de garimpo so.
	var levada: Node3D = carros[0]
	var vaga: Vector3 = levada.global_position
	levada.global_position += Vector3(0.0, 0.0, 60.0)
	await get_tree().physics_frame
	lot.restock_now()
	await get_tree().physics_frame
	# Conta VAGA CHEIA, e nao filho do no: a carcaca rebocada continua sendo
	# filha do ferro-velho enquanto atravessa o mapa, entao contar filhos diria
	# que o lote esta cheio com as vagas vazias.
	check(_filled_spots() == lot.SPOTS.size(), "a vaga vazia foi reposta",
		"%d de %d vagas cheias" % [_filled_spots(), lot.SPOTS.size()])
	var ocupou := false
	for c in _lot_cars():
		if (c as Node3D).global_position.distance_to(vaga) < 2.0:
			ocupou = true
	check(ocupou, "a carcaca nova nasceu na vaga que vagou")
	# Nao empilha: com a vaga ainda ocupada, repor de novo nao cria carro.
	var antes := _lot_cars().size()
	lot.restock_now()
	await get_tree().physics_frame
	check(_lot_cars().size() == antes, "vaga ocupada nao ganha um segundo carro",
		"%d -> %d" % [antes, _lot_cars().size()])

## Quantas VAGAS do lote tem carcaca em cima.
func _filled_spots() -> int:
	var lot := _lot()
	if lot == null:
		return 0
	var n := 0
	for spot: Dictionary in lot.SPOTS:
		var local: Vector2 = spot["pos"]
		var center: Vector3 = (lot as Node3D).to_global(Vector3(local.x, 0.0, local.y))
		for c in _lot_cars():
			var p: Vector3 = (c as Node3D).global_position
			if Vector2(p.x - center.x, p.z - center.z).length() < 3.0:
				n += 1
				break
	return n

# ---------------------------------------------------------------------- patio

## Poe um carro sucateado na laje, pelo gatilho de verdade.
func _park(offset: Vector3) -> Node:
	var car: RigidBody3D = (load("res://scenes/vehicle/Vehicle.tscn") as PackedScene).instantiate()
	car.car_model = load("res://assets/quaternius/cars/car-a.glb")
	car.is_wrecked = true
	main.get_node("Town").add_child(car)
	car.global_position = workshop.get_drop_position() + offset
	car.owned = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	return car

func _patio() -> void:
	print("\n[2] o patio limita quantos carros cabem")
	Dealership.reset()
	# As vagas pintadas e o limite tem que contar a MESMA historia: pintar tres
	# faixas e aceitar quatro carros (ou o contrario) seria pior que nao pintar.
	for nivel in range(Dealership.YARD_SLOTS.size()):
		var pintadas: int = (WorkshopScript.BAY_LAYOUTS[nivel] as Array).size()
		check(pintadas == Dealership.YARD_SLOTS[nivel],
			"nivel %d: %d vagas pintadas = %d do Dealership" % [
				nivel + 1, pintadas, Dealership.YARD_SLOTS[nivel]])

	var a := await _park(Vector3.ZERO)
	check(a.at_workshop, "o primeiro carro e aceito na laje")
	var b := await _park(Vector3(6.0, 0.0, 0.0))
	check(workshop.parked_vehicles().size() == 2, "os dois estao na laje",
		"%d na laje" % workshop.parked_vehicles().size())
	check(not b.at_workshop, "com 1 vaga, o SEGUNDO carro e recusado")

	print("    comprando o patio nivel 2...")
	GameManager.money = 100000
	Dealership.buy("patio")
	await get_tree().physics_frame
	check(workshop.slots() == 2, "agora sao 2 vagas")
	check(b.at_workshop, "o carro que estava esperando foi aceito na hora")

	# Vaga livre e pra onde a bussola manda: chegar rebocando sem saber onde
	# encostar e o que o patio de varias vagas poderia estragar.
	var livre: Vector3 = workshop.get_drop_position()
	var longe_de_a: float = livre.distance_to((a as Node3D).global_position)
	var longe_de_b: float = livre.distance_to((b as Node3D).global_position)
	check(longe_de_a > 2.0 and longe_de_b > 2.0,
		"com o patio cheio de 2, a bussola nao manda em cima de um carro parado",
		"%.1f m e %.1f m dos carros" % [longe_de_a, longe_de_b])

	print("\n[3] a tranqueira do patio nao invade vaga nenhuma")
	var vagas: Rect2 = WorkshopScript.clear_rect()
	print("    anel livre (uniao de todos os niveis): x %.1f..%.1f  z %.1f..%.1f" % [
		vagas.position.x, vagas.end.x, vagas.position.y, vagas.end.y])
	var yard := workshop.get_node_or_null("Yard")
	var invasores: Array[String] = []
	if yard:
		for prop in yard.get_children():
			if not (prop is Node3D):
				continue
			var p: Vector3 = (prop as Node3D).position
			if vagas.has_point(Vector2(p.x, p.z)):
				invasores.append("%s em (%.1f, %.1f)" % [prop.name, p.x, p.z])
	check(invasores.is_empty(), "nenhum prop dentro das vagas",
		"invasores: %s" % ", ".join(invasores) if not invasores.is_empty() else "")

	(a as Node3D).queue_free()
	(b as Node3D).queue_free()
	await get_tree().physics_frame
	Dealership.reset()

# --------------------------------------------------------------------- equipe

func _equipe() -> void:
	print("\n[4] contratar so abre no ultimo nivel da area")
	Dealership.reset()
	Staff.reset()
	GameManager.money = 100000
	check(not Staff.can_hire("mecanico"), "oficina nv.1 nao oferece mecanico")
	check(Staff.hire("mecanico") != "", "e a contratacao e recusada de fato")
	Dealership.buy("oficina")
	check(not Staff.can_hire("mecanico"), "nv.2 ainda nao")
	Dealership.buy("oficina")
	check(Staff.can_hire("mecanico"), "no nv.3 a vaga abre")

	var antes: int = GameManager.money
	check(Staff.hire("mecanico") == "", "contratou")
	check(GameManager.money == antes - Staff.cost("mecanico"),
		"o salario saiu do bolso: R$ %d" % Staff.cost("mecanico"),
		"%d -> %d" % [antes, GameManager.money])
	check(Staff.hire("mecanico") != "", "nao da pra contratar duas vezes")

	# Sem dinheiro nao se contrata — mesma regra do upgrade.
	Dealership.buy("escritorio")
	Dealership.buy("escritorio")
	GameManager.money = 5
	check(Staff.hire("recepcionista") != "", "sem dinheiro, a vaga nao fecha")

	print("\n[5] a equipe sobrevive ao disco")
	GameManager.money = 100000
	Staff.hire("recepcionista")
	var esperado: Dictionary = Staff.to_dict().duplicate()
	SaveGame.save()
	Staff.reset()
	check(not Staff.has("mecanico"), "reset demitiu antes de reler")
	SaveGame._read()
	SaveGame.apply_to_game()
	check(Staff.to_dict() == esperado, "a equipe voltou do disco", str(Staff.to_dict()))
	SaveGame.clear()

# ------------------------------------------------------------------- mecanico

func _mecanico() -> void:
	print("\n[6] o mecanico conserta de verdade, e cobra por isso")
	Dealership.reset()
	Staff.reset()
	GameManager.money = 100000
	Dealership.buy("oficina")
	Dealership.buy("oficina")
	Staff.hire("mecanico")
	await get_tree().physics_frame

	var mech := get_tree().get_first_node_in_group("mecanico")
	if mech == null:
		check(false, "o mecanico existe no patio depois de contratado")
		return
	check(mech.visible, "ele aparece no patio so depois de contratado")

	var car := await _park(Vector3.ZERO)
	car.diagnosed = false
	for k: String in car.parts:
		car.parts[k] = 1.0
	car.parts["motor"] = 0.25
	check(car.at_workshop, "o carro esta na laje pra ele mexer")

	var carteira: int = GameManager.money
	var frames := int((Staff.SECONDS_TO_DIAGNOSE + Staff.SECONDS_PER_PART + 3.0) * 60.0)
	var diagnosticou_em := -1
	for i in range(frames):
		await get_tree().physics_frame
		if diagnosticou_em < 0 and car.diagnosed:
			diagnosticou_em = i
		if car.parts["motor"] >= 1.0:
			break
	check(diagnosticou_em >= 0, "ele diagnosticou o carro sozinho",
		"em %.1f s" % (float(diagnosticou_em) / 60.0))
	check(car.parts["motor"] >= 1.0, "e trocou o motor sozinho",
		"motor agora %.2f" % car.parts["motor"])
	var gasto: int = carteira - GameManager.money
	var na_mao: int = Economy.part_price("motor",
		Economy.repaired_value(car.model_key, car.condition))
	check(gasto > na_mao, "cobrou a mao de obra por cima da peca",
		"R$ %d contra R$ %d na mao" % [gasto, na_mao])

	# Sem dinheiro ele PARA, em vez de trabalhar fiado — e o prompt diz o motivo.
	car.parts["freio"] = 0.2
	GameManager.money = 0
	for i in range(120):
		await get_tree().physics_frame
	check(car.parts["freio"] < 1.0, "sem dinheiro ele nao troca a peca")
	var prompt: String = mech.get_interact_prompt()
	check(prompt.contains("faltam"), "e o prompt explica por que ele parou", prompt)

	GameManager.money = 100000
	(car as Node3D).queue_free()
	await get_tree().physics_frame

# --------------------------------------------------------------- recepcionista

func _recepcionista() -> void:
	print("\n[7] a recepcionista poe DOIS clientes na rua")
	check(DeliveryManager.wanted_buyers() == 1, "sem ela, um cliente por vez")
	var antes: int = get_tree().get_nodes_in_group("buyer").size()
	GameManager.money = 100000
	Dealership.buy("escritorio")
	Dealership.buy("escritorio")
	check(Staff.hire("recepcionista") == "", "contratou a recepcionista")
	await get_tree().process_frame
	await get_tree().physics_frame
	var buyers := get_tree().get_nodes_in_group("buyer")
	check(DeliveryManager.wanted_buyers() == 2, "agora sao dois clientes")
	check(buyers.size() == 2, "e os dois estao na rua de verdade",
		"%d -> %d" % [antes, buyers.size()])
	if buyers.size() == 2:
		var d: float = (buyers[0] as Node3D).global_position.distance_to(
			(buyers[1] as Node3D).global_position)
		# Dois clientes na mesma calcada nao dariam escolha nenhuma.
		check(d > 10.0, "eles estao em casas diferentes", "%.0f m de distancia" % d)
		var nomes: Array[String] = []
		for b in buyers:
			nomes.append(b.client_label() if b.has_method("client_label") else "?")
		print("    esperando: %s" % ", ".join(nomes))
