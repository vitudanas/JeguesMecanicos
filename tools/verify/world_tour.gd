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
var problems: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_clear_old_shots()
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
	if problems.is_empty():
		print("=== RESULTADO ===\ntour completo e cameras sem regressao de coordenadas")
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for problem in problems:
			print("  - " + problem)
	get_tree().quit(0 if problems.is_empty() else 1)

func _clear_old_shots() -> void:
	var dir := DirAccess.open(OUT_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension().to_lower() == "png":
			dir.remove(file)

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

func _traffic_nodes() -> Array:
	var traffic: Array = get_tree().get_nodes_in_group("traffic_car")
	if not traffic.is_empty():
		return traffic
	var town := main.get_node("Town")
	for n in town.get_children():
		if String(n.name).begins_with("TrafficRoute"):
			for c in n.get_children():
				for cc in c.get_children():
					if cc is RigidBody3D:
						traffic.append(cc)
	return traffic

func _street_life_shot(shot_name: String, outer: bool) -> void:
	var traffic := _traffic_nodes()
	if traffic.is_empty():
		problems.append("%s sem trafego para enquadrar" % shot_name)
		return
	var chosen: Node3D = traffic[0]
	var chosen_radius := maxf(absf(chosen.global_position.x), absf(chosen.global_position.z))
	for candidate: Node3D in traffic:
		var radius := maxf(absf(candidate.global_position.x), absf(candidate.global_position.z))
		if (outer and radius > chosen_radius) or (not outer and radius < chosen_radius):
			chosen = candidate
			chosen_radius = radius
	# Camera atras do carro NO EIXO da rua. O antigo deslocamento diagonal podia
	# atravessar a fachada da esquina mesmo com o carro corretamente na pista.
	var forward := -chosen.global_basis.z.normalized()
	_look(chosen.global_position - forward * 12.0 + Vector3.UP * 3.2,
		chosen.global_position + forward * 7.0 + Vector3.UP * 1.1)
	await _shot(shot_name)

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
	await _street_life_shot("03_rua_centro", false)
	_look(Vector3(-90, 2.0, 260), Vector3(-90, 4.0, 130))
	await _shot("04_avenida")
	_look(Vector3(90, 2.0, 90), Vector3(25, 6.0, 25))
	await _shot("05_cruzamento")
	await _street_life_shot("06_periferia", true)

	# ------------------------------------------------------ quem esta na rua
	var traffic: Array = _traffic_nodes()
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
		var p: Node3D
		for candidate: Node3D in peds:
			if candidate.has_method("is_ragdolled") \
					and not candidate.is_ragdolled() \
					and candidate.has_method("locomotion_kind") \
					and candidate.locomotion_kind() == "animation":
				p = candidate
				break
		if p == null:
			problems.append("nenhum pedestre animado e em pe para fotografar")
			return
		var ped_scene: PackedScene = p.get("character_model")
		print("  NPC fotografado: %s" % (ped_scene.resource_path if ped_scene else "?"))
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
	# Distancia e alvo baixo deixam a silhueta inteira no quadro, em vez de
	# fotografar o ceu e cortar o cume da montanha mais proxima.
	var mountain_from := Vector3(-500, 58, 110)
	var mountain_at := Vector3(-930, 72, 40)
	if Vector2(mountain_at.x, mountain_at.z).length() < 700.0:
		problems.append("camera 16 ainda aponta para dentro da cidade")
	_look(mountain_from, mountain_at)
	await _shot("16_cordilheira")
	var transition_from := Vector3(610, 42, 270)
	var transition_at := Vector3(250, 12, 80)
	if Vector2(transition_from.x, transition_from.z).length() < 450.0 \
			or Vector2(transition_at.x, transition_at.z).length() > 360.0:
		problems.append("camera 17 nao atravessa campo e cidade")
	_look(transition_from, transition_at)
	await _shot("17_transicao_campo_cidade")
