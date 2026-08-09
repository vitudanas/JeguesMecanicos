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
	var inicial := 450
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
