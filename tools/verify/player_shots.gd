extends Node
## FOTOS + MEDIDA da jogadora (mulher com cabeca de jegue).
##
## Existe porque a sessao de 2026-08-04 montou a personagem e NAO chegou a
## olhar o resultado — o proprio changelog deixou o aviso. Defeito de
## personagem e quase todo visual: se o cranio engole a cabeca humana, se a
## escala da cabeca bate com o corpo, se a camera de 3a pessoa enquadra. Numero
## nenhum pega isso sozinho.
##
## Mas uma coisa DA pra medir, e vale mais que olhar de um angulo so: se algum
## vertice da cabeca humana fica FORA das formas do jegue. O teste abaixo le as
## esferas do proprio `DonkeyHead` (nao uma copia dos numeros) e testa vertice a
## vertice — e a versao numerica do truque de pintar a malha de magenta que
## resolveu o retalho do ombro em 2026-08-03.
##
## Precisa de janela de verdade (headless nao rasteriza, e MultiMesh/skin nao
## voltam nada com o servidor falso):
##   godot --path . tools/verify/player_shots.tscn

const OUT_DIR := "user://player_shots"

## Regiao da cabeca no espaco do osso `Head` (o mesmo em que o DonkeyHead e
## montado). A cabeca humana medida vai de -0.05 a +0.23 em Y e a |x| ate 0.12;
## do osso PRA BAIXO e pescoco/ombro, que pode aparecer mesmo (o jegue senta
## num pescoco humano, isso e o desenho). A primeira versao usava y >= -0.06 e
## |xz| <= 0.30 e acusou 363 vertices "expostos" cujo pior caso estava em
## x = -0.295 — ombro, nao cabeca. Janela larga demais mede a coisa errada.
const HEAD_REGION_MIN_Y := 0.0
const HEAD_REGION_MAX_XZ := 0.22

var main: Node
var player: Node3D
var visual: Node3D
var cam: Camera3D
var problems: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("jogador nao encontrado no grupo 'player'")
		get_tree().quit(1)
		return
	visual = player.get_node_or_null("Visual")
	if visual == null:
		push_error("jogador sem no 'Visual' — PlayerVisual.build nao rodou")
		get_tree().quit(1)
		return

	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	add_child(cam)

	_measure()
	await _run_shots()

	print("")
	if problems.is_empty():
		print("nenhum problema medido (o resto e olhar as fotos)")
	else:
		print("PROBLEMAS (%d):" % problems.size())
		for p in problems:
			print("  - %s" % p)
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

# ---------------------------------------------------------------- medicao

## Le as esferas montadas por DonkeyHead e devolve a transformada de cada uma,
## no espaco da raiz da cabeca. Ler do no construido (e nao repetir os numeros
## aqui) e o que faz este teste continuar valendo quando a cabeca mudar.
func _donkey_shapes(head_root: Node3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for c in head_root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
			out.append((c as Node3D).transform)
	return out

func _measure() -> void:
	var skeleton := CharacterVisual.find_skeleton(visual)
	if skeleton == null:
		problems.append("personagem sem Skeleton3D")
		return
	var attach := skeleton.get_node_or_null("CabecaAttach") as BoneAttachment3D
	if attach == null:
		problems.append("cabeca de jegue nao foi presa (sem no CabecaAttach)")
		return
	var head_root := attach.get_node_or_null("CabecaDeJegue") as Node3D
	if head_root == null:
		problems.append("CabecaAttach sem a cabeca montada")
		return

	# Pose de descanso: os vertices que o .glb guarda estao na pose de bind, e
	# so nela dá pra comparar direto com o osso. Com a animacao rodando a conta
	# compararia a malha deformada contra um osso ja movido.
	skeleton.reset_bone_poses()
	var anim := visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim:
		anim.pause()

	var shapes := _donkey_shapes(head_root)
	print("cabeca de jegue: %d formas esfericas lidas do no montado" % shapes.size())
	if shapes.is_empty():
		problems.append("DonkeyHead nao montou esfera nenhuma")
		return

	var to_head := head_root.global_transform.affine_inverse()
	var checked := 0
	var exposed := 0
	var worst := -1.0
	var worst_at := Vector3.ZERO
	var worst_mesh := ""

	for mi in _visible_meshes(skeleton):
		var mesh := mi.mesh
		if mesh == null:
			continue
		var to_local := to_head * mi.global_transform
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			if arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p: Vector3 = to_local * v
				if p.y < HEAD_REGION_MIN_Y:
					continue
				if absf(p.x) > HEAD_REGION_MAX_XZ or absf(p.z) > HEAD_REGION_MAX_XZ:
					continue
				checked += 1
				var out_by := _outside_by(p, shapes)
				if out_by > 0.0:
					exposed += 1
					if out_by > worst:
						worst = out_by
						worst_at = p
						worst_mesh = mi.name

	var pct := 100.0 * float(exposed) / maxf(float(checked), 1.0)
	print("cabeca humana: %d vertices na regiao da cabeca, %d fora do jegue (%.1f%%)"
		% [checked, exposed, pct])
	if exposed > 0:
		print("  pior: %.3f m para fora, em %s, ponto local %s"
			% [worst, worst_mesh, worst_at])
	if checked == 0:
		problems.append("nenhum vertice de corpo na regiao da cabeca — janela de medida errada")
	# LIMIAR FOLGADO DE PROPOSITO, e a razao importa: os vertices do .glb estao
	# na pose de BIND e sao trazidos pro mundo pela transformada do
	# MeshInstance3D, que nao e exatamente a mesma coisa que a pose de skin que
	# o renderizador usa. Medido: com o cranio cobrindo a cabeca INTEIRA nas
	# fotos de prova (16-19, corpo pintado de magenta, zero magenta na cabeca),
	# esta conta ainda acusava 67 vertices "expostos" ate 2.2 cm. Ou seja, no
	# centimetro ela erra — serve pra pegar exposicao GROSSA e pra acompanhar
	# tendencia (363 -> 88 -> 67 conforme a cabeca foi corrigida), e quem decide
	# de fato sao as fotos de prova. Apertar isso so geraria alarme falso.
	elif pct > 12.0 or worst > 0.06:
		problems.append("cabeca humana escapando do jegue: %d vertices (%.1f%%), pior %.1f cm — OLHE as fotos 16-19"
			% [exposed, pct, worst * 100.0])

	# Escala. O total INCLUI as orelhas em pe, entao passa da altura humana de
	# proposito — o que nao pode e a cabeca virar mascote de time.
	var head_aabb := _world_aabb(head_root)
	var total := _world_aabb(visual)
	var feet_y := player.global_position.y
	print("altura total com orelhas: %.2f m (topo a %.2f m do chao)"
		% [total.size.y, total.position.y + total.size.y - feet_y])
	print("cabeca de jegue: %.2f m alta x %.2f m comprida"
		% [head_aabb.size.y, head_aabb.size.z])
	if total.size.y > 2.4:
		problems.append("personagem com %.2f m — cabeca/orelhas fora de escala" % total.size.y)

	skeleton.reset_bone_poses()
	if anim:
		anim.play("idle")

## Quanto o ponto passa da forma mais generosa que o cobre (0 = coberto).
func _outside_by(p: Vector3, shapes: Array[Transform3D]) -> float:
	var best := INF
	for t in shapes:
		# A esfera do DonkeyHead e a unitaria do Godot (raio 0.5) com escala e
		# rotacao na propria transformada — entao levar o ponto pro espaco dela
		# resolve rotacao e escala de uma vez.
		var local := t.affine_inverse() * p
		var d := local.length() - 0.5
		# De volta pra metros: a escala e anisotropica, uso a menor pra nao
		# subestimar a exposicao.
		var s: Vector3 = t.basis.get_scale()
		best = minf(best, d * minf(s.x, minf(s.y, s.z)))
	return maxf(best, 0.0) if best != INF else INF

func _visible_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_collect_visible(root, out)
	return out

func _collect_visible(node: Node, out: Array[MeshInstance3D]) -> void:
	# A cabeca de jegue nao entra: o teste e sobre o que sobra da humana.
	if node is Node3D and (node as Node3D).name == "CabecaDeJegue":
		return
	if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_collect_visible(c, out)

func _world_aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _all_meshes(root):
		if mi.mesh == null:
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
	if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out

# ------------------------------------------------------------------ fotos

func _ground_at(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, 200.0, p.z), Vector3(p.x, -20.0, p.z))
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else 0.0

func _place(spot: Vector3) -> void:
	player.global_position = Vector3(spot.x, _ground_at(spot) + 0.05, spot.z)
	player.rotation.y = 0.0   # frente do CharacterBody3D e o -Z
	var head_node := player.get_node_or_null("Head") as Node3D
	if head_node:
		head_node.rotation.x = 0.0
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.force_update_transform()

func _shot(shot_name: String) -> void:
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("  foto: %s" % shot_name)

## Camera olhando pro jogador de um angulo em graus (0 = de frente, 90 = da
## direita dele, 180 = de costas), a `dist` metros e mirando em `aim_y` acima
## dos pes.
func _look_from(angle_deg: float, dist: float, aim_y: float, eye_y: float) -> void:
	var base := player.global_position
	var a := deg_to_rad(angle_deg)
	# 0 grau = na frente do jogador, que olha pro -Z.
	var offset := Vector3(sin(a) * dist, 0.0, -cos(a) * dist)
	cam.global_position = base + offset + Vector3(0.0, eye_y, 0.0)
	cam.look_at(base + Vector3(0.0, aim_y, 0.0), Vector3.UP)
	cam.make_current()

func _head_world_y() -> float:
	var skeleton := CharacterVisual.find_skeleton(visual)
	if skeleton:
		var attach := skeleton.get_node_or_null("CabecaAttach") as Node3D
		if attach:
			return attach.global_position.y
	return player.global_position.y + 1.55

func _run_shots() -> void:
	# O jogo ABRE em 1a pessoa, e nela o corpo fica em SHADOWS_ONLY — a
	# primeira rodada deste roteiro fotografou 15 vezes um campo vazio por
	# causa disso. Fotografar o corpo exige o modo em que ele existe na tela.
	if not player.third_person:
		player.toggle_camera_mode()
		for i in range(10):
			await get_tree().process_frame

	# Campo aberto perto da oficina: fundo limpo, luz direta, sem fachada
	# roubando a leitura da silhueta.
	var field := Vector3(-158.0, 0.0, 22.0)
	_place(field)
	for i in range(20):
		await get_tree().process_frame

	var feet := player.global_position.y
	var head_y := _head_world_y() - feet
	var mid := 0.95

	# ------------------------------------------------- corpo inteiro, 4 lados
	for view in [[0.0, "01_frente"], [90.0, "02_perfil"], [180.0, "03_costas"],
			[35.0, "04_tres_quartos"]]:
		_look_from(view[0], 3.4, mid, feet + 1.35)
		await _shot(view[1])

	# ------------------------------------------------------ cabeca, de perto
	# E aqui que o defeito mora: se o cranio nao engole a cabeca humana, o
	# retalho de pele aparece nesta distancia e em nenhuma outra.
	cam.fov = 42.0
	for view in [[0.0, "05_cabeca_frente"], [90.0, "06_cabeca_perfil"],
			[180.0, "07_cabeca_nuca"], [40.0, "08_cabeca_tres_quartos"],
			[15.0, "09_cabeca_de_baixo"]]:
		var eye_y := feet + head_y + (-0.35 if view[1] == "09_cabeca_de_baixo" else 0.06)
		_look_from(view[0], 1.15, head_y, eye_y)
		await _shot(view[1])
	cam.fov = 60.0

	# --------------------------------------------------- andando (a animacao)
	# A cabeca vai num BoneAttachment3D: se ela nao acompanhar o osso, e o bug
	# do cabelo dos NPCs de 2026-08-03 de volta.
	var anim := visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation("walk"):
		anim.play("walk")
		for i in range(25):
			await get_tree().process_frame
		_look_from(30.0, 3.2, mid, feet + 1.3)
		await _shot("10_andando")
		_look_from(30.0, 1.3, head_y, feet + head_y + 0.05)
		await _shot("11_andando_cabeca")
		anim.play("idle")
		for i in range(10):
			await get_tree().process_frame

	# ------------------------------------- cameras do JOGO (1a e 3a pessoa)
	# Sem make_current da camera de debug: quem manda aqui e a camera do
	# proprio jogo, que e o enquadramento que o jogador vai ver.
	var street := Vector3(-4.0, 0.0, 30.0)
	_place(street)
	for i in range(20):
		await get_tree().process_frame

	if player.has_method("toggle_camera_mode"):
		# Vem de 3a pessoa (as fotos de corpo acima). O toggle e quem devolve o
		# `current` pra camera do jogo — a de debug estava mandando ate aqui.
		player.toggle_camera_mode()
		for i in range(15):
			await get_tree().process_frame
		await _shot("12_primeira_pessoa")
		player.toggle_camera_mode()
		for i in range(15):
			await get_tree().process_frame
		await _shot("13_terceira_pessoa")
		# 3a pessoa no campo aberto, que mostra melhor o corpo
		_place(field)
		for i in range(20):
			await get_tree().process_frame
		await _shot("14_terceira_pessoa_campo")
		if anim and anim.has_animation("walk"):
			anim.play("walk")
			for i in range(20):
				await get_tree().process_frame
			await _shot("15_terceira_pessoa_andando")

	# As fotos de prova exigem o corpo VISIVEL, e em 1a pessoa ele fica em
	# SHADOWS_ONLY. Voltar pra 1a pessoa aqui deixaria as 4 fotos abaixo em
	# branco — foi o que ja aconteceu com as 15 primeiras nesta mesma sessao.
	if not player.third_person:
		player.toggle_camera_mode()
		for i in range(10):
			await get_tree().process_frame

	# ------------------------------------------------- prova do que e de quem
	# O corpo humano fica MAGENTA CHAPADO e a cabeca de jegue continua normal.
	# Assim qualquer pedaco de cabeca humana escapando do cranio aparece como
	# mancha berrante, sem chance de confundir com sombra ou com o proprio pelo
	# cinza. E a versao em foto do teste numerico la de cima — e foi exatamente
	# assim que o retalho do ombro dos NPCs foi resolvido em 2026-08-03, depois
	# de tres rodadas ajustando a malha errada.
	if anim:
		anim.play("idle")
	_paint_body_flat()
	for i in range(10):
		await get_tree().process_frame
	cam.fov = 42.0
	for view in [[180.0, "16_prova_nuca"], [150.0, "17_prova_alto_tras"],
			[0.0, "18_prova_frente"], [90.0, "19_prova_perfil"]]:
		var high: float = 0.45 if view[1] == "17_prova_alto_tras" else 0.06
		_look_from(view[0], 1.15, head_y, feet + head_y + high)
		await _shot(view[1])

## Pinta de magenta chapado tudo que e corpo humano (a cabeca de jegue fica de
## fora). So pra fotos de prova — o jogo nunca chama isto.
func _paint_body_flat() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var skeleton := CharacterVisual.find_skeleton(visual)
	var root: Node = skeleton if skeleton else visual
	for mi in _visible_meshes(root):
		mi.material_override = mat
