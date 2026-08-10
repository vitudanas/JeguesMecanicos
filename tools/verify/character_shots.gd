extends Node
## FOTOS do personagem e da tela que o monta.
##
## O `character_test` prova que o numero chega na malha; ele nao prova que o
## resultado se parece com gente. Este projeto ja perdeu rodadas inteiras
## ajustando numero de um defeito que so existia na tela (as ventas do jegue
## lendo como um segundo par de olhos, a crina virando colar de contas), entao
## personagem se OLHA.
##
## Duas perguntas que so a foto responde nesta rodada:
##   1. o cranio do jegue — calibrado no modelo FEMININO — engole tambem a
##      cabeca do MASCULINO? (a medida numerica acusa 4,7 cm de exposicao no
##      homem contra 2,2 cm na mulher, e ela erra no centimetro de proposito);
##   2. as pontas dos sliders ainda leem como corpo, e nao como deformidade.
##
## As fotos 90-93 pintam o corpo humano de MAGENTA e deixam a cabeca de jegue
## normal: qualquer pedaco de cabeca humana escapando aparece berrante. E a
## mesma tecnica que resolveu o retalho do ombro dos NPCs em 2026-08-03.
##
## Precisa de janela de verdade (headless nao rasteriza):
##   godot --path . tools/verify/character_shots.tscn

const OUT_DIR := "user://character_shots"
const CHARACTER_MENU := preload("res://scenes/ui/CharacterMenu.gd")

var _stage: Node3D = null
var _camera: Camera3D = null
var _body: Node3D = null
var _saved: Dictionary = {}
var problems: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_saved = _snapshot()
	_build_stage()
	await _shots_bodies()
	await _shots_shapes()
	await _shots_proof()
	await _shots_ui()
	_restore()

	print("")
	if problems.is_empty():
		print("=== RESULTADO ===\npersonagem fotografado; OLHE as fotos 90-93 (prova magenta)")
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0 if problems.is_empty() else 1)

# ------------------------------------------------------------------- palco

func _build_stage() -> void:
	_stage = Node3D.new()
	add_child(_stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.60, 0.72)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_stage.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 38, 0)
	key.light_energy = 1.6
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -125, 0)
	fill.light_energy = 0.6
	_stage.add_child(fill)

	_camera = Camera3D.new()
	_camera.fov = 34.0
	_camera.current = true
	_stage.add_child(_camera)

func _mount() -> void:
	if _body and is_instance_valid(_body):
		_stage.remove_child(_body)
		_body.queue_free()
	_body = PlayerVisual.build(_stage)
	_body.rotation_degrees.y = 0.0   # encarando a camera, que fica no +Z

## Enquadra o boneco. `top` e `bottom` sao fracoes da altura (0 = pe, 1 = topo),
## entao o mesmo pedido serve pra qualquer altura escolhida — enquadrar por
## distancia fixa cortava a cabeca do personagem alto.
func _frame(angle_deg: float, bottom: float, top: float) -> void:
	var height: float = Appearance.height
	var span: float = maxf((top - bottom) * height, 0.25)
	var center := Vector3(0.0, (bottom + top) * 0.5 * height, 0.0)
	var distance: float = span / (2.0 * tan(deg_to_rad(_camera.fov * 0.5))) * 1.25
	var a := deg_to_rad(angle_deg)
	_camera.position = center + Vector3(sin(a), 0.0, cos(a)) * distance
	_camera.look_at(center, Vector3.UP)

# ------------------------------------------------------------------- fotos

func _shots_bodies() -> void:
	print("\n[corpos]")
	var index := 1
	for model: Dictionary in Appearance.models():
		for donkey: bool in [true, false]:
			Appearance.reset()
			Appearance.set_model(str(model["id"]))
			Appearance.set_donkey_head(donkey)
			_mount()
			var tag: String = "%s_%s" % [model["id"], "jegue" if donkey else "humana"]
			for view: Array in [[0.0, "frente"], [90.0, "perfil"], [180.0, "costas"]]:
				_frame(float(view[0]), -0.02, 1.06)
				await _shot("%02d_%s_%s" % [index, tag, view[1]])
				index += 1
			if donkey:
				# Close na cabeca: e o unico enquadramento em que da pra julgar
				# se o cranio engole a cabeca humana.
				for view: Array in [[0.0, "cabeca_frente"], [55.0, "cabeca_tres_quartos"]]:
					_frame(float(view[0]), 0.70, 1.13)
					await _shot("%02d_%s_%s" % [index, tag, view[1]])
					index += 1

func _shots_shapes() -> void:
	print("\n[pontas dos sliders]")
	var index := 40
	for model: Dictionary in Appearance.models():
		var model_id := str(model["id"])
		for entry: Dictionary in Appearance.SHAPES:
			Appearance.reset()
			Appearance.set_model(model_id)
			Appearance.set_donkey_head(false)
			# `shape_applies` depende do modelo ATUAL, entao so pode ser
			# perguntado depois do `set_model` — perguntado antes, a mulher
			# ganharia foto de peitoral e o homem de busto.
			if not Appearance.shape_applies(entry):
				continue
			var shape_id := str(entry["id"])
			for shape: Dictionary in Appearance.SHAPES:
				Appearance.shapes[str(shape["id"])] = 0.0
			Appearance.shapes[shape_id] = 1.0
			_mount()
			# De 3/4: de frente o gluteo nao aparece e de perfil o busto some.
			_frame(35.0, -0.02, 1.06)
			await _shot("%d_%s_%s_max" % [index, model_id, shape_id.to_lower()])
			index += 1

	# As duas pontas da altura lado a lado com o mesmo enquadramento relativo:
	# e assim que da pra ver se 1,60 m ainda le como adulto.
	for wanted: float in [Appearance.HEIGHT_MIN, Appearance.HEIGHT_MAX]:
		Appearance.reset()
		Appearance.set_height(wanted)
		_mount()
		_frame(0.0, -0.02, 1.06)
		await _shot("%d_altura_%dcm" % [index, int(round(wanted * 100.0))])
		index += 1

## Prova magenta: o corpo humano fica de cor chapada e a cabeca de jegue fica
## como esta. Qualquer pedaco de cabeca humana escapando aparece berrante.
func _shots_proof() -> void:
	print("\n[prova magenta]")
	var index := 90
	for model: Dictionary in Appearance.models():
		Appearance.reset()
		Appearance.set_model(str(model["id"]))
		Appearance.set_donkey_head(true)
		_mount()
		_paint_body_magenta(_body)
		for view: Array in [[0.0, "frente"], [70.0, "tres_quartos"]]:
			_frame(float(view[0]), 0.80, 1.07)
			await _shot("%d_prova_%s_%s" % [index, model["id"], view[1]])
			index += 1

func _paint_body_magenta(root: Node) -> void:
	for mi in _all_meshes(root):
		if _under(mi, "CabecaDeJegue"):
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.0, 0.85)
		mat.roughness = 1.0
		mi.material_override = mat

func _shots_ui() -> void:
	print("\n[tela]")
	Appearance.reset()
	# O palco 3D sai da frente: a tela de personagem tem preview PROPRIO, e o
	# boneco do palco apareceria por tras dela nas fotos.
	_stage.visible = false
	_camera.current = false
	# Pelo caminho real: abre o menu principal e aperta o botao, em vez de
	# instanciar a tela na mao — assim a foto tambem prova que o botao liga na
	# tela certa.
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for i in range(20):
		await get_tree().process_frame
	var button := _find_button(menu, "Personagem")
	if button == null:
		problems.append("o menu principal nao tem botao 'Personagem'")
		menu.queue_free()
		return
	button.emit_signal("pressed")
	for i in range(30):
		await get_tree().process_frame
	var screen: Control = null
	for c in menu.get_children():
		if c is Control and c.get_script() == CHARACTER_MENU:
			screen = c as Control
	if screen == null:
		problems.append("o botao 'Personagem' nao abriu a tela")
		menu.queue_free()
		return
	print("  tela de personagem: %.0f x %.0f" % [screen.size.x, screen.size.y])
	if screen.size.x < 100.0 or screen.size.y < 100.0:
		problems.append("a tela de personagem renderizou invisivel (%.0fx%.0f)"
			% [screen.size.x, screen.size.y])
	await _shot("95_tela_personagem")

	# Com o homem escolhido, pra provar na foto que os controles trocam.
	var picker := screen.get("_model_picker") as OptionButton
	if picker:
		picker.select(1)
		picker.item_selected.emit(1)
		for i in range(20):
			await get_tree().process_frame
		await _shot("96_tela_personagem_homem")
	menu.queue_free()
	await get_tree().process_frame

func _find_button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b as Button
	return null

# --------------------------------------------------------------- utilidade

func _shot(shot_name: String) -> void:
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("  foto: %s" % shot_name)

func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out

func _under(node: Node, ancestor_name: String) -> bool:
	var n := node.get_parent()
	while n != null:
		if n.name == ancestor_name:
			return true
		n = n.get_parent()
	return false

func _snapshot() -> Dictionary:
	return {"model_id": Appearance.model_id, "donkey_head": Appearance.donkey_head,
		"height": Appearance.height, "shapes": Appearance.shapes.duplicate(),
		"skin": Appearance.skin, "cloth": Appearance.cloth, "hair": Appearance.hair}

func _restore() -> void:
	Appearance.model_id = str(_saved["model_id"])
	Appearance.donkey_head = bool(_saved["donkey_head"])
	Appearance.height = float(_saved["height"])
	Appearance.shapes = (_saved["shapes"] as Dictionary).duplicate()
	Appearance.skin = int(_saved["skin"])
	Appearance.cloth = int(_saved["cloth"])
	Appearance.hair = int(_saved["hair"])
	Appearance.save_settings()
