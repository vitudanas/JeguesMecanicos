extends Node
## FOTO das telas de menu, partindo do MainMenu de verdade.
##
## Existe porque a tela de configuracao e montada 100% EM CODIGO (ela nao tem
## .tscn de proposito — ver 2026-08-04) e ja falhou de um jeito que nenhum teste
## numerico pegou: montava os 9 controles certinho e renderizava INVISIVEL,
## medindo 0x0, porque `set_anchors_preset` nao preenche o retangulo. Menu
## montado em codigo tem que ser OLHADO.
##
## Tambem confere o tamanho medido de cada tela — se voltar a dar 0x0, falha
## alto em vez de render uma foto preta que alguem precisa reparar.
##
##   godot --path . tools/verify/ui_shot.tscn

const OUT_DIR := "user://ui_shots"

var problems: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for i in range(20):
		await get_tree().process_frame
	await _shot("01_menu_principal")
	_check_size("menu principal", menu as Control)

	# Abre a tela de configuracao pelo caminho real (o botao), nao instanciando
	# a classe na mao: assim a foto prova o fluxo que o jogador percorre.
	menu.get_node("VBox/SettingsButton").emit_signal("pressed")
	for i in range(25):
		await get_tree().process_frame
	await _shot("02_configuracoes")

	var settings: Control = null
	for c in menu.get_children():
		if c is Control and c.get_script() != null and c.has_signal("back_pressed"):
			settings = c
			break
	if settings == null:
		problems.append("a tela de configuracao nao abriu pelo botao")
	else:
		_check_size("configuracoes", settings)
		var sliders := settings.find_children("*", "HSlider", true, false)
		print("  sliders de volume: %d" % sliders.size())
		if sliders.size() != 3:
			problems.append("esperava 3 sliders de volume, achei %d" % sliders.size())
		# Rola ate o fim, que e onde a secao de Som ficou.
		for scroll in settings.find_children("*", "ScrollContainer", true, false):
			(scroll as ScrollContainer).scroll_vertical = 100000
		for i in range(12):
			await get_tree().process_frame
		await _shot("03_configuracoes_som")
		settings.emit_signal("back_pressed")
		for i in range(6):
			await get_tree().process_frame

	# CREDITOS. Os modelos de terceiro sao CC-BY: sem esta tela o jogo esta fora
	# da licenca, entao ela e cobrada como qualquer outra mecanica — que abre
	# pelo botao, que APARECE (ja tivemos tela montada e invisivel) e que lista
	# os creditos de verdade, e nao uma lista vazia.
	var botao_creditos: Button = null
	for c in menu.get_node("VBox").get_children():
		if c is Button and (c as Button).text.begins_with("Cr"):
			botao_creditos = c as Button
			break
	if botao_creditos == null:
		problems.append("o menu principal nao tem botao de Creditos")
	else:
		botao_creditos.emit_signal("pressed")
		for i in range(25):
			await get_tree().process_frame
		await _shot("06_creditos")
		var creditos: Control = null
		for c in menu.get_children():
			if c is Control and c.get_script() != null and c.has_signal("back_pressed"):
				creditos = c
				break
		if creditos == null:
			problems.append("a tela de creditos nao abriu pelo botao")
		else:
			_check_size("creditos", creditos)
			var nomes := 0
			for label in creditos.find_children("*", "Label", true, false):
				if (label as Label).text.contains("—"):
					nomes += 1
			print("  linhas de credito: %d" % nomes)
			# 51 modelos CC-BY + os pacotes CC0 + o motor. Bem abaixo disso, a
			# lista nao foi gerada ou o carregamento falhou — e credito que nao
			# aparece e o mesmo que credito nenhum.
			if nomes < 40:
				problems.append("so %d linha(s) de credito na tela" % nomes)

	menu.queue_free()
	await get_tree().process_frame

	# ---------------------------------------- menu com progresso salvo
	# Grava um save de mentira so pra foto, e devolve o estado no fim: a partida
	# do usuario nao pode ser vitima do roteiro de fotos.
	var tinha := SaveGame.has_save
	GameManager.money = 1240
	GameManager.cars_sold = 4
	SaveGame.save()
	var menu3 := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu3)
	for i in range(20):
		await get_tree().process_frame
	await _shot("04_menu_com_continuar")

	# ------------------------------------------- tela de carregamento
	# Fotografada NO MEIO do carregamento: quando ele termina, a tela troca de
	# cena e leva este roteiro junto. Por isso e a ultima foto.
	menu3.get_node("VBox/PlayButton").emit_signal("pressed")
	for i in range(6):
		await get_tree().process_frame
	await _shot("05_carregando")
	if not tinha:
		SaveGame.clear()

	print("")
	if problems.is_empty():
		print("=== RESULTADO ===")
		print("menus renderizam com tamanho de verdade")
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0 if problems.is_empty() else 1)

func _check_size(label: String, node: Control) -> void:
	var s := node.size
	print("  %s: %.0f x %.0f" % [label, s.x, s.y])
	if s.x < 100.0 or s.y < 100.0:
		problems.append("%s renderizou com tamanho %.0fx%.0f (invisivel)" % [label, s.x, s.y])

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("  foto: %s" % shot_name)
