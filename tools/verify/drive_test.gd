extends Node
## Banco de provas do carro. Nao da pra apertar tecla numa sessao automatizada,
## entao aqui o Vehicle roda com o _physics_process dele DESLIGADO e o teste
## injeta throttle/steer chamando o mesmo _apply_suspension_and_drive do jogo —
## ou seja, testa o caminho real, nao uma copia da fisica.
##
## Mede: altura de repouso, 0-50 km/h, velocidade final, raio de curva,
## distancia de freada e se o carro capota.

const VEHICLE := preload("res://scenes/vehicle/Vehicle.tscn")

var problems: Array[String] = []
var town: Node3D

func fail(msg: String) -> void:
	problems.append(msg)

func _ready() -> void:
	town = (load("res://scenes/world/Town.tscn") as PackedScene).instantiate()
	add_child(town)
	await get_tree().process_frame
	# Tira trafego e pedestres do caminho: o teste e da FISICA do carro, e com
	# a cidade viva o carro de teste acabava traseirando um carro de IA no meio
	# da medicao (a freada saiu de 3 m/s em vez de 17).
	for n in get_tree().get_nodes_in_group("traffic_car"):
		n.get_parent().queue_free()
	for n in get_tree().get_nodes_in_group("pedestrian"):
		n.queue_free()
	await get_tree().physics_frame
	await _run()
	print("\n=== RESULTADO ===")
	if problems.is_empty():
		print("nenhum problema encontrado")
	else:
		for p in problems:
			print("  - " + p)
	get_tree().quit(0 if problems.is_empty() else 1)

## Cria um carro inteiro (nao sucateado) parado sobre uma rua da cidade.
func _spawn() -> RigidBody3D:
	var car: RigidBody3D = VEHICLE.instantiate()
	car.is_wrecked = false
	town.add_child(car)
	# Rua z=0 (que corre no eixo X), faixa da direita em z=+1.5. A frente do
	# carro e o -Z, entao girar -90 graus aponta ele pro +X — ao longo da rua.
	# Sem isso o teste botava o carro atravessado e ele batia no meio-fio a 4m.
	car.global_position = Vector3(10.0, 0.5, 1.5)
	car.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
	car.set_physics_process(false)
	# MECANICA EM ORDEM. Desde que as pecas passaram a nascer sorteadas (motor
	# quebrado tira 45% da forca, freio 60% da frenagem), este banco de provas
	# media a fisica com um defeito aleatorio dentro — e reprovou por isso. Um
	# teste de FISICA tem que isolar a fisica; o efeito das pecas e testado de
	# proposito na secao propria, abaixo.
	for key: String in car.parts:
		car.parts[key] = 1.0
	return car

func _step(car: RigidBody3D, throttle: float, steer: float, handbrake := false) -> void:
	car.throttle_input = throttle
	car.steer_input = steer
	car.handbrake = handbrake
	car._apply_suspension_and_drive(get_physics_process_delta_time())
	car._update_visual(get_physics_process_delta_time())
	await get_tree().physics_frame

func _settle(car: RigidBody3D, frames: int) -> void:
	for i in range(frames):
		await _step(car, 0.0, 0.0)

func _run() -> void:
	var dt := get_physics_process_delta_time()
	print("=== BANCO DE PROVAS DO CARRO (passo de fisica %.4fs) ===" % dt)

	# ---------------------------------------------------------- repouso
	var car := _spawn()
	await _settle(car, 180)
	var rest_y: float = car.global_position.y
	var road_top := 0.02  # topo do asfalto (ver CityStreets.road_surface_y)
	print("\n[repouso] origem do carro em y=%.3f (asfalto em %.2f) => folga %+.3f m" % [
		rest_y, road_top, rest_y - road_top])
	if absf(rest_y - road_top) > 0.12:
		fail("carro nao assenta no asfalto: origem em %.3f, esperado ~%.2f" % [rest_y, road_top])
	var up: float = car.global_transform.basis.y.dot(Vector3.UP)
	if up < 0.9:
		fail("carro nasce tombado (up=%.2f)" % up)

	# Quantas rodas encostam parado — se for < 4 a suspensao esta errada.
	var grounded := 0
	for w: RayCast3D in car.wheels:
		if w.is_colliding():
			grounded += 1
	print("[repouso] rodas no chao: %d de %d" % [grounded, car.wheels.size()])
	if grounded < 4:
		fail("so %d rodas encostam no chao parado" % grounded)

	# --------------------------------------------------------- aceleracao
	var t := 0.0
	var t_50 := -1.0
	var top := 0.0
	for i in range(900):
		await _step(car, 1.0, 0.0)
		t += dt
		var v: float = car.forward_speed()
		top = maxf(top, v)
		if t_50 < 0.0 and v >= 13.9:  # 50 km/h
			t_50 = t
	print("\n[aceleracao] 0-50 km/h em %.1fs | velocidade final %.1f m/s (%.0f km/h)" % [
		t_50, top, top * 3.6])
	if t_50 < 0.0:
		fail("o carro nao chega a 50 km/h em 15s de acelerador")
	if top * 3.6 < 45.0 or top * 3.6 > 130.0:
		fail("velocidade final fora do razoavel para um calhambeque: %.0f km/h" % (top * 3.6))
	if car.global_transform.basis.y.dot(Vector3.UP) < 0.8:
		fail("carro tombou so acelerando em linha reta")

	# ------------------------------------------------------------- curva
	car.queue_free()
	await get_tree().physics_frame
	car = _spawn()
	await _settle(car, 120)
	for i in range(120):
		await _step(car, 1.0, 0.0)
	var start := car.global_position
	var start_yaw: float = car.global_rotation.y
	var turn_speed: float = car.forward_speed()
	var yaw_sum := 0.0
	var prev_yaw := start_yaw
	for i in range(180):
		await _step(car, 0.6, 1.0)
		var y: float = car.global_rotation.y
		yaw_sum += wrapf(y - prev_yaw, -PI, PI)
		prev_yaw = y
	var turned: float = absf(yaw_sum)
	print("\n[curva] a %.1f m/s girou %.0f graus em 3s" % [turn_speed, rad_to_deg(turned)])
	if turned < deg_to_rad(45.0):
		fail("o carro quase nao vira (%.0f graus em 3s a %.1f m/s)" % [
			rad_to_deg(turned), turn_speed])
	var up_turn: float = car.global_transform.basis.y.dot(Vector3.UP)
	print("[curva] inclinacao no fim: up=%.2f" % up_turn)
	if up_turn < 0.6:
		fail("o carro capota ao virar (up=%.2f)" % up_turn)

	# ------------------------------------------------------------ freada
	car.queue_free()
	await get_tree().physics_frame
	car = _spawn()
	await _settle(car, 120)
	for i in range(300):
		await _step(car, 1.0, 0.0)
	var v0: float = car.forward_speed()
	var p0 := car.global_position
	var frames := 0
	while car.forward_speed() > 0.5 and frames < 600:
		await _step(car, -1.0, 0.0)
		frames += 1
	var dist: float = p0.distance_to(car.global_position)
	print("\n[freada] de %.1f m/s parou em %.1f m (%.1fs)" % [v0, dist, frames * dt])
	if frames >= 600:
		fail("o carro nao para com o freio (S) em 10s")

	# ------------------------------------------------- re depois de parar
	for i in range(120):
		await _step(car, -1.0, 0.0)
	var rev: float = car.forward_speed()
	print("[re] velocidade apos 2s de S parado: %.2f m/s" % rev)
	if rev > -0.5:
		fail("o carro nao anda de re (%.2f m/s)" % rev)

	# ------------------------------------------------------- queda de 5m
	car.queue_free()
	await get_tree().physics_frame
	car = _spawn()
	car.global_position = Vector3(10.0, 5.0, 1.5)
	var peak := 0.0
	for i in range(600):
		await _step(car, 0.0, 0.0)
		peak = maxf(peak, car.global_position.y)
	var after := car.global_position.y
	print("\n[queda] solto de 5m: pico depois do impacto %.2f m, repouso %.3f m" % [peak, after])
	# Sem batente na mola o carro era catapultado a dezenas de metros.
	if peak > 5.2:
		fail("o carro foi CATAPULTADO no impacto (subiu a %.1f m)" % peak)
	if absf(after - 0.02) > 0.15:
		fail("depois da queda o carro nao voltou a assentar (y=%.2f)" % after)

	# ------------------------------------------- o defeito mecanico se sente
	# Nao basta o multiplicador existir no papel: o carro com motor quebrado tem
	# que ANDAR MENOS no mesmo tempo de acelerador.
	car.queue_free()
	await get_tree().physics_frame
	car = _spawn()
	await _settle(car, 90)
	var partida_sadio: Vector3 = car.global_position
	for i in range(180):
		await _step(car, 1.0, 0.0)
	var dist_sadio: float = partida_sadio.distance_to(car.global_position)

	car.queue_free()
	await get_tree().physics_frame
	car = _spawn()
	car.parts["motor"] = 0.0
	await _settle(car, 90)
	var partida_ruim: Vector3 = car.global_position
	for i in range(180):
		await _step(car, 1.0, 0.0)
	var dist_ruim: float = partida_ruim.distance_to(car.global_position)
	print("\n[mecanica] 3s de acelerador: motor bom %.1f m, motor quebrado %.1f m"
		% [dist_sadio, dist_ruim])
	if dist_ruim >= dist_sadio * 0.9:
		fail("motor quebrado quase nao muda o desempenho (%.1f vs %.1f m)"
			% [dist_ruim, dist_sadio])

	# --------------------------------------------------- resgate do capotado
	# Ate esta rodada NAO HAVIA COMO se recuperar: capotou, a partida acabava
	# ali. Este teste prova as duas metades — que o carro de fato NAO se
	# desvira sozinho (senao o resgate seria enfeite) e que o R resolve.
	car.queue_free()
	await get_tree().physics_frame
	car = _spawn()
	await _settle(car, 60)
	# De cabeca pra baixo, no lugar.
	car.global_transform = Transform3D(
		Basis(Vector3.FORWARD, PI), car.global_position + Vector3.UP * 0.5)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	await _settle(car, 180)
	var up_flipped: float = car.global_transform.basis.y.dot(Vector3.UP)
	print("\n[resgate] capotado e largado 3s: up=%.2f, sozinho=%s"
		% [up_flipped, "de pe" if car.is_upright() else "CONTINUA CAPOTADO"])
	if car.is_upright():
		fail("o carro se desvirou sozinho — o teste nao esta testando nada")

	car.driver = self   # o resgate so vale com motorista, como no jogo
	car.recover()
	await _settle(car, 90)
	var up_after: float = car.global_transform.basis.y.dot(Vector3.UP)
	var grounded_after := 0
	for w in car.wheels:
		if w.is_colliding():
			grounded_after += 1
	print("[resgate] depois do R: up=%.2f, %d/4 rodas no chao" % [up_after, grounded_after])
	if not car.is_upright():
		fail("o resgate nao desvirou o carro (up=%.2f)" % up_after)
	if grounded_after < 3:
		fail("depois do resgate o carro nao assenta (%d/4 rodas)" % grounded_after)
	# E tem que voltar a ANDAR: desvirar e largar enterrado no chao nao resolve.
	var before_drive: Vector3 = car.global_position
	for i in range(120):
		await _step(car, 1.0, 0.0)
	var drove: float = before_drive.distance_to(car.global_position)
	print("[resgate] andou %.1f m depois de resgatado" % drove)
	if drove < 3.0:
		fail("resgatado, o carro nao volta a andar (%.1f m em 2s)" % drove)
	car.driver = null

	# ----------------------------------------------------------- reboque
	car.queue_free()
	await get_tree().physics_frame
	car = _spawn()
	car.is_wrecked = true
	await _settle(car, 120)
	var tow_start := car.global_position
	# Mesma forca de scripts/TowHook.gd, com o gancho 6m a frente.
	for i in range(240):
		var target: Vector3 = tow_start + Vector3(6.0, 0.0, 0.0)
		var to_target: Vector3 = target - car.global_position
		car.apply_central_force((to_target * 14.0 - car.linear_velocity * 7.0) * car.mass)
		await _step(car, 0.0, 0.0)
	var towed: float = tow_start.distance_to(car.global_position)
	print("\n[reboque] arrastado %.2f m em 4s (alvo a 6 m)" % towed)
	if towed < 3.0:
		fail("o carro sucateado quase nao se move sendo rebocado (%.2f m)" % towed)

	# --------------------------------- todos os modelos do pool sao usaveis
	# O modelo e sorteado por carro, entao o teste de fisica so cobre UM. Aqui
	# cada modelo do pool e montado e conferido: se algum tiver as rodas com
	# outro nome ou proporcao esquisita, o Vehicle sai quebrado so as vezes —
	# que e o pior tipo de bug pra achar depois.
	print("\n[pool] conferindo cada modelo de carro")
	var probe: RigidBody3D = VEHICLE.instantiate()
	var pool: Array = probe.car_pool
	probe.free()
	for model: PackedScene in pool:
		var c: RigidBody3D = VEHICLE.instantiate()
		c.car_model = model
		c.is_wrecked = false
		town.add_child(c)
		c.global_position = Vector3(10.0, 0.5, 1.5)
		c.set_physics_process(false)
		await get_tree().physics_frame
		var r = c.rig
		var name: String = model.resource_path.get_file()
		var wheels_ok: bool = c.wheels.size() == 4
		var axles_ok: bool = r.front_axle_z < 0.0 and r.rear_axle_z > 0.0
		var size_ok: bool = r.body_aabb.size.z > 2.0 and r.body_aabb.size.x > 1.0
		var reach_ok := true
		for spot: Node3D in c.get_node("AttachPoints").get_children():
			var sp: Vector3 = spot.position
			var protrusion: float = maxf(absf(sp.x) - r.body_aabb.size.x * 0.5,
				maxf(absf(sp.z) - r.body_aabb.size.z * 0.5,
					sp.y - (r.body_aabb.position.y + r.body_aabb.size.y)))
			if protrusion < 0.05 or protrusion > 0.6:
				reach_ok = false
		print("  %-18s %.2f x %.2f x %.2f | rodas %d | eixos %.2f/%.2f | gambiarras %s" % [
			name, r.body_aabb.size.x, r.body_aabb.size.y, r.body_aabb.size.z,
			c.wheels.size(), r.front_axle_z, r.rear_axle_z, "ok" if reach_ok else "INALCANCAVEIS"])
		if not (wheels_ok and axles_ok and size_ok and reach_ok):
			fail("modelo %s nao monta direito (rodas=%d eixos=%s tamanho=%s gambiarras=%s)" % [
				name, c.wheels.size(), axles_ok, size_ok, reach_ok])
		c.queue_free()
		await get_tree().physics_frame

	# ------------------------------------------------------ rodas do rig
	var rig = car.rig
	print("\n[rig] eixo dianteiro z=%.2f | traseiro z=%.2f | bitola %.2f | raio da roda %.3f" % [
		rig.front_axle_z, rig.rear_axle_z, rig.half_track * 2.0, rig.wheel_radius])
	print("[rig] caixa da carroceria %.2f x %.2f x %.2f em y=%.2f" % [
		rig.body_aabb.size.x, rig.body_aabb.size.y, rig.body_aabb.size.z,
		rig.body_aabb.position.y])
	if rig.front_axle_z >= 0.0 or rig.rear_axle_z <= 0.0:
		fail("eixos invertidos: a frente do carro tem que estar no -Z")

	# Cada marcador tem que SOBRAR da caixa de colisao (senao o raycast de
	# interacao acerta a carroceria antes e o jogador nao consegue mirar nele)
	# mas continuar encostado no carro. O teste de loop pegou 3 pontos
	# inalcancaveis exatamente por isso.
	var box: AABB = rig.body_aabb
	for spot: Node3D in car.get_node("AttachPoints").get_children():
		var p: Vector3 = spot.position
		# Quanto o ponto passa da caixa em cada eixo (negativo = ainda dentro).
		var out_x: float = absf(p.x) - box.size.x * 0.5
		var out_z: float = absf(p.z) - box.size.z * 0.5
		var out_y: float = p.y - (box.position.y + box.size.y)
		var protrusion: float = maxf(out_x, maxf(out_z, out_y))
		var reachable: bool = protrusion >= 0.05 and protrusion <= 0.6
		# E nao pode estar solto no ar longe do carro.
		var attached: bool = out_x <= 0.6 and out_z <= 0.6 and out_y <= 0.6
		print("[gambiarra] %-9s em (%.2f, %.2f, %.2f) sobra %.2f m %s" % [
			spot.point_name, p.x, p.y, p.z, protrusion,
			"ok" if (reachable and attached) else "INALCANCAVEL"])
		if not (reachable and attached):
			fail("ponto '%s' sobra %.2f m da carroceria (precisa entre 0.05 e 0.6)" % [
				spot.point_name, protrusion])
