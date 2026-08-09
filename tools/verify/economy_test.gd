extends Node
## Os tipos de cliente valem alguma coisa — e nenhum deles e impossivel.
##
## Duas perguntas diferentes, e as duas importam:
##
##   [1] O sorteio muda mesmo o jogo? Cinco rotulos que pagam igual e enchem a
##       barra igual sao enfeite, nao mecanica.
##   [2] Da pra perder por azar? Atravessar a cidade inteira e a entrega nao
##       fechar porque o sorteio deu um cliente impossivel seria punicao sem
##       aviso. A INVARIANTE do projeto e: segurando E sem soltar, toda venda
##       fecha; a dificuldade vem de titubear e da avaria.
##
##   godot --headless --path . tools/verify/economy_test.tscn

var problems: Array[String] = []

func check(ok: bool, label: String, detail := "") -> void:
	if ok:
		print("    ok: %s%s" % [label, "" if detail == "" else "  (%s)" % detail])
	else:
		print("    FALHOU: %s%s" % [label, "" if detail == "" else "  (%s)" % detail])
		problems.append(label)

func _ready() -> void:
	await get_tree().process_frame

	print("[1] cada cliente paga diferente pelo MESMO carro (4/4 gambiarras)")
	var carro := {"km": 120.0, "lataria": 0.3, "pintura": 0.3}
	var mercado := Economy.market_value("car-a", carro, 4, 4)
	print("    carro de referencia: car-a, %d mil km, vale R$ %d" % [carro["km"], mercado])
	var precos: Dictionary = {}
	for c in Economy.CLIENTS:
		var v := Economy.offer(c, mercado)
		precos[c["nome"]] = v
		print("    %-14s R$ %3d   enche %.2f/s, paciencia %.1fs, implica x%.1f"
			% [c["nome"], v, c["enche"], c["paciencia"], c["implica"]])
	var valores: Array = precos.values()
	valores.sort()
	check(valores[0] != valores[-1], "o preco varia com o cliente",
		"de R$ %d a R$ %d" % [valores[0], valores[-1]])
	check(float(valores[-1]) / maxf(float(valores[0]), 1.0) >= 1.5,
		"a diferenca compensa escolher", "%.1fx" % (float(valores[-1]) / float(valores[0])))

	print("\n[2] avaria pesa mais em quem implica mais")
	var colecionador := _by_name("Colecionador")
	var apressado := _by_name("Apressado")
	var meio := Economy.market_value("car-a", carro, 2, 4)
	var perda_col := Economy.offer(colecionador, mercado) - Economy.offer(colecionador, meio)
	var perda_apr := Economy.offer(apressado, mercado) - Economy.offer(apressado, meio)
	print("    perder 2 gambiarras custa R$ %d com o Colecionador e R$ %d com o Apressado"
		% [perda_col, perda_apr])
	check(perda_col > perda_apr, "quem paga mais perde mais com carro quebrado")

	print("\n[3] NENHUM cliente e impossivel (segurando E sem soltar)")
	for c in Economy.CLIENTS:
		# Simula o minigame de verdade, com o mesmo objeto que o jogo usa.
		var mini := PersuasionMinigame.new()
		mini.fill_rate = c["enche"]
		mini.drain_rate = c["esvazia"]
		mini.start(c["paciencia"])
		var venceu := [false]
		mini.succeeded.connect(func() -> void: venceu[0] = true)
		var passo := 1.0 / 60.0
		# Carro DETONADO (0 de 4 inteiras) e a penalidade cheia deste cliente:
		# se fecha nessa condicao, fecha em qualquer uma.
		var penalidade: float = Economy.damage_penalty(0, 4) * float(c["implica"])
		var t := 0.0
		while mini.is_active and t < c["paciencia"] + 1.0:
			mini.update(passo, true, penalidade)
			t += passo
		check(venceu[0], "%s fecha segurando E" % c["nome"],
			"em %.1fs de %.1fs" % [t, c["paciencia"]])

	print("\n[4] soltar o botao FAZ diferenca (senao o minigame nao e minigame)")
	for c in Economy.CLIENTS:
		var mini := PersuasionMinigame.new()
		mini.fill_rate = c["enche"]
		mini.drain_rate = c["esvazia"]
		mini.start(c["paciencia"])
		var passo := 1.0 / 60.0
		var penalidade: float = Economy.damage_penalty(0, 4) * float(c["implica"])
		var t := 0.0
		# Segura metade do tempo e solta a outra metade, alternando.
		while mini.is_active and t < c["paciencia"]:
			mini.update(passo, fmod(t, 1.0) < 0.5, penalidade)
			t += passo
		print("    %-14s titubeando chega a %.0f%%" % [c["nome"], mini.progress * 100.0])

	print("\n[5] carros diferentes valem coisas diferentes")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260809
	var novo := {"km": 60.0, "lataria": 0.05, "pintura": 0.05}
	var velho := {"km": 340.0, "lataria": 0.95, "pintura": 0.95}
	var esporte_novo := Economy.repaired_value("sports-car-a", novo)
	var taxi_velho := Economy.repaired_value("taxi", velho)
	print("    sports-car-a impecavel: R$ %d   |   taxi detonado: R$ %d"
		% [esporte_novo, taxi_velho])
	check(esporte_novo > taxi_velho * 2, "o modelo e o estado mudam MUITO o valor",
		"%.1fx" % (float(esporte_novo) / maxf(float(taxi_velho), 1.0)))

	print("\n[6] o negocio da carcaca (comprar barato e o outro lado do lucro)")
	var achou_barganha := false
	var achou_abacaxi := false
	for i in range(200):
		var cond := Economy.roll_condition(rng)
		var chave: String = Economy.MODEL_VALUES.keys()[rng.randi() % Economy.MODEL_VALUES.size()]
		var pede := Economy.wreck_asking_price(chave, cond, rng)
		var vale := Economy.repaired_value(chave, cond)
		var margem := float(vale - pede) / maxf(float(vale), 1.0)
		if margem > 0.6:
			achou_barganha = true
		if margem < 0.35:
			achou_abacaxi = true
	check(achou_barganha and achou_abacaxi,
		"o lote tem barganha E abacaxi (senao nao ha o que garimpar)")

	# Pechinchar tem que COMPENSAR e ter LIMITE: sem desconto ninguem pechincha,
	# e sem piso da pra zerar o preco insistindo.
	var pedido := 300
	var piso := Economy.haggle_floor(pedido)
	var depois := pedido
	for i in range(Economy.HAGGLE_TRIES):
		depois = maxi(piso, int(round(float(depois) * (1.0 - Economy.HAGGLE_STEP))))
	print("    pedido R$ %d -> R$ %d com %d pechinchas (piso R$ %d, risco %.0f%%)"
		% [pedido, depois, Economy.HAGGLE_TRIES, piso, Economy.HAGGLE_RISK * 100.0])
	check(depois < pedido, "pechinchar desconta de verdade")
	check(depois >= piso, "a pechincha respeita o piso do dono")
	check(Economy.HAGGLE_RISK > 0.0, "pechinchar tem risco (senao e so burocracia)")

	print("\n[7] da pra comecar o jogo? (o capital inicial compra alguma carcaca)")
	# Le do GameManager, nao um numero escrito aqui: foi exatamente assim que o
	# save_test reprovou sozinho quando o capital inicial mudou.
	var inicial := GameManager.STARTING_MONEY
	var caras := 0
	var total_sorteios := 300
	for i in range(total_sorteios):
		var cond2 := Economy.roll_condition(rng)
		var chave2: String = Economy.MODEL_VALUES.keys()[rng.randi() % Economy.MODEL_VALUES.size()]
		if Economy.wreck_asking_price(chave2, cond2, rng) > inicial:
			caras += 1
	var pct := 100.0 * float(caras) / float(total_sorteios)
	print("    %.0f%% das carcacas custam mais que os R$ %d iniciais" % [pct, inicial])
	check(pct < 15.0, "o capital inicial banca a maioria das carcacas",
		"%.0f%% fora do alcance" % pct)

	print("\n[8] pecas mecanicas: peso no valor e custo do conserto")
	var sadio: Dictionary = {}
	for k: String in Economy.PARTS:
		sadio[k] = 1.0
	var detonado: Dictionary = {}
	for k: String in Economy.PARTS:
		detonado[k] = 0.0
	var cheio := Economy.repaired_value("car-a", carro)
	var val_sadio := Economy.market_value("car-a", carro, 4, 4, sadio)
	var val_detonado := Economy.market_value("car-a", carro, 4, 4, detonado)
	print("    mesmo carro: mecanica em ordem R$ %d  |  tudo quebrado R$ %d"
		% [val_sadio, val_detonado])
	check(val_detonado < val_sadio, "peca quebrada derruba o valor")
	check(Economy.repair_cost(sadio, cheio) == 0, "carro sadio nao cobra conserto")
	check(Economy.repair_cost(detonado, cheio) > 0, "carro detonado cobra conserto")

	# A DECISAO: cada peca tem que se pagar ou nao, INDIVIDUALMENTE. Se todo
	# conserto fosse lucro nao haveria escolha; se nenhum fosse, o diagnostico
	# seria enfeite (foi o que aconteceu com preco fixo: consertar tudo custava
	# R$ 400 e devolvia R$ 148).
	var vale_a_pena: Array[String] = []
	var prejuizo: Array[String] = []
	for key: String in Economy.PARTS:
		var so_esta: Dictionary = sadio.duplicate()
		so_esta[key] = 0.0
		var perda := val_sadio - Economy.market_value("car-a", carro, 4, 4, so_esta)
		var preco := Economy.part_price(key, cheio)
		var nome: String = Economy.PARTS[key]["nome"]
		print("    %-12s custa R$ %3d e devolve R$ %3d  ->  %s"
			% [nome, preco, perda, "compensa" if preco < perda else "prejuizo"])
		if preco < perda:
			vale_a_pena.append(nome)
		else:
			prejuizo.append(nome)
	check(not vale_a_pena.is_empty(), "existe conserto que compensa",
		", ".join(vale_a_pena))
	check(not prejuizo.is_empty(), "existe conserto que NAO compensa (a decisao)",
		", ".join(prejuizo))

	print("\n[9] o defeito SE FAZ SENTIR dirigindo (senao e so planilha)")
	var carro_teste := (load("res://scenes/vehicle/Vehicle.tscn") as PackedScene).instantiate()
	add_child(carro_teste)
	await get_tree().physics_frame
	for k: String in Economy.PARTS:
		carro_teste.parts[k] = 1.0
	var motor_bom: float = carro_teste.part_factor("motor", 0.55)
	var freio_bom: float = carro_teste.part_factor("freio", 0.40)
	for k: String in Economy.PARTS:
		carro_teste.parts[k] = 0.0
	var motor_ruim: float = carro_teste.part_factor("motor", 0.55)
	var freio_ruim: float = carro_teste.part_factor("freio", 0.40)
	print("    motor: %.2f -> %.2f   |   freio: %.2f -> %.2f"
		% [motor_bom, motor_ruim, freio_bom, freio_ruim])
	check(motor_ruim < motor_bom, "motor quebrado tira forca")
	check(freio_ruim < freio_bom, "freio quebrado piora a frenagem")
	carro_teste.queue_free()

	print("\n[10] preco pedido: pedir caro rende mais e custa labia")
	var npc := (load("res://scenes/npc/BuyerNPC.tscn") as PackedScene).instantiate()
	add_child(npc)
	await get_tree().process_frame
	var falso := (load("res://scenes/vehicle/Vehicle.tscn") as PackedScene).instantiate()
	falso.is_wrecked = false
	add_child(falso)
	await get_tree().physics_frame
	for k: String in Economy.PARTS:
		falso.parts[k] = 1.0
	npc.nearby_vehicle = falso
	# Com um cliente GENEROSO, pedir mais caro tem que render mais.
	npc.client = _by_name("Colecionador")
	var linhas: Array = []
	for passo in range(npc.ASK_STEPS.size()):
		npc.ask_step = passo
		linhas.append([npc.ASK_LABELS[passo], npc.asking(), npc._ceiling(), npc._difficulty()])
		print("    Colecionador  %-12s pede R$ %4d  ->  fecha por R$ %4d  (labia x%.2f)"
			% [linhas[-1][0], linhas[-1][1], linhas[-1][2], linhas[-1][3]])
	check(linhas[0][2] < linhas[-1][2], "com cliente bom, pedir mais caro rende mais",
		"R$ %d -> R$ %d" % [linhas[0][2], linhas[-1][2]])
	check(linhas[-1][3] <= linhas[0][3], "pedir caro deixa a labia mais dificil",
		"x%.2f -> x%.2f" % [linhas[0][3], linhas[-1][3]])
	npc.ask_step = 0
	check(npc._ceiling() <= npc.asking(), "o cliente nunca paga acima do pedido")

	# E com um PAO-DURO, pedir caro nao rende nada e so custa labia: e a outra
	# metade da decisao — com quem paga pouco, o certo e pedir pouco e fechar
	# rapido.
	npc.client = _by_name("Abutre")
	npc.ask_step = 0
	var abutre_barato: int = npc._ceiling()
	var abutre_facil: float = npc._difficulty()
	npc.ask_step = npc.ASK_STEPS.size() - 1
	var abutre_caro: int = npc._ceiling()
	var abutre_dificil: float = npc._difficulty()
	print("    Abutre        pedindo barato R$ %d (labia x%.2f)  |  caro R$ %d (labia x%.2f)"
		% [abutre_barato, abutre_facil, abutre_caro, abutre_dificil])
	check(abutre_barato < abutre_caro or abutre_dificil < abutre_facil,
		"com o Abutre a escolha de preco tambem pesa")

	print("\n[11] reputacao: esconder defeito cobra o preco depois")
	GameManager.reset()
	var limpo: Dictionary = {}
	for k: String in Economy.PARTS:
		limpo[k] = 1.0
	var podre: Dictionary = {}
	for k: String in Economy.PARTS:
		podre[k] = 0.0
	print("    carro em ordem: %d de reputacao   |   carro escondendo defeito: -%d"
		% [3, Economy.reputation_hit(podre)])
	check(Economy.reputation_hit(limpo) == 0, "carro em ordem nao derruba reputacao")
	check(Economy.reputation_hit(podre) > 0, "carro podre derruba reputacao")

	var alta := 0
	var baixa := 0
	GameManager.reputation = 100
	alta = int(round(Economy.offer(_by_name("Pão-duro"), 300) * Economy.reputation_bonus()))
	GameManager.reputation = 0
	baixa = int(round(Economy.offer(_by_name("Pão-duro"), 300) * Economy.reputation_bonus()))
	print("    mesmo carro e cliente: reputacao 100 paga R$ %d, reputacao 0 paga R$ %d"
		% [alta, baixa])
	check(alta > baixa, "reputacao alta faz o cliente pagar mais")
	GameManager.reset()
	npc.queue_free()
	falso.queue_free()

	print("")
	if problems.is_empty():
		print("=== RESULTADO ===")
		print("os tipos de cliente mudam o jogo e nenhum deles e impossivel")
		get_tree().quit(0)
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
		get_tree().quit(1)

func _by_name(nome: String) -> Dictionary:
	for c in Economy.CLIENTS:
		if c["nome"] == nome:
			return c
	return {}
