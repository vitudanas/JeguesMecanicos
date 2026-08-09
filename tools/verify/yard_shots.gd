extends Node
## FOTO do patio: as vagas pintadas e o mecanico.
##
## Os numeros do `staff_test` provam que o limite existe e que o mecanico troca
## a peca. Nao respondem a pergunta que so a tela responde: DA PRA VER quantas
## vagas o patio tem, e da pra ver que tem alguem trabalhando? Comprar o
## upgrade do patio nao muda numero nenhum no HUD — se a laje nao mudar de cara,
## o jogador paga R$ 2600 e nao ve nada acontecer.
##
## Precisa de janela de verdade (headless nao rasteriza):
##   godot --path . tools/verify/yard_shots.tscn

const OUT_DIR := "user://yard_shots"

var main: Node
var player: CharacterBody3D
var workshop: Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	Dealership.reset()
	Staff.reset()
	GameManager.reset()
	GameManager.money = 100000
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	player = get_tree().get_first_node_in_group("player")
	workshop = get_tree().get_first_node_in_group("workshop")
	await _run()
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

func _shot(nome: String) -> void:
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, nome])
	print("  foto: %s" % nome)

func _ground_at(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, p.y + 12.0, p.z), Vector3(p.x, p.y - 24.0, p.z))
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else 0.0

## Poe o jogador de pe olhando pro alvo, de onde ele chegaria andando.
func _stand(target: Vector3, from: Vector3) -> void:
	var chao := _ground_at(from)
	player.global_position = Vector3(from.x, chao + 0.1, from.z)
	var cam: Camera3D = player.get_node("Head/Camera3D")
	cam.current = true
	var para: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-para.x, -para.z)
	cam.rotation.x = atan2(para.y, Vector2(para.x, para.z).length())
	player.force_update_transform()
	cam.force_update_transform()

func _park(offset: Vector3) -> Node:
	var car: RigidBody3D = (load("res://scenes/vehicle/Vehicle.tscn") as PackedScene).instantiate()
	car.car_model = load("res://assets/quaternius/cars/car-a.glb")
	car.is_wrecked = true
	main.get_node("Town").add_child(car)
	car.global_position = workshop.get_drop_position() + offset
	car.owned = true
	for i in range(8):
		await get_tree().physics_frame
	return car

func _run() -> void:
	var centro: Vector3 = (workshop as Node3D).to_global(Vector3(0.0, 0.4, 2.2))
	# De onde o jogador chega: pelo portao, ao sul.
	var portao: Vector3 = (workshop as Node3D).to_global(Vector3(0.0, 1.6, 13.0))
	var lado: Vector3 = (workshop as Node3D).to_global(Vector3(-11.0, 1.6, 9.0))

	print("[1] patio nivel 1 — uma vaga pintada")
	_stand(centro, portao)
	await _shot("01_patio_nv1_do_portao")
	_stand(centro, lado)
	await _shot("02_patio_nv1_de_lado")

	print("[2] patio nivel 3 — quatro vagas")
	Dealership.buy("patio")
	Dealership.buy("patio")
	await get_tree().process_frame
	print("    vagas: %d" % workshop.slots())
	_stand(centro, portao)
	await _shot("03_patio_nv3_do_portao")
	_stand(centro, lado)
	await _shot("04_patio_nv3_de_lado")

	print("[3] com carros nas vagas")
	var carros: Array[Node] = []
	for bay: Vector2 in workshop.bays():
		var alvo: Vector3 = (workshop as Node3D).to_global(Vector3(bay.x, 1.0, bay.y))
		var c := await _park(alvo - workshop.get_drop_position())
		carros.append(c)
	_stand(centro, portao)
	await _shot("05_quatro_carros")

	print("[4] o mecanico contratado, trabalhando")
	Dealership.buy("oficina")
	Dealership.buy("oficina")
	Staff.hire("mecanico")
	var alvo_car: Node = carros[0]
	alvo_car.diagnosed = false
	alvo_car.parts["motor"] = 0.2
	for i in range(90):
		await get_tree().physics_frame
	var mech := get_tree().get_first_node_in_group("mecanico") as Node3D
	if mech:
		print("    mecanico em %s | %s" % [mech.global_position, mech.get_interact_prompt()])
		var de: Vector3 = mech.global_position + Vector3(0.0, 1.6, 6.0)
		_stand(mech.global_position + Vector3(0.0, 1.0, 0.0), de)
		await _shot("06_mecanico_trabalhando")
		_stand(mech.global_position + Vector3(0.0, 1.5, 0.0),
			mech.global_position + Vector3(2.2, 1.7, 2.2))
		await _shot("07_mecanico_perto")

	print("[5] o lote do ferro-velho")
	var lot := get_tree().get_first_node_in_group("junkyard") as Node3D
	if lot:
		_stand(lot.global_position + Vector3(0.0, 1.0, 0.0),
			lot.global_position + Vector3(2.0, 1.7, 14.0))
		await _shot("08_lote_ferro_velho")
