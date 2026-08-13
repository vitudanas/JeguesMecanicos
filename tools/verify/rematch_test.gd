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
