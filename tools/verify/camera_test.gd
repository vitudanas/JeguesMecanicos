extends Node
## As TRES camaras do V (ver Player.Cam) — comportamento e foto.
##
## O que separa as duas de 3a pessoa nao e o enquadramento, e QUEM O MOUSE GIRA.
## Isso nao aparece numa foto parada: as duas mostram o boneco de costas. Por
## isso aqui o mouse e MOVIDO DE VERDADE (`Input.parse_input_event`, o mesmo
## caminho que o jogo le) e o que se mede e se o CORPO girou junto.
##
## Precisa de janela de verdade pras fotos:
##   godot --path . tools/verify/camera_test.tscn

const OUT := "user://camera_shots"

var problems: Array[String] = []
var main: Node
var player: Node3D

func fail(m: String) -> void:
	problems.append(m)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		fail("nao achei o jogador")
		_fim()
		return
	# O mouse precisa estar CAPTURADO: o `_unhandled_input` do jogador ignora
	# movimento fora desse modo, e sem isto o teste mediria zero em tudo e
	# passaria por engano.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _rodar()
	_fim()

func _mover_mouse(dx: float, dy: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().physics_frame

func _rodar() -> void:
	var nomes := ["PRIMEIRA", "TERCEIRA_ATRAS", "TERCEIRA_LIVRE"]

	# 1. O V cicla as tres e volta pra primeira.
	print("=== ciclo do V ===")
	var vistos: Array[int] = [player.camera_mode]
	for i in range(3):
		player.toggle_camera_mode()
		vistos.append(player.camera_mode)
	print("  %s" % str(vistos))
	if vistos != [0, 1, 2, 0]:
		fail("o V nao cicla 1a -> 3a atras -> 3a livre -> 1a (deu %s)" % str(vistos))

	# 2. Em cada modo: o mouse gira o corpo ou nao?
	print("\n=== o mouse gira o CORPO? ===")
	for modo in range(3):
		while player.camera_mode != modo:
			player.toggle_camera_mode()
		await get_tree().physics_frame
		var antes: float = player.rotation.y
		var cam_antes: float = player.get("_free_yaw")
		await _mover_mouse(220.0, 0.0)
		var girou_corpo: float = absf(wrapf(player.rotation.y - antes, -PI, PI))
		var girou_cam: float = absf(wrapf(float(player.get("_free_yaw")) - cam_antes, -PI, PI))
		print("  %-16s corpo girou %5.2f rad | camera livre girou %5.2f rad" % [
			nomes[modo], girou_corpo, girou_cam])
		if modo == 2:
			if girou_corpo > 0.02:
				fail("na camera LIVRE o mouse girou o corpo %.2f rad (devia ser ~0)" % girou_corpo)
			if girou_cam < 0.1:
				fail("na camera LIVRE o mouse nao girou a camera (%.3f rad)" % girou_cam)
		else:
			if girou_corpo < 0.1:
				fail("em %s o mouse devia girar o corpo, girou %.3f rad" % [nomes[modo], girou_corpo])

	# 3. A camera ativa e uma so, e e a do modo.
	print("\n=== camera ativa por modo ===")
	for modo in range(3):
		while player.camera_mode != modo:
			player.toggle_camera_mode()
		await get_tree().process_frame
		var ativas: Array[String] = []
		for c: Camera3D in _cameras(player):
			if c.current:
				ativas.append(c.name)
		print("  %-16s -> %s" % [nomes[modo], str(ativas)])
		if ativas.size() != 1:
			fail("em %s ha %d camera(s) ativa(s), devia ser 1" % [nomes[modo], ativas.size()])

	# 4. O corpo so aparece fora da 1a pessoa (ver _apply_camera_mode).
	print("\n=== o corpo aparece? ===")
	for modo in range(3):
		while player.camera_mode != modo:
			player.toggle_camera_mode()
		await get_tree().process_frame
		var so_sombra := _so_sombra(player.get("visual"))
		print("  %-16s so sombra: %s" % [nomes[modo], so_sombra])
		if modo == 0 and not so_sombra:
			fail("em 1a pessoa o corpo devia ficar so como sombra")
		if modo != 0 and so_sombra:
			fail("em %s o corpo devia aparecer" % nomes[modo])

	# 5. Fotos: uma por modo, mais uma da LIVRE com a camera girada meia volta —
	#    que e a prova visual de que ela orbita um boneco que nao virou.
	for modo in range(3):
		while player.camera_mode != modo:
			player.toggle_camera_mode()
		for i in range(12):
			await get_tree().process_frame
		await _foto(nomes[modo].to_lower())
	await _mover_mouse(700.0, -90.0)
	for i in range(12):
		await get_tree().process_frame
	await _foto("terceira_livre_orbitada")

func _cameras(no: Node, saida: Array[Camera3D] = []) -> Array[Camera3D]:
	if no is Camera3D:
		saida.append(no)
	for c in no.get_children():
		_cameras(c, saida)
	return saida

func _so_sombra(no: Node) -> bool:
	if no == null:
		return false
	if no is GeometryInstance3D:
		return (no as GeometryInstance3D).cast_shadow == \
			GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for c in no.get_children():
		if c is GeometryInstance3D or c.get_child_count() > 0:
			return _so_sombra(c)
	return false

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, nome])
	print("  foto: %s.png" % nome)

func _fim() -> void:
	print("\n=== RESULTADO ===")
	if problems.is_empty():
		print("as tres cameras do V se comportam como esperado")
	else:
		print("%d problema(s):" % problems.size())
		for p in problems:
			print("  - " + p)
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit(0 if problems.is_empty() else 1)
