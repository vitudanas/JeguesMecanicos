extends Node
## Salvamento de progresso, de ponta a ponta.
##
## Salvar e o tipo de coisa que falha CALADA: o jogo roda igual, e o jogador so
## descobre quando volta e o dinheiro sumiu. Entao aqui nada e verificado pelo
## campo em memoria — cada etapa passa pelo DISCO de verdade e e relida.
##
##   godot --headless --path . tools/verify/save_test.tscn

var problems: Array[String] = []

func check(ok: bool, label: String, detail := "") -> void:
	if ok:
		print("    ok: %s%s" % [label, "" if detail == "" else "  (%s)" % detail])
	else:
		print("    FALHOU: %s%s" % [label, "" if detail == "" else "  (%s)" % detail])
		problems.append(label)

func _ready() -> void:
	await get_tree().process_frame
	var backup := _backup()

	print("[1] partida nova, sem save")
	SaveGame.clear()
	check(not SaveGame.has_save, "sem save o jogo nao acha progresso")
	check(not FileAccess.file_exists(SaveGame.PATH), "arquivo removido do disco")

	print("[2] vender um carro salva sozinho")
	GameManager.reset()
	var antes := GameManager.money
	# Pelo sinal real do jogo, nao chamando SaveGame.save() na mao: o que se
	# quer provar e que a VENDA dispara o autosave.
	GameManager.register_sale(275)
	await get_tree().process_frame
	check(FileAccess.file_exists(SaveGame.PATH), "venda gravou o arquivo")
	check(GameManager.money == antes + 275, "dinheiro creditado",
		"%d -> %d" % [antes, GameManager.money])

	print("[3] o que foi pro disco e o que volta dele")
	var esperado_dinheiro := GameManager.money
	var esperado_carros := GameManager.cars_sold
	# Zera a memoria e RELE do disco: sem isto o teste passaria comparando a
	# variavel com ela mesma, sem tocar no arquivo.
	SaveGame.money = 0
	SaveGame.cars_sold = 0
	SaveGame.has_save = false
	SaveGame._read()
	check(SaveGame.has_save, "save relido do disco")
	check(SaveGame.money == esperado_dinheiro, "dinheiro salvo confere",
		"disco %d, esperado %d" % [SaveGame.money, esperado_dinheiro])
	check(SaveGame.cars_sold == esperado_carros, "carros vendidos conferem",
		"disco %d, esperado %d" % [SaveGame.cars_sold, esperado_carros])

	print("[4] Continuar devolve o progresso pro jogo")
	GameManager.reset()
	check(GameManager.money == GameManager.STARTING_MONEY, "reset voltou pro inicio",
		"R$ %d" % GameManager.money)
	var avisado := [0]
	var conn := func(v: int) -> void: avisado[0] = v
	GameManager.money_changed.connect(conn)
	SaveGame.apply_to_game()
	GameManager.money_changed.disconnect(conn)
	check(GameManager.money == esperado_dinheiro, "dinheiro restaurado",
		"%d" % GameManager.money)
	# O HUD nao le o campo, ele ESCUTA — restaurar sem emitir deixaria a tela
	# mostrando o valor velho ate a proxima venda.
	check(avisado[0] == esperado_dinheiro, "sinal emitido pro HUD")

	print("[5] o menu principal oferece Continuar")
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var textos := _button_texts(menu)
	check(textos.any(func(t: String) -> bool: return t.begins_with("Continuar")),
		"botao Continuar presente", ", ".join(textos))
	check(textos.any(func(t: String) -> bool: return t == "Novo jogo"),
		"Jogar virou 'Novo jogo'")
	menu.queue_free()
	await get_tree().process_frame

	print("[6] Novo jogo apaga o progresso")
	SaveGame.clear()
	var menu2 := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu2)
	await get_tree().process_frame
	var textos2 := _button_texts(menu2)
	check(not textos2.any(func(t: String) -> bool: return t.begins_with("Continuar")),
		"sem save, sem botao Continuar", ", ".join(textos2))
	menu2.queue_free()

	_restore(backup)
	print("")
	if problems.is_empty():
		print("=== RESULTADO ===")
		print("progresso salva, sobrevive ao disco e volta pelo menu")
		get_tree().quit(0)
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
		get_tree().quit(1)

func _button_texts(node: Node, out: Array[String] = []) -> Array[String]:
	if node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		_button_texts(c, out)
	return out

## O save do proprio usuario nao pode ser vitima do teste.
func _backup() -> String:
	if not FileAccess.file_exists(SaveGame.PATH):
		return ""
	var f := FileAccess.open(SaveGame.PATH, FileAccess.READ)
	return f.get_as_text() if f else ""

func _restore(content: String) -> void:
	if content == "":
		SaveGame.clear()
		return
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	if f:
		f.store_string(content)
