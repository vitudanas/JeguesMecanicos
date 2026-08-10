extends Node
## A CIDADE COM PREDIO GERADO: quanto custa e como fica.
##
## O `building_sheet` ja mostra cada tipo gerado ISOLADO, num fundo liso. O que
## ele nao responde e a pergunta que decide o `generated_ratio`: numa fileira de
## verdade, ao lado dos modelos do kit, os dois lem como a mesma cidade? E o
## vao de janela — que e a razao de o gerador existir — sobrevive a ser visto da
## calcada, ou vira um borrao?
##
## Mede tambem o CUSTO, porque a alternativa nao e de graca: cada predio do kit
## e uma instancia de um modelo ja carregado, e cada predio gerado e malha nova.
##
## Precisa de janela de verdade (headless nao rasteriza, e sem rasterizar nao ha
## nem foto nem contagem de chamada de desenho):
##   godot --path . tools/verify/mix_shots.tscn

const OUT_DIR := "user://mix_shots"

## Onde a foto de comparacao e tirada, igual pra todas as taxas: no miolo, na
## altura dos olhos, olhando pela rua. Ponto fixo de proposito — custo medido em
## lugares diferentes nao compara nada.
##
## NA PISTA (|x| < 3), e nao na calcada. A calcada vai de 3.0 a 4.5 e a fachada
## fica em 4.6: a primeira versao ficou em x=4.2, ou seja a 40 cm da parede, e as
## fotos sairam com uma unica fachada preenchendo a tela inteira — nao dava pra
## julgar nem o predio nem a rua.
const EYE := Vector3(1.4, 1.7, -14.0)
const LOOK := Vector3(1.4, 6.0, -120.0)

## RESSALVA HONESTA sobre este A/B: mudar a taxa muda quanto RNG cada lote
## consome, entao as tres cidades NAO sao a mesma cidade com fachadas trocadas —
## sao tres cidades comparaveis. Pro custo agregado isso e indiferente; pra
## aparencia, a foto vale como amostra, nao como diferenca controlada.
const RATIOS: Array[float] = [0.0, 0.62, 1.0]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for r in RATIOS:
		await _measure_ratio(r)
	await _street_tour()
	print("\nfotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

## Carrega a cidade inteira com uma taxa de geracao e mede.
func _measure_ratio(ratio: float) -> void:
	var t0 := Time.get_ticks_msec()
	var town: Node3D = (load("res://scenes/world/Town.tscn") as PackedScene).instantiate()
	var blocks: Node = town.get_node("CityBlocks")
	blocks.set("generated_ratio", ratio)
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

	var gerados := 0
	var kit := 0
	var tris := 0
	for b in get_tree().get_nodes_in_group("city_building"):
		if b.is_in_group("predio_gerado"):
			gerados += 1
		else:
			kit += 1
		tris += _tri_count(b)

	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("taxa %.2f | %d predios (%d gerados, %d do kit) | %d tri nos predios" % [
		ratio, gerados + kit, gerados, kit, tris])
	print("           carga %d ms | %d chamadas de desenho | %d primitivas na tela" % [
		load_ms, calls, prims])

	await _shoot("taxa_%02d" % int(ratio * 100.0))
	cam.queue_free()
	town.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

## Passeio na cidade com a taxa que o jogo usa de verdade (a do Town.tscn), pra
## ver o gerado e o kit na mesma fileira em zonas diferentes.
func _street_tour() -> void:
	var town: Node3D = (load("res://scenes/world/Town.tscn") as PackedScene).instantiate()
	add_child(town)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 3000.0
	add_child(cam)
	for i in range(20):
		await get_tree().process_frame

	# Miolo (torre), anel do meio (comercio) e periferia (casa/galpao) — as tres
	# zonas do `_kinds_for`, pra conferir que o zoneamento vale nos dois caminhos.
	# Todos na PISTA, olhando pela rua ou em diagonal pra esquina — que e de onde
	# o jogador de fato ve a cidade, a pe ou dirigindo.
	var spots := [
		["miolo_rua", Vector3(1.4, 1.7, -14.0), Vector3(1.4, 8.0, -110.0)],
		["miolo_esquina", Vector3(-2.0, 1.7, -30.0), Vector3(14.0, 9.0, -46.0)],
		["meio_rua", Vector3(76.0, 1.7, 44.0), Vector3(76.0, 5.0, -30.0)],
		["meio_esquina", Vector3(-74.0, 1.7, 40.0), Vector3(-58.0, 6.0, 24.0)],
		["periferia", Vector3(151.0, 1.7, 116.0), Vector3(151.0, 4.0, 40.0)],
		["dirigindo", Vector3(1.6, 1.2, 40.0), Vector3(1.6, 3.5, -60.0)],
		["de_cima", Vector3(-60.0, 95.0, 90.0), Vector3(10.0, 6.0, -20.0)],
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
