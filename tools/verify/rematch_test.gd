extends Node
## A conversa com o comprador PODE SER REZERADA tirando o carro da zona?
##
## Escrito na revisao de 2026-08-13 (Claude) para provar na pratica, e nao so
## por leitura de codigo, o furo apontado no commit `f561f2b`: um blefe
## descoberto custa 10% da oferta e duas rodadas, mas `_on_car_exited` chama
## `_cancel_negotiation()`, e o E seguinte cai no ramo de ABRIR — que chama
## `negotiation.start(...)` e devolve oferta de abertura, rodadas cheias e
## `bluff_used = false`.
##
## Se o preco de errar some por dar uma volta com o carro, as duas jogadas de
## risco viram jogadas sem risco, e a decisao que a rodada introduziu deixa de
## existir. Este teste PASSA quando a punicao SOBREVIVE ao reestacionamento.
##
##   godot --headless --path . tools/verify/rematch_test.tscn

var falhas := 0

func check(cond: bool, label: String, extra := "") -> void:
	var suffix := "  (%s)" % extra if extra != "" else ""
	if cond:
		print("    ok: %s%s" % [label, suffix])
	else:
		falhas += 1
		print("    FALHOU: %s%s" % [label, suffix])

func _ready() -> void:
	await get_tree().process_frame
	print("\n=== a punicao da negociacao sobrevive a reestacionar? ===")

	var npc := (load("res://scenes/npc/BuyerNPC.tscn") as PackedScene).instantiate()
	add_child(npc)
	await get_tree().process_frame

	var carro := (load("res://scenes/vehicle/Vehicle.tscn") as PackedScene).instantiate()
	carro.is_wrecked = false
	add_child(carro)
	await get_tree().physics_frame
	# Carro em ordem e gambiarras inteiras: o furo tem que aparecer no melhor
	# caso possivel, senao alguem pode achar que foi avaria mascarando a conta.
	for k: String in Economy.PARTS:
		carro.parts[k] = 1.0
	for point: String in Economy.GAMBIARRAS:
		carro.installed_parts[point] = null
		carro.installed_options[point] = Economy.gambiarra_option(point, 1)

	# Cliente fixo (nao o sorteado no _ready) pra medida ser reproduzivel.
	npc.client = _by_name("Colecionador")
	npc._on_car_entered(carro)
	check(npc.nearby_vehicle == carro, "o cliente detectou o carro na zona")

	print("\n[1] abre a conversa e QUEIMA um blefe")
	npc.interact(null)
	if not npc.minigame_running:
		print("    FALHOU: a conversa nao abriu")
		_finish()
		return
	var abertura: int = npc.negotiation.current_offer
	var rodadas: int = npc.negotiation.rounds_left
	print("    abriu em R$ %d, %d rodada(s), teto R$ %d" % [
		abertura, rodadas, npc.negotiation.ceiling])

	npc._resolve_bluff(false)  # blefe DESCOBERTO: -10% e -2 rodadas
	var castigo: int = npc.negotiation.current_offer
	var rodadas_pos: int = npc.negotiation.rounds_left
	print("    blefe descoberto: R$ %d -> R$ %d, sobraram %d rodada(s)" % [
		abertura, castigo, rodadas_pos])
	check(castigo < abertura, "o blefe descoberto realmente cortou a oferta")
	check(npc.negotiation.bluff_used, "o blefe ficou marcado como usado")

	print("\n[2] tira o carro da zona e reestaciona (o que o jogador faria)")
	npc._on_car_exited(carro)
	check(not npc.minigame_running, "sair da zona cancela a conversa (isso e certo)")
	npc._on_car_entered(carro)
	npc.interact(null)
	if not npc.minigame_running:
		print("    FALHOU: reestacionar nao reabriu a conversa")
		_finish()
		return
	var depois: int = npc.negotiation.current_offer
	var rodadas_depois: int = npc.negotiation.rounds_left
	print("    reabriu em R$ %d, %d rodada(s), blefe usado: %s" % [
		depois, rodadas_depois, npc.negotiation.bluff_used])

	print("\n[3] o preco de errar sobreviveu?")
	check(depois <= castigo, "a oferta NAO volta ao patamar de antes do blefe",
		"R$ %d apos o castigo de R$ %d" % [depois, castigo])
	check(rodadas_depois <= rodadas_pos, "as rodadas gastas NAO voltam",
		"%d apos ter sobrado %d" % [rodadas_depois, rodadas_pos])
	check(npc.negotiation.bluff_used, "o blefe continua indisponivel",
		"bluff_used = %s" % npc.negotiation.bluff_used)

	if depois > castigo or rodadas_depois > rodadas_pos or not npc.negotiation.bluff_used:
		print("\n    >>> EXPLOIT CONFIRMADO: dar uma volta com o carro apaga o")
		print("        castigo. Ganho de R$ %d por reestacionamento, de graca." % (
			depois - castigo))

	print("\n[4] a conversa pausada se anuncia, e o preco fica travado")
	# O jogador precisa SABER que a oferta ficou de pe; senao ele chega achando
	# que vai comecar de novo e a trava do preco vira mistério.
	npc._on_car_exited(carro)
	npc._on_car_entered(carro)
	var prompt: String = npc.get_interact_prompt()
	check(prompt.contains("pausada") or prompt.contains("retomar"),
		"o prompt avisa que a conversa esta pausada", prompt.split("\n")[1] if
		prompt.split("\n").size() > 1 else prompt)
	# Trocar o pedido reabriria o teto sem pagar rodada: e a mesma brecha por
	# outra porta, entao Q tem que ser recusado enquanto a conversa existe.
	var passo_antes: int = npc.ask_step
	npc.negotiate()
	check(npc.ask_step == passo_antes, "Q nao muda o preco com conversa pausada",
		"ask_step %d -> %d" % [passo_antes, npc.ask_step])

	print("\n[5] e se o carro QUEBRAR enquanto a conversa esta pausada?")
	# Cenario real: o carro rola pra fora, o jogador da a volta, bate num buraco
	# e volta com menos gambiarra. A oferta foi congelada com o carro inteiro.
	var teto_inteiro: int = npc._ceiling()
	var pausada: int = npc.negotiation.current_offer
	for point: String in Economy.GAMBIARRAS:
		carro.installed_parts.erase(point)
	var teto_quebrado: int = npc._ceiling()
	print("    teto com 4/4: R$ %d   |   depois de perder as 4: R$ %d" % [
		teto_inteiro, teto_quebrado])
	npc.interact(null)  # retoma
	var oferta_retomada: int = npc.negotiation.current_offer
	print("    oferta retomada: R$ %d (o carro agora vale bem menos)" % oferta_retomada)
	check(oferta_retomada <= teto_quebrado,
		"a oferta retomada nao passa do que o carro vale AGORA",
		"R$ %d contra um teto de R$ %d" % [oferta_retomada, teto_quebrado])
	if oferta_retomada > teto_quebrado:
		print("    >>> a conversa pausada congela o preco do carro INTEIRO:")
		print("        R$ %d a mais do que o carro danificado vale." % (
			oferta_retomada - teto_quebrado))

	carro.queue_free()
	npc.queue_free()
	_finish()

func _finish() -> void:
	print("\n=== RESULTADO ===")
	if falhas == 0:
		print("a punicao da negociacao sobrevive a reestacionar")
	else:
		print("%d PROBLEMA(S): a negociacao pode ser rezerada de graca" % falhas)
	await get_tree().process_frame
	get_tree().quit(1 if falhas > 0 else 0)

func _by_name(nome: String) -> Dictionary:
	for c in Economy.CLIENTS:
		if c["nome"] == nome:
			return c
	return {}
