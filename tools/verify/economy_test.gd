extends Node
## Os tipos de cliente valem alguma coisa — e nenhum deles e impossivel.
##
## Duas perguntas diferentes, e as duas importam:
##
##   [1] O sorteio muda mesmo o jogo? Rotulos que pagam e negociam igual sao
##       enfeite, nao mecanica.
##   [2] Da pra perder por azar? Atravessar a cidade inteira e nao ter nenhuma
##       oferta seria punicao sem aviso. A INVARIANTE agora e: todo cliente abre
##       com dinheiro garantido; contraproposta e blefe so arriscam esse valor
##       quando o jogador escolhe faze-los, com a chance visivel no prompt.
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
		print("    %-14s R$ %3d   abre %.0f%%, cede %.0f%%, blefe %.0f%%, %d rodadas"
			% [c["nome"], v, float(c["abre"]) * 100.0, float(c["cede"]) * 100.0,
				float(c["blefe"]) * 100.0, c["rodadas"]])
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

	print("\n[3] NENHUM cliente e impossivel (todos abrem com oferta aceitavel)")
	for c in Economy.CLIENTS:
		var teto := Economy.offer(c, mercado)
		var abertura := int(round(float(teto) * float(c["abre"])))
		var mini := PersuasionMinigame.new()
		mini.start(abertura, teto, int(c["rodadas"]))
		check(mini.current_offer > 0 and mini.current_offer <= mini.ceiling,
			"%s abre com dinheiro garantido" % c["nome"],
			"R$ %d de um teto R$ %d" % [mini.current_offer, mini.ceiling])
		check(float(c["cede"]) > float(c["blefe"]),
			"%s: contraproposta e mais segura que blefe" % c["nome"])

	print("\n[4] negociacao em rodadas: aceitar, contrapropor ou blefar")
	var mini := PersuasionMinigame.new()
	mini.start(70, 100, 3)
	var oferta_inicial := mini.current_offer
	mini.counter(true)
	var depois_counter := mini.current_offer
	check(depois_counter > oferta_inicial and depois_counter < mini.ceiling,
		"contraproposta sobe a oferta sem entregar o teto",
		"R$ %d -> R$ %d" % [oferta_inicial, depois_counter])
	check(mini.rounds_left == 2, "contraproposta gasta uma rodada")
	mini.bluff(true)
	check(mini.current_offer > depois_counter,
		"blefe bem-sucedido da um salto maior", "R$ %d" % mini.current_offer)
	check(mini.bluff_used and not mini.can_bluff(), "blefe so pode ser tentado uma vez")

	var falha := PersuasionMinigame.new()
	falha.start(70, 100, 3)
	falha.bluff(false)
	check(falha.current_offer < 70, "blefe descoberto reduz a oferta",
		"R$ 70 -> R$ %d" % falha.current_offer)
	check(falha.rounds_left == 1, "blefe descoberto custa duas rodadas")

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

	print("\n[10] preco pedido: pedir caro rende mais e reduz a chance")
	var npc := (load("res://scenes/npc/BuyerNPC.tscn") as PackedScene).instantiate()
	add_child(npc)
	await get_tree().process_frame
	var falso := (load("res://scenes/vehicle/Vehicle.tscn") as PackedScene).instantiate()
	falso.is_wrecked = false
	add_child(falso)
	await get_tree().physics_frame
	for k: String in Economy.PARTS:
		falso.parts[k] = 1.0
	# O valor de referencia precisa ser de carro COMPLETO. Sem isso o teste
	# cai no piso de 40% por ter 0/4 gambiarras e todas as chances saturam no
	# minimo — parece cobrir dificuldade, mas compara dois clamps iguais.
	for point: String in Economy.GAMBIARRAS:
		falso.installed_parts[point] = null
		falso.installed_options[point] = Economy.gambiarra_option(point, 1)
	npc.nearby_vehicle = falso
	# Com um cliente GENEROSO, pedir mais caro tem que render mais.
	npc.client = _by_name("Colecionador")
	var linhas: Array = []
	for passo in range(npc.ASK_STEPS.size()):
		npc.ask_step = passo
		# Inicia so o estado puro para a chance levar em conta quantas rodadas ja
		# foram usadas, sem apertar E e vender o veiculo de teste.
		npc.negotiation.start(npc._opening_offer(), npc._ceiling(), int(npc.client["rodadas"]))
		linhas.append([npc.ASK_LABELS[passo], npc.asking(), npc._ceiling(),
			npc._opening_offer(), npc._counter_chance(), npc._bluff_chance()])
		print("    Colecionador  %-12s pede R$ %4d  -> abre R$ %4d / teto R$ %4d  (Q %2d%%, F %2d%%)"
			% [linhas[-1][0], linhas[-1][1], linhas[-1][3], linhas[-1][2],
				int(round(float(linhas[-1][4]) * 100.0)),
				int(round(float(linhas[-1][5]) * 100.0))])
	check(linhas[0][2] < linhas[-1][2], "com cliente bom, pedir mais caro rende mais",
		"R$ %d -> R$ %d" % [linhas[0][2], linhas[-1][2]])
	check(float(linhas[-1][5]) < float(linhas[-1][4]),
		"blefe e mais arriscado que contraproposta")
	npc.ask_step = 0
	check(npc._ceiling() <= npc.asking(), "o cliente nunca paga acima do pedido")

	# E com um PAO-DURO, pedir caro nao rende nada e so custa labia: e a outra
	# metade da decisao — com quem paga pouco, o certo e pedir pouco e fechar
	# rapido.
	npc.client = _by_name("Abutre")
	npc.ask_step = 0
	var abutre_barato: int = npc._ceiling()
	npc.negotiation.start(npc._opening_offer(), npc._ceiling(), int(npc.client["rodadas"]))
	var abutre_facil: float = npc._counter_chance()
	npc.ask_step = npc.ASK_STEPS.size() - 1
	var abutre_caro: int = npc._ceiling()
	npc.negotiation.start(npc._opening_offer(), npc._ceiling(), int(npc.client["rodadas"]))
	var abutre_dificil: float = npc._counter_chance()
	print("    Abutre        pedindo barato R$ %d (Q %.0f%%)  |  caro R$ %d (Q %.0f%%)"
		% [abutre_barato, abutre_facil * 100.0, abutre_caro, abutre_dificil * 100.0])
	check(abutre_dificil < abutre_facil,
		"pedir acima do teto reduz a chance de contraproposta",
		"%.0f%% -> %.0f%%" % [abutre_facil * 100.0, abutre_dificil * 100.0])

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

	print("\n[8] a gambiarra virou ESCOLHA (nenhuma opcao domina)")
	_gambiarras()
	# Erro de script no meio da secao aborta a funcao e o teste terminaria
	# "sem problemas" com metade das perguntas nao feitas — ja aconteceu aqui.
	check(_gambiarras_completou, "a secao da gambiarra rodou ate o fim")

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

## O catalogo de gambiarra so vale se as tres opcoes forem decisoes de verdade.
##
## Duas perguntas, e a segunda e a que importa:
##   [a] os degraus diferem mesmo em preco, resistencia e desconto?
##   [b] existe caso em que a BARATA e a jogada certa? Se a cara ganhasse
##       sempre, nao haveria escolha — so um imposto pra quem tem dinheiro.
var _gambiarras_completou := false

func _gambiarras() -> void:
	var carro := {"km": 120.0, "lataria": 0.3, "pintura": 0.3}
	var full: int = Economy.repaired_value("car-a", carro)
	print("    carro de referencia vale R$ %d consertado" % full)

	for point: String in Economy.GAMBIARRAS:
		var lista: Array[Dictionary] = []
		for i in range(Economy.GRAUS):
			# Pela funcao do jogo, nao pela tabela crua: e ela que junta o
			# objeto com os numeros do grau, e e ela que o jogo chama.
			lista.append(Economy.gambiarra_option(point, i))
		var custos: Array[int] = []
		var aguentam: Array[float] = []
		for opt: Dictionary in lista:
			custos.append(Economy.gambiarra_price(opt, full))
			aguentam.append(float(opt["aguenta"]))
			print("      %-9s %-32s R$ %3d  %-11s desconta %.1f%%" % [
				point, opt["nome"], Economy.gambiarra_price(opt, full),
				Economy.gambiarra_grade(opt), float(opt["desconto"]) * 100.0])
		check(lista.size() == Economy.GRAUS, "%s tem %d opcoes" % [point, Economy.GRAUS])
		check(custos[0] < custos[1] and custos[1] < custos[2],
			"%s: mais caro = mais caro de verdade" % point)
		check(aguentam[0] < aguentam[1] and aguentam[1] < aguentam[2],
			"%s: mais caro aguenta mais" % point)

	# Preco proporcional ao carro, e nao reais fixos (licao das pecas mecanicas).
	var taxi: int = Economy.repaired_value("taxi", carro)
	var esporte: int = Economy.repaired_value("sports-car-a", carro)
	var opt_media := Economy.gambiarra_option("bumper", 1)
	check(Economy.gambiarra_price(opt_media, esporte)
			> Economy.gambiarra_price(opt_media, taxi),
		"a mesma lona custa mais no esportivo",
		"R$ %d contra R$ %d" % [Economy.gambiarra_price(opt_media, esporte),
			Economy.gambiarra_price(opt_media, taxi)])

	# Resistencia contra o mundo real: o buraco da rua (Pothole.impact_force 8.0,
	# escalado de 0.3 a 3.0 pela velocidade) tem que separar os degraus.
	var limiar := 7.0   # break_threshold da peca
	var buraco_devagar := 8.0 * 0.5
	var buraco_rapido := 8.0 * 1.6
	print("    buraco devagar = %.1f de estresse | buraco rapido = %.1f" % [
		buraco_devagar, buraco_rapido])
	var barata: float = float(Economy.gambiarra_option("bumper", 0)["aguenta"]) * limiar
	var media: float = float(Economy.gambiarra_option("bumper", 1)["aguenta"]) * limiar
	var cara: float = float(Economy.gambiarra_option("bumper", 2)["aguenta"]) * limiar
	print("    aguentam ate: barata %.1f | media %.1f | cara %.1f" % [barata, media, cara])
	check(barata < buraco_devagar, "a barata cai ate num buraco devagar")
	check(media > buraco_devagar and media < buraco_rapido,
		"a media passa no devagar e cai no rapido")
	check(cara > buraco_rapido, "a cara aguenta o buraco rapido")

	# A PERGUNTA QUE IMPORTA: cada grau ganha em ALGUM cenario?
	#
	# Se a cara ganhasse sempre, ela seria so um imposto pra quem tem dinheiro;
	# se a barata ganhasse sempre (foi o que este teste pegou na primeira
	# calibragem), o catalogo inteiro seria enfeite. O que separa os cenarios e
	# a DURABILIDADE — cada grau perde as pecas que o estresse daquela viagem
	# arranca, e nao um numero igual pra todos.
	var pecas_ok := {"motor": 1.0, "freio": 1.0, "suspensao": 1.0,
		"pneus": 1.0, "bateria": 1.0, "escapamento": 1.0}
	var cenarios := [
		{"nome": "viagem calma  (estresse 2.0)", "estresse": 2.0, "esperado": 1},
		{"nome": "viagem normal (estresse 5.0)", "estresse": 5.0, "esperado": 2},
		{"nome": "viagem feia   (estresse 13.0)", "estresse": 13.0, "esperado": 3},
	]
	for cen: Dictionary in cenarios:
		var estresse: float = cen["estresse"]
		print("    %s:" % cen["nome"])
		var melhor := 0
		var melhor_lucro := -999999
		for grau in range(Economy.GRAUS):
			var custo := 0
			var postas: Dictionary = {}
			var intactas := 0
			for point: String in Economy.GAMBIARRAS:
				var opt := Economy.gambiarra_option(point, grau)
				custo += Economy.gambiarra_price(opt, full)
				# Mesma regra do GambiarraPart: quebra acima de limiar*aguenta.
				if estresse <= limiar * float(opt["aguenta"]):
					postas[point] = opt
					intactas += 1
			var venda := Economy.market_value("car-a", carro, intactas, 4,
				pecas_ok, postas)
			var lucro := venda - custo
			print("      grau %d: gastou R$ %3d, sobraram %d/4, vende por R$ %3d -> lucro R$ %3d" % [
				grau + 1, custo, intactas, venda, lucro])
			if lucro > melhor_lucro:
				melhor_lucro = lucro
				melhor = grau + 1
		check(melhor == int(cen["esperado"]),
			"%s: ganha o grau %d" % [cen["nome"].strip_edges(), int(cen["esperado"])],
			"ganhou o grau %d" % melhor)
	_gambiarras_completou = true
