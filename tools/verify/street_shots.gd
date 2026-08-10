extends Node
## FOTOS da rua ao nivel de quem anda nela: mobiliario, travessia, posto,
## lotes especiais e a borda da cidade.
##
## O usuario reportou (2026-08-10) que semaforo, ponto de onibus, faixa de
## pedestre e posto "estao todos fora de escala", e que o entorno da cidade tem
## casas do kit antigo. Numero nenhum resolve isso sozinho: escala se julga
## OLHANDO, e com uma referencia humana no quadro — foi a falta dela que deixou
## os NPCs com 3,76 m por meses (changelog 2026-08-03).
##
## Por isso toda foto sai da altura dos olhos de um adulto (1,70 m) e leva o
## PROPRIO jogador no quadro sempre que possivel.
##
##   godot --path . tools/verify/street_shots.tscn

const OUT_DIR := "user://street_shots"
const OLHO := 1.70

var main: Node
var cam: Camera3D
var player: Node3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in range(30):
		await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player") as Node3D
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 4000.0
	add_child(cam)
	cam.make_current()   # o Town tem camera propria; sem isto a foto sai pelo ponto de vista dela

	await _fotografar_pedestres()
	await _fotografar_mobiliario()
	await _fotografar_travessia()
	await _fotografar_lotes()
	await _fotografar_borda()

	print("\nfotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)

## Poe o jogador no quadro como regua viva: 1,80 m ao lado da peca diz na hora
## se ela esta grande ou pequena demais.
func _por_jogador(em: Vector3) -> void:
	if player == null:
		return
	player.global_position = Vector3(em.x, _chao(em) + 0.1, em.z)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.force_update_transform()
	# 3a pessoa: em 1a o corpo fica so como sombra e nao serve de referencia.
	if player.has_method("toggle_camera_mode") and not bool(player.get("third_person")):
		player.call("toggle_camera_mode")

func _chao(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, p.y + 60.0, p.z), Vector3(p.x, p.y - 60.0, p.z))
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else 0.0

func _olhar(de: Vector3, para: Vector3) -> void:
	cam.global_position = Vector3(de.x, _chao(de) + OLHO, de.z)
	cam.look_at(Vector3(para.x, _chao(para) + 1.2, para.z), Vector3.UP)

## Os pedestres em GRUPO, e nao um a um: o defeito que a variedade existe pra
## resolver ("todo mundo igual") so aparece com varios no mesmo quadro.
func _fotografar_pedestres() -> void:
	print("\n[pedestres]")
	var peds: Array = []
	for n in get_tree().get_nodes_in_group("pedestre"):
		peds.append(n)
	if peds.is_empty():
		for n in main.find_children("*", "RigidBody3D", true, false):
			if n.scene_file_path.ends_with("Pedestrian.tscn"):
				peds.append(n)
	print("  %d pedestres" % peds.size())
	if peds.is_empty():
		return
	# Junta os que estiverem mais perto uns dos outros: e o enquadramento em que
	# da pra comparar um com o outro.
	var alvo := (peds[0] as Node3D).global_position
	var melhor := 0
	var mais_perto := 0
	for i in range(peds.size()):
		var p: Vector3 = (peds[i] as Node3D).global_position
		var n := 0
		for j in range(peds.size()):
			if i != j and p.distance_to((peds[j] as Node3D).global_position) < 26.0:
				n += 1
		if n > mais_perto:
			mais_perto = n
			melhor = i
	alvo = (peds[melhor] as Node3D).global_position
	print("  %d pedestres a menos de 26 m do escolhido" % mais_perto)
	for k in range(2):
		var dir := Vector3(cos(TAU * float(k) / 2.0), 0.0, sin(TAU * float(k) / 2.0))
		_olhar(alvo + dir * 13.0, alvo)
		await _shot("0%d_pedestres" % k)

func _fotografar_mobiliario() -> void:
	print("\n[mobiliario]")
	var props := get_tree().get_nodes_in_group("street_furniture")
	print("  %d pecas de mobiliario na cidade" % props.size())
	# Os tres primeiros de cada tipo, identificados pela silhueta: semaforo e
	# alto e fino, abrigo e largo e baixo.
	var altos: Array[Node3D] = []
	var largos: Array[Node3D] = []
	for p: Node3D in props:
		var box := _aabb(p)
		if box.size.y > 3.0:
			altos.append(p)
		elif box.size.x > 2.5 or box.size.z > 2.5:
			largos.append(p)
	print("  altos (semaforo?): %d | largos (abrigo?): %d" % [altos.size(), largos.size()])
	var i := 1
	for lista: Array in [altos, largos]:
		for k in range(mini(2, lista.size())):
			var p: Node3D = lista[k]
			var pos: Vector3 = p.global_position
			_por_jogador(pos + Vector3(2.2, 0.0, 2.2))
			_olhar(pos + Vector3(7.0, 0.0, 7.0), pos)
			await _shot("%02d_mobiliario" % i)
			i += 1

func _fotografar_travessia() -> void:
	print("\n[travessia]")
	var faixas := get_tree().get_nodes_in_group("via_faixa")
	print("  %d pavimentos de travessia" % faixas.size())
	if faixas.is_empty():
		return
	var f: Node3D = faixas[faixas.size() / 2]
	var pos: Vector3 = f.global_position
	_por_jogador(pos + Vector3(0.0, 0.0, 8.0))
	# De quem vai atravessar (da calcada) e de dentro do carro.
	_olhar(pos + Vector3(0.0, 0.0, 11.0), pos)
	await _shot("10_travessia_da_calcada")
	_olhar(pos + Vector3(16.0, 0.0, 0.0), pos)
	await _shot("11_travessia_da_pista")

func _fotografar_lotes() -> void:
	print("\n[lotes especiais]")
	# Achados pela silhueta: a cobertura do posto e uma laje larga e baixa no
	# meio do quarteirao. Sem grupo nao da pra pedir pelo nome (ver street_test).
	var blocks := _find_by_script(main, "CityBlocks.gd")
	if blocks == null:
		return
	var candidatos: Array[Node3D] = []
	for c in (blocks as Node).get_children():
		if not (c is Node3D):
			continue
		var box := _aabb(c as Node3D)
		if box.size.x > 12.0 and box.size.y < 8.0 and box.size.z > 12.0:
			candidatos.append(c as Node3D)
	print("  %d candidatos a lote especial (largo e baixo)" % candidatos.size())
	for k in range(mini(3, candidatos.size())):
		var p: Node3D = candidatos[k]
		var pos: Vector3 = p.global_position
		_por_jogador(pos + Vector3(9.0, 0.0, 9.0))
		_olhar(pos + Vector3(22.0, 0.0, 22.0), pos)
		await _shot("2%d_lote" % k)

func _fotografar_borda() -> void:
	print("\n[borda da cidade / cinturao]")
	var belt := _find_by_script(main, "CityOutskirts.gd")
	if belt == null:
		return
	var filhos := (belt as Node).get_children()
	print("  %d construcoes no cinturao" % filhos.size())
	if filhos.is_empty():
		return
	# Uma do cinturao, vista de perto e com o jogador: e onde a escala aparece.
	for k in [0, filhos.size() / 3, filhos.size() / 2]:
		var c := filhos[k] as Node3D
		if c == null:
			continue
		var pos: Vector3 = c.global_position
		_por_jogador(pos + Vector3(6.0, 0.0, 6.0))
		_olhar(pos + Vector3(16.0, 0.0, 16.0), pos)
		await _shot("3%d_cinturao" % k)
	# E a transicao vista de fora, com a cidade ao fundo: e a foto que mostra o
	# degrau de altura entre o cinturao e os predios realistas.
	var c0 := filhos[0] as Node3D
	if c0:
		var p: Vector3 = c0.global_position
		var pra_fora := Vector3(signf(p.x), 0.0, signf(p.z)) * 70.0
		_olhar(p + pra_fora + Vector3(0, 22, 0), Vector3(p.x * 0.55, 0.0, p.z * 0.55))
		cam.global_position.y = _chao(p + pra_fora) + 26.0
		cam.look_at(Vector3(p.x * 0.6, 12.0, p.z * 0.6), Vector3.UP)
		await _shot("39_transicao_cidade_campo")

func _shot(nome: String) -> void:
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, nome])
	print("  foto: %s" % nome)

func _find_by_script(root: Node, file_name: String) -> Node:
	var s: Script = root.get_script() as Script
	if s != null and s.resource_path.ends_with(file_name):
		return root
	for c in root.get_children():
		var f := _find_by_script(c, file_name)
		if f:
			return f
	return null

func _aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _all_meshes(root):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var world := mi.global_transform * mi.mesh.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out
