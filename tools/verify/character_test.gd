extends Node
## O personagem do jogador: escolha, formas, cores, altura e a tela que mexe
## nisso tudo.
##
## A pergunta que este teste faz e sempre a mesma: **o que o jogador escolhe
## chega na malha?** Conferir a tabela contra ela mesma nao provaria nada — o
## caminho de verdade e Appearance -> PlayerVisual -> MeshInstance3D, e e ele
## que e percorrido aqui, lendo o peso da shape key DE VOLTA do modelo montado.
##
## A tela tambem e montada de verdade e mexida pelo controle (escrever no
## `HSlider` dispara o mesmo `value_changed` que o mouse dispararia), porque a
## tela ja falhou neste projeto renderizando INVISIVEL com todos os controles no
## lugar (SettingsMenu, 2026-08-04).
##
## Roda com:
##   godot --headless --path . tools/verify/character_test.tscn

const CHARACTER_MENU := preload("res://scenes/ui/CharacterMenu.gd")

## Altura pedida x altura medida do boneco montado. 2 cm de folga: a malha e
## medida pela AABB em pose de bind, que nao e exatamente a pose de skin.
const HEIGHT_TOLERANCE := 0.02

## Cobertura do cranio. Mesmos numeros e mesma ressalva do `player_shots`: a
## conta erra no centimetro (vertices em pose de bind contra osso ja movido),
## entao serve pra exposicao GROSSA e pra tendencia — quem decide de fato sao as
## fotos do `character_shots`.
const HEAD_REGION_MIN_Y := 0.0
const HEAD_REGION_MAX_XZ := 0.22
const EXPOSED_PCT_MAX := 12.0
const EXPOSED_WORST_MAX := 0.06

var problems: Array[String] = []
var _saved_state: Dictionary = {}

func fail(msg: String) -> void:
	problems.append(msg)
	print("    FALHOU: " + msg)

func ok(msg: String) -> void:
	print("    ok: " + msg)

func _ready() -> void:
	# O teste mexe no arquivo de aparencia de verdade (e o unico jeito de provar
	# que ele volta do DISCO). Guarda o estado do jogador e devolve no fim.
	_saved_state = _snapshot()
	await _run()
	_restore()
	print("\n=== RESULTADO ===")
	if problems.is_empty():
		print("personagem: escolha, formas, altura, save e tela conferidos")
	else:
		print("%d problema(s):" % problems.size())
		for p in problems:
			print("  - " + p)
	get_tree().quit(0 if problems.is_empty() else 1)

func _run() -> void:
	_secao_modelos()
	await _secao_formas()
	await _secao_cabeca()
	await _secao_cores()
	await _secao_altura()
	_secao_save()
	await _secao_tela()
	await _secao_mira()

# ------------------------------------------------------------------ modelos

func _secao_modelos() -> void:
	print("\n[1] os dois personagens carregam")
	for entry: Dictionary in Appearance.MODELS:
		var scene: PackedScene = load(str(entry["caminho"])) as PackedScene
		if scene == null:
			fail("modelo '%s' nao carregou de %s" % [entry["id"], entry["caminho"]])
			continue
		var visual := scene.instantiate() as Node3D
		add_child(visual)
		var box := _world_aabb(visual)
		var declared := float(entry["altura_modelo"])
		# A altura declarada na tabela e o que converte "quero 1,80 m" em escala.
		# Se ela estiver errada, o personagem sai do tamanho errado e NADA mais
		# no jogo acusa — por isso ela e conferida contra o arquivo.
		if absf(box.size.y - declared) > 0.01:
			fail("%s: altura declarada %.3f m, medida %.3f m" % [entry["id"], declared, box.size.y])
		else:
			ok("%s: %.3f m no arquivo, bate com a tabela" % [entry["id"], box.size.y])
		visual.queue_free()

# -------------------------------------------------------------------- formas

func _secao_formas() -> void:
	print("\n[2] o que o slider pede chega na malha")
	for entry: Dictionary in Appearance.MODELS:
		var model_id := str(entry["id"])
		Appearance.set_model(model_id)
		Appearance.set_donkey_head(false)
		# Tudo em zero e depois UMA forma no maximo: assim da pra provar que o
		# valor lido de volta e daquela forma, e nao sobra de outra.
		for shape: Dictionary in Appearance.SHAPES:
			Appearance.shapes[str(shape["id"])] = 0.0
		var applicable := Appearance.active_shapes()
		if applicable.is_empty():
			fail("%s: nenhuma forma aplicavel" % model_id)
			continue
		for shape_id: String in applicable:
			Appearance.shapes[shape_id] = 0.85
			var host := Node3D.new()
			add_child(host)
			var visual := PlayerVisual.build(host)
			await get_tree().process_frame
			var got := _read_shape(visual, shape_id)
			if got < 0.0:
				fail("%s: forma '%s' nao existe em malha nenhuma do modelo" % [model_id, shape_id])
			elif absf(got - 0.85) > 0.001:
				fail("%s: pedi %.2f em '%s', a malha ficou com %.2f" % [model_id, 0.85, shape_id, got])
			Appearance.shapes[shape_id] = 0.0
			host.queue_free()
		ok("%s: %d formas chegam na malha (%s)" % [model_id, applicable.size(),
			", ".join(PackedStringArray(applicable.keys()))])

	# A separacao por genero e o que faz a tela mostrar controle que serve. Se
	# ela vazar, o jogador arrasta um slider que nao faz nada.
	Appearance.set_model("masculino")
	for forbidden: String in ["Bust", "Butt", "Hips"]:
		if Appearance.active_shapes().has(forbidden):
			fail("'%s' oferecida no modelo masculino, que nao tem essa forma" % forbidden)
	Appearance.set_model("feminino")
	if Appearance.active_shapes().has("Chest"):
		fail("'Chest' oferecida no modelo feminino")
	ok("busto/gluteo/quadril so na mulher, peitoral so no homem")

## Peso da shape key lido DE VOLTA do modelo montado (-1 = nenhuma malha tem).
func _read_shape(root: Node, shape_id: String) -> float:
	var best := -1.0
	for mi in _all_meshes(root):
		var idx := mi.find_blend_shape_by_name(shape_id)
		if idx >= 0:
			best = maxf(best, mi.get_blend_shape_value(idx))
	return best

# -------------------------------------------------------------------- cabeca

func _secao_cabeca() -> void:
	print("\n[3] a cabeca de jegue cobre os dois personagens")
	for entry: Dictionary in Appearance.MODELS:
		var model_id := str(entry["id"])
		Appearance.set_model(model_id)

		# Com a cabeca de jegue: nem cabelo, nem olho, nem sobrancelha na tela.
		# O cabelo tem NOME DIFERENTE nos dois arquivos (`Hair_Long` no feminino,
		# `Hair_SimpleParted` no masculino), e era so o primeiro que sumia — o
		# homem ficava com o cabelo dentro do cranio do jegue.
		Appearance.set_donkey_head(true)
		var host := Node3D.new()
		add_child(host)
		var visual := PlayerVisual.build(host)
		await get_tree().process_frame
		var leftovers: Array[String] = []
		for mi in _all_meshes(visual):
			if DonkeyHead.is_head_part(mi.name) and mi.is_visible_in_tree():
				leftovers.append(mi.name)
		if not leftovers.is_empty():
			fail("%s: com cabeca de jegue, ainda aparece %s" % [model_id, leftovers])
		else:
			ok("%s: cabelo, olhos e sobrancelha escondidos" % model_id)
		_check_skull_coverage(model_id, visual)
		host.queue_free()

		# Sem a cabeca de jegue o cabelo tem que VOLTAR — senao a opcao "cabeca
		# humana" entrega um careca sem olhos, que ninguem pediu.
		Appearance.set_donkey_head(false)
		var host2 := Node3D.new()
		add_child(host2)
		var human := PlayerVisual.build(host2)
		await get_tree().process_frame
		var hair_visible := false
		for mi in _all_meshes(human):
			if mi.name.begins_with("Hair") and mi.is_visible_in_tree():
				hair_visible = true
		if not hair_visible:
			fail("%s: sem cabeca de jegue, o cabelo continua escondido" % model_id)
		if CharacterVisual.find_skeleton(human).get_node_or_null("CabecaAttach") != null:
			fail("%s: cabeca de jegue montada mesmo desligada na tela" % model_id)
		if hair_visible:
			ok("%s: cabeca humana volta com cabelo e sem focinho" % model_id)
		host2.queue_free()

func _check_skull_coverage(model_id: String, visual: Node3D) -> void:
	var skeleton := CharacterVisual.find_skeleton(visual)
	if skeleton == null:
		fail("%s: personagem sem Skeleton3D" % model_id)
		return
	var attach := skeleton.get_node_or_null("CabecaAttach") as BoneAttachment3D
	if attach == null:
		fail("%s: cabeca de jegue nao foi presa (sem CabecaAttach)" % model_id)
		return
	var head_root := attach.get_node_or_null("CabecaDeJegue") as Node3D
	if head_root == null:
		fail("%s: CabecaAttach sem a cabeca montada" % model_id)
		return
	# Pose de descanso: os vertices do .glb estao em bind, e so nela da pra
	# comparar direto com o osso.
	skeleton.reset_bone_poses()
	var shapes: Array[Transform3D] = []
	for c in head_root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
			shapes.append((c as Node3D).transform)
	if shapes.is_empty():
		fail("%s: DonkeyHead nao montou esfera nenhuma" % model_id)
		return

	var to_head := head_root.global_transform.affine_inverse()
	var checked := 0
	var exposed := 0
	var worst := 0.0
	for mi in _all_meshes(skeleton):
		if _under(mi, "CabecaDeJegue"):
			continue
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var to_local := to_head * mi.global_transform
		for surface in range(mi.mesh.get_surface_count()):
			var arrays := mi.mesh.surface_get_arrays(surface)
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
					worst = maxf(worst, out_by)
	if checked == 0:
		fail("%s: nenhum vertice na regiao da cabeca — janela de medida errada" % model_id)
		return
	var pct := 100.0 * float(exposed) / float(checked)
	print("      %s: %d vertices na cabeca, %d fora do jegue (%.1f%%), pior %.1f cm"
		% [model_id, checked, exposed, pct, worst * 100.0])
	if pct > EXPOSED_PCT_MAX or worst > EXPOSED_WORST_MAX:
		fail("%s: cabeca humana escapando do jegue (%.1f%%, pior %.1f cm) — OLHE as fotos"
			% [model_id, pct, worst * 100.0])

func _outside_by(p: Vector3, shapes: Array[Transform3D]) -> float:
	var best := INF
	for t in shapes:
		var local := t.affine_inverse() * p
		var d := local.length() - 0.5
		var s: Vector3 = t.basis.get_scale()
		best = minf(best, d * minf(s.x, minf(s.y, s.z)))
	return maxf(best, 0.0) if best != INF else INF

func _under(node: Node, ancestor_name: String) -> bool:
	var n := node.get_parent()
	while n != null:
		if n.name == ancestor_name:
			return true
		n = n.get_parent()
	return false

# --------------------------------------------------------------------- cores

func _secao_cores() -> void:
	print("\n[4] a cor pintada e do jogador, nao da cidade")
	Appearance.reset()
	Appearance.set_donkey_head(false)
	# Cor NEUTRA (o padrao das tres paletas): nenhuma superficie pode ganhar
	# material proprio. Duplicar material a toa custa oito materiais por
	# personagem que so repetem o original — e foi isso que fez o roteiro de
	# fotos soltar 28 erros de "material is null" ao encerrar.
	var host := Node3D.new()
	add_child(host)
	var neutral := PlayerVisual.build(host)
	await get_tree().process_frame
	if _override_count(neutral) > 0:
		fail("cor neutra criou %d material proprio" % _override_count(neutral))
	else:
		ok("cor neutra nao duplica material nenhum")
	host.queue_free()

	# Cor escolhida: agora TEM que haver material proprio, senao pintar o jogador
	# pintaria todo pedestre da cidade junto (material vindo de `.glb` e
	# compartilhado entre instancias).
	Appearance.skin = 3
	Appearance.cloth = 5
	var host2 := Node3D.new()
	add_child(host2)
	var tinted := PlayerVisual.build(host2)
	await get_tree().process_frame
	if _override_count(tinted) == 0:
		fail("cor escolhida nao criou material proprio — pintaria a cidade junto")
	else:
		ok("cor escolhida cria %d material proprio" % _override_count(tinted))

	# E voltar pro neutro tem que SOLTAR o override, senao a cor antiga fica
	# grudada no boneco depois de o jogador desfazer a escolha.
	Appearance.skin = 0
	Appearance.cloth = 0
	Appearance.hair = 0
	PlayerVisual.apply_tints(tinted)
	await get_tree().process_frame
	if _override_count(tinted) > 0:
		fail("voltar pra cor neutra deixou %d material antigo grudado" % _override_count(tinted))
	else:
		ok("voltar pro neutro solta o material e a cor original volta")
	host2.queue_free()
	Appearance.reset()

func _override_count(root: Node) -> int:
	var total := 0
	for mi in _all_meshes(root):
		for surface in range(mi.get_surface_override_material_count()):
			if mi.get_surface_override_material(surface) != null:
				total += 1
	return total

# -------------------------------------------------------------------- altura

func _secao_altura() -> void:
	print("\n[5] a altura pedida e a altura que o boneco tem")
	Appearance.set_donkey_head(false)   # orelha em pe passa da cabeca de proposito
	for entry: Dictionary in Appearance.MODELS:
		Appearance.set_model(str(entry["id"]))
		for wanted: float in [Appearance.HEIGHT_MIN, 1.80, Appearance.HEIGHT_MAX]:
			Appearance.set_height(wanted)
			var host := Node3D.new()
			add_child(host)
			var visual := PlayerVisual.build(host)
			await get_tree().process_frame
			var box := _world_aabb(visual)
			if absf(box.size.y - wanted) > HEIGHT_TOLERANCE:
				fail("%s a %.2f m: o boneco ficou com %.2f m" % [entry["id"], wanted, box.size.y])
			host.queue_free()
		ok("%s: %.2f m a %.2f m, medido na malha" % [entry["id"],
			Appearance.HEIGHT_MIN, Appearance.HEIGHT_MAX])
	Appearance.set_height(Appearance.HEIGHT_DEFAULT)

# ---------------------------------------------------------------------- save

func _secao_save() -> void:
	print("\n[6] a aparencia volta do disco")
	Appearance.set_model("masculino")
	Appearance.set_donkey_head(false)
	Appearance.set_height(1.91)
	Appearance.set_shape("Belly", 0.63)
	Appearance.skin = 3
	Appearance.cloth = 5
	Appearance.hair = 2
	Appearance.save_settings()

	# Zera na memoria e le do disco: sem isto o teste passaria mesmo que
	# `save_settings` nao gravasse nada.
	Appearance.reset()
	if Appearance.model_id != "feminino":
		fail("reset() nao voltou pro personagem padrao")
	Appearance.load_settings()
	var expected := {"model_id": "masculino", "donkey_head": false, "height": 1.91,
		"skin": 3, "cloth": 5, "hair": 2}
	for field: String in expected:
		var got: Variant = Appearance.get(field)
		var want: Variant = expected[field]
		var same: bool = (absf(float(got) - float(want)) < 0.001) if typeof(want) == TYPE_FLOAT \
			else got == want
		if not same:
			fail("'%s' voltou do disco como %s, gravei %s" % [field, got, want])
	if absf(float(Appearance.shapes.get("Belly", 0.0)) - 0.63) > 0.001:
		fail("forma 'Belly' voltou do disco como %s" % Appearance.shapes.get("Belly", 0.0))
	ok("modelo, cabeca, altura, cores e formas sobrevivem ao disco")

	# Aparencia NAO e progresso: quem aperta "Novo jogo" perde dinheiro e niveis
	# da loja, e nao pode perder o personagem que montou.
	SaveGame.clear()
	Appearance.load_settings()
	if Appearance.model_id != "masculino":
		fail("'Novo jogo' apagou a aparencia junto com o progresso")
	else:
		ok("'Novo jogo' nao mexe no personagem")

# ---------------------------------------------------------------------- tela

func _secao_tela() -> void:
	print("\n[7] a tela monta, aparece e mexe no boneco")
	Appearance.reset()
	var menu := Control.new()
	menu.set_script(CHARACTER_MENU)
	# Um Control solto nao tem tamanho: sem por dentro de um Control do tamanho
	# da janela, `PRESET_FULL_RECT` daria 0x0 e o teste acusaria um defeito que
	# nao existe.
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child(root)
	root.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	if menu.size.x < 100.0 or menu.size.y < 100.0:
		fail("a tela de personagem montou medindo %s — ver o bug do SettingsMenu 0x0" % menu.size)
	else:
		ok("tela com %d x %d" % [menu.size.x, menu.size.y])

	var preview := menu.find_child("PreviewHolder", true, false)
	if preview == null:
		fail("a tela nao tem o painel de preview")
		root.queue_free()
		return
	var viewport := preview.get_child(0) as SubViewport
	if viewport == null or not viewport.own_world_3d:
		fail("preview sem SubViewport de mundo proprio — desenharia a cena do jogo")
		root.queue_free()
		return
	var body := _find_visual(viewport)
	if body == null:
		fail("o preview nao montou personagem nenhum")
		root.queue_free()
		return
	ok("preview com o boneco montado pelo mesmo PlayerVisual do jogo")

	# Mexer no CONTROLE, e nao chamar o metodo por fora: escrever no HSlider
	# dispara o mesmo `value_changed` que o mouse dispararia, entao o que e
	# testado e o caminho que o jogador percorre.
	var sliders: Dictionary = menu.get("_sliders")
	var bust := sliders.get("Bust") as HSlider
	if bust == null:
		fail("a tela nao tem slider de busto para a mulher")
	else:
		bust.value = 0.93
		await get_tree().process_frame
		var got := _read_shape(body, "Bust")
		if absf(got - 0.93) > 0.01:
			fail("arrastei o slider de busto pra 0.93 e a malha do preview ficou em %.2f" % got)
		elif absf(float(Appearance.shapes["Bust"]) - 0.93) > 0.01:
			fail("o slider mexeu no preview mas nao no Appearance")
		else:
			ok("slider -> Appearance -> malha do preview (busto 93%)")

	# Trocar de personagem tem que TROCAR o boneco. Sem isto o jogador escolhe
	# "Homem" e continua vendo a mulher — que e o defeito mais provavel aqui.
	var picker: OptionButton = menu.get("_model_picker")
	var male_index := -1
	for i in range(Appearance.MODELS.size()):
		if str(Appearance.MODELS[i]["id"]) == "masculino":
			male_index = i
	picker.select(male_index)
	picker.item_selected.emit(male_index)
	await get_tree().process_frame
	var new_body := _find_visual(viewport)
	if Appearance.model_id != "masculino":
		fail("escolher 'Homem' nao mudou o Appearance")
	elif new_body == null:
		fail("trocar de personagem deixou o preview vazio")
	elif _read_shape(new_body, "Chest") < 0.0:
		fail("o preview continua com o modelo antigo depois de trocar pra 'Homem'")
	else:
		ok("trocar de personagem remonta o boneco do preview")

	# Um slider que nao serve pro modelo escolhido nao pode ficar na tela: ele
	# nao faria nada e o jogador so descobriria arrastando.
	var rows: Dictionary = menu.get("_rows")
	if (rows["Bust"] as Control).visible:
		fail("o slider de busto continua na tela com o personagem masculino")
	elif not (rows["Chest"] as Control).visible:
		fail("o slider de peitoral nao aparece com o personagem masculino")
	else:
		ok("a tela troca os controles junto com o personagem")

	# O botao de sair tem que caber na tela SEM rolar. Ele nasceu dentro da
	# coluna rolavel e caia abaixo da dobra — quem abrisse a tela nao acharia
	# como voltar, e isso so apareceu na foto.
	var back_button: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "Salvar e voltar":
			back_button = b as Button
	if back_button == null:
		fail("a tela nao tem botao 'Salvar e voltar'")
	else:
		var bottom: float = back_button.global_position.y + back_button.size.y
		if bottom > menu.size.y + 1.0:
			fail("o botao de voltar cai %.0f px abaixo da tela — so aparece rolando"
				% (bottom - menu.size.y))
		else:
			ok("botao de voltar visivel sem rolar (fim em y=%.0f de %.0f)" % [bottom, menu.size.y])

	root.queue_free()
	await get_tree().process_frame

## O boneco do preview. Compara por PREFIXO: se um dia sobrar o personagem
## antigo na arvore, o novo entra como "Visual2" e um `==` diria que o preview
## esta vazio — mesma armadilha de nome repetido de 2026-08-03.
func _find_visual(node: Node) -> Node3D:
	if node is Node3D and node.name.begins_with("Visual"):
		return node as Node3D
	for c in node.get_children():
		var found := _find_visual(c)
		if found:
			return found
	return null

# ----------------------------------------------------------------- mira

## A altura mexe na posicao da CAMERA, e e dela que sai a mira nos pontos de
## gambiarra — a mecanica central do jogo. Um personagem baixinho nao pode
## perder o acesso a nenhum dos 4 pontos.
func _secao_mira() -> void:
	print("\n[8] as duas pontas da altura ainda alcancam as gambiarras")
	for wanted: float in [Appearance.HEIGHT_MIN, Appearance.HEIGHT_MAX]:
		Appearance.reset()
		Appearance.set_height(wanted)
		var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
		add_child(main)
		await get_tree().process_frame
		await get_tree().physics_frame
		var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
		var car := _find_vehicle(main)
		if player == null or car == null:
			fail("%.2f m: nao achei jogador ou carro na cena" % wanted)
			main.queue_free()
			await get_tree().process_frame
			continue
		# Congelar o carro: sem isso ele assenta na suspensao entre uma medida e
		# outra e os marcadores mudam de lugar no meio da varredura.
		if car is RigidBody3D:
			(car as RigidBody3D).freeze = true
		var spots := _attach_spots(car)
		if spots.size() != 4:
			fail("%.2f m: achei %d pontos de gambiarra no carro, esperava 4" % [wanted, spots.size()])
		var reachable := 0
		var names: Array[String] = []
		for spot in spots:
			if _can_aim(player, spot):
				reachable += 1
			else:
				names.append(spot.name)
		if reachable < 4:
			fail("%.2f m: so %d dos 4 pontos de gambiarra sao alcancaveis (falta %s)"
				% [wanted, reachable, names])
		else:
			ok("%.2f m: os 4 pontos continuam alcancaveis" % wanted)
		main.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame

func _find_vehicle(root: Node) -> Node3D:
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is Node3D and root.is_ancestor_of(n):
			return n as Node3D
	return null

## Os 4 marcadores vivem em `AttachPoints`, e nao soltos no carro (o mesmo
## caminho que o `attach_test` usa).
func _attach_spots(car: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var holder := car.get_node_or_null("AttachPoints")
	if holder == null:
		return out
	for c in holder.get_children():
		if c is Node3D and c.has_method("get_interact_prompt"):
			out.append(c as Node3D)
	return out

## Anda em volta do ponto (8 direcoes x 2 distancias) e responde se de ALGUMA
## posicao normal o raio de interacao do jogo pega o marcador.
func _can_aim(player: CharacterBody3D, spot: Node3D) -> bool:
	var cam := player.get_node("Head/Camera3D") as Camera3D
	var ray := cam.get_node("InteractRay") as RayCast3D
	var target := spot.global_position
	# O jogador fica DE PE no chao de verdade, medido por raio: estimar a altura
	# do chao a partir do alvo deixa ele boiando ou enterrado, e o angulo de
	# visada e o que decide tudo num alvo baixo (licao do attach_test).
	var ground := _ground_under(target)
	for step in range(8):
		var angle := TAU * float(step) / 8.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		for dist: float in [1.4, 2.2]:
			player.global_position = Vector3(target.x + dir.x * dist, ground,
				target.z + dir.z * dist)
			player.velocity = Vector3.ZERO
			player.force_update_transform()
			var to_target: Vector3 = target - cam.global_position
			player.rotation.y = atan2(-to_target.x, -to_target.z)
			player.force_update_transform()
			to_target = target - cam.global_position
			cam.rotation.x = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
			cam.force_update_transform()
			ray.force_raycast_update()
			if ray.is_colliding() and ray.get_collider() == spot:
				return true
	return false

func _ground_under(p: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, p.y + 6.0, p.z), Vector3(p.x, p.y - 20.0, p.z))
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else p.y - 0.6

# ------------------------------------------------------------------ utilidade

func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out

func _world_aabb(root: Node) -> AABB:
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

func _snapshot() -> Dictionary:
	return {"model_id": Appearance.model_id, "donkey_head": Appearance.donkey_head,
		"height": Appearance.height, "shapes": Appearance.shapes.duplicate(),
		"skin": Appearance.skin, "cloth": Appearance.cloth, "hair": Appearance.hair}

func _restore() -> void:
	Appearance.model_id = str(_saved_state["model_id"])
	Appearance.donkey_head = bool(_saved_state["donkey_head"])
	Appearance.height = float(_saved_state["height"])
	Appearance.shapes = (_saved_state["shapes"] as Dictionary).duplicate()
	Appearance.skin = int(_saved_state["skin"])
	Appearance.cloth = int(_saved_state["cloth"])
	Appearance.hair = int(_saved_state["hair"])
	Appearance.save_settings()
