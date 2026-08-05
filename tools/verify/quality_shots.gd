extends Node
## FOTOS de acabamento: grama na altura dos olhos e fachadas de perto.
##
## Existe porque os dois defeitos desta rodada so aparecem na tela: grama fora
## de escala (numero bate, mas na foto ela passa da cintura do jogador) e
## fachada chapada. Numero nenhum pega isso — a foto pega.
##
## Precisa de janela de verdade (headless nao rasteriza):
##   godot --path . tools/verify/quality_shots.tscn
##
## Cuidados que ja custaram foto errada:
##   - O Town.tscn tem CAMERA PROPRIA: sem make_current() a foto sai pelo ponto
##     de vista dela, nao pelo da camera de debug.
##   - A grama nasce em volta do JOGADOR, nao da camera: mover so a camera
##     fotografa chao pelado. O jogador vai junto.

const OUT_DIR := "user://quality_shots"

var main: Node
var player: Node3D
var cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	player = get_tree().get_first_node_in_group("player")
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 3000.0
	add_child(cam)
	cam.make_current()
	await _run()
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

func _ground_at(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, 200.0, p.z), Vector3(p.x, -20.0, p.z))
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else 0.0

## Camera em `eye` olhando pra `look`. O jogador e teleportado junto (a grama
## nasce em volta DELE), e o mundo ganha alguns frames pra reagir.
func _view(eye: Vector3, look: Vector3, settle := 30) -> void:
	if player:
		player.global_position = Vector3(eye.x, _ground_at(eye) + 0.1, eye.z)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		player.force_update_transform()
	cam.global_position = eye
	cam.look_at(look, Vector3.UP)
	cam.make_current()
	for i in range(settle):
		await get_tree().process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	# Custo junto da foto: grama instanciada e vitrine em toda fachada sao
	# baratas de escrever e caras de desenhar — sem medir, "mais qualidade"
	# vira "menos jogo".
	#
	# CHAMADAS e PRIMITIVAS, nao milissegundos: medir tempo aqui deu numero sem
	# relacao nenhuma com o conteudo (com a grama DESLIGADA o quadro saiu mais
	# LENTO), porque o macOS estrangula a janela que nao esta em foco. Essas
	# duas sao contagem do proprio renderizador e nao dependem disso.
	var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("  foto: %-22s %6d chamadas  %9d primitivas" % [shot_name, int(calls), int(prims)])

func _run() -> void:
	# ------------------------------------------------------------------ grama
	# Campo aberto perto da oficina, na altura dos olhos: e daqui que a grama
	# fora de escala aparece (ao lado do jogador, que mede 1.80).
	var field := Vector3(-160.0, 0.0, 25.0)
	var gy := _ground_at(field)
	await _view(Vector3(field.x, gy + 1.65, field.z), Vector3(field.x + 10.0, gy + 1.2, field.z + 4.0))
	await _shot("grama_01_olhos")

	# Rasante: mostra a altura do tufo contra o horizonte.
	await _view(Vector3(field.x, gy + 0.55, field.z), Vector3(field.x + 14.0, gy + 0.7, field.z + 2.0))
	await _shot("grama_02_rasante")

	# Com o jogador no quadro, que e a referencia de escala que importa.
	if player:
		var eye := Vector3(field.x - 4.0, gy + 1.7, field.z - 3.0)
		player.global_position = Vector3(field.x, _ground_at(field) + 0.1, field.z)
		player.force_update_transform()
		cam.global_position = eye
		cam.look_at(Vector3(field.x, gy + 0.9, field.z), Vector3.UP)
		cam.make_current()
		for i in range(30):
			await get_tree().process_frame
		await _shot("grama_03_com_jogador")

	# ------------------------------------------------------------- construcoes
	# As ruas ficam em multiplos de 37.5 e a fachada a 4.6 do eixo (ver o no
	# CityBlocks em Town.tscn). Todos os pontos abaixo saem dai — camera no
	# meio da pista, olhando pra uma fileira de fachadas.
	var eyes := [
		# olhando a fileira comercial do centro de dentro da rua
		[Vector3(0.0, 1.7, 4.0), Vector3(6.0, 3.5, 30.0), "predio_01_rua"],
		# fachada de perto, na altura da vitrine
		[Vector3(-3.0, 1.7, 18.0), Vector3(5.6, 2.6, 20.0), "predio_02_fachada"],
		# vista alta do centro
		[Vector3(-90.0, 45.0, -90.0), Vector3(10.0, 8.0, 10.0), "predio_03_alto"],
		# bairro de casas, periferia
		[Vector3(-75.0, 1.7, 88.0), Vector3(-40.0, 4.0, 96.0), "predio_04_bairro"],
		# esquina do meio: mistura de torre e comercio
		[Vector3(37.5, 1.8, -34.0), Vector3(43.0, 5.0, -12.0), "predio_05_esquina"],
	]
	for e in eyes:
		await _view(e[0], e[1])
		await _shot(e[2])
