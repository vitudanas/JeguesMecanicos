extends Node
## FOLHA DE CONTATO com a CABECA DE JEGUE ligada, em todos os personagens.
##
## Existe porque o encaixe da cabeca depende de tres coisas que variam por
## arquivo e que numero nenhum garante: achar o osso certo (os 44 modelos usam
## seis padroes de nome diferentes), medir a cabeca humana pra saber quanto
## crescer, e cancelar a rotacao de repouso do osso — se o osso do pescoco
## estiver deitado, o focinho aponta pro chao.
##
## Cada personagem sai de FRENTE e de PERFIL: de frente se ve se o cranio engole
## a cabeca humana; de perfil se ve se o focinho aponta pra frente.
##
##   godot --path . tools/verify/jegue_sheet.tscn

## Modelos que o jogo NAO consegue pôr cabeça de jegue, e por que. Ficam
## listados pra este teste continuar útil: se um modelo novo entrar nesta
## situação, ele reprova em vez de passar despercebido no meio de uma falha
## permanente.
##
## `rem_rezero`: nenhum osso do rig tem "head" no nome (é o único dos 44 assim,
## junto com a Mileena — mas nela o palpite geométrico acerta). Nele o palpite
## cai no peito, e o código prefere não pôr cabeça a pôr no lugar errado.
const SEM_OSSO_DE_CABECA: Array[String] = ["rem_rezero"]

const OUT_DIR := "user://jegue_sheet"
const POR_LINHA := 5
const PASSO := 1.4

var _stage: Node3D
var _camera: Camera3D
var _saved: Dictionary = {}
var problems: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_saved = {"model": Appearance.model_id, "donkey": Appearance.donkey_head,
		"height": Appearance.height}
	_build_stage()
	await _folha()
	Appearance.model_id = str(_saved["model"])
	Appearance.donkey_head = bool(_saved["donkey"])
	Appearance.height = float(_saved["height"])
	Appearance.save_settings()

	print("")
	if problems.is_empty():
		print("=== RESULTADO ===\n%d personagens com cabeca de jegue — OLHE as fotos"
			% Appearance.models().size())
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0 if problems.is_empty() else 1)

func _build_stage() -> void:
	_stage = Node3D.new()
	add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.62, 0.74)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.5
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-16, -130, 0)
	fill.light_energy = 0.6
	_stage.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.current = true
	_stage.add_child(_camera)

func _folha() -> void:
	var modelos := Appearance.models()
	print("%d personagens" % modelos.size())
	var linhas: int = int(ceil(float(modelos.size()) / float(POR_LINHA)))
	for linha in range(linhas):
		var montados: Array[Node3D] = []
		var inicio := linha * POR_LINHA
		var fim: int = mini(inicio + POR_LINHA, modelos.size())
		var alturas: Array[float] = []
		for i in range(inicio, fim):
			var m: Dictionary = modelos[i]
			Appearance.model_id = str(m["id"])
			Appearance.donkey_head = true
			Appearance.height = 1.80
			var holder := Node3D.new()
			_stage.add_child(holder)
			holder.position = Vector3((i - inicio) * PASSO, 0.0, 0.0)
			var corpo := PlayerVisual.build(holder)
			if corpo == null:
				problems.append("%s: nao montou" % m["id"])
				continue
			corpo.rotation_degrees.y = 180.0 - PlayerVisual.facing_degrees()
			montados.append(holder)

			var cabeca := holder.find_child("CabecaDeJegue", true, false) as Node3D
			if cabeca == null:
				if not SEM_OSSO_DE_CABECA.has(str(m["id"])):
					problems.append("%s: NAO recebeu cabeca de jegue" % m["id"])
				else:
					print("  %-42s sem osso de cabeca (excecao conhecida)" % m["id"])
				alturas.append(1.6)
				continue
			# Onde a cabeca FICOU, contra a altura PEDIDA — que e exata e nao
			# precisa ser medida. Medir a altura do boneco aqui foi o meu erro da
			# primeira versao: usei a caixa da malha, que nao vale pra malha
			# skinada (ver MedirPersonagem), e o teste reprovou os 40, inclusive
			# os dois nativos que estao certos desde 2026-08-08.
			var centro := cabeca.global_position.y
			alturas.append(centro)
			var fracao: float = centro / Appearance.height
			var alvo: AABB = cabeca.get_meta("alvo_medido", AABB())
			var corpo_ossos: float = cabeca.get_meta("altura_ossos", 1.0)
			# Quanto da altura do corpo a cabeca medida ocupa. Cabeca de gente da
			# 13-16%; muito abaixo disso a de jegue sai pequena e SOME dentro da
			# humana — defeito que so a foto pega, porque a posicao esta certa.
			var quinhao: float = alvo.size.y / maxf(corpo_ossos, 0.001)
			# O TAMANHO com que a cabeca de jegue foi de fato desenhada. As malhas
			# dela sao primitivas (nao skinadas), entao aqui `mesh.get_aabb()`
			# vale — e o que nao vale pro corpo.
			var caixa := AABB()
			var primeiro := true
			for mi2 in MedirPersonagem.malhas_de(cabeca):
				if mi2.mesh == null:
					continue
				var b := mi2.global_transform * mi2.mesh.get_aabb()
				caixa = b if primeiro else caixa.merge(b)
				primeiro = false
			print("  %-42s %s | desenhada=%.2f" % [m["id"],
				cabeca.get_meta("diag", ""), caixa.size.x])
			# Cabeca de jegue mais estreita que ~18 cm some dentro da cabeca
			# humana: fica no lugar certo e o personagem aparece sem ela.
			if caixa.size.x < 0.18:
				problems.append("%s: cabeca de jegue com so %.2f m de largura — some dentro da humana"
					% [m["id"], caixa.size.x])
			# ALTURA e AVISO, nao reprovacao: ela mede a POSE, e a pose vem da
			# animacao que veio no arquivo — ha modelo que chega meio agachado, e
			# ai a cabeca fica baixa estando no lugar certo (conferido na foto).
			# O que reprova de verdade e nao ter cabeca ou ela sair pequena
			# demais, que sao defeitos independentes de pose.
			if fracao < 0.70 or fracao > 1.05:
				print("      (aviso) pose baixa: cabeca a %.0f%% da altura pedida"
					% (fracao * 100.0))
		_enquadrar(fim - inicio, alturas, 0.0)
		await _shot("linha_%d_frente" % (linha + 1))
		_enquadrar(fim - inicio, alturas, 90.0)
		await _shot("linha_%d_perfil" % (linha + 1))

		for h in montados:
			_stage.remove_child(h)
			h.queue_free()
		await get_tree().process_frame

## Enquadra a FAIXA DA CABECA, nao o corpo inteiro: de corpo inteiro a cabeca
## sai com 40 pixels e nao da pra julgar nem o focinho nem a orelha.
func _enquadrar(quantos: int, alturas: Array[float], giro: float) -> void:
	var media := 0.0
	for a in alturas:
		media += a
	media = (media / float(alturas.size())) if alturas.size() > 0 else 1.6
	var largura: float = float(quantos) * PASSO
	var centro := Vector3(largura * 0.5 - PASSO * 0.5, media, 0.0)
	var dist: float = largura * 1.05 + 1.0
	var dir := Vector3(sin(deg_to_rad(giro)), 0.0, cos(deg_to_rad(giro)))
	_camera.position = centro + dir * dist + Vector3(0.0, 0.12, 0.0)
	_camera.look_at(centro, Vector3.UP)

func _shot(nome: String) -> void:
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, nome])
