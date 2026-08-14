extends Node
## TOUR visual do mundo inteiro, renderizado do proprio jogo.
##
## Carrega o Town de verdade (com transito, pedestres, clima e entrega ativos) e
## fotografa de varios pontos: mapa inteiro, cidade de cima e no nivel da rua,
## lotes especiais, anel rural, cordilheira, oficina, ferro-velho e a entrega.
##
## Precisa de janela de verdade (headless nao rasteriza):
##   godot --path . tools/verify/world_tour.tscn

const OUT_DIR := "user://world_tour"

var main: Node
var cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	# Camera propria. O Town ja tem camera (a do jogador): sem `make_current()`
	# a foto sai pelo ponto de vista DELA e o roteiro inteiro vira lixo — erro
	# que ja custou uma rodada de fotos neste projeto.
	cam = Camera3D.new()
	cam.fov = 65.0
	cam.far = 3000.0
	add_child(cam)
	cam.make_current()
	# Deixa o mundo viver um pouco: transito anda, pedestres saem da pose
	# inicial, o DeliveryManager sorteia a casa da entrega.
	for i in range(120):
		await get_tree().physics_frame
	await _run()
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.force_update_transform()

func _shot(shot_name: String) -> void:
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("  foto: %s" % shot_name)

func _find(node_name: String) -> Node3D:
	var town := main.get_node_or_null("Town")
	if town == null:
		return null
	return town.get_node_or_null(node_name) as Node3D

func _run() -> void:
	var town := main.get_node("Town")

	# ------------------------------------------------------------- o mapa todo
	_look(Vector3(340, 300, 340), Vector3(-30, 0, 0))
	await _shot("01_mapa_inteiro")
	_look(Vector3(0, 420, 430), Vector3(0, 0, 0))
	await _shot("02_cidade_de_cima")

	# ------------------------------------------------------ cidade no chao
	# Cruzamentos reais da grade atual (9 ruas por eixo, espacadas 90 m,
	# de -360 a +360).
	# As coordenadas antigas cobriam apenas o miolo do primeiro prototipo e
	# deixavam a maior parte da cidade nova fora da revisao visual.
	_look(Vector3(0, 2.0, 300), Vector3(0, 3.0, 180))
	await _shot("03_rua_centro")
	_look(Vector3(-90, 2.0, 260), Vector3(-90, 4.0, 130))
	await _shot("04_avenida")
	_look(Vector3(90, 2.0, 90), Vector3(25, 6.0, 25))
	await _shot("05_cruzamento")
	_look(Vector3(360, 1.8, 250), Vector3(270, 4.0, 245))
	await _shot("06_periferia")

	# ------------------------------------------------------ quem esta na rua
	var traffic: Array = get_tree().get_nodes_in_group("traffic_car")
	if traffic.is_empty():
		for n in town.get_children():
			if String(n.name).begins_with("TrafficRoute"):
				for c in n.get_children():
					for cc in c.get_children():
						if cc is RigidBody3D:
							traffic.append(cc)
	if not traffic.is_empty():
		var t: Node3D = traffic[0]
		_look(t.global_position + Vector3(7, 3, 7), t.global_position)
		await _shot("07_transito")
	var peds: Array = get_tree().get_nodes_in_group("pedestrian")
	if peds.is_empty():
		for n in town.get_children():
			if String(n.name).begins_with("PedestrianRoute"):
				for c in n.get_children():
					for cc in c.get_children():
						if cc is RigidBody3D:
							peds.append(cc)
	if not peds.is_empty():
		var p: Node3D = peds[0]
		_look(p.global_position + Vector3(3.5, 1.8, 3.5), p.global_position + Vector3(0, 0.9, 0))
		await _shot("08a_pedestres_passo_1")
		for i in range(18):
			await get_tree().physics_frame
		_look(p.global_position + Vector3(3.5, 1.8, 3.5), p.global_position + Vector3(0, 0.9, 0))
		await _shot("08b_pedestres_passo_2")

	# ------------------------------------------------------ a casa da entrega
	var buyer := get_tree().get_first_node_in_group("buyer")
	if buyer:
		var b: Node3D = buyer
		_look(b.global_position + Vector3(9, 4, 9), b.global_position + Vector3(0, 1, 0))
		await _shot("09_casa_da_entrega")

	# ------------------------------------------------------ oficina e ferro-velho
	var workshop := get_tree().get_first_node_in_group("workshop")
	if workshop:
		var w: Node3D = workshop
		_look(w.global_position + Vector3(22, 12, 24), w.global_position)
		await _shot("10_oficina_de_cima")
		_look(w.global_position + Vector3(2, 2.0, 20), w.global_position + Vector3(0, 2, 0))
		await _shot("11_oficina_no_chao")
	var junk := _find("Junkyard")
	if junk:
		_look(junk.global_position + Vector3(12, 6, 14), junk.global_position)
		await _shot("12_ferro_velho")

	# ------------------------------------------------------ campo e montanha
	for spec: Array in [["Farm1", "13_fazenda"], ["Farm3", "14_fazenda2"],
			["Scrapyard1", "15_ferro_velho_rural"]]:
		var n := _find(spec[0])
		if n:
			_look(n.global_position + Vector3(26, 14, 28), n.global_position)
			await _shot(spec[1])
	_look(Vector3(-140, 6, 190), Vector3(-40, 60, 330))
	await _shot("16_cordilheira")
	_look(Vector3(150, 30, 150), Vector3(0, 8, 0))
	await _shot("17_transicao_campo_cidade")
