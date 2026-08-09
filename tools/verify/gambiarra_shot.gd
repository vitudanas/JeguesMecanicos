extends Node
## FOTO da gambiarra COM O CARRO ANDANDO.
##
## O `drive_test` mede que a peca fica a 0,00 m da ancora em movimento. Isso nao
## responde se ela PARECE presa na tela — que e como o defeito foi reportado
## ("as gambiarras descolam e ficam flutuando quando comeco a dirigir").
##
##   godot --path . tools/verify/gambiarra_shot.tscn

const OUT_DIR := "user://gambiarra_shots"

var town: Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	town = (load("res://scenes/world/Town.tscn") as PackedScene).instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().physics_frame
	await _run()
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

func _shot(nome: String) -> void:
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, nome])
	print("  foto: %s" % nome)

func _run() -> void:
	var car: RigidBody3D = (load("res://scenes/vehicle/Vehicle.tscn") as PackedScene).instantiate()
	car.is_wrecked = false
	car.car_model = load("res://assets/quaternius/cars/car-a.glb")
	town.add_child(car)
	car.global_position = Vector3(-40.0, 0.5, 1.5)
	car.rotation.y = deg_to_rad(-90.0)
	car.set_physics_process(false)
	for k: String in car.parts:
		car.parts[k] = 1.0
	for i in range(40):
		await get_tree().physics_frame

	for spot: Area3D in car.get_node("AttachPoints").get_children():
		if spot.part_scene == null:
			continue
		var part: Node = spot.part_scene.instantiate()
		town.add_child(part)
		car.install_part(spot.point_name, part, spot)
		# Some com a esfera de mira, como o `AttachSpot.interact()` faz no jogo.
		# Sem isso a foto sai cheia de bola colorida e nao mostra a gambiarra.
		spot.get_node("Marker").visible = false
	await get_tree().physics_frame

	# Quem arrancou a peca? Se ela some so de dirigir em linha reta, e defeito;
	# se some ao bater/pegar buraco, e o jogo funcionando.
	car.part_broken.connect(func(nome: String) -> void:
		print("        ARRANCOU %s a %.0f km/h" % [nome, car.linear_velocity.length() * 3.6]))
	car.body_entered.connect(func(b: Node) -> void:
		print("        BATEU em %s a %.0f km/h" % [b.name, car.linear_velocity.length() * 3.6]))

	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.make_current()

	var dt := get_physics_process_delta_time()
	for etapa: Array in [["01_parado", 0], ["02_acelerando", 90], ["03_a_toda", 180]]:
		for i in range(int(etapa[1])):
			car.throttle_input = 1.0
			car.steer_input = 0.0
			car._apply_suspension_and_drive(dt)
			car._update_visual(dt)
			await get_tree().physics_frame
		# Camera de lado, mostrando capo/retrovisor, acompanhando o carro.
		var p: Vector3 = car.global_position
		# 3/4 pela frente: pega capo, radiador e retrovisor no mesmo quadro — e
		# a vista em que uma peca solta apareceria na hora.
		cam.global_position = p + car.global_transform.basis.x * 3.4 \
			- car.global_transform.basis.z * 4.2 + Vector3(0.0, 1.5, 0.0)
		cam.look_at(p + Vector3(0.0, 0.5, 0.0), Vector3.UP)
		print("    %s: %.0f km/h" % [etapa[0], car.linear_velocity.length() * 3.6])
		# Mede junto com a foto: assim da pra dizer se o que aparece boiando na
		# imagem e gambiarra ou cenario.
		for nome: String in car.installed_parts:
			var peca: Node3D = car.installed_parts[nome]
			var anc: Node3D = car.part_anchors_node.get_node_or_null(nome)
			if peca == null or anc == null:
				continue
			print("        %-9s a %.3f m da ancora | visivel=%s | mundo %s" % [
				nome, peca.global_position.distance_to(anc.global_position),
				peca.visible, peca.global_position])
		await _shot(str(etapa[0]))
