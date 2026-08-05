extends Node
## Prova que o menu de graficos FAZ alguma coisa.
##
## Um menu de opcoes e o tipo de tela que passa em qualquer teste de "abre sem
## erro" e mesmo assim nao mexe em nada — os controles existem, salvam no disco
## e o jogo continua identico. Aqui cada preset e aplicado no `Main.tscn` de
## verdade e o custo do quadro e MEDIDO.
##
## Mede chamadas de desenho e primitivas, nao milissegundos: tempo de quadro
## medido numa janela fora de foco no macOS sai sem relacao nenhuma com o
## conteudo (com a grama desligada o quadro saiu mais LENTO — ver changelog).
##
## Precisa de janela de verdade (headless nao rasteriza):
##   godot --path . tools/verify/settings_test.tscn

const OUT_DIR := "user://quality_shots"

var problems: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	# `current_scene` continua sendo esta cena de teste (o Main entra como filho
	# dela, e `set_current_scene` so aceita filho direto da raiz). Nao ha
	# problema: `GraphicsSettings.apply()` procura o WorldEnvironment e o sol
	# percorrendo a arvore a partir dai, e o Main esta dentro.
	await get_tree().process_frame
	await get_tree().physics_frame

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 3000.0
	add_child(cam)
	# Ponto fixo com cidade E campo no quadro: e onde os dois sistemas caros
	# (grama e vitrine) aparecem juntos.
	var eye := Vector3(-150.0, 2.2, 40.0)
	if player:
		player.global_position = Vector3(eye.x, 0.1, eye.z)
		player.force_update_transform()
	cam.global_position = eye
	cam.look_at(Vector3(40.0, 6.0, 40.0), Vector3.UP)
	cam.make_current()

	var before: String = GraphicsSettings.preset
	if not GraphicsSettings.PRESETS.has(before):
		before = "alta"
	var results: Array = []
	for preset: String in GraphicsSettings.PRESET_ORDER:
		GraphicsSettings.use_preset(preset)
		# O campo de grama so re-espalha no `_process` seguinte, e a mudanca de
		# escala de render leva alguns quadros pra assentar.
		for i in range(40):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var row := {
			"preset": preset,
			"calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"escala": get_viewport().scaling_3d_scale,
			"grama": _grass_instances(),
			"sombra": _sun_shadow(),
			"ssao": _env_flag("ssao_enabled"),
			"ssil": _env_flag("ssil_enabled"),
		}
		results.append(row)
		print("%-6s  %5d chamadas  %8d primitivas  escala %.2f  grama %6d  sombra %s  ssao %s  ssil %s" % [
			preset, row["calls"], row["prims"], row["escala"], row["grama"],
			row["sombra"], row["ssao"], row["ssil"]])
		get_viewport().get_texture().get_image().save_png("%s/preset_%s.png" % [OUT_DIR, preset])

	# Devolve o que o jogador tinha: o teste grava em `user://graphics.cfg`, o
	# mesmo arquivo do jogo, e sem isto rodar a verificacao mudava a
	# configuracao de quem esta jogando nesta maquina.
	GraphicsSettings.use_preset(before)

	_check(results)

	if problems.is_empty():
		print("\nnenhum problema encontrado")
		get_tree().quit(0)
	else:
		print("\n%d PROBLEMA(S):" % problems.size())
		for p in problems:
			print("  - %s" % p)
		get_tree().quit(1)

func _check(results: Array) -> void:
	if results.size() != GraphicsSettings.PRESET_ORDER.size():
		problems.append("faltou medir preset")
		return
	# Duas cobrancas diferentes, porque os degraus nao sao todos da mesma
	# natureza — descobri isso reprovando um preset que estava certo:
	#
	#  * GEOMETRIA (primitivas) nunca pode SUBIR ao descer de preset. Ela nao
	#    precisa cair em todo degrau: de 'alta' pra 'ultra' so muda custo POR
	#    PIXEL (escala de render, SSIL, TAA), e isso nao aparece em primitiva
	#    nenhuma. Cobrar queda ali reprovava um menu que funciona.
	#  * ALGUMA COISA tem que mudar entre dois presets vizinhos. E essa a
	#    checagem que pega o controle que nao faz nada.
	var watched := ["escala", "grama", "sombra", "ssao", "ssil"]
	for i in range(1, results.size()):
		var lo: Dictionary = results[i - 1]
		var hi: Dictionary = results[i]
		if lo["prims"] > int(hi["prims"] * 1.02):
			problems.append("preset '%s' desenha MAIS geometria que '%s' (%d contra %d)" % [
				lo["preset"], hi["preset"], lo["prims"], hi["prims"]])
		var differs := false
		for key: String in watched:
			if lo[key] != hi[key]:
				differs = true
				break
		if not differs:
			problems.append("presets '%s' e '%s' aplicam exatamente a mesma coisa" % [
				lo["preset"], hi["preset"]])
	var baixa: Dictionary = results[0]
	var ultra: Dictionary = results[-1]
	if baixa["grama"] != 0:
		problems.append("preset 'baixa' deveria zerar a grama, tem %d tufos" % baixa["grama"])
	if ultra["grama"] <= 0:
		problems.append("preset 'ultra' esta sem grama nenhuma")
	if baixa["sombra"]:
		problems.append("preset 'baixa' deveria desligar a sombra do sol")
	if not ultra["ssil"]:
		problems.append("preset 'ultra' deveria ligar SSIL")
	if baixa["escala"] >= ultra["escala"]:
		problems.append("escala de render nao cai nos presets baixos")

func _grass_instances() -> int:
	var field := get_tree().get_first_node_in_group("grass_field")
	if field == null:
		problems.append("nao achei o GrassField (grupo 'grass_field')")
		return -1
	var total := 0
	for c in field.get_children():
		if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).multimesh:
			total += (c as MultiMeshInstance3D).multimesh.instance_count
	return total

func _sun_shadow() -> bool:
	var sun := _find(get_tree().current_scene, "DirectionalLight3D") as DirectionalLight3D
	return sun != null and sun.shadow_enabled

func _env_flag(flag: String) -> bool:
	var we := _find(get_tree().current_scene, "WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return false
	return bool(we.environment.get(flag))

func _find(node: Node, type_name: String) -> Node:
	if node == null:
		return null
	if node.is_class(type_name):
		return node
	for c in node.get_children():
		var r := _find(c, type_name)
		if r:
			return r
	return null
