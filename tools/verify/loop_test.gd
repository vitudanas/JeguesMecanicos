extends Node
## Teste do CORE LOOP inteiro, no caminho real do jogo.
##
## Carrega o Main.tscn de verdade (Town + Player + HUD) e percorre
## ferro-velho -> reboque -> oficina -> 4 gambiarras -> dirigir -> entrega ->
## minigame de labia -> venda.
##
## O truque que faz isso valer: `Input.parse_input_event()` alimenta o mesmo
## estado de teclado que `Input.is_key_pressed()` le, entao o E de interagir e
## o F de sair do carro passam pelo codigo do jogo, nao por um atalho do teste.
## Sem isso da so pra chamar os metodos por fora e o teste nao prova nada sobre
## o input.

var problems: Array[String] = []
var main: Node
var player: CharacterBody3D

func fail(msg: String) -> void:
	problems.append(msg)
	print("    FALHOU: " + msg)

func ok(msg: String) -> void:
	print("    ok: " + msg)

func _ready() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		fail("nao achei o jogador na cena")
		_finish()
		return
	await _run()
	_finish()

func _finish() -> void:
	print("\n=== RESULTADO ===")
	if problems.is_empty():
		print("loop completo funcionou de ponta a ponta")
	else:
		print("%d problema(s):" % problems.size())
		for p in problems:
			print("  - " + p)
	get_tree().quit(0 if problems.is_empty() else 1)

# ------------------------------------------------------------------ input real

func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

var _flip_logged := false
var _pose_pos := Vector3.ZERO
var _pose_yaw := 0.0
var _pose_pitch := 0.0
var _pose_held := false
var _track: Node3D = null
var _track_dist := 1.5
var _track_from := Vector3.ZERO

## Reancora o jogador na pose mirada. Sem isso ele cai/desliza entre posicionar
## e apertar E, e o raycast sai do alvo no frame que importa.
##
## Quando ha `_track`, a mira e RECALCULADA a cada frame a partir da posicao
## atual do alvo: o carro ainda se acomoda alguns milimetros na oficina, e uma
## pose congelada errava justo o marcador mais baixo (o radiador). Um jogador
## tambem acompanha o alvo com o olho.
func _hold_pose() -> void:
	if not _pose_held:
		return
	if _track != null and is_instance_valid(_track):
		# Alvo vivo: reaponta a partir de onde ele esta AGORA.
		_aim_at(_track.global_position, _track_dist, _track_from)
		return
	player.global_position = _pose_pos
	player.velocity = Vector3.ZERO
	player.rotation.y = _pose_yaw
	(player.get_node("Head/Camera3D") as Camera3D).rotation.x = _pose_pitch

## Posiciona e aponta, sem esperar frame nenhum.
var _stand_y := 0.0

## `_stand_y` = altura do CHAO onde o jogador esta em pe. Antes o teste punha o
## jogador 0.6m acima do ALVO, entao pra um marcador baixo (o radiador, a 0.39m
## do chao) a camera ficava 2.4m acima dele e o raio descia 58 graus — de tao
## rasante, escorregava pra carroceria. De pe no chao o angulo vira ~39 graus,
## que e o que um jogador de verdade tem.
func _aim_at(target: Vector3, dist: float, away: Vector3) -> void:
	var flat_away := Vector3(away.x, 0.0, away.z)
	if flat_away.length() < 0.01:
		flat_away = Vector3(1.0, 0.0, 0.0)
	player.global_position = Vector3(
		target.x + flat_away.normalized().x * dist, _stand_y,
		target.z + flat_away.normalized().z * dist)
	player.velocity = Vector3.ZERO
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var to_target: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to_target.x, -to_target.z)
	cam.rotation.x = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())

## Segura a tecla por varios frames, reancorando a pose em cada um. Com so 2
## frames o jogador caia/deslizava o suficiente pro raycast trocar de alvo
## bem no frame em que o Player le o E — e a interacao ia pro alvo errado.
func _tap(keycode: Key) -> void:
	_key(keycode, true)
	for i in range(8):
		_hold_pose()
		await get_tree().physics_frame
	_key(keycode, false)
	_hold_pose()
	await get_tree().physics_frame

## Poe o jogador a `dist` do alvo e mira nele (yaw no corpo, pitch na camera —
## e assim que o raycast de interacao aponta no jogo).
func _stand_and_aim(target: Vector3, dist: float, from := Vector3.ZERO) -> void:
	var away := from
	if away == Vector3.ZERO:
		away = Vector3(1.0, 0.0, 0.35).normalized()
	_aim_at(target, dist, away)
	_track_dist = dist
	_track_from = away
	var cam: Camera3D = player.get_node("Head/Camera3D")
	_pose_pos = player.global_position
	_pose_yaw = player.rotation.y
	_pose_pitch = cam.rotation.x
	_pose_held = true
	for i in range(3):
		_hold_pose()
		await get_tree().physics_frame
	_hold_pose()

func _aimed_at() -> Node:
	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractRay")
	ray.force_raycast_update()
	return ray.get_collider()

# ----------------------------------------------------------------------- loop

func _run() -> void:
	var town := main.get_node("Town")
	print("=== LOOP COMPLETO ===")

	# ------------------------------------------------- 1. rebocar do ferro-velho
	print("\n[1] ferro-velho: rebocar a carcaca")
	# O jogo sorteia o modelo do carro por carcaca (de proposito). Pro TESTE
	# isso e ruim: cada modelo tem tamanho diferente, e a geometria de cada
	# mira mudava a cada rodada — o teste passava ou falhava por sorte. Aqui o
	# LOTE inteiro do ferro-velho (ver JunkyardLot.gd) e refeito com um modelo
	# FIXO. Todo o resto (compra, reboque, gambiarra, direcao, venda) continua
	# passando pelo codigo real.
	var junkyard: Node3D = town.get_node("Junkyard")
	for c in junkyard.get_children():
		if c.is_in_group("vehicle"):
			c.free()
	junkyard.forced_model = load("res://assets/quaternius/cars/car-a.glb")
	junkyard.restock_now()
	await get_tree().physics_frame
	var wreck: RigidBody3D = null
	for c in junkyard.get_children():
		if c.is_in_group("vehicle"):
			wreck = c
			break
	if wreck == null:
		fail("nao achei o carro do ferro-velho")
		return
	if not wreck.is_wrecked:
		fail("o carro do ferro-velho nao comeca sucateado")
	await _stand_and_aim(wreck.global_position + Vector3(0, 0.7, 0), 2.4)

	# A carcaca tem DONO: primeiro vistoria, pechincha e compra; so depois
	# reboca. Antes ela era de graca e o dinheiro do jogador so subia.
	if wreck.owned:
		fail("a carcaca do ferro-velho ja nasce do jogador")
		return
	await _tap(KEY_Q)
	await _stand_and_aim(wreck.global_position + Vector3(0, 0.7, 0), 2.4)
	if not wreck.inspected:
		fail("Q na carcaca nao fez a vistoria")
		return
	ok("vistoria revelou o estado: %s" % wreck.condition_text())
	var pedido_inicial: int = wreck.asking_price
	await _tap(KEY_Q)
	ok("pechincha: pediam R$ %d, agora R$ %d%s" % [pedido_inicial, wreck.asking_price,
		"" if wreck.asking_price < pedido_inicial else " (o dono se fechou — tem risco)"])

	# REAPONTA antes de cada acao. A pose nao se mantem sozinha, e o raycast que
	# o Player le e o do passo ANTERIOR: depois de dois toques de Q a mira ja
	# tinha escorregado e o alvo vinha <null>, entao o E "nao comprava". Era o
	# arnes, nao o jogo.
	await _stand_and_aim(wreck.global_position + Vector3(0, 0.7, 0), 2.4)

	# Rebocar SEM comprar nao pode funcionar, senao a compra e decorativa.
	var carteira: int = GameManager.money
	await _tap(KEY_E)
	if player.tow_hook.is_towing():
		fail("deu pra rebocar a carcaca SEM comprar")
		return
	if GameManager.money != carteira - wreck.asking_price:
		fail("comprar nao tirou o dinheiro certo (R$ %d -> R$ %d, pedido R$ %d)"
			% [carteira, GameManager.money, wreck.asking_price])
		return
	ok("comprou por R$ %d (carteira %d -> %d)" % [
		carteira - GameManager.money, carteira, GameManager.money])
	var seen := _aimed_at()
	if seen != wreck:
		fail("mirando na carcaca o raycast pegou %s" % [seen])
	else:
		ok("o raycast de interacao acha a carcaca (prompt: '%s')" % wreck.get_interact_prompt())
	# De novo: cada acao precisa da sua mira. `_aimed_at()` acima le o raycast do
	# passo anterior e nao SEGURA a pose — sem reapontar, o E do reboque chegava
	# com o alvo ja perdido.
	await _stand_and_aim(wreck.global_position + Vector3(0, 0.7, 0), 2.4)
	await _tap(KEY_E)
	var hook = player.get_node("TowHook")
	if not hook.is_towing():
		fail("apertar E na carcaca nao engatou o reboque")
		return
	ok("E engatou o reboque")

	# ------------------------------------------------ 2. arrastar ate a oficina
	print("\n[2] levar ate a oficina")
	var workshop := get_tree().get_first_node_in_group("workshop")
	var drop: Vector3 = workshop.get_drop_position()
	var start_dist: float = wreck.global_position.distance_to(drop)
	# O jogador anda ate a oficina; o TowHook puxa o carro sozinho.
	# Velocidade real de caminhada (WALK_SPEED = 4.0 m/s), nao teleporte: e a
	# unica forma de provar que o reboque acompanha quem esta andando.
	_pose_held = false
	var walk_step: float = 4.0 / 60.0
	var steps := 0
	# Ate o CARRO chegar, nao o jogador: o carro vem alguns metros atras, entao
	# quem arrasta passa um pouco do ponto — que e o que um jogador faz.
	while wreck.global_position.distance_to(drop) > 2.5 and steps < 1800:
		var dir: Vector3 = (drop - player.global_position)
		dir.y = 0.0
		player.global_position += dir.normalized() * walk_step
		player.rotation.y = atan2(-dir.x, -dir.z)
		steps += 1
		await get_tree().physics_frame
		var up_now: float = wreck.global_transform.basis.y.dot(Vector3.UP)
		if up_now < 0.5 and not _flip_logged:
			_flip_logged = true
			print("      TOMBOU no frame %d: carro %s vel %s | jogador %s | dist ao alvo %.1f" % [
				steps, wreck.global_position.round(), wreck.linear_velocity.round(),
				player.global_position.round(), wreck.global_position.distance_to(drop)])
		# O carro nunca pode SUBIR no jogador nem sobrepor a capsula dele: foi
		# assim que ele acabou empoleirado e sendo ejetado a 375 m/s. Os
		# primeiros frames sao ignorados porque no engate o jogador esta
		# propositalmente perto, e o reboque ainda vai afastar o carro.
		if steps > 40:
			var gap: float = wreck.global_position.distance_to(player.global_position)
			var rise: float = wreck.global_position.y - player.global_position.y
			if gap < 1.8 or (gap < 2.5 and rise > 0.5):
				fail("no reboque o carro chegou a %.2f m do jogador e %+.2f m acima" % [gap, rise])
				break
	# O jogador chegou; o carro tem alguns segundos pra assentar na DropZone.
	for i in range(120):
		await get_tree().physics_frame
	var end_dist: float = wreck.global_position.distance_to(drop)
	print("    carcaca: %.1f m -> %.1f m da oficina em %d frames" % [start_dist, end_dist, steps])
	if end_dist > 5.0:
		fail("o carro nao acompanhou o reboque ate a oficina (parou a %.1f m)" % end_dist)
	else:
		ok("o carro foi arrastado ate a oficina")
	if hook.is_towing():
		fail("a DropZone da oficina nao soltou o reboque")
	else:
		ok("a DropZone soltou o reboque sozinha")

	# --------------------------------------------------- 3. montar as gambiarras
	print("\n[3] montar as 4 gambiarras")
	# Espera a carcaca parar antes de mirar. Com o carro ainda se acomodando o
	# marcador se mexe debaixo da mira e o E vai parar na carroceria.
	_pose_held = false
	var rest := 0
	while wreck.linear_velocity.length() > 0.15 and rest < 600:
		rest += 1
		await get_tree().physics_frame
	print("    carcaca parada em %.1fs (vel %.3f m/s)" % [
		rest / 60.0, wreck.linear_velocity.length()])
	if rest >= 600:
		fail("a carcaca nao para de escorregar na oficina (%.2f m/s)" % wreck.linear_velocity.length())
	# Altura em que o jogador ANDA, nao a do chao: a origem da capsula fica ~0.9m
	# acima dos pes. Usando a altura do chao ele nascia meio enterrado, o
	# move_and_slide empurrava ele quase um metro pra cima no frame seguinte e a
	# mira ia junto — o raio acabava no piso da oficina em vez do radiador.
	_stand_y = player.global_position.y
	var spots := wreck.get_node("AttachPoints").get_children()
	if spots.size() != 4:
		fail("esperava 4 pontos de gambiarra, achei %d" % spots.size())
	for spot: Node3D in spots:
		# Aproxima pelo lado em que o marcador sobra da carroceria — que e o
		# unico de onde da pra mirar nele, e o que um jogador faria.
		var side: Vector3 = spot.global_position - wreck.global_position
		# O capo sobra pra cima, entao a aproximacao dele nao e horizontal.
		if spot.point_name == "hood":
			side = (wreck.global_transform.basis.y + wreck.global_transform.basis.x * 0.6)
		side.y = maxf(side.y, 0.0)
		await _stand_and_aim(spot.global_position, 1.5, side.normalized())
		var ray0: RayCast3D = player.get_node("Head/Camera3D/InteractRay")
		var cam0: Camera3D = player.get_node("Head/Camera3D")
		ray0.force_raycast_update()
		print("      [%s] marcador %s | camera %s | bate em %s no ponto %s | dist %.2f" % [
			spot.point_name, spot.global_position, cam0.global_position,
			ray0.get_collider(),
			ray0.get_collision_point() if ray0.is_colliding() else Vector3.ZERO,
			cam0.global_position.distance_to(spot.global_position)])
		# Tenta alguns pontos de vista, como um jogador que circula o carro ate a
		# gambiarra ficar na mira. O radiador, mais baixo e embaixo do bico, so
		# entra de certos angulos.
		var hit := _aimed_at()
		if hit != spot:
			for extra: float in [25.0, -25.0, 50.0, -50.0]:
				var alt: Vector3 = side.normalized().rotated(Vector3.UP, deg_to_rad(extra))
				await _stand_and_aim(spot.global_position, 1.6, alt)
				hit = _aimed_at()
				if hit == spot:
					break
		if hit != spot:
			fail("mirando no ponto '%s' o raycast pegou %s" % [spot.point_name, hit])
			continue
		# Ate 3 tentativas. Nao e complacencia com bug: o RayCast3D que o Player
		# le e o do passo de fisica ANTERIOR, entao o teste (que reposiciona o
		# jogador por codigo) as vezes aperta E um frame antes da mira valer.
		# Um jogador que aperta E e nao instala simplesmente aperta de novo.
		# O Player so interage na BORDA DE SUBIDA do E, e nesse frame o RayCast3D
		# ainda e o do passo de fisica anterior — ou seja, a primeira batida
		# pode ir pro alvo errado. Toques repetidos COM A POSE PARADA resolvem:
		# na segunda o raio ja alcancou a mira. (Mexer o jogador entre as
		# tentativas so refaz o atraso.)
		var tries := 0
		while not wreck.installed_parts.has(spot.point_name) and tries < 4:
			tries += 1
			await _tap(KEY_E)
		if wreck.installed_parts.has(spot.point_name):
			ok("gambiarra instalada: %s (%d tentativa(s))" % [spot.display_name, tries])
		else:
			print("      DEBUG: no momento do E o jogador mirava em %s | raio agora: %s | ja instalado: %s" % [
				player.current_interactable, _aimed_at(), wreck.installed_parts.keys()])
			fail("E no ponto '%s' nao instalou a peca" % spot.point_name)
		_track = null
	if wreck.is_wrecked:
		fail("com as 4 gambiarras o carro deveria deixar de estar sucateado")
	else:
		ok("carro pronto (is_wrecked = false)")

	# --------------------------------------------------------- 4. entrar e dirigir
	print("\n[4] entrar no carro")
	# Depois de montar as gambiarras o carro tem que estar PARADO. Se ele fica
	# balancando na oficina, nao e so o teste que erra a mira — o jogador
	# tambem persegue um alvo que se mexe.
	_pose_held = false
	var settle := 0
	while wreck.linear_velocity.length() > 0.3 and settle < 300:
		settle += 1
		await get_tree().physics_frame
	var upright: float = wreck.global_transform.basis.y.dot(Vector3.UP)
	print("    assentou em %.1fs, parado em y=%.2f (vel %.2f m/s) | de pe: %.2f" % [
		settle / 60.0, wreck.global_position.y, wreck.linear_velocity.length(), upright])
	if upright < 0.7:
		fail("o carro chegou na oficina TOMBADO (up=%.2f) — nao da pra montar nem dirigir" % upright)
	if settle >= 300:
		fail("o carro nao para de se mexer na oficina (%.2f m/s depois de 5s)" % wreck.linear_velocity.length())
	var roof: float = wreck.rig.body_aabb.position.y + wreck.rig.body_aabb.size.y * 0.55
	# Aproxima pelo LADO DO CARRO (basis.x dele), nao pelo +X do mundo: depois do
	# reboque o carro para virado pra qualquer lado, e quando o eixo longo dele
	# calhava de ficar no X do mundo o jogador era posto 1.9m do centro de um
	# carro de 4.2m — ou seja, DENTRO dele, e o raio nao acertava nada.
	var flank: Vector3 = wreck.global_transform.basis.x.normalized()
	await _stand_and_aim(wreck.global_position + Vector3(0, roof, 0), 1.9, flank)
	if _aimed_at() != wreck:
		var cam2: Camera3D = player.get_node("Head/Camera3D")
		var tgt: Vector3 = wreck.global_position + Vector3(0, roof, 0)
		print("      DEBUG mira no carro: carro %s rot_y=%.0f caixa %.2fx%.2f | alvo %s" % [
			wreck.global_position.round(), rad_to_deg(wreck.global_rotation.y),
			wreck.rig.body_aabb.size.x, wreck.rig.body_aabb.size.z, tgt.round()])
		print("      jogador %s camera %s dist ate o alvo %.2f (raio alcanca 3.5)" % [
			player.global_position.round(), cam2.global_position.round(),
			cam2.global_position.distance_to(tgt)])
		fail("nao consegui mirar no carro pronto (pegou %s)" % [_aimed_at()])
	await _tap(KEY_E)
	if wreck.driver != player:
		fail("E no carro pronto nao colocou o jogador na direcao")
		return
	ok("jogador entrou no carro (camera de perseguicao ativa: %s)" % wreck.chase_camera.current)

	# O HUD tem que CONTAR o estado das gambiarras. O preco de venda vai de 40%
	# a 100% conforme as pecas intactas, e antes disto nada na tela dizia quantas
	# ainda estavam de pe — o jogador dirigia cego sobre a unica variavel que
	# mexe no dinheiro dele.
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null or hud.damage_label == null:
		fail("HUD sem o indicador de gambiarras")
		return
	await get_tree().process_frame
	if GameManager.active_vehicle != wreck:
		fail("o HUD nao sabe qual e o carro do jogador")
		return
	if not hud.damage_label.visible:
		fail("indicador de gambiarras invisivel com o jogador dirigindo")
		return
	ok("HUD mostra '%s'" % hud.damage_label.text)
	if not hud.damage_label.text.contains("4/4"):
		fail("carro inteiro mas o HUD nao diz 4/4: '%s'" % hud.damage_label.text)
		return

	# Arrebenta uma gambiarra e cobra que a leitura ACOMPANHE: um indicador que
	# so acerta no estado inicial nao serve pra nada.
	var vitima = wreck.installed_parts.values()[0]
	vitima.receive_stress(999.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if not hud.damage_label.text.contains("3/4"):
		fail("gambiarra quebrou e o HUD continua dizendo '%s'" % hud.damage_label.text)
		return
	ok("depois de quebrar uma: '%s'" % hud.damage_label.text)

	# Acelera de verdade por 2s pra provar que o carro dirigido responde ao W.
	_track = null
	_pose_held = false
	# Aponta o carro pro lado aberto do patio antes de acelerar. Depois do
	# reboque ele para virado pra qualquer lado, e quando calha de ficar de
	# nariz pro barracao o acelerador so empurra contra a parede — um jogador
	# daria re, o teste nao tem como. O que se quer medir aqui e o W chegando
	# no carro, nao a manobra.
	# Leva o carro pra estrada antes de acelerar. O patio da oficina tem cerca,
	# sucata, tanque e barracao: dependendo de como a carcaca parou, o
	# acelerador so empurra contra alguma coisa. O que este teste prova e que o
	# W CHEGA no carro pelo caminho real do input; o desempenho (0-50, final,
	# freada) e medido no drive_test, em pista livre.
	wreck.global_position = Vector3(-120.0, 0.6, 1.5)
	wreck.global_rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
	wreck.linear_velocity = Vector3.ZERO
	wreck.angular_velocity = Vector3.ZERO
	for i in range(60):
		await get_tree().physics_frame
	var v0: float = wreck.forward_speed()
	var p0 := wreck.global_position
	_key(KEY_W, true)
	# PICO, nao velocidade final: o patio da oficina tem cerca, sucata e tanque,
	# entao o carro acelera e bate em algo — o que se quer provar aqui e que o W
	# move o carro, nao que ha pista livre.
	var peak_speed := 0.0
	for i in range(120):
		await get_tree().physics_frame
		peak_speed = maxf(peak_speed, wreck.forward_speed())
	_key(KEY_W, false)
	var moved: float = p0.distance_to(wreck.global_position)
	print("    W por 2s: partiu de %.2f m/s, pico %.2f m/s, andou %.2f m" % [v0, peak_speed, moved])
	if peak_speed < 3.0 or moved < 3.0:
		var touching: Array[String] = []
		for b in wreck.get_colliding_bodies():
			touching.append(String(b.name))
		print("      DEBUG: carro encostando em %s | throttle=%.1f rodas no chao=%d" % [
			touching, wreck.throttle_input,
			wreck.wheels.filter(func(w): return w.is_colliding()).size()])
		fail("segurando W o carro nao acelerou (pico %.2f m/s, andou %.2f m)" % [peak_speed, moved])
	else:
		ok("W acelera o carro dirigido")

	# ------------------------------------------------------------- 5. a entrega
	print("\n[5] entrega")
	var buyer := get_tree().get_first_node_in_group("buyer")
	if buyer == null:
		fail("nenhum comprador foi sorteado pelo DeliveryManager")
		return
	ok("cliente sorteado numa casa em (%.0f, %.0f)" % [
		buyer.global_position.x, buyer.global_position.z])
	# A viagem ja foi provada no drive_test; aqui o que importa e a ZONA.
	var zone: Area3D = buyer.get_node("CarZone")
	wreck.global_position = zone.global_position + Vector3(0.0, 0.4, 0.0)
	wreck.linear_velocity = Vector3.ZERO
	wreck.angular_velocity = Vector3.ZERO
	for i in range(40):
		await get_tree().physics_frame
	if buyer.nearby_vehicle != wreck:
		fail("o carro parado na CarZone nao foi detectado pelo cliente")
		return
	ok("cliente detectou o carro na zona (prompt: '%s')" % buyer.get_interact_prompt())

	# Sair do carro com F e mirar no cliente.
	await _tap(KEY_F)
	if player.driving_vehicle != null:
		fail("F nao tirou o jogador do carro")
	else:
		ok("F tirou o jogador do carro")

	await _stand_and_aim(buyer.global_position + Vector3(0, 1.0, 0), 1.8)
	if _aimed_at() != buyer:
		fail("nao consegui mirar no cliente")
		return
	await _tap(KEY_E)
	if not buyer.minigame_running:
		fail("E no cliente nao comecou o minigame de labia")
		return
	ok("minigame de labia comecou")

	# ----------------------------------------------------- 6. segurar E e vender
	print("\n[6] segurar E ate fechar a venda")
	var money_before: int = GameManager.money
	var sold := [false]
	var last_progress := [0.0]
	buyer.sale_completed.connect(func(_a): sold[0] = true)
	_key(KEY_E, true)
	var frames := 0
	while not sold[0] and frames < 900:
		if is_instance_valid(buyer):
			last_progress[0] = buyer.persuasion.progress
		await get_tree().process_frame
		frames += 1
	_key(KEY_E, false)
	# O comprador e liberado assim que a venda fecha, entao o progresso tem que
	# ser lido ANTES — tocar nele depois quebra com "previously freed".
	print("    barra encheu em %d frames (progresso antes de fechar %.2f)" % [
		frames, last_progress[0]])
	if not sold[0]:
		fail("segurando E a venda nao fechou em 15s")
		return
	ok("venda fechada")
	var gained: int = GameManager.money - money_before
	if gained <= 0:
		fail("a venda nao creditou dinheiro (%d)" % gained)
	else:
		ok("creditou R$ %d (total %d, carros vendidos %d)" % [
			gained, GameManager.money, GameManager.cars_sold])

	# O DeliveryManager tem que agendar a proxima entrega sozinho.
	for i in range(480):
		await get_tree().process_frame
	print("    compradores na cena depois da venda: %d | entrega ativa: %s" % [
		get_tree().get_nodes_in_group("buyer").size(), DeliveryManager.has_active_delivery()])
	if DeliveryManager.has_active_delivery():
		ok("proxima entrega agendada sozinha")
	else:
		fail("depois da venda o DeliveryManager nao marcou a proxima entrega")
