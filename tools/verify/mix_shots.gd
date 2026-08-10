extends Node
## A CIDADE REALISTA: quanto custa e como fica.
##
## A `realistas_sheet` mostra cada predio fatiado ISOLADO, num fundo liso. O que
## ela nao responde e a pergunta que decide se a troca valeu: numa fileira de
## verdade, na altura dos olhos, os modelos lem como UMA cidade — ou como
## pacotes diferentes colados um do lado do outro?
##
## Mede tambem o custo, porque predio de fotogrametria nao e de graca: mais
## triangulo e, principalmente, muito mais textura unica que o kit.
##
## Precisa de janela de verdade (headless nao rasteriza, e sem rasterizar nao ha
## nem foto nem contagem de chamada de desenho):
##   godot --path . tools/verify/mix_shots.tscn

const OUT_DIR := "user://mix_shots"

## Ponto fixo da medicao: no centro, na altura dos olhos, olhando pela rua.
##
## NA PISTA (|x| < 3), e nao na calcada. A calcada vai de 3.0 a 4.5 e a fachada
## fica em 4.6: a primeira versao ficou em x=4.2, ou seja a 40 cm da parede, e as
## fotos sairam com uma unica fachada preenchendo a tela inteira — nao dava pra
## julgar nem o predio nem a rua.
const EYE := Vector3(1.4, 1.7, -60.0)
const LOOK := Vector3(1.4, 20.0, -300.0)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _medir()
	await _street_tour()
	print("\nfotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

## Carrega a cidade inteira como o jogo a carrega e mede.
func _medir() -> void:
	var t0 := Time.get_ticks_msec()
	var town: Node3D = (load("res://scenes/world/Town.tscn") as PackedScene).instantiate()
	add_child(town)
	var load_ms := Time.get_ticks_msec() - t0

	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 3000.0
	add_child(cam)
	cam.global_position = EYE
	cam.look_at(LOOK, Vector3.UP)
	cam.make_current()
	# Alguns quadros pra sombra/oclusao assentarem antes de contar e fotografar.
	for i in range(30):
		await get_tree().process_frame

	var realistas := 0
	var outros := 0
	var tris := 0
	for b in get_tree().get_nodes_in_group("city_building"):
		if str(b.get("visual_scene")).contains("realistas_prontos"):
			realistas += 1
		else:
			outros += 1
		tris += _tri_count(b)

	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("%d predios (%d realistas, %d de outra fonte) | %d tri nos predios" % [
		realistas + outros, realistas, outros, tris])
	print("           carga %d ms | %d chamadas de desenho | %d primitivas na tela" % [
		load_ms, calls, prims])

	await _shoot("medicao")
	cam.queue_free()
	town.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

## Passeio pelas zonas: centro, meio, industrial, borda e campo.
func _street_tour() -> void:
	var town: Node3D = (load("res://scenes/world/Town.tscn") as PackedScene).instantiate()
	add_child(town)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 3000.0
	add_child(cam)
	for i in range(20):
		await get_tree().process_frame

	# Todos na PISTA, olhando pela rua ou em diagonal pra esquina — que e de onde
	# o jogador de fato ve a cidade, a pe ou dirigindo.
	var spots := [
		["centro_rua", Vector3(1.4, 1.7, -60.0), Vector3(1.4, 20.0, -300.0)],
		["centro_esquina", Vector3(-88.5, 1.7, -40.0), Vector3(-60.0, 24.0, -80.0)],
		["meio_rua", Vector3(136.5, 1.7, 60.0), Vector3(136.5, 9.0, -180.0)],
		["meio_esquina", Vector3(-201.0, 1.7, 80.0), Vector3(-175.0, 10.0, 45.0)],
		["industrial", Vector3(248.9, 1.7, -200.0), Vector3(248.9, 8.0, -320.0)],
		["borda", Vector3(-336.0, 1.7, 70.0), Vector3(-336.0, 6.0, -140.0)],
		["dirigindo", Vector3(1.6, 1.2, 150.0), Vector3(1.6, 12.0, -160.0)],
		["de_cima", Vector3(-200.0, 200.0, 270.0), Vector3(20.0, 12.0, -50.0)],
		["rural", Vector3(-450.0, 3.0, 130.0), Vector3(-530.0, 22.0, 250.0)],
	]


	for s: Array in spots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.make_current()
		for i in range(24):
			await get_tree().process_frame
		await _shoot(str(s[0]))

func _shoot(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, nome])
	print("  foto: %s.png" % nome)

func _tri_count(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var m: Mesh = (node as MeshInstance3D).mesh
		for s in range(m.get_surface_count()):
			var arrays := m.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
				total += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			elif arrays.size() > Mesh.ARRAY_VERTEX:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for c in node.get_children():
		total += _tri_count(c)
	return total
