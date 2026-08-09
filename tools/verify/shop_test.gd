extends Node
## A LOJA: as areas do terreno mudam mesmo o jogo?
##
## Progressao e o tipo de sistema que passa fácil por decorativo — tabela bonita
## de niveis que nao altera nada. Entao aqui nada e conferido contra a propria
## tabela: cada nivel e COMPRADO de verdade e o efeito e medido no jogo.
##
##   godot --headless --path . tools/verify/shop_test.tscn

var problems: Array[String] = []

func check(ok: bool, label: String, detail := "") -> void:
	if ok:
		print("    ok: %s%s" % [label, "" if detail == "" else "  (%s)" % detail])
	else:
		print("    FALHOU: %s%s" % [label, "" if detail == "" else "  (%s)" % detail])
		problems.append(label)

func _ready() -> void:
	await get_tree().process_frame
	Dealership.reset()
	GameManager.reset()

	print("[1] a loja comeca pequena")
	for area in Dealership.ORDER:
		print("    %-12s nivel 1/%d — %s" % [area, Dealership.max_level(area) + 1,
			Dealership.current_text(area)])
	check(Dealership.can_repair("bateria"), "oficina nv.1 troca bateria")
	check(not Dealership.can_repair("motor"), "oficina nv.1 NAO troca motor")
	check(not Dealership.can_repair("freio"), "oficina nv.1 NAO troca freio")

	print("\n[2] sem dinheiro nao se compra upgrade")
	GameManager.money = 10
	var erro := Dealership.buy("oficina")
	check(erro != "", "compra recusada sem dinheiro", erro)
	check(Dealership.level("oficina") == 0, "o nivel nao subiu de graca")

	print("\n[3] comprar destrava conserto de verdade")
	GameManager.money = 100000
	check(Dealership.buy("oficina") == "", "comprou oficina nv.2")
	check(Dealership.can_repair("freio"), "agora a oficina troca freio")
	check(not Dealership.can_repair("motor"), "motor ainda nao (e o nivel 3)")
	check(Dealership.buy("oficina") == "", "comprou oficina nv.3")
	check(Dealership.can_repair("motor"), "agora troca motor")
	check(Dealership.buy("oficina") != "", "no teto, nao da pra comprar mais")

	print("\n[4] o upgrade custa dinheiro de verdade")
	Dealership.reset()
	GameManager.money = 100000
	var antes := GameManager.money
	var custo := Dealership.next_cost("patio")
	Dealership.buy("patio")
	check(GameManager.money == antes - custo, "patio debitou R$ %d" % custo,
		"%d -> %d" % [antes, GameManager.money])
	check(Dealership.yard_slots() > 1, "patio nv.2 cabe mais de um carro",
		"%d vagas" % Dealership.yard_slots())

	print("\n[5] o escritorio melhora a oferta do cliente (retorno do investimento)")
	Dealership.reset()
	var cliente := Economy.CLIENTS[0]
	var base := int(round(Economy.offer(cliente, 300) * Dealership.office_bonus()))
	GameManager.money = 100000
	Dealership.buy("escritorio")
	var melhor := int(round(Economy.offer(cliente, 300) * Dealership.office_bonus()))
	print("    mesmo carro e mesmo cliente: R$ %d -> R$ %d" % [base, melhor])
	check(melhor > base, "o escritorio paga de volta")

	print("\n[6] o progresso da loja sobrevive ao disco")
	Dealership.reset()
	GameManager.money = 100000
	Dealership.buy("oficina")
	Dealership.buy("funilaria")
	var esperado := Dealership.to_dict().duplicate()
	SaveGame.save()
	Dealership.reset()
	check(Dealership.level("oficina") == 0, "reset zerou antes de reler")
	SaveGame._read()
	SaveGame.apply_to_game()
	print("    depois de reler: %s" % Dealership.to_dict())
	check(Dealership.to_dict() == esperado, "os niveis voltaram do disco")
	SaveGame.clear()

	print("")
	if problems.is_empty():
		print("=== RESULTADO ===")
		print("as areas da loja custam, destravam e sobrevivem ao disco")
		get_tree().quit(0)
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
		get_tree().quit(1)
