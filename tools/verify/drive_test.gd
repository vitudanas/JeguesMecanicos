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

	# ------------------------------------------------------ rodas do rig
	var rig = car.rig
	print("\n[rig] eixo dianteiro z=%.2f | traseiro z=%.2f | bitola %.2f | raio da roda %.3f" % [
		rig.front_axle_z, rig.rear_axle_z, rig.half_track * 2.0, rig.wheel_radius])
	print("[rig] caixa da carroceria %.2f x %.2f x %.2f em y=%.2f" % [
		rig.body_aabb.size.x, rig.body_aabb.size.y, rig.body_aabb.size.z,
		rig.body_aabb.position.y])
	if rig.front_axle_z >= 0.0 or rig.rear_axle_z <= 0.0:
		fail("eixos invertidos: a frente do carro tem que estar no -Z")

	# Pontos de gambiarra caem sobre a carroceria?
	var box: AABB = rig.body_aabb
	for spot: Node3D in car.get_node("AttachPoints").get_children():
		var p: Vector3 = spot.position
		var inside_x: bool = absf(p.x) <= box.size.x * 0.5 + 0.25
		var inside_z: bool = absf(p.z) <= box.size.z * 0.5 + 0.25
		var inside_y: bool = p.y >= box.position.y - 0.2 and p.y <= box.position.y + box.size.y + 0.25
		print("[gambiarra] %-9s em (%.2f, %.2f, %.2f) %s" % [
			spot.point_name, p.x, p.y, p.z,
			"ok" if (inside_x and inside_z and inside_y) else "FORA DO CARRO"])
		if not (inside_x and inside_z and inside_y):
			fail("ponto de gambiarra '%s' fica fora da carroceria" % spot.point_name)
