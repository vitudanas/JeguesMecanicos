extends Node
## FOTOS de cada etapa do loop, pelo ponto de vista do jogador.
##
## Os testes numericos provam que o loop funciona; nao provam que ele e
## LEGIVEL. O defeito que travava o jogo em 2026-08-04 (mirar no carro dava
## "Rebocar [E]" e reengatava o reboque) passava em todo teste e so aparecia na
## tela. Este script leva o jogo ate cada etapa e fotografa dali.
##
## Precisa de janela de verdade (headless nao rasteriza):
##   godot --path . tools/verify/loop_shots.tscn

const OUT_DIR := "user://loop_shots"

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

func _shot(shot_name: String) -> void:
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("  foto: %s" % shot_name)

func _ground_at(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, p.y + 8.0, p.z), Vector3(p.x, p.y - 20.0, p.z))
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else 0.0

## Jogador de pe no chao, a `dist` do alvo, olhando pra ele.
func _stand(target: Vector3, dir: Vector3, dist: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var spot := Vector3(target.x + flat.x * dist, 0.0, target.z + flat.z * dist)
	player.global_position = Vector3(spot.x, _ground_at(spot) + 0.05, spot.z)
	player.velocity = Vector3.ZERO
	var cam: Camera3D = player.get_node("Head/Camera3D")
	cam.current = true
	var to_target: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to_target.x, -to_target.z)
	cam.rotation.x = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
	player.force_update_transform()
	cam.force_update_transform()
	# Um passo de fisica pro RayCast3D de interacao atualizar: o prompt que
	# aparece na foto vem dele, e sem isso a foto sai com o prompt do lugar
	# ANTERIOR — exatamente o tipo de foto que engana quem esta revisando.
	await get_tree().physics_frame
	await get_tree().physics_frame

func _run() -> void:
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is RigidBody3D and n.is_wrecked:
			car = n
			break
	if car == null:
		print("nao achei carro sucateado")
		return

	# ------------------------------------------------- 1. achar a carcaca
	var wreck_pos: Vector3 = car.global_position
	await _stand(wreck_pos + Vector3(0, 0.6, 0), Vector3(0.6, 0, 1), 12.0)
	await _shot("01_ferro_velho_de_longe")
	await _stand(wreck_pos + Vector3(0, 0.6, 0), Vector3(0.6, 0, 1), 3.0)
	await _shot("02_carcaca_de_perto")

	# ------------------------------------------------- 2. rebocando
	player.start_towing(car)
	for i in range(30):
		await get_tree().physics_frame
	var workshop := get_tree().get_first_node_in_group("workshop")
	var drop: Vector3 = workshop.get_drop_position()
	var walk := 4.0 / 60.0
	for i in range(240):
		var dir: Vector3 = drop - player.global_position
		dir.y = 0.0
		player.global_position += dir.normalized() * walk
		player.rotation.y = atan2(-dir.x, -dir.z)
		await get_tree().physics_frame
	# Olhando pra tras, que e como se confere o que esta sendo arrastado.
	var cam: Camera3D = player.get_node("Head/Camera3D")
	player.rotation.y += PI
	cam.rotation.x = deg_to_rad(-10.0)
	player.force_update_transform()
	await _shot("03_rebocando")

	# ------------------------------------------------- 3. carro montado
	var ground := _ground_at(drop)
	car.freeze = false
	car.global_position = Vector3(drop.x, ground + 0.8, drop.z)
	car.global_rotation = Vector3.ZERO
	car.linear_velocity = Vector3.ZERO
	car.force_update_transform()
	for i in range(150):
		await get_tree().physics_frame
	for spot in car.get_node("AttachPoints").get_children():
		if spot.has_method("interact"):
			spot.interact(player)
			await get_tree().physics_frame
	for i in range(60):
		await get_tree().physics_frame
	print("    gambiarras instaladas: %d | sucateado: %s" % [
		car.installed_parts.size(), car.is_wrecked])
	await _stand(car.global_position + Vector3(0, 0.5, 0), Vector3(1, 0, 0.7), 5.0)
	await _shot("04_carro_gambiarrado")

	# ------------------------------------------------- 4. dirigindo na cidade
	car.freeze = false
	car.global_position = Vector3(-100.0, ground + 0.6, 0.0)
	car.global_rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
	car.linear_velocity = Vector3.ZERO
	car.force_update_transform()
	player.global_position = car.global_position + Vector3(0, 1, 3)
	for i in range(60):
		await get_tree().physics_frame
	car.interact(player)
	var ev := InputEventKey.new()
	ev.keycode = KEY_W
	ev.physical_keycode = KEY_W
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in range(180):
		await get_tree().physics_frame
	await _shot("05_dirigindo")
	ev.pressed = false
	Input.parse_input_event(ev)
	for i in range(90):
		await get_tree().physics_frame

	# ------------------------------------------------- 5. a entrega
	var buyer := get_tree().get_first_node_in_group("buyer")
	if buyer == null:
		print("    (nenhum comprador sorteado, pulei a entrega)")
		return
	var zone: Area3D = buyer.get_node("CarZone")
	car.global_position = zone.global_position + Vector3(0.0, 0.4, 0.0)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	for i in range(40):
		await get_tree().physics_frame
	player.exit_vehicle()
	await get_tree().physics_frame
	# De longe: da pra ACHAR a casa da entrega na rua?
	await _stand(buyer.global_position + Vector3(0, 1.0, 0),
		(car.global_position - buyer.global_position).normalized(), 14.0)
	await _shot("06_chegando_na_entrega")
	await _stand(buyer.global_position + Vector3(0, 1.0, 0),
		(car.global_position - buyer.global_position).normalized(), 2.5)
	await _shot("07_cliente_de_perto")

	# ------------------------------------------------- 6. minigame de labia
	if buyer.has_method("interact"):
		buyer.interact(player)
		for i in range(90):
			await get_tree().physics_frame
		await _shot("08_barra_de_labia")
