extends Node
## O carro CONSEGUE SAIR do patio da oficina?
##
## Depois de montar as 4 gambiarras o jogador entra no carro e o proximo passo
## e dirigir ate a cidade. O patio tem barracao, tanque, cerca e sucata em
## volta, e a carcaca para em qualquer angulo — se acelerar so empurrar contra
## um obstaculo, o loop trava ali, com o jogo parecendo funcionar.
##
## O teste dirige DE VERDADE (tecla W pelo mesmo caminho de input do jogo) a
## partir de varios angulos de parada e mede quanto o carro se afasta.
##
##   godot --headless --path . tools/verify/yard_test.tscn

## Quanto o carro precisa se afastar da vaga pra contar como "saiu do patio".
const ESCAPE_DIST := 22.0
const DRIVE_SECONDS := 7.0
const HEADINGS: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

var problems: Array[String] = []
var main: Node
var player: CharacterBody3D
var car: RigidBody3D

func fail(msg: String) -> void:
	problems.append(msg)
	print("    FALHOU: " + msg)

func _ready() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	player = get_tree().get_first_node_in_group("player")
	await _run()
	print("\n=== RESULTADO ===")
	if problems.is_empty():
		print("da pra sair do patio da oficina dirigindo")
	else:
		print("%d problema(s):" % problems.size())
		for p in problems:
			print("  - " + p)
	get_tree().quit(0 if problems.is_empty() else 1)

func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _ground_at(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, p.y + 8.0, p.z), Vector3(p.x, p.y - 20.0, p.z))
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else 0.0

func _run() -> void:
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is RigidBody3D:
			car = n
			break
	var workshop := get_tree().get_first_node_in_group("workshop")
	if car == null or workshop == null:
		fail("nao achei carro ou oficina na cena")
		return

	var drop: Vector3 = workshop.get_drop_position()
	var ground := _ground_at(drop)
	print("=== SAIDA DO PATIO DA OFICINA ===")
	print("vaga em (%.0f, %.0f), chao y=%.2f" % [drop.x, drop.z, ground])
	print("sai do patio quem se afastar %.0f m em ate %.0fs de W\n" % [
		ESCAPE_DIST, DRIVE_SECONDS])

	# A prova que importa vem PRIMEIRO, com a cena ainda intacta: o angulo em que
	# a carcaca realmente para depois de ser rebocada. Rodando depois da
	# varredura, o resultado era artefato do arnes (o carro dava 336 graus sem
	# nada que explicasse no jogo) — a varredura entra e sai da DropZone oito
	# vezes, dirige o carro pra longe e deixa a oficina em outro estado. Esperar
	# nao lavou; rodar antes resolve.
	await _tow_and_park(drop, ground)

	# Carro pronto (nao sucateado): e nesse estado que o jogador dirige.
	car.is_wrecked = false
	car.at_workshop = true
	# Entrar pelo caminho REAL (interact -> enter_vehicle), nao setando os campos
	# na mao: e o enter_vehicle que decide o que acontece com a capsula do
	# jogador, e foi exatamente ali que estava o defeito.
	car.interact(player)
	await get_tree().physics_frame

	print("\n[2] cada angulo de parada, pra mapear o formato do patio")
	var escaped := 0
	for heading: float in HEADINGS:
		car.freeze = false
		car.global_position = Vector3(drop.x, ground + 0.8, drop.z)
		car.global_rotation = Vector3(0.0, deg_to_rad(heading), 0.0)
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		car.force_update_transform()
		_key(KEY_W, false)
		for i in range(90):
			await get_tree().physics_frame

		var start: Vector3 = car.global_position
		var best := 0.0
		_key(KEY_W, true)
		var frames := int(DRIVE_SECONDS * 60.0)
		for i in range(frames):
			await get_tree().physics_frame
			var d: float = Vector2(car.global_position.x - start.x,
				car.global_position.z - start.z).length()
			best = maxf(best, d)
			if best >= ESCAPE_DIST:
				break
		_key(KEY_W, false)

		var blocked := ""
		if best < ESCAPE_DIST:
			# Distinguir PRESO de LENTO: um carro parado contra um obstaculo e
			# um problema de layout; um carro ainda andando so precisava de mais
			# tempo. Sem essa medida os dois viram "preso" no relatorio.
			var speed: float = Vector2(car.linear_velocity.x, car.linear_velocity.z).length()
			var grounded := 0
			for w in car.wheels:
				if w.is_colliding():
					grounded += 1
			blocked = "| fim a %.1f m/s, %d/4 rodas no chao, %s" % [
				speed, grounded, _what_is_ahead()]
		var mark := "ok   " if best >= ESCAPE_DIST else ("LENTO" if best > 12.0 else "PRESO")
		print("    %s virado pra %3.0f graus: andou %5.1f m %s" % [
			mark, heading, best, blocked])
		if best >= ESCAPE_DIST:
			escaped += 1

	print("\n    saiu em %d dos %d angulos" % [escaped, HEADINGS.size()])
	# Nem todo angulo precisa dar certo — de frente pro barracao o jogador da re,
	# e isso e jogo, nao bug. O que nao pode e a maioria travar: ai o jogador nao
	# entende que basta manobrar e acha que o carro nao anda.
	if escaped < HEADINGS.size() / 2:
		fail("o patio prende o carro: so %d de %d angulos conseguem sair" % [
			escaped, HEADINGS.size()])

## O angulo em que a carcaca REALMENTE para depois de ser rebocada — o unico que
## o jogador vive. Varrer os 8 angulos diz o formato do patio; isto aqui diz o
## que acontece na partida. O ferro-velho fica ao NORTE, entao o carro chega
## indo pro sul e para apontando de volta pro barracao: o primeiro W anda ~8 m
## e encosta.
##
## Isso e RELATADO, nao tratado como defeito. Tentei fazer a oficina estacionar
## a carcaca virada pra saida e cada correcao revelou outra interacao: girar em
## torno da origem translada a caixa de colisao (que e deslocada, vinda da
## medida do modelo) e o solver jogava o carro 5,6 m fora da vaga; teleportar
## pra vaga encravava na laje; o raio que media o chao batia no proprio carro e
## depois na cabeca do jogador; e no fim o carro caia EM CIMA do jogador, que
## esta parado ali porque acabou de rebocar, e assentava tombado 16 graus.
## Teleportar corpo rigido pra cima de onde o jogador esta e fragil por
## natureza, e o ganho seria so evitar uma re. Dar re e jogo.
func _tow_and_park(drop: Vector3, ground: float) -> void:
	print("[1] o angulo em que a carcaca para depois do REBOQUE de verdade")
	car.is_wrecked = true
	var junkyard := get_tree().get_first_node_in_group("junkyard")
	var from_pos: Vector3 = junkyard.global_position if junkyard else Vector3(drop.x, drop.y, drop.z + 38.0)
	car.freeze = false
	car.global_position = Vector3(from_pos.x, ground + 0.8, from_pos.z)
	car.global_rotation = Vector3.ZERO
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.force_update_transform()
	player.global_position = Vector3(from_pos.x, ground + 1.0, from_pos.z - 3.0)
	for i in range(60):
		await get_tree().physics_frame
	player.start_towing(car)
	var walk_step := 4.0 / 60.0
	var steps := 0
	while Vector2(car.global_position.x - drop.x, car.global_position.z - drop.z).length() > 2.5 and steps < 1800:
		var dir: Vector3 = drop - player.global_position
		dir.y = 0.0
		player.global_position += dir.normalized() * walk_step
		player.rotation.y = atan2(-dir.x, -dir.z)
		steps += 1
		await get_tree().physics_frame
	# Tempo pra oficina estacionar E pro carro assentar depois de largado: ele e
	# solto com folga acima do chao pra cair na propria suspensao.
	for i in range(360):
		await get_tree().physics_frame
	var rest_yaw: float = fposmod(rad_to_deg(car.global_rotation.y), 360.0)
	print("    a carcaca parou virada pra %.0f graus" % rest_yaw)

	# Dirigir a partir DESSE angulo, que e o unico que o jogador vive.
	car.is_wrecked = false
	car.interact(player)
	await get_tree().physics_frame
	var start2: Vector3 = car.global_position
	var best2 := 0.0
	_key(KEY_W, true)
	for i in range(int(DRIVE_SECONDS * 60.0)):
		await get_tree().physics_frame
		best2 = maxf(best2, Vector2(car.global_position.x - start2.x,
			car.global_position.z - start2.z).length())
		if best2 >= ESCAPE_DIST:
			break
	_key(KEY_W, false)
	if best2 >= ESCAPE_DIST:
		print("    do angulo real, W sozinho ja tira o carro do patio (%.1f m)" % best2)
	else:
		print("    do angulo real, W sozinho andou %.1f m | %s" % [best2, _what_is_ahead()])
		print("    (esperado: o jogador manobra. O que NAO pode e o carro nao andar)")
	# O que e defeito de verdade: o carro nao sair do lugar. Antes da capsula do
	# jogador ser desligada ao dirigir, isso dava 0.0 m — o proprio corpo do
	# jogador, invisivel e parado onde ele entrou, segurava o carro.
	if best2 < 3.0:
		fail("com W segurado o carro andou so %.1f m: nao e manobra, e algo prendendo" % best2)
	# Devolve o jogador pro chao: a varredura entra no carro pelo caminho real,
	# e `interact` nao faz nada se o jogador ja e o motorista.
	player.exit_vehicle()
	await get_tree().physics_frame

## O que esta na frente do carro, pra dizer QUEM prende (nao so que prendeu).
##
## Tres raios (quina esquerda, centro, quina direita) e duas alturas. Com UM
## raio no centro o teste disse "nada na frente" pra um carro parado a 0.2 m/s
## com as 4 rodas no chao — o carro tinha batido de QUINA no tanque, que o raio
## central passa raspando. Um verificador que responde "nada" quando existe algo
## e pior que nao ter verificador.
func _what_is_ahead() -> String:
	var space := get_viewport().world_3d.direct_space_state
	var fwd: Vector3 = -car.global_transform.basis.z
	var right: Vector3 = car.global_transform.basis.x
	var half_w: float = car.rig.body_aabb.size.x * 0.5 if car.rig else 0.9
	var best_d := INF
	var best_who := ""
	for side: float in [-1.0, 0.0, 1.0]:
		for h: float in [0.25, 0.7]:
			var from: Vector3 = car.global_position + Vector3(0, h, 0) + right * (side * half_w * 0.9)
			var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 6.0)
			q.exclude = [car.get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var d: float = from.distance_to(hit["position"])
			if d < best_d:
				best_d = d
				var n: Node = hit["collider"]
				best_who = String(n.name)
				var p := n.get_parent()
				if p != null:
					best_who = "%s/%s" % [String(p.name), best_who]
	if best_who.is_empty():
		return "(nada em 6 m por nenhum dos 6 raios — ai sim e tracao/terreno)"
	return "barrado por %s a %.1f m" % [best_who, best_d]
