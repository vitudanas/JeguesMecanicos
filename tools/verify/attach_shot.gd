extends Node
## FOTO do que o jogador ve na hora de montar a gambiarra.
##
## Os testes anteriores provam que o raycast acerta os marcadores. Isso nao
## responde a pergunta que importa: DA PRA VER onde mirar? Aqui o carro vai pro
## patio da oficina, o jogador se posiciona como quem chegou andando, e a foto
## sai pela camera DELE.
##
## Precisa de janela de verdade (headless nao rasteriza):
##   godot --path . tools/verify/attach_shot.tscn

const OUT_DIR := "user://attach_shots"

var main: Node
var player: CharacterBody3D
var car: RigidBody3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	player = get_tree().get_first_node_in_group("player")
	await _run()
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

func _shot(name: String) -> void:
	# 12 frames: da tempo da particula de fumaca emitir e do frame estabilizar.
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("  foto: %s" % name)

## Altura do chao logo abaixo de um ponto, por raio de verdade (a colisao do
## mundo, nao um numero chutado).
func _ground_at(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, p.y + 8.0, p.z), Vector3(p.x, p.y - 20.0, p.z))
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else 0.0

## Poe o jogador de pe, a `dist` do alvo, olhando pra ele — igual ao teste de
## ergonomia, pra foto bater com o que foi medido.
func _stand(target: Vector3, dir: Vector3, dist: float, ground_y: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	player.global_position = Vector3(
		target.x + flat.x * dist, ground_y, target.z + flat.z * dist)
	var cam: Camera3D = player.get_node("Head/Camera3D")
	cam.current = true
	var to_target: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to_target.x, -to_target.z)
	cam.rotation.x = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
	player.force_update_transform()
	cam.force_update_transform()

func _run() -> void:
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is RigidBody3D and n.is_wrecked:
			car = n
			break
	if car == null:
		print("nao achei carro sucateado")
		return

	var workshop := get_tree().get_first_node_in_group("workshop")
	var drop: Vector3 = workshop.get_drop_position() if workshop else Vector3.ZERO
	# `get_drop_position()` devolve o CENTRO da Area3D, que fica 1 m acima do
	# chao — usar isso como piso poe jogador e carro boiando. O chao sai de um
	# raio pra baixo, e o carro ASSENTA com fisica em vez de ser teleportado.
	var ground_y := _ground_at(drop)
	car.freeze = false
	car.global_position = Vector3(drop.x, ground_y + 1.0, drop.z)
	car.global_rotation = Vector3.ZERO
	car.linear_velocity = Vector3.ZERO
	car.force_update_transform()
	for i in range(150):
		await get_tree().physics_frame
	car.freeze = true
	print("carro assentou em y=%.2f (chao %.2f), inclinacao %.2f" % [
		car.global_position.y, ground_y, car.global_transform.basis.y.dot(Vector3.UP)])
	var center: Vector3 = car.global_position + Vector3(0, 0.5, 0)

	# Como o jogador chega: de longe, vendo o carro inteiro.
	await _shot("00_chegando")
	_stand(center, Vector3(1, 0, 0.6), 6.0, ground_y)
	await _shot("01_de_longe_6m")
	_stand(center, Vector3(1, 0, 0.6), 3.0, ground_y)
	await _shot("02_perto_3m")

	# Um close de cada marcador, da distancia em que se instala.
	var spots := car.get_node("AttachPoints").get_children()
	for spot in spots:
		if not spot.has_method("get_interact_prompt"):
			continue
		var target: Vector3 = spot.global_position
		var side: Vector3 = target - car.global_position
		side.y = 0.0
		if side.length() < 0.2:
			side = Vector3(1, 0, 0)
		_stand(target, side.normalized(), 2.2, ground_y)
		await _shot("03_%s" % spot.point_name)

	# ---------------------------------------- o carro DEPOIS de gambiarrado
	# A premissa do jogo e vender carro remendado com tranqueira aparente. Se o
	# carro consertado nao se distingue de um carro normal na tela, a premissa
	# nao chega ao jogador — e nenhum teste numerico percebe isso, porque pra
	# eles basta a peca existir e estar presa no lugar certo.
	for spot in spots:
		if spot.has_method("interact"):
			spot.interact(player)
			await get_tree().physics_frame
	for i in range(30):
		await get_tree().physics_frame
	print("    gambiarras instaladas: %d | sucateado: %s" % [
		car.installed_parts.size(), car.is_wrecked])
	var center2: Vector3 = car.global_position + Vector3(0, 0.5, 0)
	for shot_spec: Array in [["frente", Vector3(0, 0, -1)], ["tras", Vector3(0, 0, 1)],
			["esquerda", Vector3(-1, 0, 0)], ["direita", Vector3(1, 0, 0)],
			["tres_quartos", Vector3(1, 0, -0.9)]]:
		_stand(center2, (shot_spec[1] as Vector3).normalized(), 3.4, ground_y)
		await _shot("05_montado_%s" % shot_spec[0])
