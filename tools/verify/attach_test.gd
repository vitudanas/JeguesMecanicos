extends Node
## ERGONOMIA da fixacao de gambiarra: o `loop_test` prova que a LOGICA funciona,
## mas ele teleporta o jogador pro angulo perfeito de cada marcador e mira no
## centro exato da esfera. Isso nao prova que da pra fazer com o mouse.
##
## Aqui a pergunta e outra: DE ONDE o jogador consegue mirar em cada bolinha?
## Varre um anel de posicoes em volta do carro (como quem anda em volta dele),
## mira no marcador e ve o que o raycast de interacao pega de verdade. Depois
## mede a TOLERANCIA de mira: quantos graus de erro ainda acertam.
##
## Roda com:
##   godot --headless --path . tools/verify/attach_test.tscn

const RING_STEP_DEG := 15.0
const DISTANCES: Array[float] = [1.2, 1.8, 2.5, 3.2]
const AIM_SWEEP_DEG: Array[float] = [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 14.0, 18.0]

var problems: Array[String] = []
var main: Node
var player: CharacterBody3D
var car: RigidBody3D
var _stand_y := 0.0

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
		print("os 4 pontos de gambiarra sao alcancaveis de posicoes normais")
	else:
		print("%d problema(s):" % problems.size())
		for p in problems:
			print("  - " + p)
	get_tree().quit(0 if problems.is_empty() else 1)

# --------------------------------------------------------------------- utilidade

## Mesmo posicionamento do loop_test: o jogador fica DE PE no chao (nao pairando
## na altura do alvo), porque o angulo de visada muda tudo pra um alvo baixo.
func _aim_at(target: Vector3, from_dir: Vector3, dist: float,
		yaw_err := 0.0, pitch_err := 0.0) -> void:
	var flat := Vector3(from_dir.x, 0.0, from_dir.z).normalized()
	player.global_position = Vector3(
		target.x + flat.x * dist, _stand_y, target.z + flat.z * dist)
	player.velocity = Vector3.ZERO
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var to_target: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to_target.x, -to_target.z) + deg_to_rad(yaw_err)
	cam.rotation.x = atan2(to_target.y,
		Vector2(to_target.x, to_target.z).length()) + deg_to_rad(pitch_err)
	player.force_update_transform()
	cam.force_update_transform()

## Altura do chao logo abaixo de um ponto, por raio de verdade.
func _ground_at(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, p.y + 8.0, p.z), Vector3(p.x, p.y - 20.0, p.z))
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else 0.0

func _aimed_at() -> Node:
	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractRay")
	ray.force_update_transform()
	ray.force_raycast_update()
	return ray.get_collider()

func _label(n: Node) -> String:
	if n == null:
		return "NADA (raio nao acerta nada)"
	if n == car:
		return "carroceria"
	if n == player:
		return "o proprio jogador"
	var p := n.get_parent()
	var owner_name := "?"
	if p != null and p.get_parent() != null:
		owner_name = String(p.get_parent().name)
	return "%s (de %s)" % [String(n.name), owner_name]

# ------------------------------------------------------------------------- teste

func _run() -> void:
	print("=== ERGONOMIA DA GAMBIARRA ===\n")

	# O carro sucateado do ferro-velho e o que o jogador conserta.
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is RigidBody3D and n.is_wrecked:
			car = n
			break
	if car == null:
		fail("nao achei nenhum carro sucateado na cena")
		return

	# Tira o carro do patio da oficina e poe em campo ABERTO, deitado no chao.
	# Aqui a pergunta e sobre mirar, nao sobre o cenario em volta: se o teste
	# rodasse encostado na cerca, um marcador bloqueado pela cerca viraria
	# "inalcancavel" e esconderia o resultado real da mira.
	var open_field := Vector3(-120.0, 0.5, 8.0)
	var field_ground := _ground_at(open_field)
	car.freeze = false
	car.global_position = Vector3(open_field.x, field_ground + 1.0, open_field.z)
	car.global_rotation = Vector3.ZERO
	car.linear_velocity = Vector3.ZERO
	car.force_update_transform()
	for i in range(150):
		await get_tree().physics_frame
	car.freeze = true

	var spots: Array[Node] = []
	for s in car.get_node("AttachPoints").get_children():
		if s.has_method("get_interact_prompt"):
			spots.append(s)
	print("carro: %s | %d pontos de gambiarra" % [car.name, spots.size()])

	var box: AABB = car.rig.body_aabb
	print("carroceria: %.2f x %.2f x %.2f m | topo a %.2f m do chao\n" % [
		box.size.x, box.size.y, box.size.z, car.global_position.y + box.position.y + box.size.y])

	_stand_y = field_ground
	var eye: float = _stand_y + 1.6

	# ---------------------------------------------------- 1. de onde da pra mirar
	print("[1] de quantas posicoes normais cada bolinha e alcancavel")
	print("    (anel de %d graus em %d distancias = %d posicoes por ponto)" % [
		int(RING_STEP_DEG), DISTANCES.size(),
		int(360.0 / RING_STEP_DEG) * DISTANCES.size()])
	for spot in spots:
		var target: Vector3 = spot.global_position
		var hits := 0
		var total := 0
		var blockers: Dictionary = {}
		var ang := 0.0
		while ang < 360.0:
			var dir := Vector3(cos(deg_to_rad(ang)), 0.0, sin(deg_to_rad(ang)))
			for d: float in DISTANCES:
				# Posicao dentro da carroceria nao conta: o jogador nao chega la.
				var stand := Vector3(target.x + dir.x * d, _stand_y, target.z + dir.z * d)
				var local: Vector3 = car.to_local(Vector3(stand.x, car.global_position.y, stand.z))
				if absf(local.x) < box.size.x * 0.5 + 0.35 and absf(local.z) < box.size.z * 0.5 + 0.35:
					continue
				total += 1
				_aim_at(target, dir, d)
				var hit := _aimed_at()
				if hit == spot:
					hits += 1
				else:
					var k := _label(hit)
					blockers[k] = int(blockers.get(k, 0)) + 1
			ang += RING_STEP_DEG
		var pct: float = 100.0 * float(hits) / float(maxi(total, 1))
		var line := "    %-10s altura %.2f m (olho %.2f) | acerta de %d/%d posicoes (%.0f%%)" % [
			spot.point_name, target.y, eye, hits, total, pct]
		print(line)
		if not blockers.is_empty():
			var parts: Array[String] = []
			for k: String in blockers:
				parts.append("%s x%d" % [k, blockers[k]])
			print("               barrado por: %s" % ", ".join(parts))
		if hits == 0:
			fail("%s: NENHUMA posicao consegue mirar nele" % spot.point_name)
		elif pct < 25.0:
			fail("%s: so %.0f%% das posicoes conseguem mirar (muito apertado)" % [
				spot.point_name, pct])

	# --------------------------------------------- 2. quanto erro de mira aguenta
	# De onde o jogador REALMENTE fica: do lado pra onde o marcador aponta
	# (retrovisor -> pela esquerda, parachoque -> por tras). Pegar em vez disso
	# "o primeiro angulo do anel que acerta" mede um angulo raspante e reporta
	# tolerancia zero num ponto que na pratica e facil — foi o que aconteceu.
	print("\n[2] tolerancia de mira (de frente pro ponto, erro em graus)")
	for spot in spots:
		var target: Vector3 = spot.global_position
		var best_dir: Vector3 = target - car.global_position
		best_dir.y = 0.0
		if best_dir.length() < 0.2:
			best_dir = Vector3(1.0, 0.0, 0.0)
		best_dir = best_dir.normalized()
		_aim_at(target, best_dir, 1.8)
		if _aimed_at() != spot:
			print("    %-10s de frente pro ponto o raio pega %s" % [
				spot.point_name, _label(_aimed_at())])
			fail("%s: nem de frente da pra mirar nele" % spot.point_name)
			continue
		var max_yaw := 0.0
		var max_pitch := 0.0
		for err: float in AIM_SWEEP_DEG:
			_aim_at(target, best_dir, 1.8, err, 0.0)
			var a := _aimed_at() == spot
			_aim_at(target, best_dir, 1.8, -err, 0.0)
			if a and _aimed_at() == spot:
				max_yaw = err
			_aim_at(target, best_dir, 1.8, 0.0, err)
			var b := _aimed_at() == spot
			_aim_at(target, best_dir, 1.8, 0.0, -err)
			if b and _aimed_at() == spot:
				max_pitch = err
		print("    %-10s aguenta +-%.0f graus na horizontal, +-%.0f na vertical" % [
			spot.point_name, max_yaw, max_pitch])
		if max_yaw < 3.0 or max_pitch < 3.0:
			fail("%s: exige mira quase perfeita (+-%.0f/%.0f graus)" % [
				spot.point_name, max_yaw, max_pitch])

	# ------------------------------------------- 3. da pra VER a bolinha de longe?
	print("\n[3] a bolinha aparece na tela? (esfera visivel x hitbox)")
	var marker_mesh: MeshInstance3D = spots[0].get_node("Marker")
	var vis_r: float = (marker_mesh.mesh as SphereMesh).radius
	var col_shape: CollisionShape3D = spots[0].get_node("Collision")
	var hit_r: float = (col_shape.shape as SphereShape3D).radius
	print("    esfera visivel: raio %.2f m | hitbox: raio %.2f m" % [vis_r, hit_r])
	for d: float in [2.0, 4.0, 8.0]:
		var apparent: float = rad_to_deg(atan(vis_r / d)) * 2.0
		print("    a %.0f m ela ocupa %.1f graus da tela" % [d, apparent])
	if vis_r < hit_r * 0.5:
		print("    NOTA: o alvo que voce ACERTA e %.1fx maior que a bolinha que voce VE." % (hit_r / vis_r))

	# ------------------------------ 4. no patio da oficina, onde o jogo poe o carro
	print("\n[4] no patio da oficina de verdade (com cerca/barracao em volta)")
	var workshop := get_tree().get_first_node_in_group("workshop")
	if workshop == null or not workshop.has_method("get_drop_position"):
		print("    (sem oficina na cena, pulado)")
	else:
		var drop: Vector3 = workshop.get_drop_position()
		# `get_drop_position()` e o CENTRO da Area3D, 1 m acima do chao — usar
		# esse Y como piso punha jogador e carro boiando no ar, e a medicao
		# deixava de valer. O chao sai de um raio de verdade e o carro ASSENTA
		# com fisica, como no jogo.
		var ground := _ground_at(drop)
		car.freeze = false
		car.global_position = Vector3(drop.x, ground + 1.0, drop.z)
		car.global_rotation = Vector3.ZERO
		car.linear_velocity = Vector3.ZERO
		car.force_update_transform()
		for i in range(150):
			await get_tree().physics_frame
		car.freeze = true
		_stand_y = ground
		print("    carro assentou em y=%.2f (chao %.2f), de pe %.2f" % [
			car.global_position.y, ground, car.global_transform.basis.y.dot(Vector3.UP)])
		for spot in spots:
			var target: Vector3 = spot.global_position
			var hits := 0
			var total := 0
			var blockers: Dictionary = {}
			var ang3 := 0.0
			while ang3 < 360.0:
				var dir := Vector3(cos(deg_to_rad(ang3)), 0.0, sin(deg_to_rad(ang3)))
				for d: float in DISTANCES:
					var stand := Vector3(target.x + dir.x * d, _stand_y, target.z + dir.z * d)
					var local: Vector3 = car.to_local(Vector3(stand.x, car.global_position.y, stand.z))
					if absf(local.x) < box.size.x * 0.5 + 0.35 and absf(local.z) < box.size.z * 0.5 + 0.35:
						continue
					total += 1
					_aim_at(target, dir, d)
					var hit := _aimed_at()
					if hit == spot:
						hits += 1
					else:
						var k := _label(hit)
						blockers[k] = int(blockers.get(k, 0)) + 1
				ang3 += RING_STEP_DEG
			var pct: float = 100.0 * float(hits) / float(maxi(total, 1))
			print("    %-10s acerta de %d/%d (%.0f%%)" % [spot.point_name, hits, total, pct])
			if not blockers.is_empty():
				var parts: Array[String] = []
				for k: String in blockers:
					parts.append("%s x%d" % [k, blockers[k]])
				print("               barrado por: %s" % ", ".join(parts))
			if hits == 0:
				fail("no patio da oficina, %s fica inalcancavel" % spot.point_name)

		# ------------------------- 5. a armadilha do "Rebocar" na propria carroceria
		# A carroceria e o alvo que o jogador mais acerta sem querer: ela ocupa a
		# tela toda ao lado de 4 bolinhas pequenas. Se ali aparecer "Rebocar [E]",
		# apertar E reengata o reboque e ARRASTA o carro pra longe dos marcadores
		# — foi o que travou o jogo de verdade, com o loop_test passando 5/5.
		print("\n[5] mirando na CARROCERIA dentro do patio da oficina")
		print("    at_workshop = %s" % car.at_workshop)
		var body_prompts: Dictionary = {}
		var ang4 := 0.0
		while ang4 < 360.0:
			var dir := Vector3(cos(deg_to_rad(ang4)), 0.0, sin(deg_to_rad(ang4)))
			for d: float in [2.5, 3.2]:
				_aim_at(car.global_position + Vector3(0, 0.45, 0), dir, d)
				if _aimed_at() == car:
					var pr: String = car.get_interact_prompt()
					body_prompts[pr] = int(body_prompts.get(pr, 0)) + 1
			ang4 += RING_STEP_DEG
		for pr: String in body_prompts:
			print("    '%s' x%d" % [pr, body_prompts[pr]])
			if pr.begins_with("Rebocar"):
				fail("na oficina a carroceria ainda oferece 'Rebocar' (%d posicoes): apertar E arrasta o carro pra longe das gambiarras" % body_prompts[pr])
		if body_prompts.is_empty():
			print("    (o raio nunca pegou a carroceria nessas posicoes)")
